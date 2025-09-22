//
//  LiquidGlassMaterial.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/19.
//  iOS 26 Liquid Glass Material Components
//

import SwiftUI

/// iOS 26 Liquid Glass material types for different use cases
@available(iOS 26.0, *)
public enum LiquidGlassMaterialType {
    case card
    case button
    case navigation
    case overlay
    case modal
    case toolbar

    var opacity: Double {
        switch self {
        case .card: return 0.85
        case .button: return 0.9
        case .navigation: return 0.95
        case .overlay: return 0.7
        case .modal: return 0.88
        case .toolbar: return 0.92
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .card: return 20
        case .button: return 15
        case .navigation: return 25
        case .overlay: return 30
        case .modal: return 22
        case .toolbar: return 18
        }
    }

    var material: Material {
        switch self {
        case .card: return .ultraThinMaterial
        case .button: return .thinMaterial
        case .navigation: return .regularMaterial
        case .overlay: return .thickMaterial
        case .modal: return .regularMaterial
        case .toolbar: return .thinMaterial
        }
    }
}

/// Liquid Glass material view for iOS 26
@available(iOS 26.0, *)
public struct LiquidGlassMaterial: View {
    let type: LiquidGlassMaterialType
    let cornerRadius: CGFloat
    let depth: CGFloat
    let isPressed: Bool

    @Environment(\.liquidGlassTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public init(
        type: LiquidGlassMaterialType = .card,
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0,
        isPressed: Bool = false
    ) {
        self.type = type
        self.cornerRadius = cornerRadius
        self.depth = depth
        self.isPressed = isPressed
    }

    public var body: some View {
        ZStack {
            // Base glass material
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(type.material)
                .opacity(type.opacity)

            // Liquid glass gradient overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(liquidGlassGradient)
                .blendMode(.overlay)

            // Refraction highlights
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(refractionHighlights)
                .blendMode(.softLight)

            // Interactive pressed state
            if isPressed {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white.opacity(0.2))
                    .blendMode(.overlay)
            }

            // Border highlight
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(borderGradient, lineWidth: 1)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .shadow(color: .black.opacity(0.1 * depth), radius: 8 * depth, x: 0, y: 2 * depth)
        .shadow(color: .black.opacity(0.05 * depth), radius: 16 * depth, x: 0, y: 4 * depth)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }

    // MARK: - Private Computed Properties

    private var liquidGlassGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.glassColors.primary.opacity(0.1),
                theme.glassColors.secondary.opacity(0.05),
                theme.glassColors.accent.opacity(0.08),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var refractionHighlights: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                .clear,
                .white.opacity(colorScheme == .dark ? 0.08 : 0.12),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                .clear,
                .white.opacity(colorScheme == .dark ? 0.1 : 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Liquid Glass modifier for applying material effects to any view
@available(iOS 26.0, *)
public struct LiquidGlassModifier: ViewModifier {
    let type: LiquidGlassMaterialType
    let cornerRadius: CGFloat
    let depth: CGFloat
    let isPressed: Bool

    public func body(content: Content) -> some View {
        content
            .background {
                LiquidGlassMaterial(
                    type: type,
                    cornerRadius: cornerRadius,
                    depth: depth,
                    isPressed: isPressed
                )
            }
    }
}

// MARK: - View Extensions

@available(iOS 26.0, *)
public extension View {

    /// Applies liquid glass material background
    func liquidGlassMaterial(
        _ type: LiquidGlassMaterialType = .card,
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0,
        isPressed: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                type: type,
                cornerRadius: cornerRadius,
                depth: depth,
                isPressed: isPressed
            )
        )
    }

    /// Applies card-style liquid glass material
    func liquidGlassCard(
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0
    ) -> some View {
        liquidGlassMaterial(.card, cornerRadius: cornerRadius, depth: depth)
    }

    /// Applies button-style liquid glass material
    func liquidGlassButton(
        cornerRadius: CGFloat = 12,
        isPressed: Bool = false
    ) -> some View {
        liquidGlassMaterial(.button, cornerRadius: cornerRadius, isPressed: isPressed)
    }

    /// Applies navigation-style liquid glass material
    func liquidGlassNavigation(
        cornerRadius: CGFloat = 0
    ) -> some View {
        liquidGlassMaterial(.navigation, cornerRadius: cornerRadius)
    }

    /// Applies modal-style liquid glass material
    func liquidGlassModal(
        cornerRadius: CGFloat = 20,
        depth: CGFloat = 2.0
    ) -> some View {
        liquidGlassMaterial(.modal, cornerRadius: cornerRadius, depth: depth)
    }

    /// Applies toolbar-style liquid glass material
    func liquidGlassToolbar() -> some View {
        liquidGlassMaterial(.toolbar, cornerRadius: 0)
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    VStack(spacing: 20) {
        // Card example
        VStack {
            Text("Liquid Glass Card")
                .font(.headline)
            Text("This is a card with liquid glass material")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .liquidGlassCard()

        // Button example
        Button("Liquid Glass Button") {
            // Action
        }
        .padding()
        .liquidGlassButton()

        // Modal example
        VStack {
            Text("Modal Content")
                .font(.title2)
            Text("This modal uses liquid glass material")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .liquidGlassModal()
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}