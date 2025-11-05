//
//  NewEvaluationViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 05/11/25.
//


import SwiftUI
import Combine

@MainActor
class NewEvaluationViewModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var showFullScreen = false
    
    let result: EvaluationModel
    let fullTranscript: String
    let settings: PracticeSettings
    
    let tabs = ["STRUKTUR KALIMAT", "ARTIKULASI", "FILLER WORDS", "TEMPO", "INTONASI", "KONTAK MATA"]
    
    init(result: EvaluationModel, fullTranscript: String, settings: PracticeSettings) {
        self.result = result
        self.fullTranscript = fullTranscript
        self.settings = settings
    }
    
    // MARK: - Tab Content Data
    func getEvaluatorNote(for tabIndex: Int) -> String {
        switch tabIndex {
        case 0: // Struktur Kalimat
            return "Kamu ada 11 kalimat yang ga efektif dari 5 menit presentasimu, kayak lagi ngejar jumlah kata skripsi. Potong kata-kata yang gak perlu!"
        case 1: // Artikulasi
            return "Selamat, 97 dari 100 kata kamu akhirnya terdengar jelas. Hasil yang lumayan, jangan sampai nilainya turun berikutnya. Pertahankan!"
        case 2: // Filler Words
            return "Bagus. Latihanmu ternyata ada hasilnya. Hanya \(result.fillerWordTotalCount) kata pengisi dalam 1 menit. Pertahankan!"
        case 3: // Tempo
            return "OK! Kecepatan bicaramu masuk zona aman \(Int(result.tempoWPM)) wpm. Pertahankan ritme ini, jangan tiba-tiba berubah jadi komentator sepak bola."
        case 4: // Intonasi
            return result.intonationFeedback
        case 5: // Kontak Mata
            return result.eyeContactFeedback
        default:
            return "Belum ada data untuk tab ini."
        }
    }
    
    func getSectionTitle(for tabIndex: Int) -> String {
        switch tabIndex {
        case 0:
            return "Detected Issues & Correction (Highlighted in Transcript):"
        case 1, 2:
            return "Detected Issues (Highlighted in Transcript):"
        case 3, 4:
            return "Graph:"
        default:
            return "Info:"
        }
    }
    
    func hasScrollableContent(for tabIndex: Int) -> Bool {
        return tabIndex == 0 // Only Struktur Kalimat has scrollable transcript
    }
    
    // MARK: - Actions
    func selectTab(_ index: Int) {
        selectedTab = index
    }
    
    func toggleFullScreen() {
        showFullScreen.toggle()
    }
}