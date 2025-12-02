//
//  ARVideoRecorder.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 19/11/25.
//

import AVFoundation
import UIKit

class ARVideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isRecording = false
    private var isPaused = false
    
    private var sessionStartTime: CMTime? = nil
    private var outputURL: URL?

    private var totalPauseDuration: CMTime = .zero
    private var pauseStartTimestamp: CMTime? = nil
    
    private let frameSize = CGSize(width: 1300, height: 720)
    
    func start(outputURL: URL) {
        self.outputURL = outputURL
        self.sessionStartTime = nil
        self.totalPauseDuration = .zero
        self.pauseStartTimestamp = nil
        self.isPaused = false
        
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
                    isRecording = true
                    print("✅ ARVideoRecorder: Writer ready")
                }
            }
            
        } catch {
            print("❌ ARVideoRecorder Init Error: \(error)")
        }
    }
    
    func pause() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStartTimestamp = nil
        print("⏸️ ARVideoRecorder: PAUSED")
    }
    
    func resume() {
        guard isRecording, isPaused else { return }
        isPaused = false
        print("▶️ ARVideoRecorder: RESUMED")
    }
    
    func stop(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer = assetWriter, let input = videoInput else {
            completion(nil)
            return
        }
        
        isRecording = false
        isPaused = false
        input.markAsFinished()
        
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if writer.status == .completed {
                    completion(self.outputURL)
                } else {
                    completion(nil)
                }
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
        
        let currentTimestamp = CMTime(seconds: timestamp, preferredTimescale: 600)
        
        if isPaused {
            if pauseStartTimestamp == nil {
                pauseStartTimestamp = currentTimestamp
            }
            return
        }
        
        if let pauseStart = pauseStartTimestamp {
            let pauseDuration = CMTimeSubtract(currentTimestamp, pauseStart)
            totalPauseDuration = CMTimeAdd(totalPauseDuration, pauseDuration)
            pauseStartTimestamp = nil
        }
        
        let adjustedTimestamp = CMTimeSubtract(currentTimestamp, totalPauseDuration)
        
        if sessionStartTime == nil {
            sessionStartTime = adjustedTimestamp
            writer.startSession(atSourceTime: adjustedTimestamp)
        }
        
        if input.isReadyForMoreMediaData {
            if let start = sessionStartTime, adjustedTimestamp >= start {
                adaptor.append(pixelBuffer, withPresentationTime: adjustedTimestamp)
            }
        }
    }
}
