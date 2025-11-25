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
    
    private var isLockedOvertimeMood = false
    private var moodTimer: Timer?
    private let uiUpdateInterval: TimeInterval = 2.0
    private var moodScoreEMA: Double = 0.0
    private let emaAlpha: Double = 0.4
    
    @Published private var eyeContactRating: Int = 0
    private var eyeContactViolationCount: Int = 0
    private let eyeContactViolationThreshold: Int = 2
    
    private var gazeUpCount: Int = 0
    private var gazeDownCount: Int = 0
    private var recordedGazeEvents: [GazeLogItem] = []
    private var lastGazeEventState: HeadGazeEvent = .normal
    
    private var recordedVideoURL: URL? = nil
    
    private var isSavingVideo: Bool = false
    private var isProcessingToggle: Bool = false
    
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
        self.isTrackingEyeContact = settings.selectedAspects.contains(.kontakMata)
        
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
        
        setupVideoSaveObserver()
        recordingStatus()
        setupRecordingObserver()
        setupAnalysisSubscribers()
        setupMoodAggregation()
    }
    
    private func setupVideoSaveObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ARRecordingSaved"), object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            
            if let url = notification.userInfo?["url"] as? URL {
                print("Video URL received: \(url)")
                self.recordedVideoURL = url
            }
            
            self.isSavingVideo = false
            self.isProcessingToggle = false
            
            let isAudioBusy = self.whisperKitVM.isRecording || self.whisperKitVM.isTranscribing
            
            if !isAudioBusy {
                self.processEvaluation()
            }
        }
    }
    
    func toggleRecording() {
        self.errorMessage = nil

        guard !isProcessingToggle else { return }
        guard whisperModelState == .loaded else {
            self.errorMessage = "Model belum siap, tidak bisa merekam."
            return
        }
        
        isProcessingToggle = true

        let shouldStart = (whisperKitVM.recordingStatus == .stopped)

        if shouldStart {
            
            if isTrackingEyeContact {
                NotificationCenter.default.post(name: NSNotification.Name("StartARRecording"), object: nil)
            }
            
            startGame()
            whisperKitVM.toggleRecording(
                shouldLoop: true,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isProcessingToggle = false
            }
            
        } else {
            stopGameAndProcessing()
            
            whisperKitVM.toggleRecording(
                shouldLoop: false,
                timerSeconds: Double(timerSeconds),
                durationLimitSeconds: durationLimitSeconds
            )
        }
    }
    
    private func stopGameAndProcessing() {
        stopMoodTimer()
        gameTimer?.invalidate()
        gameTimer = nil
        
        if isTrackingEyeContact {
            self.isSavingVideo = true
            NotificationCenter.default.post(name: NSNotification.Name("StopARRecording"), object: nil)
        } else {
            self.isSavingVideo = false
        }
    }
    
    private func processEvaluation() {
        guard !isStopModalActive else { return }
       
        let finalDuration = whisperKitVM.finalBufferDuration
        let dur = finalDuration > 0 ? finalDuration : Double(timerSeconds)
       
        guard dur > 0 || !whisperKitVM.confirmedText.isEmpty else {
            errorMessage = "Tidak ada data audio yang direkam."
            isAnalysisComplete = true
            isSavingVideo = false
            return
        }
       
        finalTranscript = whisperKitVM.confirmedText
       
        let (weakCount, totalCount) = calculateArticulationStats()
        
        let finalAudioURL = whisperKitVM.savedRecordingURL
       
        evaluationResult = EvaluationViewModel.process(
            tempoVM: tempoVM,
            intonationVM: intonationAnalyzerVM,
            fillerWordVM: fillerWordVM,
            duration: dur,
            fullTranscript: finalTranscript,
            articulationCount: weakCount,
            articulationTotal: totalCount,
            gazeUpCount: gazeUpCount,
            gazeDownCount: gazeDownCount,
            videoURL: recordedVideoURL,
            audioURL: finalAudioURL,
            gazeEvents: recordedGazeEvents
        )
       
        recordingStartTime = nil
        isAnalysisComplete = true
        
        isProcessingToggle = false
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
        self.eyeContactRating = 0
        
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
        
        if isMoreThanOneMinute,
           !hasScheduledAutoStop,
           whisperKitVM.recordingStatus == .recording {

            hasScheduledAutoStop = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }
                if self.whisperKitVM.recordingStatus == .recording {
                    self.toggleRecording()
                }
            }
        }
    }
    
    func cleanup() {
        gameTimer?.invalidate()
        gameTimer = nil
        presentationScore = 0.0
        stopMoodTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateHeadGazeEvent(_ event: HeadGazeEvent) {
        guard self.isTrackingEyeContact else { return }

        if event != lastGazeEventState {
            let timestamp = Double(timerSeconds)
            
            if event == .gazeUp || event == .headPitchUp {
                gazeUpCount += 1
                recordedGazeEvents.append(GazeLogItem(timestamp: timestamp, event: "Up"))
            } else if event == .gazeDown || event == .headPitchDown {
                gazeDownCount += 1
                recordedGazeEvents.append(GazeLogItem(timestamp: timestamp, event: "Down"))
            }
            lastGazeEventState = event
        }

        if event == .normal {
            if eyeContactViolationCount > 0 {
                eyeContactViolationCount = 0
            }
            
            if self.eyeContactRating != 3 {
                self.eyeContactRating = 3
            }
            return
        }
        
        eyeContactViolationCount += 1
        
        if eyeContactViolationCount >= eyeContactViolationThreshold {
            if self.eyeContactRating != 1 { self.eyeContactRating = 1 }
        } else {
            if self.eyeContactRating != 3 { self.eyeContactRating = 3 }
        }
    }
    
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
                    
                    if !self.isSavingVideo {
                        self.processEvaluation()
                    }
                }
                
                prevRec = isRec
                prevTrans = isTrans
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
