//
//  SpeechTranscriberViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class SpeechTranscriberViewModel: NSObject, ObservableObject {
    // Published state for the UI
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentLocaleIdentifier: String = "id_ID"
    
    @Published var generatedQuestions: [String] = []
    @Published var isGeneratingQuestions: Bool = false
    @Published var questionGenerationError: String?
    
    @Published var SentenceAnalysis: SentenceAnalysisResponse?
    @Published var isAnalyzingSentence: Bool = false
    @Published var SentenceAnalysisError: String?

    private let mistralService: MistralAIService

    init(mistralAPIKey: String = "DCzL0PebPbW8L4PMOXcipen5c8f5irFP") {
        self.mistralService = MistralAIService(apiKey: mistralAPIKey)
        super.init()
        observeInterruptions()
    }

    func generateQuestionsFromTranscript() async {
        guard !transcript.isEmpty else {
            questionGenerationError = "Transcript is empty. Record something first."
            return
        }
        
        isGeneratingQuestions = true
        questionGenerationError = nil
        
        do {
            let questions = try await mistralService.generateQuestions(from: transcript)
            generatedQuestions = questions
        } catch {
            questionGenerationError = "Failed to generate questions: \(error.localizedDescription)"
        }
        
        isGeneratingQuestions = false
    }
    
    func analyzeTranscriptSentence() async {
        guard !transcript.isEmpty else {
            SentenceAnalysisError = "Transcript is empty. Record something first."
            return
        }
        
        isAnalyzingSentence = true
        SentenceAnalysisError = nil
        SentenceAnalysis = nil // Hapus hasil lama
        
        do {
            let analysis = try await mistralService.analyzeSentence(from: transcript)
            self.SentenceAnalysis = analysis
        } catch {
            SentenceAnalysisError = "Failed to analyze Sentence: \(error.localizedDescription)"
        }
        
        isAnalyzingSentence = false
    }
   
    func resetSentenceAnalysis() {
        SentenceAnalysis = nil
        SentenceAnalysisError = nil
    }

    var canRecord: Bool {
        authorizationStatus == .authorized
    }

    // Speech & audio
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "id_ID"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let audioSession = AVAudioSession.sharedInstance()
    private var inputNode: AVAudioInputNode? { audioEngine.inputNode }

   

    // MARK: - Locale
    func setLocale(_ identifier: String) {
        currentLocaleIdentifier = identifier
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
    }

    // MARK: - Authorization
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
                if status != .authorized {
                    self?.errorMessage = "Speech recognition not authorized. Please enable it in Settings."
                } else {
                    self?.errorMessage = nil
                }
            }
        }
    }

    // MARK: - Live Transcription
    func startLiveTranscription() {
        guard !isRecording else { return }

        // Ensure recognizer is available
        guard let recognizer = speechRecognizer else {
            errorMessage = "Recognizer is not supported for the selected locale."
            return
        }
        guard recognizer.isAvailable else {
            errorMessage = "Recognizer is not available right now."
            return
        }
        guard authorizationStatus == .authorized else {
            errorMessage = "Permission required. Please allow Speech Recognition & Microphone."
            requestAuthorization()
            return
        }

        // Reset previous
        stopLiveTranscription(resetTranscript: true)

        do {
            // Configure audio session for recording
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't configure the audio session: \(error.localizedDescription)"
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // (Opsional) on-device kalau tersedia
        if #available(iOS 13.0, *) {
            req.requiresOnDeviceRecognition = false
        }
        recognitionRequest = req

        // Buat task pengenalan
        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                if result.isFinal {
                    self.finishAudioSession()
                    self.isRecording = false
                }
            }

            if let error = error {
                self.errorMessage = error.localizedDescription
                self.finishAudioSession()
                self.isRecording = false
            }
        }

        // Tap audio input
        guard let inputNode = inputNode else {
            errorMessage = "Audio input not available."
            return
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0) // pastikan bersih
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Audio Engine couldn't start: \(error.localizedDescription)"
            stopLiveTranscription()
        }
    }

    func stopLiveTranscription(resetTranscript: Bool = false) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        inputNode?.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionTask = nil
        recognitionRequest = nil

        finishAudioSession()
        isRecording = false
        if resetTranscript { transcript = "" }
    }

    private func finishAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // ignore
        }
    }

    // MARK: - File Transcription
    func transcribeFile(url: URL) {
        guard let recognizer = speechRecognizer else {
            errorMessage = "Recognizer is not supported for the selected locale."
            return
        }
        guard recognizer.isAvailable else {
            errorMessage = "Recognizer is not available right now."
            return
        }

        transcript = ""
        errorMessage = nil

        // Pastikan sesi audio non-aktif agar tidak bentrok
        stopLiveTranscription()

        let request = SFSpeechURLRecognitionRequest(url: url)
        recognitionTask?.cancel()
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
            Task { @MainActor in
                guard let self else { return }
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Interruptions
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            guard let info = notif.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

            if type == .began {
                // panggilan telpon dll.
                Task { @MainActor in
                    self.stopLiveTranscription()
                }
            }
        }
    }
}
