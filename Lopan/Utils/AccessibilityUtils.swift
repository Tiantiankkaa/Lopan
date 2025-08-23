//
//  AccessibilityUtils.swift
//  Lopan
//
//  Created by Claude Code for Accessibility Support
//

import SwiftUI
import UIKit

// MARK: - Accessibility Manager

class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverEnabled = false
    @Published var isSwitchControlEnabled = false
    @Published var isReduceMotionEnabled = false
    @Published var isReduceTransparencyEnabled = false
    @Published var isDarkModeEnabled = false
    @Published var preferredContentSizeCategory: ContentSizeCategory = .medium
    @Published var isHighContrastEnabled = false
    @Published var isBoldTextEnabled = false
    
    private init() {
        updateAccessibilitySettings()
        setupNotifications()
    }
    
    private func setupNotifications() {
        // VoiceOver
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
        
        // Switch Control
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.switchControlStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isSwitchControlEnabled = UIAccessibility.isSwitchControlRunning
        }
        
        // Reduce Motion
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
        
        // Reduce Transparency
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        }
        
        // Bold Text
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        }
        
        // Content Size Category
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
        }
    }
    
    private func updateAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isSwitchControlEnabled = UIAccessibility.isSwitchControlRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
    }
    
    func announceForVoiceOver(_ message: String) {
        guard isVoiceOverEnabled else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    func announceLayoutChange(_ view: Any? = nil) {
        guard isVoiceOverEnabled else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: view)
    }
    
    func announceScreenChange(_ view: Any? = nil) {
        guard isVoiceOverEnabled else { return }
        UIAccessibility.post(notification: .screenChanged, argument: view)
    }
}

// MARK: - Accessibility Modifiers

struct AccessibleModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let value: String?
    let isButton: Bool
    let isHeader: Bool
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil,
        isButton: Bool = false,
        isHeader: Bool = false
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
        self.isButton = isButton
        self.isHeader = isHeader
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(combinedTraits)
    }
    
    private var combinedTraits: AccessibilityTraits {
        var result = traits
        if isButton { result.insert(.isButton) }
        if isHeader { result.insert(.isHeader) }
        return result
    }
}

extension View {
    func accessibleContent(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil,
        isButton: Bool = false,
        isHeader: Bool = false
    ) -> some View {
        self.modifier(AccessibleModifier(
            label: label,
            hint: hint,
            traits: traits,
            value: value,
            isButton: isButton,
            isHeader: isHeader
        ))
    }
}

// MARK: - Dynamic Type Support

struct DynamicTypeModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    
    let baseFont: Font
    let maxSizeCategory: ContentSizeCategory
    
    func body(content: Content) -> some View {
        content
            .font(scaledFont)
    }
    
    private var scaledFont: Font {
        // Limit scaling for certain content size categories
        if sizeCategory > maxSizeCategory {
            return Font.custom("", size: fontSizeForCategory(maxSizeCategory))
        }
        
        return baseFont
    }
    
    private func fontSizeForCategory(_ category: ContentSizeCategory) -> CGFloat {
        switch category {
        case .extraSmall: return 12
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        case .extraLarge: return 20
        case .extraExtraLarge: return 22
        case .extraExtraExtraLarge: return 24
        case .accessibilityMedium: return 28
        case .accessibilityLarge: return 32
        case .accessibilityExtraLarge: return 36
        case .accessibilityExtraExtraLarge: return 40
        case .accessibilityExtraExtraExtraLarge: return 44
        default: return 16
        }
    }
}

extension View {
    func dynamicTypeSupport(
        baseFont: Font = .body,
        maxSizeCategory: ContentSizeCategory = .accessibilityExtraExtraExtraLarge
    ) -> some View {
        self.modifier(DynamicTypeModifier(baseFont: baseFont, maxSizeCategory: maxSizeCategory))
    }
}

// MARK: - High Contrast Support

struct HighContrastModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    let normalColor: Color
    let highContrastColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(effectiveColor)
    }
    
    private var effectiveColor: Color {
        if accessibilityManager.isHighContrastEnabled {
            return highContrastColor
        }
        return normalColor
    }
}

extension View {
    func highContrastSupport(
        normal: Color,
        highContrast: Color
    ) -> some View {
        self.modifier(HighContrastModifier(
            normalColor: normal,
            highContrastColor: highContrast
        ))
    }
}

