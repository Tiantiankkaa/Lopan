//
//  ModernVisualEffects.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/05.
//  Modern visual effects composer for enhanced UI experiences
//

import SwiftUI
import os.log

// MARK: - Visual Enhancement Level

public enum VisualEnhancementLevel: CaseIterable {
    case minimal    // Basic colors, simple animations
    case standard   // Gradients, basic glass effects
    case premium    // Full effects, complex animations
    case adaptive   // Dynamic based on device capabilities

    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .standard: return "Standard"
        case .premium: return "Premium"
        case .adaptive: return "Adaptive"
        }
    }
}

// MARK: - Elevation System

public enum ElevationLevel: CGFloat, CaseIterable {
    case base = 0
    case raised = 1
    case elevated = 2
    case floating = 3
    case modal = 4

    var shadowRadius: CGFloat {
        switch self {
        case .base: return 0
        case .raised: return 4
        case .elevated: return 8
        case .floating: return 16
        case .modal: return 24
        }
    }

    var shadowOpacity: CGFloat {
        switch self {
        case .base: return 0
        case .raised: return 0.08
        case .elevated: return 0.12
        case .floating: return 0.16
        case .modal: return 0.20
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .base: return 0
        case .raised: return 2
        case .elevated: return 4
        case .floating: return 8
        case .modal: return 12
        }
    }

    var shadowColor: Color {
        LopanColors.textPrimary.opacity(shadowOpacity)
    }
}

// MARK: - Visual Effects Composer

@MainActor
class VisualEffectsComposer: ObservableObject {
    static let shared = VisualEffectsComposer()

    private let logger = Logger(subsystem: "com.lopan.visualeffects", category: "Composer")

    @Published var enhancementLevel: VisualEnhancementLevel = .adaptive
    @Published var isReducedMotionEnabled = false
    @Published var currentTimeBasedTheme: TimeBasedTheme = .auto

    private init() {
        // Detect device capabilities and user preferences
        detectCapabilities()
        setupNotifications()
    }

    // MARK: - Time-Based Theming

    enum TimeBasedTheme: CaseIterable {
        case auto, morning, afternoon, evening, night

