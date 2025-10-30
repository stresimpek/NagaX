//
//  ImageSequenceView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI
import Combine

struct ImageSequenceView: View {
    let baseName: String = "teacher_happy"
    let frameCount: Int = 15
    let fps: Double = 12

    @State private var frameIndex = 0

    var body: some View {
        Image("\(baseName)_\(frameIndex + 1)")
            .resizable()
            .scaledToFit()
            .onReceive(Timer.publish(every: 1.0 / fps, on: .main, in: .common).autoconnect()) { _ in
                frameIndex = (frameIndex + 1) % frameCount  // loop terus
            }
    }
}
