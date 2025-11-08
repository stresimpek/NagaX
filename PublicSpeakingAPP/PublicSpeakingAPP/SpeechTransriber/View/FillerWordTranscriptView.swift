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
    
    @State private var pages: [TranscriptPage] = []
    @State private var maps: TranscriptMaps = .empty
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transkrip Kata Pengisi (Total: \(result.fillerWordTotalCount))")
                .font(.headline)
                .padding(.bottom, 5)
            
            ReusableTranscriptCardView(
                pages: pages,
                maps: maps,
                savedRecordingURL: whisperKitVM.savedRecordingURL,
                emptyStateMessage: "No Filler"
            )
        }
        .onAppear {
            let confirmed = whisperKitVM.confirmedWords
            let prev = whisperKitVM.prevWords
            let lastAgreed = whisperKitVM.lastAgreedWords
            let hypothesis = whisperKitVM.hypothesisWords
            let finalHypo = lastAgreed + TranscriptionUtilities.findLongestDifferentSuffix(prev, hypothesis)
            let allWords = confirmed + finalHypo
                        
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
        }
    }
}
