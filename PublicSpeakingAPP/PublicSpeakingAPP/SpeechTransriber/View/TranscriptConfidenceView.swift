//
//  TranscriptConfidenceView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 29/10/25.
//

import SwiftUI
import WhisperKit

struct TranscriptConfidenceView: View {
    
    @ObservedObject var vm: SpeechTranscriberViewModel
    
    var body: some View {
        ScrollView {
            let combinedText = generateAttributedText(from: vm)
            
            if combinedText == Text("") {
                Text("Tidak ada transkrip yang terekam.")
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                combinedText
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(height: 350)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func generateAttributedText(from vm: SpeechTranscriberViewModel) -> Text {
        
        if vm.enableEagerDecoding {
            let allWords: [WordTiming] = vm.confirmedWords + vm.hypothesisWords
            
            return allWords.reduce(Text("")) { (result, word) in
                let confidence = word.probability
                let color = confidence < 0.8 ? Color.red : Color.primary
                
                return result + Text(word.word).foregroundColor(color)
            }
            
        } else {
            let allSegments: [TranscriptionSegment] = vm.confirmedSegments + vm.unconfirmedSegments
            
            let logprobThreshold: Float = -0.223
            
            return allSegments.reduce(Text("")) { (result, segment) in
                let confidenceLogProb = segment.avgLogprob
                let color = confidenceLogProb < logprobThreshold ? Color.red : Color.primary
                
                return result + Text(segment.text + " ").foregroundColor(color)
            }
        }
    }
}
