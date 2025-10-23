//
//  BubbleChat.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI

struct BubbleChat: View {
    var text: String
    var isFromCurrentUser: Bool = true

    var body: some View {
        HStack {
            Text(text)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .overlay {
                    BubbleTail(isFromCurrentUser: isFromCurrentUser)
                        .fill(Color(.systemGray6))
                        .frame(width: 10, height: 14)
                        .offset(x: isFromCurrentUser ? 20 : -20, y: 6)
                }
                .foregroundColor(.black)
                .shadow(radius: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct BubbleTail: Shape {
    var isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        Path { p in
            if isFromCurrentUser {
                // ekor di kanan
                p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            } else {
                // ekor di kiri
                p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            p.closeSubpath()
        }
    }
}

