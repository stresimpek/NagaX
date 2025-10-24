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
            Image(systemName: "chevron.up")
            Rectangle()
                .stroke(.black, lineWidth: 2)
                .frame(width: 240, height: 200)
                .overlay(Text("gambar ruang kelas").font(.callout))
            Image(systemName: "chevron.down")
        }
        .foregroundStyle(.black.opacity(0.7))
    }
}
