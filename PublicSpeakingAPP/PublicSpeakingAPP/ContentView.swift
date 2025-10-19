//
//  ContentView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

//  For licensing see accompanying LICENSE.md file.
//  Copyright © 2024 Argmax, Inc. All rights reserved.

import SwiftUI
import WhisperKit
import AVFoundation
import CoreML

struct ContentView: View {
    @State private var whisperKit: WhisperKit?
    @State private var isRecording: Bool = false
    @State private var isTranscribing: Bool = false
    @State private var currentText: String = ""
    @State private var currentChunks: [Int: (chunkText: [String], fallbacks: Int)] = [:]
    
    // MARK: Model management
    @State private var modelState: ModelState = .unloaded
    @State private var localModels: [String] = []
    @State private var localModelPath: String = ""
    @State private var availableModels: [String] = []
    @State private var availableLanguages: [String] = []
    
    // Parameters yang ditentukan langsung di code
    private let modelStorage: String = "huggingface/models/argmaxinc/whisperkit-coreml"
    private let selectedModel: String = "openai_whisper-large-v3-v20240930_turbo_632MB"
    private let selectedLanguage: String = "Indonesian"
    private let selectedTask: String = "transcribe"
    private let repoName: String = "argmaxinc/whisperkit-coreml"
    
    // Parameters untuk decoding
    private let enableTimestamps: Bool = true
    private let enablePromptPrefill: Bool = true
    private let enableCachePrefill: Bool = true
    private let enableSpecialCharacters: Bool = false
    private let enableEagerDecoding: Bool = false
    private let enableDecoderPreview: Bool = true
    private let temperatureStart: Double = 0
    private let fallbackCount: Double = 5
    private let compressionCheckWindow: Double = 60
    private let sampleLength: Double = 224
    private let silenceThreshold: Double = 0.3
    private let realtimeDelayInterval: Double = 1
    private let useVAD: Bool = true
    private let tokenConfirmationsNeeded: Double = 2
    private let concurrentWorkerCount: Double = 4
    private let chunkingStrategy: ChunkingStrategy = .vad
    private let encoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    private let decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    
    // MARK: Streaming properties
    @State private var loadingProgressValue: Float = 0.0
    @State private var specializationProgressRatio: Float = 0.7
    @State private var modelLoadingTime: TimeInterval = 0
    @State private var firstTokenTime: TimeInterval = 0
    @State private var pipelineStart: TimeInterval = 0
    @State private var effectiveRealTimeFactor: TimeInterval = 0
    @State private var effectiveSpeedFactor: TimeInterval = 0
    @State private var totalInferenceTime: TimeInterval = 0
    @State private var tokensPerSecond: TimeInterval = 0
    @State private var currentLag: TimeInterval = 0
    @State private var currentFallbacks: Int = 0
    @State private var currentEncodingLoops: Int = 0
    @State private var currentDecodingLoops: Int = 0
    @State private var lastBufferSize: Int = 0
    @State private var lastConfirmedSegmentEndSeconds: Float = 0
    @State private var requiredSegmentsForConfirmation: Int = 4
    @State private var bufferEnergy: [Float] = []
    @State private var bufferSeconds: Double = 0
    @State private var confirmedSegments: [TranscriptionSegment] = []
    @State private var unconfirmedSegments: [TranscriptionSegment] = []
    
    // MARK: Eager mode properties
    @State private var eagerResults: [TranscriptionResult?] = []
    @State private var prevResult: TranscriptionResult?
    @State private var lastAgreedSeconds: Float = 0.0
    @State private var prevWords: [WordTiming] = []
    @State private var lastAgreedWords: [WordTiming] = []
    @State private var confirmedWords: [WordTiming] = []
    @State private var confirmedText: String = ""
    @State private var hypothesisWords: [WordTiming] = []
    @State private var hypothesisText: String = ""
    
    // MARK: UI properties
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var transcribeTask: Task<Void, Never>?
    
