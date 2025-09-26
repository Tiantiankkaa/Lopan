//
//  LopanAdvancedGestures.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//  Advanced Gesture Handling System for iOS 26
//

import SwiftUI

/// Advanced gesture recognition and handling system for iOS 26
@available(iOS 26.0, *)
public struct LopanAdvancedGestures {

    // MARK: - Enhanced Touch Recognition

    /// Multi-touch gesture recognizer with pressure sensitivity
    public static func pressureSensitiveGesture<Content: View>(
        content: @escaping () -> Content,
        onPressureChange: @escaping (Double) -> Void = { _ in },
        onTouchDown: @escaping () -> Void = {},
        onTouchUp: @escaping () -> Void = {}
    ) -> some View {
        PressureSensitiveView(
            content: content,
            onPressureChange: onPressureChange,
            onTouchDown: onTouchDown,
            onTouchUp: onTouchUp
        )
    }

    /// Haptic-enabled long press with customizable feedback
    public static func hapticLongPress(
        minimumDuration: Double = 0.5,
        maximumDistance: CGFloat = 10,
        onBegan: @escaping () -> Void = {},
        onChanged: @escaping (CGPoint) -> Void = { _ in },
        onEnded: @escaping () -> Void = {}
    ) -> some Gesture {
        LongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance)
            .onChanged { _ in
                LopanHapticEngine.shared.perform(.buttonLongPress)
                onBegan()
            }
            .onEnded { _ in
                LopanHapticEngine.shared.perform(.primaryAction)
                onEnded()
            }
    }

    /// Enhanced drag gesture with momentum and physics
    public static func enhancedDrag(
        coordinateSpace: CoordinateSpace = .local,
        onChanged: @escaping (DragGesture.Value, CGVector) -> Void = { _, _ in },
        onEnded: @escaping (DragGesture.Value, CGVector) -> Void = { _, _ in }
    ) -> some Gesture {
        EnhancedDragGesture(
            coordinateSpace: coordinateSpace,
            onChanged: onChanged,
            onEnded: onEnded
        )
    }
}

// MARK: - Pressure Sensitive View

@available(iOS 26.0, *)
private struct PressureSensitiveView<Content: View>: UIViewRepresentable {
    let content: () -> Content
    let onPressureChange: (Double) -> Void
    let onTouchDown: () -> Void
    let onTouchUp: () -> Void

    func makeUIView(context: Context) -> PressureSensitiveUIView {
        let uiView = PressureSensitiveUIView()
        uiView.onPressureChange = onPressureChange
        uiView.onTouchDown = onTouchDown
        uiView.onTouchUp = onTouchUp

        let hostingController = UIHostingController(rootView: content())
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        uiView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: uiView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
        ])

        return uiView
    }

    func updateUIView(_ uiView: PressureSensitiveUIView, context: Context) {
        // Update if needed
    }
}

@available(iOS 26.0, *)
private class PressureSensitiveUIView: UIView {
    var onPressureChange: ((Double) -> Void)?
    var onTouchDown: (() -> Void)?
    var onTouchUp: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTouchDown?()
        LopanHapticEngine.shared.perform(.buttonTap)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if let touch = touches.first {
            let pressure = Double(touch.force / touch.maximumPossibleForce)
            onPressureChange?(pressure)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onTouchUp?()
        onPressureChange?(0.0)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        onTouchUp?()
        onPressureChange?(0.0)
    }
}

// MARK: - Enhanced Drag Gesture

@available(iOS 26.0, *)
private struct EnhancedDragGesture: Gesture {
    let coordinateSpace: CoordinateSpace
    let onChanged: (DragGesture.Value, CGVector) -> Void
    let onEnded: (DragGesture.Value, CGVector) -> Void

    @State private var previousLocation: CGPoint = .zero
    @State private var previousTime: Date = Date()
    @State private var velocity: CGVector = .zero

    var body: some Gesture {
        DragGesture(coordinateSpace: coordinateSpace)
            .onChanged { value in
                let currentTime = Date()
                let timeDelta = currentTime.timeIntervalSince(previousTime)

                if timeDelta > 0 {
                    let locationDelta = CGPoint(
                        x: value.location.x - previousLocation.x,
                        y: value.location.y - previousLocation.y
                    )

                    velocity = CGVector(
                        dx: locationDelta.x / timeDelta,
                        dy: locationDelta.y / timeDelta
                    )
                }

                previousLocation = value.location
                previousTime = currentTime

                onChanged(value, velocity)
            }
            .onEnded { value in
                onEnded(value, velocity)
                velocity = .zero
            }
    }
}

// MARK: - Advanced Swipe Gesture System

@available(iOS 26.0, *)
public struct LopanSwipeGestureSystem {

