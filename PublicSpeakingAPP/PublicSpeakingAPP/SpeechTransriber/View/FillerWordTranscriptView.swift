//
//  FillerWordTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 03/11/25.
//

import SwiftUI
import WhisperKit

struct FillerWordTranscriptView: View {
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject var fillerWordVM: FillerWordViewModel
    
    let result: EvaluationModel
    let fullTranscript: String
        
    let onMapsCalculated: (TranscriptMaps) -> Void
    
    @State private var pages: [TranscriptPage] = []
    @State private var maps: TranscriptMaps = .empty
    
    var body: some View {
        VStack(alignment: .leading) {
            ReusableTranscriptCardView(
                pages: pages,
                maps: maps,
                savedRecordingURL: whisperKitVM.savedRecordingURL,
                emptyStateMessage: "No Filler"
            )
        }
        .onAppear {
            // --- PERBAIKAN LOGIC DISINI ---
            
            let allWords: [WordTiming]
            
            // 1. Cek apakah ada data hasil Re-transcribe (High Accuracy dengan prompt)?
            if !whisperKitVM.fillerAnalysisWords.isEmpty {
                print("✅ [FillerView] Menggunakan data Dual-Pass (fillerAnalysisWords)")
                // Gunakan data yang mengandung "emm", "eh", dll
                allWords = whisperKitVM.fillerAnalysisWords
            } else {
                print("⚠️ [FillerView] Fallback ke data Live (confirmedWords)")
                // Fallback ke logic lama (Live Data) jika re-transcribe gagal
                let confirmed = whisperKitVM.confirmedWords
                let prev = whisperKitVM.prevWords
                let lastAgreed = whisperKitVM.lastAgreedWords
                let hypothesis = whisperKitVM.hypothesisWords
                let finalHypo = lastAgreed + TranscriptionUtilities.findLongestDifferentSuffix(prev, hypothesis)
                
                allWords = confirmed + finalHypo
            }
            
            // -----------------------------
                        
            let isFiller: (WordTiming) -> Bool = { word in
                // Bersihkan kata dari tanda baca untuk pencocokan regex
                let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                return fillerWordVM.isFillerWord(cleanWord)
            }
            
            let (pages, maps) = TranscriptBuilder().buildPagesAndMaps(
                allWords: allWords,
                isProblematic: isFiller
            )
            
            self.pages = pages
            self.maps = maps
            
            // Kirim hasil perhitungan kembali ke ViewModel agar skor/grade terupdate
            onMapsCalculated(maps)
        }
    }
}
