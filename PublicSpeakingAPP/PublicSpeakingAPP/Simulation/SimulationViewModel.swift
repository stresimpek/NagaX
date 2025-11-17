//
//  SimulationViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 20/10/25.
//

import Foundation
import Combine
import SwiftUI
import WhisperKit
import AVFoundation

@MainActor
class SimulationViewModel: ObservableObject {
    @Published private(set) var presentationScore: Double = 0.0
    @Published var timerSeconds: Int = 0
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isOvertimeTrigger: Bool = false
    @Published var isOverOneMinuteTrigger: Bool = false

    private var hasPlayedOvertimeSound = false
    private var hasPlayedOverOneMinuteSound = false
    private var hasScheduledAutoStop = false
    
    @Published var isPaused: Bool = false {
            didSet {
                if isPaused {
                    gameTimer?.invalidate()
                    gameTimer = nil
                } else if !isPaused && isRecording {
                    gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.updateGameLogic()
                        }
                    }
                }
            }
        }

    
    let whisperKitVM: SpeechTranscriberViewModel
    let intonationAnalyzerVM: IntonationAnalyzerViewModel
    let tempoVM: TempoViewModel
    let fillerWordVM: FillerWordViewModel
    
    @Published var evaluationResult: EvaluationModel? = nil
    @Published var isAnalysisComplete: Bool = false
    @Published var whisperModelState: ModelState = .unloaded
    @Published var finalTranscript: String = ""
    @Published var showNoTranscriptAlert: Bool = false
    
    let settings: PracticeSettings
    private var gameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    private var distractionPlayers: [AVAudioPlayer] = []
    private var isLockedOvertimeMood = false
    
    private var moodTimer: Timer?
    private let uiUpdateInterval: TimeInterval = 2.0
    private let minDwellTime: TimeInterval = 3.0
    private var lastMoodChangeAt: Date = .distantPast
    
    private var moodScoreEMA: Double = 0.0
    private let emaAlpha: Double = 0.4
    
    var formattedTime: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init(
        settings: PracticeSettings,
        whisperKitVM: SpeechTranscriberViewModel,
        intonationAnalyzerVM: IntonationAnalyzerViewModel,
        tempoVM: TempoViewModel,
        fillerWordVM: FillerWordViewModel
    ) {
        self.settings = settings
        self.whisperKitVM = whisperKitVM
        self.intonationAnalyzerVM = intonationAnalyzerVM
        self.tempoVM = tempoVM
        self.fillerWordVM = fillerWordVM
        self.whisperKitVM.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelState)
         
        self.whisperKitVM.$publishedError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 } // Hanya teruskan jika tidak nil
            .sink { [weak self] errorText in
                self?.errorMessage = errorText
            }
            .store(in: &cancellables)
        self.whisperKitVM.$showEarlyStopModal
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] showing in
                        guard let self = self else { return }
                        self.isPaused = showing
                    }
                    .store(in: &cancellables)
        self.whisperKitVM.$showEmptyTranscriptModal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                guard let self = self else { return }
                self.isPaused = showing
                if !showing {
                    self.isPaused = false
                }
            }
            .store(in: &cancellables)
        
        recordingStatus()
        
        setupRecordingObserver()
        setupAnalysisSubscribers()
        setupMoodAggregation()
    }
    
    private func setupMoodAggregation() {
        intonationAnalyzerVM.$intonationRating
            .combineLatest(tempoVM.$tempoRating, fillerWordVM.$fillerRating)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (intonation, tempo, filler) in
                guard let self = self else { return }
                
                self.updateAggregateMood(
                    intonationRating: intonation,
                    tempoRating: tempo,
                    fillerRating: filler
                )
            }
            .store(in: &cancellables)
    }
    
    private func updateAggregateMood(intonationRating: Int, tempoRating: Int, fillerRating: Int) {
        
        if isLockedOvertimeMood { return }
    
        print("--- Update Mood ---")
        print("Settings Aspects: \(settings.selectedAspects.map { $0.title })")
        print("Incoming Ratings: Intonation=\(intonationRating), Tempo=\(tempoRating), FillerWords=\(fillerRating)")
        
        var activeRatings: [Int] = []
        
        if settings.selectedAspects.contains(.intonasi) {
            print("Intonation aspect IS selected.")
            activeRatings.append(intonationRating)
        }
        if settings.selectedAspects.contains(.tempo) {
            print("Tempo aspect IS selected.")
            activeRatings.append(tempoRating)
        }
        if settings.selectedAspects.contains(.fillerWords) {
            activeRatings.append(fillerRating)
        }
//            if settings.selectedAspects.contains(.kontakMata) {
//                activeRatings.append(eyeContactRating)
//            }
        
        let validRatings = activeRatings.filter { $0 > 0 }
        guard !validRatings.isEmpty else { return }

        let avg = Double(validRatings.reduce(0, +)) / Double(validRatings.count)
        let instantScore = (avg - 2.0)
        moodScoreEMA = emaAlpha * instantScore + (1.0 - emaAlpha) * moodScoreEMA
    }
    
    private func setupRecordingObserver() {
        var prevRec: Bool? = nil
        var prevTrans: Bool? = nil
        
        whisperKitVM.$isRecording
            .combineLatest(whisperKitVM.$isTranscribing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isRec, isTrans) in
                guard let self = self else { return }
                let justStopped = (prevRec != false || prevTrans != false) && (!isRec && !isTrans)
                if justStopped && self.recordingStartTime != nil {
                    if self.isStopModalActive {
                        print(">>> Suppress evaluation: modal active.")
                    } else {
                        self.processEvaluation()
                    }
                }
                prevRec = isRec
                prevTrans = isTrans
            }
            .store(in: &cancellables)
    }
    
    private func recordingStatus() {
        whisperKitVM.$recordingStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }

                print("[SimulationVM] Received Recording Status: \(newStatus)")

                switch newStatus {
                case .recording:
                    if !self.isRecording {
                        self.isRecording = true
                        print("[SimulationVM] State -> isRecording = true")
                    }
                    if self.recordingStartTime == nil {
                        self.recordingStartTime = Date()
                        print("[SimulationVM] Recording confirmed STARTED at: \(self.recordingStartTime!)")
                    }
                    
                case .starting:
                    if self.isRecording {
                         self.isRecording = false
                         print("[SimulationVM] State -> isRecording = false (During Starting)")
                    }
                    
                case .stopping, .stopped:
                    if self.isRecording {
                        self.isRecording = false
                        print("[SimulationVM] State -> isRecording = false (Stopped/Stopping)")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAnalysisSubscribers() {
        whisperKitVM.$confirmedText
            .combineLatest(whisperKitVM.$hypothesisText)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (confirmed, hypothesis) in
                guard let self = self, self.isRecording, self.whisperKitVM.enableEagerDecoding else { return }
                
                let liveText = confirmed + hypothesis
                let duration = self.whisperKitVM.bufferSeconds
                
                if !liveText.isEmpty && duration > 0 {
                    self.fillerWordVM.analyze(text: liveText, duration: duration)
                }
            }
            .store(in: &cancellables)

        whisperKitVM.$confirmedSegments
            .combineLatest(whisperKitVM.$unconfirmedSegments)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (confirmed, unconfirmed) in
                 guard let self = self, self.isRecording, !self.whisperKitVM.enableEagerDecoding else { return }

                let liveText = confirmed.map { $0.text }.joined() + unconfirmed.map { $0.text }.joined()
                let duration = self.whisperKitVM.bufferSeconds
                
                if !liveText.isEmpty && duration > 0 {
                    self.fillerWordVM.analyze(text: liveText, duration: duration)
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleRecording() {
        self.errorMessage = nil

        guard whisperModelState == .loaded else {
            print("Model belum siap, tidak bisa merekam.")
            self.errorMessage = "Model belum siap, tidak bisa merekam."
            return
        }

        let shouldStart = (whisperKitVM.recordingStatus == .stopped)

        if shouldStart {
            print("Requesting START recording...")
            startGame()
            whisperKitVM.toggleRecording(
                shouldLoop: true,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
        } else {
            print("Requesting STOP recording...")
            whisperKitVM.toggleRecording(
                shouldLoop: false,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
        }
    }

    private func processEvaluation() {
        guard !isRecording else { return }
        guard !isStopModalActive else {
            print("Evaluation skipped: modal active.")
            return
        }
        guard recordingStartTime != nil else { return }
        
        recordingStartTime = nil
        let finalDuration = whisperKitVM.finalBufferDuration
        
        guard finalDuration > 0 || !whisperKitVM.confirmedText.isEmpty else {
            errorMessage = "Tidak ada data audio yang direkam (durasi: \(finalDuration))."
            isAnalysisComplete = true
            return
        }
        
        finalTranscript = whisperKitVM.confirmedText
        evaluationResult = EvaluationViewModel.process(
            tempoVM: tempoVM,
            intonationVM: intonationAnalyzerVM,
            fillerWordVM: fillerWordVM,
            duration: finalDuration
        )
        isAnalysisComplete = true
    }
    
    private func startGame() {
        resetGame()

        self.isAnalysisComplete = false
        self.evaluationResult = nil
        self.finalTranscript = ""
        self.errorMessage = nil
        self.recordingStartTime  = nil
        
        isLockedOvertimeMood = false
        moodScoreEMA = 0.0
        lastMoodChangeAt = .distantPast
        
        hasPlayedOvertimeSound = false
        hasPlayedOverOneMinuteSound = false
        hasScheduledAutoStop = false  
        isOverOneMinuteTrigger = false
        isOvertimeTrigger = false
        isPaused = false
        
        whisperKitVM.resetState()
        tempoVM.clearResults()
        intonationAnalyzerVM.clearResults()
        fillerWordVM.clearResults()
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateGameLogic()
            }
        }
        startMoodTimer()
    }
    
    private func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        
        stopMoodTimer()
        stopMoodTimer()
    }
    
    private func startMoodTimer() {
        stopMoodTimer()
        moodTimer = Timer.scheduledTimer(withTimeInterval: uiUpdateInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.applySmoothedMoodToUI()
            }
        }
    }

    private func stopMoodTimer() {
        moodTimer?.invalidate()
        moodTimer = nil
    }
    
    private func resetGame() {
        timerSeconds = 0
    }
    
    private func updateGameLogic() {
        timerSeconds += 1
        
        if isMoreThanOneMinute,
           !hasScheduledAutoStop,
           whisperKitVM.recordingStatus == .recording {

            hasScheduledAutoStop = true
            print("Lebih dari 1 menit overtime – akan auto-stop dalam 5 detik")

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }

                if self.whisperKitVM.recordingStatus == .recording {
                    print("Auto-stopping recording setelah 5 detik > 1 menit overtime")
                    self.stopGame()
                    toggleRecording()
                } else {
                    print("Auto-stop dibatalkan, recording sudah berhenti lebih dulu")
                }
            }
        }
    }

    
    func cleanup() {
        gameTimer?.invalidate()
        gameTimer = nil
        timerSeconds = 0
        presentationScore = 0.0
        stopMoodTimer()
    }
    
    private func applySmoothedMoodToUI() {
        if isLockedOvertimeMood {
            presentationScore = -1.0
            return
        }
        
        if isOvertime {
            isOvertimeTrigger = true
            if !hasPlayedOvertimeSound {
                print("Overtime mulai – play SFX waktuHabis")
                playLocalSound(named: "waktuHabis")
                hasPlayedOvertimeSound = true
            }
            
            if isMoreThanOneMinute {
                isOverOneMinuteTrigger = true
    
                if !hasPlayedOverOneMinuteSound {
                    print("Overtime > 1 menit – play SFX waktuHabisBanget")
                    playLocalSound(named: "waktuHabisBanget")
                    hasPlayedOverOneMinuteSound = true
                }
                
                presentationScore = -1.0
                isLockedOvertimeMood = true
            } else {
                presentationScore = 0.0
            }
            return
        }

        let clamped = max(-1.0, min(1.0, moodScoreEMA))
        presentationScore = clamped
    }
}

