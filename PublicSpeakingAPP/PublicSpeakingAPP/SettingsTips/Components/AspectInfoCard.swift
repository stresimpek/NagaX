//
//  AspectInfoCard.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 11/11/25.
//

import SwiftUI

struct AspectInfoItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let description: String
}

struct AspectInfoCard: View {
    let item: AspectInfoItem
    var fixedHeight: CGFloat? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            
            Image(item.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30)
                .accessibilityRemoveTraits(.isImage)
                .accessibilityLabel(item.title)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(Color("BaseColorBrown"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: fixedHeight ?? 0,
               alignment: .center)
        .background(Color("BaseColorWhite"))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .background(
            Group {
                if fixedHeight == nil {
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: AspectCardHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                    }
                }
            }
        )
    }
}
