//
//  FillerWordTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 03/11/25.
//
//  Updated by Gemini on 04/11/25 with Jumper, Timestamps, and Layout Fixes.
//

import SwiftUI
import WhisperKit
import NaturalLanguage
import AVFoundation // Pastikan ini ada

// Tipe data untuk menyimpan info halaman/card
fileprivate struct TranscriptPage: Identifiable {
    let id = UUID()
    let attributedString: AttributedString
    let startTime: TimeInterval
    let endTime: TimeInterval
}

// Tipe data untuk menyimpan hasil pemetaan jumper
fileprivate struct FillerMaps {
    let totalCount: Int
    let fillerIndexToPageIndex: [Int: Int] // [GlobalFWIndex: PageIndex]
    let pageIndexToFillerIndices: [Int: [Int]] // [PageIndex: [GlobalFWIndex]]
}

struct FillerWordTranscriptView: View {
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject var fillerWordVM: FillerWordViewModel
    
    let result: EvaluationModel
    let fullTranscript: String
    
    // State untuk Paginasi
    @State private var pages: [TranscriptPage] = []
    
    // State untuk Swipe (halaman yang terlihat)
    @State private var currentPageIndex: Int = 0
    
    // State untuk Audio (halaman yang diputar)
    @State private var isPlayingPageID: UUID?
    @State private var player: AVPlayer?
    @State private var timeObserverToken: Any?
    @State private var playbackProgress: Double = 0.0
    
