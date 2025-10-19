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

    // MARK: - Accessibility Computed Properties

    private var accessibilityLabel: String {
        if isLoading {
            return "正在加载，\(title)"
        } else if !isEnabled {
            return "\(title)，不可用"
        } else {
            return title
        }
    }

    private var accessibilityHint: String {
        if isLoading {
            return "请等待操作完成"
        } else if !isEnabled {
            return "此按钮当前不可用"
        } else {
            switch style {
            case .primary:
                return "点击执行主要操作"
            case .secondary:
                return "点击执行次要操作"
            case .destructive:
                return "点击执行删除操作，请谨慎操作"
            case .tertiary, .ghost:
                return "点击执行操作"
            case .outline:
                return "点击查看更多选项"
            }
        }
    }

    private var accessibilityValue: String {
        var components: [String] = []

        if isLoading {
            components.append("加载中")
        }

        if !isEnabled {
            components.append("不可用")
        }

        if icon != nil {
            components.append("包含图标")
        }

        return components.joined(separator: "，")
    }

    // MARK: - Haptic Feedback

    private func performHapticFeedback() {
        let hapticAction = getHapticAction()
        LopanHapticEngine.shared.perform(hapticAction)
    }

    private func getHapticAction() -> LopanHapticEngine.UIAction {
        switch style {
        case .primary:
            return .primaryAction
        case .secondary:
            return .secondaryAction
        case .destructive:
            return .destructiveAction
        case .tertiary, .ghost, .outline:
            return .buttonTap
        }
    }

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
                performHapticFeedback()
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
        .lopanAccessibility(
            role: .button,
            label: accessibilityLabel,
            hint: accessibilityHint,
            value: accessibilityValue
        )
        .lopanMinimumTouchTarget()
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
                return isPressed ? LopanColors.primaryLight : LopanColors.clear
            case .outline:
                return isPressed ? LopanColors.primaryLight : LopanColors.clear
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
                return LopanColors.clear
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
                return LopanColors.clear
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

// MARK: - Dynamic Type Previews

#Preview("Default Size") {
    VStack(spacing: 16) {
        Text("Button Styles")
            .font(.headline)
            .padding(.bottom)

        LopanButton.primary("Primary Action", icon: "plus") { }
        LopanButton.secondary("Secondary Action") { }
        LopanButton.destructive("Delete Item", icon: "trash") { }
        LopanButton.outline("View Details", icon: "arrow.right", iconPosition: .trailing) { }
        LopanButton.ghost("Cancel") { }

        Divider()

        HStack {
            LopanButton.primary("Small", size: .small) { }
            LopanButton.primary("Medium", size: .medium) { }
            LopanButton.primary("Large", size: .large) { }
        }

        HStack {
            LopanButton.primary("Loading", isLoading: true) { }
            LopanButton.primary("Disabled", isEnabled: false) { }
        }
    }
    .padding()
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    VStack(spacing: 20) {
        Text("Button Preview at Extra Large Size")
            .font(.title2)
            .padding(.bottom)

        LopanButton.primary("Complete Production Order", size: .large, icon: "checkmark") { }
        LopanButton.secondary("View Manufacturing Details", size: .large) { }
        LopanButton.destructive("Cancel Manufacturing Process", size: .large, icon: "xmark") { }

        Divider()

        VStack(spacing: 12) {
            LopanButton.outline("Review Quality Control Report", size: .medium, icon: "doc.text") { }
            LopanButton.ghost("Skip This Step", size: .medium) { }
        }
    }
    .padding()
    .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Accessibility 3") {
    VStack(spacing: 24) {
        Text("Button Preview at AX3 Size")
            .font(.title2)
            .padding(.bottom)

        LopanButton.primary("Production Status: Start Manufacturing Batch", size: .large, icon: "play.fill") { }
        LopanButton.secondary("Quality Control: Review Inspection Report", size: .large, icon: "doc.magnifyingglass") { }
        LopanButton.destructive("Critical Action: Stop All Production", size: .large, icon: "stop.fill") { }

        Divider()

        VStack(spacing: 16) {
            LopanButton.outline("Export Manufacturing Data to Excel", size: .large, icon: "square.and.arrow.up") { }
            LopanButton.ghost("Return to Dashboard", size: .large, icon: "arrow.left") { }
        }
    }
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    VStack(spacing: 30) {
        Text("Maximum Accessibility Size")
            .font(.largeTitle)
            .padding(.bottom)

        LopanButton.primary("Execute Action", size: .large, icon: "checkmark.circle.fill") { }
        LopanButton.destructive("Delete Item", size: .large, icon: "trash.fill") { }

        Divider()

        LopanButton.outline("View Details", size: .large, icon: "info.circle") { }
    }
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX3") {
    VStack(spacing: 24) {
        Text("Dark Mode Button Preview")
            .font(.title2)
            .padding(.bottom)

        LopanButton.primary("Dark Mode Primary Button", size: .large, icon: "moon.fill") { }
        LopanButton.secondary("Secondary Action", size: .large) { }
        LopanButton.destructive("Destructive Action", size: .large, icon: "exclamationmark.triangle.fill") { }

        HStack {
            LopanButton.outline("Outline", size: .medium) { }
            LopanButton.ghost("Ghost", size: .medium) { }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Loading and States") {
    VStack(spacing: 20) {
        Text("Button States")
            .font(.headline)
            .padding(.bottom)

        LopanButton.primary("Processing Order", size: .large, isLoading: true) { }
        LopanButton.secondary("Loading Data", size: .medium, isLoading: true) { }

        Divider()

        LopanButton.primary("Disabled Primary", size: .large, isEnabled: false) { }
        LopanButton.destructive("Disabled Destructive", size: .medium, isEnabled: false, icon: "trash") { }
    }
    .padding()
    .environment(\.dynamicTypeSize, .xLarge)
}