//
//  AspectInfoView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 11/11/25.
//

import SwiftUI

private let aspectInfoData: [AspectInfoItem] = [
    .init(iconName: "AspectTempo", title: "Tempo", description: "Kecepatan bicaramu, jumlah kata yang kamu ucapkan per menit."),
    .init(iconName: "AspectFiller", title: "Kata Jeda", description: "Seberapa sering kamu menggunakan kata jeda seperti \"eee...\" atau \"kayak...\"."),
    .init(iconName: "AspectIntonasi", title: "Intonasi", description: "Variasi nada suaramu saat berbicara, dapat menentukan mood presentasimu."),
    .init(iconName: "AspectEye", title: "Kontak Mata", description: "Menunjukkan seberapa sering kamu menjaga kontak mata dengan audiens."),
    .init(iconName: "AspectArtikulasi", title: "Artikulasi", description: "Seberapa jelas kamu mengucapkan setiap kata."),
    .init(iconName: "AspectStruktur", title: "Struktur Kalimat", description: "Seberapa efektif dan padat kalimat yang kamu gunakan dalam menyampaikan ide.")
]

struct AspectInfoView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer().frame(height: geo.size.height * 0.08)
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        
                        Text("ASPEK PRESENTASI")
                            .font(.title3)
                            .foregroundColor(Color("BaseColorBrown"))
                            .underline()
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 20)
                            .padding(.bottom, 15)

                        ScrollView {
                            Grid(horizontalSpacing: 16, verticalSpacing: 10) {
                                ForEach(stride(from: 0, to: aspectInfoData.count, by: 2).map { $0 }, id: \.self) { index in
                                    GridRow {
                                        AspectInfoCard(item: aspectInfoData[index])
                                            .fixedSize(horizontal: false, vertical: true)
                                        if index + 1 < aspectInfoData.count {
                                            AspectInfoCard(item: aspectInfoData[index + 1])
                                                .fixedSize(horizontal: false, vertical: true)
                                        } else {
                                            Color.clear.gridCellUnsizedAxes([.vertical, .horizontal])
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                        }
                        .fixedSize(horizontal: false, vertical: false)
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.9),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.bottom, 15)
                    }
                    .frame(width: geo.size.width * 0.85)
                    .background(
                        Image("SetupPaper")
                            .resizable()
                            .scaledToFit()
                            .clipped()
                            .accessibilityHidden(true)
                    )
                    HeaderBackButton(action: onDismiss)
                        .offset(x: -20, y: -20)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
    }
}
