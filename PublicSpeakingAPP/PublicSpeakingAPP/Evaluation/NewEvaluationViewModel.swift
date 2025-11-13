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
    
    @Published var articulationCount: Int = 0
    @Published var articulationTotal: Int = 0  // Add total

    @Published var fillerWordCount: Int = 0
    
    var availableTabs: [EvaluationTab] {
        var tabs: [EvaluationTab] = []
        
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
        
        tabs.append(.artikulasi)
        tabs.append(.strukturKalimat)
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
        case .strukturKalimat: return "PEMBOROSAN KATA"
        case .artikulasi: return "ARTIKULASI"
        case .intonasi: return "INTONASI"
        case .fillerWords: return "KATA JEDA"
        case .tempo: return "TEMPO"
        case .kontakMata: return "KONTAK MATA"
        }
    }
    
    var currentEvaluatorNote: AttributedString {
            switch currentTab {
            case .strukturKalimat:
                return strukturKalimatEvaluatorNote
            case .artikulasi:
                return articulationEvaluatorNote
            case .fillerWords:
                return fillerWordEvaluatorNote
            case .tempo:
                return tempoEvaluatorNote
            case .intonasi:
                return intonationEvaluatorNote
            case .kontakMata:
                return try! AttributedString(markdown: result.eyeContactFeedback)
            }
        }
    
    private var ineffectiveSentenceCount: Int {
        let components = DiffComponent.generate(
            original: fullTranscript,
            new: sentenceAnalysisResult
        )
        // Count deleted/changed components as ineffective parts
        return components.filter { $0.type == .deleted }.count
    }
    
    private var strukturKalimatEvaluatorNote: AttributedString {
        let count = ineffectiveSentenceCount
        let duration = settings.durationMinutes

        if count == 0 {
            return try! AttributedString(markdown: "Sempurna! Tidak ada pemborosan kata dalam presentasimu. Kamu sudah efisien!")
        } else if count <= 3 {
            return try! AttributedString(markdown: "Bagus! Hanya **\(count)** bagian yang kurang efektif dari **\(duration)** menit presentasimu. Terus pertahankan!")
        } else {
            return try! AttributedString(markdown: "Kamu ada **\(count)** bagian yang ga efektif dari **\(duration)** menit presentasimu, kayak lagi ngejar jumlah kata skripsi. Potong kata-kata yang gak perlu!")
        }
    }
    
    private var articulationEvaluatorNote: AttributedString {
        let count = articulationCount
        let total = articulationTotal > 0 ? articulationTotal : 100
        let clearWords = total - count
        let percentage = total > 0 ? Int((Double(clearWords) / Double(total)) * 100) : 0

        if count == 0 {
            return try! AttributedString(markdown: "Sempurna! Semua kata terdengar jelas (**\(clearWords)** dari **\(total)**). Artikulasimu sudah sangat baik!")
        }

        if percentage >= 95 {
            return try! AttributedString(markdown: "Selamat, **\(clearWords)** dari **\(total)** kata kamu terdengar jelas. Hasil yang lumayan, jangan sampai nilainya turun berikutnya. Pertahankan!")
        } else if percentage >= 85 {
            return try! AttributedString(markdown: "Lumayan! **\(count)** kata masih kurang jelas dari **\(total)** kata. Fokus pada artikulasi yang lebih tajam!")
        } else {
            return try! AttributedString(markdown: "Perlu perbaikan! **\(count)** kata tidak terdengar jelas dari **\(total)** kata. Latih artikulasi agar audiens lebih mudah memahami.")
        }
    }
    
    private var fillerWordEvaluatorNote: AttributedString {
        let count = fillerWordCount

        switch result.fillerWordGrade {
        case "A":
            return try! AttributedString(markdown: "Luar biasa! Hanya **\(count)** kata pengisi dalam presentasimu. Kamu sudah bicara seperti profesional. Pertahankan!")
        case "B":
            return try! AttributedString(markdown: "Bagus! Latihanmu ada hasilnya. **\(count)** kata pengisi masih dalam batas wajar. Terus tingkatkan!")
        case "C":
            return try! AttributedString(markdown: "Hati-hati! Kamu terlalu sering pakai kata pengisi. Dengan **\(count)** kata pengisi, ini bisa mengganggu audiens. Latih kesadaran diri saat berbicara!")
        default:
            return try! AttributedString(markdown: "Kamu ada **\(count)** kata pengisi dalam presentasimu.")
        }
    }

    private var tempoEvaluatorNote: AttributedString {
        let wpm = Int(result.tempoWPM)

        switch result.tempoGrade {
        case "A":
            return try! AttributedString(markdown: "Sempurna! Kecepatan bicaramu **\(wpm) wpm**—zona ideal untuk dipahami audiens. Pertahankan ritme ini!")
        case "B":
            return try! AttributedString(markdown: "OK! Kecepatan bicaramu **\(wpm) wpm** masuk zona aman. Pertahankan ritme ini, jangan tiba-tiba berubah jadi komentator sepak bola.")
        case "C":
            if wpm < 120 {
                return try! AttributedString(markdown: "Terlalu lambat! **\(wpm) wpm** bisa bikin audiens ngantuk. Naikkan sedikit tempomu agar lebih energik!")
            } else {
                return try! AttributedString(markdown: "Kebut banget! **\(wpm) wpm** terlalu cepat, audiens kesulitan mengikuti. Pelan-pelan saja, ini bukan lomba ngomong tercepat.")
            }
        default:
            return try! AttributedString(markdown: "Kecepatan bicaramu **\(wpm) wpm**. Pertahankan ritme yang nyaman untuk audiens.")
        }
    }

    private var averagePitchHz: Double {
        guard !result.pitchSeries.isEmpty else { return 0 }
        let sum = result.pitchSeries.reduce(0.0) { $0 + $1.pitch }
        return sum / Double(result.pitchSeries.count)
    }
    
    private var intonationEvaluatorNote: AttributedString {
        let avgHz = Int(averagePitchHz)

        switch result.intonationGrade {
        case "A":
            return try! AttributedString(markdown: "Bagus! Intonasimu bervariasi dan ekspresif (rata-rata **\(avgHz) Hz**). Audiens pasti terbantu memahami penekanan penting dalam presentasimu!")
        case "B":
            return try! AttributedString(markdown: "\(result.intonationFeedback) (rata-rata **\(avgHz) Hz**)")
        case "C":
            return try! AttributedString(markdown: "Intonasimu terlalu datar (rata-rata **\(avgHz) Hz**). Coba variasikan nada suaramu agar presentasi tidak terdengar monoton dan membosankan.")
        default:
            if avgHz > 0 {
                return try! AttributedString(markdown: "\(result.intonationFeedback) (rata-rata **\(avgHz) Hz**)")
            } else {
                return try! AttributedString(markdown: result.intonationFeedback)
            }
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
