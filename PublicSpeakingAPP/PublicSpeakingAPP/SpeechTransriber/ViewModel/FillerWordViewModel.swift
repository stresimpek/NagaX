//
//  FillerWordViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 30/10/25.
//

import Foundation
import NaturalLanguage
import Combine

@MainActor
final class FillerWordViewModel: ObservableObject {
    
    @Published var fillerWordCounts: [String: Int] = [:]
    
    @Published var totalFillerCount: Int = 0
    @Published var fillerWordLabel: String = "..."

    private var previousTotalFillerCount: Int = 0

    private let fillerWordsID: Set<String> = [
        "eh", "ehm", "hmm", "ee", "um", "uh", "anu", "um", "eee"
    ]

    func analyze(text: String) {
        guard !text.isEmpty else {
            clearResults()
            return
        }

        let tokens = tokenize(text)
        
        var counts: [String: Int] = [:]
        for token in tokens {
            if fillerWordsID.contains(token) {
                counts[token, default: 0] += 1
            }
        }
        
        self.fillerWordCounts = counts
        
        let newTotalCount = counts.values.reduce(0, +)
        self.totalFillerCount = newTotalCount
        
        if newTotalCount > self.previousTotalFillerCount {
            self.fillerWordLabel = "FillerAda"
        } else {
            self.fillerWordLabel = "..."
        }
        
        self.previousTotalFillerCount = newTotalCount
    }

    func clearResults() {
        fillerWordCounts = [:]
        totalFillerCount = 0
        fillerWordLabel = "..."
        previousTotalFillerCount = 0
    }

    private func tokenize(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        var tokens: [String] = []
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType, options: options) { _, tokenRange in
            let token = String(text[tokenRange]).lowercased()
            tokens.append(token)
            return true
        }
        return tokens
    }
}
