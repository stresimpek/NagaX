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

enum CameraCheckState {
    case preparing
    case detecting
    case holding
    case failed
    case success
}

enum InstructionStep {
    case micCheck
    case cameraSetup
    case quietRoom
    case distanceCheck
}

@MainActor
class ModalViewModel: ObservableObject {
    @Published var currentStep: InstructionStep = .micCheck
    @Published var permissionStatus: AVAudioApplication.recordPermission = .undetermined
    @Published var isAudioDetected: Bool = false
    @Published var showPermissionAlert: Bool = false
    
    @Published private(set) var showMicWarning: Bool = true
    @Published var isButtonEnabled: Bool = false
    @Published private(set) var instructionText: String = ""
    @Published private(set) var buttonTitle: String = ""
    @Published private(set) var mainImageName: String = ""
    @Published private(set) var showMicVisualizer: Bool = false
    
    private(set) var micMonitor = MicMonitorModal()
    private var cancellables = Set<AnyCancellable>()
    private let instructions: [InstructionStep: String] = [
        .micCheck: "Nyalakan mikrofonmu, letakan HPmu, lalu cobalah berbicara! Pastikan suaramu sudah bisa didengar Prof. Belagu!",
        .cameraSetup: "",
        .quietRoom: "Pastikan kamu di ruangan yang kondusif. Gunakan headset untuk pengalaman yang lebih maksimal!",
        .distanceCheck: "Letakan HP di posisi sejajar dengan matamu dan nyalakan kameramu!"
    ]
    let needsCameraCheck: Bool
    
    @Published var cameraCheckState: CameraCheckState = .preparing
    @Published var gazeOnTarget: Bool = false
    @Published var gazePoint: CGPoint = .zero
    @Published var hasReceivedFirstGazePoint: Bool = false
    @Published var eyeContactCountdown: Int = 3
    @Published var resetARKit: Bool = false
    
    private var prepTask: DispatchWorkItem?
    private var detectTask: DispatchWorkItem?
    private var holdTask: DispatchWorkItem?
    
    init(practiceSettings: PracticeSettings) {
        self.needsCameraCheck = practiceSettings.selectedAspects.contains(.kontakMata)
        self.currentStep = .micCheck
        
        setupBindings()
        updateUIForCurrentStep(step: self.currentStep)
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
        case .micCheck:
            stopAllTimers()
            mainImageName = "ProfessorEar_Angry"
            buttonTitle = "Lanjut"
            isButtonEnabled = false
            showMicVisualizer = true
            checkAndRequestMicPermission()
            
        case .cameraSetup:
            stopMonitoring()
            mainImageName = ""
            buttonTitle = ""
            isButtonEnabled = false
            showMicVisualizer = false
            startPreparing()
            
        case .quietRoom:
            stopAllTimers()
            mainImageName = "InstructionQuiet"
            buttonTitle = "LANJUT"
            isButtonEnabled = true
            showMicVisualizer = false
            
        case .distanceCheck:
            mainImageName = "InstructionDistance"
            if needsCameraCheck {
                buttonTitle = "LANJUT"
            } else {
                buttonTitle = "MULAI LATIHAN"
            }
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
            currentStep = .distanceCheck
            
        case .distanceCheck:
            if needsCameraCheck {
                currentStep = .cameraSetup
            } else {
            }
            
        case .cameraSetup:
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
        }
    }
        
    func stopMonitoring() {
        micMonitor.stopMonitoring()
    }
    
    func stopAllTimers() {
        prepTask?.cancel()
        detectTask?.cancel()
        holdTask?.cancel()
    }
    
    func startPreparing() {
        cameraCheckState = .preparing
        instructionText = "Nyalakan kamera dan posisikan dirimu supaya terlihat dalam frame. Perhatikan titik merah ini selama 3 detik."
        
        stopAllTimers()
        
        func runCountdown(count: Int) {
            if count > 0 {
                self.eyeContactCountdown = count
                let task = DispatchWorkItem { runCountdown(count: count - 1) }
                self.prepTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
            } else {
                startDetecting()
            }
        }
        runCountdown(count: 3)
    }
    
    func startDetecting() {
        cameraCheckState = .detecting
        instructionText = "Pencocokan..."
        
        stopAllTimers()
        
        let task = DispatchWorkItem {
            if self.cameraCheckState == .detecting {
                self.setFailed()
            } else {
                
            }
        }
        self.detectTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: task)
    }
    
    func handleGazeChange(isGazing: Bool) {
        
        if isGazing && cameraCheckState == .detecting {
            stopAllTimers()
            cameraCheckState = .holding
            instructionText = "Good! Sekarang pertahankan posisimu..."
            
            func runHoldCountdown(count: Int) {
                if count > 0 {
                    self.eyeContactCountdown = count
                    let task = DispatchWorkItem { runHoldCountdown(count: count - 1) }
                    self.holdTask = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
                } else {
                    setSuccess()
                }
            }
            runHoldCountdown(count: 3)
            
        } else if !isGazing && cameraCheckState == .holding {
            stopAllTimers()
            startDetecting()
        }
    }
    
    func setFailed() {
        stopAllTimers()
        cameraCheckState = .failed
        instructionText = "Pencocokan gagal! Silahkan ulangi lagi"
    }
    
    func setSuccess() {
        stopAllTimers()
        cameraCheckState = .success
        instructionText = "Good! Sekarang pertahankan posisimu dan hindari berpindah-pindah untuk hasil yang lebih maksimal!"
    }
    
    func resetFlow() {
        stopAllTimers()
        
        self.gazeOnTarget = false
        self.resetARKit = true
        self.hasReceivedFirstGazePoint = false
        self.gazePoint = .zero
        
        startPreparing()
    }
}
