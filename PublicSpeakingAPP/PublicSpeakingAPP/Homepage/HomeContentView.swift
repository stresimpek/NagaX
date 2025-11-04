//
//  HomeContentView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI
import RiveRuntime

struct SpeakerLevel {
    let title: String
    let imageName: String
}

struct HomeContentView: View {
    let levels: [SpeakerLevel] = [
        SpeakerLevel(title: "Noob Speaker", imageName: "blobFish"),
        SpeakerLevel(title: "Professional Speaker", imageName: "beluga")
    ]

    @State private var currentLevelIndex = 0
    
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("Presentasimu dimulai dalam: ")
                CountdownBox(text: "3")
                Text("hari ")
                CountdownBox(text: "20")
                Text("jam ")
                CountdownBox(text: "30")
                Text("menit")
            }
            .font(.system(size: 16))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.darkBlue)
            .foregroundStyle(Color.white)
            
            Spacer()
            
            HStack(alignment: .top) {
                VStack {
                    Image(.titleNoob)
                        .resizable()
                        .frame(width: 180, height: 34)
                    
                    RiveViewModel(fileName:"noob cako new").view()
                        .frame(width: 200, height: 120)
                    
                    ButtonComponent(
                        title: "MULAI LATIHAN",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow,
                        action: onStart
                    )
                    .padding(.bottom, 40)
                }
                Image(.bubbleChat)
                    .resizable()
                    .frame(width: 208, height: 84)
            }
            .padding(.leading, 200)
            .frame(alignment: .top)
        }
        .ignoresSafeArea(edges: .horizontal)
        .background(Color(.baseColorBlue))
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct CountdownBox: View {
    let text: String
    var body: some View {
        Text(text)
            .frame(width: 28, height: 28)
            .background(Color.white)
            .cornerRadius(4)
            .foregroundStyle(Color.black)
    }
}

struct StatBar: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14))
            ProgressView(value: value)
                .progressViewStyle(LinearProgressViewStyle(tint: .black))
                .frame(height: 6)
                .clipShape(Capsule())
        }
    }
}

struct CardButton: View {
    let title: String
    let systemIcon: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                Image(systemName: systemIcon)
                    .font(.title2)
                Text(title)
                    .font(.system(size: 14))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black))
        }
    }
}
