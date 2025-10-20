//
//  SpeechTranscriberView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import Foundation
import SwiftUI
import AVFoundation
import WhisperKit
import Combine

@MainActor
final class SpeechTranscriberViewModel: ObservableObject {
    // Core WhisperKit object
    @Published var whisperKit: WhisperKit?
    @Published var modelState: ModelState = .unloaded
    
    // Transcription state
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    
    // UI & App State
    @Published var appStartTime = Date()
    @Published var loadingProgressValue: Float = 0.0
    
    // Live Transcription Parameters
    @Published var selectedModel: String = "openai_whisper-small_216MB"
    @Published var selectedLanguage: String = "indonesian"
    @Published var selectedTask: String = "transcribe"
    @Published var enableEagerDecoding: Bool = true
    @Published var enableTimestamps: Bool = true
    @Published var silenceThreshold: Double = 0.3
    @Published var realtimeDelayInterval: Double = 1.0
    @Published var tokenConfirmationsNeeded: Double = 2
    
    // Buffer & Audio Info
    @Published var bufferSeconds: Double = 0
    
    // Transcription result holders
    @Published var confirmedSegments: [TranscriptionSegment] = []
    @Published var unconfirmedSegments: [TranscriptionSegment] = []
    
    // For Eager Streaming
    @Published var confirmedText: String = ""
    @Published var hypothesisText: String = ""
    @Published var prevResult: TranscriptionResult?
    @Published var lastAgreedSeconds: Float = 0.0
    
    // Task management
    @Published var transcriptionTask: Task<Void, Never>?
    
    // Analyzer links
    weak var textAnalyzerVM: TextFrequencyAnalyzerViewModel?
    weak var intonationAnalyzerVM: IntonationAnalyzerViewModel?
    weak var tempoVM: TempoViewModel?
    
    private var analyzerLastSampleIndex: Int = 0
    
    // MARK: - Binding helper agar UI butuh perubahan minimal
    func binding<T>(_ keyPath: ReferenceWritableKeyPath<SpeechTranscriberViewModel, T>) -> Binding<T> {
        Binding(get: { self[keyPath: keyPath] },
                set: { self[keyPath: keyPath] = $0 })
    }
    
    // MARK: - Public API (panggil dari View)
    func onAppear() {
        loadModel()
    }
    
    func resetState() {
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
        
        analyzerLastSampleIndex = 0
        
        textAnalyzerVM?.clearResults()
        intonationAnalyzerVM?.clearResults()
        tempoVM?.clearResults()
    }
    
    func loadModel() {
        guard modelState == .unloaded else { return }
        modelState = .loading
        
        Task {
            do {
                let modelURL = try await WhisperKit.download(
                    variant: selectedModel,
                    from: "argmaxinc/whisperkit-coreml",
                    progressCallback: { progress in
                        DispatchQueue.main.async {
                            self.loadingProgressValue = Float(progress.fractionCompleted)
                            self.modelState = .downloading
                        }
                    }
                )
                
                await MainActor.run { self.modelState = .prewarming }
                
                self.whisperKit = try await WhisperKit(modelFolder: modelURL.path, verbose: true, logLevel: .debug)
                
                await MainActor.run {
                    self.modelState = self.whisperKit?.modelState ?? .unloaded
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
    
    func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            resetState()
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func startRecording() {
        guard let whisperKit = whisperKit else { return }
        Task(priority: .userInitiated) {
            guard await AudioProcessor.requestRecordPermission() else {
                print("Microphone access was not granted.")
                await MainActor.run { self.isRecording = false }
                return
            }
            
            try? whisperKit.audioProcessor.startRecordingLive { _ in
                DispatchQueue.main.async {
                    self.bufferSeconds = Double(whisperKit.audioProcessor.audioSamples.count) / Double(WhisperKit.sampleRate)
                }
            }
            
            await MainActor.run {
                self.isRecording = true
                self.isTranscribing = true
            }
            
            self.realtimeLoop()
        }
    }
    
    func stopRecording() {
        if let whisperKit {
            whisperKit.audioProcessor.stopRecording()
        }
        transcriptionTask?.cancel()
        
        Task {
            await MainActor.run {
                self.isRecording = false
                self.isTranscribing = false
                
                if self.enableEagerDecoding {
                    self.confirmedText += self.hypothesisText
                    self.hypothesisText = ""
                } else {
                    self.confirmedSegments.append(contentsOf: self.unconfirmedSegments)
                    self.unconfirmedSegments = []
                }
            }
        }
        
        analyzerLastSampleIndex = 0
    }
    
    func realtimeLoop() {
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
    
    // MARK: - Helper: convert float samples -> AVAudioPCMBuffer
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
                dst.assign(from: src.baseAddress!, count: samples.count)
            }
        }
        return buffer
    }
    
    
    func transcribeCurrentBuffer() async throws {
        guard let whisperKit = whisperKit else { return }
        
        let currentBuffer = whisperKit.audioProcessor.audioSamples
        guard !currentBuffer.isEmpty else { return }
        
        let newCount = currentBuffer.count
        if newCount > analyzerLastSampleIndex {
            let delta = Array(currentBuffer[analyzerLastSampleIndex..<newCount])
            analyzerLastSampleIndex = newCount
            if let pcm = makePCMBuffer(from: delta, sampleRate: Double(WhisperKit.sampleRate)) {
                intonationAnalyzerVM?.analyze(buffer: pcm)
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
    }
    
    func transcribeAudioSamples(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }
        
        let languageCode = Constants.languages[selectedLanguage, default: "id"]
        let options = DecodingOptions(
            task: selectedTask == "transcribe" ? .transcribe : .translate,
            language: languageCode,
            withoutTimestamps: !enableTimestamps
        )
        
        let transcription = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        return transcription.first
    }
    
    func transcribeEagerMode(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }
        
        let languageCode = Constants.languages[selectedLanguage, default: "id"]
        let options = DecodingOptions(
            task: selectedTask == "transcribe" ? .transcribe : .translate,
            language: languageCode,
            wordTimestamps: true,
            clipTimestamps: [lastAgreedSeconds]
        )
        
        let transcriptionResults = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        guard let transcription = transcriptionResults.first else { return nil }
        
        await MainActor.run {
            let newWords = transcription.allWords.filter { $0.start >= self.lastAgreedSeconds }
            
            if let prevResult = self.prevResult {
                let prevWords = prevResult.allWords.filter { $0.start >= self.lastAgreedSeconds }
                let commonPrefix = TranscriptionUtilities.findLongestCommonPrefix(prevWords, newWords)
                
                if commonPrefix.count >= Int(self.tokenConfirmationsNeeded) {
                    let wordsToConfirm = commonPrefix.prefix(commonPrefix.count - Int(self.tokenConfirmationsNeeded))
                    if !wordsToConfirm.isEmpty {
                        self.confirmedText += wordsToConfirm.map { $0.word }.joined()
                        if let lastAgreedWord = wordsToConfirm.last {
                            self.lastAgreedSeconds = lastAgreedWord.end
                        }
                    }
                }
            }
            
            // Recalc hypothesis
            let hypothesisWords = transcription.allWords.filter { $0.start >= self.lastAgreedSeconds }
            self.hypothesisText = hypothesisWords.map { $0.word }.joined()
            self.prevResult = transcription
        }
        
        return transcription
    }
}
