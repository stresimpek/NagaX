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
        ScrollView {
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
                .font(.system(size: 14))
                .padding(.top, 16)
                
                Spacer()
                
                HStack (spacing: 52) {
                    VStack {
                        Text("Noob Speaker")
                        RiveViewModel(fileName:"noob cako new").view()
                            .frame(width: 200, height: 120)
                    }
                    
                    VStack (alignment: .leading) {
                        Text("Kamu belum siap untuk presentasi")
                            .font(.system(size: 14))
                        HStack {
                            ProgressView(value: 0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .black))
                                .frame(height: 8)
                                .clipShape(Capsule())
                            Text("%")
                        }
                        HStack (spacing: 20) {
                            VStack (spacing: 20) {
                                StatBar(title: "Intonasi", value: 0)
                                StatBar(title: "Filler Words", value: 0)
                            }
                            VStack (spacing: 20) {
                                StatBar(title: "Tempo", value: 0)
                                StatBar(title: "Kontak Mata", value: 0)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(alignment: .center, spacing: 12) {
                    CardButton(title: "Penghargaan", systemIcon: "star")
                    CardButton(title: "Riwayat Latihan", systemIcon: "doc.text")
                    
                    NavigationLink(destination: SimulationViewWrapper(
                            whisperKitVM: whisperKitVM,
                            textAnalyzerVM: textAnalyzerVM,
                            intonationAnalyzerVM: intonationAnalyzerVM,
                            tempoVM: tempoVM
                        )
                        .navigationBarBackButtonHidden(true)
                    ) {
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
                .frame(maxWidth: .infinity)
                
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
