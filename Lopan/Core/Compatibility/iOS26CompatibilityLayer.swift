//
//  iOS26CompatibilityLayer.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  iOS 26 compatibility layer for progressive feature adoption
//

import SwiftUI
import Foundation
import os.log

// MARK: - iOS 26 Compatibility Layer

@MainActor
public final class iOS26CompatibilityLayer: ObservableObject {
    nonisolated(unsafe) public static let shared = iOS26CompatibilityLayer()

    // MARK: - Version Detection

    public let isIOS26Available: Bool
    public let isIOS25Available: Bool
    public let isIOS24Available: Bool
    public let currentMajorVersion: Int

    private let logger = Logger(subsystem: "com.lopan.compatibility", category: "iOS26Layer")

    nonisolated private init() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        currentMajorVersion = version.majorVersion
        isIOS26Available = version.majorVersion >= 26
        isIOS25Available = version.majorVersion >= 25
        isIOS24Available = version.majorVersion >= 24

        logger.info("🔧 iOS Compatibility Layer initialized for iOS \(self.currentMajorVersion)")
        logger.info("🆕 iOS 26 features: \(self.isIOS26Available ? "AVAILABLE" : "NOT AVAILABLE")")
    }

    // MARK: - Feature Availability Checks

    public enum CompatibilityFeature: String, CaseIterable {
        case observablePattern = "observable_pattern"
        case fluidAnimations = "fluid_animations"
        case glassMorphismV2 = "glass_morphism_v2"
        case spatialNavigation = "spatial_navigation"
        case enhancedAccessibility = "enhanced_accessibility"
        case intelligentPreloading = "intelligent_preloading"
        case adaptiveLayouts = "adaptive_layouts"
        case pressureGestures = "pressure_gestures"
        case spatialAudio = "spatial_audio"
        case metalRendering = "metal_rendering"

        public var displayName: String {
            switch self {
            case .observablePattern:
                return "Observable Pattern"
            case .fluidAnimations:
                return "Fluid Animations"
            case .glassMorphismV2:
                return "Glass Morphism v2"
            case .spatialNavigation:
                return "Spatial Navigation"
            case .enhancedAccessibility:
                return "Enhanced Accessibility"
            case .intelligentPreloading:
                return "Intelligent Preloading"
            case .adaptiveLayouts:
                return "Adaptive Layouts"
            case .pressureGestures:
                return "Pressure Gestures"
            case .spatialAudio:
                return "Spatial Audio"
            case .metalRendering:
                return "Metal Rendering"
            }
        }

        public var requiresIOS26: Bool {
            switch self {
            case .observablePattern, .fluidAnimations, .glassMorphismV2, .spatialNavigation:
                return true
            case .enhancedAccessibility, .intelligentPreloading, .adaptiveLayouts:
                return true
            case .pressureGestures, .spatialAudio, .metalRendering:
                return true
            }
        }
    }

    public func isFeatureAvailable(_ feature: CompatibilityFeature) -> Bool {
        if feature.requiresIOS26 {
            return isIOS26Available
        }
        return true // Feature available on all supported versions
    }

    // MARK: - Version-Aware Dependency Providers

    public protocol ObservationProviding {
        func createDashboardState() -> any DashboardStateProviding
        func createAnimationCoordinator() -> any AnimationCoordinating
    }

    public protocol DashboardStateProviding: ObservableObject {
        var items: [CustomerOutOfStock] { get set }
        var selectedDate: Date { get set }
        var isLoading: Bool { get set }
    }

    public protocol AnimationCoordinating {
        func performFluidTransition(duration: TimeInterval) async
        func createSpringAnimation(stiffness: Double, damping: Double) -> Animation
    }

    // MARK: - iOS 26 Providers

    @available(iOS 26.0, *)
    public final class iOS26ObservationProvider: ObservationProviding {
        public func createDashboardState() -> any DashboardStateProviding {
            return iOS26DashboardState()
        }

        public func createAnimationCoordinator() -> any AnimationCoordinating {
            return iOS26AnimationCoordinator()
        }
    }

    @available(iOS 26.0, *)
    @Observable
    public final class iOS26DashboardState: DashboardStateProviding {
        public var items: [CustomerOutOfStock] = []
        public var selectedDate = Date()
        public var isLoading = false
    }

    @available(iOS 26.0, *)
    public final class iOS26AnimationCoordinator: AnimationCoordinating {
        public func performFluidTransition(duration: TimeInterval) async {
            // iOS 26 enhanced animation system
            withAnimation(.smooth(duration: duration)) {
                // Perform transition
            }
        }

        public func createSpringAnimation(stiffness: Double, damping: Double) -> Animation {
            return .interactiveSpring(
                response: 0.5,
                dampingFraction: damping,
                blendDuration: 0.25
            )
        }
    }

    // MARK: - Legacy Providers (iOS 17+)

    public final class LegacyObservationProvider: ObservationProviding {
        public func createDashboardState() -> any DashboardStateProviding {
            return LegacyDashboardState()
        }

        public func createAnimationCoordinator() -> any AnimationCoordinating {
            return LegacyAnimationCoordinator()
        }
    }

    public final class LegacyDashboardState: ObservableObject, DashboardStateProviding {
        @Published public var items: [CustomerOutOfStock] = []
        @Published public var selectedDate = Date()
        @Published public var isLoading = false
    }

    public final class LegacyAnimationCoordinator: AnimationCoordinating {
        public func performFluidTransition(duration: TimeInterval) async {
            // Legacy animation system
            withAnimation(.easeInOut(duration: duration)) {
                // Perform transition
            }
        }

        public func createSpringAnimation(stiffness: Double, damping: Double) -> Animation {
            return .spring(
                response: 0.5,
                dampingFraction: damping,
                blendDuration: 0.25
            )
        }
    }

    // MARK: - Dependency Factory

    public var observationProvider: ObservationProviding {
        if isIOS26Available {
            if #available(iOS 26.0, *) {
                return iOS26ObservationProvider()
            }
        }
        return LegacyObservationProvider()
    }

    // MARK: - Feature Diagnostics

    public struct CompatibilityReport {
        public let iOSVersion: String
        public let availableFeatures: [CompatibilityFeature]
        public let unavailableFeatures: [CompatibilityFeature]
        public let compatibilityScore: Double

        public var summary: String {
            """
            iOS Compatibility Report
            ========================
            iOS Version: \(iOSVersion)
            Available Features: \(availableFeatures.count)/\(CompatibilityFeature.allCases.count)
            Compatibility Score: \(String(format: "%.1f", compatibilityScore * 100))%

            Available:
            \(availableFeatures.map { "✅ \($0.displayName)" }.joined(separator: "\n"))

            Unavailable:
            \(unavailableFeatures.map { "❌ \($0.displayName)" }.joined(separator: "\n"))
            """
        }
    }

    public func generateCompatibilityReport() -> CompatibilityReport {
        let allFeatures = CompatibilityFeature.allCases
        let availableFeatures = allFeatures.filter { isFeatureAvailable($0) }
        let unavailableFeatures = allFeatures.filter { !isFeatureAvailable($0) }

        let score = Double(availableFeatures.count) / Double(allFeatures.count)

        let versionString = "\(currentMajorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)"

        return CompatibilityReport(
            iOSVersion: versionString,
            availableFeatures: availableFeatures,
            unavailableFeatures: unavailableFeatures,
            compatibilityScore: score
        )
    }

    // MARK: - Runtime Feature Detection

    public func logCompatibilityStatus() {
        let report = generateCompatibilityReport()
        logger.info("📊 \(report.summary)")

        if report.compatibilityScore == 1.0 {
            logger.info("🎉 Full iOS 26 compatibility achieved!")
        } else if report.compatibilityScore >= 0.8 {
            logger.info("✅ High compatibility - most features available")
        } else if report.compatibilityScore >= 0.5 {
            logger.info("⚠️ Moderate compatibility - some features unavailable")
        } else {
            logger.warning("❌ Limited compatibility - many features unavailable")
        }
    }
}

