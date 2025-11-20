//
//  SpeechTranscriberView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//
//  Refactored with Argmax logic and re-integrated analyzers on 22/10/25.
//

import Foundation
import SwiftUI
import AVFoundation
import WhisperKit
import Combine
import CoreML

enum RecordingStatus {
    case stopped
    case starting
    case recording
    case stopping
}

@MainActor
final class SpeechTranscriberViewModel: ObservableObject {
    // Sentence Analysis (LLM)
    @Published var sentenceAnalysisResult: String = ""
    @Published var isAnalyzingSentence: Bool = false
    @Published var sentenceAnalysisError: String? = nil

    // LLM service for sentence analysis
    private let mistralService: MistralAIService

    // Core Properties
    @Published var whisperKit: WhisperKit?
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var recordingStatus: RecordingStatus = .stopped
    @Published var appStartTime = Date()
    @Published var transcriptionTask: Task<Void, Never>?
    @Published var transcribeTask: Task<Void, Never>?

    // Model Management
    @Published var modelState: ModelState = .unloaded
    @Published var modelStorage: String = "huggingface/models/argmaxinc/whisperkit-coreml"
    @Published var localModels: [String] = []
    @Published var localModelPath: String = ""
    @Published var availableModels: [String] = []
    @Published var availableLanguages: [String] = []
    @Published var disabledModels: [String] = WhisperKit.recommendedModels().disabled
    @Published var loadingProgressValue: Float = 0.0
    @Published var specializationProgressRatio: Float = 0.7

    // Transcription Settings
    @Published var selectedModel: String = "openai_whisper-large-v3-v20240930_547MB"
    @Published var selectedTask: String = "transcribe"
    @Published var selectedLanguage: String = "indonesian"
    @Published var repoName: String = "argmaxinc/whisperkit-coreml"
    @Published var enableTimestamps: Bool = true
    @Published var enablePromptPrefill: Bool = true
    @Published var enableCachePrefill: Bool = true
    @Published var enableSpecialCharacters: Bool = false
    @Published var enableEagerDecoding: Bool = true
    @Published var enableDecoderPreview: Bool = true
    @Published var temperatureStart: Double = 0
    @Published var fallbackCount: Double = 5
    @Published var compressionCheckWindow: Double = 60
    @Published var sampleLength: Double = 224
    @Published var silenceThreshold: Double = 0.5
    @Published var realtimeDelayInterval: Double = 1.0
    @Published var useVAD: Bool = true
    @Published var tokenConfirmationsNeeded: Double = 2
    @Published var concurrentWorkerCount: Double = 4
    @Published var chunkingStrategy: ChunkingStrategy = .vad
    @Published var encoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    @Published var decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine

    // Transcription State & Stats
    @Published var currentText: String = ""
    @Published var currentChunks: [Int: (chunkText: [String], fallbacks: Int)] = [:]
    @Published var modelLoadingTime: TimeInterval = 0
    @Published var firstTokenTime: TimeInterval = 0
    @Published var pipelineStart: TimeInterval = 0
    @Published var effectiveRealTimeFactor: TimeInterval = 0
    @Published var effectiveSpeedFactor: TimeInterval = 0
    @Published var totalInferenceTime: TimeInterval = 0
    @Published var tokensPerSecond: TimeInterval = 0
    @Published var currentLag: TimeInterval = 0
    @Published var currentFallbacks: Int = 0
    @Published var currentEncodingLoops: Int = 0
    @Published var currentDecodingLoops: Int = 0
    @Published var lastBufferSize: Int = 0
    @Published var lastConfirmedSegmentEndSeconds: Float = 0
    @Published var requiredSegmentsForConfirmation: Int = 4
    @Published var bufferEnergy: [Float] = []
    @Published var bufferSeconds: Double = 0
    @Published var finalBufferDuration: Double = 0
    @Published var confirmedSegments: [TranscriptionSegment] = []
    @Published var unconfirmedSegments: [TranscriptionSegment] = []

    // Eager Mode Properties
    @Published var eagerResults: [TranscriptionResult?] = []
    @Published var prevResult: TranscriptionResult?
    @Published var lastAgreedSeconds: Float = 0.0
    @Published var prevWords: [WordTiming] = []
    @Published var lastAgreedWords: [WordTiming] = []
    @Published var confirmedWords: [WordTiming] = []
    @Published var confirmedText: String = ""
    @Published var hypothesisWords: [WordTiming] = []
    @Published var hypothesisText: String = ""
    
    @Published var finalizedStyledTranscript: AttributedString = AttributedString("")
    
    @Published var savedRecordingURL: URL? = nil
    
    weak var intonationAnalyzerVM: IntonationAnalyzerViewModel?
    weak var tempoVM: TempoViewModel?
    weak var fillerWordVM: FillerWordViewModel?
    
    private var analyzerLastSampleIndex: Int = 0
    
    @Published var publishedError: String? = nil
    
    @Published var showEmptyTranscriptModal: Bool = false
    @Published var showEarlyStopModal: Bool = false
    @Published var isPaused: Bool = false
    @Published var hasSpokenInSession: Bool = false // Track if user has spoken in this session
    
    private var sessionSamples: [Float] = []
    private var lastSavedSampleIndexForSession: Int = 0
    
    // Init
    init(mistralAPIKey: String = "rvxmDdHNzkeGxHrJ9hhrZhDJTvjYCV3i") {
        self.mistralService = MistralAIService(apiKey: mistralAPIKey)
    }
    
    func binding<T>(_ keyPath: ReferenceWritableKeyPath<SpeechTranscriberViewModel, T>) -> Binding<T> {
        Binding(get: { self[keyPath: keyPath] },
                set: { self[keyPath: keyPath] = $0 })
    }

