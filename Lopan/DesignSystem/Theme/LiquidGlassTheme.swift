//
//  LiquidGlassTheme.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/19.
//  iOS 26 Liquid Glass Design System Implementation
//

import SwiftUI

/// iOS 26 Liquid Glass theme provider with translucent, reflective, and refractive effects
@available(iOS 26.0, *)
@MainActor
public final class LiquidGlassTheme: ObservableObject {

    // MARK: - Singleton Instance
    public static let shared = LiquidGlassTheme()

    // MARK: - Theme Properties
    @Published public var isEnabled: Bool = true
    @Published public var glassIntensity: Double = 0.8
    @Published public var refractionStrength: Double = 0.6
    @Published public var adaptiveMode: Bool = true

    private init() {}

    // MARK: - Glass Materials

    /// Primary glass material with high translucency
    public var primaryGlass: Material {
        .ultraThinMaterial
    }

    /// Secondary glass material for subtle effects
    public var secondaryGlass: Material {
        .thinMaterial
    }

    /// Accent glass material for interactive elements
    public var accentGlass: Material {
        .regularMaterial
    }

    /// Background glass material for containers
    public var backgroundGlass: Material {
        .thickMaterial
    }

    // MARK: - Glass Colors

    /// Dynamic glass colors that adapt to light/dark mode
    public var glassColors: LiquidGlassColors {
        LiquidGlassColors()
    }

    // MARK: - Glass Effects

    /// Creates a liquid glass background with refraction
    public func liquidGlassBackground() -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    glassColors.primary.opacity(0.1),
                    glassColors.secondary.opacity(0.05),
                    glassColors.accent.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(primaryGlass)
            .blur(radius: 1.5)

            // Refraction overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.2),
                            .clear,
                            .white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
        }
    }

    /// Creates interactive glass effect for buttons
    public func interactiveGlass(isPressed: Bool = false) -> some View {
        ZStack {
            Rectangle()
                .fill(accentGlass)

            if isPressed {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .blendMode(.overlay)
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }

    /// Creates depth-aware glass shadow
    public func glassDepthShadow(depth: CGFloat = 1.0) -> some View {
        Group {
            // Primary shadow
            Rectangle()
                .fill(.black.opacity(0.1 * depth))
                .blur(radius: 8 * depth)
                .offset(y: 2 * depth)

            // Secondary depth shadow
            Rectangle()
                .fill(.black.opacity(0.05 * depth))
                .blur(radius: 16 * depth)
                .offset(y: 4 * depth)
        }
    }
}

// MARK: - Liquid Glass Colors

@available(iOS 26.0, *)
public struct LiquidGlassColors {

    /// Primary glass tint color
    public var primary: Color {
        Color(.systemBlue).opacity(0.6)
    }

    /// Secondary glass tint color
    public var secondary: Color {
        Color(.systemPurple).opacity(0.4)
    }

    /// Accent glass color for highlights
    public var accent: Color {
        Color(.systemTeal).opacity(0.5)
    }

    /// Success glass color
    public var success: Color {
        Color(.systemGreen).opacity(0.5)
    }

    /// Warning glass color
    public var warning: Color {
        Color(.systemOrange).opacity(0.5)
    }

    /// Error glass color
    public var error: Color {
        Color(.systemRed).opacity(0.5)
    }

    /// Neutral glass color
    public var neutral: Color {
        Color(.systemGray).opacity(0.3)
    }
}

// MARK: - Environment Key

@available(iOS 26.0, *)
private struct LiquidGlassThemeKey: EnvironmentKey {
    nonisolated static let defaultValue = LiquidGlassTheme.shared
}

@available(iOS 26.0, *)
public extension EnvironmentValues {
    var liquidGlassTheme: LiquidGlassTheme {
        get { self[LiquidGlassThemeKey.self] }
        set { self[LiquidGlassThemeKey.self] = newValue }
    }
}

// MARK: - View Extensions

@available(iOS 26.0, *)
public extension View {

    /// Applies liquid glass theme to the environment
    func liquidGlassTheme(_ theme: LiquidGlassTheme = .shared) -> some View {
        environment(\.liquidGlassTheme, theme)
    }

    /// Applies liquid glass background effect
    func liquidGlassBackground() -> some View {
        background {
            LiquidGlassTheme.shared.liquidGlassBackground()
        }
    }

    /// Applies interactive glass effect
    func interactiveGlass(isPressed: Bool = false) -> some View {
        background {
            LiquidGlassTheme.shared.interactiveGlass(isPressed: isPressed)
        }
    }

    /// Applies glass depth shadow
    func glassDepthShadow(depth: CGFloat = 1.0) -> some View {
        background {
            LiquidGlassTheme.shared.glassDepthShadow(depth: depth)
        }
    }
}