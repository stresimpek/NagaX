//
//  EmptyTranscriptModalView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 13/11/25.
//

import SwiftUI

struct EmptyTranscriptModalView: View {
    let onRestart: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        
        ZStack {
            Image("SetupPaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
            
            VStack(spacing: 24) {
                VStack(spacing: 4){
                    Text("Sepertinya kamu belum mulai bicara")
                        .font(.title3)
                        .foregroundColor(.baseColorBrown)
                        .multilineTextAlignment(.center)
                    
                    Text("Silakan lakukan presentasi terlebih dahulu agar hasil evaluasi bisa muncul.")
                        .font(.footnote)
                        .foregroundColor(.baseColorBrown)
                        .multilineTextAlignment(.center)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    ButtonComponent(
                        title: "Ulang Sesi",
                        systemImage: nil,
                        size: .medium,
                        kind: .secondaryBlue,
                        action: onRestart
                    )
                    
                    ButtonComponent(
                        title: "Lanjut Latihan",
                        systemImage: nil,
                        size: .medium,
                        kind: .primaryYellow,
                        action: onContinue
                    )
                }
            }
            .frame(width: 317)
        }
        .frame(width: 370.73706, height: 190.9482)
    }
}
