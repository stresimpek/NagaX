//
//  TranscriptShared.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 04/11/25.
//

import Foundation
import SwiftUI

struct TranscriptPage: Identifiable {
    let id = UUID()
    let attributedString: AttributedString
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct TranscriptMaps {
    let totalCount: Int
    let wordIndexToPageIndex: [Int: Int]
    let pageIndexToWordIndices: [Int: [Int]]
    
    static var empty: TranscriptMaps {
        TranscriptMaps(totalCount: 0, wordIndexToPageIndex: [:], pageIndexToWordIndices: [:])
    }
}

func formatTimestamp(_ startTime: TimeInterval, _ endTime: TimeInterval) -> String {
    let startMinutes = Int(startTime) / 60
    let startSeconds = Int(startTime) % 60
    let endMinutes = Int(endTime) / 60
    let endSeconds = Int(endTime) % 60
    
    return String(format: "%02d:%02d - %02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
}
