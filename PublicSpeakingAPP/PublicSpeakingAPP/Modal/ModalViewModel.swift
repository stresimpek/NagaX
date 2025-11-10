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

class ModalViewModel: ObservableObject {
    
    @Published var permissionStatus: AVAudioApplication.recordPermission = .undetermined
    @Published var isAudioDetected: Bool = false
    @Published var showPermissionAlert: Bool = false
    
    @Published private(set) var showMicWarning: Bool = true
    @Published private(set) var isButtonEnabled: Bool = false
    @Published private(set) var instructionMessage: String = ""
    
    private(set) var micMonitor = MicMonitorModal()
    
    private var cancellables = Set<AnyCancellable>()
    private let defaultInstruction = "Nyalakan mikrofonmu, letakan HPmu, lalu cobalah berbicara!\nPastikan suaramu sudah bisa didengar Prof. Belagu!"

    
    init() {
        setupBindings()
        updateUIStates(permission: permissionStatus, audioDetected: isAudioDetected)
    }
    
    private func setupBindings() {
        micMonitor.$levels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLevels in
                guard let self = self else { return }
                
                if !self.isAudioDetected {
                    if let currentLevel = newLevels.last, currentLevel > 10 {
                        withAnimation(.easeInOut) {
                            self.isAudioDetected = true
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest($permissionStatus, $isAudioDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (status, detected) in
                self?.updateUIStates(permission: status, audioDetected: detected)
            }
            .store(in: &cancellables)
    }
    
    private func updateUIStates(permission: AVAudioApplication.recordPermission, audioDetected: Bool) {
        showMicWarning = (permission != .granted) || !audioDetected
        isButtonEnabled = (permission == .granted) && audioDetected
        
        if permission == .denied {
            instructionMessage = defaultInstruction
        } else {
            instructionMessage = defaultInstruction
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
            DispatchQueue.main.async {
                self.showPermissionAlert = true
            }
            
        @unknown default:
            print("Mic Access ???")
        }
    }
    
    func stopMonitoring() {
        micMonitor.stopMonitoring()
    }
}
