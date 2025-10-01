//
//  EnhancedLiquidGlass.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  Enhanced iOS 26 Liquid Glass with backward compatibility
//

import SwiftUI
import Foundation
import os.log

// MARK: - Enhanced Liquid Glass Material System

@MainActor
public final class EnhancedLiquidGlassManager: ObservableObject {
    public static let shared = EnhancedLiquidGlassManager()

    private let compatibilityLayer = iOS26CompatibilityLayer.shared
    private let featureFlags = FeatureFlagManager.shared
    private let logger = Logger(subsystem: "com.lopan.glassmorphism", category: "EnhancedGlass")

    @Published public var isEnabled: Bool = true
    @Published public var performanceMode: PerformanceMode = .adaptive
    @Published public var glassIntensity: Double = 0.8
    @Published public var adaptiveQuality: Bool = true

    public enum PerformanceMode: String, CaseIterable {
        case minimal = "minimal"
        case balanced = "balanced"
        case premium = "premium"
        case adaptive = "adaptive"

        public var displayName: String {
            switch self {
            case .minimal: return "Minimal"
            case .balanced: return "Balanced"
            case .premium: return "Premium"
            case .adaptive: return "Adaptive"
            }
        }

        public var blurRadius: CGFloat {
            switch self {
            case .minimal: return 8
            case .balanced: return 15
            case .premium: return 25
            case .adaptive: return 20 // Dynamic based on device
            }
        }

        public var layerCount: Int {
            switch self {
            case .minimal: return 2
            case .balanced: return 3
            case .premium: return 5
            case .adaptive: return 4
            }
        }
    }

    private init() {
        setupPerformanceMode()
        logger.info("🌊 Enhanced Liquid Glass Manager initialized")
    }

    private func setupPerformanceMode() {
        // Automatically adjust performance mode based on device capabilities
        if adaptiveQuality {
            let deviceSupportsHighPerformance = ProcessInfo.processInfo.physicalMemory > 4_000_000_000 // 4GB+

            if compatibilityLayer.isIOS26Available && deviceSupportsHighPerformance {
                performanceMode = .premium
            } else if compatibilityLayer.isIOS25Available {
                performanceMode = .balanced
            } else {
                performanceMode = .minimal
            }

            logger.info("🎛️ Adaptive performance mode set to: \(self.performanceMode.displayName)")
        }
    }

    // MARK: - Glass Material Types

    public enum MaterialType: String, CaseIterable {
        case card = "card"
        case button = "button"
        case navigation = "navigation"
        case overlay = "overlay"
        case modal = "modal"
        case toolbar = "toolbar"
        case dashboard = "dashboard"
        case quickStat = "quick_stat"
        case chartContainer = "chart_container"
        case filterChip = "filter_chip"
        case content = "content"

        public var opacity: Double {
            switch self {
            case .card: return 0.85
            case .button: return 0.9
            case .navigation: return 0.95
            case .overlay: return 0.7
            case .modal: return 0.88
            case .toolbar: return 0.92
            case .dashboard: return 0.82
            case .quickStat: return 0.88
            case .chartContainer: return 0.87
            case .filterChip: return 0.92
            case .content: return 0.85
            }
        }

        public var baseMaterial: Material {
            switch self {
            case .card, .dashboard, .chartContainer, .content: return .ultraThinMaterial
            case .button, .quickStat, .filterChip: return .thinMaterial
            case .navigation, .toolbar: return .regularMaterial
            case .overlay: return .thickMaterial
            case .modal: return .regularMaterial
            }
        }

        public var shouldUseAdvancedEffects: Bool {
            switch self {
            case .card, .modal, .dashboard, .chartContainer: return true
            case .button, .quickStat, .filterChip: return true
            case .navigation, .toolbar, .overlay, .content: return false
            }
        }
    }

    // MARK: - Enhanced Glass Material Component

    @ViewBuilder
    public func createGlassMaterial(
        type: MaterialType,
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0,
        isPressed: Bool = false,
        isHovered: Bool = false,
        customTint: Color? = nil
    ) -> some View {
        if featureFlags.isEnabled(.glassMorphismV2) && compatibilityLayer.isIOS26Available {
            if #available(iOS 26.0, *) {
                ModernLiquidGlass(
                    type: type,
                    cornerRadius: cornerRadius,
                    depth: depth,
                    isPressed: isPressed,
                    isHovered: isHovered,
                    customTint: customTint,
                    performanceMode: performanceMode
                )
            } else {
                LegacyGlassMaterial(
                    type: type,
                    cornerRadius: cornerRadius,
                    depth: depth,
                    isPressed: isPressed,
                    customTint: customTint
                )
            }
        } else {
            LegacyGlassMaterial(
                type: type,
                cornerRadius: cornerRadius,
                depth: depth,
                isPressed: isPressed,
                customTint: customTint
            )
        }
    }
}

