//
//  EyeContactEvaluationView.swift
//  PublicSpeakingAPP
//
//

import SwiftUI
import AVKit

struct EyeContactEvaluationView: View {
    let videoURL: URL?
    let gazeEvents: [GazeLogItem]
    
    @State private var player: AVPlayer?
    @State private var currentIssueIndex: Int = 0
    @State private var timeObserverToken: Any?
    @State private var isSeeking = false
    
    var issues: [GazeLogItem] {
        return gazeEvents.sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            HStack {
                if !issues.isEmpty {
                    let currentItem = issues[currentIssueIndex]
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(formatTime(currentItem.startTime)) - \(formatTime(currentItem.endTime))")
                    }
                    .font(.footnote.bold())
                    .foregroundColor(Color("BaseColorBrown"))
                } else {
                    Text("00:00")
                        .font(.footnote.bold())
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { changeClip(to: currentIssueIndex - 1) }) {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color("BaseColorBrown").opacity(0.3), lineWidth: 1))
                    }
                    .disabled(currentIssueIndex <= 0 || issues.isEmpty)
                    .opacity(currentIssueIndex <= 0 || issues.isEmpty ? 0.5 : 1.0)
                    
                    if !issues.isEmpty {
                        Text("**\(currentIssueIndex + 1)** / \(issues.count)")
                            .font(.footnote.bold())
                            .foregroundColor(Color("BaseColorBrown"))
                            .monospacedDigit()
                    } else {
                        Text("- / -")
                            .font(.footnote.bold())
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: { changeClip(to: currentIssueIndex + 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color("BaseColorBrown").opacity(0.3), lineWidth: 1))
                    }
                    .disabled(currentIssueIndex >= issues.count - 1 || issues.isEmpty)
                    .opacity(currentIssueIndex >= issues.count - 1 || issues.isEmpty ? 0.5 : 1.0)
                }
                .foregroundColor(Color("BaseColorBrown"))
            }
            .padding(.horizontal, 4)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 400)
                
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 400)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("BaseColorBrown").opacity(0.5), lineWidth: 1)
                        )
                } else {
                    VStack {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Video tidak tersedia")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if !issues.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            let type = issues[currentIssueIndex].event
                            
                            Text(labelForEvent(type))
                                .font(.caption).bold()
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.bottom, 16)
                                .padding(.leading, 16)
                            Spacer()
                        }
                    }
                }
            }
            
            if issues.isEmpty {
                Text("Hebat! Kontak matamu sangat terjaga.")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("Video dipotong khusus momen gangguan kontak mata.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanUpPlayer()
        }
    }
    
    private func setupPlayer() {
        guard let url = videoURL else { return }
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer
        
        addPeriodicTimeObserver()
        
        if !issues.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                changeClip(to: 0)
            }
        }
    }
    
    private func cleanUpPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
    }
    
    private func addPeriodicTimeObserver() {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.1, preferredTimescale: timeScale)
        
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak player] time in
            guard let player = player, !issues.isEmpty else { return }
            guard !isSeeking else { return }
            
            let currentItem = issues[currentIssueIndex]
            let currentTime = time.seconds
            
            if currentTime >= currentItem.endTime {
                print("🔁 Loop clip back to start: \(currentItem.startTime)")
                
                let targetTime = CMTime(seconds: currentItem.startTime, preferredTimescale: 600)
                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
    
    private func changeClip(to index: Int) {
        guard issues.indices.contains(index), let player = player else { return }
        
        withAnimation {
            currentIssueIndex = index
        }
        
        isSeeking = true
        let issue = issues[index]
        
        let startTime = max(0, issue.startTime - 0.5)
        let cmTime = CMTime(seconds: startTime, preferredTimescale: 600)
        
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            self.isSeeking = false
            player.play()
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%02d:%02d", min, sec)
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
