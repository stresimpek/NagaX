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
        eyeContactVM: EyeContactViewModel,
        videoURL: URL?,
        duration: TimeInterval,
        fullTranscript: String,
        articulationCount: Int,
        articulationTotal: Int
    ) -> EvaluationModel {
        
        let (tempoGrade, tempoFeedback, tempoScore) = gradeTempo(wpm: tempoVM.wpm)
        
        let (fillerGrade, fillerFeedback, fillerCount, fillerWPM, fillerScore) = gradeFillerWords(
            totalCount: fillerWordVM.totalFillerCount,
            duration: duration
        )
        
        let finalStd = intonationVM.calculateFinalStandardDeviation()
        let (intonationGrade, intonationFeedback, intonationScore) = gradeIntonation(stdDev: finalStd)
        
        let stdSeries = intonationVM.stdTimeline.map {
            PitchPoint(time: $0.time, pitch: $0.value)
        }
        let pitchSeries: [PitchPoint] = stdSeries
        
        let tempoSeries: [TempoPoint] = tempoVM.wpmHistory
            .map { TempoPoint(time: $0.timestamp, wpm: $0.wpm) }
            .sorted { $0.time < $1.time }
        
        let (eyeContactGrade, eyeContactFeedback, eyeContactScoreVal) = gradeEyeContact(
            rating: eyeContactVM.eyeContactRating,
            issueCount: eyeContactVM.issueHistory.count
        )
        
        let allScores = [tempoScore, fillerScore, intonationScore, eyeContactScoreVal]
        let overallScore = allScores.reduce(0, +) / Double(allScores.count)
        let overallGrade = percentageToGrade(overallScore * 100)
        
        let aiFeedback = "Secara keseluruhan, tempo Anda \(tempoFeedback.lowercased()) dan intonasi Anda \(intonationFeedback.lowercased()). Kontak mata \(eyeContactFeedback.lowercased())."
        
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
            
            eyeContactScore: eyeContactScoreVal * 100,
            eyeContactGrade: eyeContactGrade,
            eyeContactFeedback: eyeContactFeedback,
            videoURL: videoURL,
            gazeEvents: eyeContactVM.issueHistory,
            
            articulationCount: articulationCount,
            articulationTotal: articulationTotal
        )
    }
    
    private static func gradeEyeContact(rating: Int, issueCount: Int) -> (String, String, Double) {
        if rating == 3 {
            return ("A", "Sangat terjaga", 1.0)
        } else {
            let score = 0.5
            let feedback = "Terdeteksi \(issueCount) gangguan"
            return ("C", feedback, score)
        }
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
