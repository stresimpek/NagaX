//
//  ContentView.swift
//  testWhisper
//
//  Created by Jordan on 13/10/25.
//
// For licensing see accompanying LICENSE.md file.
// Copyright © 2024 Argmax, Inc. All rights reserved.

// For licensing see accompanying LICENSE.md file.
// Copyright © 2024 Argmax, Inc. All rights reserved.

import SwiftUI
import WhisperKit
import AVFoundation
import CoreML

// SOLUSI 1: Membuat TranscriptionSegment dapat diidentifikasi oleh ForEach
extension TranscriptionSegment: Identifiable {}

struct ContentView: View {
    // MARK: - State Properties
    
    // Core WhisperKit object
    @State private var whisperKit: WhisperKit?
    @State private var modelState: ModelState = .unloaded
    
    // Transcription state
    @State private var isRecording: Bool = false
    @State private var isTranscribing: Bool = false

    // UI & App State
    @State private var appStartTime = Date()
    @State private var loadingProgressValue: Float = 0.0
    
    // Live Transcription Parameters (mengikuti kode asli)
    @State private var selectedModel: String = "openai_whisper-small_216MB" // Model default yang direkomendasikan
    @State private var selectedLanguage: String = "indonesian" // Bisa diganti ke "english", dll.
    @State private var selectedTask: String = "transcribe"
    @State private var enableEagerDecoding: Bool = true // Diaktifkan untuk latensi rendah
    @State private var enableTimestamps: Bool = true
    @State private var silenceThreshold: Double = 0.3
    @State private var realtimeDelayInterval: Double = 1.0 // Latency vs CPU usage trade-off
    @State private var tokenConfirmationsNeeded: Double = 2

    // Buffer & Audio Info
    @State private var bufferSeconds: Double = 0
    
    // Transcription result holders
    // For Standard Streaming
    @State private var confirmedSegments: [TranscriptionSegment] = []
    @State private var unconfirmedSegments: [TranscriptionSegment] = []
    
    // For Eager Streaming
    @State private var confirmedText: String = ""
    @State private var hypothesisText: String = ""
    @State private var prevResult: TranscriptionResult?
    @State private var lastAgreedSeconds: Float = 0.0
    
    // Task management
    @State private var transcriptionTask: Task<Void, Never>?

