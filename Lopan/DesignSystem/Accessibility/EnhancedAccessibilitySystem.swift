//
//  EnhancedAccessibilitySystem.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  iOS 26 Enhanced Accessibility System with backward compatibility
//

import SwiftUI
import Foundation
import AVFoundation
import os.log

// MARK: - Enhanced Accessibility Manager

@MainActor
public final class EnhancedAccessibilityManager: ObservableObject {
    public static let shared = EnhancedAccessibilityManager()

    private let compatibilityLayer = iOS26CompatibilityLayer.shared
    private let featureFlags = FeatureFlagManager.shared
    private let logger = Logger(subsystem: "com.lopan.accessibility", category: "Enhanced")

    @Published public var isEnabled: Bool = true
    @Published public var accessibilityMode: AccessibilityMode = .adaptive
    @Published public var spatialAudioEnabled: Bool = false
    @Published public var hapticFeedbackEnabled: Bool = true
    @Published public var highContrastMode: Bool = false
    @Published public var reducedMotionMode: Bool = false

    // Current accessibility settings
    @Published public private(set) var currentSettings: AccessibilitySettings = AccessibilitySettings()

    public enum AccessibilityMode: String, CaseIterable {
        case standard = "standard"
        case enhanced = "enhanced"
        case spatial = "spatial"
        case adaptive = "adaptive"

