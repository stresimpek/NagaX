//
//  AudioRecorder.swift
//  NagaX
//
//  Created by Jordan on 02/10/25.
//

import AVFoundation

class AudioRecorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var outputURL: URL?
    
    func startRecording() {
        configureAudioSession()
        
        let format = engine.inputNode.inputFormat(forBus: 0)
        
        let fileName = "recorded.wav"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        outputURL = url
        
        file = try? AVAudioFile(forWriting: url, settings: format.settings)
        
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            try? self.file?.write(from: buffer)
        }
        
        try? engine.start()
    }
    
    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record)
        try? session.setMode(.measurement)
        try? session.setActive(true)
    }
}
