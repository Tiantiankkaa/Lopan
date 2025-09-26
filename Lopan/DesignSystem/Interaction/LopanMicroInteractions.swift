//
//  LopanMicroInteractions.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Contextual micro-interactions system
//

import SwiftUI
import UIKit

/// Contextual micro-interactions system for enhanced user experience
/// Provides intelligent haptic feedback, visual responses, and contextual animations
@MainActor
public final class LopanMicroInteractions {

    // MARK: - Interaction Types

    public enum InteractionType {
        case buttonTap
        case cardSelect
        case listSwipe
        case toggleSwitch
        case valueChange
        case navigationTransition
        case errorState
        case successState
        case dataRefresh
        case contextualAction

        var defaultHaptic: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .buttonTap, .cardSelect, .toggleSwitch:
                return .light
            case .listSwipe, .valueChange, .contextualAction:
                return .medium
            case .navigationTransition, .dataRefresh:
                return .soft
            case .errorState:
                return .rigid
            case .successState:
                return .light
            }
        }

        var defaultAnimation: Animation {
            switch self {
            case .buttonTap, .toggleSwitch:
                return .spring(response: 0.2, dampingFraction: 0.7)
            case .cardSelect, .contextualAction:
                return .easeInOut(duration: 0.3)
            case .listSwipe, .valueChange:
                return .smooth
            case .navigationTransition:
                return .spring(response: 0.4, dampingFraction: 0.8)
            case .errorState, .successState:
                return .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1)
            case .dataRefresh:
                return .smooth
            }
        }
    }

    // MARK: - Interaction Context

    public struct InteractionContext {
        let type: InteractionType
        let priority: Priority
        let customHaptic: UIImpactFeedbackGenerator.FeedbackStyle?
        let customAnimation: Animation?
        let delay: TimeInterval
        let duration: TimeInterval?

        public enum Priority {
            case low
            case medium
            case high
            case critical

            var hapticIntensity: CGFloat {
                switch self {
                case .low: return 0.3
                case .medium: return 0.6
                case .high: return 0.8
                case .critical: return 1.0
                }
            }
        }

        public init(
            type: InteractionType,
            priority: Priority = .medium,
            customHaptic: UIImpactFeedbackGenerator.FeedbackStyle? = nil,
            customAnimation: Animation? = nil,
            delay: TimeInterval = 0.0,
            duration: TimeInterval? = nil
        ) {
            self.type = type
            self.priority = priority
            self.customHaptic = customHaptic
            self.customAnimation = customAnimation
            self.delay = delay
            self.duration = duration
        }
    }

    // MARK: - Haptic Engine

    private static let hapticEngine = LopanHapticEngine.shared

    // MARK: - Public Interface

    /// Trigger contextual interaction
    public static func trigger(_ context: InteractionContext) {
        // Apply delay if specified
        if context.delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + context.delay) {
                performInteraction(context)
            }
        } else {
            performInteraction(context)
        }
    }

    /// Trigger simple interaction
    public static func trigger(_ type: InteractionType) {
        let context = InteractionContext(type: type)
        trigger(context)
    }

    /// Create interactive modifier
    public static func interactive(
        context: InteractionContext,
        action: @escaping () -> Void
    ) -> some ViewModifier {
        InteractiveModifier(context: context, action: action)
    }

    /// Create contextual button interaction
    public static func contextualButton(
        priority: InteractionContext.Priority = .medium,
        action: @escaping () -> Void
    ) -> some ViewModifier {
        let context = InteractionContext(type: .buttonTap, priority: priority)
        return InteractiveModifier(context: context, action: action)
    }

    // MARK: - Specialized Interactions

    /// Success feedback interaction
    public static func success(message: String? = nil) {
        let context = InteractionContext(
            type: .successState,
            priority: .high,
            customHaptic: .light
        )

        trigger(context)

        // Optional success notification
        if let message = message {
            NotificationCenter.default.post(
                name: .lopanSuccessNotification,
                object: message
            )
        }
    }

    /// Error feedback interaction
    public static func error(message: String? = nil) {
        let context = InteractionContext(
            type: .errorState,
            priority: .critical,
            customHaptic: .rigid
        )

        trigger(context)

        // Optional error notification
        if let message = message {
            NotificationCenter.default.post(
                name: .lopanErrorNotification,
                object: message
            )
        }
    }

    /// Data refresh interaction
    public static func dataRefresh(intensity: InteractionContext.Priority = .medium) {
        let context = InteractionContext(
            type: .dataRefresh,
            priority: intensity,
            delay: 0.1
        )
        trigger(context)
    }

    /// Navigation transition interaction
    public static func navigationTransition(from: String, to: String) {
        let context = InteractionContext(
            type: .navigationTransition,
            priority: .medium,
            delay: 0.05
        )
        trigger(context)

        // Record for performance monitoring
        LopanPerformanceProfiler.shared.recordViewTransition(
            from: from,
            to: to,
            duration: 0.25
        )
    }

    // MARK: - Smart Interactions

    /// Context-aware interaction based on current app state
    public static func contextAware(
        baseType: InteractionType,
        currentContext: AppContext
    ) {
        let priority: InteractionContext.Priority

        // Adjust interaction based on context
        switch currentContext.mode {
        case .focused:
            priority = .high
        case .distracted:
            priority = .low
        case .normal:
            priority = .medium
        case .accessibility:
            priority = .critical
        }

        // Adjust for battery state
        let adjustedPriority = adjustForBatteryState(priority, batteryLevel: currentContext.batteryLevel)

        let context = InteractionContext(
            type: baseType,
            priority: adjustedPriority
        )

        trigger(context)
    }

    // MARK: - Performance Considerations

    private static func adjustForBatteryState(
        _ priority: InteractionContext.Priority,
        batteryLevel: Float
    ) -> InteractionContext.Priority {
        // Reduce interaction intensity on low battery
        if batteryLevel < 0.2 {
            switch priority {
            case .high, .critical:
                return .medium
            case .medium:
                return .low
            default:
                return priority
            }
        }
        return priority
    }

    private static func shouldThrottle() -> Bool {
        // Throttle interactions if performance is degraded
        let currentFPS = LopanPerformanceProfiler.shared.currentMetrics.currentFPS
        return currentFPS < 55.0 // Below 55fps, throttle micro-interactions
    }

    private static func performInteraction(_ context: InteractionContext) {
        // Skip if performance is degraded
        if shouldThrottle() && context.priority != .critical {
            return
        }

        // Trigger haptic feedback
        let hapticStyle = context.customHaptic ?? context.type.defaultHaptic
        // Use appropriate LopanHapticEngine method based on haptic style
        switch hapticStyle {
        case .light:
            hapticEngine.light()
        case .medium:
            hapticEngine.medium()
        case .heavy:
            hapticEngine.heavy()
        case .soft:
            hapticEngine.light()
        case .rigid:
            hapticEngine.heavy()
        }

        // Optional visual feedback could be added here
    }
}

