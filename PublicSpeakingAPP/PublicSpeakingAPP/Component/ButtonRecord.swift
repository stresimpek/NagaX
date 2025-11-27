//
//  ButtonRecord.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 20/11/25.
//

import SwiftUI

struct ButtonRecord: View {
    let title: String?
    let systemImage: String?
    var size: AppButtonSize = .medium
    var kind: AppButtonStyleKind = .primaryYellow
    var fullWidth: Bool = false
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var customCircleSize: CGFloat? = nil
    var action: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        
    private var iconPointSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 18 : 22
    }
    
    var body: some View {
        let isIconOnly = (title == nil && systemImage != nil)
        let effectiveKind: AppButtonStyleKind = isEnabled ? kind : .disabled
        
        Button {
            if isEnabled && !isLoading {
                action()
            }
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: iconPointSize, weight: .semibold))
                        .foregroundStyle(Color(.red))
                }
                if let title {
                    Text(title)
                        .font(size.font)
                        .multilineTextAlignment(.center)
//                        .lineLimit(2)
//                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(
            AppButtonStyle(
                size: size,
                kind: effectiveKind,
                isLoading: isLoading,
                isEnabled: isEnabled,
                isIconOnly: isIconOnly,
                overrideCircleSize: customCircleSize
            )
        )
        .disabled(!isEnabled || isLoading)
    }
    
    var accessibilityLabel: Text {
        if let title = title { return Text(title) }
        if let systemImage = systemImage { return Text(systemImage.replacingOccurrences(of: ".", with: " ")) }
        return Text("Tombol")
    }
}
