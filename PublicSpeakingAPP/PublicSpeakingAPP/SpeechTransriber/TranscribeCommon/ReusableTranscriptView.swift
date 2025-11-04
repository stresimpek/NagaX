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
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ForEach(pages.indices, id: \.self) { index in
                    let page = pages[index]
                    
                    VStack(spacing: 0) {
                        
                        HStack {
                            Text(formatTimestamp(page.startTime, page.endTime))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 8) {
                                Button(action: { jumpToWord(globalIndex: currentJumperIndex - 1) }) {
                                    Image(systemName: "chevron.left")
                                }
                                .disabled(currentJumperIndex <= 1)
                                
                                Text("\(currentJumperIndex) / \(maps.totalCount) kata")
                                    .font(.caption.monospacedDigit().bold())
                                
                                Button(action: { jumpToWord(globalIndex: currentJumperIndex + 1) }) {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(currentJumperIndex >= maps.totalCount)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        
                        Text(page.attributedString)
                            .font(.system(.body, design: .serif))
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        
                        Spacer(minLength: 10)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                if let url = savedRecordingURL {
                                    audioPlayerVM.playSegment(url: url, page: page)
                                } else {
                                    
                                }
                            }) {
                                Image(systemName: audioPlayerVM.isPlayingPageID == page.id ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                            }
                            
                            ProgressView(value: audioPlayerVM.isPlayingPageID == page.id ? audioPlayerVM.playbackProgress : 0.0)
                                .tint(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    .tag(index)
                }
            }
        }
        .frame(minHeight: 150)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
