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
                Image(option.systemImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
                
                Text(option.title)
                    .font(.footnote.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false,
                               vertical: true)
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(width: 110, height: 98, alignment: .top)
            .foregroundColor(.baseColorWhite)
            .background(.darkBlue2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .darkBlue3, radius: 0, x: 0, y: 3)
            
            if option.isEnabled == true {
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
            
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                if option.isEnabled == false { return }
                isSelected.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(option.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
