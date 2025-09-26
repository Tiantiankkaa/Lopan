//
//  LopanAnimation.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//  Updated for iOS 26 compatibility on 2025/9/23.
//

import SwiftUI
import UIKit

/// Modern animation and motion design system for Lopan production management app
/// Follows iOS 26 motion guidelines with accessibility-first design and semantic patterns
public struct LopanAnimation {
    
    // MARK: - Animation Durations (iOS 26 Optimized)

    /// Instant feedback for immediate responses
    public static let instant: TimeInterval = 0.0

    /// Fast animations for micro-interactions (button taps, selections)
    public static let fast: TimeInterval = 0.12

    /// Normal speed for standard UI transitions
    public static let normal: TimeInterval = 0.25

    /// Slow animations for complex state changes
    public static let slow: TimeInterval = 0.35

    /// Extended duration for loading states and complex transitions
    public static let extended: TimeInterval = 0.5

    /// Reduced duration when accessibility reduce motion is enabled
    public static let accessibilityReduced: TimeInterval = 0.08
    
    // MARK: - Easing Curves (iOS 26 Enhanced)

    /// Smooth ease out for button interactions
    public static let easeOut = Animation.easeOut(duration: accessibilityDuration(normal))

    /// Ease in for element appearances
    public static let easeIn = Animation.easeIn(duration: accessibilityDuration(normal))

    /// Balanced ease in-out for general UI transitions
    public static let easeInOut = Animation.easeInOut(duration: accessibilityDuration(normal))

    /// Natural spring animation with optimized parameters
    public static let spring = Animation.spring(
        response: accessibilitySpringResponse(0.4),
        dampingFraction: 0.85,
        blendDuration: 0
    )

    /// Bouncy spring for success states and celebrations
    public static let bouncy = Animation.spring(
        response: accessibilitySpringResponse(0.3),
        dampingFraction: 0.65,
        blendDuration: 0
    )

    /// Gentle spring for subtle interactions
    public static let gentle = Animation.spring(
        response: accessibilitySpringResponse(0.5),
        dampingFraction: 0.9,
        blendDuration: 0
    )
    
    // MARK: - Semantic UI Animations

    /// Button press and release animation
    public static let buttonTap = Animation.easeOut(duration: accessibilityDuration(fast))

    /// Card hover and focus states
    public static let cardHover = Animation.easeInOut(duration: accessibilityDuration(fast))

    /// Modal and sheet presentation
    public static let modalPresent = Animation.easeOut(duration: accessibilityDuration(normal))

    /// Modal and sheet dismissal
    public static let modalDismiss = Animation.easeIn(duration: accessibilityDuration(fast))

    /// List item and content appearance
    public static let listItemAppear = Animation.easeOut(duration: accessibilityDuration(normal))
        .delay(UIAccessibility.isReduceMotionEnabled ? 0 : 0.05)

    /// Loading states and progress indicators
    public static let loading = Animation.easeInOut(duration: accessibilityDuration(extended))
        .repeatForever(autoreverses: true)

    /// Success feedback and positive states
    public static let success = UIAccessibility.isReduceMotionEnabled ? easeOut : bouncy

    /// Error feedback and validation failures
    public static let error = Animation.easeOut(duration: accessibilityDuration(fast))

    /// Form field focus and validation
    public static let fieldFocus = gentle
    
    // MARK: - Navigation Animations

    /// Page-to-page navigation transitions
    public static let pageTransition = Animation.easeInOut(duration: accessibilityDuration(normal))

    /// Tab switching animation
    public static let tabTransition = Animation.easeOut(duration: accessibilityDuration(fast))

    /// Navigation stack push/pop transitions
    public static let navigationTransition = Animation.easeInOut(duration: accessibilityDuration(normal))

    /// Back navigation specific timing
    public static let backNavigation = Animation.easeIn(duration: accessibilityDuration(fast))

    /// Deep link navigation for direct jumps
    public static let deepLinkTransition = Animation.easeInOut(duration: accessibilityDuration(slow))
    
    // MARK: - Micro-interactions

    /// Ripple effect for touch feedback
    public static let ripple = Animation.easeOut(duration: accessibilityDuration(0.6))

    /// Pulse animation for attention-drawing elements
    public static let pulse = Animation.easeInOut(duration: accessibilityDuration(1.0))
        .repeatForever(autoreverses: true)

