//
//  DistraksiInfoView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 02/12/25.
//

import SwiftUI

struct DistraksiInfoView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                    .frame(height: geo.size.height * 0.08)

                ZStack(alignment: .topLeading) {
                    SetupPaperCard(geo: geo) {
                        VStack(spacing: 32) {
                            Text("DISTRAKSI DALAM SIMULASI")
                                .font(.title3)
                                .foregroundColor(Color("BaseColorBrown"))
                                .underline()
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 20)
                                .padding(.bottom, 15)
                            
                            Image("Distraksi")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: isIpad ? 160 : 120)
                            
                            Text("Selama kamu presentasi, akan ada distraksi suara yang muncul. Aturlah jumlah distraksi sesuai keinginanmu.")
                                .font(isIpad ? .body : .subheadline)
                                .lineSpacing(4)
                                .foregroundColor(.baseColorBrown)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 20)
                        }
                        .padding(.top)
                    }

                    HeaderBackButton(action: onDismiss)
                        .offset(x: 25, y: -15)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
    }
}
