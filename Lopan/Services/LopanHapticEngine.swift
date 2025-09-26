//
//  LopanHapticEngine.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI
import UIKit
import AVFoundation

/// Centralized haptic feedback service for Lopan production management app
/// Unifies simple haptic feedback with sophisticated contextual patterns
public final class LopanHapticEngine: ObservableObject {

    // MARK: - Singleton Instance

    public static let shared = LopanHapticEngine()

    // MARK: - Private Properties

    private let enhancedEngine = EnhancedHapticEngine.shared
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Settings

    @Published public var isEnabled: Bool = true
    @Published public var useEnhancedPatterns: Bool = true
    @Published public var respectsSystemSettings: Bool = true

    // MARK: - Private Computed Properties

    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }

    private var isHapticAllowed: Bool {
        guard isEnabled else { return false }
        guard !respectsSystemSettings || !UIAccessibility.isReduceMotionEnabled else { return false }
        guard !audioSession.isOtherAudioPlaying else { return false }
        return true
    }

    // MARK: - Initialization

    private init() {
        setupHapticEngine()
    }

    private func setupHapticEngine() {
        prepareGenerators()

        // Listen for system preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func accessibilitySettingsChanged() {
        objectWillChange.send()
    }

    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Basic Haptic Feedback (Legacy Support)

    /// Light haptic feedback - compatible with LopanHapticEngine.shared.light()
    public func light() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.light()
        } else {
            impactLight.impactOccurred()
        }
    }

    /// Medium haptic feedback - compatible with LopanHapticEngine.shared.medium()
    public func medium() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.medium()
        } else {
            impactMedium.impactOccurred()
        }
    }

    /// Heavy haptic feedback - compatible with LopanHapticEngine.shared.heavy()
    public func heavy() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.heavy()
        } else {
            impactHeavy.impactOccurred()
        }
    }

    /// Selection haptic feedback - compatible with LopanHapticEngine.shared.selection()
    public func selection() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.selection()
        } else {
            selectionGenerator.selectionChanged()
        }
    }

    /// Success haptic feedback - compatible with LopanHapticEngine.shared.success()
    public func success() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.success()
        } else {
            notification.notificationOccurred(.success)
        }
    }

    /// Warning haptic feedback - compatible with LopanHapticEngine.shared.warning()
    public func warning() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.warning()
        } else {
            notification.notificationOccurred(.warning)
        }
    }

    /// Error haptic feedback - compatible with LopanHapticEngine.shared.error()
    public func error() {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.error()
        } else {
            notification.notificationOccurred(.error)
        }
    }

    // MARK: - Enhanced Contextual Feedback

    /// Perform contextual haptic feedback for UI interactions
    public func perform(_ action: UIAction) {
        guard isHapticAllowed else { return }

        if useEnhancedPatterns {
            enhancedEngine.perform(action.toCustomerAction)
        } else {
            // Fall back to basic feedback
            action.basicFallback()
        }
    }

    /// Perform enhanced haptic patterns directly
    internal func performEnhanced(_ action: EnhancedHapticEngine.CustomerAction) {
        guard isHapticAllowed else { return }
        enhancedEngine.perform(action)
    }

    // MARK: - UI Action Definitions

    public enum UIAction {
        // Button interactions
        case buttonTap
        case buttonLongPress
        case primaryAction
        case secondaryAction
        case destructiveAction

        // Navigation
        case navigationTap
        case tabSwitch
        case backNavigation
        case modalPresent
        case modalDismiss

        // List interactions
        case listItemTap
        case listItemSelect
        case listItemDeselect
        case swipeAction
        case pullToRefresh

        // Form interactions
        case textInput
        case formSubmit
        case formValidationError
        case formValidationSuccess

        // Data operations
        case dataLoad
        case dataLoadSuccess
        case dataLoadError
        case dataSave
        case dataSaveSuccess
        case dataSaveError

        // Batch operations
        case batchModeEnter
        case batchModeExit
        case batchSelect
        case batchDeselect
        case batchExecute

        // Search and filter
        case searchInput
        case searchResultFound
        case searchNoResults
        case filterApply
        case filterClear

        // Custom patterns
        case celebration
        case notification
        case alert

        var toCustomerAction: EnhancedHapticEngine.CustomerAction {
            switch self {
            case .buttonTap, .navigationTap, .tabSwitch, .listItemTap:
                return .cardTap
            case .buttonLongPress:
                return .cardLongPress
            case .primaryAction, .dataSave, .formSubmit:
                return .formSaveSuccess
            case .secondaryAction:
                return .cardTap
            case .destructiveAction:
                return .customerDeleted
            case .backNavigation, .modalDismiss:
                return .batchModeExit
            case .modalPresent:
                return .batchModeEnter
            case .listItemSelect, .batchSelect:
                return .selectionToggle
            case .listItemDeselect, .batchDeselect:
                return .selectionToggle
            case .swipeAction:
                return .swipeActionReveal
            case .pullToRefresh:
                return .refreshPullComplete
            case .textInput:
                return .cardTap
            case .formValidationError, .dataLoadError, .dataSaveError:
                return .formValidationError
            case .formValidationSuccess, .dataLoadSuccess, .dataSaveSuccess:
                return .formSaveSuccess
            case .dataLoad:
                return .refreshPullStart
            case .batchModeEnter:
                return .batchModeEnter
            case .batchModeExit:
                return .batchModeExit
            case .batchExecute:
                return .bulkActionExecute
            case .searchInput:
                return .cardTap
            case .searchResultFound:
                return .searchResultFound
            case .searchNoResults:
                return .searchNoResults
            case .filterApply:
                return .filterApply
            case .filterClear:
                return .filterClear
            case .celebration:
                return .customerAdded
            case .notification:
                return .customerUpdated
            case .alert:
                return .formValidationError
            }
        }

        func basicFallback() {
            switch self {
            case .buttonTap, .navigationTap, .tabSwitch, .listItemTap, .textInput, .searchInput:
                LopanHapticEngine.shared.light()
            case .buttonLongPress, .primaryAction, .swipeAction, .filterApply:
                LopanHapticEngine.shared.medium()
            case .destructiveAction, .batchExecute:
                LopanHapticEngine.shared.heavy()
            case .listItemSelect, .listItemDeselect, .batchSelect, .batchDeselect:
                LopanHapticEngine.shared.selection()
            case .formValidationSuccess, .dataSaveSuccess, .dataLoadSuccess, .celebration:
                LopanHapticEngine.shared.success()
            case .searchNoResults, .notification, .alert:
                LopanHapticEngine.shared.warning()
            case .formValidationError, .dataLoadError, .dataSaveError:
                LopanHapticEngine.shared.error()
            default:
                LopanHapticEngine.shared.light()
            }
        }
    }

    // MARK: - Smart Feedback Suggestions

    /// Get suggested haptic feedback based on context
    public func suggestedAction(for context: FeedbackContext) -> UIAction {
        switch context {
        case .button(let style, let size):
            return buttonActionForStyle(style, size: size)
        case .navigation(let type):
            return navigationActionForType(type)
        case .list(let action, let isMultiSelect):
            return listActionForAction(action, isMultiSelect: isMultiSelect)
        case .form(let validation):
            return formActionForValidation(validation)
        case .data(let operation, let success):
            return dataActionForOperation(operation, success: success)
        }
    }

    public enum FeedbackContext {
        case button(style: ButtonStyle, size: ButtonSize)
        case navigation(type: NavigationType)
        case list(action: ListAction, isMultiSelect: Bool)
        case form(validation: FormValidation)
        case data(operation: DataOperation, success: Bool)

        public enum ButtonStyle {
            case primary, secondary, destructive, ghost, outline
        }

        public enum ButtonSize {
            case small, medium, large
        }

        public enum NavigationType {
            case forward, backward, tab, modal
        }

        public enum ListAction {
            case tap, select, swipe, refresh
        }

        public enum FormValidation {
            case valid, invalid, submitting, submitted
        }

        public enum DataOperation {
            case loading, saving, deleting, creating
        }
    }

    private func buttonActionForStyle(_ style: FeedbackContext.ButtonStyle, size: FeedbackContext.ButtonSize) -> UIAction {
        switch style {
        case .primary:
            return .primaryAction
        case .secondary:
            return .secondaryAction
        case .destructive:
            return .destructiveAction
        case .ghost, .outline:
            return .buttonTap
        }
    }

    private func navigationActionForType(_ type: FeedbackContext.NavigationType) -> UIAction {
        switch type {
        case .forward:
            return .navigationTap
        case .backward:
            return .backNavigation
        case .tab:
            return .tabSwitch
        case .modal:
            return .modalPresent
        }
    }

    private func listActionForAction(_ action: FeedbackContext.ListAction, isMultiSelect: Bool) -> UIAction {
        switch action {
        case .tap:
            return .listItemTap
        case .select:
            return isMultiSelect ? .batchSelect : .listItemSelect
        case .swipe:
            return .swipeAction
        case .refresh:
            return .pullToRefresh
        }
    }

    private func formActionForValidation(_ validation: FeedbackContext.FormValidation) -> UIAction {
        switch validation {
        case .valid:
            return .formValidationSuccess
        case .invalid:
            return .formValidationError
        case .submitting:
            return .formSubmit
        case .submitted:
            return .formValidationSuccess
        }
    }

    private func dataActionForOperation(_ operation: FeedbackContext.DataOperation, success: Bool) -> UIAction {
        switch (operation, success) {
        case (.loading, true):
            return .dataLoadSuccess
        case (.loading, false):
            return .dataLoadError
        case (.saving, true):
            return .dataSaveSuccess
        case (.saving, false):
            return .dataSaveError
        case (.deleting, true):
            return .destructiveAction
        case (.deleting, false):
            return .dataSaveError
        case (.creating, true):
            return .celebration
        case (.creating, false):
            return .dataSaveError
        }
    }

    // MARK: - Accessibility Integration

    /// Provide haptic feedback with accessibility considerations
    public func accessibleFeedback(for action: UIAction, announcement: String? = nil) {
        if UIAccessibility.isVoiceOverRunning {
            if let announcement = announcement {
                LopanAccessibilityAnnouncer.announce(announcement)
            }
        } else {
            perform(action)
        }
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Add haptic feedback to any view
    public func lopanHaptic(
        _ action: LopanHapticEngine.UIAction,
        trigger: Bool = true,
        engine: LopanHapticEngine = .shared
    ) -> some View {
        self.onChange(of: trigger) { _, newValue in
            if newValue {
                engine.perform(action)
            }
        }
    }

    /// Add haptic feedback to tap gestures
    public func lopanHapticTap(
        _ action: LopanHapticEngine.UIAction = .buttonTap,
        engine: LopanHapticEngine = .shared
    ) -> some View {
        self.onTapGesture {
            engine.perform(action)
        }
    }

    /// Add contextual haptic feedback
    public func lopanContextualHaptic(
        for context: LopanHapticEngine.FeedbackContext,
        engine: LopanHapticEngine = .shared
    ) -> some View {
        self.onTapGesture {
            let action = engine.suggestedAction(for: context)
            engine.perform(action)
        }
    }
}

