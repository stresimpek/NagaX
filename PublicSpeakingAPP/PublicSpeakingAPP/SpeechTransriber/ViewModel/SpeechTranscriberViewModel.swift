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
    case stopping // Opsional, jika perlu
}

@MainActor
final class SpeechTranscriberViewModel: ObservableObject {
    // MARK: - Core Properties
    @Published var whisperKit: WhisperKit?
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var recordingStatus: RecordingStatus = .stopped
    @Published var appStartTime = Date()
    @Published var transcriptionTask: Task<Void, Never>?
    @Published var transcribeTask: Task<Void, Never>?

    // MARK: - Model Management
    @Published var modelState: ModelState = .unloaded
    @Published var modelStorage: String = "huggingface/models/argmaxinc/whisperkit-coreml"
    @Published var localModels: [String] = []
    @Published var localModelPath: String = ""
    @Published var availableModels: [String] = []
    @Published var availableLanguages: [String] = []
    @Published var disabledModels: [String] = WhisperKit.recommendedModels().disabled
    @Published var loadingProgressValue: Float = 0.0
    @Published var specializationProgressRatio: Float = 0.7

    // MARK: - Transcription Settings
    @Published var selectedModel: String = "openai_whisper-small_216MB"
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
    @Published var silenceThreshold: Double = 0.3
    @Published var realtimeDelayInterval: Double = 1.0
    @Published var useVAD: Bool = true
    @Published var tokenConfirmationsNeeded: Double = 2
    @Published var concurrentWorkerCount: Double = 4
    @Published var chunkingStrategy: ChunkingStrategy = .vad
    @Published var encoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    @Published var decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine

    // MARK: - Transcription State & Stats
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

    // MARK: - Eager Mode Properties
    @Published var eagerResults: [TranscriptionResult?] = []
    @Published var prevResult: TranscriptionResult?
    @Published var lastAgreedSeconds: Float = 0.0
    @Published var prevWords: [WordTiming] = []
    @Published var lastAgreedWords: [WordTiming] = []
    @Published var confirmedWords: [WordTiming] = []
    @Published var confirmedText: String = ""
    @Published var hypothesisWords: [WordTiming] = []
    @Published var hypothesisText: String = ""
    
    // MARK: - Analyzer Links (DITAMBAHKAN KEMBALI)
    weak var textAnalyzerVM: TextFrequencyAnalyzerViewModel?
    weak var intonationAnalyzerVM: IntonationAnalyzerViewModel?
    weak var tempoVM: TempoViewModel?
    
    private var analyzerLastSampleIndex: Int = 0
    
    @Published var publishedError: String? = nil
    
    func binding<T>(_ keyPath: ReferenceWritableKeyPath<SpeechTranscriberViewModel, T>) -> Binding<T> {
        Binding(get: { self[keyPath: keyPath] },
                set: { self[keyPath: keyPath] = $0 })
    }
    // -------------------------------------
    
    // MARK: - Public API (panggil dari View)

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

    func resetState() {
        transcribeTask?.cancel()
        transcriptionTask?.cancel()
        isRecording = false
        isTranscribing = false
        recordingStatus = .stopped
        whisperKit?.audioProcessor.stopRecording()
        currentText = ""
        currentChunks = [:]

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
        
        analyzerLastSampleIndex = 0
        textAnalyzerVM?.clearResults()
        intonationAnalyzerVM?.clearResults()
        tempoVM?.clearResults()
    }

    // MARK: - Model Management Logic
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
    
    // MARK: - Recording Logic
    func toggleRecording(shouldLoop: Bool) {
//        isRecording.toggle()

        if isRecording {
            print("[SpeechTranscriber] toggleRecording -> STOPPING")
            isRecording = false // Set internal state
            stopRecording(shouldLoop)
        } else {
            print("[SpeechTranscriber] toggleRecording -> STARTING")
            resetState() // Bersihkan state lama SEBELUM mulai
            
            startRecording(shouldLoop)
        }
    }

    func startRecording(_ loop: Bool) {
        guard let whisperKit = whisperKit else { return }
        
        self.recordingStatus = .starting
        
        Task(priority: .userInitiated) {
            guard await AudioProcessor.requestRecordPermission() else {
                print("Microphone access was not granted.")
                self.publishedError = "Izin mikrofon ditolak. Mohon aktifkan di Pengaturan."
                await MainActor.run {
                    self.isRecording = false
                    self.recordingStatus = .stopped
                }
                return
            }

            var deviceId: DeviceID?
            
            do {
                try whisperKit.audioProcessor.startRecordingLive(inputDeviceID: deviceId) { _ in
                    DispatchQueue.main.async {
                        self.bufferEnergy = whisperKit.audioProcessor.relativeEnergy
                        self.bufferSeconds = Double(whisperKit.audioProcessor.audioSamples.count) / Double(WhisperKit.sampleRate)
                    }
                }

                await MainActor.run {
                    isRecording = true
                    isTranscribing = true
                    recordingStatus = .recording
                }
                
                if loop {
                    realtimeLoop()
                }
            } catch {
                print("❌ Error starting audio recording: \(error.localizedDescription)")
                self.publishedError = "Gagal memulai perekaman audio."
                await MainActor.run {
                    isRecording = false
                    isTranscribing = false
                    recordingStatus = .stopped
                    print("[SpeechTranscriber] Status -> .stopped (Start Failed)")
                }
            }
        }
        
    }

