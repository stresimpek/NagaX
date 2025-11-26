//
//  EvaluationSummaryCard.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 18/11/25.
//

import SwiftUI

struct CardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct EvaluationSummaryItem: Identifiable {
    let id = UUID()
    let iconName: String
    let text: AttributedString
    let tab: EvaluationTab
}

struct EvaluationSummaryCard: View {
    let item: EvaluationSummaryItem
    
    var fixedHeight: CGFloat? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(item.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30)
                .foregroundColor(Color("BaseColorBrown"))
                .accessibilityHidden(true)
            
            Text(item.text)
                .font(.body)
                .foregroundColor(Color("BaseColorBrown"))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: CardHeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .frame(height: fixedHeight)
        .background(Color("BaseColorWhite"))
        .cornerRadius(12)
    }
}