    // MARK: - Body View
    var body: some View {
        VStack(spacing: 20) {
            Text("Whisper Live Transcribe")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            modelStateView
            
            transcriptionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            controlsView
        }
        .padding()
        .onAppear(perform: loadModel)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var modelStateView: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(modelState == .loaded ? .green : (modelState == .unloaded ? .red : .yellow))
                .symbolEffect(.variableColor, isActive: modelState != .loaded && modelState != .unloaded)
            if modelState == .loading || modelState == .downloading || modelState == .prewarming {
                ProgressView(value: loadingProgressValue)
                    .progressViewStyle(LinearProgressViewStyle())
                Text(String(format: "%.0f%%", loadingProgressValue * 100))
            } else {
                Text(modelState.description)
            }
        }
        .padding(.horizontal)
    }

    private var transcriptionView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if enableEagerDecoding {
                        Text("\(Text(confirmedText).fontWeight(.bold))\(Text(hypothesisText).foregroundColor(.gray))")
                            .id("bottom")
                    } else {
                        ForEach(confirmedSegments) { segment in
                            Text(segment.text)
                                .fontWeight(.bold)
                        }
                        ForEach(unconfirmedSegments) { segment in
                            Text(segment.text)
                                .foregroundColor(.gray)
                        }
                        .id("bottom")
                    }
                    
                    if !isRecording && confirmedText.isEmpty && confirmedSegments.isEmpty {
                         Text("Tekan tombol rekam untuk memulai...")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: confirmedText) { _, _ in proxy.scrollTo("bottom") }
            .onChange(of: hypothesisText) { _, _ in proxy.scrollTo("bottom") }
            .onChange(of: unconfirmedSegments) { _, _ in proxy.scrollTo("bottom") }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 15) {
            Toggle("Eager Mode (Latensi Rendah)", isOn: $enableEagerDecoding)
                .disabled(isRecording)

            Button(action: {
                withAnimation {
                    toggleRecording()
                }
            }) {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundColor(modelState == .loaded ? .red : .gray)
            }
            .disabled(modelState != .loaded)
            
            Text(isRecording ? "Durasi Buffer: \(String(format: "%.1f", bufferSeconds))s" : "Siap Merekam")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Core Logic
    
    private func resetState() {
        isRecording = false
        isTranscribing = false
        if let whisperKit {
            whisperKit.audioProcessor.stopRecording()
        }
        transcriptionTask?.cancel()
        
        confirmedSegments = []
        unconfirmedSegments = []
        confirmedText = ""
        hypothesisText = ""
        prevResult = nil
        lastAgreedSeconds = 0.0
        bufferSeconds = 0
    }
    
    private func loadModel() {
        guard modelState == .unloaded else { return }
        modelState = .loading
        
        Task {
            do {
                // SOLUSI 2: Pisahkan proses download dan inisialisasi
                let modelURL = try await WhisperKit.download(
                    variant: selectedModel,
                    from: "argmaxinc/whisperkit-coreml", // Repositori
                    progressCallback: { progress in
                        DispatchQueue.main.async {
                            self.loadingProgressValue = Float(progress.fractionCompleted)
                            self.modelState = .downloading
                        }
                    }
                )
                
                await MainActor.run { modelState = .prewarming }
                
                whisperKit = try await WhisperKit(modelFolder: modelURL.path, verbose: true, logLevel: .debug)
                
                await MainActor.run {
                    self.modelState = whisperKit?.modelState ?? .unloaded
                    if self.modelState == .loaded {
                        self.loadingProgressValue = 1.0
                    }
                }
            } catch {
                print("Error loading WhisperKit model: \(error.localizedDescription)")
                await MainActor.run { self.modelState = .unloaded }
            }
        }
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            resetState()
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    private func startRecording() {
        // SOLUSI 3: Buka optional `whisperKit` dulu
        guard let whisperKit = whisperKit else { return }
        Task(priority: .userInitiated) {
            guard await AudioProcessor.requestRecordPermission() else {
                print("Microphone access was not granted.")
                await MainActor.run { isRecording = false }
                return
            }
            
            try? whisperKit.audioProcessor.startRecordingLive { _ in
                DispatchQueue.main.async {
                    bufferSeconds = Double(whisperKit.audioProcessor.audioSamples.count) / Double(WhisperKit.sampleRate)
                }
            }
            
            await MainActor.run {
                isRecording = true
                isTranscribing = true
            }
            realtimeLoop()
        }
    }

    private func stopRecording() {
        if let whisperKit {
            whisperKit.audioProcessor.stopRecording()
        }
        transcriptionTask?.cancel()
        
        Task {
            await MainActor.run {
                isRecording = false
                isTranscribing = false
                
                if enableEagerDecoding {
                    confirmedText += hypothesisText
                    hypothesisText = ""
                } else {
                    confirmedSegments.append(contentsOf: unconfirmedSegments)
                    unconfirmedSegments = []
                }
            }
        }
    }

    private func realtimeLoop() {
        transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer()
                    try await Task.sleep(for: .seconds(realtimeDelayInterval))
                } catch is CancellationError {
                    print("Transcription task cancelled.")
                    break
                } catch {
                    print("Error during transcription loop: \(error.localizedDescription)")
                    break
                }
            }
        }
    }
    
    private func transcribeCurrentBuffer() async throws {
        // SOLUSI 3: Buka optional `whisperKit` dulu
        guard let whisperKit = whisperKit else { return }

        let currentBuffer = whisperKit.audioProcessor.audioSamples
        guard !currentBuffer.isEmpty else {
            return
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
    }
    
    private func transcribeAudioSamples(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }
        
        let languageCode = Constants.languages[selectedLanguage, default: "id"]
        let options = DecodingOptions(
            task: selectedTask == "transcribe" ? .transcribe : .translate,
            language: languageCode,
            withoutTimestamps: !enableTimestamps
        )
        
        let transcription = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        // SOLUSI 4: Hapus `?` karena `transcription` bukan optional
        return transcription.first
    }

    private func transcribeEagerMode(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }
        
        let languageCode = Constants.languages[selectedLanguage, default: "id"]
        let options = DecodingOptions(
            task: selectedTask == "transcribe" ? .transcribe : .translate,
            language: languageCode,
            wordTimestamps: true,
            clipTimestamps: [lastAgreedSeconds]
        )
        
        let transcriptionResults = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        
        // SOLUSI 4: Hapus `?` karena `transcriptionResults` bukan optional
        guard let transcription = transcriptionResults.first else {
            return nil
        }
        
        await MainActor.run {
            let newWords = transcription.allWords.filter { $0.start >= self.lastAgreedSeconds }
            
            if let prevResult = self.prevResult {
                let prevWords = prevResult.allWords.filter { $0.start >= self.lastAgreedSeconds }
                let commonPrefix = TranscriptionUtilities.findLongestCommonPrefix(prevWords, newWords)
                
                if commonPrefix.count >= Int(tokenConfirmationsNeeded) {
                    let wordsToConfirm = commonPrefix.prefix(commonPrefix.count - Int(tokenConfirmationsNeeded))
                    if !wordsToConfirm.isEmpty {
                        self.confirmedText += wordsToConfirm.map { $0.word }.joined()
                        if let lastAgreedWord = wordsToConfirm.last {
                            self.lastAgreedSeconds = lastAgreedWord.end
                        }
                    }
                }
            }
            
            // Recalculate hypothesis from the last confirmed point
            let hypothesisWords = transcription.allWords.filter { $0.start >= self.lastAgreedSeconds }
            self.hypothesisText = hypothesisWords.map { $0.word }.joined()
            self.prevResult = transcription
        }
        
        return transcription
    }
}

#Preview {
    ContentView()
}
