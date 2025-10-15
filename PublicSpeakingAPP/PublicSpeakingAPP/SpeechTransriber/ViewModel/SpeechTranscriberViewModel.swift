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
    // ... (properti yang sudah ada seperti @Published var transcript) ...
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentLocaleIdentifier: String = "id_ID"

    // MARK: - Tambahkan properti untuk Analyzer VM
    weak var textAnalyzerVM: TextFrequencyAnalyzerViewModel?
    weak var intonationAnalyzerVM: IntonationAnalyzerViewModel?

    var canRecord: Bool {
        authorizationStatus == .authorized
    }
    
    // ... (sisa properti speech & audio) ...
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "id_ID"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioSession = AVAudioSession.sharedInstance()
    private var inputNode: AVAudioInputNode? { audioEngine.inputNode }
    
    override init() {
        super.init()
        observeInterruptions()
    }
    
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

        // ... (kode guard check yang sudah ada) ...
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

        stopLiveTranscription(resetTranscript: true)
        
        // MARK: - Bersihkan hasil analisis sebelumnya
        textAnalyzerVM?.clearResults()
        intonationAnalyzerVM?.clearResults()

        // ... (kode setup audio session yang sudah ada) ...
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't configure the audio session: \(error.localizedDescription)"
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            req.requiresOnDeviceRecognition = false
        }
        recognitionRequest = req

        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                if result.isFinal {
                    // MARK: - PANGGIL ANALISIS DI SINI!
                    print("\n\n✅ Transcription Finalized. Starting analysis...")
                    self.textAnalyzerVM?.analyze(text: self.transcript)
                    
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

        // ... (sisa kode startLiveTranscription) ...
        guard let inputNode = inputNode else {
            errorMessage = "Audio input not available."
            return
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.intonationAnalyzerVM?.analyze(buffer: buffer)
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
    
    // ... (sisa kode di SpeechTranscriberViewModel) ...
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
                Task { @MainActor in
                    self.stopLiveTranscription()
                }
            }
        }
    }
}
