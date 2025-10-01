//
//  FluidAnimationSystem.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  iOS 26 Enhanced Fluid Animation System with backward compatibility
//

import SwiftUI
import Foundation
import os.log

// MARK: - Fluid Animation Manager

@MainActor
public final class FluidAnimationManager: ObservableObject {
    public static let shared = FluidAnimationManager()

    private let compatibilityLayer = iOS26CompatibilityLayer.shared
    private let featureFlags = FeatureFlagManager.shared
    private let logger = Logger(subsystem: "com.lopan.animations", category: "FluidAnimations")

    @Published public var isEnabled: Bool = true
    @Published public var performanceMode: AnimationPerformanceMode = .adaptive
    @Published public var hapticFeedbackEnabled: Bool = true
    @Published public var reducedMotionOverride: Bool = false

    public enum AnimationPerformanceMode: String, CaseIterable {
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

        public var springResponse: Double {
            switch self {
            case .minimal: return 0.6
            case .balanced: return 0.4
            case .premium: return 0.3
            case .adaptive: return 0.35
            }
        }

        public var dampingFraction: Double {
            switch self {
            case .minimal: return 0.9
            case .balanced: return 0.8
            case .premium: return 0.7
            case .adaptive: return 0.75
            }
        }

        public var enableMicroInteractions: Bool {
            switch self {
            case .minimal: return false
            case .balanced: return true
            case .premium: return true
            case .adaptive: return true
            }
        }
    }

    private init() {
        setupPerformanceMode()
        setupAccessibilityObserver()
        logger.info("🎭 Fluid Animation Manager initialized")
    }

    private func setupPerformanceMode() {
        if performanceMode == .adaptive {
            let deviceSupportsHighPerformance = ProcessInfo.processInfo.physicalMemory > 4_000_000_000

            if compatibilityLayer.isIOS26Available && deviceSupportsHighPerformance {
                performanceMode = .premium
            } else if compatibilityLayer.isIOS25Available {
                performanceMode = .balanced
            } else {
                performanceMode = .minimal
            }

            logger.info("🎛️ Adaptive animation mode set to: \(self.performanceMode.displayName)")
        }
    }

