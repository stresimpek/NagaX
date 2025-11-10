//
//  TempoViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 20/10/25.
//

import Foundation
import WhisperKit
import Combine

struct TempoPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let wpm: Double
}

@MainActor
final class TempoViewModel: ObservableObject {
    
    @Published var wpm: Double = 0.0
    @Published var tempoLabel: String = "..."
    @Published var tempoRating: Int = 0
    @Published var wpmHistory: [(timestamp: TimeInterval, wpm: Double)] = []

    private let wpmIdealMin: Double = 110.0
    private let wpmIdealMax: Double = 140.0
    private let wpmCukupMin: Double = 90.0
    private let wpmCukupMax: Double = 160.0
    
    private var wordHistory: [(endTime: TimeInterval, duration: TimeInterval)] = []
    private let windowSize: TimeInterval = 10.0
    private let smoothingFactor: Double = 0.3

    func updateTempo(from allWords: [WordTiming], totalDuration: TimeInterval) {
        for word in allWords {
            if !wordHistory.contains(where: { $0.endTime == TimeInterval(word.end) }) {
                let duration = TimeInterval(word.end - word.start)
                if duration > 0 {
                     wordHistory.append((endTime: TimeInterval(word.end), duration: duration))
                }
            }
        }
        
        wordHistory = wordHistory.filter { (endTime, _) in
            (totalDuration - endTime) <= windowSize
        }
        
        let totalWordsInWindow = wordHistory.count
        let totalSpeechDurationInWindow = wordHistory.reduce(0.0) { $0 + $1.duration }
        
        var calculatedWPM: Double = 0.0
        
        if totalWordsInWindow > 0 && totalSpeechDurationInWindow > 0.1 {
            calculatedWPM = (Double(totalWordsInWindow) / totalSpeechDurationInWindow) * 60.0
        }

        self.wpm = (self.wpm * (1.0 - smoothingFactor)) + (calculatedWPM * smoothingFactor)
        
        if self.wpm > 0 {
            self.wpmHistory.append((timestamp: totalDuration, wpm: self.wpm))
        }
        
        let roundedWPM = self.wpm.rounded()
        print("Rounded wpm : \(roundedWPM)")
        
        if roundedWPM >= wpmIdealMin && roundedWPM <= wpmIdealMax {
            self.tempoLabel = "Tempo Ideal"
            self.tempoRating = 3
        } else if (roundedWPM >= wpmCukupMin && roundedWPM < wpmIdealMin) || (roundedWPM > wpmIdealMax && roundedWPM <= wpmCukupMax) {
            self.tempoLabel = "Tempo Cukup"
            self.tempoRating = 2
        } else if roundedWPM < wpmCukupMin {
            self.tempoLabel = "Tempo Lambat"
            self.tempoRating = 1
        } else {
            self.tempoLabel = "Tempo Cepat"
            self.tempoRating = 1
        }
    }
    
    func clearResults() {
        self.wpm = 0.0
        self.tempoLabel = "..."
        self.wordHistory = []
        self.tempoRating = 0
        self.wpmHistory.removeAll()
    }
}
