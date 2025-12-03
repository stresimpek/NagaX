//
//  EmptyTranscriptModalView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 13/11/25.
//

import SwiftUI

struct EmptyTranscriptModalView: View {
    let onRestart: () -> Void
    let onContinue: () -> Void
    
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                VStack {
                    Spacer(minLength: 0)
                    VStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("Sepertinya kamu belum mulai bicara")
                                .font(.title3)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                            
                            Text("Silakan lakukan presentasi terlebih dahulu agar hasil evaluasi bisa muncul.")
                                .font(.footnote)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, isPad ? 56 : 27)
                        if isPad {
                            VStack(spacing: 12) {
                                ButtonComponent(
                                    title: "Ulang Sesi",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .secondaryBlue,
                                    fullWidth: true,
                                    action: onRestart
                                )
                                ButtonComponent(
                                    title: "Lanjut Latihan",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .primaryYellow,
                                    fullWidth: true,
                                    action: onContinue
                                )
                            }
                            .padding(.horizontal, 56)
                            
                        } else {
                            HStack(spacing: 12) {
                                ButtonComponent(
                                    title: "Ulang Sesi",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .secondaryBlue,
                                    action: onRestart
                                )
                                
                                ButtonComponent(
                                    title: "Lanjut Latihan",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .primaryYellow,
                                    action: onContinue
                                )
                                
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, isPad ? 30 : 18)
                    .background(
                        Image("SetupPaper")
                            .resizable(resizingMode: .stretch)
                            .scaledToFill()
                            .accessibilityHidden(true)
                    )
                    .frame(
                        width: isPad ? 429 : 370,
                        alignment: .center
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
