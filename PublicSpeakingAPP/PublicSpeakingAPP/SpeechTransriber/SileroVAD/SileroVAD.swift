//
//  SileroVAD.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/11/25.
//

import Foundation
import CoreML
import AVFoundation

class SileroVAD {
    private var model: MLModel?
    
    // State untuk Silero V6 (2 layer, 1 batch, 128 context)
    // Silero V6 menggunakan context size 128 (sebelumnya 64 di v4)
    private var state: MLMultiArray?
    private let contextSize = 128
    
    // Threshold (0.5 adalah standar, naikkan ke 0.6 jika masih terlalu sensitif)
    var threshold: Float = 0.9
    
    init(modelName: String = "silero-vad-unified-v6.0.0") {
        // Coba load .mlmodelc (folder compiled)
        if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all // Gunakan Neural Engine
                self.model = try MLModel(contentsOf: modelURL, configuration: config)
                self.resetStates()
                print("[SileroVAD] Model V6 loaded successfully via .mlmodelc")
            } catch {
                print("[SileroVAD] Failed to load model: \(error)")
            }
        } else {
            // Fallback: Coba load dari class generated (jika Anda mengompile .mlpackage di Xcode)
            print("[SileroVAD] .mlmodelc not found in bundle. Make sure it's added to Copy Bundle Resources.")
        }
    }
    
    func resetStates() {
        // Shape V6 Unified: [2, 1, 128]
        let shape = [2, 1, NSNumber(value: contextSize)]
        
        guard let newState = try? MLMultiArray(shape: shape, dataType: .float32) else { return }
        
        // PERBAIKAN DI SINI:
        // Tambahkan ", _" setelah ptr
        newState.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
            ptr.initialize(repeating: 0.0)
        }
        
        self.state = newState
    }
    
    func detectVoice(in audioBuffer: [Float]) -> Float {
        guard let model = model, let currentState = state else { return 0.0 }
        
        // Silero V6 Unified optimal di chunk 512 samples (32ms @ 16kHz) atau lebih.
        // Input shape: [1, N]
        let inputCount = audioBuffer.count
        
        do {
            let inputData = try MLMultiArray(shape: [1, NSNumber(value: inputCount)], dataType: .float32)
            
            // Copy audio samples ke MLMultiArray
            for (i, sample) in audioBuffer.enumerated() {
                inputData[i] = NSNumber(value: sample)
            }
            
            // Siapkan input dictionary
            // PENTING: Nama key ("input", "state") harus sesuai dengan model V6
            let inputs: [String: Any] = [
                "input": inputData,
                "state": currentState
            ]
            
            let provider = try MLDictionaryFeatureProvider(dictionary: inputs)
            let prediction = try model.prediction(from: provider)
            
            // Ambil output
            // V6 output keys biasanya: "output" (probabilitas), "stateN" (state baru)
            guard let outputProbArray = prediction.featureValue(for: "output")?.multiArrayValue,
                  let nextState = prediction.featureValue(for: "stateN")?.multiArrayValue else {
                return 0.0
            }
            
            // Update state untuk chunk berikutnya
            self.state = nextState
            
            // Output probabilitas (ambil nilai float pertama)
            let probability = outputProbArray[0].floatValue
            return probability
            
        } catch {
            // Seringkali error di chunk pertama saat inisialisasi, abaikan saja
            // print("[SileroVAD] Inference error: \(error.localizedDescription)")
            return 0.0
        }
    }
}
