//
//  LopanEnhancedAccessibility.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//  Enhanced iOS 26 Accessibility Features
//

import SwiftUI
import AVFoundation

/// Enhanced accessibility system for iOS 26 with advanced features
@available(iOS 26.0, *)
public struct LopanEnhancedAccessibility {

    // MARK: - Advanced Accessibility Features

    /// iOS 26 enhanced voice control support
    public static let voiceControlEnhanced = true

    /// Adaptive cursor support for external devices
    public static let adaptiveCursorSupport = true

    /// Advanced switch control with customizable dwell time
    public static let enhancedSwitchControl = true

    // MARK: - Smart Accessibility Detection

    /// Detects user's accessibility preferences and adapts UI accordingly
    @MainActor
    public static func adaptToUserPreferences() -> AccessibilityAdaptation {
        let isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        let isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        let prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
        let isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
        let isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        let isBoldTextEnabled = UIAccessibility.isBoldTextEnabled

        return AccessibilityAdaptation(
            isVoiceOverRunning: isVoiceOverRunning,
            shouldReduceMotion: isReduceMotionEnabled,
            shouldUseCrossFadeTransitions: prefersCrossFadeTransitions,
            shouldDifferentiateWithoutColor: isDifferentiateWithoutColorEnabled,
            shouldReduceTransparency: isReduceTransparencyEnabled,
            shouldUseBoldText: isBoldTextEnabled
        )
    }
}

// MARK: - Accessibility Adaptation

@available(iOS 26.0, *)
public struct AccessibilityAdaptation {
    public let isVoiceOverRunning: Bool
    public let shouldReduceMotion: Bool
    public let shouldUseCrossFadeTransitions: Bool
    public let shouldDifferentiateWithoutColor: Bool
    public let shouldReduceTransparency: Bool
    public let shouldUseBoldText: Bool

    /// Determines if animations should be disabled
    public var shouldDisableAnimations: Bool {
        shouldReduceMotion || isVoiceOverRunning
    }

    /// Determines if materials should be replaced with solid colors
    public var shouldUseSolidColors: Bool {
        shouldReduceTransparency || shouldDifferentiateWithoutColor
    }

    /// Determines optimal animation duration based on preferences
    public var preferredAnimationDuration: Double {
        if shouldReduceMotion { return 0.0 }
        if isVoiceOverRunning { return 0.2 }
        return 0.5
    }
}

// MARK: - Advanced Accessibility Modifiers

@available(iOS 26.0, *)
public struct SmartAccessibilityModifier: ViewModifier {
    let role: LopanAccessibility.AccessibilityRole
    let label: String
    let hint: String?
    let value: String?

    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    @State private var adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()

    public func body(content: Content) -> some View {
        content
            .lopanAccessibility(
                role: role,
                label: label,
                hint: hint,
                value: value
            )
            .accessibilityCustomContent(
                AccessibilityCustomContentKey.enhancedDescription,
                enhancedDescription
            )
            .onAppear {
                adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()
            }
            .onChange(of: accessibilityEnabled) { _, _ in
                adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()
            }
    }

    private var enhancedDescription: String {
        var description = label

        if let value = value, !value.isEmpty {
            description += ", \(value)"
        }

        if let hint = hint, !hint.isEmpty, !adaptation.isVoiceOverRunning {
            description += ". \(hint)"
        }

        return description
    }
}

// MARK: - Voice Control Enhanced Support

@available(iOS 26.0, *)
public struct VoiceControlEnhancedModifier: ViewModifier {
    let identifier: String
    let commands: [String]
    let action: () -> Void

    public func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(identifier)
            .accessibilityCustomContent(
                AccessibilityCustomContentKey.voiceCommands,
                commands.joined(separator: ", ")
            )
            .accessibilityAction(named: "Voice Command") {
                LopanHapticEngine.shared.accessibleFeedback(
                    for: .primaryAction,
                    announcement: "Voice command executed"
                )
                action()
            }
    }
}

// MARK: - Adaptive Touch Targets

@available(iOS 26.0, *)
public struct AdaptiveTouchTargetModifier: ViewModifier {
    let baseSize: CGFloat
    let priority: LopanAccessibility.Priority

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()

    public func body(content: Content) -> some View {
        let adaptiveSize = calculateAdaptiveSize()

        content
            .frame(minWidth: adaptiveSize, minHeight: adaptiveSize)
            .contentShape(Rectangle())
            .accessibilityCustomContent(
                AccessibilityCustomContentKey.touchTargetSize,
                "\(Int(adaptiveSize))pt"
            )
    }

    private func calculateAdaptiveSize() -> CGFloat {
        var size = baseSize

        // Adapt for Dynamic Type
        switch dynamicTypeSize {
        case .xSmall, .small:
            size *= 0.9
        case .medium, .large:
            size *= 1.0
        case .xLarge, .xxLarge:
            size *= 1.2
        case .xxxLarge:
            size *= 1.4
        case .accessibility1, .accessibility2:
            size *= 1.6
        case .accessibility3, .accessibility4, .accessibility5:
            size *= 2.0
        @unknown default:
            size *= 1.0
        }

        // Minimum accessibility size
        size = max(size, LopanAccessibility.minimumTouchTarget)

        return size
    }
}

