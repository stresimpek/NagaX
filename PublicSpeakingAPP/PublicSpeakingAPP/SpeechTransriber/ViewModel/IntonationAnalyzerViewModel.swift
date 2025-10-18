//
//  IntonationAnalyzerViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 13/10/25.
//

import Foundation
import AVFoundation
import Combine
import TensorFlowLite

@MainActor
final class IntonationAnalyzerViewModel: ObservableObject {
    
    // MARK: - Published Properties for UI
    @Published var pitchHistory: [Double] = []
    @Published var intonationLabel: String = "Speak to begin..."
    @Published var standardDeviation: Double = 0.0
    
    // MARK: - TFLite Properties
    private var interpreter: Interpreter?
    private let historySize = 200
    private let requiredSampleRate = 16000.0
    private var audioBuffer = [Float]()
    private var requiredInputSize = 0
    
    private let windowSamples = 16000
    private let hopSamples = 8000
    
    // MARK: - Audio Conversion
    private var audioConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                              sampleRate: 16000.0,
                                              channels: 1,
                                              interleaved: false)!
    
    init() {
        loadModel()
    }
    

    private var inputBaseShape: [Int] = [] // contoh: [-1, 1024] atau [1, 16000]
    private var inputRank: Int = 2

    private func loadModel() {
       guard let modelPath = Bundle.main.path(forResource: "spice", ofType: "tflite") else {
           print("❌ FATAL: spice.tflite not found"); intonationLabel = "Error: Model file not found."; return
       }
       do {
           interpreter = try Interpreter(modelPath: modelPath)
           // Alokasikan awal supaya tensor terinisialisasi
           try interpreter?.allocateTensors()
           print("✅ TFLite model loaded.")
       } catch {
           print("❌ Interpreter init error: \(error)"); intonationLabel = "Error: Could not load model."
       }
   }

    func analyze(buffer: AVAudioPCMBuffer) {
           guard let converted = convertAudio(buffer: buffer) else { return }
           let n = Int(converted.frameLength)
           guard let ch = converted.floatChannelData?.pointee else { return }
           let chunk = Array(UnsafeBufferPointer(start: ch, count: n))
           audioBuffer.append(contentsOf: chunk)

           // Proses per frame tetap
           while audioBuffer.count >= windowSamples {
               let frame = Array(audioBuffer.prefix(windowSamples))
               // slide dengan hop (overlap)
               audioBuffer.removeFirst(hopSamples)
               runInference(on: frame)
           }
       }

        private func runInference(on audioFrame: [Float]) {
            guard let interpreter = interpreter else { return }
            // Pastikan panjang frame sesuai
            let N = audioFrame.count
            guard N > 0 else { return }

            do {
                // ✅ Model kamu mengharapkan rank-1 (vector), jadi gunakan [N] saja.
                try interpreter.resizeInput(at: 0, to: Tensor.Shape([N]))
                try interpreter.allocateTensors() // WAJIB setelah resize

                let inputData = Data(buffer: UnsafeBufferPointer(start: audioFrame, count: N))
                try interpreter.copy(inputData, toInputAt: 0)

                try interpreter.invoke()

                let pitchTensor = try interpreter.output(at: 0)
                let unctTensor  = try interpreter.output(at: 1)

                let pitchVals = pitchTensor.data.toArray(type: Float.self)
                let unctVals  = unctTensor.data.toArray(type: Float.self)
                let confVals  = unctVals.map { 1.0 - $0 }

                let f0Hz = zip(pitchVals, confVals).compactMap { (p, c) -> Double? in
                    guard c >= 0.85 else { return nil }
                    return Double(spiceOutputToHz(p))
                }
                updatePitchHistory(with: f0Hz)

            } catch {
                print("❌ Inference error: \(error)")
            }
        }


       @inline(__always)
       private func spiceOutputToHz(_ p: Float) -> Float {
           let PT_OFFSET: Float = 25.58
           let PT_SLOPE:  Float = 63.07
           let FMIN:      Float = 10.0
           let BINS_PER_OCT: Float = 12.0
           let cqtBin = p * PT_SLOPE + PT_OFFSET
           return FMIN * powf(2.0, cqtBin / BINS_PER_OCT)
       }

       private func updatePitchHistory(with newPitches: [Double]) {
           let valid = newPitches.filter { $0 > 0 }
           guard !valid.isEmpty else { return }
           pitchHistory.append(contentsOf: valid)
           if pitchHistory.count > historySize {
               pitchHistory.removeFirst(pitchHistory.count - historySize)
           }
           calculateStatistics()
       }
    
    private func calculateStatistics() {
        guard pitchHistory.count > 1 else { return }
        let mean = pitchHistory.reduce(0, +) / Double(pitchHistory.count)
        let sumOfSquaredDiffs = pitchHistory.map { pow($0 - mean, 2) }.reduce(0, +)
        self.standardDeviation = sqrt(sumOfSquaredDiffs / Double(pitchHistory.count))
        
        if standardDeviation < 18.0 {
            intonationLabel = "Intonasi Cenderung Datar"
        } else if standardDeviation < 35.0 {
            intonationLabel = "Intonasi Cukup Bervariasi"
        } else {
            intonationLabel = "Intonasi Sangat Dinamis!"
        }
    }
    
    private func convertAudio(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if audioConverter == nil {
            audioConverter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter = audioConverter else { return nil }
        let capacity = AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        if let error = error {
            print("❌ Error during audio conversion: \(error.localizedDescription)")
            return nil
        }
        return convertedBuffer
    }

    func clearResults() {
        pitchHistory.removeAll()
        audioBuffer.removeAll()
        intonationLabel = "Speak to begin..."
        standardDeviation = 0.0
        audioConverter = nil
    }
}

extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes { $0.bindMemory(to: T.self) }.map { $0 }
    }
}