    private func setupAccessibilityObserver() {
        // Monitor accessibility settings for reduced motion
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleReducedMotionChange()
        }
    }

    private func handleReducedMotionChange() {
        let isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled

        if isReducedMotionEnabled && !reducedMotionOverride {
            performanceMode = .minimal
            logger.info("♿ Reduced motion detected - switching to minimal animations")
        } else {
            setupPerformanceMode()
            logger.info("🎭 Standard motion - using adaptive animation mode")
        }
    }

    // MARK: - Animation Presets

    public enum AnimationType {
        case cardAppear
        case cardTap
        case cardHover
        case buttonPress
        case modalPresent
        case modalDismiss
        case statusChange
        case dataRefresh
        case dataTransition  // For chart/data updates on time range changes
        case navigationTransition
        case quickStatSelect
        case filterApply
        case searchUpdate
        case scrollToTop
        case loadingState
        case errorState
        case successState

        public var identifier: String {
            String(describing: self)
        }
    }

    // MARK: - iOS 26 Enhanced Animation Creation

    @ViewBuilder
    public func createAnimation(
        _ type: AnimationType,
        isActive: Bool = true,
        completion: (() -> Void)? = nil
    ) -> Animation {
        if featureFlags.isEnabled(.fluidAnimations) && compatibilityLayer.isIOS26Available {
            if #available(iOS 26.0, *) {
                return createModernAnimation(type, isActive: isActive)
            }
        }
        return createLegacyAnimation(type, isActive: isActive)
    }

    @available(iOS 26.0, *)
    private func createModernAnimation(_ type: AnimationType, isActive: Bool) -> Animation {
        switch type {
        case .cardAppear:
            return .smooth(duration: 0.6, extraBounce: 0.15)

        case .cardTap, .buttonPress:
            return .interactiveSpring(
                response: performanceMode.springResponse * 0.8,
                dampingFraction: performanceMode.dampingFraction,
                blendDuration: 0.25
            )

        case .cardHover:
            return .smooth(duration: 0.3)

        case .modalPresent:
            return .smooth(duration: 0.5, extraBounce: 0.1)

        case .modalDismiss:
            return .smooth(duration: 0.4)

        case .statusChange, .quickStatSelect:
            return .interactiveSpring(
                response: 0.3,
                dampingFraction: 0.8,
                blendDuration: 0.2
            )

        case .dataRefresh:
            return .smooth(duration: 0.8, extraBounce: 0.2)

        case .dataTransition:
            return .smooth(duration: 0.5, extraBounce: 0.1)

        case .navigationTransition:
            return .smooth(duration: 0.45)

        case .filterApply, .searchUpdate:
            return .smooth(duration: 0.35)

        case .scrollToTop:
            return .smooth(duration: 1.0)

        case .loadingState:
            return .linear(duration: 1.5).repeatForever(autoreverses: false)

        case .errorState:
            return .interactiveSpring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.1)

        case .successState:
            return .smooth(duration: 0.5, extraBounce: 0.3)
        }
    }

    private func createLegacyAnimation(_ type: AnimationType, isActive: Bool) -> Animation {
        switch type {
        case .cardAppear:
            return .spring(
                response: performanceMode.springResponse,
                dampingFraction: performanceMode.dampingFraction,
                blendDuration: 0.25
            )

        case .cardTap, .buttonPress:
            return .spring(
                response: performanceMode.springResponse * 0.8,
                dampingFraction: performanceMode.dampingFraction,
                blendDuration: 0.2
            )

        case .cardHover:
            return .easeInOut(duration: 0.3)

        case .modalPresent:
            return .spring(
                response: 0.5,
                dampingFraction: 0.8,
                blendDuration: 0.3
            )

        case .modalDismiss:
            return .easeInOut(duration: 0.4)

        case .statusChange, .quickStatSelect:
            return .spring(
                response: 0.3,
                dampingFraction: 0.8,
                blendDuration: 0.15
            )

        case .dataRefresh:
            return .spring(
                response: 0.6,
                dampingFraction: 0.7,
                blendDuration: 0.25
            )

        case .dataTransition:
            return .spring(
                response: 0.45,
                dampingFraction: 0.85,
                blendDuration: 0.2
            )

        case .navigationTransition:
            return .easeInOut(duration: 0.45)

        case .filterApply, .searchUpdate:
            return .easeInOut(duration: 0.35)

        case .scrollToTop:
            return .easeInOut(duration: 1.0)

        case .loadingState:
            return .linear(duration: 1.5).repeatForever(autoreverses: false)

        case .errorState:
            return .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.1)

        case .successState:
            return .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.2)
        }
    }

    // MARK: - Micro-Interactions

    public func triggerMicroInteraction(_ type: MicroInteractionType) {
        guard performanceMode.enableMicroInteractions else { return }

        if hapticFeedbackEnabled {
            triggerHapticFeedback(for: type)
        }

        logger.debug("🎯 Triggered micro-interaction: \(type.identifier)")
    }

    public enum MicroInteractionType {
        case lightTap
        case mediumTap
        case heavyTap
        case success
        case warning
        case error
        case selection
        case impact
        case notification

        public var identifier: String {
            String(describing: self)
        }
    }

    private func triggerHapticFeedback(for type: MicroInteractionType) {
        switch type {
        case .lightTap, .selection:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case .mediumTap, .impact:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .heavyTap:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)

        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)

        case .notification:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Animation Sequences

    public func performSequentialAnimation(
        _ steps: [AnimationStep],
        completion: (() -> Void)? = nil
    ) async {
        for (index, step) in steps.enumerated() {
            await withAnimation(createAnimation(step.type)) {
                step.action()
            }

            if step.delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(step.delay * 1_000_000_000))
            }

            if index == steps.count - 1 {
                completion?()
            }
        }
    }

    public struct AnimationStep {
        public let type: AnimationType
        public let action: () -> Void
        public let delay: TimeInterval

        public init(type: AnimationType, delay: TimeInterval = 0, action: @escaping () -> Void) {
            self.type = type
            self.delay = delay
            self.action = action
        }
    }

    // MARK: - Performance Monitoring

    public func measureAnimationPerformance<T>(
        _ type: AnimationType,
        operation: () async throws -> T
    ) async rethrows -> T {
        return try await FeatureFlagManager.shared.measureFeaturePerformance(.fluidAnimations) {
            try await operation()
        }
    }
}

// MARK: - Animation View Modifiers

public struct FluidAnimationModifier: ViewModifier {
    let type: FluidAnimationManager.AnimationType
    let isActive: Bool
    let microInteraction: FluidAnimationManager.MicroInteractionType?

    private let animationManager = FluidAnimationManager.shared

    public init(
        type: FluidAnimationManager.AnimationType,
        isActive: Bool = true,
        microInteraction: FluidAnimationManager.MicroInteractionType? = nil
    ) {
        self.type = type
        self.isActive = isActive
        self.microInteraction = microInteraction
    }

    public func body(content: Content) -> some View {
        content
            .animation(animationManager.createAnimation(type, isActive: isActive), value: isActive)
            .onChange(of: isActive) { _, newValue in
                if newValue, let microInteraction = microInteraction {
                    animationManager.triggerMicroInteraction(microInteraction)
                }
            }
    }
}

public struct PressableAnimationModifier: ViewModifier {
    @State private var isPressed = false

    let microInteraction: FluidAnimationManager.MicroInteractionType

    private let animationManager = FluidAnimationManager.shared

    public init(microInteraction: FluidAnimationManager.MicroInteractionType = .lightTap) {
        self.microInteraction = microInteraction
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(animationManager.createAnimation(.buttonPress), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
                if pressing {
                    animationManager.triggerMicroInteraction(microInteraction)
                }
            }, perform: {})
    }
}

