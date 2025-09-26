//
//  DynamicTypePreviewProvider.swift
//  Lopan
//
//  Dynamic Type preview generator for iOS 26 UI/UX compliance
//  Ensures all major screens support Dynamic Type at XL sizes
//

import SwiftUI

/// Dynamic Type size configurations for preview testing
public enum DynamicTypeTestSize: CaseIterable {
    case small
    case medium
    case large
    case extraLarge
    case extraExtraLarge
    case extraExtraExtraLarge
    case accessibility1
    case accessibility2
    case accessibility3
    case accessibility4
    case accessibility5

    var size: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .xLarge
        case .extraExtraLarge: return .xxLarge
        case .extraExtraExtraLarge: return .xxxLarge
        case .accessibility1: return .accessibility1
        case .accessibility2: return .accessibility2
        case .accessibility3: return .accessibility3
        case .accessibility4: return .accessibility4
        case .accessibility5: return .accessibility5
        }
    }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large (Default)"
        case .extraLarge: return "Extra Large"
        case .extraExtraLarge: return "XX Large"
        case .extraExtraExtraLarge: return "XXX Large"
        case .accessibility1: return "AX1"
        case .accessibility2: return "AX2"
        case .accessibility3: return "AX3"
        case .accessibility4: return "AX4"
        case .accessibility5: return "AX5 (Maximum)"
        }
    }

    var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}

/// Preview container for Dynamic Type testing
public struct DynamicTypePreview<Content: View>: View {
    let content: Content
    let sizes: [DynamicTypeTestSize]
    let showLabels: Bool
    let colorScheme: ColorScheme?

    public init(
        sizes: [DynamicTypeTestSize] = [.large, .extraExtraLarge, .accessibility2],
        showLabels: Bool = true,
        colorScheme: ColorScheme? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.sizes = sizes
        self.showLabels = showLabels
        self.colorScheme = colorScheme
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                ForEach(sizes, id: \.self) { testSize in
                    VStack(alignment: .leading, spacing: 8) {
                        if showLabels {
                            HStack {
                                Text(testSize.displayName)
                                    .font(.headline)
                                    .foregroundColor(LopanColors.textPrimary)

                                if testSize.isAccessibilitySize {
                                    Label("Accessibility", systemImage: "accessibility")
                                        .font(.caption)
                                        .foregroundColor(LopanColors.info)
                                        .labelStyle(.iconOnly)
                                }

                                Spacer()

                                Text(colorScheme == .dark ? "Dark" : "Light")
                                    .font(.caption)
                                    .foregroundColor(LopanColors.textSecondary)
                            }
                            .padding(.horizontal)

                            Divider()
                        }

                        content
                            .environment(\.dynamicTypeSize, testSize.size)
                            .conditionally(colorScheme != nil) { view in
                                view.environment(\.colorScheme, colorScheme!)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LopanColors.background)
                                    .shadow(
                                        color: LopanColors.shadow,
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            )
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(LopanColors.backgroundSecondary)
    }
}

/// Helper view modifier for conditional application
struct ConditionalModifier<Transform: View>: ViewModifier {
    let condition: Bool
    let transform: (Content) -> Transform

    func body(content: Content) -> some View {
        if condition {
            transform(content)
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func conditionally<Transform: View>(
        _ condition: Bool,
        transform: @escaping (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

/// Preview helper for generating Dynamic Type matrices
public struct DynamicTypeMatrix<Content: View>: View {
    let content: () -> Content
    let includeAccessibilitySizes: Bool

    public init(
        includeAccessibilitySizes: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.includeAccessibilitySizes = includeAccessibilitySizes
        self.content = content
    }

    private var sizes: [DynamicTypeTestSize] {
        if includeAccessibilitySizes {
            return [.medium, .large, .extraLarge, .extraExtraLarge, .accessibility1, .accessibility3]
        } else {
            return [.small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge]
        }
    }

    public var body: some View {
        TabView {
            // Light mode previews
            DynamicTypePreview(
                sizes: sizes,
                colorScheme: .light,
                content: content
            )
            .tabItem {
                Label("Light", systemImage: "sun.max")
            }

            // Dark mode previews
            DynamicTypePreview(
                sizes: sizes,
                colorScheme: .dark,
                content: content
            )
            .tabItem {
                Label("Dark", systemImage: "moon")
            }
        }
    }
}

// MARK: - Preview Providers for Major Screens

/// Preview provider specifically for QuickStatCard
public struct QuickStatCardDynamicTypePreviews: View {
    public var body: some View {
        DynamicTypeMatrix {
            HStack(spacing: 12) {
                QuickStatCard(
                    title: "总计",
                    value: "142",
                    icon: "list.bullet.rectangle.fill",
                    color: LopanColors.primary
                )

                QuickStatCard(
                    title: "待处理",
                    value: "28",
                    icon: "clock.fill",
                    color: LopanColors.warning,
                    trend: .up
                )
            }
            .padding()
        }
    }
}

/// Preview provider for Navigation Components
public struct NavigationComponentsDynamicTypePreviews: View {
    public var body: some View {
        DynamicTypeMatrix {
            VStack(spacing: 16) {
                Text("Navigation Bar")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LopanColors.primary.opacity(0.1))
                    .cornerRadius(8)

                Text("Dynamic Type Testing")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LopanColors.success.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()
        }
    }
}

// MARK: - Composite Preview for All Components

public struct AllComponentsDynamicTypePreview: View {
    public var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Quick Stats Section
                GroupBox(label: Text("Quick Stats Cards").font(.headline)) {
                    QuickStatCardDynamicTypePreviews()
                        .frame(height: 200)
                }

                // Navigation Components
                GroupBox(label: Text("Navigation Components").font(.headline)) {
                    NavigationComponentsDynamicTypePreviews()
                        .frame(height: 200)
                }
            }
            .padding()
        }
        .navigationTitle("Dynamic Type Tests")
    }
}

// MARK: - Accessibility Testing Helper

/// Helper view for testing text truncation and layout issues
public struct TextTruncationTester: View {
    let text: String
    let maxLines: Int?

    public init(_ text: String, maxLines: Int? = nil) {
        self.text = text
        self.maxLines = maxLines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original Text:")
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)

            Text(text)
                .lineLimit(maxLines)
                .minimumScaleFactor(maxLines != nil ? 0.7 : 1.0)
                .border(LopanColors.error.opacity(0.3), width: 1)

            if maxLines != nil {
                Text("Line limit: \(maxLines!)")
                    .font(.caption2)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Preview Providers

#Preview("Quick Stat Card - Dynamic Type") {
    QuickStatCardDynamicTypePreviews()
}

#Preview("Navigation Components - Dynamic Type") {
    NavigationComponentsDynamicTypePreviews()
}

#Preview("All Components - Dynamic Type Matrix") {
    AllComponentsDynamicTypePreview()
}

#Preview("Text Truncation Test") {
    DynamicTypePreview(
        sizes: [.large, .accessibility1, .accessibility5]
    ) {
        VStack(spacing: 16) {
            TextTruncationTester(
                "This is a long text that should wrap properly at all Dynamic Type sizes",
                maxLines: 2
            )

            TextTruncationTester(
                "客户名称可能会很长需要正确处理换行和截断的情况",
                maxLines: 1
            )

            TextTruncationTester(
                "无限制行数的文本应该能够完全显示所有内容并正确换行"
            )
        }
    }
}