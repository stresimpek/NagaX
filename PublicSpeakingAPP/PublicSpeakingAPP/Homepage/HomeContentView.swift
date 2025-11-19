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
                    .font(.system(size: 16))
                Spacer()
                Button(action: onDatePicker) {
                    Image(systemName: "calendar")
                }
                .padding(.horizontal, 20)
                .font(.system(size: 20))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.darkBlue)
            .foregroundStyle(Color.white)
            
            Spacer()
            
            HStack(alignment: .top) {
                VStack {
                    Spacer()
                    
                    NameBanner(name: "Si Cupu (Kamu)")
                    
                    MicroAnimation(artboardName: "Home", stateMachineName: "SM_Home")
                        .frame(height: 120)
                    
                    Spacer()
                    
                    ButtonComponent(
                        title: "Mulai Latihan",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow,
                        action: onStart
                    )
                    .padding(.bottom, 12)
                }
                
                SpeechBubble(text: "Hari ini belum latihan nih... Latihan gasih?")
                
                
            }
            .padding(.leading, 200)
            .frame(alignment: .top)
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
                .font(.footnoteBold)
                .foregroundColor(Color(.baseColorBrown))
                .frame(width: 198, height: 86, alignment: .center)
                .multilineTextAlignment(.center)
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
        ZStack {
            Image("Rectangle 10")
                .resizable()
                .frame(width: 34.44737, height: 27)
                .offset(x: -74, y:4)
            
            Image("Rectangle 11")
                .resizable()
                .frame(width: 34.44737, height: 27)
                .offset(x: 74, y:4)
            
            Text(name)
                .font(.footnoteBold)
                .foregroundStyle(Color.darkBlue2)
                .frame(width: 136.80527, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.lightBlue))
                )
        }
        .frame(height: 27)
    }
}

struct CountdownBox: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .padding(4)
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
