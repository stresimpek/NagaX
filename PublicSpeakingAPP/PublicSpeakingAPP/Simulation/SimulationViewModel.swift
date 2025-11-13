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
    
    
    let whisperKitVM: SpeechTranscriberViewModel
    let textAnalyzerVM: TextFrequencyAnalyzerViewModel
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
//    private let emaAlpha: Double = 0.25
    private let emaAlpha: Double = 0.4
    
    var formattedTime: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init(
        settings: PracticeSettings,
        whisperKitVM: SpeechTranscriberViewModel,
        textAnalyzerVM: TextFrequencyAnalyzerViewModel,
        intonationAnalyzerVM: IntonationAnalyzerViewModel,
        tempoVM: TempoViewModel,
        fillerWordVM: FillerWordViewModel
    ) {
        self.settings = settings
        self.whisperKitVM = whisperKitVM
        self.textAnalyzerVM = textAnalyzerVM
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
        var previousRecState: Bool? = nil
        var previousTransState: Bool? = nil

        whisperKitVM.$isRecording
            .combineLatest(whisperKitVM.$isTranscribing) // <-- HANYA 2 SINYAL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isRec, isTrans) in // <-- HANYA 2 SINYAL
                guard let self = self else { return }

                let startTimeStatus = (self.recordingStartTime == nil) ? "nil" : "set"
    
                // --- KONDISI ASLI ---
                let justStoppedCompletely = (previousRecState != false || previousTransState != false) && (!isRec && !isTrans)

                if justStoppedCompletely && self.recordingStartTime != nil {
                    print(">>> Observer Condition MET for final evaluation (Just Stopped Completely).")
                    self.processEvaluation()
                } else {
                    var reasons: [String] = []
                    if !justStoppedCompletely { reasons.append("Not a 'Just Stopped Completely' transition") }
                    if self.recordingStartTime == nil { reasons.append("startTime is nil") }
                    if previousRecState == nil { reasons.append("previous state was nil (initial run?)") }
                    print(">>> Observer Condition FAILED: Reasons - \(reasons.joined(separator: ", "))")
                }

                previousRecState = isRec
                previousTransState = isTrans
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
            whisperKitVM.toggleRecording(shouldLoop: true)
        } else {
            print("Requesting STOP recording...")
            stopGame()
            whisperKitVM.toggleRecording(shouldLoop: false)
        }
    }


    private func processEvaluation() {
        guard !self.isRecording else { /* ... */ return }
        print("Memproses evaluasi...")

        guard self.recordingStartTime != nil else {
             print("processEvaluation called again after completion or during processing, ignoring.")
             return
        }
        self.recordingStartTime = nil
        
        let finalDuration = whisperKitVM.finalBufferDuration
        
        let finalIntonationStdDev = intonationAnalyzerVM.calculateFinalStandardDeviation()
        
        guard finalDuration > 0 else {
            self.errorMessage = "Tidak ada data audio yang direkam (durasi: \(finalDuration))."
            print("Tidak ada data audio yang direkam (durasi: \(finalDuration))")
            self.isAnalysisComplete = true
            return
        }
        
        print("Data Evaluasi:")
        print("- Duration: \(finalDuration)s")
        print("- Tempo WPM: \(tempoVM.wpm)")
        print("- Filler Words: \(fillerWordVM.totalFillerCount)")
        print("- Intonation StdDev (Final Full): \(finalIntonationStdDev)")
        
        self.finalTranscript = self.whisperKitVM.confirmedText
        self.evaluationResult = EvaluationViewModel.process(
            tempoVM: self.tempoVM,
            intonationVM: self.intonationAnalyzerVM,
            fillerWordVM: self.fillerWordVM,
            duration: finalDuration
        )
        
        self.isAnalysisComplete = true
        print("Evaluasi selesai, navigasi ke hasil")
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
        
        whisperKitVM.resetState()
        tempoVM.clearResults()
        intonationAnalyzerVM.clearResults()
        textAnalyzerVM.clearResults()
        fillerWordVM.clearResults()
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateGameLogic()
        }
        startMoodTimer()
    }
    
    private func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        
        distractionPlayers.forEach { player in
            if player.isPlaying {
                player.stop()
            }
        }
        
        stopMoodTimer()
        
    }
    
    private func startMoodTimer() {
        stopMoodTimer()
        moodTimer = Timer.scheduledTimer(withTimeInterval: uiUpdateInterval, repeats: true) { [weak self] _ in
            self?.applySmoothedMoodToUI()
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
    }
    
    func cleanup() {
        gameTimer?.invalidate()
        gameTimer = nil
        timerSeconds = 0
        presentationScore = 0.0
        stopMoodTimer()
    }
    
    private func applySmoothedMoodToUI() {
        // — overtime rules (tetap) —
        if isLockedOvertimeMood {
            presentationScore = -1.0   // paksa angry di Rive
            return
        }
        if isOvertime {
            if isMoreThanOneMinute {
                presentationScore = -1.0
                isLockedOvertimeMood = true
            } else {
                presentationScore = 0.0
            }
            return
        }

        // ⬅️ Baris kunci untuk Rive:
        let clamped = max(-1.0, min(1.0, moodScoreEMA))
        presentationScore = clamped
    }


}

extension SimulationViewModel {
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
}
