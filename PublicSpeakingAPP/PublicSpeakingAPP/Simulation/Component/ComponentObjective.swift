//
//  ComponentObjective.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 21/11/25.
//

import SwiftUI

struct ComponentObjective: View {
    let text: String
    let isOvertime: Bool
    var onFinished: (() -> Void)? = nil
    
    @Binding var dontShowAgain: Bool
    let showDontShowAgain: Bool

    @State private var appear = false

    private var fadeMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear,  location: 0.0),
                .init(color: .white,  location: 0.30),
                .init(color: .white,  location: 0.70),
                .init(color: .clear,  location: 1.0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(appear ? 0.5 : 0.0)
                .ignoresSafeArea()

            Text(text)
                .padding(.horizontal, 64)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    (isOvertime ? Color.baseColorRed : Color.blue)
                        .mask(fadeMask)
                )
                .frame(maxWidth: .infinity)
                .offset(y: appear ? 0 : -20)
                .opacity(appear ? 1 : 0)
            
            if showDontShowAgain {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            dontShowAgain.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(.baseColorWhite)
                                        .frame(width: 22, height: 22)

                                    if dontShowAgain {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.baseColorBlack)
                                    }
                                }

                                Text("Jangan tampilkan lagi")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.baseColorWhite)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.darkBlue3)
                            .cornerRadius(999)
                            .shadow(color: .baseColorBlack,
                                    radius: 0,
                                    x: 0,
                                    y: 1)
                        }
                        .offset(y: appear ? 0 : 25)
                        .opacity(appear ? 1 : 0)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appear)
        .onAppear {
            appear = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    appear = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onFinished?()
                }
            }
        }
    }
}


struct BannerItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isOvertime: Bool
    let showDontShowAgain: Bool
}
