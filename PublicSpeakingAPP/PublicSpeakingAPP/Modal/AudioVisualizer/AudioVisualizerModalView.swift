//
//  AudioVisualizerView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 02/11/25.
//


import SwiftUI

struct AudioVisualizerModalView: View {
    @ObservedObject var micMonitor: MicMonitorModal
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(micMonitor.levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 3, height: micMonitor.levels[i])
            }
        }
        .frame(height: 50)
        .animation(.easeOut(duration: 0.15), value: micMonitor.levels)
    }
}

