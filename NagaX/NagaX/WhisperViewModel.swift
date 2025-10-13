//
//  WhisperViewModel.swift
//  NagaX
//
//  Created by Jordan on 02/10/25.
//

import Foundation
import WhisperKit

@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var transcription: String = "Belum ada transkrip"
    @Published var isLoadingModel: Bool = false
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    
    private var whisper: WhisperKit?
    private let recorder = AudioRecorder()
    
    func setupWhisper() async {
        guard whisper == nil else { return }
        
        isLoadingModel = true
        transcription = "⏳ Sedang memuat model Whisper..."
        
        do {
            let config = WhisperKitConfig(model: "small")
            whisper = try await WhisperKit(config)
            
            transcription = "✅ Model siap dipakai!"
        } catch {
            transcription = "❌ Gagal memuat model: \(error.localizedDescription)"
        }
        
        isLoadingModel = false
    }

    
    func startRecording() {
        recorder.startRecording()
        isRecording = true
        transcription = "🎤 Sedang merekam..."
    }
    
    func stopAndTranscribe() async {
        recorder.stopRecording()
        isRecording = false
        isTranscribing = true
        transcription = "⚙️ Sedang transkripsi..."
        
        await setupWhisper()
        guard let whisper = whisper else {
            transcription = "❌ Gagal memuat model"
            isTranscribing = false
            return
        }
        
        if let url = recorder.outputURL {
            var options = DecodingOptions()
            options.language = "id"
            options.task = .transcribe
            
            let promptText = """
            Aturan transkripsi:
            1. Gunakan hanya huruf alfabet Latin (a-z) dan tanda baca yang umum dalam bahasa Indonesia, seperti titik dan koma. Jangan gunakan karakter dari tulisan Arab, Jepang, atau Mandarin.
            2. Sertakan semua filler words atau gumaman yang terdengar, seperti 'umm', 'eh', 'anu', dan 'hmm'.
            """
            
            if let tokens = whisper.tokenizer?.encode(text: promptText) {
                options.promptTokens = tokens
            }
            
            let results = try? await whisper.transcribe(
                audioPaths: [url.path],
                decodeOptions: options
            )
            
            transcription = results?
                .flatMap { $0! }
                .map { $0.text }
                .joined(separator: " ") ?? "(Tidak ada hasil)"
        } else {
            transcription = "❌ Tidak ada file rekaman"
        }
        
        isTranscribing = false
    }
}
