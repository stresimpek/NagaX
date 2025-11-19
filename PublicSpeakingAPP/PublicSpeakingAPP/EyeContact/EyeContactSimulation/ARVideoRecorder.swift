//
//  ARVideoRecorder.swift
//  PublicSpeakingAPP
//
//  Created by Gemini on 19/11/25.
//

import AVFoundation
import UIKit

class ARVideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isRecording = false
    private var startTime: CMTime = .zero
    private var outputURL: URL?
    
    // Gunakan resolusi standar 720p Portrait
    private let frameSize = CGSize(width: 720, height: 1280)
    
    func start(outputURL: URL) {
        self.outputURL = outputURL
        
        // 1. PENTING: Hapus file lama jika ada. AVAssetWriter gagal jika file exist.
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            // 2. Setting Kompresi Video
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: frameSize.width,
                AVVideoHeightKey: frameSize.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            // 3. Gunakan BGRA (Format standar ARKit di banyak device)
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: frameSize.width,
                kCVPixelBufferHeightKey as String: frameSize.height
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            if let writer = assetWriter, let input = videoInput {
                if writer.canAdd(input) {
                    writer.add(input)
                } else {
                    print("❌ ARVideoRecorder: Cannot add input to writer")
                    return
                }
                
                // Start writing
                if writer.startWriting() {
                    writer.startSession(atSourceTime: .zero)
                    isRecording = true
                    startTime = .zero
                    print("✅ ARVideoRecorder: Started writing to \(outputURL.lastPathComponent)")
                } else {
                    print("❌ ARVideoRecorder: Failed to start writing. Error: \(String(describing: writer.error))")
                }
            }
            
        } catch {
            print("❌ ARVideoRecorder Init Error: \(error)")
        }
    }
    
    func stop(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer = assetWriter, let input = videoInput else {
            print("⚠️ ARVideoRecorder: Stop called but not recording.")
            completion(nil)
            return
        }
        
        isRecording = false
        input.markAsFinished()
        
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if writer.status == .completed {
                    print("✅ ARVideoRecorder: Finished successfully. URL: \(self.outputURL?.absoluteString ?? "nil")")
                    completion(self.outputURL)
                } else {
                    print("❌ ARVideoRecorder: Failed to finish. Status: \(writer.status.rawValue), Error: \(String(describing: writer.error))")
                    completion(nil)
                }
            }
        }
    }
    
    func record(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard isRecording,
              let writer = assetWriter,
              let input = videoInput,
              let adaptor = pixelBufferAdaptor else { return }
        
        if writer.status == .failed {
            print("❌ Writer Failed while recording: \(String(describing: writer.error))")
            isRecording = false
            return
        }
        
        let presentationTime = CMTime(seconds: timestamp, preferredTimescale: 600)
        
        // Set start time pada frame pertama
        if startTime == .zero {
            startTime = presentationTime
            writer.startSession(atSourceTime: presentationTime)
        }
        
        if input.isReadyForMoreMediaData {
            let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            if !success {
                print("⚠️ Dropped frame at \(timestamp)")
            }
        }
    }
}
