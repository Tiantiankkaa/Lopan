//
//  LopanAnimation.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Animation and motion design system for Lopan production management app
/// Following iOS 2025 trends for purposeful motion and micro-interactions
struct LopanAnimation {
    
    // MARK: - Animation Durations
    static let instant: TimeInterval = 0.0
    static let fast: TimeInterval = 0.15
    static let normal: TimeInterval = 0.25
    static let slow: TimeInterval = 0.35
    static let slower: TimeInterval = 0.5
    
    // MARK: - Easing Curves
    static let easeOut = Animation.easeOut(duration: normal)
    static let easeIn = Animation.easeIn(duration: normal)
    static let easeInOut = Animation.easeInOut(duration: normal)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
    
    // MARK: - Semantic Animations
    static let buttonTap = Animation.easeOut(duration: fast)
    static let cardHover = Animation.easeInOut(duration: fast)
    static let modalPresent = Animation.easeOut(duration: normal)
    static let listItemAppear = Animation.easeOut(duration: normal).delay(0.1)
    static let loading = Animation.easeInOut(duration: slow).repeatForever(autoreverses: true)
    static let success = spring
    static let error = Animation.easeOut(duration: fast)
    
    // MARK: - Page Transitions
    static let pageTransition = Animation.easeInOut(duration: normal)
    static let tabTransition = Animation.easeOut(duration: fast)
    static let navigationTransition = Animation.easeInOut(duration: normal)
    
    // MARK: - Micro-interactions
    static let ripple = Animation.easeOut(duration: 0.6)
    static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    static let shake = Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)
    
    // MARK: - Interactive Feedback
    static let hapticLight = UIImpactFeedbackGenerator.FeedbackStyle.light
    static let hapticMedium = UIImpactFeedbackGenerator.FeedbackStyle.medium
    static let hapticHeavy = UIImpactFeedbackGenerator.FeedbackStyle.heavy
}

// MARK: - Animation View Extensions
extension View {
    /// Applies button tap animation
    func buttonTapAnimation() -> some View {
        self.animation(LopanAnimation.buttonTap, value: UUID())
    }
    
    /// Applies card hover animation
    func cardHoverAnimation() -> some View {
        self.animation(LopanAnimation.cardHover, value: UUID())
    }
    
    /// Applies spring animation
    func springAnimation() -> some View {
        self.animation(LopanAnimation.spring, value: UUID())
    }
    
    /// Applies loading animation
    func loadingAnimation() -> some View {
        self.animation(LopanAnimation.loading, value: UUID())
    }
    
    /// Applies success animation
    func successAnimation() -> some View {
        self.animation(LopanAnimation.success, value: UUID())
    }
    
    /// Applies error animation
    func errorAnimation() -> some View {
        self.animation(LopanAnimation.error, value: UUID())
    }
    
    /// Adds pulse animation
    func pulseAnimation() -> some View {
        self.animation(LopanAnimation.pulse, value: UUID())
    }
    
    /// Adds shake animation for error states
    func shakeAnimation() -> some View {
        self.animation(LopanAnimation.shake, value: UUID())
    }
}

// MARK: - Haptic Feedback Helper
struct HapticFeedback {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Transition Extensions
extension AnyTransition {
    /// Slide transition for cards
    static var slideCard: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// Modal presentation transition
    static var modalPresentation: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }
    
    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }
    
    /// Blur transition for glass morphism
    static var blurTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 1.1))
    }
}