extension SimulationViewModel {
    
    private func playLocalSound(named name: String, ext: String = "MP3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Sound file \(name).\(ext) tidak ditemukan di bundle")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            distractionPlayers.append(player)
                    
            distractionPlayers.removeAll { !$0.isPlaying }
        } catch {
            print("Gagal play sound \(name): \(error)")
        }
    }

    var durationLimitSeconds: Int {
        max(0, settings.durationMinutes * 60)
    }
    
    var isOvertime: Bool {
        durationLimitSeconds > 0 && timerSeconds >= durationLimitSeconds
    }

    var overtimeSeconds: Int {
        guard isOvertime else { return 0 }
        return timerSeconds - durationLimitSeconds
    }
    
    var isMoreThanOneMinute: Bool {
        overtimeSeconds > 60
    }
    
    private var isStopModalActive: Bool {
        whisperKitVM.showEarlyStopModal || whisperKitVM.showEmptyTranscriptModal
    }
    
    func resumeAfterEarlyStop() {
        whisperKitVM.continueRecording(shouldLoop: true)
        if gameTimer == nil {
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateGameLogic()
            }
        }
        isPaused = false
    }
    
    func restartAfterEmptyTranscript() {
        stopGame()
        whisperKitVM.restartSession(shouldLoop: true)
        startGame()
    }
}
