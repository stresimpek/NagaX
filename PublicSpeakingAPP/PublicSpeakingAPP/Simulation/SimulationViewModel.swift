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
    let settings: PracticeSettings
    let isTrackingEyeContact: Bool

    @Published var evaluationResult: EvaluationModel? = nil
    @Published var isAnalysisComplete: Bool = false
    @Published var whisperModelState: ModelState = .unloaded
    @Published var finalTranscript: String = ""
    @Published var showNoTranscriptAlert: Bool = false
   
    private var gameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    private var distractionPlayers: [AVAudioPlayer] = []
    
    // Mood & Scoring
    private var isLockedOvertimeMood = false
    private var moodTimer: Timer?
    private let uiUpdateInterval: TimeInterval = 2.0
    private var moodScoreEMA: Double = 0.0
    private let emaAlpha: Double = 0.4
    
    // Eye Contact Logic
    @Published private var eyeContactRating: Int = 0
    private var eyeContactViolationCount: Int = 0
    private let eyeContactViolationThreshold: Int = 2
    
    // Task 1: Specific Gaze Tracking
    private var gazeUpCount: Int = 0
    private var gazeDownCount: Int = 0
    private var recordedGazeEvents: [GazeLogItem] = []
    private var lastGazeEventState: HeadGazeEvent = .normal
    
    // Task 2: Video Recording (Front Camera via ARKit)
    private var recordedVideoURL: URL? = nil
    
    // FLAGS PENTING:
    private var isSavingVideo: Bool = false     // Mencegah evaluasi jalan sebelum video save
    private var isProcessingToggle: Bool = false // Mencegah tombol ditekan 2x (Anti-Spam)
    
    var formattedTime: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Init
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
        self.isTrackingEyeContact = settings.selectedAspects.contains(.kontakMata)
        
        // Bind Whisper State
        self.whisperKitVM.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelState)
         
        // Bind Errors
        self.whisperKitVM.$publishedError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] errorText in
                self?.errorMessage = errorText
            }
            .store(in: &cancellables)
        
        // Bind Modals to Pause State
        self.whisperKitVM.$showEarlyStopModal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                self?.isPaused = showing
            }
            .store(in: &cancellables)
        
        self.whisperKitVM.$showEmptyTranscriptModal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                guard let self = self else { return }
                self.isPaused = showing
                if !showing { self.isPaused = false }
            }
            .store(in: &cancellables)
        
        // Setup Listeners
        setupVideoSaveObserver() // Listener untuk URL Video dari ARVC
        recordingStatus()
        setupRecordingObserver()
        setupAnalysisSubscribers()
        setupMoodAggregation()
    }
    
    // MARK: - Video Recording Observer (Front Camera)
    private func setupVideoSaveObserver() {
        // Mendengarkan notifikasi dari SimulationARTrackerVC bahwa video sudah disimpan
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ARRecordingSaved"), object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            
            // Ambil URL dari userInfo notifikasi
            if let url = notification.userInfo?["url"] as? URL {
                print("🎥 Video URL received in ViewModel: \(url)")
                self.recordedVideoURL = url
            } else {
                print("⚠️ Video URL not found in notification or save failed.")
            }
            
            // Reset flags
            self.isSavingVideo = false
            self.isProcessingToggle = false // BUKA KUNCI TOMBOL STOP
            
            // Lanjut ke Evaluasi
            self.processEvaluation()
        }
    }
    
    // MARK: - Recording Control
    func toggleRecording() {
        self.errorMessage = nil

        // 1. CEGAH SPAM TOMBOL (Anti-Double Click)
        guard !isProcessingToggle else {
            print("⚠️ Toggle ignored: Processing busy.")
            return
        }
        
        guard whisperModelState == .loaded else {
            self.errorMessage = "Model belum siap, tidak bisa merekam."
            return
        }
        
        // Kunci tombol sementara
        isProcessingToggle = true

        let shouldStart = (whisperKitVM.recordingStatus == .stopped)

        if shouldStart {
            print("Requesting START recording...")
            
            // Kirim sinyal ke ARTrackerVC untuk mulai rekam kamera depan
            NotificationCenter.default.post(name: NSNotification.Name("StartARRecording"), object: nil)
            
            startGame()
            whisperKitVM.toggleRecording(
                shouldLoop: true,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
            
            // Buka kunci tombol setelah delay singkat (agar state stabil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isProcessingToggle = false
            }
            
        } else {
            print("Requesting STOP recording...")
            
            // Stop Game & Video Dulu
            stopGameAndProcessing()
            
            // Stop Whisper
            whisperKitVM.toggleRecording(
                shouldLoop: false,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
            
            // NOTE: Kita TIDAK membuka isProcessingToggle di sini.
            // Kunci akan dibuka otomatis oleh `setupVideoSaveObserver` setelah video selesai disimpan.
        }
    }
    
    // Fungsi Centralized Stop
    private func stopGameAndProcessing() {
        stopMoodTimer()
        gameTimer?.invalidate()
        gameTimer = nil
        
        // Set flag bahwa kita sedang menunggu video disimpan
        self.isSavingVideo = true
        
        // Kirim sinyal ke ARTrackerVC untuk STOP rekam kamera depan
        NotificationCenter.default.post(name: NSNotification.Name("StopARRecording"), object: nil)
    }
    
    private func processEvaluation() {
        // Pastikan tidak ada modal yang menghalangi
        guard !isStopModalActive else { return }
        
        // Pastikan kita punya durasi atau teks
        let finalDuration = whisperKitVM.finalBufferDuration
        let dur = finalDuration > 0 ? finalDuration : Double(timerSeconds)
        
        guard dur > 0 || !whisperKitVM.confirmedText.isEmpty else {
            errorMessage = "Tidak ada data audio yang direkam."
            isAnalysisComplete = true
            isSavingVideo = false
            return
        }
        
        finalTranscript = whisperKitVM.confirmedText
        
        // Generate Evaluation Model
        evaluationResult = EvaluationViewModel.process(
            tempoVM: tempoVM,
            intonationVM: intonationAnalyzerVM,
            fillerWordVM: fillerWordVM,
            duration: dur,
            gazeUpCount: gazeUpCount,      // Task 1 Data
            gazeDownCount: gazeDownCount,  // Task 1 Data
            videoURL: recordedVideoURL,    // Task 2 Data
            gazeEvents: recordedGazeEvents // Task 1&2 Data
        )
        
        recordingStartTime = nil
        isAnalysisComplete = true
        print("✅ Evaluation Processed. Video present: \(recordedVideoURL != nil)")
    }

    // MARK: - Game Logic
    private func startGame() {
        resetGame()

        self.isAnalysisComplete = false
        self.evaluationResult = nil
        self.finalTranscript = ""
        self.errorMessage = nil
        self.recordingStartTime  = nil
        self.eyeContactRating = 0
        
        // Reset Metrics
        self.gazeUpCount = 0
        self.gazeDownCount = 0
        self.eyeContactViolationCount = 0
        self.recordedGazeEvents = []
        self.lastGazeEventState = .normal
        self.recordedVideoURL = nil
        self.isSavingVideo = false
        
        isLockedOvertimeMood = false
        moodScoreEMA = 0.0
        
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
    
    private func resetGame() {
        timerSeconds = 0
    }
    
    private func updateGameLogic() {
        timerSeconds += 1
        
        // Logic Auto-Stop jika Overtime > 1 Menit
        if isMoreThanOneMinute,
           !hasScheduledAutoStop,
           whisperKitVM.recordingStatus == .recording {

            hasScheduledAutoStop = true
            print("Overtime > 1m. Auto-stop in 5s.")

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }
                if self.whisperKitVM.recordingStatus == .recording {
                    self.toggleRecording() // Trigger stop sequence
                }
            }
        }
    }
    
    func cleanup() {
        gameTimer?.invalidate()
        gameTimer = nil
        presentationScore = 0.0
        stopMoodTimer()
        // Hapus observer agar tidak memory leak
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Gaze & Eye Contact Logic (Task 1)
    func updateHeadGazeEvent(_ event: HeadGazeEvent) {
        guard self.isTrackingEyeContact else { return }

        // Hitung Gaze Up/Down secara spesifik & Log Waktu
        if event != lastGazeEventState {
            let timestamp = Double(timerSeconds)
            
            if event == .gazeUp {
                gazeUpCount += 1
                recordedGazeEvents.append(GazeLogItem(timestamp: timestamp, event: "Up"))
            } else if event == .gazeDown {
                gazeDownCount += 1
                recordedGazeEvents.append(GazeLogItem(timestamp: timestamp, event: "Down"))
            }
            lastGazeEventState = event
        }

        // Logika Rating Realtime (Mood Meter)
        if event == .normal {
            if eyeContactViolationCount > 0 {
                eyeContactViolationCount = 0
            }
            let newRating = 3
            if self.eyeContactRating != newRating { self.eyeContactRating = newRating }
            return
        }
        
        eyeContactViolationCount += 1
        if eyeContactViolationCount >= eyeContactViolationThreshold {
            if self.eyeContactRating != 1 { self.eyeContactRating = 1 }
        } else {
            if self.eyeContactRating != 2 { self.eyeContactRating = 2 }
        }
    }
    
    // MARK: - Mood Aggregation
    private func setupMoodAggregation() {
        intonationAnalyzerVM.$intonationRating
            .combineLatest(tempoVM.$tempoRating, fillerWordVM.$fillerRating, $eyeContactRating)
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
        if settings.selectedAspects.contains(.intonasi) { activeRatings.append(intonationRating) }
        if settings.selectedAspects.contains(.tempo) { activeRatings.append(tempoRating) }
        if settings.selectedAspects.contains(.fillerWords) { activeRatings.append(fillerRating) }
        if settings.selectedAspects.contains(.kontakMata) { activeRatings.append(eyeContactRating) }
        
        let validRatings = activeRatings.filter { $0 > 0 }
        guard !validRatings.isEmpty else { return }

        let avg = Double(validRatings.reduce(0, +)) / Double(validRatings.count)
        // Rating 1..3 -> Score -1..1
        let instantScore = (avg - 2.0)
        moodScoreEMA = emaAlpha * instantScore + (1.0 - emaAlpha) * moodScoreEMA
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

    // MARK: - Audio Observers & Setup
    private func setupRecordingObserver() {
        var prevRec: Bool? = nil
        var prevTrans: Bool? = nil
        
        whisperKitVM.$isRecording
            .combineLatest(whisperKitVM.$isTranscribing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isRec, isTrans) in
                guard let self = self else { return }
                let justStopped = (prevRec != false || prevTrans != false) && (!isRec && !isTrans)
                
                // Safety Check: Jika audio berhenti tapi video sedang saving, JANGAN evaluasi dulu.
                // Biarkan observer video yang trigger evaluasi.
                if justStopped && self.recordingStartTime != nil && !self.isSavingVideo {
                    print("Audio stopped. No video saving flag. Triggering fallback evaluation.")
                    self.processEvaluation()
                }
                
                prevRec = isRec
                prevTrans = isTrans
            }
            .store(in: &cancellables)
    }
    
    private func setupAnalysisSubscribers() {
        // Eager Decoding
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

        // Segmented Decoding
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
    
    // MARK: - Helpers
    private func recordingStatus() {
        whisperKitVM.$recordingStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }
                switch newStatus {
                case .recording:
                    if !self.isRecording { self.isRecording = true }
                    if self.recordingStartTime == nil { self.recordingStartTime = Date() }
                case .starting:
                    if self.isRecording { self.isRecording = false }
                case .stopping, .stopped:
                    if self.isRecording { self.isRecording = false }
                }
            }
            .store(in: &cancellables)
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
    
    private func playLocalSound(named name: String, ext: String = "MP3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
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
        stopGameAndProcessing()
        whisperKitVM.restartSession(shouldLoop: true)
        startGame()
    }
}
