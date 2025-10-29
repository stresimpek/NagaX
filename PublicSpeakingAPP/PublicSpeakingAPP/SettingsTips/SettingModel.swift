//
//  SettingModel.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 26/10/25.
//

import Foundation

// Definisikan ini di file global agar bisa diakses semua View/VM
struct AspectOption: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    
    // Definisikan sebagai static var agar mudah diakses
    static let intonasi = AspectOption(id: "intonasi", title: "Intonasi", systemImage: "waveform")
    static let fillerWords = AspectOption(id: "fillerWords", title: "Filler Words", systemImage: "text.badge.plus")
    static let tempo = AspectOption(id: "tempo", title: "Tempo", systemImage: "metronome")
    static let kontakMata = AspectOption(id: "kontakMata", title: "Kontak Mata", systemImage: "eye")
    
    // Array untuk ForEach di SettingsView
    static let allOptions: [AspectOption] = [.intonasi, .fillerWords, .tempo, .kontakMata]
}

// Struct untuk menampung semua pilihan dari SettingsView
struct PracticeSettings: Hashable {
    let durationMinutes: Int
    let distractionLevel: Double
    let enableQnA: Bool
    let randomTopic: Bool
    let selectedAspects: Set<AspectOption>
}
