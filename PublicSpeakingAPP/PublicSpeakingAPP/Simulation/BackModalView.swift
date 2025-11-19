//
//  BackModalView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 18/11/25.
//

import SwiftUI

struct BackModalView: View {
    let onBackHome: () -> Void
    let onPause: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Image("SetupPaper")
                .resizable()
                .aspectRatio(contentMode: .fill)

            VStack(spacing: 24) {
                    Text("Simulation Paused")
                        .font(.title3)
                        .foregroundColor(.baseColorBrown)
                        .multilineTextAlignment(.center)
                        .underline(true)

                HStack(spacing: 24) {
                    ButtonComponent(
                        title: nil,
                        systemImage: "house.fill",
                        size: .largeIconCircle,
                        kind: .primaryYellow,
                        customCircleSize: 60,
                        action: onBackHome
                    )
                    ButtonComponent(
                        title: nil,
                        systemImage: "play.fill",
                        size: .largeIconCircle,
                        kind: .primaryYellow,
                        customCircleSize: 85,
                        action: onPause
                    )
                    ButtonComponent(
                        title: nil,
                        systemImage: "arrow.trianglehead.counterclockwise",
                        size: .largeIconCircle,
                        kind: .primaryYellow,
                        customCircleSize: 60,
                        action: onRetry
                    )
                }
            }
            .frame(width: 317)
        }
        .frame(width: 370.73706, height: 190.9482)
 
    }
}

