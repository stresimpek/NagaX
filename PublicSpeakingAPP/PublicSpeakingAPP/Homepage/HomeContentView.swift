//
//  HomeContentView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI
import RiveRuntime
import SwiftData

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
    let onDatePicker: () -> Void
    
    @Query private var savedDates: [PresentationDateModel]
    private var targetDate: Date? { savedDates.first?.date }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                CountdownRow(targetDate: targetDate)
                    .font(.footnote)
                Spacer()
                Button(action: onDatePicker) {
                    Image(systemName: "calendar")
                        .accessibilityLabel("Atur tanggal presentasimu")
                }
                .padding(.horizontal, 40)
                .font(.title)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.darkBlue)
            .foregroundStyle(Color.white)
            
            Spacer()
            
            GeometryReader { geometry in
                ScrollView {
                    ZStack {
                        VStack(spacing: isIpad ? 0 : 20) {
                            Spacer()
                            VStack(spacing: isIpad ? 40 : 12) {
                                NameBanner(name: "Si Cupu (Kamu)")

                                MicroAnimation(artboardName: "Home")
                                    .frame(height: isIpad ? 180 : 120)
                            }
                            .accessibilityHidden(true)
                            
                            if !isIpad {
                                ButtonComponent(
                                    title: "Mulai Latihan",
                                    systemImage: nil,
                                    size: .large,
                                    kind: .primaryYellow,
                                    action: onStart
                                )
                            }
                            Spacer()
                        }
                        .frame(minHeight: geometry.size.height)
                        
                        SpeechBubble(text: "Hari ini belum latihan nih... Latihan gasih?")
                            .padding(.leading, isIpad ? 490 : 440)
                            .padding(.bottom, isIpad ? 40: 160)
                            .accessibilityLabel("Hari ini kamu belum latihan. Ayo mulai latihan")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    if isIpad {
                        HStack {
                            Spacer()
                            
                            ButtonComponent(
                                title: "Mulai Latihan",
                                systemImage: nil,
                                size: .large,
                                kind: .primaryYellow,
                                action: onStart
                            )
                        }
                        .padding(.bottom, 52)
                        .padding(.trailing, 44)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .background(Color(.baseColorBlue))
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct SpeechBubble: View {
    var text: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Main bubble background + text
            Text(text)
                .font(isIpad ? .title3 : .footnoteBold)
                .bold()
                .foregroundColor(Color(.baseColorBrown))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.baseColorWhite))
                )
            
            Image("Vector 92")
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 20.4)
                .offset(x: -4, y: 2)
        }
        .frame(width: 207, height: 86)
        .accessibilityElement(children: .combine)
    }
}

struct TriangleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Triangle pointing right (rotated later)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct NameBanner: View {
    var name: String
    
    var body: some View {
        HStack(alignment: .top, spacing: -10) {
            
            Image("Rectangle 10")
                .resizable()
                .frame(width: isIpad ? 56.37 : 34.45, height: isIpad ? 44.18 : 27)
                .offset(y: 6)
            
            Text(name)
                .font(isIpad ? .title1 : .footnoteBold)
                .foregroundStyle(Color.darkBlue2)
                .padding(.horizontal, isIpad ? 40 : 24)
                .padding(.vertical, isIpad ? 14 : 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.lightBlue))
                )
                .zIndex(1)
            
            Image("Rectangle 11")
                .resizable()
                .frame(width: isIpad ? 56.37 : 34.45, height: isIpad ? 44.18 : 27)
                .offset(y: 6)
        }
    }
}

struct CountdownBox: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
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

