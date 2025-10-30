//
//  SettingModel.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 26/10/25.
//

import Foundation

struct AspectOption: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    
    static let intonasi = AspectOption(id: "intonasi", title: "Intonasi", systemImage: "waveform")
    static let fillerWords = AspectOption(id: "fillerWords", title: "Filler Words", systemImage: "text.badge.plus")
    static let tempo = AspectOption(id: "tempo", title: "Tempo", systemImage: "metronome")
    static let kontakMata = AspectOption(id: "kontakMata", title: "Kontak Mata", systemImage: "eye")
    
    static let allOptions: [AspectOption] = [.intonasi, .fillerWords, .tempo, .kontakMata]
}

struct PracticeSettings: Hashable {
    let durationMinutes: Int
    let distractionLevel: Double
    let enableQnA: Bool
    let randomTopic: Bool
    let selectedAspects: Set<AspectOption>
}