        public var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .enhanced: return "Enhanced"
            case .spatial: return "Spatial"
            case .adaptive: return "Adaptive"
            }
        }

        public var usesSpatialAudio: Bool {
            switch self {
            case .standard, .enhanced: return false
            case .spatial, .adaptive: return true
            }
        }

        public var usesAdvancedFeatures: Bool {
            switch self {
            case .standard: return false
            case .enhanced, .spatial, .adaptive: return true
            }
        }
    }

    public struct AccessibilitySettings {
        public let isVoiceOverRunning: Bool
        public let isReduceMotionEnabled: Bool
        public let isReduceTransparencyEnabled: Bool
        public let isIncreaseContrastEnabled: Bool
        public let isDifferentiateWithoutColorEnabled: Bool
        public let isOnOffSwitchLabelsEnabled: Bool
        public let preferredContentSizeCategory: UIContentSizeCategory
        public let isLargeContentSizeCategory: Bool
        public let isBoldTextEnabled: Bool
        public let isButtonShapesEnabled: Bool

        public init() {
            self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            self.isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            self.isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
            self.isOnOffSwitchLabelsEnabled = UIAccessibility.isOnOffSwitchLabelsEnabled
            self.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
            self.isLargeContentSizeCategory = preferredContentSizeCategory.isAccessibilityCategory
            self.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            self.isButtonShapesEnabled = false // UIAccessibility.isButtonShapesEnabled not available in all iOS versions
        }
    }

    private init() {
        setupAccessibilityMode()
        setupAccessibilityObservers()
        updateCurrentSettings()
        logger.info("♿ Enhanced Accessibility Manager initialized")
    }

    private func setupAccessibilityMode() {
        if featureFlags.isEnabled(.enhancedAccessibility) && compatibilityLayer.isIOS26Available {
            accessibilityMode = .adaptive
            spatialAudioEnabled = true
        } else {
            accessibilityMode = .enhanced
            spatialAudioEnabled = false
        }

        logger.info("🎯 Accessibility mode set to: \(self.accessibilityMode.displayName)")
    }

    private func setupAccessibilityObservers() {
        let notifications = [
            UIAccessibility.voiceOverStatusDidChangeNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            // UIAccessibility.differentiateDarkColorsStatusDidChangeNotification, // Not available in current iOS SDK
            UIAccessibility.boldTextStatusDidChangeNotification,
            UIAccessibility.buttonShapesEnabledStatusDidChangeNotification,
            UIContentSizeCategory.didChangeNotification
        ]

        for notification in notifications {
            NotificationCenter.default.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAccessibilityChange()
            }
        }
    }

    private func handleAccessibilityChange() {
        updateCurrentSettings()
        adaptToAccessibilitySettings()
        logger.info("♿ Accessibility settings changed - adapting interface")
    }

    private func updateCurrentSettings() {
        currentSettings = AccessibilitySettings()
    }

    private func adaptToAccessibilitySettings() {
        // Update modes based on accessibility settings
        reducedMotionMode = currentSettings.isReduceMotionEnabled
        highContrastMode = currentSettings.isIncreaseContrastEnabled

        // Disable spatial audio if VoiceOver is running to avoid conflicts
        if currentSettings.isVoiceOverRunning {
            spatialAudioEnabled = false
        }

        // Auto-adjust accessibility mode
        if accessibilityMode == .adaptive {
            if currentSettings.isVoiceOverRunning || currentSettings.isLargeContentSizeCategory {
                accessibilityMode = .enhanced
            }
        }
    }

    // MARK: - Spatial Audio

    @available(iOS 26.0, *)
    public func provideSpatialAudioCue(
        for element: AccessibilityElement,
        at location: CGPoint,
        in bounds: CGSize
    ) {
        guard spatialAudioEnabled && accessibilityMode.usesSpatialAudio else { return }

        // Calculate spatial position (normalized to -1 to 1)
        let normalizedX = (location.x / bounds.width) * 2 - 1
        let normalizedY = 1 - (location.y / bounds.height) * 2

        // Generate spatial audio cue
        let audioSessionCategory = AVAudioSession.Category.ambient
        try? AVAudioSession.sharedInstance().setCategory(audioSessionCategory, options: [.mixWithOthers])

        // Play spatial audio cue based on element type
        playSpatialCue(for: element.type, at: CGPoint(x: normalizedX, y: normalizedY))

        logger.debug("🔊 Spatial audio cue played for \(element.type.rawValue) at (\(String(format: "%.2f", normalizedX)), \(String(format: "%.2f", normalizedY)))")
    }

    @available(iOS 26.0, *)
    private func playSpatialCue(for elementType: AccessibilityElement.ElementType, at position: CGPoint) {
        // Simplified spatial audio implementation
        // In a real implementation, you'd use AVAudioEngine with spatial audio effects

        let frequency: Double
        switch elementType {
        case .button: frequency = 800
        case .card: frequency = 600
        case .text: frequency = 400
        case .heading: frequency = 1000
        case .list: frequency = 500
        case .navigation: frequency = 900
        }

        // Create a brief tone at the calculated frequency
        // Position affects volume and stereo positioning
        generateTone(frequency: frequency, duration: 0.1, position: position)
    }

    private func generateTone(frequency: Double, duration: TimeInterval, position: CGPoint) {
        // Simplified tone generation for spatial audio cues
        // This is a placeholder - real implementation would use AVAudioEngine
        let systemSoundID: SystemSoundID = 1157 // UIKeyboardInputClick
        AudioServicesPlaySystemSound(systemSoundID)
    }

    // MARK: - Enhanced VoiceOver Support

    public func enhancedVoiceOverDescription(
        for element: AccessibilityElement,
        context: AccessibilityContext
    ) -> String {
        var description = element.baseDescription

        // Add context-aware information
        if let position = context.positionInfo {
            description += " \(position)"
        }

        if let actionHints = element.actionHints, !actionHints.isEmpty {
            description += " 可用操作: \(actionHints.joined(separator: ", "))"
        }

        // Add state information
        if let state = element.currentState {
            description += " 当前状态: \(state)"
        }

        // Add relationship information
        if let relationships = context.relationships, !relationships.isEmpty {
            let relationshipText = relationships.map { "\($0.type): \($0.target)" }.joined(separator: ", ")
            description += " 关联元素: \(relationshipText)"
        }

        return description
    }

    public struct AccessibilityElement {
        public let id: String
        public let type: ElementType
        public let baseDescription: String
        public let actionHints: [String]?
        public let currentState: String?

        public enum ElementType: String, CaseIterable {
            case button = "button"
            case card = "card"
            case text = "text"
            case heading = "heading"
            case list = "list"
            case navigation = "navigation"

            public var voiceOverDescription: String {
                switch self {
                case .button: return "按钮"
                case .card: return "卡片"
                case .text: return "文本"
                case .heading: return "标题"
                case .list: return "列表"
                case .navigation: return "导航"
                }
            }
        }
    }

    public struct AccessibilityContext {
        public let positionInfo: String?
        public let relationships: [AccessibilityRelationship]?
        public let containerInfo: String?

        public struct AccessibilityRelationship {
            public let type: RelationshipType
            public let target: String

            public enum RelationshipType: String {
                case parent = "parent"
                case child = "child"
                case sibling = "sibling"
                case controls = "controls"
                case describedBy = "described_by"
            }
        }
    }

    // MARK: - High Contrast Support

    public func adaptColorsForAccessibility(_ color: Color) -> Color {
        guard highContrastMode else { return color }

        // Increase contrast for accessibility
        if color == LopanColors.textSecondary {
            return LopanColors.textPrimary
        }

        if color == LopanColors.backgroundSecondary {
            return LopanColors.background
        }

        // Make colors more accessible
        return color
    }

    public var accessibleColors: AccessibleColorPalette {
        AccessibleColorPalette(isHighContrast: highContrastMode)
    }

    public struct AccessibleColorPalette {
        public let isHighContrast: Bool

        public var textPrimary: Color {
            isHighContrast ? Color.primary : LopanColors.textPrimary
        }

        public var textSecondary: Color {
            isHighContrast ? Color.primary : LopanColors.textSecondary
        }

        public var background: Color {
            isHighContrast ? Color(UIColor.systemBackground) : LopanColors.background
        }

        public var cardBackground: Color {
            isHighContrast ? Color(UIColor.secondarySystemBackground) : LopanColors.backgroundSecondary
        }

        public var accent: Color {
            isHighContrast ? Color.blue : LopanColors.primary
        }

        public var success: Color {
            isHighContrast ? Color.green : LopanColors.success
        }

        public var warning: Color {
            isHighContrast ? Color.orange : LopanColors.warning
        }

        public var error: Color {
            isHighContrast ? Color.red : LopanColors.error
        }
    }

    // MARK: - Dynamic Type Support

    public func adaptiveFont(
        _ style: Font.TextStyle,
        design: Font.Design = .default,
        weight: Font.Weight = .regular
    ) -> Font {
        if currentSettings.isLargeContentSizeCategory {
            // Ensure minimum readable sizes for accessibility
            switch style {
            case .caption, .caption2:
                return .system(.footnote, design: design, weight: weight)
            case .footnote:
                return .system(.subheadline, design: design, weight: weight)
            default:
                return .system(style, design: design, weight: weight)
            }
        }

        return .system(style, design: design, weight: weight)
    }

    // MARK: - Performance Monitoring

    public func generateAccessibilityReport() -> AccessibilityPerformanceReport {
        return AccessibilityPerformanceReport(
            accessibilityMode: accessibilityMode,
            currentSettings: currentSettings,
            featuresEnabled: AccessibilityFeatures(
                spatialAudio: spatialAudioEnabled,
                highContrast: highContrastMode,
                enhancedVoiceOver: accessibilityMode.usesAdvancedFeatures
            )
        )
    }

    public struct AccessibilityPerformanceReport {
        public let accessibilityMode: AccessibilityMode
        public let currentSettings: AccessibilitySettings
        public let featuresEnabled: AccessibilityFeatures

        public var summary: String {
            """
            Enhanced Accessibility Performance Report
            =========================================
            Accessibility Mode: \(self.accessibilityMode.displayName)
            VoiceOver: \(currentSettings.isVoiceOverRunning ? "Running" : "Not Running")
            Reduce Motion: \(currentSettings.isReduceMotionEnabled ? "Enabled" : "Disabled")
            High Contrast: \(currentSettings.isIncreaseContrastEnabled ? "Enabled" : "Disabled")
            Large Text: \(currentSettings.isLargeContentSizeCategory ? "Enabled" : "Disabled")
            Content Size: \(currentSettings.preferredContentSizeCategory.rawValue)

            Enhanced Features:
            - Spatial Audio: \(featuresEnabled.spatialAudio ? "Enabled" : "Disabled")
            - High Contrast: \(featuresEnabled.highContrast ? "Enabled" : "Disabled")
            - Enhanced VoiceOver: \(featuresEnabled.enhancedVoiceOver ? "Enabled" : "Disabled")
            """
        }
    }

    public struct AccessibilityFeatures {
        public let spatialAudio: Bool
        public let highContrast: Bool
        public let enhancedVoiceOver: Bool
    }
}

