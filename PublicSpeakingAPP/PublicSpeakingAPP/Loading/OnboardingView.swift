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
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("Latihan dengan simulasi & review penyampaianmu")
                                .font(isIpad ? .title1 : .title2)
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("""
                            Setelah latihan, kamu dapat melihat kembali penyampaian presentasimu.
                            Refleksikan dan latihan terus sampai kamu merasa siap!
                            """)
                            .font(isIpad ? .headline : .subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 32)
                        
                        MicroAnimation(artboardName: "Onboarding")
                            .frame(height: isIpad ? 160 : 120)
                            .accessibilityHidden(true)
                            .padding(.top, 16)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Spacer()
                        
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
                    .padding(.bottom, 52)
                    .padding(.trailing, 44)
                }
            }
        }
    }
}
