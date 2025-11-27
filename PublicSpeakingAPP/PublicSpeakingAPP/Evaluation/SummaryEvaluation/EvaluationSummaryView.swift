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
        ZStack(alignment: .bottom) {
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            Image("HandPaper")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 30)
                .accessibilityHidden(true)
                .overlay(
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
                            .padding(.bottom, 10)
                        
                        ScrollView(showsIndicators: true) {
                            VStack {
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
                                .padding(.bottom, 16)
                                
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
                                .padding(.top, 4)
                                .padding(.bottom, 10)
                            }
                        }
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
                        .padding(.bottom, 10)
                    }
                    .padding(.horizontal, 130)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                )
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(edges: .bottom)
    }
}
