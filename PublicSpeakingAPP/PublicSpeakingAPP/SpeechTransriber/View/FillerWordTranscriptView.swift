//
//  FillerWordTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 03/11/25.
//
//  Updated by Gemini on 04/11/25 with complex sentence/word count rules.
//

import SwiftUI
import WhisperKit
import NaturalLanguage

struct FillerWordTranscriptView: View {
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject var fillerWordVM: FillerWordViewModel
    
    let result: EvaluationModel
    let fullTranscript: String
    
    // State untuk Paginasi (dibuat saat .onAppear)
    @State private var pages: [AttributedString] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transkrip Kata Pengisi (Total: \(result.fillerWordTotalCount))")
                .font(.headline)
                .padding(.bottom, 5)
            
            TabView {
                if pages.isEmpty {
                    Text("Memproses transkrip...")
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            Text(pages[index])
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            
                            Spacer(minLength: 0)
                            
                            Text("Halaman \(index + 1) dari \(pages.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .padding(.bottom, 10)
                        }
                        .tag(index)
                    }
                }
            }
            .frame(minHeight: 150) // Tinggi minimal agar card muncul
            .tabViewStyle(.page(indexDisplayMode: .never)) // Untuk swipe
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .onAppear {
            // Panggil fungsi buildPages hanya satu kali
            self.pages = buildPages()
        }
    }
    
    // MARK: - Helper Functions untuk Paginasi
    
    /**
     * FUNGSI LOGIKA PAGINASI BARU
     * Mengikuti aturan kustom Anda:
     * - Rule 1: 2 kalimat, 20-30 kata -> potong di titik.
     * - Rule 2: 2 kalimat, < 20 kata -> tambah jadi 3 kalimat.
     * - Rule 3: 3 kalimat, <= 30 kata -> potong di titik.
     * - Rule 4: Tidak ada titik -> potong di 30 kata.
     */
    private func buildPages() -> [AttributedString] {
        let fillerSet = fillerWordVM.fillerWordsID
        
        // 1. Dapatkan semua kata langsung dari view model
        let confirmedWords = whisperKitVM.confirmedWords
        let prevWords = whisperKitVM.prevWords
        let lastAgreedWords = whisperKitVM.lastAgreedWords
        let hypothesisWords = whisperKitVM.hypothesisWords
        
        let finalHypothesisWords = lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(prevWords, hypothesisWords)
        let allWords = confirmedWords + finalHypothesisWords // Ini adalah array [WordTiming]
        
        // Fallback
        if allWords.isEmpty {
            var fallback = AttributedString(fullTranscript.isEmpty ? "Transkrip tidak tersedia." : fullTranscript)
            fallback.font = .system(.body, design: .serif)
            fallback.foregroundColor = .gray
            return [fallback]
        }

        // 2. Siapkan variabel untuk membangun halaman
        var pages: [AttributedString] = []
        var currentPage = AttributedString("")
        var currentWordCount = 0
        var currentSentenceCount = 0
        let punctuation = CharacterSet(charactersIn: ".?!")

        // 3. Loop melalui setiap kata di array 'allWords'
        for (index, word) in allWords.enumerated() {
            
            // --- Styling (logika lama Anda) ---
            let cleanWord = word.word
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            
            var str = AttributedString(word.word + " ")
            
            if fillerSet.contains(cleanWord) {
                str.foregroundColor = .red
                str.font = .system(.body, design: .serif).bold()
            } else {
                str.foregroundColor = .primary
                str.font = .system(.body, design: .serif)
            }
            // --- Akhir Styling ---
            
            // Tambahkan kata yang sudah di-style ke halaman saat ini
            currentPage.append(str)
            currentWordCount += 1
            
            let isLastWord = (index == allWords.count - 1)
            // Cek apakah kata INI mengandung tanda baca
            let hasPunctuation = word.word.rangeOfCharacter(from: punctuation) != nil
            
            if hasPunctuation {
                currentSentenceCount += 1
            }
            
            // --- Cek Aturan Paginasi ---
            var closePage = false
            
            // ATURAN TERAKHIR: Jika ini kata terakhir, tutup halaman.
            if isLastWord {
                closePage = true
                
            // ATURAN JIKA ADA TANDA BACA (Rule 1, 2, 3, 4)
            } else if hasPunctuation {
                
                // Rule 1: 2 kalimat & 20-30 kata (atau lebih, kita potong saja)
                if currentSentenceCount == 2 && currentWordCount >= 20 {
                    // User request 20-30. Jika 35, lebih baik potong di 35
                    // daripada lanjut dan jadi 50.
                    closePage = true
                
                // Rule 2: 2 kalimat & < 20 kata
                } else if currentSentenceCount == 2 && currentWordCount < 20 {
                    // JANGAN tutup halaman, tunggu kalimat ke-3
                    closePage = false
                
                // Rule 3 & 4: 3 kalimat (ini terjadi setelah rule 2)
                } else if currentSentenceCount == 3 {
                    // Tutup halaman, berapapun jumlah katanya (28, 29, atau 30)
                    closePage = true
                }
            
            // ATURAN JIKA TIDAK ADA TANDA BACA (Rule 5)
            } else if !hasPunctuation {
                
                // Rule 5: 30 kata & belum ada tanda baca
                if currentWordCount == 30 {
                    closePage = true
                }
            }
            
            // "Tutup" halaman jika ada aturan yang terpenuhi
            if closePage {
                pages.append(currentPage)
                
                // Reset untuk halaman berikutnya
                currentPage = AttributedString("")
                currentWordCount = 0
                currentSentenceCount = 0
            }
        }
        
        return pages
    }
}
