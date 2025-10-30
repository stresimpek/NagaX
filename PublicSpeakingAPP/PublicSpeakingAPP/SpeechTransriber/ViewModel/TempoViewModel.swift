//
//  TempoViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 20/10/25.
//

import Foundation
import WhisperKit
import Combine

@MainActor
final class TempoViewModel: ObservableObject {
    
    @Published var wpm: Double = 0.0
    @Published var tempoLabel: String = "..."
    @Published var tempoRating: Int = 0

    private let wpmIdealMin: Double = 100.0
    private let wpmIdealMax: Double = 150.0
    private let wpmCukupMin: Double = 80.0
    private let wpmCukupMax: Double = 170.0
    
    private var wordHistory: [(endTime: TimeInterval, duration: TimeInterval)] = []
    private let windowSize: TimeInterval = 10.0
    private let smoothingFactor: Double = 0.3

//    func updateTempo(text: String, duration: TimeInterval) {
//        // Guard clause untuk mencegah pembagian dengan nol
//        guard duration > 1.0 else {
//            self.wpm = 0.0
//            self.tempoLabel = "..."
//            return
//        }
//        
//        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
//        guard wordCount > 0 else {
//            self.wpm = 0.0
//            self.tempoLabel = "0"
//            return
//        }
//
//        let calculatedWPM = (Double(wordCount) / duration) * 60.0
//        
//        self.wpm = calculatedWPM
//        
//        if calculatedWPM < wpmLambat {
//            self.tempoLabel = "Tempo Lambat"
//        } else if calculatedWPM > wpmCepat {
//            self.tempoLabel = "Tempo Cepat"
//        } else {
//            self.tempoLabel = "Tempo Ideal"
//        }
//    }
    
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
        
        let roundedWPM = self.wpm.rounded()
        
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
    }
}
