//
//  EyeContactEvaluationView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 13/11/25.
//

import SwiftUI
import AVKit

struct EyeContactEvaluationView: View {
    let videoURL: URL?
    let gazeEvents: [GazeLogItem]
    
    @State private var player = AVPlayer()
    @State private var currentIssueIndex: Int = 0
    @State private var loopObserver: NSObjectProtocol?
    @State private var isFullScreen: Bool = false
    
    var issues: [GazeLogItem] {
        return gazeEvents.sorted { $0.startTime < $1.startTime }
    }
    
    private var videoWidth: CGFloat {
        UIScreen.main.bounds.width * 0.45
    }
    
    private var videoHeight: CGFloat {
        videoWidth * (9.0 / 16.0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                if issues.indices.contains(currentIssueIndex) {
                    let currentItem = issues[currentIssueIndex]
                    Text(formatTimestamp(currentItem.startTime, currentItem.endTime))
                        .font(.footnoteBold)
                        .foregroundColor(.baseColorBrown)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { loadClip(at: currentIssueIndex - 1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentIssueIndex <= 0)
                    .opacity(currentIssueIndex <= 0 ? 0.5 : 1.0)
                    
                    Text("**\(currentIssueIndex + 1)** / \(issues.count)")
                        .font(.footnoteBold)
                        .monospacedDigit()
                    
                    Button(action: { loadClip(at: currentIssueIndex + 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentIssueIndex >= issues.count - 1)
                    .opacity(currentIssueIndex >= issues.count - 1 ? 0.5 : 1.0)
                }
                .foregroundColor(.baseColorBrown)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
            
            ZStack {
                if videoURL != nil {
                    CleanClipPlayer(player: player)
                        .frame(width: videoWidth, height: videoHeight)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Color.black.opacity(0.001)
                                .allowsHitTesting(true)
                        )
                } else {
                    ZStack {
                        Color.black.opacity(0.1)
                        VStack {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Video tidak tersedia")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: videoWidth, height: videoHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if issues.indices.contains(currentIssueIndex) {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            let type = issues[currentIssueIndex].event
                            Text(labelForEvent(type))
                                .font(.caption).bold()
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            ButtonComponent(
                                title: "Lihat Full",
                                systemImage: "arrow.up.left.and.arrow.down.right",
                                size: .small,
                                kind: .primaryYellow,
                                action: { isFullScreen = true }
                            )
                        }
                        .padding(.bottom, 12)
                        .padding(.horizontal, 12)
                    }
                    .frame(width: videoWidth, height: videoHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
            
        }
        .onAppear {
            configureAudioSession()
            setupInitialClip()
        }
        .onDisappear {
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            player.pause()
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            ZStack(alignment: .topLeading) {
                
                Color.black.edgesIgnoringSafeArea(.all)
                
                if videoURL != nil {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                }
                
                Button(action: {
                    isFullScreen = false
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(.leading, 20)
                .padding(.top, 10)
            }
            .ignoresSafeArea()
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Gagal setting audio session: \(error)")
        }
    }
    
    private func setupInitialClip() {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak player] notification in
            if let currentItem = player?.currentItem,
               let notifObject = notification.object as? AVPlayerItem,
               currentItem == notifObject {
                player?.seek(to: .zero)
                player?.play()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadClip(at: 0)
        }
    }
    
    private func loadClip(at index: Int) {
        guard issues.indices.contains(index), let url = videoURL else { return }
        
        withAnimation {
            currentIssueIndex = index
        }
        
        let issue = issues[index]
        let asset = AVAsset(url: url)
        let totalDuration = asset.duration.seconds
        
        let startSeconds = max(0, issue.startTime - 3.0)
        let endSeconds = min(totalDuration, issue.endTime + 3.0)
        let durationSeconds = endSeconds - startSeconds
        
        guard durationSeconds > 0 else { return }
        
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
        )
        
        let composition = AVMutableComposition()
        
        do {
            if let videoTrack = asset.tracks(withMediaType: .video).first,
               let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                compVideoTrack.preferredTransform = videoTrack.preferredTransform
            }
            
            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
            
            let playerItem = AVPlayerItem(asset: composition)
            player.replaceCurrentItem(with: playerItem)
            player.play()
            
        } catch {
            print("Error creating clip: \(error)")
        }
    }
    
    private func formatTimestamp(_ startTime: TimeInterval, _ endTime: TimeInterval) -> String {
        let startMinutes = Int(startTime) / 60
        let startSeconds = Int(startTime) % 60
        let endMinutes = Int(endTime) / 60
        let endSeconds = Int(endTime) % 60
        
        return String(format: "%02d:%02d - %02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
    }
    
    private func labelForEvent(_ event: String) -> String {
        switch event {
        case "HeadUp": return "Kepala Terlalu Naik"
        case "HeadDown": return "Kepala Menunduk"
        case "GazeUp": return "Mata Melihat ke Atas"
        case "GazeDown": return "Mata Melihat ke Bawah"
        default: return "Gangguan Kontak Mata"
        }
    }
}

struct CleanClipPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
}
