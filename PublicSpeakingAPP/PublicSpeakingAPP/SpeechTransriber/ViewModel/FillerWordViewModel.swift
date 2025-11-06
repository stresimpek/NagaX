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
    @Published var fillerRating: Int = 0
    @Published var totalFillerCount: Int = 0
    @Published var fillerWordLabel: String = "NoFiller"

    private var previousTotalFillerCount: Int = 0
    private var ratingResetTimer: Timer?

    private let fillerWordPatterns: [NSRegularExpression] = {
        let patterns = [
            "e+h+",      // eh, eeh, ehh, eeeh, ehhh
            "h+m+",      // hm, hmm, hmmm
            "a+h+",      // ah, aah, ahh, aaah
            "u+m+",      // um, umm, ummm
            "u+h+",      // uh, uhh, uhhh
            "a+n+u+"     // anu, anuu, annuu
        ]
        
        return patterns.compactMap {
            try? NSRegularExpression(pattern: "^\\b\($0)\\b$", options: .caseInsensitive)
        }
    }()

    func isFillerWord(_ word: String) -> Bool {
        let cleanWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        return fillerWordPatterns.contains { regex in
            let range = NSRange(cleanWord.startIndex..<cleanWord.endIndex, in: cleanWord)
            return regex.firstMatch(in: cleanWord, range: range) != nil
        }
    }

    func analyze(text: String, duration: TimeInterval) {
        guard !text.isEmpty else {
            clearResults()
            return
        }

        let tokens = tokenize(text)

        var counts: [String: Int] = [:]
        for token in tokens {
            if isFillerWord(token) {
                counts[token, default: 0] += 1
            }
        }

        self.fillerWordCounts = counts
        
        let newTotalCount = counts.values.reduce(0, +)
        self.totalFillerCount = newTotalCount

        if newTotalCount > self.previousTotalFillerCount {
            self.fillerRating = 1
            self.fillerWordLabel = "FillerAda"

            ratingResetTimer?.invalidate()
            ratingResetTimer = Timer.scheduledTimer(
                timeInterval: 3.0,
                target: self,
                selector: #selector(resetFillerRating),
                userInfo: nil,
                repeats: false
            )
        } else if ratingResetTimer == nil {
            self.fillerRating = 3
            self.fillerWordLabel = "NoFiller"
        }

        self.previousTotalFillerCount = newTotalCount
    }

    @objc private func resetFillerRating() {
        print("FillerWordVM: Timer fired. Resetting rating -> 3")
        self.fillerRating = 3
        self.fillerWordLabel = "NoFiller"
        self.ratingResetTimer?.invalidate()
        self.ratingResetTimer = nil
    }

    func clearResults() {
        fillerWordCounts = [:]
        totalFillerCount = 0
        fillerWordLabel = "NoFiller"
        previousTotalFillerCount = 0
        fillerRating = 0
        
        ratingResetTimer?.invalidate()
        ratingResetTimer = nil
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
