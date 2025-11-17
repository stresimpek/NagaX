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

enum IntonationError: Error, LocalizedError {
    case modelNotFound
    case interpreterFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Error: Model file (spice.tflite) tidak ditemukan."
        case .interpreterFailed(let error):
            return "Error: Gagal memuat model TFLite. \(error.localizedDescription)"
        }
    }
}

@MainActor
final class IntonationAnalyzerViewModel: ObservableObject {
     
    @Published var intonationLabel: String = "Speak to begin..."
    @Published var standardDeviation: Double = 0.0
    @Published var intonationRating: Int = 0
    @Published var publishedError: String? = nil

    @Published var pitchHistory: [(timestamp: TimeInterval, pitch: Double)] = []
    @Published var allPitchHistory: [(timestamp: TimeInterval, pitch: Double)] = []
    private let windowSize: TimeInterval = 10.0
    
    private var interpreter: Interpreter?
    private let requiredSampleRate = 16000.0
    private var audioBuffer = [Float]()
    private let windowSamples = 16000
    private let hopSamples = 8000
    
    private var audioConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)!
     
    init() {
        loadModel()
    }
     
    private func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "spice", ofType: "tflite") else {
            let err = IntonationError.modelNotFound
            print("FATAL: \(err.localizedDescription)")
            self.intonationLabel = "Error: Model file not found."
            self.publishedError = err.localizedDescription
            return
        }
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
            print("TFLite model loaded.")
        } catch {
            let err = IntonationError.interpreterFailed(error)
            print("Interpreter init error: \(err.localizedDescription)")
            self.intonationLabel = "Error: Could not load model."
            self.publishedError = err.localizedDescription
        }
    }
    
    func analyze(buffer: AVAudioPCMBuffer, currentTime: TimeInterval) {
        guard let converted = convertAudio(buffer: buffer) else { return }
        let n = Int(converted.frameLength)
        guard let ch = converted.floatChannelData?.pointee else { return }
        let chunk = Array(UnsafeBufferPointer(start: ch, count: n))
        audioBuffer.append(contentsOf: chunk)

        while audioBuffer.count >= windowSamples {
            let frame = Array(audioBuffer.prefix(windowSamples))
            audioBuffer.removeFirst(hopSamples)
            
            runInference(on: frame, at: currentTime)
        }
    }

    private func runInference(on audioFrame: [Float], at currentTime: TimeInterval) {
        guard let interpreter = interpreter else { return }
        let N = audioFrame.count
        guard N > 0 else { return }

        do {
            try interpreter.resizeInput(at: 0, to: Tensor.Shape([N]))
            try interpreter.allocateTensors()

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
            updatePitchHistory(with: f0Hz, at: currentTime)
            
        } catch {
            print("Inference error: \(error)")
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

    private func updatePitchHistory(with newPitches: [Double], at time: TimeInterval) {
        let valid = newPitches.filter { $0 > 0 }
        guard !valid.isEmpty else { return }

        let newEntries = valid.map { (timestamp: time, pitch: $0) }
        pitchHistory.append(contentsOf: newEntries)
        pitchHistory = pitchHistory.filter { (timestamp, _) in
            (time - timestamp) <= windowSize
        }

        // untuk hasil akhir & chart (tidak difilter)
        allPitchHistory.append(contentsOf: newEntries)
        
        // Kirim `currentTime` untuk proses filter window
        calculateStatistics(at: time)
    }
     
    // Ubah untuk mem-filter berdasarkan `windowSize` 10 detik
    private func calculateStatistics(at currentTime: TimeInterval) {
 
        // Ekstrak nilai pitch dari data yang sudah di-filter
        let pitchesInWindow = pitchHistory.map { $0.pitch }
        
        guard pitchesInWindow.count > 1 else {
            self.standardDeviation = 0.0
            self.intonationLabel = "..."
            self.intonationRating = 0
            return
        }
        
        let mean = pitchesInWindow.reduce(0, +) / Double(pitchesInWindow.count)
        let sumOfSquaredDiffs = pitchesInWindow.map { pow($0 - mean, 2) }.reduce(0, +)
        self.standardDeviation = sqrt(sumOfSquaredDiffs / Double(pitchesInWindow.count))
         
        if standardDeviation < 18.0 {
            self.intonationLabel = "Intonasi Cenderung Datar"
            self.intonationRating = 1
        } else if standardDeviation >= 22.0 && standardDeviation <= 35.0 {
            self.intonationLabel = "Intonasi Sangat Bervariasi!"
            self.intonationRating = 3
        } else if (standardDeviation >= 18.0 && standardDeviation < 22.0) || standardDeviation > 35.0 {
            self.intonationLabel = "Intonasi Cukup Dinamis"
            self.intonationRating = 2
        }
    }
    
    func calculateFinalStandardDeviation() -> Double {
        let allPitches = allPitchHistory.map { $0.pitch }
        
        guard allPitches.count > 1 else {
            print("[IntonationVM Final] GUARD FAILED (total pitches <= 1). Returning 0.0")
            return 0.0
        }
        
        let mean = allPitches.reduce(0, +) / Double(allPitches.count)
        let sumOfSquaredDiffs = allPitches.map { pow($0 - mean, 2) }.reduce(0, +)
        let finalStdDev = sqrt(sumOfSquaredDiffs / Double(allPitches.count))
        
        print("[IntonationVM Final] Total Pitches=\(allPitches.count), Final StdDev=\(finalStdDev)")
        return finalStdDev
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
            print("Error during audio conversion: \(error.localizedDescription)")
            return nil
        }
        return convertedBuffer
    }

    func clearResults() {
        pitchHistory.removeAll()
        audioBuffer.removeAll()
        intonationLabel = "Speak to begin..."
        standardDeviation = 0.0
        intonationRating = 0
        audioConverter = nil
        publishedError = nil
    }
}

extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes { $0.bindMemory(to: T.self) }.map { $0 }
    }
}
