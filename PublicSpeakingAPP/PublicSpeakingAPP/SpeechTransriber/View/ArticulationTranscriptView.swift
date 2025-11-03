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
    
    private var articulationStyledTranscript: AttributedString {
        let confirmedWords = whisperKitVM.confirmedWords
        let prevWords = whisperKitVM.prevWords
        let lastAgreedWords = whisperKitVM.lastAgreedWords
        let hypothesisWords = whisperKitVM.hypothesisWords
        
        let finalHypothesisWords = lastAgreedWords + TranscriptionUtilities.findLongestDifferentSuffix(prevWords, hypothesisWords)
        
        var newAttributed = AttributedString("")
        
        for word in confirmedWords {
            var str = AttributedString(word.word + " ")
            if word.probability < 0.8 {
                str.foregroundColor = .red
            } else {
                str.foregroundColor = .primary
            }
            newAttributed.append(str)
        }
        
        for word in finalHypothesisWords {
            var str = AttributedString(word.word + " ")
            if word.probability < 0.8 {
                str.foregroundColor = .red
            } else {
                str.foregroundColor = .primary
            }
            newAttributed.append(str)
        }
        
        if newAttributed.description.isEmpty {
            return AttributedString(fullTranscript)
        }
        
        return newAttributed
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transkrip Artikulasi")
                .font(.headline)
                .padding(.bottom, 5)
            
            ScrollView {
                Text(articulationStyledTranscript)
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
