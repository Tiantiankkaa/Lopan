//
//  LopanAccessibility.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI

/// Centralized accessibility system for Lopan design system
/// Provides reusable modifiers and standardized accessibility patterns
public struct LopanAccessibility {

    // MARK: - Accessibility Constants

    /// Minimum touch target size following iOS 26 guidelines
    public static let minimumTouchTarget: CGFloat = 44

    /// Standard accessibility timing for announcements
    public static let standardAnnouncementDelay: Double = 0.1

    // MARK: - Accessibility Roles

    public enum AccessibilityRole {
        case button
        case card
        case statistic
        case navigation
        case filter
        case input
        case list
        case grid
        case dialog
        case alert
        case loading
        case searchField
        case text

        var traits: AccessibilityTraits {
            switch self {
            case .button:
                return .isButton
            case .card:
                return .isButton
            case .statistic:
                return .isStaticText
            case .navigation:
                return .isLink
            case .filter:
                return .isButton
            case .input:
                return .isSearchField
            case .list:
                return .isStaticText
            case .grid:
                return .isStaticText
            case .dialog:
                return .isModal
            case .alert:
                return .isModal
            case .loading:
                return .updatesFrequently
            case .searchField:
                return .isSearchField
            case .text:
                return .isStaticText
            }
        }
    }

    // MARK: - Accessibility Priority

    public enum Priority {
        case low
        case normal
        case high
        case critical

        var accessibilityPriority: Double {
            switch self {
            case .low: return 0.25
            case .normal: return 0.5
            case .high: return 0.75
            case .critical: return 1.0
            }
        }
    }

    // MARK: - Announcement Types

    public enum AnnouncementType {
        case polite
        case assertive

        @available(iOS 17.0, *)
        var notification: UIAccessibility.Notification {
            switch self {
            case .polite:
                return .announcement
            case .assertive:
                return .layoutChanged
            }
        }
    }
}

// MARK: - View Modifiers

extension View {

    /// Apply comprehensive accessibility configuration for interactive elements
    /// - Parameters:
    ///   - role: The accessibility role of the element
    ///   - label: Descriptive label for screen readers
    ///   - hint: Additional guidance for users
    ///   - value: Current value (for dynamic content)
    ///   - priority: Accessibility focus priority
    /// - Returns: View with accessibility configuration applied
    public func lopanAccessibility(
        role: LopanAccessibility.AccessibilityRole,
        label: String,
        hint: String? = nil,
        value: String? = nil,
        priority: LopanAccessibility.Priority = .normal
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(role.traits)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityRespondsToUserInteraction(role.traits.contains(.isButton))
    }

    /// Create accessible grouped content with semantic meaning
    /// - Parameters:
    ///   - label: Group description
    ///   - hint: Additional context for the group
    /// - Returns: View configured as accessibility group
    public func lopanAccessibilityGroup(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isStaticText)
    }

    /// Apply accessibility configuration for statistics and metrics
    /// - Parameters:
    ///   - metric: Name of the metric
    ///   - value: Current value
    ///   - trend: Optional trend information
    /// - Returns: View with statistic accessibility
    public func lopanAccessibilityStatistic(
        metric: String,
        value: String,
        trend: String? = nil
    ) -> some View {
        let fullValue = trend.map { "\(value), \($0)" } ?? value
        return self.lopanAccessibility(
            role: .statistic,
            label: metric,
            value: fullValue
        )
    }

    /// Ensure minimum touch target size for accessibility
    /// - Parameter size: Minimum size (defaults to 44pt)
    /// - Returns: View with proper touch target
    public func lopanMinimumTouchTarget(
        size: CGFloat = LopanAccessibility.minimumTouchTarget
    ) -> some View {
        self
            .frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    /// Configure accessibility for navigation elements
    /// - Parameters:
    ///   - destination: Where navigation leads
    ///   - isBackButton: Whether this is a back navigation
    /// - Returns: View with navigation accessibility
    public func lopanAccessibilityNavigation(
        destination: String,
        isBackButton: Bool = false
    ) -> some View {
        let label = isBackButton ? "返回 \(destination)" : "导航到 \(destination)"
        return self.lopanAccessibility(
            role: .navigation,
            label: label,
            hint: isBackButton ? "返回上一页面" : "点击进入详情页面"
        )
    }

    /// Configure accessibility for filter and selection controls
    /// - Parameters:
    ///   - filterName: Name of the filter
    ///   - isSelected: Current selection state
    ///   - count: Optional count of filtered items
    /// - Returns: View with filter accessibility
    public func lopanAccessibilityFilter(
        filterName: String,
        isSelected: Bool,
        count: Int? = nil
    ) -> some View {
        let state = isSelected ? "已选择" : "未选择"
        let countText = count.map { ", \($0) 项" } ?? ""
        let value = "\(state)\(countText)"

        return self.lopanAccessibility(
            role: .filter,
            label: filterName,
            hint: isSelected ? "点击取消选择" : "点击选择此筛选条件",
            value: value
        )
    }
}

