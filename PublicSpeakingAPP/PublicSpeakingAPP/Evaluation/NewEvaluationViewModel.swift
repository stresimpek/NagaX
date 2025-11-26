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
        let words2 = new.splitByWord()
        let n = words1.count
        let m = words2.count
        // Build LCS table
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0..<n {
            for j in 0..<m {
                if words1[i] == words2[j] {
                    dp[i + 1][j + 1] = dp[i][j] + 1
                } else {
                    dp[i + 1][j + 1] = max(dp[i][j + 1], dp[i + 1][j])
                }
            }
        }
        // Reconstruct diff path
        var components: [DiffComponent] = []
        var i = n, j = m
        var ops: [(String, DiffType)] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && words1[i-1] == words2[j-1] {
                ops.append((words1[i-1], .same))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
                ops.append((words2[j-1], .added))
                j -= 1
            } else if i > 0 && (j == 0 || dp[i][j-1] < dp[i-1][j]) {
                ops.append((words1[i-1], .deleted))
                i -= 1
            }
        }
        // Hasil ops di-reverse karena proses dari belakang
        for (word, type) in ops.reversed() {
            components.append(DiffComponent(text: word, type: type))
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
    @Published var articulationCalculated: Bool = false

    @Published var fillerWordCount: Int = 0     
    @Published var fillerWordCalculated: Bool = false
    
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
        self.fillerWordCount = result.fillerWordTotalCount
        
        self.articulationCount = result.articulationCount
        self.articulationTotal = result.articulationTotal
        
        self.articulationCalculated = true
        self.fillerWordCalculated = true
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

        return try! AttributedString(markdown: "Kamu ada **\(count)** kata yang ga efektif. Yuk cek rekomendasi perbaikannya! Kamu mungkin mau potong beberapa kata agar pesan lebih ringkas dan efektif.")

    }
    
    private var articulationEvaluatorNote: AttributedString {
        let count = articulationCount
        let total = articulationTotal
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
            let status = wpm < 100 ? "agak lambat" : "agak cepat"
                return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di rentang **\(status)**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
        
        case "C":
            let status = wpm < 80 ? "sangat lambat" : "sangat cepat"
                
                return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di rentang **\(status)**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
            
        default:
            return try! AttributedString(markdown: "Selama presentasi, tempo bicaranya paling sering ada di rentang **kurang pas**. Yuk cek tips dan rekaman, kapan ritme ini paling cocok sama pesan yang kamu bawa.")
        }
    }

    private var averagePitchHz: Double {
        guard !result.pitchSeries.isEmpty else { return 0 }
        let sum = result.pitchSeries.reduce(0.0) { $0 + $1.pitch }
        return sum / Double(result.pitchSeries.count)
    }
    
    private var intonationEvaluatorNote: AttributedString {
        let finalstd = result.intonationStdDev

    
            
        if finalstd < 1.5 {
            return try! AttributedString(markdown: "Intonasimu paling sering terdengar **cenderung datar**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
        }
        else if finalstd <= 2.5 {
            return try! AttributedString(markdown: "Intonasimu paling sering terdengar **cukup bervariasi**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
        }
        else if finalstd <= 4.5 {
            return try! AttributedString(markdown: "Intonasimu paling sering terdengar **sangat bervariasi**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
        }
        else {
                return try! AttributedString(markdown: "Intonasimu paling sering terdengar **agak berlebihan**. Yuk cek tips & rekaman, lihat bagian mana yang bisa kamu mainkan naik-turun suaranya sesuai pesan yang dibawa.")
            
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
        
        // Filter out deleted words, excluding whitespace
        let deletedCount = components.filter {
            $0.type == .deleted && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
        
        // Debug print
        print("=== DIFF DEBUG ===")
        print("Original length: \(fullTranscript.count)")
        print("New length: \(sentenceAnalysisResult.count)")
        print("Total components: \(components.count)")
        print("Deleted words: \(deletedCount)")
        print("Deleted words: \(components.filter { $0.type == .deleted && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.map { $0.text })")
        
        return deletedCount
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
            return try! AttributedString(markdown: "Kamu ada **\(count)** kata yang terdeteksi kurang efektif.")
            
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
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di **zona aman**.")
            case "B":
                let status = wpm < 100 ? "agak lambat" : "agak cepat"
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **\(status)**.")
            case "C":
                let status = wpm < 80 ? "sangat lambat" : "sangat cepat"
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **\(status)**.")
            default:
                return try! AttributedString(markdown: "Tempo bicaramu paling sering berada di rentang **kurang pas**.")
            }
            
        case .intonasi:
            let finalstd = result.intonationStdDev

            if finalstd < 1.5 {
                return try! AttributedString(markdown: "Intonasimu paling sering terdengar **cenderung datar**.")
            } else if finalstd <= 2.5 {
                return try! AttributedString(markdown: "Intonasimu paling sering terdengar **cukup bervariasi**.")
            } else if finalstd <= 4.5 {
                return try! AttributedString(markdown: "Intonasimu paling sering terdengar **sangat bervariasi**.")
            } else {
                return try! AttributedString(markdown: "Intonasimu paling sering terdengar **agak berlebihan**.")
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
