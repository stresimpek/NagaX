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
    let isEnabled: Bool
    
    static let pemborosanKata = AspectOption(id: "pemborosanKata", title: "Pemborosan Kata", systemImage: "AspectStruktur", isEnabled: false)
    static let artikulasi = AspectOption(id: "artikulasi", title: "Artikulasi", systemImage: "AspectArtikulasi", isEnabled: false)
    static let intonasi = AspectOption(id: "intonasi", title: "Intonasi", systemImage: "AspectIntonasi", isEnabled: true)
    static let tempo = AspectOption(id: "tempo", title: "Tempo", systemImage: "AspectTempo", isEnabled: true)
    static let fillerWords = AspectOption(id: "fillerWords", title: "Kata Jeda", systemImage: "AspectFiller", isEnabled: true)
    static let kontakMata = AspectOption(id: "kontakMata", title: "Kontak Mata", systemImage: "AspectEye", isEnabled: true)
    
    static let allOptions: [AspectOption] = [.intonasi, .fillerWords, .tempo, .kontakMata]
}

struct PracticeSettings: Hashable {
    let durationMinutes: Int
    let distractionLevel: Double
    let selectedAspects: Set<AspectOption>
}
