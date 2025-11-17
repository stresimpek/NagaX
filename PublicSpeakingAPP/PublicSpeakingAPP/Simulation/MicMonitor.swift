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
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bus: AVAudioNodeBus = 0
    private var isMonitoring = false
    private var displayTimer: Timer?

    @Published var levels: [CGFloat] = Array(repeating: 20, count: 20)

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                print("❌ Microphone permission denied")
                return
            }
            DispatchQueue.main.async {
                self?.setupAndStartEngine()
            }
        }
    }

    private func setupAndStartEngine() {
        let session = AVAudioSession.sharedInstance()

        // NUCLEAR RESET: Stop everything first
        audioEngine?.stop()
        audioEngine?.reset()
        audioEngine = nil
        inputNode = nil

        do {
            // Force deactivate
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            Thread.sleep(forTimeInterval: 0.2)
            
            // Configure session for recording
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            Thread.sleep(forTimeInterval: 0.1)
            try session.setActive(true)
            Thread.sleep(forTimeInterval: 0.2)
            
            // NOW create engine after session is fully active
            audioEngine = AVAudioEngine()
            guard let engine = audioEngine else {
                print("❌ Failed to create engine")
                startSimulatedMonitoring()
                return
            }
            
            inputNode = engine.inputNode
            let inputNode = engine.inputNode
            
            // Wait a bit before getting format
            Thread.sleep(forTimeInterval: 0.1)
            
            let format = inputNode.inputFormat(forBus: bus)
            
            print("🔍 Format check: SR=\(format.sampleRate), Ch=\(format.channelCount)")
            
            guard format.sampleRate > 0, format.channelCount > 0 else {
                print("❌ Invalid format - falling back to simulation")
                cleanupEngine()
                startSimulatedMonitoring()
                return
            }
            
            print("✅ Valid format: \(format.sampleRate) Hz, \(format.channelCount) channels")
            
            inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            try engine.start()
            isMonitoring = true
            print("🎙️ Mic monitoring started successfully")
            
        } catch {
            print("❌ Audio setup error: \(error.localizedDescription)")
            cleanupEngine()
            startSimulatedMonitoring()
        }
    }

    func stopMonitoring() {
        displayTimer?.invalidate()
        displayTimer = nil

        guard isMonitoring || audioEngine != nil else { return }

        inputNode?.removeTap(onBus: bus)
        audioEngine?.stop()
        audioEngine?.reset()
        cleanupEngine()
        isMonitoring = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("⚠️ Session deactivation failed:", error.localizedDescription)
        }

        print("🛑 Mic monitoring stopped")
    }

    private func cleanupEngine() {
        inputNode = nil
        audioEngine = nil
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let rms = sqrt((0..<frameLength).reduce(0) { $0 + pow(channelData[$1], 2) } / Float(frameLength))
        let normalized = max(0.05, min(1.0, CGFloat(rms) * 10))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.levels.isEmpty {
                self.levels.removeFirst()
                self.levels.append(normalized * 60)
            }
        }
    }

    private func startSimulatedMonitoring() {
        displayTimer?.invalidate()
        isMonitoring = true

        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            DispatchQueue.main.async {
                let newLevel = CGFloat.random(in: 8...45)
                self.levels.removeFirst()
                self.levels.append(newLevel)
            }
        }

        print("🎙️ Simulated monitoring started")
    }
}
