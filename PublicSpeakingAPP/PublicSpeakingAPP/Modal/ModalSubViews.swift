//
//  ModalSubViews.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 10/11/25.
//

import SwiftUI

struct TitleView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("INSTRUKSI")
                .font(isIpad ? .title1 : .title2.weight(.black))
                .foregroundColor(Color("BaseColorBrown"))
                .padding(.bottom, 1)
                .background(
                    Rectangle()
                        .fill(Color("BaseColorBrown"))
                        .frame(height: 3)
                        .cornerRadius(10)
                    , alignment: .bottom
                )
        }
    }
}

struct MicSetupView: View {
    let micMonitor: MicMonitorModal
    let showMicWarning: Bool
    let imageName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 60) {
            ZStack(alignment: .topLeading) {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.baseColorWhite)
                    AudioVisualizerModalView(micMonitor: micMonitor)
                }
                .padding(.horizontal, 8)
                .frame(width: 280, height: 50)
                .frame(alignment: .leading)
                .background(Color.black.opacity(0.27))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .offset(x: 20)
                    
                if showMicWarning {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.baseColorRed)
                        .offset(x: 10, y: -5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(), value: showMicWarning)

            

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 150)
        }
        .accessibilityHidden(true)
    }
}

struct InstructionTextView: View {
    let message: AttributedString
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            Text(message)
                .font(isIpad ? .body : .subheadline)
                .lineSpacing(4)
                .foregroundColor(.baseColorBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StartButtonView: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        ButtonComponent(
            title: title,
            systemImage: nil,
            size: .large,
            kind: isEnabled ? .primaryYellow : .disabled,
            fullWidth: true,
            isEnabled: isEnabled,
            action: action
        )
        .animation(.easeInOut, value: title)
        .animation(.easeInOut, value: isEnabled)
    }
}