// MARK: - Legacy Support Bridge

/// Bridge for migrating from old HapticFeedback struct
public struct LopanHapticFeedback {
    private static let engine = LopanHapticEngine.shared

    public static func light() { engine.light() }
    public static func medium() { engine.medium() }
    public static func heavy() { engine.heavy() }
    public static func selection() { engine.selection() }
    public static func success() { engine.success() }
    public static func warning() { engine.warning() }
    public static func error() { engine.error() }
}

// MARK: - Performance Monitoring

extension LopanHapticEngine {
    #if DEBUG
    /// Monitor haptic feedback performance
    public func enablePerformanceMonitoring() {
        // Implementation for debugging haptic performance
        print("🎯 LopanHapticEngine performance monitoring enabled")
    }
    #endif
}

// MARK: - Configuration

extension LopanHapticEngine {
    /// Configure haptic engine settings
    public func configure(
        isEnabled: Bool = true,
        useEnhancedPatterns: Bool = true,
        respectsSystemSettings: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.useEnhancedPatterns = useEnhancedPatterns
        self.respectsSystemSettings = respectsSystemSettings
    }

    /// Reset to default settings
    public func resetToDefaults() {
        configure()
        prepareGenerators()
    }
}

// MARK: - Preview

#if DEBUG
struct LopanHapticEngineTestView: View {
    @StateObject private var hapticEngine = LopanHapticEngine.shared

