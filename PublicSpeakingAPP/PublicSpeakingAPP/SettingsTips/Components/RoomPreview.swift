//
//  RoomPreview.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI

struct RoomPreview: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    private var isiPad: Bool {
        sizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(.ruangKelas)
                .resizable()
                .frame(width: isiPad ? 328 : 208, height: isiPad ? 226 : 144)
            Text("Ruang Kelas")
                .font(isiPad ? .title1 : .title2)
                .bold()
                .foregroundStyle(Color.baseColorWhite)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Simulasi di Ruang Kelas"))
    }
}
