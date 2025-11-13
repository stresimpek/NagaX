//
//  AudioPlayerService.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 04/11/25.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlayerService: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published private(set) var isPlayingPageID: UUID?
    @Published private(set) var playbackProgress: Double = 0.0

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var segmentEndTime: Double?

    init() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try s.setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
    }

    // MARK: - Public API

    /// Main case: play dari cursorTime (tanpa batas end)
    func play(from url: URL, startAt seconds: Double = 0) {
        playFromCursor(url: url, startAt: seconds)
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let t = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    func stopPlayback() {
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self)
        player = nil
        isPlaying = false
        isPlayingPageID = nil
        playbackProgress = 0.0
        currentTime = 0.0
        duration = 0.0
        segmentEndTime = nil
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

    // MARK: - Private helpers

    private func playFromCursor(url: URL, startAt seconds: Double) {
        isPlayingPageID = nil
        setupAndPlay(url: url, startAt: seconds, endAt: nil, trackPageProgress: false)
    }

    /// Helper tunggal yang meniru pola `playSegment` (seek → add timeObserver → play)
    private func setupAndPlay(url: URL,
                              startAt: Double,
                              endAt: Double?,
                              trackPageProgress: Bool)
    {
        // Reuse kalau URL sama
        if let player,
           let item = player.currentItem,
           let assetURL = (item.asset as? AVURLAsset)?.url,
           assetURL == url
        {
            segmentEndTime = endAt
            attachTimeObserver(trackPageProgress: trackPageProgress)
            let t = CMTime(seconds: max(0, startAt), preferredTimescale: 600)
            player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                guard let self, finished else { return }
                self.player?.play()
                self.isPlaying = true
            }
            return
        }

        // Player baru
        stopPlayback()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        segmentEndTime = endAt

        // Update duration begitu siap
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(itemReadyToPlay),
                                               name: .AVPlayerItemNewAccessLogEntry,
                                               object: item)

        // Seek lalu play (meniru pola yang sudah jalan di playSegment)
        let startTime = CMTime(seconds: max(0, startAt), preferredTimescale: 600)
        player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self, finished else { return }
            self.attachTimeObserver(trackPageProgress: trackPageProgress)
            self.player?.play()
            self.isPlaying = true
        }
    }

    @objc private func itemReadyToPlay() {
        if let d = player?.currentItem?.duration.seconds, d.isFinite {
            duration = d
        }
    }

    private func attachTimeObserver(trackPageProgress: Bool) {
        // Bersihkan observer lama
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        guard let player else { return }

        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let t = time.seconds
            self.currentTime = t

            // Duration (fallback kalau sebelumnya indefinite)
            if let d = player.currentItem?.duration.seconds, d.isFinite {
                self.duration = d
            }

            // Hitung progress umum (berdasarkan duration file)
            if self.duration > 0 {
                self.playbackProgress = min(1.0, max(0.0, t / self.duration))
            }

            // Auto-stop saat mencapai endAt (untuk segmen)
            if let end = self.segmentEndTime, t >= end {
                self.stopPlayback()
                return
            }

            // Auto-stop saat file selesai
            if let d = player.currentItem?.duration.seconds,
               d.isFinite, t >= d
            {
                self.stopPlayback()
                return
            }
        }
    }
}