    var body: some View {
        NavigationView {
            List {
                Section("基础触觉反馈") {
                    Button("轻触") { hapticEngine.light() }
                    Button("中等") { hapticEngine.medium() }
                    Button("强烈") { hapticEngine.heavy() }
                    Button("选择") { hapticEngine.selection() }
                    Button("成功") { hapticEngine.success() }
                    Button("警告") { hapticEngine.warning() }
                    Button("错误") { hapticEngine.error() }
                }

                Section("UI 交互") {
                    Button("按钮点击") { hapticEngine.perform(.buttonTap) }
                    Button("主要操作") { hapticEngine.perform(.primaryAction) }
                    Button("危险操作") { hapticEngine.perform(.destructiveAction) }
                    Button("导航点击") { hapticEngine.perform(.navigationTap) }
                    Button("列表选择") { hapticEngine.perform(.listItemSelect) }
                    Button("滑动操作") { hapticEngine.perform(.swipeAction) }
                }

                Section("数据操作") {
                    Button("保存成功") { hapticEngine.perform(.dataSaveSuccess) }
                    Button("保存失败") { hapticEngine.perform(.dataSaveError) }
                    Button("加载完成") { hapticEngine.perform(.dataLoadSuccess) }
                    Button("庆祝") { hapticEngine.perform(.celebration) }
                }

                Section("设置") {
                    Toggle("启用触觉反馈", isOn: $hapticEngine.isEnabled)
                    Toggle("使用增强模式", isOn: $hapticEngine.useEnhancedPatterns)
                    Toggle("遵循系统设置", isOn: $hapticEngine.respectsSystemSettings)
                }
            }
            .navigationTitle("触觉反馈测试")
        }
    }
}

#Preview {
    LopanHapticEngineTestView()
}
#endif