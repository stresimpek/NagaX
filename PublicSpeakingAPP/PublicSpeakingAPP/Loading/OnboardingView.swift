//
//  OnboardingView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 12/11/25.
//

import SwiftUI

struct OnboardingView: View {
    var onStartTapped: () -> Void
    
    var body: some View {
        ZStack {
            Color("BaseColorBlue")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                
                VStack(spacing: 8) {
                    Text("Latihan dengan simulasi & review penyampaianmu")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Setelah latihan, kamu dapat melihat kembali penyampaian presentasimu.\nRefleksikan dan latihan terus sampai kamu merasa siap!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                MicroAnimation(artboardName: "Onboarding")
                    .frame(height: 120)
                    .accessibilityHidden(true)
                
                Spacer()
                
                ButtonComponent(
                    title: "Mulai",
                    systemImage: nil,
                    size: .large,
                    kind: .primaryYellow,
                    fullWidth: true,
                    isLoading: false,
                    isEnabled: true,
                    action: onStartTapped
                )
                .padding(.horizontal, 250)
            }.padding(.vertical, 16)
        }
    }
}
