//
//  TempoViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 20/10/25.
//

import Foundation
import Combine

@MainActor
final class TempoViewModel: ObservableObject {
    
    @Published var wpm: Double = 0.0
    @Published var tempoLabel: String = "..."

    // Standar WPM Bahasa Indonesia
    private let wpmLambat: Double = 60.0
    private let wpmCepat: Double = 100.0

    func updateTempo(text: String, duration: TimeInterval) {
        // Guard clause untuk mencegah pembagian dengan nol
        guard duration > 1.0 else {
            self.wpm = 0.0
            self.tempoLabel = "..."
            return
        }
        
        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        guard wordCount > 0 else {
            self.wpm = 0.0
            self.tempoLabel = "0"
            return
        }

        let calculatedWPM = (Double(wordCount) / duration) * 60.0
        
        self.wpm = calculatedWPM
        
        if calculatedWPM < wpmLambat {
            self.tempoLabel = "Tempo Lambat"
        } else if calculatedWPM > wpmCepat {
            self.tempoLabel = "Tempo Cepat"
        } else {
            self.tempoLabel = "Tempo Ideal"
        }
    }
    
    func clearResults() {
        self.wpm = 0.0
        self.tempoLabel = "..."
    }
}
