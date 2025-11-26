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
                // Saat pause, kita tidak memproses update game logic
            } else if !isPaused && isRecording {
                // Resume timer jika masih recording
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
    
    // --- INTEGRASI BARU: EyeContactVM ---
    let eyeContactVM: EyeContactViewModel
    
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
        fillerWordVM: FillerWordViewModel,
        // Inject EyeContactVM (Changed to optional to fix MainActor isolation error)
        eyeContactVM: EyeContactViewModel? = nil
    ) {
        self.settings = settings
        self.whisperKitVM = whisperKitVM
        self.intonationAnalyzerVM = intonationAnalyzerVM
        self.tempoVM = tempoVM
        self.fillerWordVM = fillerWordVM
        // Initialize inside init body to ensure MainActor isolation
        self.eyeContactVM = eyeContactVM ?? EyeContactViewModel()
        
        self.whisperKitVM.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelState)
         
        self.whisperKitVM.$publishedError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
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
    
    // --- FUNGSI BARU: Menerima Event dari ARTracker ---
    func updateHeadGazeEvent(_ event: HeadGazeEvent) {
        // CEK PENTING:
        // 1. Harus sedang Recording.
        // 2. Tidak boleh sedang Pause (misal modal stop muncul).
        guard isRecording, !isPaused else {
            return
        }
        
        // Teruskan ke VM khusus
        eyeContactVM.processEvent(event, at: Double(timerSeconds))
    }
    
    private func setupMoodAggregation() {
        // Gabungkan publisher dari semua VM termasuk EyeContact
        intonationAnalyzerVM.$intonationRating
            .combineLatest(tempoVM.$tempoRating, fillerWordVM.$fillerRating, eyeContactVM.$eyeContactRating)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (intonation, tempo, filler, eyeContact) in
                guard let self = self else { return }
                
                self.updateAggregateMood(
                    intonationRating: intonation,
                    tempoRating: tempo,
                    fillerRating: filler,
                    eyeContactRating: eyeContact
                )
            }
            .store(in: &cancellables)
    }
    
    private func updateAggregateMood(intonationRating: Int, tempoRating: Int, fillerRating: Int, eyeContactRating: Int) {
        
        if isLockedOvertimeMood { return }
        
        var activeRatings: [Int] = []
        
        if settings.selectedAspects.contains(.intonasi) {
            activeRatings.append(intonationRating)
        }
        if settings.selectedAspects.contains(.tempo) {
            activeRatings.append(tempoRating)
        }
        if settings.selectedAspects.contains(.fillerWords) {
            activeRatings.append(fillerRating)
        }
        // --- Tambahkan Kontak Mata jika dipilih di settings ---
        if settings.selectedAspects.contains(.kontakMata) {
            activeRatings.append(eyeContactRating)
        }
        
        // Filter nilai 0 (belum ada data)
        let validRatings = activeRatings.filter { $0 > 0 }
        
        // Jika belum ada satupun rating valid, skip update mood
        guard !validRatings.isEmpty else { return }

        // Hitung Rata-rata
        let avg = Double(validRatings.reduce(0, +)) / Double(validRatings.count)
        
        // Konversi ke Mood Score (-1.0 s/d 1.0)
        // Rating 1 (Buruk) -> -1.0
        // Rating 2 (Cukup) -> 0.0
        // Rating 3 (Bagus) -> 1.0
        let instantScore = (avg - 2.0)
        
        // Smoothing (EMA) agar perubahan mood tidak terlalu drastis
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

                switch newStatus {
                case .recording:
                    if !self.isRecording {
                        self.isRecording = true
                    }
                    if self.recordingStartTime == nil {
                        self.recordingStartTime = Date()
                    }
                    
                case .starting:
                    if self.isRecording {
                         self.isRecording = false
                    }
                    
                case .stopping, .stopped:
                    if self.isRecording {
                        self.isRecording = false
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
            self.errorMessage = "Model belum siap, tidak bisa merekam."
            return
        }

        let shouldStart = (whisperKitVM.recordingStatus == .stopped)

        if shouldStart {
            startGame()
            whisperKitVM.toggleRecording(
                shouldLoop: true,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
        } else {
            whisperKitVM.toggleRecording(
                shouldLoop: false,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
        }
    }

    private func processEvaluation() {
        guard !isRecording else { return }
        guard !isStopModalActive else { return }
        guard recordingStartTime != nil else { return }
        
        recordingStartTime = nil
        let finalDuration = whisperKitVM.finalBufferDuration
        
        guard finalDuration > 0 || !whisperKitVM.confirmedText.isEmpty else {
            errorMessage = "Tidak ada data audio yang direkam."
            isAnalysisComplete = true
            return
        }
        
        finalTranscript = whisperKitVM.confirmedText
        let (weakCount, totalCount) = calculateArticulationStats()
        
        evaluationResult = EvaluationViewModel.process(
            tempoVM: tempoVM,
            intonationVM: intonationAnalyzerVM,
            fillerWordVM: fillerWordVM,
            duration: finalDuration,
            fullTranscript: finalTranscript,
            articulationCount: weakCount,
            articulationTotal: totalCount
        )
        isAnalysisComplete = true
    }
    
    private func calculateArticulationStats() -> (count: Int, total: Int) {
        let allWords = whisperKitVM.confirmedWords
        let weakWordsCount = allWords.filter { word in
            let cleaned = word.word.trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespaces))
            return !cleaned.isEmpty && word.probability < 0.55
        }.count
        return (weakWordsCount, allWords.count)
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
        // --- RESET EyeContactVM saat mulai baru ---
        eyeContactVM.clearResults()
        
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }
                if self.whisperKitVM.recordingStatus == .recording {
                    self.stopGame()
                    toggleRecording()
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
                playLocalSound(named: "waktuHabis")
                hasPlayedOvertimeSound = true
            }
            
            if isMoreThanOneMinute {
                isOverOneMinuteTrigger = true
                if !hasPlayedOverOneMinuteSound {
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

// Extension untuk Helper Functions
extension SimulationViewModel {
    
    private func playLocalSound(named name: String, ext: String = "MP3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            distractionPlayers.append(player)
            distractionPlayers.removeAll { !$0.isPlaying }
        } catch {
            print("Gagal play sound: \(error)")
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
