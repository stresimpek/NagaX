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
    
    private var strukturKalimatEvaluatorNote: AttributedString {
        let count = ineffectiveSentenceCount
        let duration = settings.durationMinutes

        return try! AttributedString(markdown: "Kamu ada **\(count)** kalimat yang ga efektif. Yuk cek rekomendasi perbaikannya! Kamu mungkin mau potong beberapa kata agar pesan lebih ringkas dan efektif.")

    }
    
    private var articulationEvaluatorNote: AttributedString {
        let count = articulationCount
        let total = articulationTotal > 0 ? articulationTotal : 100
        let clearWords = total - count
        let percentage = total > 0 ? Int((Double(clearWords) / Double(total)) * 100) : 0

        return try! AttributedString(markdown: "Kamu ada **\(count)** dari **\(total)** kata tertangkap kurang jelas. Kamu bisa cek kata-kata yang kurang jelas, lalu coba ucap ulang untuk refleksi.")
    }
    
    private var fillerWordEvaluatorNote: AttributedString {
        let count = fillerWordCount
        
        return try! AttributedString(markdown: "Kata seperti **“eh”, “uh”, “hm”** nyelip **\(count)** kali dalam presentasimu! Kamu bisa coba tarik nafas dan beri jeda untuk mengurangi kata pengisi. ")
    }

    private var tempoEvaluatorNote: AttributedString {
        let wpm = Int(result.tempoWPM)

        switch result.tempoGrade {
        case "A":
            return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di **zona aman**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
        case "B":
            if wpm < 100 {
                return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di **rentang agak lambat**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
            } else {
                return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di **rentang agak cepat**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
            }
        case "C":
            if wpm < 80 {
                return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di **rentang sangat lambat**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
            } else {
                return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di **rentang sangat cepat**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
            }
        default:
            return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di **rentang ...**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
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
            return try! AttributedString(markdown: "Intonasimu paling sering **terdengar berdinamika**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
        case "B":
            return try! AttributedString(markdown: "Intonasimu paling sering **terdengar cukup bervariasi**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
        case "C":
            return try! AttributedString(markdown: "Intonasimu paling sering **terdengar cenderung datar**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
        default:
            if avgHz > 0 {
                return try! AttributedString(markdown: "Intonasimu paling sering **terdengar ...**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
            } else {
                return try! AttributedString(markdown: "Intonasimu paling sering **terdengar ...**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
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
    
    var currentGuidance: [AttributedString] {
        switch currentTab {
        case .strukturKalimat:
            return [
                try! AttributedString(markdown: "**Jika ada dua kata yang punya makna sama**, tandai dan coba hapus salah satu kata dan lihat apakah maknanya berubah."),
                try! AttributedString(markdown: "Saat menyusun kalimat, coba pikir kembali: “**Apakah ide ini udah ada di kalimat sebelumnya?**“")
            ]
        case .artikulasi:
            return [
                try! AttributedString(markdown: "Ucapkan kata dengan **ritme tenang dan stabil**."),
                try! AttributedString(markdown: "Latihan baca lantang & gerakkan mulut jelas, rekam untuk evaluasi."),
                try! AttributedString(markdown: "Hindari bicara tanpa jeda untuk bernafas.")
            ]
        case .fillerWords:
            return [
                try! AttributedString(markdown: "Setiap ingin bilang kata pengisi, cobalah **ganti dengan micro-pause**."),
                try! AttributedString(markdown: "Buat **daftar kata kunci/frasa transisi** yang bisa dipakai untuk menyambung ide."),
                try! AttributedString(markdown: "Latihan **menjelaskan ide dalam diam dulu** sebelum ngomong.")
            ]
        case .tempo:
            return [
                try! AttributedString(markdown: "Tempo **tenang**, cocok untuk **menekankan poin penting/pesan emosional**."),
                try! AttributedString(markdown: "Tempo **energik**, cocok untuk **menunjukkan antusiasme**."),
                try! AttributedString(markdown: "Tempo rentang **cepat/lambat** bisa membuat penyampaian **kurang jelas**.")
            ]
        case .intonasi:
            return [
                try! AttributedString(markdown: "Gunakan **nada naik** saat menyebut **kata kunci, poin utama, & pertanyaan**."),
                try! AttributedString(markdown: "Gunakan **nada turun** di **kalimat akhir**, jadi terdengar tegas & selesai."),
                try! AttributedString(markdown: "Konten antusias = naikkan energi suara. Reflektif = turunkan nada jadi tenang.")
            ]
        case .kontakMata:
            return [
                try! AttributedString(markdown: "Mata sering menatap ke **langit, lantai, dan catatan** memberi **kesan ragu**."),
                try! AttributedString(markdown: "Jika gugup, coba **pilih titik fokus** lain seperti **dahi**."),
                try! AttributedString(markdown: "**Bagi audiens jadi tiga zona** (kiri, tengah, kanan) **tatap bergantian**, agar seluruh audiens merasa dilibatkan. Idealnya, menatap seseorang = **3-5 detik**.")
            ]
        }
    }
    
    var currentHasScrollableContent: Bool {
        return currentTab == .strukturKalimat
    }
    
    func toggleFullScreen() {
        showFullScreen.toggle()
    }
    
    var ineffectiveSentenceCount: Int {
        let components = DiffComponent.generate(
            original: fullTranscript,
            new: sentenceAnalysisResult
        )
        return components.filter { $0.type == .deleted }.count
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

extension NewEvaluationViewModel {
    
    func iconName(for tab: EvaluationTab) -> String {
        switch tab {
        case .tempo: return "AspectTempo"
        case .intonasi: return "AspectIntonasi"
        case .fillerWords: return "AspectFiller"
        case .kontakMata: return "AspectEye"
        case .artikulasi: return "AspectArtikulasi"
        case .strukturKalimat: return "AspectStruktur"
        }
    }
    
    func getSummaryNote(for tab: EvaluationTab) -> AttributedString {
        switch tab {
        case .strukturKalimat:
            let count = ineffectiveSentenceCount
            return try! AttributedString(markdown: "Kamu ada **\(count)** kalimat yang terdeteksi kurang efektif.")
            
        case .artikulasi:
            let count = articulationCount
            let total = articulationTotal
            return try! AttributedString(markdown: "Kamu ada **\(count)** dari **\(total)** kata yang tertangkap kurang jelas.")
            
        case .fillerWords:
            let count = fillerWordCount
            return try! AttributedString(markdown: "Kata seperti “eh”, “uh”, “hm” nyelip **\(count)** kali.")
            
        case .tempo:
            let wpm = Int(result.tempoWPM)
            switch result.tempoGrade {
            case "A":
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **ideal**.")
            case "B":
                let status = wpm < 100 ? "tenang" : "energik"
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **\(status)**.")
            case "C":
                let status = wpm < 80 ? "lambat" : "cepat"
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **\(status)**.")
            default:
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **kurang pas**.")
            }
            
        case .intonasi:
            switch result.intonationGrade {
            case "A":
                return try! AttributedString(markdown: "Intonasimu paling sering terdeteksi **dinamis**.")
            case "B":
                return try! AttributedString(markdown: "Intonasimu paling sering terdeteksi **cukup variatif**.")
            case "C":
                return try! AttributedString(markdown: "Intonasimu paling sering terdeteksi **cenderung datar**.")
            default:
                return try! AttributedString(markdown: "Intonasi perlu latihan.")
            }
            
        case .kontakMata:
            switch result.eyeContactGrade {
            case "A":
                return try! AttributedString(markdown: "Kontak mata **sangat baik**.")
            case "B":
                return try! AttributedString(markdown: "Kontak mata **cukup baik**.")
            default:
                return try! AttributedString(markdown: "Kontak mata **perlu fokus**.")
            }
        }
    }

    var summaryItems: [EvaluationSummaryItem] {
        return availableTabs.map { tab in
            EvaluationSummaryItem(
                iconName: iconName(for: tab),
                text: getSummaryNote(for: tab),
                tab: tab
            )
        }
    }
}
