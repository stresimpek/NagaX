//
//  EvaluationResult.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 21/10/25.
//

import Foundation

struct EvaluationModel: Identifiable, Hashable {
    let id: UUID
    let presentationDate: Date
    let durationInSeconds: TimeInterval
    
    let overallGrade: String
    let overallScore: Double
    let aiFeedback: String

    // Tempo
    let tempoWPM: Double
    let tempoGrade: String
    let tempoFeedback: String
    
    // Kata Pengisi (Filler Words)
    let fillerWordTotalCount: Int
    let fillerWordsPerMinute: Double
    let fillerWordGrade: String
    let fillerWordFeedback: String

    // Intonasi
    let intonationStdDev: Double
    let intonationGrade: String
    let intonationFeedback: String
    
    let pitchSeries: [PitchPoint]
    let tempoSeries: [TempoPoint]

    // Kontak Mata (Dummy)
    let eyeContactScore: Double
    let eyeContactGrade: String
    let eyeContactFeedback: String

    init(
        id: UUID = UUID(),
        presentationDate: Date = Date(),
        durationInSeconds: TimeInterval = 0.0,
        overallGrade: String = "D",
        overallScore: Double = 0.0,
        aiFeedback: String = "Belum ada data. Silakan mulai latihan pertama Anda!",
        tempoWPM: Double = 0.0,
        tempoGrade: String = "D",
        tempoFeedback: String = "N/A",
        fillerWordTotalCount: Int = 0,
        fillerWordsPerMinute: Double = 0.0,
        fillerWordGrade: String = "D",
        fillerWordFeedback: String = "N/A",
        intonationStdDev: Double = 0.0,
        intonationGrade: String = "D",
        intonationFeedback: String = "N/A",
        pitchSeries: [PitchPoint] = [],
        tempoSeries: [TempoPoint] = [],
        eyeContactScore: Double = 0.0,
        eyeContactGrade: String = "D",
        eyeContactFeedback: String = "N/A"
    ) {
        self.id = id
        self.presentationDate = presentationDate
        self.durationInSeconds = durationInSeconds
        self.overallGrade = overallGrade
        self.overallScore = overallScore
        self.aiFeedback = aiFeedback
        self.tempoWPM = tempoWPM
        self.tempoGrade = tempoGrade
        self.tempoFeedback = tempoFeedback
        self.fillerWordTotalCount = fillerWordTotalCount
        self.fillerWordsPerMinute = fillerWordsPerMinute
        self.fillerWordGrade = fillerWordGrade
        self.fillerWordFeedback = fillerWordFeedback
        self.intonationStdDev = intonationStdDev
        self.intonationGrade = intonationGrade
        self.intonationFeedback = intonationFeedback
        self.pitchSeries = pitchSeries
        self.tempoSeries = tempoSeries
        self.eyeContactScore = eyeContactScore
        self.eyeContactGrade = eyeContactGrade
        self.eyeContactFeedback = eyeContactFeedback
    }
}

