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
    
    var issues: [GazeLogItem] {
        return gazeEvents.sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            HStack {
                if !issues.isEmpty {
                    let currentTimestamp = issues[currentIssueIndex].timestamp
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(formatTime(currentTimestamp))
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
                    Button(action: { jumpToIssue(index: currentIssueIndex - 1) }) {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color("BaseColorBrown").opacity(0.3), lineWidth: 1))
                    }
                    .disabled(currentIssueIndex <= 0 || issues.isEmpty)
                    .opacity(currentIssueIndex <= 0 || issues.isEmpty ? 0.5 : 1.0)
                    
                    // Indikator Posisi (e.g., 1 / 5)
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
                    
                    // Tombol Next
                    Button(action: { jumpToIssue(index: currentIssueIndex + 1) }) {
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
                    .frame(height: 400) // Tinggi Video
                
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
                Text("Tekan tombol panah di atas untuk melompat ke momen saat pandanganmu teralihkan.")
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
            player?.pause()
        }
    }
    
    
    private func setupPlayer() {
        guard let url = videoURL else { return }
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer
        
        if !issues.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                jumpToIssue(index: 0)
            }
        }
    }
    
    private func jumpToIssue(index: Int) {
        guard issues.indices.contains(index), let player = player else { return }
   
        withAnimation {
            currentIssueIndex = index
        }
        
        let issue = issues[index]
        let timestamp = issue.timestamp
        
        let seekTime = max(0, timestamp - 1.5)
        let cmTime = CMTime(seconds: seekTime, preferredTimescale: 600)
        
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        if player.timeControlStatus != .playing {
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
        case "HeadUp":
            return "Kepala Terlalu Naik"
        case "HeadDown":
            return "Kepala Menunduk"
        case "GazeUp":
            return "Mata Melihat ke Atas"
        case "GazeDown":
            return "Mata Melihat ke Bawah"
        default:
            return "Gangguan Kontak Mata"
        }
    }
}