    /// Shake animation for error validation
    public static let shake = UIAccessibility.isReduceMotionEnabled
        ? Animation.easeOut(duration: accessibilityReduced)
        : Animation.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)

    /// Bounce animation for success acknowledgment
    public static let bounce = UIAccessibility.isReduceMotionEnabled
        ? success
        : Animation.spring(response: 0.3, dampingFraction: 0.4)

    /// Wiggle animation for interactive hints
    public static let wiggle = UIAccessibility.isReduceMotionEnabled
        ? Animation.easeOut(duration: accessibilityReduced)
        : Animation.easeInOut(duration: 0.1).repeatCount(2, autoreverses: true)

    /// Breath animation for loading states
    public static let breathe = Animation.easeInOut(duration: accessibilityDuration(2.0))
        .repeatForever(autoreverses: true)
    
    // MARK: - Data and Content Animations

    /// Content refresh and reload
    public static let contentRefresh = Animation.easeInOut(duration: accessibilityDuration(normal))

    /// Search results appearance
    public static let searchResults = Animation.easeOut(duration: accessibilityDuration(normal))
        .delay(UIAccessibility.isReduceMotionEnabled ? 0 : 0.1)

    /// Filter application
    public static let filterApply = Animation.easeInOut(duration: accessibilityDuration(fast))

    /// Batch operation feedback
    public static let batchOperation = Animation.easeOut(duration: accessibilityDuration(slow))

    /// Status change animations
    public static let statusChange = gentle

    // MARK: - Accessibility Support

    /// Determines appropriate duration based on accessibility settings
    private static func accessibilityDuration(_ baseDuration: TimeInterval) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? min(baseDuration * 0.3, accessibilityReduced) : baseDuration
    }

    /// Adjusts spring response for accessibility
    private static func accessibilitySpringResponse(_ baseResponse: Double) -> Double {
        UIAccessibility.isReduceMotionEnabled ? min(baseResponse * 0.5, 0.2) : baseResponse
    }

    /// Checks if motion-based animations should be disabled
    public static var isMotionEnabled: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    /// Provides safe animation that respects accessibility preferences
    public static func safeAnimation(_ animation: Animation) -> Animation {
        UIAccessibility.isReduceMotionEnabled ? Animation.easeOut(duration: accessibilityReduced) : animation
    }
}

// MARK: - Modern Animation Extensions

extension View {

    // MARK: - Core Animation Modifiers

    /// Applies button tap animation with proper state tracking
    public func lopanButtonAnimation<T: Equatable>(_ value: T) -> some View {
        self.animation(LopanAnimation.buttonTap, value: value)
    }

    /// Applies card hover animation with state tracking
    public func lopanCardAnimation<T: Equatable>(_ value: T) -> some View {
        self.animation(LopanAnimation.cardHover, value: value)
    }

    /// Applies spring animation with accessibility support
    public func lopanSpringAnimation<T: Equatable>(_ value: T) -> some View {
        self.animation(LopanAnimation.spring, value: value)
    }

    /// Applies safe loading animation that respects accessibility
    public func lopanLoadingAnimation<T: Equatable>(_ value: T) -> some View {
        self.animation(LopanAnimation.loading, value: value)
    }

    /// Applies success animation with accessibility fallback
    public func lopanSuccessAnimation<T: Equatable>(_ value: T) -> some View {
        self.animation(LopanAnimation.success, value: value)
    }

    /// Applies error animation with accessibility considerations
    public func lopanErrorAnimation<T: Equatable>(_ value: T) -> some View {
        self.animation(LopanAnimation.error, value: value)
    }

    // MARK: - Advanced Animation Modifiers

    /// Applies contextual animation based on interaction type
    public func lopanContextualAnimation<T: Equatable>(
        _ type: LopanAnimationType,
        value: T
    ) -> some View {
        self.animation(type.animation, value: value)
    }

    /// Applies safe animation that automatically respects accessibility
    public func lopanSafeAnimation<T: Equatable>(
        _ animation: Animation,
        value: T
    ) -> some View {
        self.animation(LopanAnimation.safeAnimation(animation), value: value)
    }

    /// Conditionally applies animation based on motion preferences
    public func lopanConditionalAnimation<T: Equatable>(
        _ animation: Animation,
        value: T,
        fallback: Animation? = nil
    ) -> some View {
        self.animation(
            LopanAnimation.isMotionEnabled ? animation : (fallback ?? LopanAnimation.easeOut),
            value: value
        )
    }

    // MARK: - Specialized Animation Effects

    /// Adds pulse effect for attention-drawing elements
    public func lopanPulseEffect(isActive: Bool = true) -> some View {
        self.scaleEffect(isActive && LopanAnimation.isMotionEnabled ? 1.05 : 1.0)
            .animation(LopanAnimation.pulse, value: isActive)
    }

