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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let onPracticeAgain: () -> Void
    let onViewDetails: () -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var isIPadLayout: Bool {
        horizontalSizeClass == .regular &&
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        ZStack {
            Image(isIPadLayout ? "HandBG - iPad" : "HandBG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            if isIPadLayout {
                iPadLayout
            } else {
                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            iOSLayout(proxy: proxy)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    var iPadLayout: some View {
        GeometryReader { proxy in

            ScrollView(.vertical, showsIndicators: true) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Text("LEMBAR EVALUASI")
                                .font(.title2.weight(.black))
                                .foregroundColor(Color("BaseColorBrown"))
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                                .padding(.bottom, 2)

                            Rectangle()
                                .fill(Color("BaseColorBrown"))
                                .frame(width: 200, height: 3)
                                .cornerRadius(3)
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 22)

                        VStack(spacing: 16) {
                            ForEach(viewModel.summaryItems) { item in
                                EvaluationSummaryCard(item: item, fixedHeight: nil)
                            }
                        }
                        .padding(.horizontal, 52)

                        Spacer(minLength: 24)

                        VStack(spacing: 16) {
                            ButtonComponent(
                                title: "Lihat Detail",
                                systemImage: nil,
                                size: .largePill,
                                kind: .primaryYellow,
                                fullWidth: true,
                                action: onViewDetails
                            )

                            ButtonComponent(
                                title: "Latihan Lagi",
                                systemImage: nil,
                                size: .largePill,
                                kind: .secondaryBlue,
                                fullWidth: true,
                                action: onPracticeAgain
                            )
                        }
                        .padding(.horizontal, 52)
                        .padding(.bottom, 60)
                    }
                    .frame(width: 712)
                    .frame(minHeight: max(proxy.size.height - 60, 0), alignment: .top)
                    .background(Color("LightYellow"))
                  
                    .padding(.horizontal, 12)


                    Spacer(minLength: 0)
                }
                .padding(.top, 60)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    func iOSLayout(proxy: GeometryProxy) -> some View {
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
                .padding(.horizontal, 32)
                .padding(.top, 8)

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
        .background(Color("LightYellow"))
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .safeAreaPadding(.horizontal)
    }
}