    func onAppear() {
        guard modelState == .unloaded else {
            return
        }
        fetchModels()
        
        if modelState == .unloaded {
            loadModel(selectedModel)
        }
        
    }
    
    func getComputeOptions() -> ModelComputeOptions {
        return ModelComputeOptions(audioEncoderCompute: encoderComputeUnits, textDecoderCompute: decoderComputeUnits)
    }
    
    private func resetSessionAggregation() {
        sessionSamples.removeAll()
        lastSavedSampleIndexForSession = 0
        savedRecordingURL = nil

        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsDir.appendingPathComponent("full_recording.wav")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    func resetState() {
        transcribeTask?.cancel()
        transcriptionTask?.cancel()
        isRecording = false
        isTranscribing = false
        recordingStatus = .stopped
        whisperKit?.audioProcessor.stopRecording()
        currentText = ""
        currentChunks = [:]
        
        resetSessionAggregation()

        
        pipelineStart = Double.greatestFiniteMagnitude
        firstTokenTime = Double.greatestFiniteMagnitude
        effectiveRealTimeFactor = 0
        effectiveSpeedFactor = 0
        totalInferenceTime = 0
        tokensPerSecond = 0
        currentLag = 0
        currentFallbacks = 0
        currentEncodingLoops = 0
        currentDecodingLoops = 0
        lastBufferSize = 0
        lastConfirmedSegmentEndSeconds = 0
        requiredSegmentsForConfirmation = 2
        bufferEnergy = []
        bufferSeconds = 0
        finalBufferDuration = 0
        confirmedSegments = []
        unconfirmedSegments = []

        eagerResults = []
        prevResult = nil
        lastAgreedSeconds = 0.0
        prevWords = []
        lastAgreedWords = []
        confirmedWords = []
        confirmedText = ""
        hypothesisWords = []
        hypothesisText = ""
        
        savedRecordingURL = nil
        
        analyzerLastSampleIndex = 0
        intonationAnalyzerVM?.clearResults()
        tempoVM?.clearResults()
        fillerWordVM?.clearResults()
        
        showEmptyTranscriptModal = false
        showEarlyStopModal = false
        isPaused = false
        hasSpokenInSession = false
    }

    func fetchModels() {
        availableModels = [selectedModel]

        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelPath = documents.appendingPathComponent(modelStorage).path

            if FileManager.default.fileExists(atPath: modelPath) {
                localModelPath = modelPath
                do {
                    let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: modelPath)
                    for model in downloadedModels where !localModels.contains(model) {
                        localModels.append(model)
                    }
                } catch {
                    print("Error enumerating files at \(modelPath): \(error.localizedDescription)")
                }
            }
        }

        localModels = WhisperKit.formatModelFiles(localModels)
        for model in localModels {
            if !availableModels.contains(model) {
                availableModels.append(model)
            }
        }

        print("Found locally: \(localModels)")
        print("Previously selected model: \(selectedModel)")