    /// Adds shake effect for error validation
    public func lopanShakeEffect(trigger: Bool) -> some View {
        self.offset(x: trigger && LopanAnimation.isMotionEnabled ? 2 : 0)
            .animation(LopanAnimation.shake, value: trigger)
    }

    /// Adds bounce effect for success states
    public func lopanBounceEffect(trigger: Bool) -> some View {
        self.scaleEffect(trigger && LopanAnimation.isMotionEnabled ? 1.1 : 1.0)
            .animation(LopanAnimation.bounce, value: trigger)
    }

    /// Adds breathe effect for loading states
    public func lopanBreatheEffect(isActive: Bool) -> some View {
        self.opacity(isActive && LopanAnimation.isMotionEnabled ? 0.6 : 1.0)
            .animation(LopanAnimation.breathe, value: isActive)
    }
}

// MARK: - Animation Types

/// Semantic animation types for different UI contexts
public enum LopanAnimationType {
    case buttonTap
    case cardHover
    case modalPresent
    case modalDismiss
    case listAppear
    case navigation
    case success
    case error
    case loading
    case refresh
    case search
    case filter
    case batchOperation
    case statusChange

    var animation: Animation {
        switch self {
        case .buttonTap:
            return LopanAnimation.buttonTap
        case .cardHover:
            return LopanAnimation.cardHover
        case .modalPresent:
            return LopanAnimation.modalPresent
        case .modalDismiss:
            return LopanAnimation.modalDismiss
        case .listAppear:
            return LopanAnimation.listItemAppear
        case .navigation:
            return LopanAnimation.navigationTransition
        case .success:
            return LopanAnimation.success
        case .error:
            return LopanAnimation.error
        case .loading:
            return LopanAnimation.loading
        case .refresh:
            return LopanAnimation.contentRefresh
        case .search:
            return LopanAnimation.searchResults
        case .filter:
            return LopanAnimation.filterApply
        case .batchOperation:
            return LopanAnimation.batchOperation
        case .statusChange:
            return LopanAnimation.statusChange
        }
    }
}

/// @deprecated Use LopanHapticEngine instead
/// Compatibility wrapper for legacy haptic feedback code
@available(*, deprecated, message: "Use LopanHapticEngine.shared instead")
public struct HapticFeedback {
    public static func light() { LopanHapticEngine.shared.light() }
    public static func medium() { LopanHapticEngine.shared.medium() }
    public static func heavy() { LopanHapticEngine.shared.heavy() }
    public static func selection() { LopanHapticEngine.shared.selection() }
    public static func success() { LopanHapticEngine.shared.success() }
    public static func warning() { LopanHapticEngine.shared.warning() }
    public static func error() { LopanHapticEngine.shared.error() }
}

// MARK: - Modern Transition Extensions

extension AnyTransition {

    /// Slide transition for cards with accessibility support
    public static var lopanSlideCard: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Modal presentation transition
    public static var lopanModalPresentation: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .move(edge: .bottom).combined(with: .opacity)
    }

    /// Scale and fade transition with accessibility fallback
    public static var lopanScaleAndFade: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Glass morphism transition
    public static var lopanGlassTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: 1.05))
    }

    /// Navigation stack transition
    public static var lopanNavigationTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// List item appearance transition
    public static var lopanListItemTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .move(edge: .top).combined(with: .opacity)
    }

    /// Search results transition
    public static var lopanSearchResultsTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .scale(scale: 0.95).combined(with: .opacity)
    }

    /// Status change transition
    public static var lopanStatusTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}

// MARK: - Performance Monitoring

#if DEBUG
extension LopanAnimation {
    /// Monitor animation performance in debug builds
    public static func enablePerformanceMonitoring() {
        print("🎬 LopanAnimation performance monitoring enabled")
        print("📱 Motion enabled: \(isMotionEnabled)")
        print("⏱️ Base durations: fast=\(fast)s, normal=\(normal)s, slow=\(slow)s")
        print("♿ Accessibility reduced duration: \(accessibilityReduced)s")
    }
}
#endif

// MARK: - SwiftUI Integration Helpers

extension View {
    /// Applies animation with automatic haptic feedback integration
    public func lopanAnimatedAction<T: Equatable>(
        _ animationType: LopanAnimationType,
        hapticAction: LopanHapticEngine.UIAction? = nil,
        value: T
    ) -> some View {
        self.animation(animationType.animation, value: value)
            .onChange(of: value) { _, _ in
                if let hapticAction = hapticAction {
                    LopanHapticEngine.shared.perform(hapticAction)
                }
            }
    }
}
