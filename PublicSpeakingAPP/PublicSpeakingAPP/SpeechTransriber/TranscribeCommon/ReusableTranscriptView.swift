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
        TabView(selection: $currentPageIndex) {
            if pages.isEmpty {
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.yellow2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ForEach(pages.indices, id: \.self) { index in
                    let page = pages[index]
                    
                    VStack(alignment: .leading ,spacing: 0) {
                        
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
                                } else {
                                    
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
                    .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: currentPageIndex) {
             audioPlayerVM.stopPlayback()
        }
        .onDisappear {
            audioPlayerVM.stopPlayback()
        }
    }
    
    private func jumpToWord(globalIndex: Int) {
        guard globalIndex >= 1 && globalIndex <= maps.totalCount else { return }
        
        if let targetPageIndex = maps.wordIndexToPageIndex[globalIndex] {
            self.currentJumperIndex = globalIndex
            self.currentPageIndex = targetPageIndex
        }
    }
}
