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
    private var sessionStartTime: CMTime? = nil
    private var outputURL: URL?

    private let frameSize = CGSize(width: 1300, height: 720)
    
    func start(outputURL: URL) {
        self.outputURL = outputURL
        self.sessionStartTime = nil // Reset waktu mulai
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: frameSize.width,
                AVVideoHeightKey: frameSize.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            if let writer = assetWriter, let input = videoInput {
                if writer.canAdd(input) {
                    writer.add(input)
                }
                
                if writer.startWriting() {
                    // HAPUS BARIS INI: writer.startSession(atSourceTime: .zero)
                    // KITA JANGAN MULAI SESSION DI SINI.
                    
                    isRecording = true
                    print("✅ ARVideoRecorder: Writer ready (Waiting for first frame)")
                }
            }
            
        } catch {
            print("❌ ARVideoRecorder Init Error: \(error)")
        }
    }
    
    func stop(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer = assetWriter, let input = videoInput else {
            completion(nil)
            return
        }
        
        isRecording = false
        input.markAsFinished()
        
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if writer.status == .completed {
                    print("✅ Video Saved: \(self.outputURL?.absoluteString ?? "")")
                    completion(self.outputURL)
                } else {
                    print("❌ Save Failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                }
                // Bersihkan resource
                self.assetWriter = nil
                self.videoInput = nil
                self.pixelBufferAdaptor = nil
            }
        }
    }
    
    func record(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard isRecording,
              let writer = assetWriter,
              let input = videoInput,
              let adaptor = pixelBufferAdaptor else { return }
        
        if writer.status == .failed {
            print("❌ Writer Failed: \(writer.error?.localizedDescription ?? "")")
            isRecording = false
            return
        }
        
        // Konversi timestamp dari ARKit ke CMTime
        let presentationTime = CMTime(seconds: timestamp, preferredTimescale: 600)
        
        // LOGIKA KUNCI: Mulai session saat frame PERTAMA datang
        if sessionStartTime == nil {
            sessionStartTime = presentationTime
            writer.startSession(atSourceTime: presentationTime)
            print("🚀 ARVideoRecorder: Session Started at \(timestamp)")
        }
        
        // Pastikan input siap
        if input.isReadyForMoreMediaData {
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
    }
}
