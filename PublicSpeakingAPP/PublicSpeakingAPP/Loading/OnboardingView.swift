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
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Latihan dengan simulasi & review penyampaianmu")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("""
                        Setelah latihan, kamu dapat melihat kembali penyampaian presentasimu.
                        Refleksikan dan latihan terus sampai kamu merasa siap!
                        """)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 32)
                    
                    MicroAnimation(artboardName: "Onboarding")
                        .frame(height: 120)
                    .accessibilityHidden(true)
                        .padding(.top, 16)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    ButtonComponent(
                        title: "Mulai",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow,
                        fullWidth: false,
                        isLoading: false,
                        isEnabled: true,
                        action: onStartTapped
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }
}
