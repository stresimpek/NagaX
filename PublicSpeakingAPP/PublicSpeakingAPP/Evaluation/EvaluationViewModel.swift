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
//        textAnalyzerVM: TextFrequencyAnalyzerViewModel,
        intonationVM: IntonationAnalyzerViewModel,
        fillerWordVM: FillerWordViewModel,
        duration: TimeInterval
    ) -> EvaluationModel {
        
        let (tempoGrade, tempoFeedback, tempoScore) = gradeTempo(wpm: tempoVM.wpm)
        let (fillerGrade, fillerFeedback, fillerCount, fillerWPM, fillerScore) = gradeFillerWords(
            totalCount: fillerWordVM.totalFillerCount,
            duration: duration
        )
        
        let finalStd = intonationVM.calculateFinalStandardDeviation()
        let (intonationGrade, intonationFeedback, intonationScore) = gradeIntonation(stdDev: finalStd)
        
        let pitchSeries: [PitchPoint] = intonationVM.allPitchHistory
            .map { PitchPoint(time: $0.timestamp, pitch: $0.pitch) }
            .sorted { $0.time < $1.time }
        
        // Dummy Data
        let eyeContactScore = 0.5
        let eyeContactGrade = "C"
        let eyeContactFeedback = "Kontak mata belum dianalisis"
        
        // Rata-rata Nilai
        let allScores = [tempoScore, fillerScore, intonationScore]
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
            intonationStdDev: finalStd,
            intonationGrade: intonationGrade,
            intonationFeedback: intonationFeedback,
            pitchSeries: pitchSeries,
            eyeContactScore: eyeContactScore * 100,
            eyeContactGrade: eyeContactGrade,
            eyeContactFeedback: eyeContactFeedback
        )
    }
    
    private static func gradeTempo(wpm: Double) -> (String, String, Double) {
        let roundedWPM = wpm.rounded()

        if roundedWPM >= 100.0 && roundedWPM <= 150.0 {
            return ("A", "Tempo Ideal", 1.0)
        } else if (roundedWPM >= 80.0 && roundedWPM < 100.0) ||
                  (roundedWPM > 150.0 && roundedWPM <= 170.0) { 
             let feedback = (roundedWPM < 100.0) ? "Tempo Agak Lambat" : "Tempo Agak Cepat"
            return ("B", feedback, 0.75)
        } else {
            let feedback = (roundedWPM < 80.0) ? "Tempo Sangat Lambat" : "Tempo Sangat Cepat"
            return ("C", feedback, 0.5)
        }
    }
    
    private static func gradeFillerWords(totalCount: Int, duration: TimeInterval) -> (String, String, Int, Double, Double) {
        let minutes = duration / 60.0
        
        guard minutes > 0 else {
            return ("A", "Baik", totalCount, 0.0, 1.0)
        }
        
        let fillerWPM = Double(totalCount) / minutes
        
        if fillerWPM <= 5.0 {
            return ("A", "Baik", totalCount, fillerWPM, 1.0)
        } else if fillerWPM <= 10.0 {
            return ("B", "Acceptable", totalCount, fillerWPM, 0.75)
        } else {
            return ("C", "Distracting", totalCount, fillerWPM, 0.5)
        }
    }

    private static func gradeIntonation(stdDev: Double) -> (String, String, Double) {
        if stdDev >= 25.0 && stdDev <= 35.0 {
            return ("A", "Sangat Dinamis", 1.0)
        } else if stdDev >= 18.0 && stdDev < 25.0 {
            return ("B", "Cukup Bervariasi", 0.75)
        } else {
            let feedback = (stdDev < 18.0) ? "Cenderung Datar" : "Agak Berlebihan"
            return ("C", feedback, 0.5)
        }
    }

    private static func percentageToGrade(_ percentage: Double) -> String {
        if percentage >= 90.0 {
            return "A"
        } else if percentage >= 70.0 {
            return "B"
        } else {
            return "C"
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
