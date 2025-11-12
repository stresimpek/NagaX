//
//  NewEvaluationViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 05/11/25.
//

import Foundation
import Combine

enum EvaluationTab {
    case strukturKalimat
    case artikulasi
    case intonasi
    case fillerWords
    case tempo
    case kontakMata
}

enum DiffType {
    case same
    case deleted
    case added
}

struct DiffComponent: Identifiable, Hashable {
    let id = UUID()
    let text: String
    var type: DiffType
    
    static func generate(original: String, new: String) -> [DiffComponent] {
        let words1 = original.splitByWord()
        let newSpace = " " + new
        let words2 = newSpace.splitByWord()
        let diff = words2.difference(from: words1)
        
        var components: [DiffComponent] = []
        var currentComponents = words1.map { DiffComponent(text: $0, type: .same) }

        for change in diff.removals.reversed() {
            switch change {
            case .remove(let offset, _, _):
                if currentComponents.indices.contains(offset) {
                    currentComponents[offset].type = .deleted
                }
            case .insert:
                break
            }
        }
        
        for change in diff.insertions.reversed() {
            switch change {
            case .insert(let offset, let element, _):
                let newComponent = DiffComponent(text: element, type: .added)
              
                var targetInsertionIndex = 0
                var postRemovalCounter = 0
                var found = false
                
                for (index, component) in currentComponents.enumerated() {
                    if postRemovalCounter == offset {
                        targetInsertionIndex = index
                        found = true
                        break
                    }
                    if component.type != .deleted {
                        postRemovalCounter += 1
                    }
                }
                if !found {
                    targetInsertionIndex = currentComponents.count
                }
                currentComponents.insert(newComponent, at: targetInsertionIndex)
                
            case .remove:
                break
            }
        }
        
        if components.isEmpty {
            for component in currentComponents {
                if let last = components.last, last.type == component.type {
                    let mergedComponent = DiffComponent(text: last.text + component.text, type: last.type)
                    components[components.count - 1] = mergedComponent
                } else {
                    components.append(component)
                }
            }
        }
        
        return components
    }
}

class NewEvaluationViewModel: ObservableObject {
    let result: EvaluationModel
    let fullTranscript: String
    let settings: PracticeSettings
    
    let sentenceAnalysisResult: String
    
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
    
    init(result: EvaluationModel, fullTranscript: String, sentenceAnalysisResult: String, settings: PracticeSettings) {
        self.result = result
        self.fullTranscript = fullTranscript
        self.sentenceAnalysisResult = sentenceAnalysisResult
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

extension String {
    func splitByWord() -> [String] {
        let regex = try? NSRegularExpression(pattern: "\\s+|\\S+")
        let range = NSRange(location: 0, length: self.utf16.count)
        
        return (regex?.matches(in: self, options: [], range: range).map {
            (self as NSString).substring(with: $0.range)
        })!
    }
}
