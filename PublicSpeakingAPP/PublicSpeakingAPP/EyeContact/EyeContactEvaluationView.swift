//
//  EyeContactEvaluationView.swift
//  PublicSpeakingAPP
//
//  Created by Gemini on 19/11/25.
//

import SwiftUI
import AVKit
import Combine

struct EyeContactEvaluationView: View {
    
    let videoURL: URL?
    var gazeEvents: [GazeLogItem] = []
    
    @StateObject private var audioPlayerVM = AudioPlayerService()
    @State private var currentIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: - 1. Video Player Area
            if let url = videoURL {
                ZStack {
                    if let player = audioPlayerVM.player {
                        // Jika video masih bermasalah, mutekan player sebagai langkah pencegahan audio
                        VideoPlayer(player: player)
                    } else {
                        Rectangle()
                            .fill(Color.black.opacity(0))
                            .overlay(ProgressView())
                    }
                }
                .frame(height: 220)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BaseColorBrown").opacity(0.2), lineWidth: 1)
                )
            } else {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Rekaman simulasi tidak tersedia.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            Divider()
                .padding(.vertical, 8) // Pembatas antara Video dan Event Controls
            
            // MARK: - 2. CONTROLS NAVIGASI EVENT
            // Teks "Tidak ada isu..." sudah dihapus.
            // Jika tidak ada event, bagian ini tidak akan merender apa-apa.
            if !gazeEvents.isEmpty, let url = videoURL {
                eventNavigationControlCard(url: url)
            }
        }
        .onAppear {
            if let url = videoURL {
                audioPlayerVM.setupForVideo(url: url)
            }
        }
        .onDisappear {
            audioPlayerVM.stopPlayback()
        }
    }
}

// MARK: - Subviews & Logic
private extension EyeContactEvaluationView {
    
    // UI Kontrol Navigasi Event (SEGMENT PLAYBACK)
    @ViewBuilder
    private func eventNavigationControlCard(url: URL) -> some View {
        let currentEvent = gazeEvents[currentIndex]
        
        VStack(alignment: .leading, spacing: 12) {
            
            // --- INFO EVENT ---
            VStack(alignment: .leading, spacing: 4) {
                Text("Titik Isu: Event \(currentIndex + 1) dari \(gazeEvents.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: currentEvent.event == "Up" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.title3)
                    Text(currentEvent.event == "Up" ? "Mata Lihat Atas (\(formatTimestamp(seconds: currentEvent.timestamp)))" : "Mata Lihat Bawah (\(formatTimestamp(seconds: currentEvent.timestamp)))")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(currentEvent.event == "Up" ? .orange : .red)
            }
            
            // --- PLAYBACK CONTROLS SEGMENT (Tombol & Progress) ---
            HStack(spacing: 12) {
                // Tombol Navigasi Chevron
                Group {
                    Button(action: { jumpToEvent(index: currentIndex - 1) }) {
                        Image(systemName: "chevron.left.circle.fill")
                    }
                    .disabled(currentIndex <= 0)
                    
                    Button(action: { jumpToEvent(index: currentIndex + 1) }) {
                        Image(systemName: "chevron.right.circle.fill")
                    }
                    .disabled(currentIndex >= gazeEvents.count - 1)
                }
                .font(.title2)
                .foregroundColor(Color("BaseColorBrown"))
                
                Spacer()
                
                // Tombol Play Segmen
                Button(action: {
                    playSegmentForEvent(event: currentEvent, url: url)
                }) {
                    let isPlayingThisSegment = audioPlayerVM.isPlaying && (audioPlayerVM.isPlayingPageID != nil)
                    
                    Image(systemName: isPlayingThisSegment ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("BaseColorBrown"))
                        .frame(width: 44, height: 44)
                }
                
                // Progress Bar Segmen
                ProgressView(value: audioPlayerVM.isPlaying ? audioPlayerVM.playbackProgress : 0.0)
                    .tint(Color("BaseColorBrown"))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Logic Functions
    
    func jumpToEvent(index: Int) {
        guard index >= 0 && index < gazeEvents.count else { return }
        withAnimation {
            audioPlayerVM.stopPlayback()
            currentIndex = index
        }
    }
    
    func playSegmentForEvent(event: GazeLogItem, url: URL) {
        let clipStart = max(0, event.timestamp - 1.5)
        let clipEnd = event.timestamp + 1.5
        
        let dummyPage = TranscriptPage(
            attributedString: AttributedString("Gaze Event"),
            startTime: clipStart,
            endTime: clipEnd
        )
        
        audioPlayerVM.playSegment(url: url, page: dummyPage)
    }
    
    func formatTimestamp(seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
