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

class MicMonitor: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private let bus: AVAudioNodeBus = 0
    
    @Published var levels: [CGFloat] = Array(repeating: 5, count: 20)
    
    init() {
        inputNode = audioEngine.inputNode
    }
    
    func startMonitoring() {
        guard let inputNode else { return }
        stopMonitoring() // avoid duplicate taps
        
        let format = inputNode.inputFormat(forBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            print("Mic monitoring started")
        } catch {
            print("AudioEngine failed to start:", error.localizedDescription)
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
        let normalized = max(0.05, min(1.0, CGFloat(rms) * 10)) // smoother normalization
        
        DispatchQueue.main.async {
            self.levels.removeFirst()
            self.levels.append(normalized * 60)
        }
    }
}
