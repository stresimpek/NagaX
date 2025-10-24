//
//  Header.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 21/10/25.
//

import SwiftUI

struct Header: View {
    var title: String
    var onBack: () -> Void = {}

    var body: some View {
        ZStack {
//            HStack {
//                Button(action: onBack) {
//                    Image(systemName: "chevron.left")
//                        .font(.title2.weight(.semibold))
//                        .padding(8)
//                }
//                Spacer()
//            }
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.gray.opacity(0.6))
                .clipShape(Capsule())
        }.padding(.bottom, 16)
//        .padding(.horizontal, 16)
//        .padding(.top, 8)
    }
}

#Preview {
    Header(title: "Hello World")
}