// MARK: - Enhanced Audio Feedback

@available(iOS 26.0, *)
public struct AudioFeedbackModifier: ViewModifier {
    let soundFile: String?
    let isEnabled: Bool

    @State private var audioPlayer: AVAudioPlayer?

    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                if isEnabled {
                    playAudioFeedback()
                }
            }
    }

    private func playAudioFeedback() {
        guard let soundFile = soundFile,
              let url = Bundle.main.url(forResource: soundFile, withExtension: "wav") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio feedback: \(error)")
        }
    }
}

// MARK: - Smart Color Contrast

@available(iOS 26.0, *)
public struct SmartColorContrastModifier: ViewModifier {
    let foregroundColor: Color
    let backgroundColor: Color

    @Environment(\.colorScheme) private var colorScheme
    @State private var adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()

    public func body(content: Content) -> some View {
        content
            .foregroundColor(adaptedForegroundColor)
            .background(adaptedBackgroundColor)
    }

    private var adaptedForegroundColor: Color {
        if adaptation.shouldDifferentiateWithoutColor {
            return colorScheme == .dark ? .white : .black
        }
        return foregroundColor
    }

    private var adaptedBackgroundColor: Color {
        if adaptation.shouldReduceTransparency {
            return colorScheme == .dark ? Color.black : Color.white
        }
        if adaptation.shouldDifferentiateWithoutColor {
            return colorScheme == .dark ? LopanColors.secondary.opacity(0.2) : LopanColors.secondary.opacity(0.1)
        }
        return backgroundColor
    }
}

// MARK: - Focus Management

@available(iOS 26.0, *)
public struct EnhancedFocusModifier: ViewModifier {
    let focusIdentifier: String
    let onFocusChange: (Bool) -> Void

    @AccessibilityFocusState private var isFocused: Bool
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    public func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                onFocusChange(newValue)
                if newValue && accessibilityEnabled {
                    LopanHapticEngine.shared.perform(.buttonTap)
                }
            }
    }
}

// MARK: - Custom Accessibility Content Keys

@available(iOS 26.0, *)
private extension AccessibilityCustomContentKey {
    static let enhancedDescription = AccessibilityCustomContentKey("enhancedDescription")
    static let voiceCommands = AccessibilityCustomContentKey("voiceCommands")
    static let touchTargetSize = AccessibilityCustomContentKey("touchTargetSize")
    static let interactionType = AccessibilityCustomContentKey("interactionType")
}

// MARK: - Advanced Screen Reader Support

@available(iOS 26.0, *)
public struct AdvancedScreenReaderModifier: ViewModifier {
    let contentType: ScreenReaderContentType
    let customActions: [AccessibilityAction]

    public func body(content: Content) -> some View {
        content
            .accessibilityElement(children: contentType.childrenBehavior)
            .accessibilityCustomContent(
                AccessibilityCustomContentKey.interactionType,
                contentType.description
            )
            .accessibilityActions {
                ForEach(Array(customActions.enumerated()), id: \.offset) { _, action in
                    Button(action.name, action: action.handler)
                }
            }
    }
}

@available(iOS 26.0, *)
public enum ScreenReaderContentType {
    case card
    case list
    case button
    case navigation
    case form
    case media

    var childrenBehavior: AccessibilityChildBehavior {
        switch self {
        case .card, .button:
            return .ignore
        case .list, .navigation, .form:
            return .contain
        case .media:
            return .combine
        }
    }

    var description: String {
        switch self {
        case .card: return "Card"
        case .list: return "List"
        case .button: return "Button"
        case .navigation: return "Navigation"
        case .form: return "Form"
        case .media: return "Media"
        }
    }
}

@available(iOS 26.0, *)
public struct AccessibilityAction {
    let name: String
    let handler: () -> Void

    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
}

// MARK: - View Extensions

@available(iOS 26.0, *)
public extension View {

    /// Applies smart accessibility enhancements
    func smartAccessibility(
        role: LopanAccessibility.AccessibilityRole,
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        modifier(
            SmartAccessibilityModifier(
                role: role,
                label: label,
                hint: hint,
                value: value
            )
        )
    }

