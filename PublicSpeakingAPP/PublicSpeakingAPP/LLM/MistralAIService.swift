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
        let content = chatCompletion.choices.first?.message.content ?? ""
        
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
        
        //        """
        //        ###
        //        \(transcript)
        //        ###
        //        Based on this transcript, generate 5 thoughtful and contextual questions that could be used in a Q&A session.
        //
        //        Guidelines for questions:
        //        - Questions should be directly related to the content of the transcript
        //        - Each question should probe deeper into topics mentioned in the transcript
        //        - Questions should be insightful and encourage detailed responses
        //        - Format as a numbered list with just the questions (no explanations)
        //        - Make sure questions are clear and concise
        //        """
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