    func getComputeOptions() -> ModelComputeOptions {
        return ModelComputeOptions(audioEncoderCompute: encoderComputeUnits, textDecoderCompute: decoderComputeUnits)
    }

    // MARK: Views
    var body: some View {
        VStack(spacing: 0) {
            // Header dengan status model
            headerView
            
            // Area transcript
            transcriptionView
                .frame(maxHeight: .infinity)
            
            // Energy visualization
            if !bufferEnergy.isEmpty {
                energyVisualizationView
                    .frame(height: 40)
            }
            
            // Controls
            controlsView
                .frame(height: 120)
        }
        .padding()
        .onAppear {
            fetchModels()
        }
    }
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(modelState == .loaded ? .green : (modelState == .unloaded ? .red : .yellow))
                        .symbolEffect(.variableColor, isActive: modelState != .loaded && modelState != .unloaded)
                    
                    Text(modelState.description)
                        .font(.headline)
                    
                    if modelState == .loading || modelState == .prewarming {
                        ProgressView(value: loadingProgressValue, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 100)
                        
                        Text(String(format: "%.1f%%", loadingProgressValue * 100))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if modelState == .loaded {
                    HStack(spacing: 16) {
                        Text("RTF: \(effectiveRealTimeFactor.formatted(.number.precision(.fractionLength(3))))")
                        Text("Speed: \(effectiveSpeedFactor.formatted(.number.precision(.fractionLength(1))))x")
                        Text("Tokens: \(tokensPerSecond.formatted(.number.precision(.fractionLength(0))))/s")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if modelState == .unloaded {
                Button {
                    loadModel(selectedModel)
                    modelState = .loading
                } label: {
                    Text("Load Model")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    var transcriptionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if enableEagerDecoding {
                    let startSeconds = eagerResults.first??.segments.first?.start ?? 0
                    let endSeconds = lastAgreedSeconds > 0 ? lastAgreedSeconds : eagerResults.last??.segments.last?.end ?? 0
                    let timestampText = (enableTimestamps && eagerResults.first != nil) ? "[\(String(format: "%.2f", startSeconds)) --> \(String(format: "%.2f", endSeconds))]" : ""
                    
                    Text("\(timestampText) \(Text(confirmedText).fontWeight(.bold))\(Text(hypothesisText).fontWeight(.bold).foregroundColor(.gray))")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    
                    if enableDecoderPreview {
                        Text("\(currentText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(Array(confirmedSegments.enumerated()), id: \.element) { _, segment in
                        let timestampText = enableTimestamps ? "[\(String(format: "%.2f", segment.start)) --> \(String(format: "%.2f", segment.end))]" : ""
                        Text(timestampText + segment.text)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    ForEach(Array(unconfirmedSegments.enumerated()), id: \.element) { _, segment in
                        let timestampText = enableTimestamps ? "[\(String(format: "%.2f", segment.start)) --> \(String(format: "%.2f", segment.end))]" : ""
                        Text(timestampText + segment.text)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    
                    if enableDecoderPreview {
                        Text("\(currentText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if currentText.isEmpty && !isRecording {
                    Text("Tekan tombol record untuk mulai streaming transkripsi...")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    var energyVisualizationView: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 1) {
                let startIndex = max(bufferEnergy.count - 200, 0)
                ForEach(Array(bufferEnergy.enumerated())[startIndex...], id: \.element) { _, energy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 1)
                            .frame(width: 2, height: CGFloat(energy) * 20)
                    }
                    .frame(maxHeight: 20)
                    .background(energy > Float(silenceThreshold) ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                }
            }
        }
        .defaultScrollAnchor(.trailing)
        .frame(height: 24)
        .scrollIndicators(.never)
        .padding(.horizontal)
    }
    
    var controlsView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Encoder: \(currentEncodingLoops)")
                        .font(.caption)
                    Text("Decoder: \(currentDecodingLoops)")
                        .font(.caption)
                }
                
                Spacer()
                
                if isRecording {
                    Text("\(String(format: "%.1f", bufferSeconds)) s")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Button {
                    resetState()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                .disabled(modelState != .loaded)
            }
            
            Button {
                withAnimation {
                    toggleRecording(shouldLoop: true)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .disabled(modelState != .loaded)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: Logic Functions
    
    func resetState() {
        transcribeTask?.cancel()
        transcriptionTask?.cancel()
        isRecording = false
        isTranscribing = false
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

        Task {
            let remoteModelSupport = await WhisperKit.recommendedRemoteModels()
            await MainActor.run {
                for model in remoteModelSupport.supported {
                    if !availableModels.contains(model) {
                        availableModels.append(model)
                    }
                }
            }
        }
    }
    
    func loadModel(_ model: String, redownload: Bool = false) {
        whisperKit = nil
        Task {
            let config = WhisperKitConfig(computeOptions: getComputeOptions(),
                                          verbose: true,
                                          logLevel: .debug,
                                          prewarm: false,
                                          load: false,
                                          download: false)
            whisperKit = try await WhisperKit(config)
            guard let whisperKit = whisperKit else { return }

            var folder: URL?

            if localModels.contains(model) && !redownload {
                folder = URL(fileURLWithPath: localModelPath).appendingPathComponent(model)
            } else {
                folder = try await WhisperKit.download(variant: model, from: repoName, progressCallback: { progress in
                    DispatchQueue.main.async {
                        loadingProgressValue = Float(progress.fractionCompleted) * specializationProgressRatio
                        modelState = .downloading
                    }
                })
            }

            await MainActor.run {
                loadingProgressValue = specializationProgressRatio
                modelState = .downloaded
            }

            if let modelFolder = folder {
                whisperKit.modelFolder = modelFolder

                await MainActor.run {
                    loadingProgressValue = specializationProgressRatio
                    modelState = .prewarming
                }

                let progressBarTask = Task {
                    await updateProgressBar(targetProgress: 0.9, maxTime: 240)
                }

                do {
                    try await whisperKit.prewarmModels()
                    progressBarTask.cancel()
                } catch {
                    print("Error prewarming models, retrying: \(error.localizedDescription)")
                    progressBarTask.cancel()
                    if !redownload {
                        loadModel(model, redownload: true)
                        return
                    } else {
                        modelState = .unloaded
                        return
                    }
                }

                await MainActor.run {
                    loadingProgressValue = specializationProgressRatio + 0.9 * (1 - specializationProgressRatio)
                    modelState = .loading
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
    
    func toggleRecording(shouldLoop: Bool) {
        isRecording.toggle()

        if isRecording {
            resetState()
            startRecording(shouldLoop)
        } else {
            stopRecording(shouldLoop)
        }
    }
    
    func startRecording(_ loop: Bool) {
        if let audioProcessor = whisperKit?.audioProcessor {
            Task(priority: .userInitiated) {
                guard await AudioProcessor.requestRecordPermission() else {
                    print("Microphone access was not granted.")
                    return
                }

                try? audioProcessor.startRecordingLive(inputDeviceID: nil) { _ in
                    DispatchQueue.main.async {
                        bufferEnergy = whisperKit?.audioProcessor.relativeEnergy ?? []
                        bufferSeconds = Double(whisperKit?.audioProcessor.audioSamples.count ?? 0) / Double(WhisperKit.sampleRate)
                    }
                }

                isRecording = true
                isTranscribing = true
                if loop {
                    realtimeLoop()
                }
            }
        }
    }
    
    func stopRecording(_ loop: Bool) {
        isRecording = false
        stopRealtimeTranscription()
        if let audioProcessor = whisperKit?.audioProcessor {
            audioProcessor.stopRecording()
        }

        if !loop {
            transcribeTask = Task {
                isTranscribing = true
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
                finalizeText()
                isTranscribing = false
            }
        }

        finalizeText()
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
    
    // MARK: Streaming Logic
    
    func realtimeLoop() {
        transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer(delayInterval: Float(realtimeDelayInterval))
                } catch {
                    print("Error: \(error.localizedDescription)")
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
                    let numberOfSegmentsToConfirm = segments.count - requiredSegmentsForConfirmation
                    let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
                    let remainingSegments = Array(segments.suffix(requiredSegmentsForConfirmation))

                    if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > lastConfirmedSegmentEndSeconds {
                        lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end
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

        let languageCode = "id"
        let task: DecodingTask = .transcribe
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
                if var currentChunk = currentChunks[chunkId], let previousChunkText = currentChunk.chunkText.last {
                    if progress.text.count >= previousChunkText.count {
                        currentChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
                        updatedChunk = currentChunk
                    } else {
                        if fallbacks == currentChunk.fallbacks {
                            updatedChunk.chunkText = [updatedChunk.chunkText.first ?? "" + progress.text]
                        } else {
                            updatedChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
                            updatedChunk.fallbacks = fallbacks
                        }
                    }
                }

                currentChunks[chunkId] = updatedChunk
                let joinedChunks = currentChunks.sorted { $0.key < $1.key }.flatMap { $0.value.chunkText }.joined(separator: "\n")

                currentText = joinedChunks
                currentFallbacks = fallbacks
                currentDecodingLoops += 1
            }

            let currentTokens = progress.tokens
            let checkWindow = Int(compressionCheckWindow)
            if currentTokens.count > checkWindow {
                let checkTokens: [Int] = currentTokens.suffix(checkWindow)
                let compressionRatio = TextUtilities.compressionRatio(of: checkTokens)
                if compressionRatio > options.compressionRatioThreshold! {
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
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
            confirmedText = "Eager mode requires word timestamps, which are not supported by the current model: \(selectedModel)."
            return nil
        }

        let languageCode = Constants.languages[selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = .transcribe

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
                if progress.text.count < currentText.count {
                    if fallbacks == currentFallbacks {
                    } else {
                        print("Fallback occured: \(fallbacks)")
                    }
                }
                currentText = progress.text
                currentFallbacks = fallbacks
                currentDecodingLoops += 1
            }
            
            let currentTokens = progress.tokens
            let checkWindow = Int(compressionCheckWindow)
            if currentTokens.count > checkWindow {
                let checkTokens: [Int] = currentTokens.suffix(checkWindow)
                let compressionRatio = TextUtilities.compressionRatio(of: checkTokens)
                if compressionRatio > options.compressionRatioThreshold! {
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
                return false
            }

            return nil
        }

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
                    hypothesisWords = result.allWords.filter { $0.start >= lastAgreedSeconds }

                    if let prevResult = prevResult {
                        prevWords = prevResult.allWords.filter { $0.start >= lastAgreedSeconds }
                        let commonPrefix = TranscriptionUtilities.findLongestCommonPrefix(prevWords, hypothesisWords)

                        if commonPrefix.count >= Int(tokenConfirmationsNeeded) {
                            lastAgreedWords = commonPrefix.suffix(Int(tokenConfirmationsNeeded))
                            lastAgreedSeconds = lastAgreedWords.first!.start
                            confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - Int(tokenConfirmationsNeeded)))
                        } else {
                            skipAppend = true
                        }
                    }
                    prevResult = result
                }

                if !skipAppend {
                    eagerResults.append(transcription)
                }
            }

            await MainActor.run {
                let finalWords = confirmedWords.map { $0.word }.joined()
                confirmedText = finalWords

                let lastHypothesis = lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(prevWords, hypothesisWords)
                hypothesisText = lastHypothesis.map { $0.word }.joined()
            }
        } catch {
            print("[EagerMode] Error: \(error)")
            finalizeText()
        }

        let mergedResult = TranscriptionUtilities.mergeTranscriptionResults(eagerResults, confirmedWords: confirmedWords)

        return mergedResult
    }
}

