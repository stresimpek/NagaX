//
//  EyeContactEvaluationView.swift
//  PublicSpeakingAPP
//
//  Created by Gemini on 19/11/25.
//

import SwiftUI
import AVKit

struct EyeContactEvaluationView: View {
    let videoURL: URL?
    
    @StateObject private var audioPlayerVM = AudioPlayerService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if let url = videoURL {
                ZStack {
                    VideoPlayer(player: audioPlayerVM.player)
                        .frame(height: 220)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.baseColorBrown.opacity(0.2), lineWidth: 1)
                        )
                }
                // --- DEBUG TEXT (Hapus nanti kalau sudah fix) ---
                Text("Debug URL: \(url.lastPathComponent)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            } else {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Rekaman simulasi tidak tersedia.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    // --- DEBUG TEXT ---
                    Text("Debug Status: URL is nil")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Controls
            HStack(spacing: 16) {
                Button(action: {
                    if audioPlayerVM.isPlaying {
                        audioPlayerVM.pause()
                    } else {
                        audioPlayerVM.resume()
                    }
                }) {
                    Image(systemName: audioPlayerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.baseColorBrown)
                }
                .disabled(videoURL == nil)
                
                ProgressView(value: audioPlayerVM.playbackProgress)
                    .tint(.baseColorBrown)
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            if let url = videoURL {
                print("👁️ EyeContactView received URL: \(url)")
                audioPlayerVM.setupForVideo(url: url)
            } else {
                print("👁️ EyeContactView received NIL URL")
            }
        }
        .onDisappear {
            audioPlayerVM.stopPlayback()
        }
    }
}
