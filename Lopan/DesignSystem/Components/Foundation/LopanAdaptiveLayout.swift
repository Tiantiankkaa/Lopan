//
//  LopanAdaptiveLayout.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI

/// Adaptive layout system for Lopan design system
/// Provides layouts that gracefully respond to Dynamic Type size changes
public struct LopanAdaptiveLayout {

    // MARK: - Dynamic Type Size Detection

    /// Check if current Dynamic Type size requires adaptive layout
    public static func isAdaptiveSize(_ dynamicTypeSize: DynamicTypeSize) -> Bool {
        switch dynamicTypeSize {
        case .large, .xLarge, .xxLarge, .xxxLarge,
             .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }

    /// Get adaptive spacing based on Dynamic Type size
    public static func adaptiveSpacing(
        base: CGFloat,
        for dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        if isAdaptiveSize(dynamicTypeSize) {
            return base * 1.5  // Increase spacing for large text
        }
        return base
    }

    /// Get adaptive padding based on Dynamic Type size
    public static func adaptivePadding(
        base: CGFloat,
        for dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        if isAdaptiveSize(dynamicTypeSize) {
            return base * 1.3  // Increase padding for large text
        }
        return base
    }

    // MARK: - Adaptive Layout Types

    public enum LayoutDirection {
        case horizontal
        case vertical
        case adaptive
    }

    public enum BreakpointBehavior {
        case stack      // Switch to VStack at breakpoint
        case wrap       // Wrap content at breakpoint
        case scroll     // Enable horizontal scrolling
    }
}

// MARK: - Adaptive Layout Views

/// Adaptive HStack that switches to VStack for large text sizes
public struct LopanAdaptiveHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    let breakpointBehavior: LopanAdaptiveLayout.BreakpointBehavior

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        breakpointBehavior: LopanAdaptiveLayout.BreakpointBehavior = .stack,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.breakpointBehavior = breakpointBehavior
        self.content = content()
    }

    public var body: some View {
        let shouldStack = LopanAdaptiveLayout.isAdaptiveSize(dynamicTypeSize)
        let adaptiveSpacing = spacing.map {
            LopanAdaptiveLayout.adaptiveSpacing(base: $0, for: dynamicTypeSize)
        }

        Group {
            if shouldStack && breakpointBehavior == .stack {
                VStack(alignment: .leading, spacing: adaptiveSpacing) {
                    content
                }
            } else if shouldStack && breakpointBehavior == .scroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: alignment, spacing: adaptiveSpacing) {
                        content
                    }
                    .padding(.horizontal)
                }
            } else {
                HStack(alignment: alignment, spacing: adaptiveSpacing) {
                    content
                }
            }
        }
    }
}

/// Adaptive VStack with dynamic spacing
public struct LopanAdaptiveVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let adaptiveSpacing = spacing.map {
            LopanAdaptiveLayout.adaptiveSpacing(base: $0, for: dynamicTypeSize)
        }

        VStack(alignment: alignment, spacing: adaptiveSpacing) {
            content
        }
    }
}

/// Adaptive Grid that adjusts columns based on Dynamic Type size
public struct LopanAdaptiveGrid<Content: View>: View {
    let columns: [GridItem]
    let spacing: CGFloat?
    let pinnedViews: PinnedScrollableViews
    let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        columns: [GridItem],
        spacing: CGFloat? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.content = content()
    }

    public var body: some View {
        let adaptiveColumns = getAdaptiveColumns()
        let adaptiveSpacing = spacing.map {
            LopanAdaptiveLayout.adaptiveSpacing(base: $0, for: dynamicTypeSize)
        }

        LazyVGrid(
            columns: adaptiveColumns,
            spacing: adaptiveSpacing,
            pinnedViews: pinnedViews
        ) {
            content
        }
    }

    private func getAdaptiveColumns() -> [GridItem] {
        if LopanAdaptiveLayout.isAdaptiveSize(dynamicTypeSize) {
            // For large text, reduce to single column or fewer columns
            if columns.count > 2 {
                return [GridItem(.flexible())]
            } else if columns.count == 2 {
                return [GridItem(.flexible())]
            }
        }
        return columns
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply adaptive padding that scales with Dynamic Type
    public func lopanAdaptivePadding(
        _ length: CGFloat
    ) -> some View {
        modifier(LegacyAdaptivePaddingModifier(edges: .all, padding: length))
    }

    /// Apply adaptive padding with different values for different edges
    public func lopanAdaptivePadding(
        _ edges: Edge.Set = .all,
        _ length: CGFloat
    ) -> some View {
        modifier(LegacyAdaptivePaddingModifier(edges: edges, padding: length))
    }

    /// Apply adaptive margins for card layouts
    public func lopanAdaptiveCardLayout() -> some View {
        modifier(AdaptiveCardLayoutModifier())
    }

    /// Apply adaptive minimum height based on Dynamic Type
    public func lopanAdaptiveMinHeight(
        _ height: CGFloat
    ) -> some View {
        modifier(AdaptiveMinHeightModifier(baseHeight: height))
    }
}

