//
//  ReusableTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 04/11/25.
//

import SwiftUI
import AVFoundation

struct ReusableTranscriptCardView: View {
    
    let pages: [TranscriptPage]
    let maps: TranscriptMaps
    let savedRecordingURL: URL?
    let emptyStateMessage: String
    
    @State private var currentPageIndex: Int = 0
    @State private var currentJumperIndex: Int = 1
    
    @StateObject private var audioPlayerVM = AudioPlayerService()
    
    var body: some View {
        Group {
            if pages.isEmpty {
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.yellow2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                // Tampilkan hanya satu page sesuai currentPageIndex
                pageView(for: pages[safe: currentPageIndex] ?? pages[0])
            }
        }
        .onDisappear {
            audioPlayerVM.stopPlayback()
        }
    }
    
    @ViewBuilder
    private func pageView(for page: TranscriptPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack {
                Text(formatTimestamp(page.startTime, page.endTime))
                    .font(.footnoteBold)
                    .foregroundColor(.baseColorBrown)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { jumpToWord(globalIndex: currentJumperIndex - 1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentJumperIndex <= 1)
                    
                    Text("**\(currentJumperIndex)** / \(maps.totalPages)")
                        .font(.footnoteBold)
                    
                    Button(action: { jumpToWord(globalIndex: currentJumperIndex + 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentJumperIndex >= maps.totalCount)
                }
                .foregroundColor(.baseColorBrown)
            }
            .padding(.bottom)
            
            Text(page.attributedString)
                .font(.system(.body, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            
            HStack(spacing: 12) {
                Button(action: {
                    if let url = savedRecordingURL {
                        audioPlayerVM.playSegment(url: url, page: page)
                    }
                }) {
                    Image(systemName: audioPlayerVM.isPlayingPageID == page.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.baseColorBrown)
                        .frame(width: 44, height: 44)
                }
                
                ProgressView(value: audioPlayerVM.isPlayingPageID == page.id ? audioPlayerVM.playbackProgress : 0.0)
                    .tint(.baseColorBrown)
            }
            .padding(.top)
        }
    }
    
    private func jumpToWord(globalIndex: Int) {
        guard globalIndex >= 1 && globalIndex <= maps.totalCount else { return }
        
        if let targetPageIndex = maps.wordIndexToPageIndex[globalIndex] {
            currentJumperIndex = globalIndex
            // amanin kalo index out of range
            if targetPageIndex >= 0 && targetPageIndex < pages.count {
                withAnimation {
                    currentPageIndex = targetPageIndex
                }
            }
        }
    }
}

// helper biar aman akses array
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
