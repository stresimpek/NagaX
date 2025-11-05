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
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Kembali")
                }
            }
            Spacer()
            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text("Lanjut")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(isNextDisabled)
        }
        .buttonStyle(.plain)
        .padding()
    }
}
