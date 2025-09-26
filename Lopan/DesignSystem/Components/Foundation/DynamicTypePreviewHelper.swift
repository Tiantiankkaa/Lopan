//
//  DynamicTypePreviewHelper.swift
//  Lopan
//
//  Created by Claude on 2025/9/22.
//

import SwiftUI

/// Dynamic Type preview utilities for iOS 26 accessibility compliance
/// Supports testing views at various Dynamic Type sizes including accessibility sizes
struct DynamicTypePreviewHelper {

    // MARK: - Dynamic Type Size Sets

    /// Standard Dynamic Type sizes for general testing
    static let standardSizes: [DynamicTypeSize] = [
        .small,
        .medium,
        .large,        // Default system size
        .xLarge,
        .xxLarge,
        .xxxLarge
    ]

    /// Accessibility Dynamic Type sizes for comprehensive testing
    static let accessibilitySizes: [DynamicTypeSize] = [
        .accessibility1,
        .accessibility2,
        .accessibility3,
        .accessibility4,
        .accessibility5
    ]

    /// All Dynamic Type sizes for complete testing
    static let allSizes: [DynamicTypeSize] = standardSizes + accessibilitySizes

    // MARK: - Critical Test Sizes

    /// Key sizes that must be tested for iOS 26 compliance
    static let criticalSizes: [DynamicTypeSize] = [
        .medium,          // System default
        .xxxLarge,        // Largest non-accessibility
        .accessibility3   // Mid-range accessibility
    ]
}

// MARK: - View Extensions for Dynamic Type Previews

extension View {
    /// Creates previews for critical Dynamic Type sizes
    func dynamicTypePreview() -> some View {
        Group {
            ForEach(DynamicTypePreviewHelper.criticalSizes, id: \.self) { size in
                self
                    .dynamicTypeSize(size)
                    .previewDisplayName("Dynamic Type: \(size.displayName)")
            }
        }
    }

    /// Creates previews for all accessibility Dynamic Type sizes
    func accessibilityDynamicTypePreview() -> some View {
        Group {
            ForEach(DynamicTypePreviewHelper.accessibilitySizes, id: \.self) { size in
                self
                    .dynamicTypeSize(size)
                    .previewDisplayName("Accessibility: \(size.displayName)")
            }
        }
    }

    /// Creates comprehensive Dynamic Type previews with light/dark mode
    func comprehensiveDynamicTypePreview() -> some View {
        Group {
            // Light mode previews
            ForEach(DynamicTypePreviewHelper.criticalSizes, id: \.self) { size in
                self
                    .dynamicTypeSize(size)
                    .preferredColorScheme(.light)
                    .previewDisplayName("Light - \(size.displayName)")
            }

            // Dark mode previews
            ForEach(DynamicTypePreviewHelper.criticalSizes, id: \.self) { size in
                self
                    .dynamicTypeSize(size)
                    .preferredColorScheme(.dark)
                    .previewDisplayName("Dark - \(size.displayName)")
            }
        }
    }
}

// MARK: - DynamicTypeSize Display Names

extension DynamicTypeSize {
    var displayName: String {
        switch self {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M (Default)"
        case .large: return "L"
        case .xLarge: return "XL"
        case .xxLarge: return "XXL"
        case .xxxLarge: return "XXXL"
        case .accessibility1: return "A1"
        case .accessibility2: return "A2"
        case .accessibility3: return "A3"
        case .accessibility4: return "A4"
        case .accessibility5: return "A5"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Multi-Locale Preview Helper

extension View {
    /// Creates previews with localization and Dynamic Type combinations
    func multiLocalePreview() -> some View {
        Group {
            // Chinese (Simplified) - Default
            self
                .dynamicTypeSize(.medium)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .previewDisplayName("中文 (M)")

            // Chinese (Simplified) - Large accessibility
            self
                .dynamicTypeSize(.accessibility3)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .previewDisplayName("中文 (A3)")

            // English - Default
            self
                .dynamicTypeSize(.medium)
                .environment(\.locale, Locale(identifier: "en"))
                .previewDisplayName("English (M)")

            // English - Large accessibility
            self
                .dynamicTypeSize(.accessibility3)
                .environment(\.locale, Locale(identifier: "en"))
                .previewDisplayName("English (A3)")

            // RTL - Arabic for layout testing
            self
                .dynamicTypeSize(.medium)
                .environment(\.locale, Locale(identifier: "ar"))
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName("RTL (M)")
        }
    }
}

// MARK: - iOS 26 Compliance Preview Group

struct iOS26CompliancePreview<Content: View>: View {
    let content: Content
    let title: String

    init(_ title: String = "iOS 26 Compliance", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Group {
            // Standard compliance test
            content
                .dynamicTypeSize(.medium)
                .preferredColorScheme(.light)
                .previewDisplayName("\(title) - Light (M)")

            // Dark mode test
            content
                .dynamicTypeSize(.medium)
                .preferredColorScheme(.dark)
                .previewDisplayName("\(title) - Dark (M)")

            // Accessibility size test
            content
                .dynamicTypeSize(.accessibility3)
                .preferredColorScheme(.light)
                .previewDisplayName("\(title) - Light (A3)")

            // RTL layout test
            content
                .dynamicTypeSize(.medium)
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName("\(title) - RTL (M)")
        }
    }
}

// MARK: - Usage Example Preview

#Preview("Dynamic Type Helper Examples") {
    iOS26CompliancePreview("Sample Card") {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            Text("产品名称")
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)

            Text("这是一个示例产品描述，用于测试动态字体大小在不同可访问性级别下的表现。")
                .font(.body)
                .foregroundColor(LopanColors.textSecondary)

            HStack {
                Button("主要操作") {
                    LopanHapticEngine.shared.light()
                }
                .foregroundColor(LopanColors.textOnPrimary)
                .padding(.horizontal, LopanSpacing.md)
                .padding(.vertical, LopanSpacing.sm)
                .background(LopanColors.primary)
                .cornerRadius(8)

                Button("次要操作") {
                    LopanHapticEngine.shared.light()
                }
                .foregroundColor(LopanColors.textPrimary)
                .padding(.horizontal, LopanSpacing.md)
                .padding(.vertical, LopanSpacing.sm)
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(8)
            }
        }
        .padding(LopanSpacing.md)
        .background(LopanColors.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: LopanColors.border, radius: 2, x: 0, y: 1)
    }
}