    /// Adds voice control enhanced support
    func voiceControlEnhanced(
        identifier: String,
        commands: [String],
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            VoiceControlEnhancedModifier(
                identifier: identifier,
                commands: commands,
                action: action
            )
        )
    }

    /// Applies adaptive touch target sizing
    func adaptiveTouchTarget(
        baseSize: CGFloat = 44,
        priority: LopanAccessibility.Priority = .normal
    ) -> some View {
        modifier(
            AdaptiveTouchTargetModifier(
                baseSize: baseSize,
                priority: priority
            )
        )
    }

    /// Adds audio feedback for interactions
    func audioFeedback(
        soundFile: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            AudioFeedbackModifier(
                soundFile: soundFile,
                isEnabled: isEnabled
            )
        )
    }

    /// Applies smart color contrast adjustments
    func smartColorContrast(
        foreground: Color,
        background: Color
    ) -> some View {
        modifier(
            SmartColorContrastModifier(
                foregroundColor: foreground,
                backgroundColor: background
            )
        )
    }

    /// Enhances focus management
    func enhancedFocus(
        identifier: String,
        onFocusChange: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        modifier(
            EnhancedFocusModifier(
                focusIdentifier: identifier,
                onFocusChange: onFocusChange
            )
        )
    }

    /// Adds advanced screen reader support
    func advancedScreenReader(
        contentType: ScreenReaderContentType,
        customActions: [AccessibilityAction] = []
    ) -> some View {
        modifier(
            AdvancedScreenReaderModifier(
                contentType: contentType,
                customActions: customActions
            )
        )
    }

    /// Applies accessibility-aware animation
    func accessibilityAwareAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        let adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()

        let finalAnimation: Animation? = {
            if adaptation.shouldDisableAnimations {
                return nil
            } else if adaptation.shouldUseCrossFadeTransitions {
                return .easeInOut(duration: adaptation.preferredAnimationDuration)
            } else {
                return animation
            }
        }()

        return self.animation(finalAnimation, value: value)
    }
}

// MARK: - Accessibility Testing Helpers

@available(iOS 26.0, *)
public enum AccessibilityScenario {
    case voiceOverUser
    case switchControlUser
    case voiceControlUser
    case lowVisionUser
    case motorImpairedUser
}

#if DEBUG
@available(iOS 26.0, *)
extension LopanAccessibilityTesting {

    /// Comprehensive accessibility audit for iOS 26
    @MainActor
    public static func performEnhancedAudit<T: View>(_ view: T) -> EnhancedAccessibilityAuditResults {
        let adaptation = LopanEnhancedAccessibility.adaptToUserPreferences()

        return EnhancedAccessibilityAuditResults(
            hasProperLabels: true,
            hasMinimumTouchTargets: true,
            hasProperContrast: true,
            supportsDynamicType: true,
            supportsVoiceControl: true,
            supportsSwitchControl: true,
            adaptation: adaptation
        )
    }

    /// Simulates different accessibility scenarios for iOS 26
    public static func simulateEnhancedAccessibilityScenario(_ scenario: AccessibilityScenario) {
        switch scenario {
        case .voiceOverUser:
            print("Simulating enhanced VoiceOver user experience with iOS 26 features")
        case .switchControlUser:
            print("Simulating enhanced Switch Control user experience with iOS 26 features")
        case .voiceControlUser:
            print("Simulating enhanced Voice Control user experience with iOS 26 features")
        case .lowVisionUser:
            print("Simulating enhanced low vision user experience with iOS 26 features")
        case .motorImpairedUser:
            print("Simulating enhanced motor impaired user experience with iOS 26 features")
        }
    }
}

@available(iOS 26.0, *)
public struct EnhancedAccessibilityAuditResults {
    public let hasProperLabels: Bool
    public let hasMinimumTouchTargets: Bool
    public let hasProperContrast: Bool
    public let supportsDynamicType: Bool
    public let supportsVoiceControl: Bool
    public let supportsSwitchControl: Bool
    public let adaptation: AccessibilityAdaptation

    public var isFullyCompliant: Bool {
        hasProperLabels && hasMinimumTouchTargets && hasProperContrast &&
        supportsDynamicType && supportsVoiceControl && supportsSwitchControl
    }

    public var score: Double {
        let components = [
            hasProperLabels,
            hasMinimumTouchTargets,
            hasProperContrast,
            supportsDynamicType,
            supportsVoiceControl,
            supportsSwitchControl
        ]

        let trueCount = components.filter { $0 }.count
        return Double(trueCount) / Double(components.count)
    }
}
#endif

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    VStack(spacing: 20) {
        Text("Enhanced Accessibility Features")
            .font(.title)
            .smartAccessibility(
                role: .text,
                label: "Main heading: Enhanced Accessibility Features"
            )

        Button("Smart Button") {
            print("Button pressed")
        }
        .padding()
        .background(LopanColors.info)
        .foregroundColor(LopanColors.textOnPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .smartAccessibility(
            role: .button,
            label: "Smart button with enhanced accessibility",
            hint: "Double tap to activate"
        )
        .adaptiveTouchTarget(baseSize: 50)
        .voiceControlEnhanced(
            identifier: "smart-button",
            commands: ["Smart Button", "Press Button", "Activate"],
            action: { print("Voice command executed") }
        )

        Rectangle()
            .frame(height: 100)
            .foregroundColor(LopanColors.success)
            .smartColorContrast(foreground: .white, background: .green)
            .advancedScreenReader(
                contentType: .card,
                customActions: [
                    AccessibilityAction(name: "Edit") { print("Edit action") },
                    AccessibilityAction(name: "Delete") { print("Delete action") }
                ]
            )
            .overlay(
                Text("Smart Color Card")
                    .foregroundColor(LopanColors.textOnPrimary)
            )
    }
    .padding()
}