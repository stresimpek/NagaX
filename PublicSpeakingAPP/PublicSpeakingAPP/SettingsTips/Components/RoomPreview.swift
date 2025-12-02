//
//  RoomPreview.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI

struct RoomPreview: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(.ruangKelas)
                .resizable()
                .frame(width: isIpad ? 328 : 208, height: isIpad ? 226 : 144)
            Text("Ruang Kelas")
                .font(isIpad ? .title1 : .title2)
                .bold()
                .foregroundStyle(Color.baseColorWhite)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Simulasi di Ruang Kelas"))
    }
}
