//
//  MistralAIService.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 15/10/25.
//

import Foundation

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
    
    func analyzeSentence(from transcript: String) async throws -> String {
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
                let chatCompletion = try JSONDecoder().decode(ChatCompletion.self, from: data)
                
                guard let content = chatCompletion.choices.first?.message.content else {
                    throw NSError(domain: "MistralAIService", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "No content in Mistral response."])
                }
                
                print("Mistral Analysis (String): \(content)")
                return content
                
            } catch {
                print("JSON Decode Error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Received non-JSON or malformed JSON: \(jsonString)")
                }
                throw NSError(domain: "MistralAIService", code: 0,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response: \(error.localizedDescription)"])
            }
        }
    
    private func getSentenceAnalysisPrompt(transcript: String) -> String {
        return """
        Anda adalah seorang Asisten AI yang berperan sebagai Pakar Tata Bahasa Indonesia, yang berfokus pada 7 Kaidah Kehematan.

        TUGAS: Analisis transkrip yang diberikan. Berikan ulasan singkat dalam bentuk teks (paragraf) tentang kesalahan kehematan kalimat yang ditemukan.

        KAIDAH KEHEMATAN (Gunakan 7 kaidah ini):
        a. Penggunaan kata di dalam frasa yang tidak hemat (Contoh: mempunyai hak -> berhak).
        b. Penggunaan konjungsi yang tidak tepat (Contoh: disebabkan karena).
        c. Penggunaan kata ulang dengan makna yang sama secara bersamaan (Contoh: para dosen-dosen).
        d. Penggunaan kata 'paling', 'amat', 'sangat' bersamaan atau dengan imbuhan 'ter-' (Contoh: amat sangat tampan sekali).
        e. Penggunaan sinonim yang kurang tepat (Contoh: memerhatikan film -> menonton film).
        f. Penggunaan subjek yang berulang dalam kalimat majemuk.
        g. Penggunaan superordinat pada hiponimi kata (Contoh: baju berwarna Putih).
        
        INSTRUKSI OUTPUT:
        - Hasilkan HANYA teks paragraf biasa sebagai jawaban Anda dan JANGAN TAMPILKAN POIN-POIN KAIDAH, HANYA PARAGRA PERBAIKAN SAJA.

        PENTING: PASTIKAN SEMUA KALIMAT TIDAK ADA YANG TERLEWAT UNTUK DIMASUKKAN KEDALAM OUTPUT HASIL ANALISIS.
        
        Contoh Input:
        Para siswa-siswi yang ada di sekolah tersebut sedang melaksanakan kegiatan kerja bakti membersihkan halaman sekolah pada pagi hari. Mereka semua saling bekerja sama satu sama lain untuk menyapu daun-daun yang berserakan, walaupun sebenarnya pada kenyataannya sebagian dari mereka tampak kurang bersemangat karena cuaca panas yang sangat terik sekali. Kepala sekolah turun langsung secara pribadi untuk memantau kegiatan itu dan memberikan arahan serta petunjuk-petunjuk yang diperlukan agar kegiatan berjalan dengan lancar.
        
        OUTPUT yang diharapkan:
        Para siswa yang ada di sekolah tersebut sedang melaksanakan kegiatan kerja bakti membersihkan halaman sekolah pada pagi hari. Mereka bekerja sama untuk menyapu daun-daun yang berserakan, walaupun sebenarnya sebagian dari mereka tampak kurang bersemangat karena cuaca yang sangat terik. Kepala sekolah turun langsung untuk memantau kegiatan itu an memberikan arahan serta petunjuk-petunjuk yang diperlukan agar kegiatan berjalan dengan lancar.

        UNTUK INPUT:
        \(transcript)

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