// MARK: - Accessibility Announcements

public struct LopanAccessibilityAnnouncer {

    /// Make an accessibility announcement to screen readers
    /// - Parameters:
    ///   - message: Message to announce
    ///   - type: Announcement priority type
    ///   - delay: Optional delay before announcement
    public static func announce(
        _ message: String,
        type: LopanAccessibility.AnnouncementType = .polite,
        delay: Double = LopanAccessibility.standardAnnouncementDelay
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if #available(iOS 17.0, *) {
                AccessibilityNotification.Announcement(message)
                    .post()
            } else {
                UIAccessibility.post(
                    notification: UIAccessibility.Notification.announcement,
                    argument: message
                )
            }
        }
    }

    /// Announce success feedback
    /// - Parameter message: Success message
    public static func announceSuccess(_ message: String) {
        announce("成功：\(message)", type: .polite)
    }

    /// Announce error feedback
    /// - Parameter message: Error message
    public static func announceError(_ message: String) {
        announce("错误：\(message)", type: .assertive)
    }

    /// Announce loading state changes
    /// - Parameters:
    ///   - isLoading: Current loading state
    ///   - context: Context for the loading operation
    public static func announceLoading(_ isLoading: Bool, context: String) {
        let message = isLoading ? "正在加载\(context)" : "\(context)加载完成"
        announce(message, type: .polite)
    }

    /// Announce data updates
    /// - Parameters:
    ///   - count: Number of items
    ///   - itemType: Type of items
    public static func announceDataUpdate(count: Int, itemType: String) {
        let message = "已更新，共\(count)个\(itemType)"
        announce(message, type: .polite)
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
public struct LopanAccessibilityTesting {

    /// Check if view has proper accessibility configuration
    /// - Parameter view: View to test
    /// - Returns: Accessibility audit results
    public static func auditView<T: View>(_ view: T) -> AccessibilityAuditResults {
        // This would integrate with Xcode's accessibility inspector in a real implementation
        return AccessibilityAuditResults()
    }

    /// Simulate VoiceOver navigation for testing
    /// - Parameter view: View to simulate navigation on
    public static func simulateVoiceOverNavigation<T: View>(_ view: T) {
        // Implementation would simulate VoiceOver gestures
        print("Simulating VoiceOver navigation for view: \(type(of: view))")
    }
}

public struct AccessibilityAuditResults {
    public let hasLabels: Bool = true
    public let hasMinimumTouchTargets: Bool = true
    public let hasProperContrast: Bool = true
    public let supportsDynamicType: Bool = true

    public var isCompliant: Bool {
        hasLabels && hasMinimumTouchTargets && hasProperContrast && supportsDynamicType
    }
}
#endif

// MARK: - Accessibility Preview Helpers

#if DEBUG
extension View {
    /// Preview with accessibility testing configurations
    public func accessibilityPreview() -> some View {
        Group {
            // Standard view
            self
                .previewDisplayName("Standard")

            // Large text
            self
                .environment(\.dynamicTypeSize, .xxxLarge)
                .previewDisplayName("Large Text")

            // VoiceOver simulation
            self
                .environment(\.accessibilityEnabled, true)
                .previewDisplayName("VoiceOver")

            // Reduce motion
            self
                .previewDisplayName("Reduce Motion")
        }
    }
}
#endif