// MARK: - Enhanced Accessibility View Modifiers

public struct EnhancedAccessibilityModifier: ViewModifier {
    let element: EnhancedAccessibilityManager.AccessibilityElement
    let context: EnhancedAccessibilityManager.AccessibilityContext?

    @StateObject private var accessibilityManager = EnhancedAccessibilityManager.shared

    public init(
        element: EnhancedAccessibilityManager.AccessibilityElement,
        context: EnhancedAccessibilityManager.AccessibilityContext? = nil
    ) {
        self.element = element
        self.context = context
    }

    public func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(enhancedDescription)
            .accessibilityHint(actionHints)
            .accessibilityAddTraits(accessibilityTraits)
            .font(accessibilityManager.adaptiveFont(.body))
            .foregroundColor(accessibilityManager.accessibleColors.textPrimary)
    }

    private var enhancedDescription: String {
        if let context = context {
            return accessibilityManager.enhancedVoiceOverDescription(for: element, context: context)
        }
        return element.baseDescription
    }

    private var actionHints: String {
        element.actionHints?.joined(separator: ", ") ?? ""
    }

    private var accessibilityTraits: AccessibilityTraits {
        switch element.type {
        case .button:
            return .isButton
        case .card:
            return [.isButton, .allowsDirectInteraction]
        case .text:
            return .isStaticText
        case .heading:
            return .isHeader
        case .list:
            return .allowsDirectInteraction
        case .navigation:
            return [.isButton, .allowsDirectInteraction]
        }
    }
}

