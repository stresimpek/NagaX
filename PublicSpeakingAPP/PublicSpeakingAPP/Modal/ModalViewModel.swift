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
    case volumeCheck
}

@MainActor
class ModalViewModel: ObservableObject {
    @Published var currentStep: InstructionStep = .micCheck
    @Published var permissionStatus: AVAudioApplication.recordPermission = .undetermined
    @Published var isAudioDetected: Bool = false
    @Published var showPermissionAlert: Bool = false
    
    @Published private(set) var showMicWarning: Bool = true
    @Published var isButtonEnabled: Bool = false
    
    // UBAH: String -> AttributedString
    @Published private(set) var instructionText: AttributedString = ""
    @Published private(set) var buttonTitle: String = ""
    
    @Published private(set) var mainImageName: String = ""
    @Published private(set) var animationName: String = ""
    @Published private(set) var showMicVisualizer: Bool = false
    
    private(set) var micMonitor = MicMonitorModal()
    private var cancellables = Set<AnyCancellable>()
    
    // UBAH: Dictionary menggunakan AttributedString
    private let instructions: [InstructionStep: AttributedString] = [
        .micCheck: try! AttributedString(
            markdown: "Nyalakan mikrofonmu, letakan HPmu, lalu cobalah berbicara! Pastikan suaramu sudah bisa didengar **Prof. Belagu!**"
        ),
        .cameraSetup: try! AttributedString(markdown: ""), // Kosong karena dinamis
        .quietRoom: try! AttributedString(
            markdown: "Pastikan kamu di ruangan yang kondusif. **Gunakan headset** untuk pengalaman yang lebih maksimal!"
        ),
        .distanceCheck: try! AttributedString(
            markdown: "Letakan HP di posisi **sejajar dengan matamu** dan nyalakan kameramu!"
        ),
        .volumeCheck: try! AttributedString(
            markdown: "Aktifkan volume HP-mu agar suara distraksi dapat terdengar dengan jelas."
        )
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
    
    init(practiceSettings: PracticeSettings, startAtCameraStep: Bool = false) {
        self.needsCameraCheck = practiceSettings.selectedAspects.contains(.kontakMata)
        if startAtCameraStep {
            self.currentStep = .cameraSetup
        } else {
            self.currentStep = .micCheck
        }
        
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
        instructionText = instructions[step] ?? AttributedString("")
        
        switch step {
        case .micCheck:
            stopAllTimers()
            mainImageName = "ProfessorEar_Angry" // Fallback icon
            animationName = ""
            buttonTitle = "Lanjut"
            isButtonEnabled = false
            showMicVisualizer = true
            checkAndRequestMicPermission()
            
        case .cameraSetup:
            stopMonitoring()
            mainImageName = ""
            animationName = ""
            buttonTitle = ""
            isButtonEnabled = false
            showMicVisualizer = false
            startPreparing()
            
        case .quietRoom:
            stopAllTimers()
            mainImageName = ""
            animationName = "Kondusif" // Nama Artboard Animasi
            buttonTitle = "LANJUT"
            isButtonEnabled = true
            showMicVisualizer = false
            
        case .distanceCheck:
            mainImageName = ""
            animationName = "ArmLength" // Nama Artboard Animasi
            if needsCameraCheck {
                buttonTitle = "LANJUT"
            } else {
                buttonTitle = "MULAI LATIHAN"
            }
            isButtonEnabled = true
            showMicVisualizer = false
        case .volumeCheck:
            mainImageName = ""
            animationName = "VOLUME"
            buttonTitle = "LANJUT"
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
            currentStep = .volumeCheck
            
        case .distanceCheck:
            if needsCameraCheck {
                currentStep = .cameraSetup
            } else {
                // Logic start handled in View
            }
        case .volumeCheck:
            currentStep = .distanceCheck
            
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
        @unknown default:
            print("Mic Access ???")
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
    
    // MARK: - Logic Eye Contact (Updated to use AttributedString)
    
    func startPreparing() {
        cameraCheckState = .preparing
        // UBAH: Menggunakan AttributedString(markdown:)
        instructionText = try! AttributedString(markdown: "Nyalakan kamera dan posisikan dirimu supaya terlihat dalam frame. Perhatikan **titik merah ini** selama 3 detik.")
        
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
        instructionText = try! AttributedString(markdown: "Pencocokan...")
        
        stopAllTimers()
        
        let task = DispatchWorkItem {
            if self.cameraCheckState == .detecting {
                self.setFailed()
            }
        }
        self.detectTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: task)
    }
    
    func handleGazeChange(isGazing: Bool) {
        
        if isGazing && cameraCheckState == .detecting {
            stopAllTimers()
            cameraCheckState = .holding
            instructionText = try! AttributedString(markdown: "Good! Sekarang **pertahankan posisimu**...")
            
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
        instructionText = try! AttributedString(markdown: "Pencocokan gagal! Silahkan ulangi lagi.")
    }
    
    func setSuccess() {
        stopAllTimers()
        cameraCheckState = .success
        instructionText = try! AttributedString(markdown: "Good! Sekarang **pertahankan posisimu** dan hindari berpindah-pindah untuk hasil yang lebih maksimal!")
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
