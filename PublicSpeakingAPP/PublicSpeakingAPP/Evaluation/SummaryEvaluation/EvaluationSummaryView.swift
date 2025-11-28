//
//  EvaluationSummaryView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 18/11/25.
//

import SwiftUI

struct EvaluationSummaryView: View {
    @ObservedObject var viewModel: NewEvaluationViewModel
    
    @State private var maxCardHeight: CGFloat = 0
    
    let onPracticeAgain: () -> Void
    let onViewDetails: () -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Background wallpaper
            Image("HandBG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Text("LEMBAR EVALUASI")
                                .font(.title2.weight(.black))
                                .foregroundColor(Color("BaseColorBrown"))
                                .padding(.bottom, 1)
                                .background(
                                    Rectangle()
                                        .fill(Color("BaseColorBrown"))
                                        .frame(height: 3)
                                        .cornerRadius(10)
                                    , alignment: .bottom
                                )
                                .padding(.vertical, 18)

                            VStack(spacing: 31) {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(viewModel.summaryItems) { item in
                                        EvaluationSummaryCard(
                                            item: item,
                                            fixedHeight: maxCardHeight > 0 ? maxCardHeight : nil
                                        )
                                    }
                                }
                                .onPreferenceChange(CardHeightPreferenceKey.self) { newHeight in
                                    maxCardHeight = newHeight
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                // Buttons
                                HStack(spacing: 12) {
                                    ButtonComponent(
                                        title: "Latihan Lagi",
                                        systemImage: nil,
                                        size: .largePill,
                                        kind: .secondaryBlue,
                                        fullWidth: false,
                                        action: onPracticeAgain
                                    )

                                    ButtonComponent(
                                        title: "Lihat Detail",
                                        systemImage: nil,
                                        size: .largePill,
                                        kind: .primaryYellow,
                                        fullWidth: false,
                                        action: onViewDetails
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 12)
                                .padding(.bottom, 30)
                            }
                        }
                        .frame(maxWidth: 860)
                        .frame(minHeight: proxy.size.height)
                        .background(
                           Color("LightYellow")
                        )
                        .padding(.top, 32)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .safeAreaPadding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}
