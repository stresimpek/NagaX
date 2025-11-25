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
    case quietRoom
    case distanceCheck
    case cameraSetup
}

@MainActor
class ModalViewModel: ObservableObject {
    
    @Published var currentStep: InstructionStep = .micCheck
    @Published var permissionStatus: AVAudioApplication.recordPermission = .undetermined
    @Published var isAudioDetected: Bool = false
    @Published var showPermissionAlert: Bool = false
    
    @Published private(set) var showMicWarning: Bool = true
    @Published var isButtonEnabled: Bool = false
    
    @Published private(set) var instructionText: AttributedString = ""
    @Published private(set) var buttonTitle: String = ""
    @Published private(set) var mainImageName: String = ""
    @Published private(set) var showMicVisualizer: Bool = false
    
    private(set) var micMonitor = MicMonitorModal()
    private var cancellables = Set<AnyCancellable>()
    
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
    
    private let instructions: [InstructionStep: AttributedString] = [
        .micCheck: try! AttributedString(
            markdown: "Nyalakan mikrofonmu, letakan HPmu, lalu cobalah berbicara! Pastikan suaramu sudah bisa didengar **Prof. Belagu**!"
        ),
        .quietRoom: try! AttributedString(
            markdown: "Pastikan kamu di ruangan yang kondusif. Gunakan **headset** untuk pengalaman yang lebih maksimal!"
        ),
        .distanceCheck: try! AttributedString(
            markdown: "Letakan HP di posisi sejajar dengan matamu dengan **jarak maksimal satu lengan**."
        ),
        .cameraSetup: try! AttributedString(
            markdown: ""
        )
    ]
    
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
        if step != .cameraSetup {
            instructionText = instructions[step] ?? ""
        }
        
        switch step {
        case .micCheck:
            stopAllTimers()
            mainImageName = "ProfessorEar_Angry"
            buttonTitle = "LANJUT"
            isButtonEnabled = false
            showMicVisualizer = true
            checkAndRequestMicPermission()
            
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
            
        case .cameraSetup:
            stopMonitoring()
            mainImageName = ""
            buttonTitle = ""
            isButtonEnabled = false
            showMicVisualizer = false
            startPreparing()
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
            // Logic Code 1: Cek butuh kamera atau tidak
            if needsCameraCheck {
                currentStep = .cameraSetup
            } else {
                // Di handle View untuk onStart()
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
    
    func startPreparing() {
        cameraCheckState = .preparing
        instructionText = try! AttributedString(markdown: "Nyalakan kamera dan posisikan dirimu supaya terlihat dalam frame. Perhatikan **titik merah** ini selama **3 detik**.")
        
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
            instructionText = try! AttributedString(markdown: "Good! Sekarang **pertahankan** posisimu...")
            
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
        instructionText = try! AttributedString(markdown: "Pencocokan **gagal**! Silahkan ulangi lagi")
    }
    
    func setSuccess() {
        stopAllTimers()
        cameraCheckState = .success
        instructionText = try! AttributedString(markdown: "Good! Sekarang pertahankan posisimu dan hindari berpindah-pindah untuk hasil yang lebih maksimal!")
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
