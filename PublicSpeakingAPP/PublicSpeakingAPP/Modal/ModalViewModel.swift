//
//  ModalViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 10/11/25.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

enum InstructionStep {
    case quietRoom
    case micCheck
    case cameraPosition
}

class ModalViewModel: ObservableObject {
    
    @Published var currentStep: InstructionStep = .micCheck
    @Published var permissionStatus: AVAudioApplication.recordPermission = .undetermined
    @Published var isAudioDetected: Bool = false
    @Published var showPermissionAlert: Bool = false
    
    @Published private(set) var showMicWarning: Bool = true
    @Published private(set) var isButtonEnabled: Bool = false
    @Published private(set) var instructionText: String = ""
    @Published private(set) var buttonTitle: String = ""
    @Published private(set) var mainImageName: String = ""
    @Published private(set) var showMicVisualizer: Bool = false
    
    private(set) var micMonitor = MicMonitorModal()
    private var cancellables = Set<AnyCancellable>()
    private let instructions: [InstructionStep: String] = [
        .quietRoom: "Pastikan kamu di ruangan yang kondusif.\nGunakan headset untuk pengalaman yang lebih maksimal!",
        .micCheck: "Nyalakan mikrofonmu, letakan HPmu, lalu cobalah berbicara!\nPastikan suaramu sudah bisa didengar Prof. Belagu!",
        .cameraPosition: "Letakan HP di posisi sejajar dengan matamu dan\nnyalakan kameramu!"
    ]
    
    init() {
        setupBindings()
        updateUIForCurrentStep(step: .micCheck)
    }
    
    private func setupBindings() {
        $currentStep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStep in
                self?.updateUIForCurrentStep(step: newStep)
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest($permissionStatus, $isAudioDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (status, detected) in
                guard let self = self, self.currentStep == .micCheck else { return }
                self.updateMicCheckUI(permission: status, audioDetected: detected)
            }
            .store(in: &cancellables)
        
        micMonitor.$levels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLevels in
                guard let self = self, !self.isAudioDetected else { return }
                if let currentLevel = newLevels.last, currentLevel > 10 {
                    withAnimation(.easeInOut) {
                        self.isAudioDetected = true
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateUIForCurrentStep(step: InstructionStep) {
        instructionText = instructions[step] ?? ""
        
        switch step {
        case .quietRoom:
            mainImageName = "InstructionQuiet"
            buttonTitle = "LANJUT"
            isButtonEnabled = true
            showMicVisualizer = false
            
        case .micCheck:
            mainImageName = "ProfessorEar_Angry"
            buttonTitle = "LANJUT"
            isButtonEnabled = false
            showMicVisualizer = true
            checkAndRequestMicPermission()
            
        case .cameraPosition:
            mainImageName = "InstructionDistance"
            buttonTitle = "MULAI LATIHAN"
            isButtonEnabled = true
            showMicVisualizer = false
        }
    }
    
    private func updateMicCheckUI(permission: AVAudioApplication.recordPermission, audioDetected: Bool) {
        let micOK = (permission == .granted)
        let audioOK = audioDetected
        
        showMicWarning = !micOK || !audioOK
        isButtonEnabled = micOK && audioOK
        
        if isButtonEnabled {
            mainImageName = "ProfessorEar_Calm"
        } else {
            mainImageName = "ProfessorEar_Angry"
        }
    }
    
    func nextStep() {
        switch currentStep {
        case .micCheck:
            stopMonitoring()
            currentStep = .quietRoom
            
        case .quietRoom:
            currentStep = .cameraPosition
            
        case .cameraPosition:
            break
        }
    }
    
    private func startMonitoring() {
        micMonitor.startMonitoring()
    }

    func checkAndRequestMicPermission() {
        permissionStatus = AVAudioApplication.shared.recordPermission

        switch permissionStatus {
        case .granted:
            permissionStatus = .granted
            startMonitoring()
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        self.permissionStatus = .granted
                        self.startMonitoring()
                    } else {
                        self.permissionStatus = .denied
                        self.showPermissionAlert = true
                    }
                }
            }
        case .denied:
            self.showPermissionAlert = true
        @unknown default:
            print("Mic Access ???")
        }
    }
    
    func stopMonitoring() {
        micMonitor.stopMonitoring()
    }
}