// MARK: - Environment Integration

private struct CompatibilityLayerKey: EnvironmentKey {
    static let defaultValue = iOS26CompatibilityLayer.shared
}

public extension EnvironmentValues {
    var compatibilityLayer: iOS26CompatibilityLayer {
        get { self[CompatibilityLayerKey.self] }
        set { self[CompatibilityLayerKey.self] = newValue }
    }
}

// MARK: - SwiftUI Integration Helpers

public extension View {
    /// Conditionally apply iOS 26 specific modifiers
    @ViewBuilder
    func iOS26Conditional<Content: View>(
        @ViewBuilder ios26: () -> Content,
        @ViewBuilder fallback: () -> Content = { EmptyView() }
    ) -> some View {
        if iOS26CompatibilityLayer.shared.isIOS26Available {
            if #available(iOS 26.0, *) {
                ios26()
            } else {
                fallback()
            }
        } else {
            fallback()
        }
    }

    /// Apply adaptive styling based on iOS version
    @ViewBuilder
    func adaptiveStyle<Style: ViewModifier>(
        ios26: Style,
        legacy: Style
    ) -> some View {
        if iOS26CompatibilityLayer.shared.isIOS26Available {
            self.modifier(ios26)
        } else {
            self.modifier(legacy)
        }
    }
}

// MARK: - Performance Monitoring

public final class CompatibilityPerformanceMonitor {
    public static let shared = CompatibilityPerformanceMonitor()
    private let logger = Logger(subsystem: "com.lopan.compatibility", category: "Performance")

    private var metrics: [String: TimeInterval] = [:]

    public func measureFeaturePerformance<T>(
        feature: iOS26CompatibilityLayer.CompatibilityFeature,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics[feature.rawValue] = duration
            logger.info("⏱️ \(feature.displayName) completed in \(String(format: "%.3f", duration))s")
        }

        return try await operation()
    }

    public func getPerformanceReport() -> [String: TimeInterval] {
        return metrics
    }
}