public struct SpatialAudioModifier: ViewModifier {
    let element: EnhancedAccessibilityManager.AccessibilityElement
    let location: CGPoint
    let bounds: CGSize

    @StateObject private var accessibilityManager = EnhancedAccessibilityManager.shared

    public init(
        element: EnhancedAccessibilityManager.AccessibilityElement,
        location: CGPoint,
        bounds: CGSize
    ) {
        self.element = element
        self.location = location
        self.bounds = bounds
    }

    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                if #available(iOS 26.0, *) {
                    accessibilityManager.provideSpatialAudioCue(
                        for: element,
                        at: location,
                        in: bounds
                    )
                }
            }
    }
}

// MARK: - Environment Integration

private struct EnhancedAccessibilityManagerKey: EnvironmentKey {
    static let defaultValue = EnhancedAccessibilityManager.shared
}

public extension EnvironmentValues {
    var enhancedAccessibility: EnhancedAccessibilityManager {
        get { self[EnhancedAccessibilityManagerKey.self] }
        set { self[EnhancedAccessibilityManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Applies enhanced accessibility features
    func enhancedAccessibility(
        element: EnhancedAccessibilityManager.AccessibilityElement,
        context: EnhancedAccessibilityManager.AccessibilityContext? = nil
    ) -> some View {
        modifier(EnhancedAccessibilityModifier(element: element, context: context))
    }

    /// Applies spatial audio cues for accessibility
    func spatialAudioCue(
        element: EnhancedAccessibilityManager.AccessibilityElement,
        location: CGPoint = .zero,
        bounds: CGSize = CGSize(width: 100, height: 100)
    ) -> some View {
        modifier(SpatialAudioModifier(element: element, location: location, bounds: bounds))
    }

    /// Applies accessibility-adapted colors
    func accessibleColors() -> some View {
        let manager = EnhancedAccessibilityManager.shared
        return self
            .foregroundColor(manager.accessibleColors.textPrimary)
            .background(manager.accessibleColors.background)
    }

    /// Quick accessibility setup for dashboard cards
    func dashboardCardAccessibility(
        title: String,
        value: String,
        isSelected: Bool = false,
        actions: [String] = ["激活", "查看详情"]
    ) -> some View {
        let element = EnhancedAccessibilityManager.AccessibilityElement(
            id: UUID().uuidString,
            type: .card,
            baseDescription: "\(title): \(value)",
            actionHints: actions,
            currentState: isSelected ? "已选中" : "未选中"
        )

        return enhancedAccessibility(element: element)
    }

    /// Quick accessibility setup for buttons
    func buttonAccessibility(
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        let element = EnhancedAccessibilityManager.AccessibilityElement(
            id: UUID().uuidString,
            type: .button,
            baseDescription: label,
            actionHints: hint.map { [$0] },
            currentState: isEnabled ? "可用" : "不可用"
        )

        return enhancedAccessibility(element: element)
    }
}