    /// Multi-directional swipe with velocity thresholds
    public static func multiDirectionalSwipe(
        minimumDistance: CGFloat = 50,
        minimumVelocity: CGFloat = 100,
        onSwipe: @escaping (AdvancedSwipeDirection, CGFloat) -> Void
    ) -> some Gesture {
        DragGesture()
            .onEnded { value in
                let distance = sqrt(
                    pow(value.translation.width, 2) + pow(value.translation.height, 2)
                )

                guard distance >= minimumDistance else { return }

                let velocity = sqrt(
                    pow(value.velocity.width, 2) + pow(value.velocity.height, 2)
                )

                guard velocity >= minimumVelocity else { return }

                let angle = atan2(value.translation.height, value.translation.width)
                let direction = AdvancedSwipeDirection.from(angle: angle)

                LopanHapticEngine.shared.perform(.swipeAction)
                onSwipe(direction, velocity)
            }
    }

    /// Contextual swipe actions with visual feedback
    public static func contextualSwipe<Leading: View, Trailing: View>(
        leadingActions: @escaping () -> Leading,
        trailingActions: @escaping () -> Trailing,
        threshold: CGFloat = 80
    ) -> some ViewModifier {
        ContextualSwipeModifier(
            leadingActions: leadingActions,
            trailingActions: trailingActions,
            threshold: threshold
        )
    }
}

// MARK: - Swipe Direction

@available(iOS 26.0, *)
public enum AdvancedSwipeDirection: CaseIterable {
    case up, down, left, right

    static func from(angle: Double) -> AdvancedSwipeDirection {
        let degrees = angle * 180 / .pi

        switch degrees {
        case -45...45:
            return .right
        case 45...135:
            return .down
        case 135...180, -180...(-135):
            return .left
        case -135...(-45):
            return .up
        default:
            return .right
        }
    }
}

// MARK: - Contextual Swipe Modifier

@available(iOS 26.0, *)
private struct ContextualSwipeModifier<Leading: View, Trailing: View>: ViewModifier {
    let leadingActions: () -> Leading
    let trailingActions: () -> Trailing
    let threshold: CGFloat

    @State private var offset: CGFloat = 0
    @State private var isRevealing: Bool = false

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            // Leading actions
            leadingActions()
                .frame(width: max(0, -offset))
                .clipped()
                .opacity(offset < -threshold ? 1 : 0.5)

            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width

                            if abs(offset) > threshold && !isRevealing {
                                isRevealing = true
                                LopanHapticEngine.shared.perform(.buttonTap)
                            } else if abs(offset) <= threshold && isRevealing {
                                isRevealing = false
                            }
                        }
                        .onEnded { value in
                            withAnimation(LopanAdvancedAnimations.liquidSpring) {
                                if abs(value.translation.width) > threshold {
                                    // Snap to revealed state
                                    offset = value.translation.width > 0 ? threshold : -threshold
                                } else {
                                    // Snap back to center
                                    offset = 0
                                }
                            }
                        }
                )

            // Trailing actions
            trailingActions()
                .frame(width: max(0, offset))
                .clipped()
                .opacity(offset > threshold ? 1 : 0.5)
        }
        .clipped()
    }
}

// MARK: - Advanced Zoom Gesture

@available(iOS 26.0, *)
public struct LopanZoomGestureSystem {

    /// Enhanced zoom with momentum and bounds
    public static func enhancedZoom(
        minimumScale: CGFloat = 0.5,
        maximumScale: CGFloat = 3.0,
        onChanged: @escaping (CGFloat) -> Void = { _ in },
        onEnded: @escaping (CGFloat) -> Void = { _ in }
    ) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let clampedScale = max(minimumScale, min(maximumScale, value))
                onChanged(clampedScale)
            }
            .onEnded { value in
                let clampedScale = max(minimumScale, min(maximumScale, value))
                LopanHapticEngine.shared.perform(.primaryAction)
                onEnded(clampedScale)
            }
    }
}

// MARK: - Gesture Combination System

@available(iOS 26.0, *)
public struct LopanGestureCombinations {

    /// Simultaneous zoom and pan gesture
    public static func zoomAndPan(
        onZoomChanged: @escaping (CGFloat) -> Void = { _ in },
        onPanChanged: @escaping (CGSize) -> Void = { _ in },
        onGestureEnded: @escaping () -> Void = {}
    ) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged(onZoomChanged),
            DragGesture()
                .onChanged { value in
                    onPanChanged(value.translation)
                }
        )
        .onEnded { _ in
            onGestureEnded()
        }
    }

    /// Sequential tap and long press
    public static func tapThenLongPress(
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) -> some Gesture {
        SequenceGesture(
            TapGesture()
                .onEnded { onTap() },
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in onLongPress() }
        )
    }
}

// MARK: - Accessibility-Enhanced Gestures

@available(iOS 26.0, *)
public struct LopanAccessibleGestures {

    /// Voice control compatible gesture
    public static func voiceControlGesture(
        action: @escaping () -> Void,
        label: String
    ) -> some ViewModifier {
        AccessibleGestureModifier(action: action, label: label)
    }

