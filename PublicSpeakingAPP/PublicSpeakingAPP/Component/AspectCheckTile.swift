//
//  AspectCheckTile.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI

struct AspectCheckTile: View {
    let option: AspectOption
    @Binding var isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image(systemName: option.systemImage)
                //                    .font(.system(size: 24, weight: .semibold))
                Text(option.title)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(width: 110, height: 90)
            .background(Color.darkBlue2.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.darkBlue3.opacity(0.9), lineWidth: 1)
            )
            
            Group {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.large)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .stroke(Color.lightBlue.opacity(0.8), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .padding(8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isSelected.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(option.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