public struct HoverAnimationModifier: ViewModifier {
    @State private var isHovered = false

    private let animationManager = FluidAnimationManager.shared

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(animationManager.createAnimation(.cardHover), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    animationManager.triggerMicroInteraction(.lightTap)
                }
            }
    }
}

// MARK: - Environment Integration

private struct FluidAnimationManagerKey: EnvironmentKey {
    static let defaultValue = FluidAnimationManager.shared
}

public extension EnvironmentValues {
    var fluidAnimations: FluidAnimationManager {
        get { self[FluidAnimationManagerKey.self] }
        set { self[FluidAnimationManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Applies fluid animation with optional micro-interaction
    func fluidAnimation(
        _ type: FluidAnimationManager.AnimationType,
        isActive: Bool = true,
        microInteraction: FluidAnimationManager.MicroInteractionType? = nil
    ) -> some View {
        modifier(FluidAnimationModifier(
            type: type,
            isActive: isActive,
            microInteraction: microInteraction
        ))
    }

    /// Applies pressable animation with haptic feedback
    func pressableAnimation(
        microInteraction: FluidAnimationManager.MicroInteractionType = .lightTap
    ) -> some View {
        modifier(PressableAnimationModifier(microInteraction: microInteraction))
    }

    /// Applies hover animation (for iPad/Mac)
    func hoverAnimation() -> some View {
        modifier(HoverAnimationModifier())
    }

    /// Combines pressable and hover animations
    func interactiveAnimation(
        microInteraction: FluidAnimationManager.MicroInteractionType = .lightTap
    ) -> some View {
        self
            .pressableAnimation(microInteraction: microInteraction)
            .hoverAnimation()
    }

    /// Card entrance animation
    func cardAppearAnimation() -> some View {
        fluidAnimation(.cardAppear, microInteraction: .lightTap)
    }

    /// Quick stat selection animation
    func quickStatAnimation(isSelected: Bool) -> some View {
        fluidAnimation(.quickStatSelect, isActive: isSelected, microInteraction: .selection)
    }

    /// Status change animation
    func statusChangeAnimation(isChanging: Bool) -> some View {
        fluidAnimation(.statusChange, isActive: isChanging, microInteraction: .mediumTap)
    }

    /// Data refresh animation
    func dataRefreshAnimation(isRefreshing: Bool) -> some View {
        fluidAnimation(.dataRefresh, isActive: isRefreshing)
    }

    /// Data transition animation (for chart/table updates on time range changes)
    func dataTransitionAnimation(isTransitioning: Bool) -> some View {
        fluidAnimation(.dataTransition, isActive: isTransitioning)
    }

    /// Filter apply animation
    func filterAnimation(isApplying: Bool) -> some View {
        fluidAnimation(.filterApply, isActive: isApplying)
    }

    /// Success state animation
    func successAnimation(isSuccess: Bool) -> some View {
        fluidAnimation(.successState, isActive: isSuccess, microInteraction: .success)
    }

    /// Error state animation
    func errorAnimation(isError: Bool) -> some View {
        fluidAnimation(.errorState, isActive: isError, microInteraction: .error)
    }
}

// MARK: - Animation Performance Utilities

public extension FluidAnimationManager {
    func optimizeForLowPowerMode() {
        let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        if isLowPowerModeEnabled {
            performanceMode = .minimal
            hapticFeedbackEnabled = false
            logger.info("🔋 Low power mode detected - optimizing animations")
        } else {
            setupPerformanceMode()
            hapticFeedbackEnabled = true
            logger.info("🔌 Normal power mode - restoring animation performance")
        }
    }

    func generatePerformanceReport() -> AnimationPerformanceReport {
        return AnimationPerformanceReport(
            performanceMode: performanceMode,
            isReducedMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            hapticFeedbackEnabled: hapticFeedbackEnabled,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            deviceMemory: ProcessInfo.processInfo.physicalMemory,
            iOSVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    struct AnimationPerformanceReport {
        public let performanceMode: AnimationPerformanceMode
        public let isReducedMotionEnabled: Bool
        public let hapticFeedbackEnabled: Bool
        public let isLowPowerModeEnabled: Bool
        public let deviceMemory: UInt64
        public let iOSVersion: Int

        public var summary: String {
            """
            Animation Performance Report
            ============================
            Performance Mode: \(performanceMode.displayName)
            Reduced Motion: \(isReducedMotionEnabled ? "Enabled" : "Disabled")
            Haptic Feedback: \(hapticFeedbackEnabled ? "Enabled" : "Disabled")
            Low Power Mode: \(isLowPowerModeEnabled ? "Enabled" : "Disabled")
            Device Memory: \(deviceMemory / 1_000_000)MB
            iOS Version: \(iOSVersion)

            Micro-interactions: \(performanceMode.enableMicroInteractions ? "Enabled" : "Disabled")
            Spring Response: \(String(format: "%.2f", performanceMode.springResponse))s
            Damping Fraction: \(String(format: "%.2f", performanceMode.dampingFraction))
            """
        }
    }
}