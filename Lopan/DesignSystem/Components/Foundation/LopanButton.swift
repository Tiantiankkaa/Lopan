//
//  LopanButton.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Modern button component system for Lopan production management app
/// Supports multiple styles, sizes, and states with consistent design
struct LopanButton: View {
    // MARK: - Properties
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    let size: ButtonSize
    let isEnabled: Bool
    let isLoading: Bool
    let icon: String?
    let iconPosition: IconPosition
    
    @State private var isPressed = false
    
    // MARK: - Initializers
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.icon = icon
        self.iconPosition = iconPosition
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                HapticFeedback.light()
                action()
            }
        }) {
            HStack(spacing: size.iconSpacing) {
                if iconPosition == .leading {
                    iconView
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .foregroundColor(style.foregroundColor(isEnabled: isEnabled))
                } else {
                    Text(title)
                        .font(size.font)
                        .fontWeight(.medium)
                }
                
                if iconPosition == .trailing {
                    iconView
                }
            }
            .foregroundColor(style.foregroundColor(isEnabled: isEnabled))
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.button)
                    .fill(style.backgroundColor(isEnabled: isEnabled, isPressed: isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.button)
                            .stroke(style.borderColor(isEnabled: isEnabled), lineWidth: style.borderWidth)
                    )
            )
            .lopanShadow(style.shadow(isEnabled: isEnabled, isPressed: isPressed))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(LopanAnimation.buttonTap) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let icon = icon {
            Image(systemName: icon)
                .font(size.iconFont)
        }
    }
}

// MARK: - Button Styles
extension LopanButton {
    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case destructive
        case ghost
        case outline
        
        func backgroundColor(isEnabled: Bool, isPressed: Bool) -> Color {
            guard isEnabled else { return disabledBackgroundColor }
            
            switch self {
            case .primary:
                return isPressed ? LopanColors.primaryDark : LopanColors.primary
            case .secondary:
                return isPressed ? LopanColors.secondaryDark : LopanColors.secondary
            case .tertiary:
                return isPressed ? LopanColors.surface : LopanColors.backgroundSecondary
            case .destructive:
                return isPressed ? LopanColors.errorDark : LopanColors.error
            case .ghost:
                return isPressed ? LopanColors.primaryLight : Color.clear
            case .outline:
                return isPressed ? LopanColors.primaryLight : Color.clear
            }
        }
        
        func foregroundColor(isEnabled: Bool) -> Color {
            guard isEnabled else { return LopanColors.textTertiary }
            
            switch self {
            case .primary, .destructive:
                return LopanColors.textOnPrimary
            case .secondary:
                return LopanColors.textOnDark
            case .tertiary, .ghost, .outline:
                return LopanColors.primary
            }
        }
        
        func borderColor(isEnabled: Bool) -> Color {
            guard isEnabled else { return LopanColors.borderLight }
            
            switch self {
            case .outline:
                return LopanColors.primary
            default:
                return Color.clear
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .outline:
                return 1
            default:
                return 0
            }
        }
        
        func shadow(isEnabled: Bool, isPressed: Bool) -> ShadowStyle {
            guard isEnabled else { return LopanShadows.none }
            
            switch self {
            case .primary, .destructive:
                return isPressed ? LopanShadows.buttonPressed : LopanShadows.button
            case .secondary:
                return isPressed ? LopanShadows.buttonPressed : LopanShadows.sm
            default:
                return LopanShadows.none
            }
        }
        
        private var disabledBackgroundColor: Color {
            switch self {
            case .primary, .destructive:
                return LopanColors.surface
            case .secondary:
                return LopanColors.backgroundSecondary
            default:
                return Color.clear
            }
        }
    }
}

// MARK: - Button Sizes
extension LopanButton {
    enum ButtonSize {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return LopanSpacing.minTouchTarget
            case .large: return 52
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return LopanSpacing.sm
            case .medium: return LopanSpacing.md
            case .large: return LopanSpacing.lg
            }
        }
        
        var font: Font {
            switch self {
            case .small: return LopanTypography.buttonSmall
            case .medium: return LopanTypography.buttonMedium
            case .large: return LopanTypography.buttonLarge
            }
        }
        
        var iconFont: Font {
            switch self {
            case .small: return .system(size: 14, weight: .medium)
            case .medium: return .system(size: 16, weight: .medium)
            case .large: return .system(size: 18, weight: .medium)
            }
        }
        
        var iconSpacing: CGFloat {
            switch self {
            case .small: return LopanSpacing.xs
            case .medium: return LopanSpacing.sm
            case .large: return LopanSpacing.md
            }
        }
    }
}

// MARK: - Icon Position
extension LopanButton {
    enum IconPosition {
        case leading
        case trailing
    }
}

// MARK: - Convenience Initializers
extension LopanButton {
    /// Creates a primary button
    static func primary(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) -> LopanButton {
        LopanButton(
            title,
            style: .primary,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            icon: icon,
            iconPosition: iconPosition,
            action: action
        )
    }
    
    /// Creates a secondary button
    static func secondary(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) -> LopanButton {
        LopanButton(
            title,
            style: .secondary,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            icon: icon,
            iconPosition: iconPosition,
            action: action
        )
    }
    
    /// Creates a destructive button
    static func destructive(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) -> LopanButton {
        LopanButton(
            title,
            style: .destructive,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            icon: icon,
            iconPosition: iconPosition,
            action: action
        )
    }
    
    /// Creates a ghost button
    static func ghost(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) -> LopanButton {
        LopanButton(
            title,
            style: .ghost,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            icon: icon,
            iconPosition: iconPosition,
            action: action
        )
    }
    
    /// Creates an outline button
    static func outline(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) -> LopanButton {
        LopanButton(
            title,
            style: .outline,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            icon: icon,
            iconPosition: iconPosition,
            action: action
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: LopanSpacing.md) {
        LopanButton.primary("Primary Button", icon: "plus") { }
        LopanButton.secondary("Secondary Button") { }
        LopanButton.outline("Outline Button", icon: "arrow.right", iconPosition: .trailing) { }
        LopanButton.ghost("Ghost Button") { }
        LopanButton.destructive("Delete", icon: "trash") { }
        LopanButton.primary("Loading", isLoading: true) { }
        LopanButton.primary("Disabled", isEnabled: false) { }
    }
    .padding()
}