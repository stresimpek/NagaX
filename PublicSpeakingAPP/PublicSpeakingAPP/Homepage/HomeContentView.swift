//
//  HomeContentView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI

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
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Presentasimu dimulai")
                    CountdownBox(text: "3")
                    Text("hari")
                    CountdownBox(text: "20")
                    Text("jam")
                    CountdownBox(text: "30")
                    Text("menit")
                }
                .font(.system(size: 14))
                .padding(.top, 16)
                
                VStack(spacing: 6) {
                    Text("Kamu 0% siap untuk presentasi")
                        .font(.system(size: 14))
                    ProgressView(value: 0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .black))
                        .frame(height: 8)
                        .clipShape(Capsule())
                    HStack {
                        Text("Belum siap")
                        Spacer()
                        Text("Siap")
                    }
                    .font(.system(size: 12))
                }
                .padding(.horizontal)
                
                HStack(alignment: .center) {
                    Button(action: {
                        withAnimation {
                            currentLevelIndex = (currentLevelIndex - 1 + levels.count) % levels.count
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding(8)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Image(levels[currentLevelIndex].imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                        Text(levels[currentLevelIndex].title)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            currentLevelIndex = (currentLevelIndex + 1) % levels.count
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 16)
                
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        StatBar(title: "Intonasi", value: 0)
                        StatBar(title: "Filler Words", value: 0)
                        StatBar(title: "Tempo", value: 0)
                        StatBar(title: "Eye Contact", value: 0)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    
                    VStack(spacing: 12) {
                        CardButton(title: "Penghargaan", systemIcon: "star")
                        CardButton(title: "Latihanku", systemIcon: "doc.text")
                    }
                    .frame(maxWidth: 140)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Text("Yuk, mulai latihan presentasi untuk meningkatkan rank mu")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: onStart) {
                    Text("Mulai Presentasi")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct CountdownBox: View {
    let text: String
    var body: some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black))
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
