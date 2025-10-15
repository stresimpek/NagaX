//
//  TextAnalyzerViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 09/10/25.
//

import Foundation
import NaturalLanguage
import Combine

@MainActor
final class TextFrequencyAnalyzerViewModel: ObservableObject {
    // MARK: - Published Properties for UI
    @Published var wordFrequencies: [String: Int] = [:]
    @Published var termFrequencies: [String: Double] = [:]
    @Published var repeatedWordsInWindow: [String: Int] = [:]
    @Published var repeatedBigrams: [String: Int] = [:]
    @Published var repeatedTrigrams: [String: Int] = [:]

    // MARK: - Indonesian Stop Words
    private let stopWordsID: Set<String> = [
        "ada", "adalah", "adanya", "adapun", "agak", "agaknya", "agar", "akan", "akankah", "akhir",
        "akhiri", "akhirnya", "aku", "akulah", "amat", "amatlah", "anda", "andalah", "antar",
        "antara", "antaranya", "apa", "apaan", "apabila", "apakah", "apalagi", "apatah", "artinya",
        "asal", "asalkan", "atas", "atau", "ataukah", "ataupun", "awal", "awalnya", "bagai",
        "bagaikan", "bagaimana", "bagaimanakah", "bagaimanapun", "bagi", "bagian", "bahkan",
        "bahwa", "bahwasanya", "baik", "bakal", "bakalan", "balik", "banyak", "bapak", "baru",
        "bawah", "beberapa", "begini", "beginian", "beginikah", "beginilah", "begitu", "begitukah",
        "begitulah", "begitupun", "bekerja", "belakang", "belakangan", "belum", "belumlah",
        "benar", "benarkah", "benarlah", "berada", "berakhir", "berakhirlah", "berakhirnya",
        "berapa", "berapakah", "berapalah", "berapapun", "berarti", "berawal", "berbagai",
        "berdatangan", "beri", "berikan", "berikut", "berikutnya", "berjumlah", "berkali-kali",
        "berkata", "berkehendak", "berkeinginan", "berkenaan", "berlainan", "berlalu", "berlangsung",
        "berlebihan", "bermacam", "bermacam-macam", "bermaksud", "bermula", "bersama", "bersama-sama",
        "bersiap", "bersiap-siap", "bertanya", "bertanya-tanya", "berturut", "berturut-turut",
        "bertutur", "berujar", "berupa", "besar", "betul", "betulkah", "biasa", "biasanya", "bila",
        "bilakah", "bisa", "bisakah", "boleh", "bolehkah", "bolehlah", "buat", "bukan", "bukankah",
        "bukanlah", "bukannya", "bulan", "bung", "cara", "caranya", "cukup", "cukupkah", "cukuplah",
        "cuma", "dahulu", "dalam", "dan", "dapat", "dari", "daripada", "datang", "demi", "demikian",
        "demikianlah", "dengan", "depan", "di", "dia", "diakhiri", "diakhirinya", "dialah",
        "diantara", "diantaranya", "diberi", "diberikan", "diberikannya", "dibuat", "dibuatnya",
        "didapat", "didatangkan", "digunakan", "diibaratkan", "diibaratkannya", "diingat",
        "diingatkan", "diinginkan", "dijawab", "dijelaskan", "dijelaskannya", "dikarenakan",
        "dikatakan", "dikatakannya", "dikerjakan", "diketahui", "diketahuinya", "dikiranya",
        "dilakukan", "dilalui", "dilihat", "dilihatnya", "dimaksud", "dimaksudkan", "dimaksudkannya",
        "dimaksudnya", "diminta", "dimintai", "dimisalkan", "dimulai", "dimulailah", "dimulainya",
        "dimungkinkan", "dini", "dipastikan", "diperbuat", "diperbuatnya", "dipergunakan",
        "diperkirakan", "diperlihatkan", "diperlukan", "diperlukannya", "dipersoalkan",
        "dipertanyakan", "dipunyai", "diri", "dirinya", "disampaikan", "disebut", "disebutkan",
        "disebutkannya", "disini", "disinilah", "ditambahkan", "ditandaskan", "ditanya", "ditanyai",
        "ditanyakan", "ditegaskan", "ditujukan", "ditunjuk", "ditunjuki", "ditunjukkan",
        "ditunjukkannya", "dituturkan", "dituturkannya", "diucapkan", "diucapkannya", "diungkapkan",
        "dong", "dulu", "empat", "enggak", "enggaknya", "entah", "entahlah", "guna", "gunakan",
        "hal", "hampir", "hanya", "hanyalah", "hari", "harus", "haruslah", "harusnya", "hendak",
        "hendaklah", "hendaknya", "hingga", "ia", "ialah", "ibarat", "ibaratnya", "ibu", "ikut",
        "ingat", "ingat-ingat", "ingin", "inginkah", "inginkan", "ini", "inikah", "inilah", "itu",
        "itukah", "itulah", "jadi", "jadilah", "jadinya", "jangan", "jangankan", "janganlah",
        "jauh", "jawab", "jawaban", "jawabnya", "jelas", "jelaskan", "jelaslah", "jelasnya", "jika",
        "jikalau", "juga", "jumlah", "jumlahnya", "justru", "kala", "kalau", "kalaulah", "kalaupun",
        "kali", "kalian", "kami", "kamilah", "kamu", "kamulah", "kan", "kapan", "kapankah",
        "kapanpun", "karena", "karenanya", "kasus", "kata", "katakan", "katakanlah", "katanya",
        "ke", "keadaan", "kebetulan", "kecil", "kedua", "keduanya", "keinginan", "kelak",
        "kelima", "keluar", "kembali", "kemudian", "kemungkinan", "kemungkinannya", "kenapa",
        "kepada", "kepadanya", "keterlaluan", "ketika", "khususnya", "kini", "kinilah", "kira",
        "kira-kira", "kiranya", "kita", "kitalah", "kok", "lagi", "lagian", "lah", "lain",
        "lainnya", "lalu", "lama", "lamanya", "lanjut", "lanjutnya", "lebih", "lewat", "lima",
        "luar", "macam", "maka", "makanya", "makin", "malah", "malahan", "mampu", "mampukah",
        "mana", "manakala", "manalagi", "masa", "masalah", "masalahnya", "masih", "masihkah",
        "masing", "masing-masing", "mau", "maupun", "melainkan", "melakukan", "melalui", "melihat",
        "melihatnya", "memang", "memastikan", "memberi", "memberikan", "membuat", "memerlukan",
        "memintakan", "memisalkan", "memperbuat", "mempergunakan", "memperkirakan",
        "memperlihatkan", "mempersiapkan", "mempersoalkan", "mempertanyakan", "mempunyai",
        "memulai", "memungkinkan", "menjadi", "menjawab", "menjelaskan", "menuju", "menurut",
        "menuturkan", "menyampaikan", "menyangkut", "menyatakan", "menyebutkan", "menyeluruh",
        "menyiapkan", "merasa", "mereka", "merekalah", "merupakan", "meski", "meskipun", "meyakini",
        "minta", "mirip", "misal", "misalkan", "misalnya", "mula", "mulai", "mulailah", "mulanya",
        "mungkin", "mungkinkah", "nah", "naik", "namun", "nanti", "nantinya", "nyaris", "nyatanya",
        "oleh", "olehnya", "pada", "padahal", "padanya", "pak", "paling", "panjang", "pantas",
        "para", "pasti", "pastilah", "penting", "pentingnya", "per", "percuma", "perlu", "perlukah",
        "perlunya", "pernah", "persoalan", "pertama", "pertama-tama", "pertanyaan", "pertanyakan",
        "pihak", "pihaknya", "pukul", "pula", "pun", "punya", "rasa", "rasanya", "rata", "rupanya",
        "saat", "saatnya", "saja", "sajalah", "saling", "sama", "sama-sama", "sambil", "sampai",
        "sana", "sangat", "sangatlah", "sangkut", "satu", "saya", "sayalah", "se", "sebab",
        "sebabnya", "sebagai", "sebagaimana", "sebagainya", "sebagian", "sebaik", "sebaik-baiknya",
        "sebaiknya", "sebaliknya", "sebanyak", "sebelum", "sebelumnya", "sebenarnya", "seberapa",
        "sebesar", "sebetulnya", "sebisanya", "sebuah", "sebut", "sebutlah", "sebutnya", "secara",
        "secukupnya", "sedang", "sedangkan", "sedemikian", "sedikit", "sedikitnya", "seenaknya",
        "segala", "segalanya", "segera", "seharusnya", "sehingga", "seingat", "sejak", "sejauh",
        "sejenak", "sejumlah", "sekadar", "sekadarnya", "sekali", "sekali-kali", "sekalian",
        "sekaligus", "sekalipun", "sekarang", "sekaranglah", "sekecil", "seketika", "sekiranya",
        "sekitar", "sekitarnya", "sela", "selain", "selaku", "selalu", "selama", "selama-lamanya",
        "selamanya", "selanjutnya", "seluruh", "seluruhnya", "semacam", "semakin", "semampu",
        "semampunya", "semasa", "semasih", "semata", "semata-mata", "semaunya", "sementara",
        "semisal", "semisalnya", "sempat", "semua", "semuanya", "semula", "sendiri", "sendirian",
        "sendirinya", "seolah", "seolah-olah", "seorang", "sepanjang", "sepantasnya", "sepantasnyalah",
        "seperlunya", "seperti", "sepertinya", "sepeserpun", "sering", "seringnya", "serta", "serupa",
        "sesaat", "sesampai", "sesegera", "sesekali", "seseorang", "sesuatu", "sesuatunya",
        "sesudah", "sesudahnya", "setelah", "setempat", "setengah", "seterusnya", "setiap",
        "setiba", "setibanya", "setidak-tidaknya", "setidaknya", "setinggi", "seusai", "sewaktu",
        "siap", "siapa", "siapakah", "siapapun", "sini", "sinilah", "suatu", "sudah", "sudahkah",
        "sudahlah", "supaya", "tadi", "tadinya", "tahu", "tahun", "tak", "tanpa", "tanya",
        "tanyakan", "tanyanya", "tapi", "tegas", "tegasnya", "telah", "tempat", "tengah", "tentang",
        "tentu", "tentulah", "tentunya", "tepat", "terakhir", "terasa", "terbanyak", "terdahulu",
        "terdapat", "terdiri", "terhadap", "terhadapnya", "teringat", "teringat-ingat", "terjadi",
        "terjadilah", "terjadinya", "terkira", "terlalu", "terlebih", "terlihat", "termasuk",
        "ternyata", "tersampaikan", "tersebut", "tersebutlah", "tertentu", "tertuju", "terus",
        "terutama", "tetap", "tetapi", "tiap", "tiba", "tiba-tiba", "tidak", "tidakkah", "tidaklah",
        "toh", "turut", "untuk", "usah", "usai", "wah", "wahai", "waktu", "waktunya", "walau",
        "walaupun", "while", "ya", "yaitu", "yakin", "yakni", "yang"
    ]