        var backgroundGradient: LinearGradient {
            switch self {
            case .auto:
                return currentTimeGradient()
            case .morning:
                return LopanColors.Aurora.subtle
            case .afternoon:
                return LopanColors.Aurora.gradient1
            case .evening:
                return LopanColors.Aurora.gradient2
            case .night:
                return LinearGradient(
                    colors: [Color.black, Color(UIColor.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }

        private func currentTimeGradient() -> LinearGradient {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 6..<12: return LopanColors.Aurora.subtle        // Morning
            case 12..<17: return LopanColors.Aurora.gradient1    // Afternoon
            case 17..<20: return LopanColors.Aurora.gradient2    // Evening
            default: return LinearGradient(                      // Night
                colors: [Color.black, Color(UIColor.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            }
        }
    }

    // MARK: - Gradient Factories

    func cardGradient(for style: CardStyle) -> LinearGradient {
        switch style {
        case .primary:
            return LopanColors.Gradients.primaryCard
        case .success:
            return LopanColors.Gradients.successCard
        case .warning:
            return LopanColors.Gradients.warningCard
        case .error:
            return LopanColors.Gradients.errorCard
        case .neutral:
            return LinearGradient(
                colors: [LopanColors.secondary, LopanColors.textSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func jewelTone(for style: CardStyle) -> Color {
        switch style {
        case .primary: return LopanColors.Jewel.sapphire
        case .success: return LopanColors.Jewel.emerald
        case .warning: return LopanColors.Jewel.citrine
        case .error: return LopanColors.Jewel.ruby
        case .neutral: return LopanColors.secondary
        }
    }

    func neonAccent(for style: CardStyle) -> Color {
        switch style {
        case .primary: return LopanColors.Neon.blue
        case .success: return LopanColors.Neon.green
        case .warning: return LopanColors.Neon.pink
        case .error: return LopanColors.Neon.pink
        case .neutral: return LopanColors.Neon.purple
        }
    }

    // MARK: - Glass Effects

    func glassBackground(intensity: GlassIntensity = .medium) -> some View {
        ZStack {
            // Base material
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(LopanColors.Gradients.glassOverlay)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(intensity.overlayOpacity),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }

    enum GlassIntensity {
        case subtle, medium, strong

        var overlayOpacity: Double {
            switch self {
            case .subtle: return 0.05
            case .medium: return 0.15
            case .strong: return 0.25
            }
        }
    }

    // MARK: - Neumorphic Effects

    func neumorphicShadow(isPressed: Bool = false) -> some View {
        let baseColor = Color(UIColor.secondarySystemBackground)

        return Rectangle()
            .fill(baseColor)
            .shadow(
                color: .black.opacity(isPressed ? 0.2 : 0.15),
                radius: isPressed ? 5 : 10,
                x: isPressed ? 2 : 5,
                y: isPressed ? 2 : 5
            )
            .shadow(
                color: .white.opacity(isPressed ? 0.5 : 0.7),
                radius: isPressed ? 5 : 10,
                x: isPressed ? -2 : -5,
                y: isPressed ? -2 : -5
            )
    }

    // MARK: - Private Methods

    private func detectCapabilities() {
        // Detect device performance tier
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory

        if physicalMemory > 8_000_000_000 { // 8GB+
            enhancementLevel = .premium
        } else if physicalMemory > 4_000_000_000 { // 4GB+
            enhancementLevel = .standard
        } else {
            enhancementLevel = .minimal
        }

        logger.info("Visual enhancement level set to: \(self.enhancementLevel.displayName)")
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
        }

        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
}

// MARK: - Card Style Enum

public enum CardStyle: CaseIterable {
    case primary, success, warning, error, neutral
}

// MARK: - View Modifiers

extension View {
    /// Apply elevation shadow with modern depth system
    func elevationShadow(_ level: ElevationLevel) -> some View {
        self.shadow(
            color: level.shadowColor,
            radius: level.shadowRadius,
            x: 0,
            y: level.shadowY
        )
    }

    /// Apply glassmorphic background
    func glassMorphic(intensity: VisualEffectsComposer.GlassIntensity = .medium) -> some View {
        self.background(
            VisualEffectsComposer.shared.glassBackground(intensity: intensity)
        )
    }

    /// Apply neumorphic shadow effect
    func neumorphic(isPressed: Bool = false) -> some View {
        self.background(
            VisualEffectsComposer.shared.neumorphicShadow(isPressed: isPressed)
        )
    }

    /// Apply modern card styling with elevation and gradients
    func modernCard(
        style: CardStyle = .neutral,
        elevation: ElevationLevel = .elevated,
        cornerRadius: CGFloat = 12
    ) -> some View {
        let composer = VisualEffectsComposer.shared

        return self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(UIColor.secondarySystemBackground))

                    if composer.enhancementLevel != .minimal {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(composer.cardGradient(for: style).opacity(0.1))
                    }

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                }
            )
            .elevationShadow(elevation)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        composer.jewelTone(for: style).opacity(0.3),
                        lineWidth: 1
                    )
            )
    }

    /// Apply micro-interaction animations
    func microInteraction(scale: CGFloat = 0.95) -> some View {
        self.scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: false)
    }
}

// MARK: - Animated Number Text

struct AnimatedNumberText: View {
    let value: String
    @State private var animatedValue: Double = 0

    var body: some View {
        Text(String(format: "%.0f", animatedValue))
            .onAppear {
                if let doubleValue = Double(value) {
                    withAnimation(.easeOut(duration: 1.2)) {
                        animatedValue = doubleValue
                    }
                }
            }
            .onChange(of: value) { _, newValue in
                if let doubleValue = Double(newValue) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        animatedValue = doubleValue
                    }
                }
            }
    }
}

// MARK: - Aurora Background View

struct AuroraBackgroundView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient
            LopanColors.Aurora.gradient1
                .blur(radius: 50)
                .offset(x: sin(phase) * 100, y: cos(phase * 0.8) * 50)

            LopanColors.Aurora.gradient2
                .blur(radius: 40)
                .offset(x: cos(phase * 1.2) * 80, y: sin(phase * 0.6) * 60)
        }
        .opacity(0.3)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}