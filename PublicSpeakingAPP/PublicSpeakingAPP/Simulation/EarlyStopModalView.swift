//
//  EarlyStopModalView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 13/11/25.
//

import SwiftUI

struct EarlyStopModalView: View {
    let onContinue: () -> Void
    let onViewEvaluation: () -> Void
    
    var body: some View {
        ZStack {
            Image("SetupPaper")
                .resizable()
                .aspectRatio(contentMode: .fill)

            VStack(spacing: 24) {
                VStack(spacing: 4){
                    Text("Selesai Latihan?")
                        .font(.title3)
                        .foregroundColor(.baseColorBrown)
                        .multilineTextAlignment(.center)
                    
                    Text("Sesi latihanmu belum memenuhi durasi yang terpilih, kamu akan lanjut ke evaluasi setelah ini.")
                        .font(.footnote)
                        .foregroundColor(.baseColorBrown)
                        .multilineTextAlignment(.center)
                }

                // Buttons
                HStack(spacing: 12) {
                    ButtonComponent(
                        title: "Lanjut Latihan",
                        systemImage: nil,
                        size: .largeIconCircle,
                        kind: .secondaryBlue,
                        action: onContinue
                    )
                    ButtonComponent(
                        title: "Lihat Evaluasi",
                        systemImage: nil,
                        size: .largeIconCircle,
                        kind: .primaryYellow,
                        action: onViewEvaluation
                    )
                }
            }
            .frame(width: 317)
        }
        .frame(width: 370.73706, height: 190.9482)
 
    }
}