// MARK: - Interactive Modifier

private struct InteractiveModifier: ViewModifier {
    let context: LopanMicroInteractions.InteractionContext
    let action: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? -0.05 : 0.0)
            .animation(
                context.customAnimation ?? context.type.defaultAnimation,
                value: isPressed
            )
            .onTapGesture {
                // Trigger interaction
                LopanMicroInteractions.trigger(context)

                // Visual feedback
                withAnimation(context.customAnimation ?? context.type.defaultAnimation) {
                    isPressed = true
                }

                // Reset visual state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(context.customAnimation ?? context.type.defaultAnimation) {
                        isPressed = false
                    }
                }

                // Execute action
                action()
            }
    }
}

// MARK: - App Context

public struct AppContext {
    public enum Mode {
        case normal
        case focused
        case distracted
        case accessibility
    }

    let mode: Mode
    let batteryLevel: Float
    let isLowPowerMode: Bool
    let accessibilityEnabled: Bool

    public init(
        mode: Mode = .normal,
        batteryLevel: Float = 1.0,
        isLowPowerMode: Bool = false,
        accessibilityEnabled: Bool = false
    ) {
        self.mode = mode
        self.batteryLevel = batteryLevel
        self.isLowPowerMode = isLowPowerMode
        self.accessibilityEnabled = accessibilityEnabled
    }

    public static var current: AppContext {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        return AppContext(
            mode: .normal, // Could be determined by app state
            batteryLevel: device.batteryLevel,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            accessibilityEnabled: UIAccessibility.isVoiceOverRunning
        )
    }
}

// MARK: - Specialized View Modifiers

extension View {
    /// Add contextual interaction behavior
    public func interactive(
        _ type: LopanMicroInteractions.InteractionType,
        priority: LopanMicroInteractions.InteractionContext.Priority = .medium,
        action: @escaping () -> Void
    ) -> some View {
        let context = LopanMicroInteractions.InteractionContext(type: type, priority: priority)
        return self.modifier(LopanMicroInteractions.interactive(context: context, action: action))
    }

    /// Add contextual button interaction
    public func contextualButton(
        priority: LopanMicroInteractions.InteractionContext.Priority = .medium,
        action: @escaping () -> Void
    ) -> some View {
        self.modifier(LopanMicroInteractions.contextualButton(priority: priority, action: action))
    }

    /// Add smart swipe interaction
    public func swipeInteractive(
        direction: SwipeDirection = .horizontal,
        action: @escaping () -> Void
    ) -> some View {
        self.modifier(SwipeInteractionModifier(direction: direction, action: action))
    }

    /// Add toggle interaction
    public func toggleInteractive(
        isOn: Binding<Bool>,
        priority: LopanMicroInteractions.InteractionContext.Priority = .medium
    ) -> some View {
        self.modifier(ToggleInteractionModifier(isOn: isOn, priority: priority))
    }
}

// MARK: - Swipe Interaction Modifier

public enum SwipeDirection {
    case horizontal
    case vertical
    case any
}

private struct SwipeInteractionModifier: ViewModifier {
    let direction: SwipeDirection
    let action: () -> Void

