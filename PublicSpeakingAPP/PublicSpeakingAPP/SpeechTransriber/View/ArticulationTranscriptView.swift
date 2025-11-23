//
//  ArticulationTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 03/11/25.
//

import SwiftUI
import WhisperKit

struct ArticulationTranscriptView: View {
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    
    let fullTranscript: String
    
    let onMapsCalculated: (TranscriptMaps, Int) -> Void
    
    @State private var pages: [TranscriptPage] = []
    @State private var maps: TranscriptMaps = .empty
    
    var body: some View {
        VStack(alignment: .leading) {
            ReusableTranscriptCardView(
                pages: pages,
                maps: maps,
                savedRecordingURL: whisperKitVM.savedRecordingURL,
                emptyStateMessage: "Tidak ada artikulasi lemah"
            )
        }
        .onAppear {
            let confirmed = whisperKitVM.confirmedWords
            let prev = whisperKitVM.prevWords
            let lastAgreed = whisperKitVM.lastAgreedWords
            let hypothesis = whisperKitVM.hypothesisWords
            let finalHypo = lastAgreed + TranscriptionUtilities.findLongestDifferentSuffix(prev, hypothesis)
            let allWords = confirmed + finalHypo
            

            let isWeakArticulation: (WordTiming) -> Bool = { word in
                let cleanedWord = word.word.trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespaces))
                
                if cleanedWord.isEmpty {
                    return false
                }
                
                return word.probability < 0.99
            }
            
            let (pages, maps) = TranscriptBuilder().buildPagesAndMaps(
                allWords: allWords,
                isProblematic: isWeakArticulation
            )
            
            self.pages = pages
            self.maps = maps
            onMapsCalculated(maps, allWords.count) 
        }
    }
}
