//
//  FillerTranscriberViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/11/25.
//

import Foundation
import SwiftUI
import AVFoundation
import WhisperKit
import Combine
import CoreML

extension SpeechTranscriberViewModel {
    
    /// Fungsi ini dipanggil SETELAH rekaman selesai untuk kebutuhan evaluasi akurat (Filler Words)
    // Di dalam Extension SpeechTranscriberViewModel

    func transcribeForEvaluation(audioURL: URL) async throws -> (String, [WordTiming]) {
        guard let whisperKit = whisperKit else {
            throw NSError(domain: "WhisperKitNotLoaded", code: 0, userInfo: nil)
        }
        
        // MARK: - LOGGING START
        print("\n🟪🟪🟪 [EVAL-FILLER] STARTING DUAL-PASS 🟪🟪🟪")
        print("[EVAL-FILLER] Reading Audio File: \(audioURL.lastPathComponent)")
        
        // 1. Load Audio
        let audioData = try loadAudioFileAsFloatArray(url: audioURL)
        print("[EVAL-FILLER] Audio Samples Loaded: \(audioData.count)")
        
        // 2. Setup Prompt
        let prompt = "Emm, eee, eh, uh, uhh, hmh, yak, oke, nah, jadi..."
        print("[EVAL-FILLER] Prompt Context: \"\(prompt)\"")
        
        let languageCode = Constants.languages[selectedLanguage, default: Constants.defaultLanguageCode]
        
        let promptTokenIDs: [Int]
        if let tokenizer = whisperKit.tokenizer {
            promptTokenIDs = try tokenizer.encode(text: prompt)
        } else {
            promptTokenIDs = []
        }
        
        // 3. Setup Options
        // PERBAIKAN PENTING: usePrefillPrompt harus FALSE agar prompt hanya jadi konteks, bukan input paksa.
        let options = DecodingOptions(
            verbose: true, // Set true jika mau lihat detail per segment di console
            task: .transcribe,
            language: languageCode,
            temperature: 0,
            usePrefillPrompt: false, // <--- SUDAH DIGANTI FALSE AGAR TEKS MUNCUL
            usePrefillCache: false,
            skipSpecialTokens: false,
            withoutTimestamps: false,
            wordTimestamps: true,
            promptTokens: promptTokenIDs
        )
        
        print("[EVAL-FILLER] Transcribing...")

        // 4. Transcribe
        let results = try await whisperKit.transcribe(
            audioArray: audioData,
            decodeOptions: options
        )
        
        // 5. Process Result
        let text = results.map { $0.text }.joined(separator: " ")
        let allWords = results.flatMap { $0.allWords }
        
        // MARK: - LOGGING RESULT
        print("\n🟪🟪🟪 [EVAL-FILLER] RESULT 🟪🟪🟪")
        print("--------------------------------------------------")
        print("RAW TEXT RESULT: \"\(text)\"")
        print("--------------------------------------------------")
        print("[EVAL-FILLER] Total Words Detected: \(allWords.count)")
        print("🟪🟪🟪 [EVAL-FILLER] END 🟪🟪🟪\n")
        
        return (text, allWords)
    }
    
    // Helper untuk mengubah WAV file jadi Float Array untuk WhisperKit
    private func loadAudioFileAsFloatArray(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioBufferError", code: 0, userInfo: nil)
        }
        
        try file.read(into: buffer)
        
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "AudioDataError", code: 0, userInfo: nil)
        }
        
        // Convert audio buffer to simple array [Float]
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        
        return samples
    }
}
