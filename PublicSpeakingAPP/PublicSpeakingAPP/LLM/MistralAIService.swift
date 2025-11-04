//
//  MistralAIService.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 15/10/25.
//

import Foundation

struct SentenceAnalysisResponse: Decodable {
    let totalErrors: Int
    let segments: [SentenceSegment]
}

struct SentenceSegment: Decodable, Hashable {
    let original: String
    let correction: String?
    let isCorrected: Bool
    let ruleViolated: String?
}

struct ChatMessage: Encodable {
    let role: String
    let content: String
}

struct ChatParams: Encodable {
    let model: String
    let messages: [ChatMessage]
}

struct ChatChoice: Decodable {
    let message: ChatResponseMessage
}

struct ChatResponseMessage: Decodable {
    let content: String
}

struct ChatCompletion: Decodable {
    let choices: [ChatChoice]
}

class MistralAIService {
    private let apiKey: String
    private let baseURL = "https://api.mistral.ai/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateQuestions(from transcript: String) async throws -> [String] {
        let prompt = getQuestionGenerationPrompt(transcript: transcript)
        
        let params = ChatParams(
            model: "mistral-small",
            messages: [
                ChatMessage(role: "user", content: prompt)
            ]
        )
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(params)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "MistralAIService", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get response from Mistral AI"])
        }
        
        let chatCompletion = try JSONDecoder().decode(ChatCompletion.self, from: data)
        
        print(chatCompletion)
        let content = chatCompletion.choices.first?.message.content ?? ""
        print(content)
        
        // Parse the returned content to extract questions
        return parseQuestionsFromResponse(content)
    }
    
    
    private func getQuestionGenerationPrompt(transcript: String) -> String {
        // Check if transcript is too short
        let wordCount = transcript.split(separator: " ").count
        
        if wordCount < 20 {
            return """
            ###
            \(transcript)
            ###
            Anda adalah seorang guru yang sedang mengevaluasi pemahaman siswa. Berdasarkan transkrip singkat ini, buatlah beberapa pertanyaan dalam Bahasa Indonesia yang akan membantu Anda menilai pemahaman siswa tentang topik ini.

            Jika transkrip terlalu singkat:
            - Fokus pada kata kunci yang ada dalam transkrip
            - Buat 1-2 pertanyaan sederhana yang relevan
            - Jangan mengasumsikan informasi yang tidak ada dalam transkrip
            - Lebih baik membuat sedikit pertanyaan yang relevan daripada banyak pertanyaan yang tidak berkaitan

            Format sebagai daftar bernomor dengan hanya pertanyaan saja.
            """
        }
        
        return """
        ###
        \(transcript)
        ###
        Anda adalah seorang guru berpengalaman yang sedang membuat pertanyaan evaluasi untuk menilai pemahaman mendalam siswa. Berdasarkan transkrip ini, buatlah 5 pertanyaan dalam Bahasa Indonesia yang akan menguji pemahaman konseptual siswa.

        Panduan untuk pertanyaan:
        - Pertanyaan harus berdasarkan konten spesifik dalam transkrip
        - Buatlah pertanyaan yang mendorong pemikiran kritis dan analitis
        - Variasikan jenis pertanyaan (pemahaman, analisis, evaluasi)
        - Format sebagai daftar bernomor (1, 2, 3...)
        - Semua pertanyaan HARUS dalam Bahasa Indonesia yang jelas dan ringkas
        - Fokus hanya pada informasi yang benar-benar ada dalam transkrip
        - Hindari asumsi tentang informasi yang tidak disebutkan

        Tujuan pertanyaan ini adalah untuk mengevaluasi pemahaman siswa, jadi pastikan pertanyaannya relevan dan bermakna.
        """
    }
    
    func analyzeSentence(from transcript: String) async throws -> SentenceAnalysisResponse {
            let prompt = getSentenceAnalysisPrompt(transcript: transcript)
            
            let params = ChatParams(
                model: "mistral-small",
                messages: [
                    ChatMessage(role: "user", content: prompt)
                ]
            )
            
            var request = URLRequest(url: URL(string: baseURL)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(params)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("Mistral Error Body: \(errorBody)")
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw NSError(domain: "MistralAIService", code: status,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to get Sentence response from Mistral AI"])
            }
            
            do {
                    // Langkah 1: Decode respons API utama (ChatCompletion)
                    let chatCompletion = try JSONDecoder().decode(ChatCompletion.self, from: data)
                    
                    // Langkah 2: Ambil string JSON dari 'content'
                    guard let jsonString = chatCompletion.choices.first?.message.content else {
                        throw NSError(domain: "MistralAIService", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "No content in Mistral response."])
                    }
                    
                    // Langkah 3: Ubah string JSON menjadi Data
                    guard let jsonData = jsonString.data(using: .utf8) else {
                        throw NSError(domain: "MistralAIService", code: 2,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to Data."])
                    }
                    
                    // Langkah 4: Decode Data JSON menjadi SentenceAnalysisResponse
                    // Kita letakkan ini di try-catch sendiri agar bisa log string-nya jika gagal
                    do {
                        let analysisResponse = try JSONDecoder().decode(SentenceAnalysisResponse.self, from: jsonData)
                        print(analysisResponse)
                        return analysisResponse
                    } catch let decodeError {
                        // Ini penting untuk debugging jika Mistral mengembalikan string yang BUKAN JSON
                        print("--- GAGAL PARSE JSON STRING DARI MISTRAL ---")
                        print("Error: \(decodeError)")
                        print("String yang diterima: \(jsonString)")
                        print("---------------------------------------------")
                        // Teruskan error aslinya
                        throw NSError(domain: "MistralAIService", code: 3,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to parse nested JSON: \(decodeError.localizedDescription)"])
                    }
                    
                } catch {
                    // Ini akan menangkap error dari decoding ChatCompletion (langkah 1)
                    print("JSON Decode Error (Outer): \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Received non-JSON or malformed JSON (Outer): \(jsonString)")
                    }
                    throw NSError(domain: "MistralAIService", code: 0,
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response: \(error.localizedDescription)"])
                }
        }
    
        private func getSentenceAnalysisPrompt(transcript: String) -> String {
            return """
            Anda adalah seorang Asisten AI yang berperan sebagai Pakar Tata Bahasa Indonesia, yang berfokus pada 7 Kaidah Kehematan.

            TUGAS: Analisis transkrip yang diberikan. Bagi transkrip menjadi beberapa segmen. Untuk setiap segmen, berikan teks asli dan teks koreksi (jika ada).

            KAIDAH KEHEMATAN (Gunakan 7 kaidah ini):
            a. Penggunaan kata di dalam frasa yang tidak hemat (Contoh: mempunyai hak -> berhak).
            b. Penggunaan konjungsi yang tidak tepat (Contoh: disebabkan karena).
            c. Penggunaan kata ulang dengan makna yang sama secara bersamaan (Contoh: para dosen-dosen).
            d. Penggunaan kata 'paling', 'amat', 'sangat' bersamaan atau dengan imbuhan 'ter-' (Contoh: amat sangat tampan sekali).
            e. Penggunaan sinonim yang kurang tepat (Contoh: memerhatikan film -> menonton film).
            f. Penggunaan subjek yang berulang dalam kalimat majemuk.
            g. Penggunaan superordinat pada hiponimi kata (Contoh: baju berwarna Putih).
            
            INSTRUKSI OUTPUT:
            Hasilkan HANYA sebuah objek JSON yang valid tanpa teks tambahan.
            Struktur JSON harus sebagai berikut:

            {
              "totalErrors": [jumlah total kesalahan yang ditemukan],
              "segments": [
                {
                  "original": "Teks asli dari segmen ini.",
                  "correction": "Teks koreksi untuk segmen ini (jika tidak ada, sama dengan asli).",
                  "isCorrected": true,
                  "ruleViolated": "Kaidah 'c' (jika tidak ada, null)"
                },
                {
                  "original": "Segmen berikutnya dari teks.",
                  "correction": "Segmen berikutnya dari teks.",
                  "isCorrected": false,
                  "ruleViolated": null
                }
                // ... dan seterusnya untuk seluruh transkrip
              ]
            }

            PENTING: PASTIKAN SELURUH TRANSKRIP DI ANALISIS DENGAN BAIK DAN PERBAIKAN TIDAK MENGUBAH MAKNA DARI TRANSKRIP ASLI. JANGAN SAMPAI ADA 1 KALIMAT YANG TERLEWAT SAAT DI SEGMENTASI!
            
            Contoh:
            Para siswa-siswi yang ada di sekolah tersebut sedang melaksanakan kegiatan kerja bakti membersihkan halaman sekolah pada pagi hari. Mereka semua saling bekerja sama satu sama lain untuk menyapu daun-daun yang berserakan, walaupun sebenarnya pada kenyataannya sebagian dari mereka tampak kurang bersemangat karena cuaca panas yang sangat terik sekali. Kepala sekolah turun langsung secara pribadi untuk memantau kegiatan itu dan memberikan arahan serta petunjuk-petunjuk yang diperlukan agar kegiatan berjalan
            
            {
              "totalErrors": 7,
              "segments": [
                {
                  "original": "Para siswa-siswi yang ada di sekolah tersebut",
                  "correction": "Para siswa yang ada di sekolah tersebut",
                  "isCorrected": true,
                  "ruleViolated": "Kaidah c"
                },
                {
                  "original": "sedang melaksanakan kegiatan kerja bakti membersihkan halaman sekolah pada pagi hari.",
                  "correction": null,
                  "isCorrected": false,
                  "ruleViolated": null
                },
                {
                  "original": "Mereka semua saling bekerja sama satu sama lain",
                  "correction": "Mereka bekerja sama",
                  "isCorrected": true,
                  "ruleViolated": "Kaidah c"
                },
                {
                  "original": "untuk menyapu daun-daun yang berserakan,",
                  "correction": null,
                  "isCorrected": false,
                  "ruleViolated": null
                },
                {
                  "original": "walaupun sebenarnya pada kenyataannya sebagian dari mereka tampak kurang bersemangat karena cuaca panas yang sangat terik sekali.",
                  "correction": "walaupun sebenarnya sebagian dari mereka tampak kurang bersemangat karena cuaca yang terik.",
                  "isCorrected": true,
                  "ruleViolated": "Kaidah d"
                },
                {
                  "original": "Kepala sekolah turun langsung secara pribadi untuk memantau kegiatan itu",
                  "correction": "Kepala sekolah turun langsung untuk memantau kegiatan itu",
                  "isCorrected": true,
                  "ruleViolated": "Kaidah a"
                },
                {
                  "original": "dan memberikan arahan serta petunjuk-petunjuk yang diperlukan agar kegiatan berjalan...",
                  "correction": null,
                  "isCorrected": false,
                  "ruleViolated": null"
                }
              ]
            }

            Untuk InputINPUT:
            \(transcript)

            Balikan dengan format JSON!
            
            """
        }
    
    private func parseQuestionsFromResponse(_ response: String) -> [String] {
        // Simple parsing logic that looks for numbered questions (1., 2., etc.)
        let lines = response.components(separatedBy: .newlines)
        var questions: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Match lines that start with a number and period/parenthesis
            if let _ = trimmedLine.range(of: #"^\d+[\.\)]"#, options: .regularExpression) {
                // Remove the number and any whitespace
                if let range = trimmedLine.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                    let question = trimmedLine.replacingCharacters(in: range, with: "")
                    if !question.isEmpty {
                        questions.append(question)
                    }
                } else {
                    // If regex replacement fails, just add the trimmed line
                    questions.append(trimmedLine)
                }
            }
        }
        return questions
    }
}

