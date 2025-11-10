//
//  NewEvaluationViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 05/11/25.
//

import Foundation

enum EvaluationTab {
    case strukturKalimat
    case artikulasi
    case intonasi
    case fillerWords
    case tempo
    case kontakMata
}

class NewEvaluationViewModel: ObservableObject {
    let result: EvaluationModel
    let fullTranscript: String
    let settings: PracticeSettings
    
    @Published var selectedTabIndex: Int = 0
    @Published var showFullScreen: Bool = false
    
    var availableTabs: [EvaluationTab] {
        var tabs: [EvaluationTab] = [.strukturKalimat, .artikulasi]
        
        if settings.selectedAspects.contains(.intonasi) {
            tabs.append(.intonasi)
        }
        if settings.selectedAspects.contains(.fillerWords) {
            tabs.append(.fillerWords)
        }
        if settings.selectedAspects.contains(.tempo) {
            tabs.append(.tempo)
        }
        if settings.selectedAspects.contains(.kontakMata) {
            tabs.append(.kontakMata)
        }
        
        return tabs
    }
    
    var currentTab: EvaluationTab {
        availableTabs[selectedTabIndex]
    }
    
    init(result: EvaluationModel, fullTranscript: String, settings: PracticeSettings) {
        self.result = result
        self.fullTranscript = fullTranscript
        self.settings = settings
    }
    
    func selectTab(_ index: Int) {
        selectedTabIndex = index
    }
    
    func tabTitle(for tab: EvaluationTab) -> String {
        switch tab {
        case .strukturKalimat: return "STRUKTUR KALIMAT"
        case .artikulasi: return "ARTIKULASI"
        case .intonasi: return "INTONASI"
        case .fillerWords: return "FILLER WORDS"
        case .tempo: return "TEMPO"
        case .kontakMata: return "KONTAK MATA"
        }
    }
    
    var currentEvaluatorNote: String {
        switch currentTab {
        case .strukturKalimat:
            return "Kamu ada 11 kalimat yang ga efektif dari 5 menit presentasimu, kayak lagi ngejar jumlah kata skripsi. Potong kata-kata yang gak perlu!"
        case .artikulasi:
            return "Selamat, 97 dari 100 kata kamu akhirnya terdengar jelas. Hasil yang lumayan, jangan sampai nilainya turun berikutnya. Pertahankan!"
        case .fillerWords:
            return "Bagus. Latihanmu ternyata ada hasilnya. Hanya \(result.fillerWordTotalCount) kata pengisi dalam 1 menit. Pertahankan!"
        case .tempo:
            return "OK! Kecepatan bicaramu masuk zona aman \(Int(result.tempoWPM)) wpm. Pertahankan ritme ini, jangan tiba-tiba berubah jadi komentator sepak bola."
        case .intonasi:
            return result.intonationFeedback
        case .kontakMata:
            return result.eyeContactFeedback
        }
    }
    
    var currentSectionTitle: String {
        switch currentTab {
        case .strukturKalimat:
            return "Detected Issues & Correction (Highlighted in Transcript):"
        case .artikulasi, .fillerWords:
            return "Detected Issues (Highlighted in Transcript):"
        case .tempo, .intonasi:
            return "Graph:"
        case .kontakMata:
            return "Info:"
        }
    }
    
    var currentHasScrollableContent: Bool {
        return currentTab == .strukturKalimat
    }
    
    func toggleFullScreen() {
        showFullScreen.toggle()
    }
}
