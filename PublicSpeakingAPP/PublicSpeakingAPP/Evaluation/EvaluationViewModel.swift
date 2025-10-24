//
//  EvaluationProcessor.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 21/10/25.
//

import Foundation

@MainActor
struct EvaluationViewModel {
    
    static func process(
        tempoVM: TempoViewModel,
        textAnalyzerVM: TextFrequencyAnalyzerViewModel,
        intonationVM: IntonationAnalyzerViewModel,
        duration: TimeInterval
    ) -> EvaluationModel {
        
        let (tempoGrade, tempoFeedback, tempoScore) = gradeTempo(wpm: tempoVM.wpm)
        let (fillerGrade, fillerFeedback, fillerCount, fillerWPM, fillerScore) = gradeFillerWords(
            counts: textAnalyzerVM.fillerWordCount,
            duration: duration
        )
        let (intonationGrade, intonationFeedback, intonationScore) = gradeIntonation(stdDev: intonationVM.standardDeviation)
        
        // Dummy Data
        let eyeContactScore = 0.5
        let eyeContactGrade = "C"
        let eyeContactFeedback = "Kontak mata belum dianalisis"

        // Rata-rata Nilai
        let allScores = [tempoScore, fillerScore, intonationScore, eyeContactScore]
        let overallScore = allScores.reduce(0, +) / Double(allScores.count)
        let overallGrade = percentageToGrade(overallScore * 100)
        
        // Dummy AI Feedback
        let aiFeedback = "Secara keseluruhan, tempo Anda \(tempoFeedback.lowercased()) dan intonasi Anda \(intonationFeedback.lowercased()). Anda menggunakan \(fillerCount) kata pengisi."
        
        return EvaluationModel(
            durationInSeconds: duration,
            overallGrade: overallGrade,
            overallScore: overallScore * 100,
            aiFeedback: aiFeedback,
            tempoWPM: tempoVM.wpm,
            tempoGrade: tempoGrade,
            tempoFeedback: tempoFeedback,
            fillerWordTotalCount: fillerCount,
            fillerWordsPerMinute: fillerWPM,
            fillerWordGrade: fillerGrade,
            fillerWordFeedback: fillerFeedback,
            intonationStdDev: intonationVM.standardDeviation,
            intonationGrade: intonationGrade,
            intonationFeedback: intonationFeedback,
            eyeContactScore: eyeContactScore * 100,
            eyeContactGrade: eyeContactGrade,
            eyeContactFeedback: eyeContactFeedback
        )
    }
    
    private static func gradeTempo(wpm: Double) -> (String, String, Double) {
        if wpm < 60.0 {
            return ("D", "Tempo Lambat", 0.25)
        } else if wpm >= 60.0 && wpm <= 80.0 {
            return ("A", "Tempo Ideal", 1.0)
        } else {
            return ("C", "Tempo Cepat", 0.5)
        }
    }
    
    private static func gradeFillerWords(counts: [String: Int], duration: TimeInterval) -> (String, String, Int, Double, Double) {
        let totalCount = counts.values.reduce(0, +)
        let minutes = duration / 60.0
        
        guard minutes > 0 else {
            return ("A", "OK", totalCount, 0.0, 1.0)
        }
        
        let fillerWPM = Double(totalCount) / minutes
        
        if fillerWPM <= 5.0 {
            return ("A", "Sangat Baik", totalCount, fillerWPM, 1.0)
        } else if fillerWPM <= 10.0 {
            return ("B", "Cukup Baik", totalCount, fillerWPM, 0.75)
        } else if fillerWPM <= 15.0 {
            return ("C", "Perlu Latihan", totalCount, fillerWPM, 0.5)
        } else {
            return ("D", "Terlalu Banyak", totalCount, fillerWPM, 0.25)
        }
    }

    private static func gradeIntonation(stdDev: Double) -> (String, String, Double) {
        if stdDev < 18.0 {
            return ("D", "Cenderung Datar", 0.25)
        } else if stdDev < 22.0 {
            return ("C", "Agak Bervariasi", 0.5)
        } else if stdDev < 25.0 {
            return ("B", "Cukup Bervariasi", 0.75)
        } else if stdDev >= 25.0 && stdDev <= 30.0 {
            return ("A", "Sangat Bervariasi", 0.75)
        } else {
            return ("D", "Terlalu Berlebihan", 1.0)
        }
    }

    private static func percentageToGrade(_ percentage: Double) -> String {
        if percentage >= 90.0 {
            return "A"
        } else if percentage >= 75.0 {
            return "B"
        } else if percentage >= 50.0 {
            return "C"
        } else {
            return "D"
        }
    }
    
    private static func gradeToPercentage(_ grade: String) -> Double {
        switch grade.uppercased() {
        case "A": return 1.0
        case "B": return 0.75
        case "C": return 0.5
        case "D": return 0.25
        default: return 0.0
        }
    }
}