    // MARK: - Public API
    func analyze(text: String) {
        guard !text.isEmpty else {
            clearResults()
            return
        }

        // 1. Preprocessing (Tokenization & Stop Word Removal)
        let tokens = preprocess(text: text)

        // 2. Run all analyses
        analyzeFrequency(tokens: tokens)
        analyzeProximity(tokens: tokens, windowSize: 15) // Window 15 kata
        analyzeNGrams(tokens: tokens)
    }

    func clearResults() {
        wordFrequencies = [:]
        repeatedWordsInWindow = [:]
        repeatedBigrams = [:]
        repeatedTrigrams = [:]
    }

    // MARK: - Analysis Functions
    
    /// 1. Tokenisasi dan menghapus stop words
    private func preprocess(text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        var tokens: [String] = []

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType, options: options) { _, tokenRange in
            let token = String(text[tokenRange]).lowercased()
            tokens.append(token)
            return true
        }
        
        // Filter stop words
        let filteredTokens = tokens.filter { !stopWordsID.contains($0) }
        
        print("---  preprocess ---")
        print("Original Tokens: \(tokens.count), Filtered Tokens: \(filteredTokens.count)")
        return filteredTokens
    }

    private func analyzeFrequency(tokens: [String]) {
        let totalTokens = tokens.count
        guard totalTokens > 0 else {
            self.wordFrequencies = [:]
            self.termFrequencies = [:]
            return
        }

        // Langkah 1: Hitung frekuensi absolut untuk semua kata (seperti sebelumnya)
        var allFrequencies: [String: Int] = [:]
        for token in tokens {
            allFrequencies[token, default: 0] += 1
        }

        // Langkah 2: Siapkan dictionary baru untuk hasil yang lolos seleksi
        var significantFrequencies: [String: Int] = [:]
        var allTermFrequencies: [String: Double] = [:]
        
        // Tentukan ambang batas (threshold), 5% = 0.05
        let threshold: Double = 0.3

        // Langkah 3: Loop melalui semua frekuensi untuk menghitung TF dan memfilternya
        for (word, count) in allFrequencies {
            // Hitung TF untuk setiap kata
            let tf = Double(count) / Double(totalTokens)
            allTermFrequencies[word] = tf // Simpan semua TF jika diperlukan di tempat lain

            // Langkah 4: Cek apakah TF melebihi ambang batas
            if tf > threshold {
                // Jika ya, simpan FREKUENSI ABSOLUT-nya
                significantFrequencies[word] = count
            }
        }

        // Langkah 5: Update properti yang akan ditampilkan di UI
        self.wordFrequencies = significantFrequencies
        self.termFrequencies = allTermFrequencies // Kita tetap simpan semua TF untuk data internal

        // Modifikasi print untuk menunjukkan proses filtering
        print("\n--- 📊 Term Frequency Analysis (Threshold: >\(threshold * 100)%) ---")
        if self.wordFrequencies.isEmpty {
            print("No words exceeded the significance threshold.")
        } else {
            print("Significant Repetitions Found:")
            self.wordFrequencies.sorted { $0.value > $1.value }.forEach { word, count in
                // Ambil nilai TF yang sudah dihitung untuk ditampilkan di print
                if let tf = self.termFrequencies[word] {
                    let percentage = String(format: "%.2f%%", tf * 100)
                    print("- '\(word)': Muncul \(count) kali (porsi \(percentage))")
                }
            }
        }
    }

    /// 3. Menganalisis pengulangan kata dalam jarak berdekatan (window)
    private func analyzeProximity(tokens: [String], windowSize: Int) {
        var repeatedInWindow: [String: Int] = [:]
        
        guard tokens.count > windowSize else { return }

        for i in 0...(tokens.count - windowSize) {
            let window = tokens[i..<(i + windowSize)]
            var windowFrequencies: [String: Int] = [:]
            for token in window {
                windowFrequencies[token, default: 0] += 1
            }
            
            for (token, count) in windowFrequencies where count > 1 {
                repeatedInWindow[token, default: 0] += 1 // Menghitung seberapa sering sebuah kata terulang di *banyak* window
            }
        }
        
        self.repeatedWordsInWindow = repeatedInWindow
        
        print("\n--- 📏 Proximity Analysis (Window Size: \(windowSize)) ---")
        self.repeatedWordsInWindow.sorted { $0.value > $1.value }.forEach { print("\($0.key): \($0.value) times repeated in a window") }
    }

    /// 4. Menganalisis pengulangan frasa (bigram & trigram)
    private func analyzeNGrams(tokens: [String]) {
        var bigramFrequencies: [String: Int] = [:]
        var trigramFrequencies: [String: Int] = [:]
        
        // Bigram analysis (2 kata)
        if tokens.count >= 2 {
            for i in 0..<(tokens.count - 1) {
                let bigram = tokens[i] + " " + tokens[i+1]
                bigramFrequencies[bigram, default: 0] += 1
            }
        }

        // Trigram analysis (3 kata)
        if tokens.count >= 3 {
            for i in 0..<(tokens.count - 2) {
                let trigram = tokens[i] + " " + tokens[i+1] + " " + tokens[i+2]
                trigramFrequencies[trigram, default: 0] += 1
            }
        }
        
        self.repeatedBigrams = bigramFrequencies.filter { $0.value > 1 }
        self.repeatedTrigrams = trigramFrequencies.filter { $0.value > 1 }
        
        print("\n--- 🔗 N-Gram Analysis (more than once) ---")
        print("-- Bigrams --")
        self.repeatedBigrams.sorted { $0.value > $1.value }.forEach { print("\($0.key): \($0.value)") }
        print("-- Trigrams --")
        self.repeatedTrigrams.sorted { $0.value > $1.value }.forEach { print("\($0.key): \($0.value)") }
    }
}
