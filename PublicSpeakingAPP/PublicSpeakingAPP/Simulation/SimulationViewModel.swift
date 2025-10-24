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
    
    @Published var teacherMood: TeacherMood = .idle
    @Published var studentMoods: [StudentMood] = Array(repeating: .idle, count: 9)
    @Published var timerSeconds: Int = 0
    @Published var isRecording: Bool = false
    
    let whisperKitVM: SpeechTranscriberViewModel
    let textAnalyzerVM: TextFrequencyAnalyzerViewModel
    let intonationAnalyzerVM: IntonationAnalyzerViewModel
    let tempoVM: TempoViewModel
    
    @Published var evaluationResult: EvaluationModel? = nil
    @Published var isAnalysisComplete: Bool = false
    @Published var whisperModelState: ModelState = .unloaded
    @Published var finalTranscript: String = ""
    
    private var gameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var recordingStartTime: Date?
    
    private var distractionPlayers: [AVAudioPlayer] = []
    
    var formattedTime: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init(
        whisperKitVM: SpeechTranscriberViewModel,
        textAnalyzerVM: TextFrequencyAnalyzerViewModel,
        intonationAnalyzerVM: IntonationAnalyzerViewModel,
        tempoVM: TempoViewModel
    ) {
        self.whisperKitVM = whisperKitVM
        self.textAnalyzerVM = textAnalyzerVM
        self.intonationAnalyzerVM = intonationAnalyzerVM
        self.tempoVM = tempoVM
        
        self.whisperKitVM.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelState)
        
        setupRecordingObserver()
        setupAnalysisSubscribers()
        
        tempoVM.$tempoLabel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tempoLabel in
                guard let self = self else { return }
                
                guard self.isRecording else {
                    self.setTeacherMood(.idle)
                    return
                }
                
                switch tempoLabel {
                case "Tempo Ideal":
                    self.setTeacherMood(.happy)
                case "Tempo Lambat", "Tempo Cepat":
                    self.setTeacherMood(.angry)
                default:
                    self.setTeacherMood(.idle)
                }
            }
            .store(in: &cancellables)
        
        setupAudioPlayers(named: ["fast-knocking-on-door.mp3", "opening-door.mp3"])
    }
    
    private func setupRecordingObserver() {
        whisperKitVM.$isRecording
            .combineLatest(whisperKitVM.$isTranscribing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isRec, isTrans) in
                guard let self = self else { return }
                
                if !isRec && !isTrans && self.recordingStartTime != nil {
                    print("Recording selesai, memulai evaluasi...")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.processEvaluation()
                        self.recordingStartTime = nil
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
                    self.textAnalyzerVM.analyze(text: liveText)
//                    self.tempoVM.updateTempo(text: liveText, duration: duration)
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
                    self.textAnalyzerVM.analyze(text: liveText)
//                    self.tempoVM.updateTempo(text: liveText, duration: duration)
                }
            }
            .store(in: &cancellables)
        }
    
    private func setupAudioPlayers(named fileNames: [String]) {
        distractionPlayers.removeAll()
        
        for fullName in fileNames {
            guard let lastDot = fullName.lastIndex(of: ".") else {
                print("Audio Error: Format nama file salah (tidak ada ekstensi): '\(fullName)'.")
                continue
            }
            
            let pathWithoutExtension = String(fullName[..<lastDot])
            let fileExtension = String(fullName[lastDot...].dropFirst())

            guard let fileURL = Bundle.main.url(forResource: pathWithoutExtension, withExtension: fileExtension) else {
                print("Audio Error: File '\(fullName)' (dicari sebagai '\(pathWithoutExtension).\(fileExtension)') tidak ditemukan di bundle.")
                continue
            }
            
            do {
                let player = try AVAudioPlayer(contentsOf: fileURL)
                player.prepareToPlay()
                distractionPlayers.append(player)
                print("Audio Player siap dengan file: \(fullName)")
            } catch {
                print("Audio Error: Gagal memuat player '\(fullName)': \(error.localizedDescription)")
            }
        }
    }
    
    private func playAndScheduleDistraction() {
        guard isRecording else { return }
        
        guard !distractionPlayers.isEmpty else { return }
        
        let randomDelay = TimeInterval.random(in: 15.0...25.0)
        
        print("Audio Distraksi: Dijadwalkan dalam \(String(format: "%.1f", randomDelay)) detik.")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
            guard let self = self else { return }
            
            guard self.isRecording else { return }
            
            let randomPlayer = self.distractionPlayers.randomElement()
            
            if let player = randomPlayer {
                print("Memutar suara: \(player.url?.lastPathComponent ?? "unknown")")
                player.currentTime = 0
                player.play()
            } else {
                print("Audio Distraksi: Gagal memilih player.")
            }
            
            // Schedule next distraction
            self.playAndScheduleDistraction()
        }
    }
    
    func toggleRecording() {
            guard whisperModelState == .loaded else {
                print("Model belum siap, tidak bisa merekam.")
                return
            }
        
            let wasRecording = isRecording
            isRecording.toggle()
            
            if wasRecording {
                print("Menghentikan recording...")
                stopGame()
                whisperKitVM.toggleRecording(shouldLoop: true)
                
            } else {
                print("Memulai recording...")
                startGame()
                isAnalysisComplete = false
                evaluationResult = nil
                finalTranscript = ""
                
                whisperKitVM.toggleRecording(shouldLoop: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.whisperKitVM.isRecording {
                        self.recordingStartTime = Date()
                        print("Recording dimulai pada: \(self.recordingStartTime!)")
                    }
                }
            }
        }
    
    private func processEvaluation() {
        print("Memproses evaluasi...")
        
        guard whisperKitVM.bufferSeconds > 0 else {
            print("Tidak ada data audio yang direkam")
            return
        }
        
        let duration = whisperKitVM.bufferSeconds
        
        print("Data Evaluasi:")
        print("- Duration: \(duration)s")
        print("- Tempo WPM: \(tempoVM.wpm)")
        print("- Filler Words: \(textAnalyzerVM.fillerWordCount)")
        print("- Intonation StdDev: \(intonationAnalyzerVM.standardDeviation)")
        
        self.finalTranscript = self.whisperKitVM.confirmedText
        self.evaluationResult = EvaluationViewModel.process(
            tempoVM: self.tempoVM,
            textAnalyzerVM: self.textAnalyzerVM,
            intonationVM: self.intonationAnalyzerVM,
            duration: duration
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnalysisComplete = true
            print("Evaluasi selesai, navigasi ke hasil")
        }
    }

    
    func setTeacherMood(_ mood: TeacherMood) {
        if self.teacherMood == mood && self.isRecording {
            self.teacherMood = .idle
            DispatchQueue.main.async {
                self.teacherMood = mood
            }
        } else {
            self.teacherMood = mood
        }
    }
    
    func setStudentMoods(_ mood: StudentMood) {
        if self.studentMoods.first == mood && self.isRecording {
            self.studentMoods = Array(repeating: .idle, count: 9)
            DispatchQueue.main.async {
                self.studentMoods = Array(repeating: mood, count: 9)
            }
        } else {
            self.studentMoods = Array(repeating: mood, count: 9)
        }
    }
    
    private func startGame() {
        resetGame()
                self.teacherMood = .idle
        self.studentMoods = Array(repeating: .idle, count: 9)
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateGameLogic()
        }
        playAndScheduleDistraction()
    }
    
    private func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        
        distractionPlayers.forEach { player in
            if player.isPlaying {
                player.stop()
            }
        }
        
        self.teacherMood = .idle
        self.studentMoods = Array(repeating: .idle, count: 9)
        
    }
    
    private func resetGame() {
        timerSeconds = 0
    }
    
    private func updateGameLogic() {
        timerSeconds += 1
    }
    
    func cleanup() {
        gameTimer?.invalidate()
        gameTimer = nil
        cancellables.removeAll()
    }
}
