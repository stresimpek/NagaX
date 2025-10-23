//
//  Untitled.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 21/10/25.
//

import SwiftUI

struct TipsPresentasiView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    
    
    var body: some View {
        VStack(spacing: 0) {
            Header(title: "Tips Presentasi")

            Spacer(minLength: 24)

            HStack(alignment: .bottom, spacing: 20) {
                // Karakter di kiri
                ImageSequenceView()
                    .frame(width: 230, height: 230)
                    .padding(.horizontal, 16)

                // Chat + pilihan di kanan
                VStack(alignment: .leading, spacing: 12) {
                    BubbleChat(
                        text: "Selamat datang di kelasku! Namaku Mr. Cako, aku akan menilai presentasimu nanti.",
                        isFromCurrentUser: false // ekor kiri (dari karakter)
                    )
                    .frame(maxWidth: 280, alignment: .leading) // kontrol lebar bubble
                    .fixedSize(horizontal: false, vertical: true)

                    ButtonComponent(text: "Presentasi? Aku belum siap…", action: onBack)
//                    ButtonComponent(text: "Oke, aku mau langsung mulai!", action: {  })
                    ButtonComponent(text: "Presentasi? Aku belum siap…", action: onContinue)
                }
                .padding(.trailing, 16)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}
