//
//  TranscriptBuilder.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 04/11/25.
//

import Foundation
import WhisperKit

struct TranscriptBuilder {
    
    func buildPagesAndMaps(allWords: [WordTiming],
                           isProblematic: (WordTiming) -> Bool) -> (pages: [TranscriptPage], maps: TranscriptMaps) {
        
        guard !allWords.isEmpty else {
            return ([], .empty)
        }

        var pages: [TranscriptPage] = []
        let punctuationSet = CharacterSet(charactersIn: ".?!")
        var currentIndex = 0
        
        var wordIndexToPageIndex: [Int: Int] = [:]
        var pageIndexToWordIndices: [Int: [Int]] = [:]
        
        let allProblematicWordGlobalIndices: [Int] = allWords.enumerated().compactMap { (index, word) -> Int? in
            return isProblematic(word) ? index : nil
        }
        let totalProblematicWordCount = allProblematicWordGlobalIndices.count

        while currentIndex < allWords.count {
            
            let nextProblematicWord = allWords[currentIndex...].enumerated().first { (index, word) -> Bool in
                return isProblematic(word)
            }
            
            guard let foundWord = nextProblematicWord else {
                break
            }
            
            let wordIndex = currentIndex + foundWord.offset
            
            let start: Int
            let end: Int
            
            let windowStart = max(0, wordIndex - 25)
            let windowEnd = min(allWords.count - 1, wordIndex + 25)
            let punctuationFoundInWindow = allWords[windowStart...windowEnd].contains(where: {
                $0.word.rangeOfCharacter(from: punctuationSet) != nil
            })
            
            if punctuationFoundInWindow {
                let searchRangeBefore = currentIndex...wordIndex
                let nearestPuncBefore = allWords[searchRangeBefore].lastIndex {
                    $0.word.rangeOfCharacter(from: punctuationSet) != nil
                }
                start = (nearestPuncBefore != nil) ? nearestPuncBefore! + 1 : currentIndex
                
                let searchRangeAfter = wordIndex...(allWords.count - 1)
                let nearestPuncAfter = allWords[searchRangeAfter].firstIndex {
                    $0.word.rangeOfCharacter(from: punctuationSet) != nil
                }
                end = nearestPuncAfter ?? (allWords.count - 1)
                
            } else {
                start = max(currentIndex, wordIndex - 10)
                end = min(allWords.count - 1, wordIndex + 10)
            }
            
            let pageWords = allWords[start...end]
            let currentPageIndex = pages.count
            
            guard let firstWord = pageWords.first, let lastWord = pageWords.last else {
                currentIndex = end + 1
                continue
            }
            let pageStartTime = TimeInterval(firstWord.start)
            let pageEndTime = TimeInterval(lastWord.end)
            
            var pageString = AttributedString("")
            
            var problematicIndicesOnThisPage: [Int] = []
            for word in pageWords {
                var str = AttributedString(word.word + " ")
                
                if isProblematic(word) {
                    str.foregroundColor = .red
                    str.font = .system(.body, design: .serif).bold()
                    
                    let globalIndexForThisWord = allWords.firstIndex(of: word)
                    if let globalIndex = globalIndexForThisWord, allProblematicWordGlobalIndices.contains(globalIndex) {
                        
                        if let countIndex = allProblematicWordGlobalIndices.firstIndex(of: globalIndex) {
                            let oneBasedIndex = countIndex + 1
                            
                            if wordIndexToPageIndex[oneBasedIndex] == nil {
                                wordIndexToPageIndex[oneBasedIndex] = currentPageIndex
                                problematicIndicesOnThisPage.append(oneBasedIndex)
                            }
                        }
                    }
                } else {
                    str.foregroundColor = .primary
                    str.font = .system(.body, design: .serif)
                }
                pageString.append(str)
            }
            
            if !problematicIndicesOnThisPage.isEmpty {
                pageIndexToWordIndices[currentPageIndex] = problematicIndicesOnThisPage
            }
            
            let page = TranscriptPage(
                attributedString: pageString,
                startTime: pageStartTime,
                endTime: pageEndTime
            )
            pages.append(page)
            
            currentIndex = end + 1
        }
        
        let maps = TranscriptMaps(totalCount: totalProblematicWordCount,
                                  wordIndexToPageIndex: wordIndexToPageIndex,
                                  pageIndexToWordIndices: pageIndexToWordIndices)
        
        return (pages, maps)
    }
}