    @State private var dragOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(dragOffset)
            .animation(.smooth, value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation

                        switch direction {
                        case .horizontal:
                            dragOffset = CGSize(width: translation.width * 0.3, height: 0)
                        case .vertical:
                            dragOffset = CGSize(width: 0, height: translation.height * 0.3)
                        case .any:
                            dragOffset = CGSize(
                                width: translation.width * 0.3,
                                height: translation.height * 0.3
                            )
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50

                        let shouldTrigger: Bool
                        switch direction {
                        case .horizontal:
                            shouldTrigger = abs(value.translation.width) > threshold
                        case .vertical:
                            shouldTrigger = abs(value.translation.height) > threshold
                        case .any:
                            shouldTrigger = sqrt(
                                pow(value.translation.width, 2) + pow(value.translation.height, 2)
                            ) > threshold
                        }

                        if shouldTrigger {
                            LopanMicroInteractions.trigger(.listSwipe)
                            action()
                        }

                        // Reset offset
                        withAnimation(.smooth) {
                            dragOffset = .zero
                        }
                    }
            )
    }
}

// MARK: - Toggle Interaction Modifier

private struct ToggleInteractionModifier: ViewModifier {
    @Binding var isOn: Bool
    let priority: LopanMicroInteractions.InteractionContext.Priority

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                let context = LopanMicroInteractions.InteractionContext(
                    type: .toggleSwitch,
                    priority: priority
                )

                LopanMicroInteractions.trigger(context)

                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let lopanSuccessNotification = Notification.Name("LopanSuccessNotification")
    static let lopanErrorNotification = Notification.Name("LopanErrorNotification")
}

// MARK: - Usage Examples and Debug

#if DEBUG
struct MicroInteractionsDebugView: View {
    @State private var toggleState = false
    @State private var selectedCard: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Contextual Button Examples
                    VStack {
                        Text("Contextual Buttons")
                            .font(.headline)

                        HStack(spacing: 15) {
                            Button("Low Priority") { }
                                .padding()
                                .background(LopanColors.secondary.opacity(0.2))
                                .cornerRadius(8)
                                .contextualButton(priority: .low) {
                                    print("Low priority button tapped")
                                }

                            Button("Medium Priority") { }
                                .padding()
                                .background(LopanColors.primary.opacity(0.2))
                                .cornerRadius(8)
                                .contextualButton(priority: .medium) {
                                    print("Medium priority button tapped")
                                }

                            Button("High Priority") { }
                                .padding()
                                .background(LopanColors.accent.opacity(0.2))
                                .cornerRadius(8)
                                .contextualButton(priority: .high) {
                                    print("High priority button tapped")
                                }
                        }
                    }

                    // Card Selection Examples
                    VStack {
                        Text("Interactive Cards")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                            ForEach(0..<4, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedCard == index ? LopanColors.accent : LopanColors.background)
                                    .frame(height: 100)
                                    .overlay(
                                        Text("Card \(index + 1)")
                                            .foregroundColor(selectedCard == index ? .white : .primary)
                                    )
                                    .interactive(.cardSelect, priority: .medium) {
                                        selectedCard = selectedCard == index ? nil : index
                                    }
                            }
                        }
                    }

                    // Swipe Interactions
                    VStack {
                        Text("Swipe Interactions")
                            .font(.headline)

                        VStack(spacing: 10) {
                            Text("Swipe Horizontally →")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LopanColors.primary.opacity(0.1))
                                .cornerRadius(8)
                                .swipeInteractive(direction: .horizontal) {
                                    print("Horizontal swipe detected")
                                }

                            Text("Swipe Vertically ↕")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LopanColors.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .swipeInteractive(direction: .vertical) {
                                    print("Vertical swipe detected")
                                }
                        }
                    }

                    // Toggle Interactions
                    VStack {
                        Text("Toggle Interactions")
                            .font(.headline)

                        HStack {
                            Text("Enhanced Toggle")
                            Spacer()
                            Circle()
                                .fill(toggleState ? LopanColors.accent : LopanColors.secondary)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: toggleState ? "checkmark" : "xmark")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                )
                                .toggleInteractive(isOn: $toggleState, priority: .medium)
                        }
                        .padding()
                        .background(LopanColors.background)
                        .cornerRadius(12)
                    }

                    // Feedback Examples
                    VStack {
                        Text("Feedback Types")
                            .font(.headline)

                        HStack(spacing: 15) {
                            Button("Success") {
                                LopanMicroInteractions.success(message: "Operation completed!")
                            }
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)

                            Button("Error") {
                                LopanMicroInteractions.error(message: "Something went wrong!")
                            }
                            .padding()
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(8)

                            Button("Refresh") {
                                LopanMicroInteractions.dataRefresh(intensity: .high)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Micro-Interactions")
            .onReceive(NotificationCenter.default.publisher(for: .lopanSuccessNotification)) { notification in
                if let message = notification.object as? String {
                    print("Success: \(message)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lopanErrorNotification)) { notification in
                if let message = notification.object as? String {
                    print("Error: \(message)")
                }
            }
        }
    }
}

#Preview {
    MicroInteractionsDebugView()
}
#endif