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
         
        // BARU: Pantau error dari WhisperKit
        self.whisperKitVM.$publishedError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 } // Hanya teruskan jika tidak nil
            .sink { [weak self] errorText in
                // Tampilkan error ini di UI kita
                self?.errorMessage = errorText
            }
            .store(in: &cancellables)
        
        recordingStatus()
        
        setupRecordingObserver()
        setupAnalysisSubscribers()
        
        // BARU: Logika mood terpusat
        setupMoodAggregation()
        
        // DIHAPUS: Subscriber tempo.$tempoLabel dihapus
        // karena sudah ditangani di setupMoodAggregation()
        
        setupAudioPlayers(named: ["fast-knocking-on-door.mp3", "opening-door.mp3"])
    }
    
    private func setupMoodAggregation() {
            // Gabungkan semua publisher rating yang relevan
        intonationAnalyzerVM.$intonationRating
            .combineLatest(tempoVM.$tempoRating)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (intonation, tempo) in
                guard let self = self else { return }
                
                // Panggil fungsi logika baru
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
            setStudentMoods(.focus) // Student juga
        case 2:
            setTeacherMood(.idle) // "flat"
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

//    private func setupRecordingObserver() {
//        whisperKitVM.$isRecording
//            .combineLatest(whisperKitVM.$isTranscribing)
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] (isRec, isTrans) in
//                guard let self = self else { return }
//
//                // Kondisi tetap sama
//                if !isRec && !isTrans && self.recordingStartTime != nil {
//                    print("Recording observer triggered for final evaluation.")
//                    // Cukup panggil processEvaluation. Biarkan dia yang mengelola 'recordingStartTime'.
//                    self.processEvaluation()
//                    // HAPUS BARIS INI: self.recordingStartTime = nil
//                }
//            }
//            .store(in: &cancellables)
//    }
    
    private func setupRecordingObserver() {
            // Simpan state sebelumnya di dalam scope sink
            var previousRecState: Bool? = nil // Awalnya nil
            var previousTransState: Bool? = nil // Awalnya nil

            whisperKitVM.$isRecording
                .combineLatest(whisperKitVM.$isTranscribing)
                .receive(on: DispatchQueue.main)
                // Hapus debounce dulu untuk melihat state mentah
                // .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
                .sink { [weak self] (isRec, isTrans) in
                    guard let self = self else { return }

                    let startTimeStatus = (self.recordingStartTime == nil) ? "nil" : "set"
        

                    // --- KONDISI BARU YANG LEBIH KUAT ---
                    // Cek apakah ini transisi DARI AKTIF KE BERHENTI?
                    // Yaitu, state sebelumnya TIDAK false,false DAN state sekarang ADALAH false,false
                    let justStoppedCompletely = (previousRecState != false || previousTransState != false) && (!isRec && !isTrans)

                    // Hanya panggil evaluasi JIKA:
                    // 1. Transisinya adalah "baru saja berhenti total"
                    // 2. DAN sesi rekaman ini memang sudah dimulai (startTime tidak nil)
                    if justStoppedCompletely && self.recordingStartTime != nil {
                        print(">>> Observer Condition MET for final evaluation (Just Stopped Completely).")
                        self.processEvaluation()
                    } else {
                        var reasons: [String] = []
                        if !justStoppedCompletely { reasons.append("Not a 'Just Stopped Completely' transition") }
                        if self.recordingStartTime == nil { reasons.append("startTime is nil") }
                        // Tambahkan debug jika perlu:
                        if previousRecState == nil { reasons.append("previous state was nil (initial run?)") }
                        print(">>> Observer Condition FAILED: Reasons - \(reasons.joined(separator: ", "))")
                    }

                    // Update state sebelumnya untuk pengecekan berikutnya
                    previousRecState = isRec
                    previousTransState = isTrans
                }
                .store(in: &cancellables)
        }
    
    private func recordingStatus() {
        whisperKitVM.$recordingStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }

                print("[SimulationVM] Received Recording Status: \(newStatus)")

                switch newStatus {
                case .recording:
                    // BARU: Set isRecording jadi true HANYA saat dikonfirmasi
                    if !self.isRecording { // Hanya set jika belum true
                        self.isRecording = true
                        print("[SimulationVM] State -> isRecording = true")
                    }
                    // Set startTime jika belum ada (logika sebelumnya sudah benar)
                    if self.recordingStartTime == nil {
                        self.recordingStartTime = Date()
                        print("[SimulationVM] Recording confirmed STARTED at: \(self.recordingStartTime!)")
                    }
                    
                case .starting:
                    // Saat starting, kita anggap BELUM recording
                    if self.isRecording { // Jika sebelumnya true (jarang terjadi), set false
                         self.isRecording = false
                         print("[SimulationVM] State -> isRecording = false (During Starting)")
                    }
                    // Jangan set startTime di sini
                    
                case .stopping, .stopped:
                    // BARU: Set isRecording jadi false saat berhenti atau sudah berhenti
                    if self.isRecording { // Hanya set jika belum false
                        self.isRecording = false
                        print("[SimulationVM] State -> isRecording = false (Stopped/Stopping)")
                    }
                    // Reset startTime di sini juga aman, sebagai backup jika processEvaluation gagal
                    // self.recordingStartTime = nil // Opsional, karena processEvaluation sudah handle
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
            
            // Schedule next distraction
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

        let shouldStart = (whisperKitVM.recordingStatus == .stopped)

        if shouldStart {
            print("Requesting START recording...")
            startGame()
            whisperKitVM.toggleRecording(shouldLoop: true)
        } else {
            print("Requesting STOP recording...")
            stopGame()
            whisperKitVM.toggleRecording(shouldLoop: false)
        }
    }


        private func processEvaluation() {
            guard !self.isRecording else { /* ... */ return }
            print("Memproses evaluasi...")

            // ---- GUARD BARU: Kunci Sekali Pakai ----
            // 1. Pastikan evaluasi belum pernah dijalankan (cek recordingStartTime)
            guard self.recordingStartTime != nil else {
                 print("processEvaluation called again after completion or during processing, ignoring.")
                 return // Jangan lakukan apa-apa jika sudah nil
            }
            // 2. Jika belum, SEGERA atur ke nil untuk mencegah pemanggilan ganda
            self.recordingStartTime = nil
            // -----------------------------------------

            let finalDuration = whisperKitVM.finalBufferDuration
            
            let finalIntonationStdDev = intonationAnalyzerVM.calculateFinalStandardDeviation()
            
            guard finalDuration > 0 else {
                self.errorMessage = "Tidak ada data audio yang direkam (durasi: \(finalDuration))."
                print("Tidak ada data audio yang direkam (durasi: \(finalDuration))")
                self.isAnalysisComplete = true // Tetap set complete agar UI tahu
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
        
        self.isAnalysisComplete = false
        self.evaluationResult = nil
        self.finalTranscript = ""
        // Reset juga error message lama
        self.errorMessage = nil
        self.recordingStartTime  = nil
        
        whisperKitVM.resetState()
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
        cancellables.removeAll()
    }
}