    /// Switch control compatible gesture
    public static func switchControlGesture(
        action: @escaping () -> Void,
        hint: String
    ) -> some ViewModifier {
        SwitchControlGestureModifier(action: action, hint: hint)
    }
}

@available(iOS 26.0, *)
private struct AccessibleGestureModifier: ViewModifier {
    let action: () -> Void
    let label: String

    func body(content: Content) -> some View {
        content
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityAction {
                LopanHapticEngine.shared.perform(.primaryAction)
                action()
            }
            .onTapGesture {
                action()
            }
    }
}

@available(iOS 26.0, *)
private struct SwitchControlGestureModifier: ViewModifier {
    let action: () -> Void
    let hint: String

    func body(content: Content) -> some View {
        content
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(hint)
            .accessibilityAction {
                LopanHapticEngine.shared.perform(.primaryAction)
                action()
            }
            .onTapGesture {
                action()
            }
    }
}

// MARK: - View Extensions

@available(iOS 26.0, *)
public extension View {

    /// Applies pressure-sensitive gesture recognition
    func pressureSensitive(
        onPressureChange: @escaping (Double) -> Void = { _ in },
        onTouchDown: @escaping () -> Void = {},
        onTouchUp: @escaping () -> Void = {}
    ) -> some View {
        LopanAdvancedGestures.pressureSensitiveGesture(
            content: { self },
            onPressureChange: onPressureChange,
            onTouchDown: onTouchDown,
            onTouchUp: onTouchUp
        )
    }

    /// Applies haptic-enabled long press
    func hapticLongPress(
        minimumDuration: Double = 0.5,
        onBegan: @escaping () -> Void = {},
        onEnded: @escaping () -> Void = {}
    ) -> some View {
        self.gesture(
            LopanAdvancedGestures.hapticLongPress(
                minimumDuration: minimumDuration,
                onBegan: onBegan,
                onEnded: onEnded
            )
        )
    }

    /// Applies multi-directional swipe gesture
    func multiDirectionalSwipe(
        minimumDistance: CGFloat = 50,
        onSwipe: @escaping (AdvancedSwipeDirection, CGFloat) -> Void
    ) -> some View {
        self.gesture(
            LopanSwipeGestureSystem.multiDirectionalSwipe(
                minimumDistance: minimumDistance,
                onSwipe: onSwipe
            )
        )
    }

    /// Applies contextual swipe actions
    func contextualSwipe<Leading: View, Trailing: View>(
        leading: @escaping () -> Leading,
        trailing: @escaping () -> Trailing,
        threshold: CGFloat = 80
    ) -> some View {
        modifier(
            LopanSwipeGestureSystem.contextualSwipe(
                leadingActions: leading,
                trailingActions: trailing,
                threshold: threshold
            )
        )
    }

    /// Applies enhanced zoom gesture
    func enhancedZoom(
        minimumScale: CGFloat = 0.5,
        maximumScale: CGFloat = 3.0,
        onChanged: @escaping (CGFloat) -> Void = { _ in },
        onEnded: @escaping (CGFloat) -> Void = { _ in }
    ) -> some View {
        self.gesture(
            LopanZoomGestureSystem.enhancedZoom(
                minimumScale: minimumScale,
                maximumScale: maximumScale,
                onChanged: onChanged,
                onEnded: onEnded
            )
        )
    }

    /// Applies voice control compatible gesture
    func voiceControlCompatible(
        action: @escaping () -> Void,
        label: String
    ) -> some View {
        modifier(
            LopanAccessibleGestures.voiceControlGesture(
                action: action,
                label: label
            )
        )
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    VStack(spacing: 30) {
        Text("Advanced Gesture System")
            .font(.title)

        Rectangle()
            .frame(width: 200, height: 100)
            .foregroundColor(LopanColors.info)
            .pressureSensitive(
                onPressureChange: { pressure in
                    print("Pressure: \(pressure)")
                }
            )
            .overlay(
                Text("Pressure Sensitive")
                    .foregroundColor(LopanColors.textOnPrimary)
            )

        Rectangle()
            .frame(width: 200, height: 100)
            .foregroundColor(LopanColors.success)
            .hapticLongPress(
                onBegan: { print("Long press began") },
                onEnded: { print("Long press ended") }
            )
            .overlay(
                Text("Haptic Long Press")
                    .foregroundColor(LopanColors.textOnPrimary)
            )

        Rectangle()
            .frame(width: 200, height: 100)
            .foregroundColor(LopanColors.premium)
            .multiDirectionalSwipe { direction, velocity in
                print("Swiped \(direction) with velocity \(velocity)")
            }
            .overlay(
                Text("Multi-directional Swipe")
                    .foregroundColor(LopanColors.textOnPrimary)
            )
    }
    .padding()
}