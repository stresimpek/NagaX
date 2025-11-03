//
//  AudioVisualizerBoxView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 02/11/25.
//


import SwiftUI

struct AudioVisualizerBoxView: View {
    @ObservedObject var micMonitor: MicMonitor
    var micIcon: String = "mic.circle.fill"
    var width: CGFloat = 200
    var height: CGFloat = 50
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .frame(width: width, height: height + 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: micIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                
                AudioVisualizerView(micMonitor: micMonitor)
                    .frame(height: height)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
        }
    }
}
