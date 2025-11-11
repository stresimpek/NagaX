//
//  SwiftUIView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI

/// Design tokens untuk ukuran
enum AppButtonSize {
    case large, medium, small, largeIconCircle
    
    var cornerRadius: CGFloat {
        switch self {
        case .large: 20
        case .medium: 16
        case .small: 14
        case .largeIconCircle: 25
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .large: 20
        case .medium: 16
        case .small: 12
        case .largeIconCircle: 14
        }
    }
    var verticalPadding: CGFloat {
        switch self {
        case .large: 14
        case .medium: 10
        case .small: 8
        case .largeIconCircle: 14
        }
    }
    var font: Font {
        switch self {
        case .large: .system(size: 20, weight: .semibold)
        case .medium: .system(size: 16, weight: .semibold)
        case .small: .system(size: 14, weight: .semibold)
        case .largeIconCircle: .system(size: 20, weight: .semibold)
        }
    }
    var iconSize: CGFloat {
        switch self {
        case .large: 22
        case .medium: 18
        case .small: 16
        case .largeIconCircle: 22
        }
    }
}

//private extension Font {
//    /// Perkiraan ketinggian font untuk menghitung minHeight
//    var sizeApprox: CGFloat {
//        // Heuristic: try to infer common system sizes by comparing description
//        let description = String(describing: self).lowercased()
//        // Look for explicit size markers in the description (best-effort, non-fatal)
//        if let sizeMatch = description.split(separator: "(").last?.split(separator: ")").first,
//           let explicit = sizeMatch.split(separator: ",").first,
//           let parsed = Double(explicit.trimmingCharacters(in: .whitespaces)) {
//            return CGFloat(parsed)
//        }
//        #if canImport(UIKit)
//        // Map common SwiftUI fonts to UIKit point sizes as a fallback
//        // This mapping is approximate and only used when we can't parse a size.
//        switch description {
//        case let d where d.contains("largetitle"): return UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
//        case let d where d.contains("title2"): return UIFont.preferredFont(forTextStyle: .title2).pointSize
//        case let d where d.contains("title3"): return UIFont.preferredFont(forTextStyle: .title3).pointSize
//        case let d where d.contains("title"): return UIFont.preferredFont(forTextStyle: .title1).pointSize
//        case let d where d.contains("headline"): return UIFont.preferredFont(forTextStyle: .headline).pointSize
//        case let d where d.contains("subheadline"): return UIFont.preferredFont(forTextStyle: .subheadline).pointSize
//        case let d where d.contains("callout"): return UIFont.preferredFont(forTextStyle: .callout).pointSize
//        case let d where d.contains("footnote"): return UIFont.preferredFont(forTextStyle: .footnote).pointSize
//        case let d where d.contains("caption2"): return UIFont.preferredFont(forTextStyle: .caption2).pointSize
//        case let d where d.contains("caption"): return UIFont.preferredFont(forTextStyle: .caption1).pointSize
//        default:
//            return UIFont.preferredFont(forTextStyle: .body).pointSize
//        }
//        #elseif canImport(AppKit)
//        // On macOS, provide a reasonable default body size
//        return NSFont.preferredFont(forTextStyle: .body).pointSize
//        #else
//        return 16
//        #endif
//    }
//}

/// Variasi warna
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

/// ButtonStyle untuk efek tekan/disabled
struct AppButtonStyle: ButtonStyle {
    let size: AppButtonSize
    let kind: AppButtonStyleKind
    let isLoading: Bool
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(kind.background)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .shadow(color: kind.shadow, radius: 0, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
            .overlay {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(kind.foreground)
                }
            }
            .contentShape(Rectangle()) // perbesar area tap
    }
}

/// Satu komponen untuk: teks-only, ikon-only, atau ikon+teks
struct ButtonComponent: View {
    let title: String?                 // nil => ikon-only
    let systemImage: String?           // nil => teks-only
    var size: AppButtonSize = .medium
    var kind: AppButtonStyleKind = .primaryYellow
    var fullWidth: Bool = false
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(AppButtonStyle(size: size, kind: kind, isLoading: isLoading, isEnabled: isEnabled))
        .disabled(!isEnabled || isLoading)
        // Aksesibilitas untuk ikon-only
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: Text {
        if let title = title { return Text(title) }
        // fallback ikon-only
        if let systemImage = systemImage { return Text(systemImage.replacingOccurrences(of: ".", with: " ")) }
        return Text("Button")
    }
}

