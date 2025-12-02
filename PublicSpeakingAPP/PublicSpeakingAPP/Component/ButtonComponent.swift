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
        case .large: 24
        case .medium: 24
        case .small: 24
        case .largeIconCircle: 25
        case .largePill: 100
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .large: 32
        case .medium: 16
        case .small: 12
        case .largeIconCircle: 14
        case .largePill: 24
        }
    }
    var verticalPadding: CGFloat {
        switch self {
        case .large: 16
        case .medium: 11
        case .small: 8
        case .largeIconCircle: 14
        case .largePill: 14
        }
    }
    var minHeight: CGFloat {
        switch self {
        case .large, .largePill: 52
        case .medium, .largeIconCircle: 48
        case .small: 40
        }
    }
    private var textStyle: Font.TextStyle {
        switch self {
        case .large, .largePill:
            return .title3
        case .medium, .largeIconCircle:
            return .headline
        case .small:
            return .subheadline
        }
    }
    var font: Font {
        .system(textStyle, design: .default)
    }
    var iconSize: Image.Scale {
        switch self {
        case .large, .largePill, .largeIconCircle:
            return .large
        case .medium:
            return .medium
        case .small:
            return .small
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
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var isIpad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
       
    private var circleBase: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 40
        case .medium, .large:
            return 44
        default:
            return 48
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        let isCircle = isIconOnly && (size == .largeIconCircle)
        let baseCircleSize: CGFloat = {
            if let overrideCircleSize {
                return overrideCircleSize
            }
            return max(size.minHeight, circleBase)
        }()
        
        let circleSize = baseCircleSize
        
        return configuration.label
            .font(isIpad ? .title1 : size.font)
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(
                minWidth: isCircle ? circleSize : (isIpad ? 219 : nil),
                maxWidth: isCircle ? circleSize : nil,
                
                minHeight: isCircle ? circleSize : (isIpad ? 60 : nil),
                maxHeight: isCircle ? circleSize : nil
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
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        
    private var iconPointSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 16
        case .medium, .large:
            return 18
        case .xLarge, .xxLarge, .xxxLarge:
            return 20
        default:
            return 20
        }
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
                        .font(.system(size: iconPointSize, weight: .bold))
                }
                if let title {
                    Text(title)
                        .font(size.font)
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
