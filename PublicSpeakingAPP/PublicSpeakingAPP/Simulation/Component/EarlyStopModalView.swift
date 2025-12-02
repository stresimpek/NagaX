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
                            Text("Selesai Latihan?")
                                .font(.title3)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                            
                            Text("Sesi latihanmu belum memenuhi durasi yang terpilih, kamu akan lanjut ke evaluasi setelah ini.")
                                .font(.footnote)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, isPad ? 56 : 27)
                        if isPad {
                            VStack(spacing: 12) {
                                ButtonComponent(
                                    title: "Lanjut Latihan",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .secondaryBlue,
                                    fullWidth: true,
                                    action: onContinue
                                )
                                ButtonComponent(
                                    title: "Lihat Evaluasi",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .primaryYellow,
                                    fullWidth: true,
                                    action: onViewEvaluation
                                )
                            }
                            .padding(.horizontal, 56)
                        } else {
                            HStack(spacing: 12) {
                                ButtonComponent(
                                    title: "Lanjut Latihan",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .secondaryBlue,
                                    action: onContinue
                                )
                                ButtonComponent(
                                    title: "Lihat Evaluasi",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .primaryYellow,
                                    action: onViewEvaluation
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
                    )
                    .frame(
                        width: isPad ? 429 : 370,
                        height: isPad ? 296 : 190,
                        alignment: .center
                    )
                    .cornerRadius(24)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

