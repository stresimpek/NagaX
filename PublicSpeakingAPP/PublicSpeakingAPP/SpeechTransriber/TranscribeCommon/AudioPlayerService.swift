//
//  AudioPlayerService.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 04/11/25.
//

import Foundation
import AVFoundation

@MainActor
class AudioPlayerService: ObservableObject {
    
    @Published private(set) var isPlayingPageID: UUID?
    @Published private(set) var playbackProgress: Double = 0.0
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            
        }
    }
    
    func stopPlayback() {
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        isPlayingPageID = nil
        playbackProgress = 0.0
    }
    
    func playSegment(url: URL, page: TranscriptPage) {
        if isPlayingPageID == page.id {
            stopPlayback()
            return
        }
        stopPlayback()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        let startTime = CMTime(seconds: page.startTime, preferredTimescale: 600)
        
        player?.seek(to: startTime, completionHandler: { [weak self] (finished) in
            guard let self = self, finished else { return }
            
            Task { @MainActor in
                self.isPlayingPageID = page.id
                
                self.timeObserverToken = self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
                    
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        let clipStartTime = page.startTime
                        let clipEndTime = page.endTime
                        let clipDuration = clipEndTime - clipStartTime
                        let currentTimeInClip = time.seconds - clipStartTime
                        
                        if clipDuration > 0 {
                            self.playbackProgress = min(1.0, max(0.0, currentTimeInClip / clipDuration))
                        }

                        if time.seconds >= page.endTime {
                            self.stopPlayback()
                        }
                    }
                }
                self.player?.play()
            }
        })
    }
}
