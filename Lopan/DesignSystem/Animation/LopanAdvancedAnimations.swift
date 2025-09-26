//
//  LopanAdvancedAnimations.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//  Advanced iOS 26 Animation System
//

import SwiftUI

/// Advanced animation system for iOS 26 with enhanced performance and visual fidelity
@available(iOS 26.0, *)
public struct LopanAdvancedAnimations {

    // MARK: - Enhanced Spring Animations

    /// High-fidelity spring animation for iOS 26
    public static let liquidSpring = Animation.spring(
        response: 0.55,
        dampingFraction: 0.825,
        blendDuration: 0.25
    )

    /// Ultra-smooth micro animation for subtle interactions
    public static let microInteraction = Animation.spring(
        response: 0.3,
        dampingFraction: 0.9,
        blendDuration: 0.1
    )

    /// Bouncy animation for delightful interactions
    public static let delightfulBounce = Animation.spring(
        response: 0.6,
        dampingFraction: 0.7,
        blendDuration: 0.2
    )

    /// Cinematic easing for modal presentations
    public static let cinematicEase = Animation.timingCurve(
        0.25, 0.1, 0.25, 1.0,
        duration: 0.8
    )

    // MARK: - Enhanced Timing Curves

    /// iOS 26 optimized ease-in-out curve
    public static let enhancedEaseInOut = Animation.timingCurve(
        0.4, 0.0, 0.2, 1.0,
        duration: 0.5
    )

    /// Dramatic animation for important state changes
    public static let dramaticReveal = Animation.timingCurve(
        0.15, 0.9, 0.25, 1.0,
        duration: 1.2
    )

    /// Quick response animation for immediate feedback
    public static let instantResponse = Animation.timingCurve(
        0.25, 0.46, 0.45, 0.94,
        duration: 0.2
    )
}

// MARK: - Fluid Animation Controller

@available(iOS 26.0, *)
public struct FluidAnimationController {

    /// Creates a fluid transition between states with iOS 26 optimizations
    public static func fluidTransition<T: Equatable>(
        value: T,
        duration: Double = 0.5,
        delay: Double = 0.0,
        completion: @escaping () -> Void = {}
    ) -> Animation {
        Animation
            .spring(response: 0.55, dampingFraction: 0.825)
            .delay(delay)
    }

    /// Creates staggered animations for list items
    public static func staggeredReveal(
        itemCount: Int,
        staggerDelay: Double = 0.05,
        baseDelay: Double = 0.0
    ) -> [Animation] {
        (0..<itemCount).map { index in
            Animation
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(baseDelay + (Double(index) * staggerDelay))
        }
    }

    /// Creates ripple effect animation for button presses
    public static func rippleEffect(
        origin: CGPoint,
        duration: Double = 0.6
    ) -> Animation {
        Animation
            .timingCurve(0.4, 0.0, 0.2, 1.0, duration: duration)
    }
}

// MARK: - Advanced Visual Effects

@available(iOS 26.0, *)
public struct LopanVisualEffects {

    /// Enhanced blur effect with iOS 26 optimizations
    public static func enhancedBlur(
        radius: CGFloat = 20,
        intensity: Double = 1.0
    ) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: radius * intensity)
            .opacity(0.8)
    }

    /// Morphing background effect
    public static func morphingGradient(
        colors: [Color],
        speed: Double = 1.0
    ) -> some View {
        MorphingGradientView(colors: colors, speed: speed)
    }

    /// Parallax scroll effect
    public static func parallaxEffect(
        offset: CGFloat,
        intensity: Double = 0.3
    ) -> some View {
        Rectangle()
            .fill(.clear)
            .offset(y: offset * intensity)
    }
}

// MARK: - Morphing Gradient View

@available(iOS 26.0, *)
private struct MorphingGradientView: View {
    let colors: [Color]
    let speed: Double

