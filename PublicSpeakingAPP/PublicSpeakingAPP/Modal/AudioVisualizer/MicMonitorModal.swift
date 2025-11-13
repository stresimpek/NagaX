//
//  MicMonitor.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 02/11/25.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

class MicMonitorModal: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private let bus: AVAudioNodeBus = 0
    
    @Published var levels: [CGFloat] = Array(repeating: 5, count: 33)
    
    init() {
        setupAudioSession()
        inputNode = audioEngine.inputNode
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .record instead of .playAndRecord
            // Use .default mode for better sensitivity than .measurement
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            print("Audio session configured")
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func startMonitoring() {
        guard let inputNode else {
            print("No audio input node available")
            return
        }
        
        stopMonitoring() // avoid duplicate taps
        
        // Ensure engine is prepared
        audioEngine.prepare()
        
        // Get format
        let format = inputNode.inputFormat(forBus: bus)
        
        // Validate format
        guard format.sampleRate > 0, format.channelCount > 0 else {
            print("Invalid format - SR: \(format.sampleRate), Ch: \(format.channelCount)")
            
            // Try to fix by reactivating audio session
            setupAudioSession()
            
            // Retry once
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.retryStartMonitoring()
            }
            return
        }
        
        // Install tap
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            print("Mic monitoring started - \(format.sampleRate)Hz, \(format.channelCount)ch")
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
    }
    
    private func retryStartMonitoring() {
        guard let inputNode else { return }
        
        let format = inputNode.inputFormat(forBus: bus)
        
        guard format.sampleRate > 0, format.channelCount > 0 else {
            print("Still invalid after retry - microphone unavailable")
            return
        }
        
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            print("Mic monitoring started after retry")
        } catch {
            print("Failed after retry: \(error)")
        }
    }
    
    func stopMonitoring() {
        inputNode?.removeTap(onBus: bus)
        audioEngine.stop()
        print("Mic monitoring stopped")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let rms = sqrt((0..<frameLength).reduce(0) { $0 + pow(channelData[$1], 2) } / Float(frameLength))
        let normalized = max(0.05, min(1.0, CGFloat(rms) * 10))
        
        DispatchQueue.main.async {
            self.levels.removeFirst()
            self.levels.append(normalized * 60)
        }
    }
}
