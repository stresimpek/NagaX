//
//  AspectCheckTile.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 23/10/25.
//

import SwiftUI

struct AspectTileHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AspectCheckTile: View {
    let option: AspectOption
    @Binding var isSelected: Bool
    
    var fixedHeight: CGFloat? = nil
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image(option.systemImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(isSelected || !option.isEnabled ? .darkTurqoise : .baseColorWhite)
                
                VStack {
                    Spacer(minLength: 0)
                    Text(option.title)
                        .font(.footnote.bold())
                        .multilineTextAlignment(.center)
//                        .lineLimit(2)
//                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(width: 134)
            .frame(minHeight: fixedHeight ?? 0, alignment: .top)
            .foregroundColor(isSelected || !option.isEnabled ? .darkTurqoise : .baseColorWhite)
            .background(isSelected || !option.isEnabled ? Color.turqoise : Color.darkBlue2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isSelected || !option.isEnabled ? Color.shadowTurqoise : Color.darkBlue3,
                    radius: 0, x: 0, y: 3)
            
            ZStack {
                Circle()
                    .fill(Color.baseColorWhite)
                    .frame(width: 17, height: 17)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.18), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .blur(radius: 1.2)
                    )

                if isSelected || !option.isEnabled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.baseColorBlack)
                }
            }
            .padding(8)
        }
        .background(
            Group {
                if fixedHeight == nil {
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: AspectTileHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                    }
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                if option.isEnabled == false { return }
                isSelected.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityHint(Text("Tap dua kali untuk memilih"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
