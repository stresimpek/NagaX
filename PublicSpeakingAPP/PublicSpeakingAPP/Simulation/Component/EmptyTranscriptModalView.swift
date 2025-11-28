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
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("Sepertinya kamu belum mulai bicara")
                                .font(.title2)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                            
                            Text("Silakan lakukan presentasi terlebih dahulu agar hasil evaluasi bisa muncul.")
                                .font(.subheadline)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        
                        HStack(spacing: 12) {
                            buttonsContent
                        }
                    }
                    .frame(width: 370)
                    .padding(.vertical, 30)
                    .background(
                        Image("SetupPaper")
                            .resizable()
                            .resizable(resizingMode: .stretch)
                            .accessibilityHidden(true)

                    )
                    .frame(width: 450)
                    
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    var buttonsContent: some View {
        Group {
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
    }
}
