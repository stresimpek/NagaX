//
//  FillerWordTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 03/11/25.
//
//  Updated by Gemini on 04/11/25 with progress bar and layout fixes.
//

import SwiftUI
import WhisperKit
import NaturalLanguage
import AVFoundation // Pastikan ini ada

// Tipe data baru untuk menyimpan info halaman/card
fileprivate struct TranscriptPage: Identifiable {
    let id = UUID()
    let attributedString: AttributedString
    let startTime: TimeInterval
    let endTime: TimeInterval
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
    
    // --- BARU: State untuk Progress Bar ---
    @State private var playbackProgress: Double = 0.0
    
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
                            
                            // --- PERBAIKAN: Teks di atas ---
                            Text(page.attributedString)
                                .font(.system(.body, design: .serif)) // Pastikan font disetel
                                .padding()
                                .fixedSize(horizontal: false, vertical: true) // <-- PERBAIKAN TEKS TERPOTONG
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            
                            Spacer(minLength: 10) // Pendorong ke bawah
                            
                            // --- PERBAIKAN: Kontrol di bawah ---
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
                                
                                // Progress Bar dan Teks Indikator
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: isPlayingPageID == page.id ? playbackProgress : 0.0)
                                        .tint(.blue)
                                    
                                    Text(isPlayingPageID == page.id ? "Memutar audio..." : "Contoh \(index + 1) dari \(pages.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
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
            .onChange(of: currentPageIndex) { _ in
                 stopPlayback()
            }
        }
        .onAppear {
            self.pages = buildPages()
            
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
    
    // MARK: - Audio Playback Logic
    
    private func stopPlayback() {
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        isPlayingPageID = nil
        playbackProgress = 0.0 // <-- RESET PROGRESS
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
                
                // --- BARU: Hitung Progress Bar ---
                let clipStartTime = page.startTime
                let clipEndTime = page.endTime
                let clipDuration = clipEndTime - clipStartTime
                let currentTimeInClip = time.seconds - clipStartTime
                
                if clipDuration > 0 {
                    // Pastikan progress antara 0.0 dan 1.0
                    self.playbackProgress = min(1.0, max(0.0, currentTimeInClip / clipDuration))
                }
                // --- AKHIR HITUNG PROGRESS ---

                // Hentikan jika sudah melewati endTime
                if time.seconds >= page.endTime {
                    self.stopPlayback()
                }
            }
            
            // Mulai mainkan
            self.player?.play()
        })
    }
    

    // MARK: - Helper Functions untuk Paginasi (Tidak Berubah)
    
    /**
     * FUNGSI LOGIKA PAGINASI (Logika Non-Overlap)
     */
    private func buildPages() -> [TranscriptPage] {
        let fillerSet = fillerWordVM.fillerWordsID
        
        // 1. Dapatkan semua kata langsung dari view model
        let confirmedWords = whisperKitVM.confirmedWords
        let prevWords = whisperKitVM.prevWords
        let lastAgreedWords = whisperKitVM.lastAgreedWords
        let hypothesisWords = whisperKitVM.hypothesisWords
        
        let finalHypothesisWords = lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(prevWords, hypothesisWords)
        let allWords = confirmedWords + finalHypothesisWords
        
        guard !allWords.isEmpty else { return [] }

        // 2. Siapkan variabel
        var pages: [TranscriptPage] = []
        let punctuationSet = CharacterSet(charactersIn: ".?!")
        var currentIndex = 0 // Kursor untuk mencegah overlap

        // 3. Loop melalui transkrip
        while currentIndex < allWords.count {
            
            // 4. Cari filler word BERIKUTNYA dari posisi kursor
            let nextFillerWord = allWords[currentIndex...].enumerated().first { (index, word) -> Bool in
                let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                return fillerSet.contains(cleanWord)
            }
            
            // 5. Jika tidak ada lagi, berhenti
            guard let foundFiller = nextFillerWord else {
                break
            }
            
            let wordIndex = currentIndex + foundFiller.offset
            
            // 6. Tentukan Batasan Awal (start) dan Akhir (end) halaman
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
            
            // --- 7. Buat Halaman (Card) ---
            let pageWords = allWords[start...end]
            
            guard let firstWord = pageWords.first, let lastWord = pageWords.last else {
                currentIndex = end + 1
                continue
            }
            let pageStartTime = TimeInterval(firstWord.start)
            let pageEndTime = TimeInterval(lastWord.end)
            
            // Buat AttributedString
            var pageString = AttributedString("")
            for word in pageWords {
                let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                var str = AttributedString(word.word + " ")
                
                if fillerSet.contains(cleanWord) {
                    str.foregroundColor = .red
                    str.font = .system(.body, design: .serif).bold()
                } else {
                    str.foregroundColor = .primary
                    str.font = .system(.body, design: .serif)
                }
                pageString.append(str)
            }
            
            let page = TranscriptPage(
                attributedString: pageString,
                startTime: pageStartTime,
                endTime: pageEndTime
            )
            pages.append(page)
            
            // --- 8. LOMPATKAN KURSOR (Kunci non-overlap) ---
            currentIndex = end + 1
        }
        
        return pages
    }
}
