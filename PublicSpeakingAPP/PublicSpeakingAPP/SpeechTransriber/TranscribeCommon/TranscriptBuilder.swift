//
//  TranscriptBuilder.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 04/11/25.
//

import Foundation
import WhisperKit
import SwiftUI

struct TranscriptBuilder {
    
    func buildPagesAndMaps(
        allWords: [WordTiming],
        isProblematic: (WordTiming) -> Bool
    ) -> (pages: [TranscriptPage], maps: TranscriptMaps) {
        
        guard !allWords.isEmpty else {
            return ([], .empty)
        }
        
        var pages: [TranscriptPage] = []
        let punctuationSet = CharacterSet(charactersIn: ".?!")
        var currentIndex = 0
        
        var errorSlotIndex = 0
        
        var totalProblematicWordCount = 0
        
        var wordIndexToPageIndex: [Int: Int] = [:]
        var pageIndexToWordIndices: [Int: [Int]] = [:]
        
        while currentIndex < allWords.count {
            let nextProblematicWord = allWords[currentIndex...]
                .enumerated()
                .first { (_, word) in isProblematic(word) }
            
            guard let foundWord = nextProblematicWord else {
                break
            }
            
            let wordIndex = currentIndex + foundWord.offset
            
            let start: Int
            let end: Int
            
            let windowStart = max(0, wordIndex - 25)
            let windowEnd   = min(allWords.count - 1, wordIndex + 25)
            let punctuationFoundInWindow = allWords[windowStart...windowEnd].contains {
                $0.word.rangeOfCharacter(from: punctuationSet) != nil
            }
            
            if punctuationFoundInWindow {
                let searchRangeBefore = currentIndex..<wordIndex
                let nearestPuncBefore = allWords[searchRangeBefore].lastIndex {
                    $0.word.rangeOfCharacter(from: punctuationSet) != nil
                }
                start = (nearestPuncBefore != nil) ? nearestPuncBefore! + 1 : currentIndex
                
                let maxLookAhead = min(allWords.count - 1, wordIndex + 40)
                let searchRangeAfter = wordIndex...maxLookAhead
                
                let nearestPuncAfter = allWords[searchRangeAfter].firstIndex {
                    $0.word.rangeOfCharacter(from: punctuationSet) != nil
                }
                
                end = nearestPuncAfter ?? min(allWords.count - 1, wordIndex + 15)
            } else {
                start = max(currentIndex, wordIndex - 10)
                end   = min(allWords.count - 1, wordIndex + 10)
            }

            let pageWords = allWords[start...end]
            let currentPageIndex = pages.count
            
            guard let firstWord = pageWords.first,
                  let lastWord  = pageWords.last else {
                currentIndex = end + 1
                continue
            }
            
            let pageStartTime = TimeInterval(firstWord.start)
            let pageEndTime   = TimeInterval(lastWord.end)
            
            var pageString = AttributedString("")
            var problematicGlobalIndicesOnThisPage: [Int] = []
            
            for (localOffset, word) in pageWords.enumerated() {
                var str = AttributedString(word.word + " ")
                
                if isProblematic(word) {
                    str.foregroundColor = .baseColorRed
                    str.font = .system(.body, design: .serif).bold()
                    
                    let globalIndex = start + localOffset
                    problematicGlobalIndicesOnThisPage.append(globalIndex)
                    
                    totalProblematicWordCount += 1
                } else {
                    str.foregroundColor = .primary
                    str.font = .system(.body, design: .serif)
                }
                
                pageString.append(str)
            }
            
            if !problematicGlobalIndicesOnThisPage.isEmpty {
                errorSlotIndex += 1
                
                wordIndexToPageIndex[errorSlotIndex] = currentPageIndex
                
                pageIndexToWordIndices[currentPageIndex] = problematicGlobalIndicesOnThisPage
            }
            
            let page = TranscriptPage(
                attributedString: pageString,
                startTime: pageStartTime,
                endTime: pageEndTime
            )
            pages.append(page)
            
            currentIndex = end + 1
        }
        
        let maps = TranscriptMaps(
            totalPages: errorSlotIndex,
            totalCount: totalProblematicWordCount,
            wordIndexToPageIndex: wordIndexToPageIndex,
            pageIndexToWordIndices: pageIndexToWordIndices
        )
        
        return (pages, maps)
    }
}