// MARK: - Reduce Motion Support

struct ReduceMotionModifier: ViewModifier {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    let animation: Animation
    let reducedAnimation: Animation?
    
    func body(content: Content) -> some View {
        content
            .animation(effectiveAnimation, value: UUID())
    }
    
    private var effectiveAnimation: Animation? {
        if accessibilityManager.isReduceMotionEnabled {
            return reducedAnimation ?? .none
        }
        return animation
    }
}

extension View {
    func reduceMotionSupport(
        animation: Animation,
        reducedAnimation: Animation? = nil
    ) -> some View {
        self.modifier(ReduceMotionModifier(
            animation: animation,
            reducedAnimation: reducedAnimation
        ))
    }
}

// MARK: - Voice Control Support

struct VoiceControlModifier: ViewModifier {
    let voiceControlLabel: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityInputLabels([voiceControlLabel])
    }
}

extension View {
    func voiceControlSupport(label: String) -> some View {
        self.modifier(VoiceControlModifier(voiceControlLabel: label))
    }
}

// MARK: - Accessible Colors

struct AccessibleColors {
    static func textColor(for background: Color, in colorScheme: ColorScheme) -> Color {
        // Calculate contrast ratio and return appropriate text color
        switch colorScheme {
        case .dark:
            return .white
        case .light:
            return .black
        @unknown default:
            return .primary
        }
    }
    
    static func contrastRatio(foreground: Color, background: Color) -> Double {
        // Simplified contrast ratio calculation
        // In a real implementation, you would convert colors to RGB and calculate luminance
        return 4.5 // Placeholder for minimum WCAG AA contrast ratio
    }
    
    static var adaptiveColors: [String: (light: Color, dark: Color, highContrast: Color)] {
        return [
            "primary": (
                light: Color.blue,
                dark: Color.blue,
                highContrast: Color.white
            ),
            "secondary": (
                light: Color.gray,
                dark: Color.gray,
                highContrast: Color.black
            ),
            "background": (
                light: Color.white,
                dark: Color.black,
                highContrast: Color.black
            )
        ]
    }
}

// MARK: - Accessibility Testing Helper

#if DEBUG
struct AccessibilityTestingView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Accessibility Testing")
                .font(.largeTitle)
                .accessibleContent(
                    label: "Accessibility Testing",
                    isHeader: true
                )
            
            Group {
                Text("VoiceOver: \(accessibilityManager.isVoiceOverEnabled ? "Enabled" : "Disabled")")
                Text("Reduce Motion: \(accessibilityManager.isReduceMotionEnabled ? "Enabled" : "Disabled")")
                Text("Bold Text: \(accessibilityManager.isBoldTextEnabled ? "Enabled" : "Disabled")")
                Text("Content Size: \(accessibilityManager.preferredContentSizeCategory.description)")
            }
            .dynamicTypeSupport()
            
            Button("Test VoiceOver Announcement") {
                accessibilityManager.announceForVoiceOver("This is a test announcement")
            }
            .accessibleContent(
                label: "Test VoiceOver Announcement",
                hint: "Triggers a VoiceOver announcement for testing",
                isButton: true
            )
            
            Button("Test Screen Change") {
                accessibilityManager.announceScreenChange()
            }
            .accessibleContent(
                label: "Test Screen Change",
                hint: "Announces a screen change for VoiceOver",
                isButton: true
            )
        }
        .padding()
    }
}
#endif

// MARK: - ContentSizeCategory Extension

extension ContentSizeCategory {
    init(_ uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
    
    var description: String {
        switch self {
        case .extraSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        case .extraExtraLarge: return "Extra Extra Large"
        case .extraExtraExtraLarge: return "Extra Extra Extra Large"
        case .accessibilityMedium: return "Accessibility Medium"
        case .accessibilityLarge: return "Accessibility Large"
        case .accessibilityExtraLarge: return "Accessibility Extra Large"
        case .accessibilityExtraExtraLarge: return "Accessibility Extra Extra Large"
        case .accessibilityExtraExtraExtraLarge: return "Accessibility Extra Extra Extra Large"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    #if DEBUG
    AccessibilityTestingView()
    #else
    Text("Accessibility Utils")
    #endif
}