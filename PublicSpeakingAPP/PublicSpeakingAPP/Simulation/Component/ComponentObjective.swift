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
    
    @Environment(\.horizontalSizeClass) private var sizeClass

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

            (isOvertime ? Color.baseColorRed : Color.darkBlue)
                .mask(fadeMask)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay {
                    Text(text)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 20)
                }
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
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.baseColorWhite)
                            .cornerRadius(999)
                        }
                        .offset(y: appear ? 0 : 25)
                        .opacity(appear ? 1 : 0)
                        .padding(.bottom, sizeClass == .regular ? 54 : 24)
                        .padding(.trailing, sizeClass == .regular ? 60 : 0)
                        
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
