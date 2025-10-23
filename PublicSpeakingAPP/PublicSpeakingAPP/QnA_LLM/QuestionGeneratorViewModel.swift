//
//  QuestionGeneratorViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 23/10/25.
//

import SwiftUI
import LLM

// Renamed to avoid conflict with WhisperKit.ModelState
enum LLMModelState {
    case unloaded
    case downloading
    case loading
    case loaded
    case failed
    case prewarming
}

class QuestionGeneratorViewModel: ObservableObject {
    @Published var generatedQuestions: String = ""
    @Published var isGenerating: Bool = false
    @Published var error: String?
    @Published var modelState: LLMModelState = .unloaded
    @Published var loadingProgress: Float = 0.0
    @Published var downloadStatus: String = ""
    
    private var llm: Model?
    
    func loadModel() {
        guard modelState == .unloaded else {
            print("❌ Model already loading/loaded")
            return
        }
        
        print("✅ Starting model load")
        modelState = .loading

        Task {
            do {
                await MainActor.run {
                    self.downloadStatus = "Checking for model..."
                    print("📝 Status: Checking for model...")
                }

                print("🔗 Starting download from URL")
                let modelURL = try await ModelDownloader.shared.downloadModel(
                    from: "https://huggingface.co/unsloth/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
                    fileName: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
                    progressCallback: { progress in
                        print("📊 Progress: \(progress)")
                        Task { @MainActor in
                            self.loadingProgress = progress
                            self.modelState = .downloading
                            let percentage = Int(progress * 100)
                            self.downloadStatus = "Downloading model: \(percentage)%"
                        }
                    }
                )

                print("✅ Download complete: \(modelURL)")
                
                await MainActor.run {
                    self.downloadStatus = "Loading model into memory..."
                    print("📝 Status: Loading into memory...")
                    self.llm = Model(from: modelURL)
                    self.modelState = self.llm != nil ? .loaded : .failed
                    self.loadingProgress = 1.0
                    self.downloadStatus = self.llm != nil ? "Model ready!" : "Failed to load model"
                    print("✅ Model state: \(self.modelState)")
                }
            } catch {
                print("❌ Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.modelState = .failed
                    self.downloadStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func generateQuestions(from text: String) {
        guard let llm = llm else {
            error = "Model not loaded"
            return
        }
        
        guard !text.isEmpty else {
            error = "No text to analyze"
            return
        }
        
        let prompt = """
        Baca teks berikut dengan teliti dan buat 3-5 pertanyaan kritis yang langsung terkait dengan isi teks.
        
        Aturan ketat:
        - Setiap pertanyaan HARUS berdasar pada informasi yang secara eksplisit ada dalam teks
        - Jangan menambahkan fakta, asumsi, atau informasi dari luar teks
        - Fokus pada:
          * Apa yang tidak dijelaskan tetapi penting
          * Asumsi tersirat dalam pernyataan
          * Konsistensi logika dalam teks
        
        Teks:
        \(text)
        
        Pertanyaan kritis:
        """
        
        Task {
            await MainActor.run {
                self.isGenerating = true
                self.generatedQuestions = ""
                self.error = nil
            }
            
            await llm.respond(to: prompt)
            
            await MainActor.run {
                self.generatedQuestions = llm.output
                self.isGenerating = false
            }
        }
    }
    
    func reset() {
        generatedQuestions = ""
        error = nil
    }
}

class Model: LLM {
    convenience init?(from url: URL) {
        let systemPrompt = "Kamu adalah asisten yang membantu membuat pertanyaan kritis berdasarkan teks yang diberikan."
        self.init(from: url, template: .chatML(systemPrompt))
    }
}