// MARK: - Modern iOS 26 Liquid Glass Implementation

@available(iOS 26.0, *)
private struct ModernLiquidGlass: View {
    let type: EnhancedLiquidGlassManager.MaterialType
    let cornerRadius: CGFloat
    let depth: CGFloat
    let isPressed: Bool
    let isHovered: Bool
    let customTint: Color?
    let performanceMode: EnhancedLiquidGlassManager.PerformanceMode

    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase: Double = 0

    var body: some View {
        ZStack {
            // Base material layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(type.baseMaterial)
                .opacity(type.opacity)

            // Enhanced gradient layers for premium experience
            if performanceMode.layerCount >= 3 {
                // Primary liquid gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(primaryLiquidGradient)
                    .blendMode(.overlay)

                // Secondary refraction layer
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(refractionGradient)
                    .blendMode(.softLight)
            }

            // Interactive state layers
            if isHovered {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(hoverOverlay)
                    .blendMode(.overlay)
            }

            if isPressed {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(pressedOverlay)
                    .blendMode(.overlay)
            }

            // Advanced effects for premium mode
            if performanceMode == .premium && type.shouldUseAdvancedEffects {
                // Animated liquid shimmer
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(animatedShimmerGradient)
                    .blendMode(.softLight)
                    .opacity(0.3)

                // Depth perception layer
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(depthGradient)
                    .blendMode(.multiply)
                    .opacity(0.1)
            }

            // Border highlighting
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(borderGradient, lineWidth: 1)
        }
        .scaleEffect(pressedScale)
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: isPressed)
        .animation(.smooth(duration: 0.3), value: isHovered)
        .onAppear {
            if performanceMode == .premium {
                startShimmerAnimation()
            }
        }
    }

    // MARK: - Computed Properties

    private var primaryLiquidGradient: LinearGradient {
        let colors: [Color] = [
            (customTint ?? LopanColors.primary).opacity(0.12),
            LopanColors.secondary.opacity(0.06),
            (customTint ?? LopanColors.info).opacity(0.09),
            .clear
        ]

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var refractionGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                .clear,
                .white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                .clear,
                .white.opacity(colorScheme == .dark ? 0.12 : 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var animatedShimmerGradient: LinearGradient {
        let shimmerColors: [Color] = [
            .clear,
            .white.opacity(0.1),
            .white.opacity(0.2),
            .white.opacity(0.1),
            .clear
        ]

        return LinearGradient(
            colors: shimmerColors,
            startPoint: UnitPoint(x: animationPhase - 0.3, y: 0),
            endPoint: UnitPoint(x: animationPhase + 0.3, y: 1)
        )
    }

    private var depthGradient: RadialGradient {
        RadialGradient(
            colors: [
                .clear,
                .black.opacity(0.05),
                .black.opacity(0.1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }

    private var hoverOverlay: Color {
        .white.opacity(colorScheme == .dark ? 0.1 : 0.15)
    }

    private var pressedOverlay: Color {
        .white.opacity(colorScheme == .dark ? 0.2 : 0.25)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.25 : 0.45),
                .clear,
                .white.opacity(colorScheme == .dark ? 0.15 : 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var pressedScale: CGFloat {
        isPressed ? 0.98 : (isHovered ? 1.02 : 1.0)
    }

    private var shadowOpacity: Double {
        0.1 * depth * (isPressed ? 0.5 : 1.0)
    }

    private var shadowRadius: CGFloat {
        (8 * depth) * (isPressed ? 0.7 : 1.0)
    }

    private var shadowOffset: CGFloat {
        (2 * depth) * (isPressed ? 0.5 : 1.0)
    }

    private func startShimmerAnimation() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            animationPhase = 1.3
        }
    }
}

// MARK: - Legacy Glass Material (iOS 17+)

private struct LegacyGlassMaterial: View {
    let type: EnhancedLiquidGlassManager.MaterialType
    let cornerRadius: CGFloat
    let depth: CGFloat
    let isPressed: Bool
    let customTint: Color?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base material
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(type.baseMaterial)
                .opacity(type.opacity)

            // Simple gradient overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(legacyGradient)
                .blendMode(.overlay)

            // Interactive state
            if isPressed {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white.opacity(0.2))
                    .blendMode(.overlay)
            }

            // Simple border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .shadow(color: .black.opacity(0.1 * depth), radius: 6 * depth, x: 0, y: 2 * depth)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
    }

    private var legacyGradient: LinearGradient {
        LinearGradient(
            colors: [
                (customTint ?? LopanColors.primary).opacity(0.1),
                LopanColors.secondary.opacity(0.05),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Environment Integration

private struct EnhancedLiquidGlassManagerKey: EnvironmentKey {
    static let defaultValue = EnhancedLiquidGlassManager.shared
}

public extension EnvironmentValues {
    var enhancedLiquidGlass: EnhancedLiquidGlassManager {
        get { self[EnhancedLiquidGlassManagerKey.self] }
        set { self[EnhancedLiquidGlassManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Applies enhanced liquid glass material with backward compatibility
    func enhancedLiquidGlass(
        _ type: EnhancedLiquidGlassManager.MaterialType = .card,
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0,
        isPressed: Bool = false,
        isHovered: Bool = false,
        customTint: Color? = nil
    ) -> some View {
        background {
            EnhancedLiquidGlassManager.shared.createGlassMaterial(
                type: type,
                cornerRadius: cornerRadius,
                depth: depth,
                isPressed: isPressed,
                isHovered: isHovered,
                customTint: customTint
            )
        }
    }

    /// Dashboard card with enhanced glass material
    func dashboardGlassCard(
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0,
        isPressed: Bool = false,
        customTint: Color? = nil
    ) -> some View {
        enhancedLiquidGlass(
            .dashboard,
            cornerRadius: cornerRadius,
            depth: depth,
            isPressed: isPressed,
            customTint: customTint
        )
    }

    /// Quick stat card with enhanced glass material
    func quickStatGlassCard(
        cornerRadius: CGFloat = 12,
        isPressed: Bool = false
    ) -> some View {
        enhancedLiquidGlass(
            .quickStat,
            cornerRadius: cornerRadius,
            depth: 0.8,
            isPressed: isPressed
        )
    }

    /// Interactive button with glass material
    func glassButton(
        cornerRadius: CGFloat = 12,
        isPressed: Bool = false,
        isHovered: Bool = false,
        customTint: Color? = nil
    ) -> some View {
        enhancedLiquidGlass(
            .button,
            cornerRadius: cornerRadius,
            depth: 0.6,
            isPressed: isPressed,
            isHovered: isHovered,
            customTint: customTint
        )
    }

    /// Modal glass material
    func glassModal(
        cornerRadius: CGFloat = 20,
        depth: CGFloat = 2.0
    ) -> some View {
        enhancedLiquidGlass(
            .modal,
            cornerRadius: cornerRadius,
            depth: depth
        )
    }

    /// Chart container with glass material
    func chartContainerGlass(
        cornerRadius: CGFloat = 20,
        depth: CGFloat = 2.0,
        customTint: Color? = nil
    ) -> some View {
        enhancedLiquidGlass(
            .chartContainer,
            cornerRadius: cornerRadius,
            depth: depth,
            customTint: customTint
        )
    }

    /// Filter chip with glass material
    func filterChipGlass(
        cornerRadius: CGFloat = 16,
        isPressed: Bool = false,
        customTint: Color? = nil
    ) -> some View {
        enhancedLiquidGlass(
            .filterChip,
            cornerRadius: cornerRadius,
            depth: 0.5,
            isPressed: isPressed,
            customTint: customTint
        )
    }

    /// Content card with glass material
    func contentGlass(
        cornerRadius: CGFloat = 16,
        depth: CGFloat = 1.0
    ) -> some View {
        enhancedLiquidGlass(
            .content,
            cornerRadius: cornerRadius,
            depth: depth
        )
    }
}

// MARK: - Performance Monitoring

public extension EnhancedLiquidGlassManager {
    func measureGlassPerformance<T>(
        operation: () async throws -> T
    ) async rethrows -> T {
        return try await FeatureFlagManager.shared.measureFeaturePerformance(.glassMorphismV2) {
            try await operation()
        }
    }

    func optimizeForDevice() {
        let deviceMemory = ProcessInfo.processInfo.physicalMemory
        let deviceName = UIDevice.current.model

        logger.info("🔧 Optimizing glass performance for device: \(deviceName), Memory: \(deviceMemory / 1_000_000)MB")

        if deviceMemory < 3_000_000_000 { // Less than 3GB
            performanceMode = .minimal
            adaptiveQuality = false
            logger.info("⚡ Low memory device detected - using minimal glass effects")
        } else if deviceMemory < 6_000_000_000 { // Less than 6GB
            performanceMode = .balanced
            logger.info("⚖️ Medium memory device detected - using balanced glass effects")
        } else {
            performanceMode = .premium
            logger.info("🚀 High memory device detected - using premium glass effects")
        }
    }
}