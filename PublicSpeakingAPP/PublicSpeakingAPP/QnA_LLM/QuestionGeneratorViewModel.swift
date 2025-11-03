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
                    from: "https://huggingface.co/mradermacher/gemma-3n-E2B-GGUF/resolve/main/gemma-3n-E2B.Q2_K.gguf",
                    fileName: "gemma-3n-E2B.Q2_K.gguf",
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
        
//        let prompt = """
//        Baca teks berikut dengan teliti dan buat 3-5 pertanyaan kritis yang langsung terkait dengan isi teks.
//        
//        Aturan ketat:
//        - Setiap pertanyaan HARUS berdasar pada informasi yang secara eksplisit ada dalam teks
//        - Jangan menambahkan fakta, asumsi, atau informasi dari luar teks
//        - Fokus pada:
//          * Apa yang tidak dijelaskan tetapi penting
//          * Asumsi tersirat dalam pernyataan
//          * Konsistensi logika dalam teks
//        
//        Teks:
//        \(text)
//        
//        Pertanyaan kritis:
//        """
        let prompt = """
        Teks:
        \(text)
        Berdasarkan teks di atas, 
        PERAN: Anda adalah seorang Asisten AI yang berperan sebagai Pakar Tata Bahasa Indonesia. Fokus utama Anda adalah menganalisis efektivitas kalimat berdasarkan prinsip Kehematan.

        TUGAS UTAMA: Analisis paragraf input yang diberikan. Identifikasi setiap frasa atau kalimat yang melanggar 7 Kaidah Kehematan di bawah ini. Untuk setiap pelanggaran yang ditemukan, Anda harus menyajikan temuan dalam format output yang ditentukan.

        KAIDAH KEHEMATAN: Anda harus mendasarkan seluruh analisis Anda hanya pada 7 kaidah berikut:

        a. Penggunaan kata di dalam frasa yang tidak hemat: (Contoh: mempunyai hak -> berhak, tidak setuju -> menolak, tidak berhasil -> gagal). b. Penggunaan konjungsi yang tidak tepat: (Contoh: konjungsi ganda seperti disebabkan karena). c. Penggunaan kata ulang dengan makna yang sama secara bersamaan: (Contoh: para dosen-dosen). d. Penggunaan kata paling, amat, sangat secara bersamaan atau bertemu dengan kata berimbuhan ter-: (Contoh: amat sangat tampan sekali atau paling tersulit). e. Penggunaan sinonim yang kurang tepat: (Contoh: memerhatikan film seharusnya menonton film). f. Penggunaan subjek yang berulang dalam kalimat majemuk: (Contoh: Sesudah Presiden Jokowi berkunjung..., ia akan...). g. Penggunaan superordinat pada hiponimi kata: (Contoh: baju berwarna Putih).

        FORMAT INPUT: Input akan berupa satu paragraf teks atau lebih.

        FORMAT OUTPUT WAJIB: Anda harus mengikuti struktur ini dengan ketat untuk setiap kesalahan yang ditemukan. Jika ada lebih dari satu kesalahan, ulangi blok format ini.

        Output:
        Kalimat tidak efektif dari kalimat tersebut:
        [Kutip frasa atau kalimat yang tidak efektif]

        Pelanggaran Kaidah:
        [Sebutkan kaidah yang dilanggar, misal: Penggunaan kata ulang dengan makna yang sama]

        Perbaikan:
        [Tulis ulang kalimat yang sudah diperbaiki]
        Jika tidak ada kesalahan yang ditemukan dalam teks input, respons Anda hanya boleh: Teks sudah efektif berdasarkan 7 kaidah kehematan.

        CONTOH EKSEKUSI:

        Input: Para tamu-tamu undangan diharapkan agar segera masuk ke dalam ruangan. Acara ini adalah merupakan acara yang paling terpenting di tahun ini. Disebabkan karena acara ini akan dihadiri oleh Bapak Presiden.

        Output: Kalimat tidak efektif dari kalimat tersebut: Para tamu-tamu undangan

        Pelanggaran Kaidah: Penggunaan kata ulang dengan makna yang sama secara bersamaan.

        Perbaikan: Para tamu (atau Tamu-tamu undangan)

        Kalimat tidak efektif dari kalimat tersebut: diharapkan agar segera masuk

        Pelanggaran Kaidah: Penggunaan konjungsi yang tidak tepat (ganda: diharapkan & agar).

        Perbaikan: diharapkan segera masuk

        Kalimat tidak efektif dari kalimat tersebut: masuk ke dalam ruangan

        Pelanggaran Kaidah: Penggunaan kata di dalam frasa yang tidak hemat (kata 'masuk' sudah pasti 'ke dalam').

        Perbaikan: masuk ruangan

        Kalimat tidak efektif dari kalimat tersebut: Acara ini adalah merupakan acara

        Pelanggaran Kaidah: Penggunaan kata di dalam frasa yang tidak hemat (sinonim 'adalah' dan 'merupakan').

        Perbaikan: Acara ini merupakan acara (atau Acara ini adalah acara)

        Kalimat tidak efektif dari kalimat tersebut: yang paling terpenting

        Pelanggaran Kaidah: Penggunaan kata 'paling' bertemu dengan kata berimbuhan 'ter-'.

        Perbaikan: yang terpenting (atau yang paling penting)

        Kalimat tidak efektif dari kalimat tersebut: Disebabkan karena acara ini

        Pelanggaran Kaidah: Penggunaan konjungsi yang tidak tepat (ganda: disebabkan & karena).

        Perbaikan: Sebab, acara ini (atau Hal itu disebabkan acara ini)
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