// MARK: - Adaptive Modifiers

private struct LegacyAdaptivePaddingModifier: ViewModifier {
    let edges: Edge.Set
    let padding: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(padding: CGFloat) {
        self.edges = .all
        self.padding = padding
    }

    init(edges: Edge.Set, padding: CGFloat) {
        self.edges = edges
        self.padding = padding
    }

    func body(content: Content) -> some View {
        let adaptivePadding = LopanAdaptiveLayout.adaptivePadding(
            base: padding,
            for: dynamicTypeSize
        )
        content.padding(edges, adaptivePadding)
    }
}

private struct AdaptiveCardLayoutModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let isLarge = LopanAdaptiveLayout.isAdaptiveSize(dynamicTypeSize)
        let padding = isLarge ? LopanSpacing.lg : LopanSpacing.md
        let cornerRadius = isLarge ? LopanCornerRadius.card * 1.2 : LopanCornerRadius.card

        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LopanColors.surface)
            )
    }
}

private struct AdaptiveMinHeightModifier: ViewModifier {
    let baseHeight: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let isLarge = LopanAdaptiveLayout.isAdaptiveSize(dynamicTypeSize)
        let adaptiveHeight = isLarge ? baseHeight * 1.4 : baseHeight

        content.frame(minHeight: adaptiveHeight)
    }
}

// MARK: - Responsive Breakpoints

public struct LopanBreakpoints {
    /// Minimum width for horizontal layout in adaptive components
    public static let horizontalMinWidth: CGFloat = 320

    /// Maximum text size category before forcing vertical layouts
    public static let maxHorizontalTextSize: ContentSizeCategory = .extraLarge

    /// Get preferred layout direction based on available width and text size
    public static func preferredDirection(
        width: CGFloat,
        textSize: ContentSizeCategory
    ) -> LopanAdaptiveLayout.LayoutDirection {
        if textSize > maxHorizontalTextSize || width < horizontalMinWidth {
            return .vertical
        }
        return .horizontal
    }
}

// MARK: - Adaptive Form Layouts

/// Adaptive form row that stacks label and input on small screens or large text
public struct LopanAdaptiveFormRow<Label: View, Input: View>: View {
    let label: Label
    let input: Input
    let spacing: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        spacing: CGFloat = LopanSpacing.sm,
        @ViewBuilder label: () -> Label,
        @ViewBuilder input: () -> Input
    ) {
        self.spacing = spacing
        self.label = label()
        self.input = input()
    }

    public var body: some View {
        let shouldStack = LopanAdaptiveLayout.isAdaptiveSize(dynamicTypeSize)
        let adaptiveSpacing = LopanAdaptiveLayout.adaptiveSpacing(
            base: spacing,
            for: dynamicTypeSize
        )

        if shouldStack {
            VStack(alignment: .leading, spacing: adaptiveSpacing) {
                label
                input
            }
        } else {
            HStack(spacing: adaptiveSpacing) {
                label
                Spacer()
                input
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: LopanSpacing.lg) {
        LopanAdaptiveHStack {
            Text("Label")
                .lopanLabelMedium()
            Spacer()
            Text("Value")
                .lopanBodyMedium()
        }
        .lopanAdaptivePadding(LopanSpacing.md)
        .background(LopanColors.surface)

        LopanAdaptiveGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]) {
            ForEach(0..<4, id: \.self) { index in
                Text("Item \(index)")
                    .lopanBodyMedium()
                    .lopanAdaptiveCardLayout()
            }
        }

        LopanAdaptiveFormRow {
            Text("Username")
                .lopanLabelMedium()
        } input: {
            TextField("Enter username", text: .constant(""))
                .textFieldStyle(.roundedBorder)
        }
    }
    .padding()
    .accessibilityPreview()
}