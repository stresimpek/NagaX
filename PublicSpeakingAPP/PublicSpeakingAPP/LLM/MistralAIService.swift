//
//  MistralAIService.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 12/11/25.
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
        - Output berupa paragraf salinan ulang input namun sudah diperbaiki sesuai dengan kaidah kehematan
        - Hasilkan HANYA teks paragraf biasa sebagai jawaban Anda dan JANGAN TAMPILKAN POIN-POIN KAIDAH, HANYA PARAGRAf PERBAIKAN SAJA. 
        - JANGAN MENGELUARKAN KALIMAT DI LUAR KONTEKS INPUT -> TERUTAMA JANGAN KELUARAKAN KALIMAT PENJELASAN KESALAHAN
        - Jika tidak ada kalimat yang melanggar kaidah kehematan, maka balikan input lagi
        - Paragraf, tanpa tanda kutip

        PENTING: PASTIKAN SEMUA KALIMAT TIDAK ADA YANG TERLEWAT UNTUK DIMASUKKAN KEDALAM OUTPUT HASIL ANALISIS.
        
        Contoh Input: Para ibu-ibu tersebut sedang menjaga anaknya yang sedang bermain di lapangan.
        Contoh output: Para ibu tersebut menjaga anaknya yang sedang bermain di lapangan.
        
        Dalam tanda kutip adalah input, berikan output sesuai format yang diberikan: " \(transcript) "

        """
    }
}

