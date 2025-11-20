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
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            
            Image(item.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(Color("BaseColorBrown"))
                    .lineSpacing(4)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BaseColorWhite"))
        .cornerRadius(16)
    }
}
