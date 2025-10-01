//
//  EnhancedCardInteractionModifier.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/28.
//

import SwiftUI

/// Enhanced card interaction modifier that provides sophisticated micro-interactions
/// while maintaining Apple HIG compliance and accessibility standards
struct EnhancedCardInteractionModifier: ViewModifier {

    // MARK: - Configuration

    struct Configuration {
        let hoverScale: CGFloat
        let pressScale: CGFloat
        let shadowRadius: CGFloat
        let shadowOpacity: Double
        let animationDuration: Double
        let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
        let enableHaptics: Bool
        let enableAccessibilityAnnouncements: Bool

        static let `default` = Configuration(
            hoverScale: 1.02,
            pressScale: 0.98,
            shadowRadius: 8,
            shadowOpacity: 0.15,
            animationDuration: 0.2,
            hapticStyle: .light,
            enableHaptics: true,
            enableAccessibilityAnnouncements: true
        )

        static let subtle = Configuration(
            hoverScale: 1.01,
            pressScale: 0.99,
            shadowRadius: 4,
            shadowOpacity: 0.1,
            animationDuration: 0.15,
            hapticStyle: .light,
            enableHaptics: false,
            enableAccessibilityAnnouncements: false
        )

        static let prominent = Configuration(
            hoverScale: 1.05,
            pressScale: 0.95,
            shadowRadius: 12,
            shadowOpacity: 0.25,
            animationDuration: 0.25,
            hapticStyle: .medium,
            enableHaptics: true,
            enableAccessibilityAnnouncements: true
        )
    }

    // MARK: - Properties

    let configuration: Configuration
    let onTap: (() -> Void)?

    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hapticGenerator = UIImpactFeedbackGenerator()

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .scaleEffect(calculateScale())
            .shadow(
                color: LopanColors.shadow.opacity(calculateShadowOpacity()),
                radius: calculateShadowRadius(),
                x: 0,
                y: calculateShadowOffset()
            )
            .animation(
                .easeInOut(duration: reduceMotion ? 0 : configuration.animationDuration),
                value: isPressed
            )
            .animation(
                .easeInOut(duration: reduceMotion ? 0 : configuration.animationDuration * 1.2),
                value: isHovered
            )
            .onHover { hovering in
                guard isEnabled else { return }
                withAnimation {
                    isHovered = hovering
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        withAnimation {
                            isPressed = true
                        }

                        if configuration.enableHaptics {
                            hapticGenerator.impactOccurred()
                        }

                        if configuration.enableAccessibilityAnnouncements {
                            UIAccessibility.post(notification: .announcement, argument: "Button pressed")
                        }
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        withAnimation {
                            isPressed = false
                        }

                        // Delay tap action to allow animation to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            onTap?()
                        }
                    }
            )
            .disabled(!isEnabled)
            .onAppear {
                if configuration.enableHaptics {
                    hapticGenerator.prepare()
                }
            }
    }

    // MARK: - Calculations

    private func calculateScale() -> CGFloat {
        guard isEnabled else { return 1.0 }

        if isPressed {
            return configuration.pressScale
        } else if isHovered {
            return configuration.hoverScale
        }
        return 1.0
    }

    private func calculateShadowOpacity() -> Double {
        guard isEnabled else { return 0.05 }

        if isPressed {
            return configuration.shadowOpacity * 0.5
        } else if isHovered {
            return configuration.shadowOpacity * 1.3
        }
        return configuration.shadowOpacity
    }

    private func calculateShadowRadius() -> CGFloat {
        guard isEnabled else { return 2 }

        if isPressed {
            return configuration.shadowRadius * 0.5
        } else if isHovered {
            return configuration.shadowRadius * 1.2
        }
        return configuration.shadowRadius
    }

    private func calculateShadowOffset() -> CGFloat {
        guard isEnabled else { return 1 }

        if isPressed {
            return 2
        } else if isHovered {
            return 6
        }
        return 4
    }
}

// MARK: - View Extension

extension View {
    /// Applies enhanced card interaction micro-interactions
    func enhancedCardInteraction(
        configuration: EnhancedCardInteractionModifier.Configuration = .default,
        onTap: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            EnhancedCardInteractionModifier(
                configuration: configuration,
                onTap: onTap
            )
        )
    }

    /// Convenience method for subtle card interactions
    func subtleCardInteraction(onTap: (() -> Void)? = nil) -> some View {
        enhancedCardInteraction(configuration: .subtle, onTap: onTap)
    }

    /// Convenience method for prominent card interactions
    func prominentCardInteraction(onTap: (() -> Void)? = nil) -> some View {
        enhancedCardInteraction(configuration: .prominent, onTap: onTap)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        VStack(spacing: 8) {
            Text("Enhanced Card Interactions")
                .font(.title2)
                .fontWeight(.bold)

            Text("Hover and tap to see micro-interactions")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        VStack(spacing: 16) {
            // Default interaction
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(height: 100)
                .overlay {
                    Text("Default Interaction")
                        .font(.headline)
                }
                .enhancedCardInteraction {
                    print("Default card tapped")
                }

            // Subtle interaction
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(height: 100)
                .overlay {
                    Text("Subtle Interaction")
                        .font(.headline)
                }
                .subtleCardInteraction {
                    print("Subtle card tapped")
                }

            // Prominent interaction
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(height: 100)
                .overlay {
                    Text("Prominent Interaction")
                        .font(.headline)
                }
                .prominentCardInteraction {
                    print("Prominent card tapped")
                }
        }
        .padding()
    }
    .padding()
}