        Task {
            let remoteModelSupport = await WhisperKit.recommendedRemoteModels()
            await MainActor.run {
                for model in remoteModelSupport.supported {
                    if !availableModels.contains(model) {
                        availableModels.append(model)
                    }
                }
                for model in remoteModelSupport.disabled {
                    if !disabledModels.contains(model) {
                        disabledModels.append(model)
                    }
                }
            }
        }
    }

    func loadModel(_ model: String, redownload: Bool = false) {
        print("Selected Model: \(selectedModel)")
        print("""
            Computing Options:
            - Mel Spectrogram:  \(getComputeOptions().melCompute.description)
            - Audio Encoder:    \(getComputeOptions().audioEncoderCompute.description)
            - Text Decoder:     \(getComputeOptions().textDecoderCompute.description)
            - Prefill Data:     \(getComputeOptions().prefillCompute.description)
        """)

        modelState = .loading
        whisperKit = nil
        
        Task {
            let config = WhisperKitConfig(computeOptions: getComputeOptions(),
                                          verbose: true,
                                          logLevel: .debug,
                                          prewarm: false,
                                          load: false,
                                          download: false)
            whisperKit = try await WhisperKit(config)
            guard let whisperKit = whisperKit else {
                return
            }

            var folder: URL?

            if localModels.contains(model) && !redownload {
                folder = URL(fileURLWithPath: localModelPath).appendingPathComponent(model)
            } else {
                folder = try await WhisperKit.download(variant: model, from: repoName, progressCallback: { progress in
                    DispatchQueue.main.async {
                        self.loadingProgressValue = Float(progress.fractionCompleted) * self.specializationProgressRatio
                        self.modelState = .downloading
                    }
                })
            }

            await MainActor.run {
                self.loadingProgressValue = self.specializationProgressRatio
                self.modelState = .downloaded
            }

            if let modelFolder = folder {
                whisperKit.modelFolder = modelFolder

                await MainActor.run {
                    self.loadingProgressValue = self.specializationProgressRatio
                    self.modelState = .prewarming
                }

                let progressBarTask = Task {
                    await updateProgressBar(targetProgress: 0.9, maxTime: 240)
                }

                do {
                    try await whisperKit.prewarmModels()
                    progressBarTask.cancel()
                } catch {
                    self.publishedError = "Gagal memuat model: \(error.localizedDescription)"
                    print("Error prewarming models, retrying: \(error.localizedDescription)")
                    progressBarTask.cancel()
                    if !redownload {
                        loadModel(model, redownload: true)
                        return
                    } else {
                        await MainActor.run { modelState = .unloaded }
                        return
                    }
                }

                await MainActor.run {
                    self.loadingProgressValue = self.specializationProgressRatio + 0.9 * (1 - self.specializationProgressRatio)
                    self.modelState = .loading
                }

                try await whisperKit.loadModels()

                await MainActor.run {
                    if !localModels.contains(model) {
                        localModels.append(model)
                    }

                    availableLanguages = Constants.languages.map { $0.key }.sorted()
                    loadingProgressValue = 1.0
                    modelState = whisperKit.modelState
                }
            }
        }
    }

    func deleteModel() {
        if localModels.contains(selectedModel) {
            let modelFolder = URL(fileURLWithPath: localModelPath).appendingPathComponent(selectedModel)

            do {
                try FileManager.default.removeItem(at: modelFolder)

                if let index = localModels.firstIndex(of: selectedModel) {
                    localModels.remove(at: index)
                }

                modelState = .unloaded
            } catch {
                print("Error deleting model: \(error)")
            }
        }
    }

    func updateProgressBar(targetProgress: Float, maxTime: TimeInterval) async {
        let initialProgress = loadingProgressValue
        let decayConstant = -log(1 - targetProgress) / Float(maxTime)

        let startTime = Date()

        while true {
            let elapsedTime = Date().timeIntervalSince(startTime)

            let decayFactor = exp(-decayConstant * Float(elapsedTime))
            let progressIncrement = (1 - initialProgress) * (1 - decayFactor)
            let currentProgress = initialProgress + progressIncrement

            await MainActor.run {
                loadingProgressValue = currentProgress
            }

            if currentProgress >= targetProgress {
                break
            }

            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                break
            }
        }
    }
    
    // Recording Logic
    func toggleRecording(shouldLoop: Bool, timerSeconds: Double, durationLimitSeconds: Int) {
        isRecording.toggle()

        if isRecording {
            resetState()
            startRecording(shouldLoop)
        } else {
            stopRecording(shouldLoop, timerSeconds: timerSeconds, durationLimitSeconds: durationLimitSeconds)
        }
    }

    func startRecording(_ loop: Bool) {
        guard let whisperKit = whisperKit else { return }

        self.recordingStatus = .starting

        Task(priority: .userInitiated) {
            var deviceId: DeviceID?

            try? whisperKit.audioProcessor.startRecordingLive(inputDeviceID: deviceId) { _ in
                DispatchQueue.main.async {
                    self.bufferEnergy = whisperKit.audioProcessor.relativeEnergy
                    self.bufferSeconds = Double(whisperKit.audioProcessor.audioSamples.count) / Double(WhisperKit.sampleRate)
                }
            }

            // Align the session index with whatever the audio processor currently has
            // (works whether the buffer resets to 0 or continues accumulating).
            self.lastSavedSampleIndexForSession = whisperKit.audioProcessor.audioSamples.count

            await MainActor.run {
                isRecording = true
                isTranscribing = true
                recordingStatus = .recording
            }

            if loop {
                realtimeLoop()
            }
        }
    }
    
    func proceedToEvaluation(loop: Bool) {
        // Save the final audio for playback
        Task(priority: .background) {
            let url = await saveSessionAudioAsWavFile()
            await MainActor.run {
                self.savedRecordingURL = url
            }
        }

        if loop {
            stopRealtimeTranscription()
            
            // Check if we need to re-transcribe for pause/resume case
            if !sessionSamples.isEmpty {
                // Pause/resume case: re-transcribe the full session
                Task {
                    do {
                        try await transcribeFullSession()
                        finalizeText()
                        await self.analyzeTranscriptSentence()
                    } catch {
                        print("Error during full session transcription: \(error.localizedDescription)")
                    }
                }
            } else {
                // Normal case: use existing transcription
                finalizeText()
                Task { await self.analyzeTranscriptSentence() }
            }
        } else {
            transcriptionTask?.cancel()

            transcribeTask = Task {
                await MainActor.run { isTranscribing = true }

                do {
                    // Check if we need to re-transcribe for pause/resume case
                    if !sessionSamples.isEmpty {
                        // Pause/resume case: re-transcribe the full session
                        try await transcribeFullSession()
                    } else {
                        // Normal case: just do one final transcription of current buffer
                        try await transcribeCurrentBuffer()
                    }
                } catch {
                    print("Error during final transcription: \(error.localizedDescription)")
                }
                finalizeText()
                
                // REVISI: Await analysis here, handled with fallback inside
                await self.analyzeTranscriptSentence()

                await MainActor.run {
                    isTranscribing = false
                }
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                if !self.isTranscribing {
                    self.recordingStatus = .stopped
                    print("[SpeechTranscriber] Status -> .stopped")
                }
            }
        }
    }
    
    private func transcribeFullSession() async throws {
        // Get the complete session audio
        guard let whisperKit = whisperKit else { return }
        let current = whisperKit.audioProcessor.audioSamples
        
        let completeAudio: [Float]
        if !sessionSamples.isEmpty {
            // Combine saved session + any remaining tail
            let tailDelta: ArraySlice<Float> = current.suffix(from: min(lastSavedSampleIndexForSession, current.count))
            completeAudio = sessionSamples + tailDelta
            print("[FullSession] Transcribing session: \(sessionSamples.count) + tail: \(tailDelta.count) = \(completeAudio.count) samples (\(Double(completeAudio.count)/16000.0)s)")
        } else {
            completeAudio = Array(current)
            print("[FullSession] Transcribing current buffer: \(completeAudio.count) samples")
        }
        
        guard !completeAudio.isEmpty else {
            print("[FullSession] No audio to transcribe")
            return
        }
        
        // Clear previous transcription state before final transcription
        await MainActor.run {
            confirmedText = ""
            confirmedWords = []
            confirmedSegments = []
            hypothesisText = ""
            hypothesisWords = []
            unconfirmedSegments = []
            lastAgreedSeconds = 0.0
            lastAgreedWords = []
            prevWords = []
            prevResult = nil
            eagerResults = []
        }
        
        if enableEagerDecoding {
            // For eager mode, transcribe the complete audio
            let _ = try await transcribeEagerMode(completeAudio)
        } else {
            // For normal mode, transcribe the complete audio
            let result = try await transcribeAudioSamples(completeAudio)
            
            await MainActor.run {
                guard let segments = result?.segments else { return }
                self.confirmedSegments = segments
                self.unconfirmedSegments = []
                
                if let allWords = result?.allWords {
                    self.confirmedWords = allWords
                    self.confirmedText = allWords.map { $0.word }.joined()
                }
                
                print("[FullSession] Final transcript: '\(self.confirmedText)'")
            }
        }
    }
    
    func stopRecording(_ loop: Bool, timerSeconds: Double, durationLimitSeconds: Int) {
        recordingStatus = .stopping
        isRecording = false
        whisperKit?.audioProcessor.stopRecording()

        Task {
            // Wait for any pending transcription to complete
            await flushPendingTranscription(graceSeconds: 0.5)

            let currentTranscript = confirmedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if currentTranscript.isEmpty && !hasSpokenInSession {
                await MainActor.run {
                    isPaused = true
                    showEmptyTranscriptModal = true
                }
                return
            }
            
            if timerSeconds < Double(durationLimitSeconds) {
                // Save current audio to session before showing modal
                appendCurrentDeltaToSession()
                await MainActor.run {
                    isPaused = true
                    showEarlyStopModal = true
                }
                return
            }
            
            // Normal stop (no pause) - proceed directly to evaluation
            await MainActor.run { proceedToEvaluation(loop: loop) }
        }
    }

        
    func continueRecording(shouldLoop: Bool) {
        showEmptyTranscriptModal = false
        showEarlyStopModal = false
        isPaused = false
        
        // Instead, resume recording while preserving state
        resumeRecording(shouldLoop)
    }
    
    private func resumeRecording(_ loop: Bool) {
        guard let whisperKit = whisperKit else { return }
        
        self.recordingStatus = .starting
        
        Task(priority: .userInitiated) {
            var deviceId: DeviceID?
            
            try? whisperKit.audioProcessor.startRecordingLive(inputDeviceID: deviceId) { _ in
                DispatchQueue.main.async {
                    self.bufferEnergy = whisperKit.audioProcessor.relativeEnergy
                    self.bufferSeconds = Double(whisperKit.audioProcessor.audioSamples.count) / Double(WhisperKit.sampleRate)
                }
            }
            
            // The sessionSamples array already contains everything up to lastSavedSampleIndexForSession
            // So we continue from where the audio processor currently is
            self.lastSavedSampleIndexForSession = whisperKit.audioProcessor.audioSamples.count
            
            await MainActor.run {
                isRecording = true
                isTranscribing = true
                recordingStatus = .recording
            }
            
            if loop {
                realtimeLoop()
            }
        }
    }

    func restartSession(shouldLoop: Bool) {
        showEmptyTranscriptModal = false
        showEarlyStopModal = false
        resetState()
        hasSpokenInSession = false

        // Clear session aggregation for a brand-new session
        sessionSamples.removeAll()
        lastSavedSampleIndexForSession = 0

        startRecording(shouldLoop)
    }

        func proceedToEvaluationFromModal(loop: Bool) {
            showEmptyTranscriptModal = false
            showEarlyStopModal = false
            isPaused = false
            proceedToEvaluation(loop: loop)
        }

    func finalizeText() {
        Task {
            await MainActor.run {
                if hypothesisText != "" {
                    confirmedText += hypothesisText
                    hypothesisText = ""
                }

                if !unconfirmedSegments.isEmpty {
                    confirmedSegments.append(contentsOf: unconfirmedSegments)
                    unconfirmedSegments = []
                }
                
                self.updateFinalizedStyledTranscript()
            }
        }
    }
    
    // LLM Sentence Analysis
    func analyzeTranscriptSentence() async {
        // Use the finalized confirmedText as transcript after finalizeText()
        let transcript = self.confirmedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            await MainActor.run { self.sentenceAnalysisError = "Transcript is empty. Record something first." }
            return
        }

        await MainActor.run {
            self.isAnalyzingSentence = true
            self.sentenceAnalysisError = nil
            self.sentenceAnalysisResult = ""
        }

        do {
            let analysis = try await mistralService.analyzeSentence(from: transcript)
            await MainActor.run { self.sentenceAnalysisResult = analysis }
        } catch {
            // REVISI: FALLBACK JIKA AI ERROR (QUOTA EXCEEDED / NETWORK ERROR)
            // Agar evaluasi tetap jalan dan page tidak kosong/stuck
            print("⚠️ Mistral API Error: \(error.localizedDescription). Using fallback data.")
            
            let dummyAnalysis = """
            [Analisis AI Tidak Tersedia: Koneksi/Kuota]
            
            Transkrip Anda:
            "\(transcript)"
            
            Saran Umum:
            1. Perhatikan struktur S-P-O-K agar kalimat efektif.
            2. Kurangi kata pengisi (filler words) seperti 'hmm', 'anu'.
            3. Jaga tempo bicara agar audiens nyaman.
            """
            
            await MainActor.run {
                self.sentenceAnalysisResult = dummyAnalysis
                self.sentenceAnalysisError = "AI Analysis Unavailable (Using Fallback): \(error.localizedDescription)"
            }
        }

        await MainActor.run { self.isAnalyzingSentence = false }
    }
    
    @MainActor
    func updateFinalizedStyledTranscript() {
        print("Updating finalized styled transcript. Confirmed: \(confirmedWords.count), Prev: \(prevWords.count), LastAgreed: \(lastAgreedWords.count), Hypothesis: \(hypothesisWords.count)")
        
        var attributed = AttributedString("")

        for word in confirmedWords {
            var str = AttributedString(word.word + " ")
            str.foregroundColor = Color(.label)
            attributed.append(str)
        }
        
        let finalHypothesisWords = self.lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(self.prevWords, self.hypothesisWords)
        
        print("--- [DEBUG] Final hypothesis (non-overlapping) has \(finalHypothesisWords.count) words.")

        for word in finalHypothesisWords {
            var str = AttributedString(word.word + " ")
            str.foregroundColor = Color(.label)
            attributed.append(str)
        }

        finalizedStyledTranscript = attributed
    }
    
    // Transcription Logic
    func realtimeLoop() {
        transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer(delayInterval: Float(realtimeDelayInterval))
                } catch is CancellationError {
                    print("Realtime loop cancelled.")
                    break
                } catch {
                    print("Error in realtime loop: \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    func stopRealtimeTranscription() {
        isTranscribing = false
        transcriptionTask?.cancel()
    }

    func transcribeCurrentBuffer(delayInterval: Float = 1.0) async throws {
        guard let whisperKit = whisperKit else { return }
        let currentBuffer = whisperKit.audioProcessor.audioSamples
        let newCount = currentBuffer.count
        let totalDuration = Double(newCount) / Double(WhisperKit.sampleRate)

        if newCount > analyzerLastSampleIndex {
            let delta = Array(currentBuffer[analyzerLastSampleIndex..<newCount])
            analyzerLastSampleIndex = newCount
            if let pcm = makePCMBuffer(from: delta, sampleRate: Double(WhisperKit.sampleRate)) {
                intonationAnalyzerVM?.analyze(buffer: pcm, currentTime: totalDuration)
            }
        }

        let nextBufferSize = currentBuffer.count - lastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)
        guard nextBufferSeconds > delayInterval else {
            await MainActor.run {
                if currentText.isEmpty { currentText = "Waiting for speech..." }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
            return
        }

        if useVAD {
            let voiceDetected = AudioProcessor.isVoiceDetected(
                in: whisperKit.audioProcessor.relativeEnergy,
                nextBufferInSeconds: nextBufferSeconds,
                silenceThreshold: Float(silenceThreshold)
            )
            guard voiceDetected else {
                await MainActor.run {
                    if currentText.isEmpty { currentText = "Waiting for speech..." }
                }
                try await Task.sleep(nanoseconds: 100_000_000)
                return
            }
        }

        lastBufferSize = currentBuffer.count

        if enableEagerDecoding {
            // use wrapper to ensure hasSpokenInSession is updated
            let transcription = try await transcribeEagerMode(Array(currentBuffer))
            await MainActor.run {
                currentText = ""
                tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
                firstTokenTime = transcription?.timings.firstTokenTime ?? 0
                modelLoadingTime = transcription?.timings.modelLoading ?? 0
                pipelineStart = transcription?.timings.pipelineStart ?? 0
                currentLag = transcription?.timings.decodingLoop ?? 0
                currentEncodingLoops = Int(transcription?.timings.totalEncodingRuns ?? 0)
                let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                totalInferenceTime = transcription?.timings.fullPipeline ?? 0
                effectiveRealTimeFactor = Double(totalInferenceTime) / totalAudio
                effectiveSpeedFactor = totalAudio / Double(totalInferenceTime)
            }
        } else {
            let transcription = try await transcribeAudioSamples(Array(currentBuffer))
            if let allWords = transcription?.allWords, let tempoVM = self.tempoVM {
                let totalDuration = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                tempoVM.updateTempo(from: allWords, totalDuration: totalDuration)
            }
            await MainActor.run {
                currentText = ""
                guard let segments = transcription?.segments else { return }
                tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
                firstTokenTime = transcription?.timings.firstTokenTime ?? 0
                modelLoadingTime = transcription?.timings.modelLoading ?? 0
                pipelineStart = transcription?.timings.pipelineStart ?? 0
                currentLag = transcription?.timings.decodingLoop ?? 0
                currentEncodingLoops += Int(transcription?.timings.totalEncodingRuns ?? 0)
                let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                totalInferenceTime += transcription?.timings.fullPipeline ?? 0
                effectiveRealTimeFactor = Double(totalInferenceTime) / totalAudio
                effectiveSpeedFactor = totalAudio / Double(totalInferenceTime)

                if segments.count > requiredSegmentsForConfirmation {
                    let numberToConfirm = segments.count - requiredSegmentsForConfirmation
                    let confirmedArray = Array(segments.prefix(numberToConfirm))
                    let remaining = Array(segments.suffix(requiredSegmentsForConfirmation))
                    if let lastConfirmed = confirmedArray.last,
                       lastConfirmed.end > lastConfirmedSegmentEndSeconds {
                        lastConfirmedSegmentEndSeconds = lastConfirmed.end
                        for seg in confirmedArray where !confirmedSegments.contains(segment: seg) {
                            confirmedSegments.append(seg)
                        }
                    }
                    unconfirmedSegments = remaining
                } else {
                    unconfirmedSegments = segments
                }
            }
        }
    }

    private func transcribeAudioSamples_impl(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        let languageCode = Constants.languages[selectedLanguage, default: Constants.defaultLanguageCode]
        
        let task: DecodingTask = selectedTask == "transcribe" ? .transcribe : .translate
        let seekClip: [Float] = [lastConfirmedSegmentEndSeconds]
        let prompt = "Kalimat ini mungkin terpotong, jangan mengarang kata-kata untuk mengisi sisa kalimat."
        
        let myPromptTokenIDs: [Int]
        if let tokenizer = whisperKit.tokenizer {
            myPromptTokenIDs = try tokenizer.encode(text: prompt)
        } else {
            myPromptTokenIDs = []
        }
        
        let options = DecodingOptions(
            verbose: true,
            task: task,
            language: languageCode,
            temperature: Float(temperatureStart),
            temperatureFallbackCount: Int(fallbackCount),
            sampleLength: Int(sampleLength),
            usePrefillPrompt: enablePromptPrefill,
            usePrefillCache: enableCachePrefill,
            skipSpecialTokens: !enableSpecialCharacters,
            withoutTimestamps: false,
            wordTimestamps: true,
            clipTimestamps: seekClip,
            promptTokens: myPromptTokenIDs,
            chunkingStrategy: chunkingStrategy
        )

        let decodingCallback: ((TranscriptionProgress) -> Bool?) = { (progress: TranscriptionProgress) in
            DispatchQueue.main.async {
                let fallbacks = Int(progress.timings.totalDecodingFallbacks)
                let chunkId = 0

                var updatedChunk = (chunkText: [progress.text], fallbacks: fallbacks)
                if var currentChunk = self.currentChunks[chunkId], let previousChunkText = currentChunk.chunkText.last {
                    if progress.text.count >= previousChunkText.count {
                        currentChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
                        updatedChunk = currentChunk
                    } else {
                        if fallbacks == currentChunk.fallbacks {
                            updatedChunk.chunkText = [updatedChunk.chunkText.first ?? "" + progress.text]
                        } else {
                            updatedChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
                            updatedChunk.fallbacks = fallbacks
                            print("Fallback occured: \(fallbacks)")
                        }
                    }
                }

                self.currentChunks[chunkId] = updatedChunk
                let joinedChunks = self.currentChunks.sorted { $0.key < $1.key }.flatMap { $0.value.chunkText }.joined(separator: "\n")

                self.currentText = joinedChunks
                self.currentFallbacks = fallbacks
                self.currentDecodingLoops += 1
            }

            let currentTokens = progress.tokens
            let checkWindow = Int(self.compressionCheckWindow)
            if currentTokens.count > checkWindow {
                let checkTokens: [Int] = currentTokens.suffix(checkWindow)
                let compressionRatio = TextUtilities.compressionRatio(of: checkTokens)
                if compressionRatio > options.compressionRatioThreshold! {
                    print("Early stopping due to compression threshold")
                    return false
                }
            }
            
            
            if progress.avgLogprob! < options.logProbThreshold! {
                print("Early stopping due to logprob threshold")
                return false
            }
            return nil
        }

        let segmentCallback: SegmentDiscoveryCallback = { segments in
            for segment in segments {
                print("Discovered segment: \(segment.id) (\(segment.seek))): \(segment.start) -> \(segment.end) \(segment.text)")
            }
        }

        whisperKit.segmentDiscoveryCallback = segmentCallback

        let transcriptionResults: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: samples,
            decodeOptions: options,
            callback: decodingCallback
        )

        let mergedResults = TranscriptionUtilities.mergeTranscriptionResults(transcriptionResults)
        return mergedResults
    }

    private func transcribeEagerMode_impl(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        guard whisperKit.textDecoder.supportsWordTimestamps else {
            await MainActor.run {
                confirmedText = "Eager mode requires word timestamps, which are not supported by the current model: \(selectedModel)."
            }
            return nil
        }

        let languageCode = Constants.languages[selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = selectedTask == "transcribe" ? .transcribe : .translate
        print(selectedLanguage)
        print(languageCode)

        let options = DecodingOptions(
            verbose: true,
            task: task,
            language: languageCode,
            temperature: Float(temperatureStart),
            temperatureFallbackCount: Int(fallbackCount),
            sampleLength: Int(sampleLength),
            usePrefillPrompt: enablePromptPrefill,
            usePrefillCache: enableCachePrefill,
            skipSpecialTokens: !enableSpecialCharacters,
            withoutTimestamps: !enableTimestamps,
            wordTimestamps: true,
            firstTokenLogProbThreshold: -1.5,
            chunkingStrategy: ChunkingStrategy.none
        )

        let decodingCallback: ((TranscriptionProgress) -> Bool?) = { progress in
            DispatchQueue.main.async {
                let fallbacks = Int(progress.timings.totalDecodingFallbacks)
                if progress.text.count < self.currentText.count {
                    if fallbacks != self.currentFallbacks {
                        print("Fallback occured: \(fallbacks)")
                    }
                }
                self.currentText = progress.text
                self.currentFallbacks = fallbacks
                self.currentDecodingLoops += 1
            }
            
            let currentTokens = progress.tokens
            let checkWindow = Int(self.compressionCheckWindow)
            if currentTokens.count > checkWindow {
                let checkTokens: [Int] = currentTokens.suffix(checkWindow)
                let compressionRatio = TextUtilities.compressionRatio(of: checkTokens)
                if compressionRatio > options.compressionRatioThreshold! {
                    print("Early stopping due to compression threshold")
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
                print("Early stopping due to logprob threshold")
                return false
            }

            return nil
        }

        print("[EagerMode] \(lastAgreedSeconds)-\(Double(samples.count) / 16000.0) seconds")

        let segmentCallback: SegmentDiscoveryCallback = { segments in
            for segment in segments {
                print("Discovered segment: \(segment.id) (\(segment.seek))): \(segment.start) -> \(segment.end)")
            }
        }

        whisperKit.segmentDiscoveryCallback = segmentCallback

        let streamingAudio = samples
        var streamOptions = options
        streamOptions.clipTimestamps = [lastAgreedSeconds]
        let lastAgreedTokens = lastAgreedWords.flatMap { $0.tokens }
        streamOptions.prefixTokens = lastAgreedTokens
        
        do {
            let transcription: TranscriptionResult? = try await whisperKit.transcribe(audioArray: streamingAudio, decodeOptions: streamOptions, callback: decodingCallback).first
            
            await MainActor.run {
                var skipAppend = false
                if let result = transcription {
                    self.hypothesisWords = result.allWords.filter { $0.start >= self.lastAgreedSeconds }

                    if let prevResult = self.prevResult {
                        self.prevWords = prevResult.allWords.filter { $0.start >= self.lastAgreedSeconds }
                        let commonPrefix = TranscriptionUtilities.findLongestCommonPrefix(self.prevWords, self.hypothesisWords)
                        print("[EagerMode] Prev \"\((self.prevWords.map { $0.word }).joined())\"")
                        print("[EagerMode] Next \"\((self.hypothesisWords.map { $0.word }).joined())\"")
                        print("[EagerMode] Found common prefix \"\((commonPrefix.map { $0.word }).joined())\"")

                        if commonPrefix.count >= Int(self.tokenConfirmationsNeeded) {
                            self.lastAgreedWords = commonPrefix.suffix(Int(self.tokenConfirmationsNeeded))
                            self.lastAgreedSeconds = self.lastAgreedWords.first!.start
                            print("[EagerMode] Found new last agreed word \"\(self.lastAgreedWords.first!.word)\" at \(self.lastAgreedSeconds) seconds")

                            self.confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - Int(self.tokenConfirmationsNeeded)))
                            let currentWords = self.confirmedWords.map { $0.word }.joined()
                            print("[EagerMode] Current:  \(self.lastAgreedSeconds) -> \(Double(samples.count) / 16000.0) \(currentWords)")
                        } else {
                            print("[EagerMode] Using same last agreed time \(self.lastAgreedSeconds)")
                            skipAppend = true
                        }
                    }
                    self.prevResult = result
                }

                if !skipAppend {
                    self.eagerResults.append(transcription)
                }
            }

            await MainActor.run {
                let finalWords = self.confirmedWords.map { $0.word }.joined()
                self.confirmedText = finalWords

                let lastHypothesis = self.lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(self.prevWords, self.hypothesisWords)
                self.hypothesisText = lastHypothesis.map { $0.word }.joined()
                
                // ADD THIS CHECK HERE
                if !self.confirmedWords.isEmpty || !self.hypothesisWords.isEmpty {
                    self.hasSpokenInSession = true
                }
                
                let allCurrentWords = self.confirmedWords + lastHypothesis
                let totalDuration = Double(samples.count) / Double(WhisperKit.sampleRate)

                if let tempoVM = self.tempoVM {
                    tempoVM.updateTempo(from: allCurrentWords, totalDuration: totalDuration)
                }
            }
        } catch {
            print("[EagerMode] Error: \(error)")
            finalizeText()
        }

        let mergedResult = TranscriptionUtilities.mergeTranscriptionResults(eagerResults, confirmedWords: confirmedWords)
        return mergedResult
    }

    private func makePCMBuffer(from samples: [Float], sampleRate: Double = Double(WhisperKit.sampleRate)) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty else { return nil }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 1,
                                         interleaved: false) else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let dst = buffer.floatChannelData?.pointee {
            samples.withUnsafeBufferPointer { src in
                dst.update(from: src.baseAddress!, count: samples.count)
            }
        }
        return buffer
    }
    
    private func saveAudioBufferAsWavFile() async -> URL? {
        guard let whisperKit = whisperKit else { return nil }
        
        let samples = Array(whisperKit.audioProcessor.audioSamples)
        
        guard !samples.isEmpty else { return nil }
        
        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsDir.appendingPathComponent("full_recording.wav")
        
        try? fileManager.removeItem(at: fileURL)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: WhisperKit.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            
            guard let buffer = makePCMBuffer(from: samples, sampleRate: Double(WhisperKit.sampleRate)) else {
                print("Gagal membuat PCM buffer untuk disimpan")
                return nil
            }
            try audioFile.write(from: buffer)
            print("Audio berhasil disimpan di: \(fileURL)")
            return fileURL
        } catch {
            print("Error menyimpan audio: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func appendCurrentDeltaToSession() {
        guard let whisperKit = whisperKit else { return }
        let samples = whisperKit.audioProcessor.audioSamples
        
        guard samples.count > lastSavedSampleIndexForSession else {
            print("[Session] No new samples to append (count: \(samples.count), lastIndex: \(lastSavedSampleIndexForSession))")
            return
        }
        
        let delta = samples[lastSavedSampleIndexForSession..<samples.count]
        sessionSamples.append(contentsOf: delta)
        lastSavedSampleIndexForSession = samples.count
        
        print("[Session] Appended \(delta.count) samples. Total session: \(sessionSamples.count) samples (\(Double(sessionSamples.count)/16000.0)s)")
    }


    // Save the aggregated session audio (all segments) to WAV and update duration
    private func saveSessionAudioAsWavFile() async -> URL? {
        guard let whisperKit = whisperKit else { return nil }
        let current = whisperKit.audioProcessor.audioSamples
        
        // Determine which audio to save
        let audioToSave: [Float]
        
        if !sessionSamples.isEmpty {
            // Pause/resume case: use aggregated session samples + any new tail
            let tailDelta: ArraySlice<Float> = current.suffix(from: min(lastSavedSampleIndexForSession, current.count))
            audioToSave = sessionSamples + tailDelta
            print("[SaveAudio] Using session samples: \(sessionSamples.count) + tail: \(tailDelta.count)")
        } else {
            // Normal case: use the entire current buffer
            audioToSave = Array(current)
            print("[SaveAudio] Using current buffer: \(current.count)")
        }

        guard !audioToSave.isEmpty else { return nil }

        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsDir.appendingPathComponent("full_recording.wav")

        try? fileManager.removeItem(at: fileURL)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: WhisperKit.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            guard let buffer = makePCMBuffer(from: audioToSave, sampleRate: Double(WhisperKit.sampleRate)) else {
                print("Failed to build PCM buffer for session audio")
                return nil
            }
            try audioFile.write(from: buffer)

            let duration = Double(audioToSave.count) / Double(WhisperKit.sampleRate)
            await MainActor.run {
                self.finalBufferDuration = duration
            }

            print("Session audio saved at: \(fileURL)")
            return fileURL
        } catch {
            print("Error saving session audio: \(error.localizedDescription)")
            return nil
        }
    }
    
    func transcribeCurrentBuffer() async throws {
        guard let whisperKit = whisperKit else { return }
        
        let currentBuffer = whisperKit.audioProcessor.audioSamples
        
        
        let totalDuration = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
        
        await MainActor.run {
            self.finalBufferDuration = totalDuration
        }
        
        guard !currentBuffer.isEmpty else { return }
        
        let newCount = currentBuffer.count
        if newCount > analyzerLastSampleIndex {
            let delta = Array(currentBuffer[analyzerLastSampleIndex..<newCount])
            analyzerLastSampleIndex = newCount
            if let pcm = makePCMBuffer(from: delta, sampleRate: Double(WhisperKit.sampleRate)) {
                intonationAnalyzerVM?.analyze(buffer: pcm, currentTime: totalDuration)
            }
        }
        
        let result: TranscriptionResult?
        if enableEagerDecoding {
            result = try await transcribeEagerMode(Array(currentBuffer))
        } else {
            result = try await transcribeAudioSamples(Array(currentBuffer))
            if !confirmedSegments.isEmpty || !unconfirmedSegments.isEmpty {
                self.hasSpokenInSession = true
            }
            await MainActor.run {
                guard let segments = result?.segments else { return }
                let requiredSegmentsForConfirmation = 2
                if segments.count > requiredSegmentsForConfirmation {
                    let confirmCount = segments.count - requiredSegmentsForConfirmation
                    self.confirmedSegments = Array(segments.prefix(confirmCount))
                    self.unconfirmedSegments = Array(segments.suffix(requiredSegmentsForConfirmation))
                } else {
                    self.unconfirmedSegments = segments
                }
                
                if !segments.isEmpty {
                    self.hasSpokenInSession = true
                }
            }
        }
        
        if let allWords = result?.allWords, let tempoVM = self.tempoVM {
            let totalDuration = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
            
            tempoVM.updateTempo(from: allWords, totalDuration: totalDuration)
        }
    }
}

