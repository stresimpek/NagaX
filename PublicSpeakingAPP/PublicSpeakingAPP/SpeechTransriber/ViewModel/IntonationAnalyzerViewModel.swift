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
    private var inputRank: Int = 0

    private func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "spice", ofType: "tflite") else {
            print("❌ FATAL: Model file 'spice.tflite' not found.")
            intonationLabel = "Error: Model file not found."
            return
        }

        do {
            let itpr = try Interpreter(modelPath: modelPath)
            self.interpreter = itpr

            // Alokasikan sekali agar kita bisa baca info tensor (beberapa model butuh ini untuk expose shape)
            try itpr.allocateTensors()

            let inTensor = try itpr.input(at: 0)
            let dims = inTensor.shape.dimensions
            self.inputBaseShape = dims
            self.inputRank = dims.count

            // Ukuran "samples" biasanya ada di dimensi terakhir
            self.requiredInputSize = max(dims.last ?? 0, 0)  // bisa 0 kalau model flexible (dynamic)
            print("✅ Model loaded. Original input shape: \(dims) rank=\(inputRank) last=\(requiredInputSize)")

        } catch {
            print("❌ Error: Failed to configure TFLite interpreter: \(error)")
            intonationLabel = "Error: Could not load model."
        }
    }

    
    func analyze(buffer: AVAudioPCMBuffer) {
        guard requiredInputSize > 0 else { return }
        guard let convertedBuffer = convertAudio(buffer: buffer) else { return }
        
        let frameLength = Int(convertedBuffer.frameLength)
        guard let channelData = convertedBuffer.floatChannelData?.pointee else { return }
        let floatArray = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        audioBuffer.append(contentsOf: floatArray)
        
        while audioBuffer.count >= requiredInputSize {
            let chunkToProcess = Array(audioBuffer.prefix(requiredInputSize))
            audioBuffer.removeFirst(requiredInputSize)
            runInference(on: chunkToProcess)
        }
    }


    private func runInference(on audioChunk: [Float]) {
        guard let interpreter = interpreter else { return }
        guard !audioChunk.isEmpty else { return }

        do {
            // 1) Siapkan shape 2D: [1, samples]
            let newShapeArray: [Int]
            if inputRank == 2 {
                newShapeArray = [1, audioChunk.count]
            } else if inputRank == 1 {
                newShapeArray = [audioChunk.count]
            } else {
                print("❌ Unexpected input rank \(inputRank).")
                return
            }

            // MARK: - THE FIX IS HERE
            // Bungkus array [Int] ke dalam struktur Tensor.Shape
            let newShape = Tensor.Shape(newShapeArray)
            
            try interpreter.resizeInput(at: 0, to: newShape)
            try interpreter.allocateTensors()  // WAJIB setelah resize

            // 2) Copy data
            let inputData = Data(buffer: UnsafeBufferPointer(start: audioChunk, count: audioChunk.count))
            try interpreter.copy(inputData, toInputAt: 0)

            // 3) Invoke
            try interpreter.invoke()

            // 4) Ambil dua output: pitch & uncertainty
            let pitchTensor = try interpreter.output(at: 0)
            let unctTensor  = try interpreter.output(at: 1)

            let pitchVals = pitchTensor.data.toArray(type: Float.self)
            let unctVals  = unctTensor.data.toArray(type: Float.self)
            let confVals  = unctVals.map { 1.0 - $0 }  // confidence

            // 5) Konversi ke Hz dan filter berdasarkan confidence
            let f0Hz = zip(pitchVals, confVals).compactMap { (p, c) -> Double? in
                guard c >= 0.85 else { return nil }
                return Double(spiceOutputToHz(p))
            }

            updatePitchHistory(with: f0Hz)

        } catch {
            print("❌ Error: Failed during TFLite inference: \(error)")
        }
    }
    
    @inline(__always)
    private func spiceOutputToHz(_ p: Float) -> Float {
        // Parameter publik SPICE (konstan)
        let PT_OFFSET: Float = 25.58
        let PT_SLOPE:  Float = 63.07
        let FMIN:      Float = 10.0
        let BINS_PER_OCT: Float = 12.0
        let cqtBin = p * PT_SLOPE + PT_OFFSET
        return FMIN * powf(2.0, cqtBin / BINS_PER_OCT)
    }


    
    // ... Sisa file (updatePitchHistory, dll.) tidak ada perubahan ...
    private func updatePitchHistory(with newPitches: [Double]) {
        let validPitches = newPitches.filter { $0 > 0.0 }
        guard !validPitches.isEmpty else { return }
        pitchHistory.append(contentsOf: validPitches)
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
