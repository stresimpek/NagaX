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
    
    private var fillerWordStyledTranscript: AttributedString {
        let fillerSet = fillerWordVM.fillerWordsID
        
        let confirmedWords = whisperKitVM.confirmedWords
        let prevWords = whisperKitVM.prevWords
        let lastAgreedWords = whisperKitVM.lastAgreedWords
        let hypothesisWords = whisperKitVM.hypothesisWords
        
        let finalHypothesisWords = lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(prevWords, hypothesisWords)
        
        var newAttributed = AttributedString("")
        
        for word in confirmedWords {
            let cleanWord = word.word.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            
            var str = AttributedString(word.word + " ")
            str.foregroundColor = fillerSet.contains(cleanWord) ? .red : .primary
            newAttributed.append(str)
        }
        
        for word in finalHypothesisWords {
            let cleanWord = word.word.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            
            var str = AttributedString(word.word + " ")
            str.foregroundColor = fillerSet.contains(cleanWord) ? .red : .primary
            newAttributed.append(str)
        }
        
        if newAttributed.description.isEmpty {
            return AttributedString(fullTranscript)
        }
        
        return newAttributed
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transkrip Kata Pengisi (Total: \(result.fillerWordTotalCount))")
                .font(.headline)
                .padding(.bottom, 5)
            
            ScrollView {
                Text(fillerWordStyledTranscript)
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 350)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}