extension SpeechTranscriberViewModel {
    @MainActor
    func updateHasSpokenInSession() {
        if hasSpokenInSession { return }

        let energyThreshold: Float = 0.001
        let energySpoke = (bufferEnergy.max() ?? 0) > energyThreshold

        if energySpoke ||
            !confirmedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !hypothesisText.isEmpty ||
            !confirmedSegments.isEmpty ||
            !unconfirmedSegments.isEmpty ||
            !confirmedWords.isEmpty ||
            !hypothesisWords.isEmpty {
            hasSpokenInSession = true
        }
    }
}

private extension SpeechTranscriberViewModel {
    private func flushPendingTranscription(graceSeconds: Double) async {
        // Give time for any in-flight transcription to complete
        try? await Task.sleep(nanoseconds: UInt64(graceSeconds * 1_000_000_000))
        
        // Process any remaining audio in the buffer
        if enableEagerDecoding && isTranscribing {
            guard let whisperKit = whisperKit else { return }
            let currentBuffer = whisperKit.audioProcessor.audioSamples
            
            if !currentBuffer.isEmpty {
                print("[Flush] Processing final buffer: \(currentBuffer.count) samples")
                // Process one final time to capture any remaining speech
                try? await transcribeEagerMode(Array(currentBuffer))
            }
        }
        
        await MainActor.run {
            finalizeText()
            updateHasSpokenInSession()
            print("[Flush] Finalized text: '\(confirmedText)'")
        }
    }
}

extension SpeechTranscriberViewModel {
    // Rename original bodies to *_impl before adding these wrappers.
    func transcribeAudioSamples(_ samples: [Float]) async throws -> TranscriptionResult? {
        let result = try await transcribeAudioSamples_impl(samples)
        await MainActor.run {
            if let r = result, (!r.segments.isEmpty || !r.allWords.isEmpty) {
                updateHasSpokenInSession()
            }
        }
        return result
    }
    
    func transcribeEagerMode(_ samples: [Float]) async throws -> TranscriptionResult? {
        let merged = try await transcribeEagerMode_impl(samples)
        await MainActor.run { updateHasSpokenInSession() }
        return merged
    }
}
