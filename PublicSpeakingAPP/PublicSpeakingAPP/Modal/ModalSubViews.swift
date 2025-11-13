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
                .font(.title2.weight(.black))
                .foregroundColor(.baseColorBrown)
                .underline(true, color: .baseColorBrown)
        }
    }
}

struct MicSetupView: View {
    let micMonitor: MicMonitorModal
    let showMicWarning: Bool
    let imageName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 60) {
            ZStack(alignment: .leading) {
                AudioVisualizerModalView(micMonitor: micMonitor)
                    .padding(.leading, 30)
                    .padding(.trailing, 0)
                    .frame(width: 280, height: 50)
                    .frame(alignment: .leading)
                    .background(Color.black.opacity(0.27))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .offset(x: 20)
                   
                MicIconButton(showMicWarning: showMicWarning)
            }
            Image(imageName)
                .resizable().scaledToFit().frame(height: 150)
        }
    }
}

struct MicIconButton: View {
    let showMicWarning: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.baseColorBrown)
                .frame(width: 60, height: 60)
                .background(Color.baseColorWhite)
                .clipShape(Circle())
                .shadow(color: .beige, radius: 0, x: 0, y: 3)

            if showMicWarning {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.baseColorRed)
                    .background(Color.baseColorWhite.clipShape(Circle()))
                    .offset(x: -5, y: -5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showMicWarning)
    }
}

struct InstructionTextView: View {
    let message: String
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            Text(message)
                .font(.subheadline)
                .lineSpacing(6)
                .foregroundColor(.baseColorBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, geometry.size.width * 0.05)
                .lineLimit(nil)
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
