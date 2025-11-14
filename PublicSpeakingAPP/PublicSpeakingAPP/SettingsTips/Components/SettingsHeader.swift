//
//  SettingsHeader.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI

struct SettingsHeader: View {
    let onBack: () -> Void
    let onNext: () -> Void
    var isNextDisabled: Bool = false
    var body: some View {
        HStack {
            ButtonComponent(
                title: nil,
                systemImage: "arrow.uturn.left",
                size: .medium,
                kind: .secondaryBlue,
                action: onBack
            )
            .padding(.leading, 16)
            .padding(.top, 16)
            
            Spacer()
            
            ButtonComponent(
                title: nil,
                systemImage: "arrow.uturn.right",
                size: .medium,
                kind: .secondaryBlue,
                action: onNext
            )
            .padding(.leading, 16)
            .padding(.top, 16)
            .disabled(isNextDisabled)
        }
    }
}
