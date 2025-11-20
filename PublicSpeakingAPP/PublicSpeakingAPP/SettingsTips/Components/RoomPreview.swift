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
                .frame(width: 208, height: 144)
            Text("Ruang Kelas")
                .font(.title2)
                .bold()
                .foregroundStyle(Color.baseColorWhite)
        }
    }
}
