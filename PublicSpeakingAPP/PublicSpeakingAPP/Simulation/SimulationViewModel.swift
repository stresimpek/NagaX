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
    
    @Published var errorMessage: String? = nil
    
    let whisperKitVM: SpeechTranscriberViewModel
    let textAnalyzerVM: TextFrequencyAnalyzerViewModel
    let intonationAnalyzerVM: IntonationAnalyzerViewModel
    let tempoVM: TempoViewModel
    
    @Published var evaluationResult: EvaluationModel? = nil
    @Published var isAnalysisComplete: Bool = false
    @Published var whisperModelState: ModelState = .unloaded
    @Published var finalTranscript: String = ""
    
    private let settings: PracticeSettings
    @Published var showNoTranscriptAlert: Bool = false
    
    private var gameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var recordingStartTime: Date?
    private var isEvaluating: Bool = false
    private var didHaveActiveStateThisSession: Bool = false
    
    private var distractionPlayers: [AVAudioPlayer] = []
    
    var formattedTime: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init(
        settings: PracticeSettings, // BARU
        whisperKitVM: SpeechTranscriberViewModel,
        textAnalyzerVM: TextFrequencyAnalyzerViewModel,
        intonationAnalyzerVM: IntonationAnalyzerViewModel,
        tempoVM: TempoViewModel,
//        eyeContactVM: EyeContactViewModel // BARU
    ) {
        self.settings = settings // BARU
        self.whisperKitVM = whisperKitVM
        self.textAnalyzerVM = textAnalyzerVM
        self.intonationAnalyzerVM = intonationAnalyzerVM
        self.tempoVM = tempoVM
//        self.eyeContactVM = eyeContactVM // BARU
        
        self.whisperKitVM.$modelState
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelState)

        self.whisperKitVM.$publishedError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] errorText in
                // Tampilkan error ini di UI kita
                self?.errorMessage = errorText
            }
            .store(in: &cancellables)
        
        setupRecordingObserver()
        setupAnalysisSubscribers()
        setupMoodAggregation()
        
        setupAudioPlayers(named: ["fast-knocking-on-door.mp3", "opening-door.mp3"])
    }
    
    private func setupMoodAggregation() {
        intonationAnalyzerVM.$intonationRating
            .combineLatest(tempoVM.$tempoRating)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (intonation, tempo) in
                guard let self = self else { return }

                self.updateAggregateMood(
                    intonationRating: intonation,
                    tempoRating: tempo
                )
            }
            .store(in: &cancellables)
    }
    
    private func updateAggregateMood(intonationRating: Int, tempoRating: Int) {
        guard isRecording else {
            setTeacherMood(.idle)
            setStudentMoods(.idle)
            return
        }
    
        print("--- Update Mood ---")
        print("Settings Aspects: \(settings.selectedAspects.map { $0.title })")
        print("Incoming Ratings: Intonation=\(intonationRating), Tempo=\(tempoRating)")
        
        var activeRatings: [Int] = []
        
        if settings.selectedAspects.contains(.intonasi) {
            print("Intonation aspect IS selected.")
            activeRatings.append(intonationRating)
        }
        if settings.selectedAspects.contains(.tempo) {
            print("Tempo aspect IS selected.")
            activeRatings.append(tempoRating)
        }
//            if settings.selectedAspects.contains(.fillerWords) {
//                activeRatings.append(fillerRating)
//            }
//            if settings.selectedAspects.contains(.kontakMata) {
//                activeRatings.append(eyeContactRating)
//            }
        
        // Filter rating '0' (N/A atau belum dihitung)
        let validRatings = activeRatings.filter { $0 > 0 }
        print("Valid Ratings for Averaging: \(validRatings)")
        
        // Jika tidak ada data valid (mungkin baru mulai), jangan lakukan apa-apa
        guard !validRatings.isEmpty else {
            setTeacherMood(.idle)
            setStudentMoods(.idle)
            return
        }
        
        // Hitung total dan rata-rata, lalu bulatkan ke bawah
        let totalRating = validRatings.reduce(0, +)
        let averageRating = Double(totalRating) / Double(validRatings.count)
        let finalRating = Int(floor(averageRating)) // Bulatkan ke bawah
        print("Final Aggregate Rating: \(finalRating)")

        // Tentukan mood berdasarkan rating akhir
        switch finalRating {
        case 3:
            setTeacherMood(.happy)
            setStudentMoods(.focus)
        case 2:
            setTeacherMood(.idle)
            setStudentMoods(.idle)
        case 1:
            setTeacherMood(.angry)
            setStudentMoods(.sleep)
        default:
            setTeacherMood(.idle)
            setStudentMoods(.idle)
        }
    print("Setting Mood: Teacher=\(teacherMood), Students=\(studentMoods.first ?? .idle)")
            print("--------------------")
    }


    private func setupRecordingObserver() {
        var prevRec: Bool = false
        var prevTrans: Bool = false

        whisperKitVM.$isRecording
            .combineLatest(whisperKitVM.$isTranscribing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isRec, isTrans) in
                guard let self = self else { return }
                let wasActive = (prevRec || prevTrans)
                let nowActive = (isRec || isTrans)
                if !wasActive && nowActive && self.recordingStartTime == nil {
                    self.recordingStartTime = Date()
                    self.didHaveActiveStateThisSession = true
                    print(">>> startTime SET (rising-edge) at \(self.recordingStartTime!)")
                }
                prevRec = isRec
                prevTrans = isTrans
            }
            .store(in: &cancellables)

        whisperKitVM.$isRecording
            .combineLatest(whisperKitVM.$isTranscribing)
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .scan<(Bool,Bool), (prev:(Bool,Bool), curr:(Bool,Bool))>((prev:(false,false), curr:(false,false))) { acc, curr in
                (prev: acc.curr, curr: curr)
            }
            .sink { [weak self] pair in
                guard let self = self else { return }
                let (prevRec, prevTrans) = pair.prev
                let (isRec, isTrans) = pair.curr
                let justStopped = (prevRec || prevTrans) && (!isRec && !isTrans)
                let stOK = (self.recordingStartTime != nil)
                if justStopped && stOK && self.didHaveActiveStateThisSession && !self.isEvaluating {
                    print(">>> Observer Condition MET for final evaluation.")
                    self.isEvaluating = true
                    self.processEvaluation()
                } else if justStopped {
                    let st = (self.recordingStartTime == nil) ? "nil" : "set"
                    print(">>> Observer Condition FAILED (startTime=\(st), didHaveActive=\(self.didHaveActiveStateThisSession), isEvaluating=\(self.isEvaluating))")
                }
            }
            .store(in: &cancellables)

        whisperKitVM.$isRecording
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: &self.$isRecording)
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
        
        guard settings.distractionLevel > 0 else {
            print("Distraksi dinonaktifkan (Level 0).")
            return
        }
        
        guard !distractionPlayers.isEmpty else { return }
        
        let delayRange: ClosedRange<TimeInterval>
        
        if settings.distractionLevel == 1.0 { // "sedikit"
            delayRange = 30.0...45.0 // Lebih lama (misal: 30-45 detik)
            print("Distraksi Level: Sedikit (delay 30-45s)")
        } else { // Asumsi level 2.0 ("banyak") atau default
            delayRange = 15.0...25.0 // Tetap seperti semula (15-25 detik)
             print("Distraksi Level: Banyak (delay 15-25s)")
        }
        
        let randomDelay = TimeInterval.random(in: delayRange)
        
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
            
            self.playAndScheduleDistraction()
        }
    }
    
    func toggleRecording() {
        self.errorMessage = nil

        guard whisperModelState == .loaded else {
            print("Model belum siap, tidak bisa merekam.")
            self.errorMessage = "Model belum siap, tidak bisa merekam."
            return
        }

        if self.isRecording {
            stopGame()
            whisperKitVM.toggleRecording(shouldLoop: false)
        } else {
            print("Requesting START recording...")
            if self.recordingStartTime == nil {
                self.recordingStartTime = Date()
                self.didHaveActiveStateThisSession = true
                print(">>> Optimistic: startTime SET at \(self.recordingStartTime!)")
            }
            startGame()
            whisperKitVM.toggleRecording(shouldLoop: true)
        }
    }


        private func processEvaluation() {
            print("Memproses evaluasi...")
            guard let start = self.recordingStartTime else {
                   print("processEvaluation called but startTime is nil (already processed?), ignoring.")
                   self.isEvaluating = false
                   return
               }
               self.recordingStartTime = nil
               self.didHaveActiveStateThisSession = false
            
            let finalDuration = whisperKitVM.finalBufferDuration
            
            let finalIntonationStdDev = intonationAnalyzerVM.calculateFinalStandardDeviation()
            
            guard finalDuration > 0 else {
                self.errorMessage = "Tidak ada data audio yang direkam (durasi: \(finalDuration))."
                print("Tidak ada data audio yang direkam (durasi: \(finalDuration))")
                self.isAnalysisComplete = true // Tetap set complete agar UI tahu
                self.isEvaluating = false
                self.recordingStartTime = nil
                return
            }
            
            print("Data Evaluasi:")
            print("- Duration: \(finalDuration)s")
            print("- Tempo WPM: \(tempoVM.wpm)")
            print("- Filler Words: \(textAnalyzerVM.fillerWordCount)")
            print("- Intonation StdDev (Final Full): \(finalIntonationStdDev)")
            
            self.finalTranscript = self.whisperKitVM.confirmedText
            self.evaluationResult = EvaluationViewModel.process(
                tempoVM: self.tempoVM,
                textAnalyzerVM: self.textAnalyzerVM,
                intonationVM: finalIntonationStdDev,
                duration: finalDuration
            )
            
            self.isAnalysisComplete = true
            print("Evaluasi selesai, navigasi ke hasil")
            self.isEvaluating = false        }

    
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
        
        self.isAnalysisComplete = false
        self.evaluationResult = nil
        self.finalTranscript = ""
        self.errorMessage = nil
        self.recordingStartTime  = nil
        self.isEvaluating = false
        self.didHaveActiveStateThisSession = false
        
        tempoVM.clearResults()
        intonationAnalyzerVM.clearResults()
        textAnalyzerVM.clearResults()
        
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
    }
}

