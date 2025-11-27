//
//  EarlyStopModalView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 13/11/25.
//

import SwiftUI

struct EarlyStopModalView: View {
    let onContinue: () -> Void
    let onViewEvaluation: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Spacer()
                    VStack(spacing: 24) {
                        VStack(spacing: 4){
                            Text("Selesai Latihan?")
                                .font(.title2)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                            
                            Text("Sesi latihanmu belum memenuhi durasi yang terpilih, kamu akan lanjut ke evaluasi setelah ini.")
                                .font(.subheadline)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        
                        HStack(spacing: 12) {
                            buttonsContent
                        }
                    }
                    .frame(width: 317)
                    .padding(.vertical, 30)
                    .background(
                        Image("SetupPaper")
                            .resizable()
                            .resizable(resizingMode: .stretch)
                            .accessibilityHidden(true)
                    )
                    .frame(width: 370)
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
                title: "Lanjut",
                systemImage: nil,
                size: .medium,
                kind: .secondaryBlue,
                action: onContinue
            )
            ButtonComponent(
                title: "Evaluasi",
                systemImage: nil,
                size: .medium,
                kind: .primaryYellow,
                action: onViewEvaluation
            )
        }
    }
}
