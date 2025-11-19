//
//  SwiftUIView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI

enum AppButtonSize {
    case large, medium, small, largeIconCircle, largePill
    
    var cornerRadius: CGFloat {
        switch self {
        case .large: 20
        case .medium: 16
        case .small: 14
        case .largeIconCircle: 25
        case .largePill: 100
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .large: 20
        case .medium: 16
        case .small: 12
        case .largeIconCircle: 14
        case .largePill: 24
        }
    }
    var verticalPadding: CGFloat {
        switch self {
        case .large: 14
        case .medium: 10
        case .small: 8
        case .largeIconCircle: 14
        case .largePill: 14
        }
    }
    var font: Font {
        switch self {
        case .large: .system(size: 20, weight: .semibold)
        case .medium: .system(size: 16, weight: .semibold)
        case .small: .system(size: 14, weight: .semibold)
        case .largeIconCircle: .system(size: 20, weight: .semibold)
        case .largePill: .system(size: 20, weight: .semibold)
        }
    }
    var iconSize: CGFloat {
        switch self {
        case .large: 22
        case .medium: 18
        case .small: 16
        case .largeIconCircle: 22
        case .largePill: 22
        }
    }
}

enum AppButtonStyleKind {
    case secondaryBlue
    case primaryYellow
    case disabled
    
    var foreground: Color {
        switch self {
        case .secondaryBlue: .baseColorWhite
        case .primaryYellow: .baseColorBrown
        case .disabled: .textGrey
        }
    }
    var background: Color {
        switch self {
        case .secondaryBlue: .darkBlue2
        case .primaryYellow: .baseColorYellow
        case .disabled: .disabledButton
        }
    }
    var shadow: Color {
        switch self {
        case .secondaryBlue: .darkBlue3
        case .primaryYellow: .yellow2
        case .disabled: .shadowDisabled
        }
    }
}

struct AppButtonStyle: ButtonStyle {
    let size: AppButtonSize
    let kind: AppButtonStyleKind
    let isLoading: Bool
    let isEnabled: Bool
    let isIconOnly: Bool
    var overrideCircleSize: CGFloat? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        let isCircle = isIconOnly && (size == .largeIconCircle)
        let defaultCircleSize = size.iconSize + size.horizontalPadding * 2
        let circleSize = overrideCircleSize ?? defaultCircleSize
        
        return configuration.label
            .font(size.font)
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(
                width: isCircle ? circleSize : nil,
                height: isCircle ? circleSize : nil
            )
            .background(
                Group {
                    if isCircle {
                        Circle()
                            .fill(kind.background)
                    } else {
                        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                            .fill(kind.background)
                    }
                }
                .shadow(color: kind.shadow,
                        radius: 0,
                        x: 0,
                        y: configuration.isPressed ? 1 : 3)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
            .overlay {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(kind.foreground)
                }
            }
            .contentShape(Rectangle())
    }
}

struct ButtonComponent: View {
    let title: String?
    let systemImage: String?
    var size: AppButtonSize = .medium
    var kind: AppButtonStyleKind = .primaryYellow
    var fullWidth: Bool = false
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var customCircleSize: CGFloat? = nil
    var action: () -> Void
    
    var body: some View {
        // icon-only: ada icon, tidak ada title
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
                        .font(.system(size: size.iconSize, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .font(size.font)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: Text {
        if let title = title { return Text(title) }
        if let systemImage = systemImage { return Text(systemImage.replacingOccurrences(of: ".", with: " ")) }
        return Text("Button")
    }
}