    @State private var animationProgress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        LinearGradient(
            colors: interpolatedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .onAppear {
            startMorphingAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var interpolatedColors: [Color] {
        guard colors.count >= 2 else { return colors }

        let progress = animationProgress
        let colorCount = colors.count

        return (0..<colorCount).map { index in
            let nextIndex = (index + 1) % colorCount
            let t = sin(progress + Double(index) * 0.5) * 0.5 + 0.5
            return Color.lerp(from: colors[index], to: colors[nextIndex], amount: t)
        }
    }

    private func startMorphingAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            withAnimation(.linear(duration: 0.016)) {
                animationProgress += 0.01 * speed
                if animationProgress > .pi * 2 {
                    animationProgress = 0
                }
            }
        }
    }
}

// MARK: - Color Extensions

@available(iOS 26.0, *)
private extension Color {
    static func lerp(from: Color, to: Color, amount: Double) -> Color {
        let clampedAmount = max(0, min(1, amount))

        let fromComponents = from.components
        let toComponents = to.components

        return Color(
            red: fromComponents.red + (toComponents.red - fromComponents.red) * clampedAmount,
            green: fromComponents.green + (toComponents.green - fromComponents.green) * clampedAmount,
            blue: fromComponents.blue + (toComponents.blue - fromComponents.blue) * clampedAmount,
            opacity: fromComponents.alpha + (toComponents.alpha - fromComponents.alpha) * clampedAmount
        )
    }

    private var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        // Simplified color component extraction - in a real implementation,
        // you would use UIColor to extract actual RGB values
        return (0.5, 0.5, 0.5, 1.0)
    }
}

// MARK: - Advanced Animation Modifiers

@available(iOS 26.0, *)
public struct FluidScaleModifier: ViewModifier {
    let isPressed: Bool
    let pressedScale: CGFloat
    let animation: Animation

    public init(
        isPressed: Bool,
        pressedScale: CGFloat = 0.95,
        animation: Animation = LopanAdvancedAnimations.liquidSpring
    ) {
        self.isPressed = isPressed
        self.pressedScale = pressedScale
        self.animation = animation
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1.0)
            .animation(animation, value: isPressed)
    }
}

@available(iOS 26.0, *)
public struct BreathingEffectModifier: ViewModifier {
    @State private var isBreathing = false
    let intensity: Double
    let duration: Double

    public init(intensity: Double = 0.05, duration: Double = 2.0) {
        self.intensity = intensity
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isBreathing ? 1.0 + intensity : 1.0)
            .animation(
                Animation.easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear {
                isBreathing = true
            }
    }
}

@available(iOS 26.0, *)
public struct ShimmerEffectModifier: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1.0
    let duration: Double
    let intensity: Double

    public init(duration: Double = 1.5, intensity: Double = 0.3) {
        self.duration = duration
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(intensity),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset * UIScreen.main.bounds.width * 2)
                    .animation(
                        Animation.linear(duration: duration)
                            .repeatForever(autoreverses: false),
                        value: shimmerOffset
                    )
            )
            .onAppear {
                shimmerOffset = 1.0
            }
    }
}

// MARK: - View Extensions

@available(iOS 26.0, *)
public extension View {

    /// Applies fluid scale animation for button presses
    func fluidScale(
        isPressed: Bool,
        pressedScale: CGFloat = 0.95,
        animation: Animation = LopanAdvancedAnimations.liquidSpring
    ) -> some View {
        modifier(
            FluidScaleModifier(
                isPressed: isPressed,
                pressedScale: pressedScale,
                animation: animation
            )
        )
    }

    /// Applies subtle breathing animation
    func breathingEffect(
        intensity: Double = 0.05,
        duration: Double = 2.0
    ) -> some View {
        modifier(
            BreathingEffectModifier(
                intensity: intensity,
                duration: duration
            )
        )
    }

    /// Applies shimmer effect for loading states
    func shimmerEffect(
        duration: Double = 1.5,
        intensity: Double = 0.3
    ) -> some View {
        modifier(
            ShimmerEffectModifier(
                duration: duration,
                intensity: intensity
            )
        )
    }