    // --- BARU: State untuk Jumper ---
    @State private var totalFillerWordCount: Int = 0
    @State private var currentFillerWordIndex: Int = 1 // 1-based index
    @State private var fillerIndexToPageIndex: [Int: Int] = [:]
    @State private var pageIndexToFillerIndices: [Int: [Int]] = [:]

    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transkrip Kata Pengisi (Total: \(result.fillerWordTotalCount))")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Gunakan $currentPageIndex untuk selection agar swipe berfungsi
            TabView(selection: $currentPageIndex) {
                if pages.isEmpty {
                    Text("Tidak ada kata pengisi yang terdeteksi. Kerja bagus!")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    // Loop menggunakan INDEKS
                    ForEach(pages.indices, id: \.self) { index in
                        let page = pages[index] // Ambil halaman saat ini
                        
                        VStack(spacing: 0) {
                            
                            // --- BARU: Header Card (Timestamp & Jumper) ---
                            HStack {
                                // Kiri Atas: Timestamp
                                Text(formatTimestamp(page.startTime, page.endTime))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)

                                Spacer()

                                // Kanan Atas: Jumper
                                HStack(spacing: 8) {
                                    Button(action: { jumpToFillerWord(globalIndex: currentFillerWordIndex - 1) }) {
                                        Image(systemName: "chevron.left")
                                    }
                                    .disabled(currentFillerWordIndex <= 1)
                                    
                                    Text("\(currentFillerWordIndex) / \(totalFillerWordCount) kata")
                                        .font(.caption.monospacedDigit().bold())
                                    
                                    Button(action: { jumpToFillerWord(globalIndex: currentFillerWordIndex + 1) }) {
                                        Image(systemName: "chevron.right")
                                    }
                                    .disabled(currentFillerWordIndex >= totalFillerWordCount)
                                }
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            // --- AKHIR HEADER ---
                            
                            // Teks Transkrip
                            Text(page.attributedString)
                                .font(.system(.body, design: .serif))
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                                .fixedSize(horizontal: false, vertical: true) // <-- PERBAIKAN TEKS TERPOTONG
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            
                            Spacer(minLength: 10) // Pendorong ke bawah
                            
                            // --- Kontrol Audio di Bawah ---
                            HStack(spacing: 12) {
                                // Tombol Play
                                Button(action: {
                                    if let url = whisperKitVM.savedRecordingURL {
                                        playSegment(url: url, page: page)
                                    } else {
                                        print("Gagal memutar: URL rekaman tidak ditemukan.")
                                    }
                                }) {
                                    Image(systemName: isPlayingPageID == page.id ? "stop.circle.fill" : "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 44, height: 44)
                                }
                                
                                // Progress Bar
                                ProgressView(value: isPlayingPageID == page.id ? playbackProgress : 0.0)
                                    .tint(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                        .tag(index) // Tag harus menggunakan INDEKS
                    }
                }
            }
            .frame(minHeight: 150) // Tinggi minimal
            .tabViewStyle(.page(indexDisplayMode: .never)) // Untuk swipe
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // Hentikan audio saat user swipe
            .onChange(of: currentPageIndex) { newPageIndex in
                 stopPlayback()
                 
                 // Update Jumper agar sesuai dengan halaman yang di-swipe
                 if let fillerIndicesOnPage = pageIndexToFillerIndices[newPageIndex],
                    let firstFillerIndex = fillerIndicesOnPage.first {
                     self.currentFillerWordIndex = firstFillerIndex
                 }
            }
        }
        .onAppear {
            // Bangun halaman dan peta jumper
            let (pages, maps) = buildPagesAndMaps()
            self.pages = pages
            self.fillerIndexToPageIndex = maps.fillerIndexToPageIndex
            self.pageIndexToFillerIndices = maps.pageIndexToFillerIndices
            self.totalFillerWordCount = maps.totalCount
            
            // Set Jumper ke kata pertama di halaman pertama
            if let firstIndices = maps.pageIndexToFillerIndices[0], let firstIndex = firstIndices.first {
                self.currentFillerWordIndex = firstIndex
            } else {
                self.currentFillerWordIndex = (maps.totalCount > 0) ? 1 : 0
            }
            
            // Set audio session agar bisa play di mode silent
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Gagal mengaktifkan audio session: \(error.localizedDescription)")
            }
        }
        .onDisappear {
            stopPlayback()
            player = nil
        }
    }
    
    // MARK: - Jumper Logic
    
    private func jumpToFillerWord(globalIndex: Int) {
        // 'globalIndex' adalah 1-based (misal 1/6)
        guard globalIndex >= 1 && globalIndex <= totalFillerWordCount else { return }
        
        // Cari halaman target dari peta
        if let targetPageIndex = fillerIndexToPageIndex[globalIndex] {
            // Update state jumper
            self.currentFillerWordIndex = globalIndex
            // Lompat ke halaman (card)
            self.currentPageIndex = targetPageIndex
        }
    }
    
    // MARK: - Audio Playback Logic
    
    private func stopPlayback() {
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        isPlayingPageID = nil
        playbackProgress = 0.0
    }
    
    private func playSegment(url: URL, page: TranscriptPage) {
        if isPlayingPageID == page.id {
            stopPlayback()
            return
        }
        stopPlayback()
        
        print("[AudioPlayback] Mencoba memutar segmen: \(page.startTime) -> \(page.endTime)")
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        let startTime = CMTime(seconds: page.startTime, preferredTimescale: 600)
        
        // Gunakan completion handler (tanpa [weak self] karena ini Struct)
        player?.seek(to: startTime, completionHandler: { (finished) in
            
            guard finished else { return }
            
            self.isPlayingPageID = page.id
            
            self.timeObserverToken = self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { time in
                
                // Hitung Progress Bar
                let clipStartTime = page.startTime
                let clipEndTime = page.endTime
                let clipDuration = clipEndTime - clipStartTime
                let currentTimeInClip = time.seconds - clipStartTime
                
                if clipDuration > 0 {
                    self.playbackProgress = min(1.0, max(0.0, currentTimeInClip / clipDuration))
                }

                // Hentikan jika sudah melewati endTime
                if time.seconds >= page.endTime {
                    self.stopPlayback()
                }
            }
            
            // Mulai mainkan
            self.player?.play()
        })
    }
    

    // MARK: - Helper Functions
    
    // Format "00:30 - 00:40"
    private func formatTimestamp(_ startTime: TimeInterval, _ endTime: TimeInterval) -> String {
        let startMinutes = Int(startTime) / 60
        let startSeconds = Int(startTime) % 60
        let endMinutes = Int(endTime) / 60
        let endSeconds = Int(endTime) % 60
        
        return String(format: "%02d:%02d - %02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
    }
    
    /**
     * FUNGSI LOGIKA PAGINASI (Logika Non-Overlap + Pemetaan Jumper)
     */
    private func buildPagesAndMaps() -> (pages: [TranscriptPage], maps: FillerMaps) {
        let fillerSet = fillerWordVM.fillerWordsID
        
        let confirmedWords = whisperKitVM.confirmedWords
        let prevWords = whisperKitVM.prevWords
        let lastAgreedWords = whisperKitVM.lastAgreedWords
        let hypothesisWords = whisperKitVM.hypothesisWords
        let finalHypothesisWords = lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(prevWords, hypothesisWords)
        let allWords = confirmedWords + finalHypothesisWords
        
        guard !allWords.isEmpty else {
            return ([], FillerMaps(totalCount: 0, fillerIndexToPageIndex: [:], pageIndexToFillerIndices: [:]))
        }

        var pages: [TranscriptPage] = []
        let punctuationSet = CharacterSet(charactersIn: ".?!")
        var currentIndex = 0 // Kursor untuk mencegah overlap
        
        // --- Persiapan Jumper ---
        var fillerIndexToPageIndex: [Int: Int] = [:]
        var pageIndexToFillerIndices: [Int: [Int]] = [:]
        var globalFillerCount = 0 // 0-based internal, akan jadi 1-based saat disimpan
        
        // 1. Temukan dulu SEMUA global index dari filler word
        let allFillerWordGlobalIndices: [Int] = allWords.enumerated().compactMap { (index, word) -> Int? in
            let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return fillerSet.contains(cleanWord) ? index : nil
        }
        let totalFillerWordCount = allFillerWordGlobalIndices.count
        // --- Selesai Persiapan Jumper ---
        

        while currentIndex < allWords.count {
            
            // 2. Cari filler word BERIKUTNYA dari posisi kursor
            let nextFillerWord = allWords[currentIndex...].enumerated().first { (index, word) -> Bool in
                let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                return fillerSet.contains(cleanWord)
            }
            
            guard let foundFiller = nextFillerWord else {
                break
            }
            
            let wordIndex = currentIndex + foundFiller.offset
            
            // 3. Tentukan Batasan Awal (start) dan Akhir (end) halaman
            let start: Int
            let end: Int
            
            // Cek Aturan 1 (Tanda Baca) vs Aturan 2 (10 Kata)
            let windowStart = max(0, wordIndex - 25)
            let windowEnd = min(allWords.count - 1, wordIndex + 25)
            let punctuationFoundInWindow = allWords[windowStart...windowEnd].contains(where: {
                $0.word.rangeOfCharacter(from: punctuationSet) != nil
            })
            
            if punctuationFoundInWindow {
                // ATURAN 1: Ambil kalimat utuh
                let searchRangeBefore = currentIndex...wordIndex
                let nearestPuncBefore = allWords[searchRangeBefore].lastIndex {
                    $0.word.rangeOfCharacter(from: punctuationSet) != nil
                }
                start = (nearestPuncBefore != nil) ? nearestPuncBefore! + 1 : currentIndex
                
                let searchRangeAfter = wordIndex...(allWords.count - 1)
                let nearestPuncAfter = allWords[searchRangeAfter].firstIndex {
                    $0.word.rangeOfCharacter(from: punctuationSet) != nil
                }
                end = nearestPuncAfter ?? (allWords.count - 1)
                
            } else {
                // ATURAN 2: Ambil 10 kata
                start = max(currentIndex, wordIndex - 10)
                end = min(allWords.count - 1, wordIndex + 10)
            }
            
            // --- 4. Buat Halaman (Card) ---
            let pageWords = allWords[start...end]
            let pageRange = start...end
            let currentPageIndex = pages.count // Halaman saat ini (misal 0)
            
            guard let firstWord = pageWords.first, let lastWord = pageWords.last else {
                currentIndex = end + 1
                continue
            }
            let pageStartTime = TimeInterval(firstWord.start)
            let pageEndTime = TimeInterval(lastWord.end)
            
            // Buat AttributedString
            var pageString = AttributedString("")
            
            // --- 5. Petakan Jumper ---
            var fillerIndicesOnThisPage: [Int] = []
            for word in pageWords {
                let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                var str = AttributedString(word.word + " ")
                
                if fillerSet.contains(cleanWord) {
                    str.foregroundColor = .red
                    str.font = .system(.body, design: .serif).bold()
                    
                    // Cek apakah ini adalah global filler word (untuk menghindari duplikat)
                    let globalIndexForThisWord = allWords.firstIndex(of: word)
                    if let globalIndex = globalIndexForThisWord, allFillerWordGlobalIndices.contains(globalIndex) {
                        
                        // Cari tahu ini filler word ke berapa (1-based)
                        if let countIndex = allFillerWordGlobalIndices.firstIndex(of: globalIndex) {
                            let oneBasedIndex = countIndex + 1
                            
                            // Jika belum dipetakan, petakan
                            if fillerIndexToPageIndex[oneBasedIndex] == nil {
                                fillerIndexToPageIndex[oneBasedIndex] = currentPageIndex
                                fillerIndicesOnThisPage.append(oneBasedIndex)
                            }
                        }
                    }
                } else {
                    str.foregroundColor = .primary
                    str.font = .system(.body, design: .serif)
                }
                pageString.append(str)
            }
            
            if !fillerIndicesOnThisPage.isEmpty {
                pageIndexToFillerIndices[currentPageIndex] = fillerIndicesOnThisPage
            }
            // --- Selesai Pemetaan ---
            
            let page = TranscriptPage(
                attributedString: pageString,
                startTime: pageStartTime,
                endTime: pageEndTime
            )
            pages.append(page)
            
            // --- 6. LOMPATKAN KURSOR ---
            currentIndex = end + 1
        }
        
        let maps = FillerMaps(totalCount: totalFillerWordCount,
                              fillerIndexToPageIndex: fillerIndexToPageIndex,
                              pageIndexToFillerIndices: pageIndexToFillerIndices)
        
        return (pages, maps)
    }
}
