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
        intonationVM: IntonationAnalyzerViewModel,
        fillerWordVM: FillerWordViewModel,
        duration: TimeInterval,
        // ADDED PARAMETERS
        gazeUpCount: Int,
        gazeDownCount: Int,
        videoURL: URL?,
        gazeEvents: [GazeLogItem]
    ) -> EvaluationModel {
        
        let (tempoGrade, tempoFeedback, tempoScore) = gradeTempo(wpm: tempoVM.wpm)
        let (fillerGrade, fillerFeedback, fillerCount, fillerWPM, fillerScore) = gradeFillerWords(
            totalCount: fillerWordVM.totalFillerCount,
            duration: duration
        )
        
        let finalStd = intonationVM.calculateFinalStandardDeviation()
        let (intonationGrade, intonationFeedback, intonationScore) = gradeIntonation(stdDev: finalStd)
        
        let stdSeries = intonationVM.stdTimeline.map {
            PitchPoint(time: $0.time, pitch: $0.value) // pitch = std dev (semitone)
        }
        
        let pitchSeries: [PitchPoint] = stdSeries
        
        let tempoSeries: [TempoPoint] = tempoVM.wpmHistory
            .map { TempoPoint(time: $0.timestamp, wpm: $0.wpm) }
            .sorted { $0.time < $1.time }
        
        // Eye Contact Logic
        // Simple grading logic based on count (Bisa disesuaikan)
        let totalGazeIssues = gazeUpCount + gazeDownCount
        let eyeContactScore: Double
        let eyeContactGrade: String
        let eyeContactFeedback: String
        
        if totalGazeIssues == 0 {
            eyeContactScore = 1.0
            eyeContactGrade = "A"
            eyeContactFeedback = "Kontak mata sangat baik dan fokus."
        } else if totalGazeIssues < 5 {
            eyeContactScore = 0.75
            eyeContactGrade = "B"
            eyeContactFeedback = "Kontak mata cukup baik, namun ada beberapa distraksi."
        } else {
            eyeContactScore = 0.5
            eyeContactGrade = "C"
            eyeContactFeedback = "Perlu lebih fokus menjaga pandangan."
        }
        
        // Rata-rata Nilai
        let allScores = [tempoScore, fillerScore, intonationScore, eyeContactScore]
        let overallScore = allScores.reduce(0, +) / Double(allScores.count)
        let overallGrade = percentageToGrade(overallScore * 100)
        
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
            tempoSeries: tempoSeries,
            eyeContactScore: eyeContactScore * 100,
            eyeContactGrade: eyeContactGrade,
            eyeContactFeedback: eyeContactFeedback,
            // New Params
            totalGazeIssues: totalGazeIssues,
            videoURL: videoURL,
            gazeEvents: gazeEvents
        )
    }
    
    private static func gradeTempo(wpm: Double) -> (String, String, Double) {
        let roundedWPM = wpm.rounded()

        if roundedWPM >= 100.0 && roundedWPM <= 140.0 {
            return ("A", "Tempo Ideal", 1.0)
        } else if (roundedWPM >= 80.0 && roundedWPM < 100.0) ||
                  (roundedWPM > 140.0 && roundedWPM <= 160.0) {
             let feedback = (roundedWPM >= 80.0 && roundedWPM < 100.0) ? "Tempo Agak Lambat" : "Tempo Agak Cepat"
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
        if stdDev >= 2.5 && stdDev <= 4.5 {
            return ("A", "Sangat Dinamis", 1.0)
        } else if (stdDev >= 1.5 && stdDev < 2.5) || stdDev > 4.5 {
            let feedback = (stdDev > 4.5) ? "Agak Berlebihan" : "Cukup Dinamis"
            return ("B", feedback, 0.75)
        } else {
            return ("C", "Sangat Datar", 0.5)
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
