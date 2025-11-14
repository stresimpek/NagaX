//
//  ModalViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 10/11/25.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI // Diperlukan untuk CGPoint

// Enum dari EyeContactViewModel sekarang pindah ke sini (atau file global)
enum CameraCheckState {
    case preparing
    case detecting
    case holding
    case failed
    case success
}

// Enum utama untuk langkah-langkah
enum InstructionStep {
    case micCheck
    case cameraSetup
    case quietRoom
    case distanceCheck
}

@MainActor
class ModalViewModel: ObservableObject {
    
    // MARK: - Properti Modal yang Sudah Ada
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
        .micCheck: "Nyalakan mikrofonmu, letakan HPmu, lalu cobalah berbicara!\nPastikan suaramu sudah bisa didengar Prof. Belagu!",
        .cameraSetup: "", // Ini akan dikelola oleh state machine di bawah
        .quietRoom: "Pastikan kamu di ruangan yang kondusif.\nGunakan headset untuk pengalaman yang lebih maksimal!",
        .distanceCheck: "Letakan HP di posisi sejajar dengan matamu dan\nnyalakan kameramu!"
    ]
    let needsCameraCheck: Bool
    
    // MARK: - ProPERTI BARU (Digabung dari EyeContactViewModel)
    
    @Published var cameraCheckState: CameraCheckState = .preparing
    @Published var gazeOnTarget: Bool = false
    @Published var gazePoint: CGPoint = .zero
    @Published var hasReceivedFirstGazePoint: Bool = false
    @Published var eyeContactCountdown: Int = 3 // Ganti nama dari 'countdown'
    @Published var resetARKit: Bool = false
    
    private var prepTask: DispatchWorkItem?
    private var detectTask: DispatchWorkItem?
    private var holdTask: DispatchWorkItem?
    
    // MARK: - Init dan Setup
    
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
        
        // ... (binding mic lainnya tetap sama) ...
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
    
    // MARK: - UI Logic
    
    private func updateUIForCurrentStep(step: InstructionStep) {
        // Set instruksi default
        instructionText = instructions[step] ?? ""
        
        switch step {
        case .micCheck:
            stopAllTimers() // Pastikan timer kamera mati
            mainImageName = "ProfessorEar_Angry"
            buttonTitle = "LANJUT"
            isButtonEnabled = false
            showMicVisualizer = true
            checkAndRequestMicPermission()
            
        case .cameraSetup:
            stopMonitoring() // Matikan mic
            mainImageName = ""
            buttonTitle = "" // Tombol diurus oleh ModalView
            isButtonEnabled = false
            showMicVisualizer = false
            startPreparing() // **MULAI LOGIKA KAMERA DI SINI**
            
        case .quietRoom:
            stopAllTimers() // Pastikan timer kamera mati
            mainImageName = "InstructionQuiet"
            buttonTitle = "LANJUT"
            isButtonEnabled = true
            showMicVisualizer = false
            
        // KODE BARU
        case .distanceCheck:
            mainImageName = "InstructionDistance"
            // Tombolnya sekarang dinamis
            if needsCameraCheck {
                buttonTitle = "LANJUT" // Akan lanjut ke setup kamera
            } else {
                buttonTitle = "MULAI LATIHAN" // Ini langkah terakhir jika tak perlu kamera
            }
            isButtonEnabled = true
            showMicVisualizer = false
        }
    }
    
    private func updateMicCheckUI(permission: AVAudioApplication.recordPermission, audioDetected: Bool) {
        // ... (fungsi ini tetap sama) ...
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
    
    // MARK: - Flow Logic
    
    // KODE BARU
    func nextStep() {
        switch currentStep {
        case .micCheck:
            stopMonitoring()
            currentStep = .quietRoom // Selalu ke quietRoom setelah mic
            
        case .quietRoom:
            currentStep = .distanceCheck // Selalu ke distanceCheck setelah quietRoom
            
        case .distanceCheck:
            // Cek kamera HANYA di langkah ini
            if needsCameraCheck {
                currentStep = .cameraSetup // Lanjut ke kamera jika perlu
            } else {
                // Jika tidak perlu kamera, langkah ini adalah yang terakhir,
                // tapi tombol "MULAI LATIHAN" akan ditangani di ModalView.
                // Jadi, kita tidak melakukan apa-apa di sini.
            }
            
        case .cameraSetup:
            // Ini sekarang langkah terakhir, tombolnya akan ditangani di ModalView.
            break
        }
    }
    
    // ... (fungsi mic check: startMonitoring, checkAndRequestMicPermission, stopMonitoring tetap sama) ...
    private func startMonitoring() {
        micMonitor.startMonitoring()
    }
    
    func checkAndRequestMicPermission() {
        // ... (kode asli Anda) ...
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
    
    // MARK: - LOGIKA BARU (Digabung dari EyeContactViewModel)
    
    func stopAllTimers() {
        prepTask?.cancel()
        detectTask?.cancel()
        holdTask?.cancel()
        print("Flow: SEMUA TIMER DIBATALKAN.")
    }
    
    func startPreparing() {
        print("Flow: startPreparing()")
        cameraCheckState = .preparing
        // **Update properti instructionText milik ModalViewModel**
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
        print("Flow: startDetecting() (Timer 5s GAGAL dimulai)")
        cameraCheckState = .detecting
        instructionText = "Pencocokan..."
        
        stopAllTimers()
        
        let task = DispatchWorkItem {
            if self.cameraCheckState == .detecting {
                print("Flow: GAGAL 5 DETIK. Menampilkan tombol reset.")
                self.setFailed()
            } else {
                print("Flow: Timer 5s selesai, tapi state sudah berubah. Aman.")
            }
        }
        self.detectTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: task)
    }
    
    func handleGazeChange(isGazing: Bool) {
        
        if isGazing && cameraCheckState == .detecting {
            print("Flow: Gaze KETEMU. Membatalkan timer gagal 5s.")
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
            print("Flow: Gaze LEPAS. Batal hold, kembali ke detecting.")
            stopAllTimers()
            startDetecting()
        }
    }
    
    func setFailed() {
        print("Flow: setFailed() dipanggil.")
        stopAllTimers()
        cameraCheckState = .failed
        instructionText = "Pencocokan gagal! Silahkan ulangi lagi"
    }
    
    func setSuccess() {
        print("Flow: SUKSES TOTAL.")
        stopAllTimers()
        cameraCheckState = .success
        instructionText = "Good! Sekarang pertahankan posisimu dan hindari berpindah-pindah untuk hasil yang lebih maksimal!"
    }
    
    func resetFlow() {
        print("Flow: resetFlow() dipanggil oleh tombol.")
        stopAllTimers()
        
        self.gazeOnTarget = false
        self.resetARKit = true // Sinyal untuk reset UIKit VC
        self.hasReceivedFirstGazePoint = false
        self.gazePoint = .zero
        
        startPreparing()
    }
}
