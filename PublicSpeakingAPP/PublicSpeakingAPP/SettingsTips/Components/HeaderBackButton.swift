//
//  HeaderBackButton.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 11/11/25.
//

import SwiftUI

struct HeaderBackButton: View {
    let action: () -> Void
    
    var body: some View {
        ButtonComponent(
            title: nil,
            systemImage: "arrow.uturn.left",
            size: .largeIconCircle,
            kind: .secondaryBlue,
            action: action
        )
        .accessibilityLabel("Kembali")
    }
}