    func stopRecording(_ loop: Bool) {
        isRecording = false
        self.recordingStatus = .stopping
        
        if let audioProcessor = whisperKit?.audioProcessor {
            audioProcessor.stopRecording()
        }
        
        if loop {
            stopRealtimeTranscription()
            finalizeText()
        } else {
            transcriptionTask?.cancel()
            
            transcribeTask = Task {
                await MainActor.run { isTranscribing = true }
                
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    print("Error pada transkripsi akhir: \(error.localizedDescription)")
                }
                finalizeText()

                await MainActor.run {
                    isTranscribing = false
                }
            }
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 detik
            await MainActor.run {
                if !self.isTranscribing { // Hanya set stopped jika transkripsi benar2 selesai
                    self.recordingStatus = .stopped
                    print("[SpeechTranscriber] Status -> .stopped")
                }
            }
        }
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
            }
        }
    }
    
    // MARK: - Transcription Logic

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
                if currentText == "" {
                    currentText = "Waiting for speech..."
                }
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
                    if currentText == "" {
                        currentText = "Waiting for speech..."
                    }
                }
                try await Task.sleep(nanoseconds: 100_000_000)
                return
            }
        }

        lastBufferSize = currentBuffer.count

        if enableEagerDecoding {
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
                guard let segments = transcription?.segments else {
                    return
                }

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
                    let numberOfSegmentsToConfirm = segments.count - requiredSegmentsForConfirmation
                    let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
                    let remainingSegments = Array(segments.suffix(requiredSegmentsForConfirmation))

                    if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > lastConfirmedSegmentEndSeconds {
                        lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end
                        print("Last confirmed segment end: \(lastConfirmedSegmentEndSeconds)")

                        for segment in confirmedSegmentsArray {
                            if !confirmedSegments.contains(segment: segment) {
                                confirmedSegments.append(segment)
                            }
                        }
                    }
                    unconfirmedSegments = remainingSegments
                } else {
                    unconfirmedSegments = segments
                }
            }
        }
    }

    func transcribeAudioSamples(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        let languageCode = Constants.languages[selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = selectedTask == "transcribe" ? .transcribe : .translate
        let seekClip: [Float] = [lastConfirmedSegmentEndSeconds]

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
            clipTimestamps: seekClip,
            concurrentWorkerCount: Int(concurrentWorkerCount),
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

    func transcribeEagerMode(_ samples: [Float]) async throws -> TranscriptionResult? {
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
                            print("[EAndaEagerMode] Found new last agreed word \"\(self.lastAgreedWords.first!.word)\" at \(self.lastAgreedSeconds) seconds")

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
                
                let allCurrentWords = self.confirmedWords + lastHypothesis
                let totalDuration = Double(samples.count) / Double(WhisperKit.sampleRate)

                if let tempoVM = self.tempoVM {
                    tempoVM.updateTempo(from: allCurrentWords, totalDuration: totalDuration)
                }
                
                textAnalyzerVM?.analyze(text: self.confirmedText + self.hypothesisText)
            }
        } catch {
            print("[EagerMode] Error: \(error)")
            finalizeText()
        }

        let mergedResult = TranscriptionUtilities.mergeTranscriptionResults(eagerResults, confirmedWords: confirmedWords)
        return mergedResult
    }
    
    // MARK: - Helper: convert float samples -> AVAudioPCMBuffer (DITAMBAHKAN KEMBALI)
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
                // Gunakan totalDuration di sini juga
                intonationAnalyzerVM?.analyze(buffer: pcm, currentTime: totalDuration)
            }
        }
        
        let result: TranscriptionResult?
        if enableEagerDecoding {
            result = try await transcribeEagerMode(Array(currentBuffer))
        } else {
            result = try await transcribeAudioSamples(Array(currentBuffer))
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
            }
        }
        
        if let allWords = result?.allWords, let tempoVM = self.tempoVM {
            let totalDuration = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
            
            tempoVM.updateTempo(from: allWords, totalDuration: totalDuration)
        }
    }
}