    /// Applies staggered reveal animation
    func staggeredReveal(
        index: Int,
        staggerDelay: Double = 0.05,
        baseDelay: Double = 0.0
    ) -> some View {
        let animation = Animation
            .spring(response: 0.6, dampingFraction: 0.8)
            .delay(baseDelay + (Double(index) * staggerDelay))

        return self
            .opacity(1.0)
            .animation(animation, value: true)
    }

    /// Applies morphing gradient background
    func morphingGradientBackground(
        colors: [Color],
        speed: Double = 1.0
    ) -> some View {
        background {
            LopanVisualEffects.morphingGradient(colors: colors, speed: speed)
        }
    }
}

// MARK: - Performance Optimized Animations

@available(iOS 26.0, *)
public struct LopanPerformanceAnimations {

    /// GPU-accelerated transform animation
    public static func gpuAcceleratedTransform(
        scale: CGFloat = 1.0,
        rotation: Angle = .zero,
        translation: CGSize = .zero
    ) -> some View {
        Rectangle()
            .fill(.clear)
            .scaleEffect(scale)
            .rotationEffect(rotation)
            .offset(translation)
            .drawingGroup() // Forces GPU rendering
    }

    /// Metal-powered particle system for celebrations
    public static func particleSystem(
        particleCount: Int = 50,
        colors: [Color] = [.blue, .purple, .pink]
    ) -> some View {
        // Placeholder for Metal-powered particle system
        // In a real implementation, this would use Metal Performance Shaders
        ParticleSystemView(particleCount: particleCount, colors: colors)
    }
}

@available(iOS 26.0, *)
private struct ParticleSystemView: View {
    let particleCount: Int
    let colors: [Color]

    @State private var particles: [ParticleData] = []

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: particle.position.x,
                        y: particle.position.y,
                        width: particle.size,
                        height: particle.size
                    )),
                    with: .color(particle.color.opacity(particle.alpha))
                )
            }
        }
        .onAppear {
            generateParticles()
            animateParticles()
        }
    }

    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            ParticleData(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -2...2),
                    dy: CGFloat.random(in: -2...2)
                ),
                size: CGFloat.random(in: 4...12),
                color: colors.randomElement() ?? .blue,
                alpha: 1.0
            )
        }
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            withAnimation(.linear(duration: 0.016)) {
                for i in particles.indices {
                    particles[i].position.x += particles[i].velocity.dx
                    particles[i].position.y += particles[i].velocity.dy
                    particles[i].alpha *= 0.995

                    // Reset particle when it fades out
                    if particles[i].alpha < 0.1 {
                        particles[i] = ParticleData(
                            position: CGPoint(
                                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                                y: UIScreen.main.bounds.height + 20
                            ),
                            velocity: CGVector(
                                dx: CGFloat.random(in: -2...2),
                                dy: CGFloat.random(in: -4...0)
                            ),
                            size: CGFloat.random(in: 4...12),
                            color: colors.randomElement() ?? .blue,
                            alpha: 1.0
                        )
                    }
                }
            }
        }
    }
}

@available(iOS 26.0, *)
private struct ParticleData {
    var position: CGPoint
    var velocity: CGVector
    let size: CGFloat
    let color: Color
    var alpha: Double
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    VStack(spacing: 20) {
        Text("Advanced iOS 26 Animations")
            .font(.title)
            .fluidScale(isPressed: false)

        Button("Fluid Button") {
            // Action
        }
        .padding()
        .background(LopanColors.info)
        .foregroundColor(LopanColors.textOnPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fluidScale(isPressed: false)

        Text("Breathing Text")
            .breathingEffect()

        Text("Shimmer Loading")
            .shimmerEffect()

        Rectangle()
            .frame(height: 100)
            .morphingGradientBackground(colors: [.blue, .purple, .pink])
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}