//
//  SwiftUIView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI

struct ButtonComponent: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .fontWeight(.semibold)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
        }
        .foregroundStyle(.black)
        .background(Color.gray)
        .clipShape(.rect(cornerRadius: 20))
        .shadow(radius: 0.5)
    }
}
