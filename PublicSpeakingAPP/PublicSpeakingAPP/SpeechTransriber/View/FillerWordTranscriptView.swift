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
            
            let allWords: [WordTiming]
            
            if !whisperKitVM.fillerAnalysisWords.isEmpty {
                print("✅ [FillerView] Menggunakan data Dual-Pass (fillerAnalysisWords)")
                allWords = whisperKitVM.fillerAnalysisWords
            } else {
                print("⚠️ [FillerView] Fallback ke data Live (confirmedWords)")
                let confirmed = whisperKitVM.confirmedWords
                let prev = whisperKitVM.prevWords
                let lastAgreed = whisperKitVM.lastAgreedWords
                let hypothesis = whisperKitVM.hypothesisWords
                let finalHypo = lastAgreed + TranscriptionUtilities.findLongestDifferentSuffix(prev, hypothesis)
                
                allWords = confirmed + finalHypo
            }
                        
            let isFiller: (WordTiming) -> Bool = { word in
                let cleanWord = word.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                return fillerWordVM.isFillerWord(cleanWord)
            }
            
            let (pages, maps) = TranscriptBuilder().buildPagesAndMaps(
                allWords: allWords,
                isProblematic: isFiller
            )
            
            self.pages = pages
            self.maps = maps
            
            onMapsCalculated(maps)
        }
    }
}
