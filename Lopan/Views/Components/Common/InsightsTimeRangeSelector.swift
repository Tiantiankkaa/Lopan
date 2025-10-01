//
//  InsightsTimeRangeSelector.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Modern time range selector for Insights with iOS 26 Liquid Glass design
//

import SwiftUI

// MARK: - Time Range Selector

/// Modern time range selector with liquid glass morphism and fluid animations
struct InsightsTimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    @Binding var showCustomDatePicker: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation

    private let quickRanges: [TimeRange] = [.today, .thisWeek, .thisMonth]

    init(
        selectedRange: Binding<TimeRange>,
        showCustomDatePicker: Binding<Bool>
    ) {
        self._selectedRange = selectedRange
        self._showCustomDatePicker = showCustomDatePicker
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(quickRanges, id: \.self) { range in
                TimeRangeButton(
                    range: range,
                    isSelected: selectedRange == range,
                    namespace: animation
                ) {
                    selectRange(range)
                }
            }

            // Custom range button
            TimeRangeButton(
                range: .custom,
                isSelected: selectedRange == .custom,
                namespace: animation
            ) {
                showCustomDatePicker = true
                selectedRange = .custom
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
    }

    private func selectRange(_ range: TimeRange) {
        withAnimation(
            FluidAnimationManager.shared.createAnimation(.filterApply)
        ) {
            selectedRange = range
        }

        // Haptic feedback with micro-interaction
        FluidAnimationManager.shared.triggerMicroInteraction(.selection)
    }
}

// MARK: - Time Range Button

private struct TimeRangeButton: View {
    let range: TimeRange
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 6) {
                // Icon for custom range
                if range == .custom {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor)
                }

                Text(range.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(buttonBackground)
            .overlay(selectionIndicator)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isSelected {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LopanColors.primary.opacity(0.15))
                    .matchedGeometryEffect(id: "selection", in: namespace)

                RoundedRectangle(cornerRadius: 10)
                    .fill(LopanColors.Gradients.glassOverlay)
                    .blendMode(.overlay)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(LopanColors.primary.opacity(0.3), lineWidth: 1.5)
        }
    }

    private var textColor: Color {
        if isSelected {
            return LopanColors.primary
        } else {
            return LopanColors.textSecondary
        }
    }

    private func handleTap() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = false
            }
        }

        action()
    }
}

// MARK: - Analysis Mode Carousel

/// Modern carousel for switching between analysis modes with fluid animations
struct AnalysisModeCarousel: View {
    @Binding var selectedMode: AnalysisMode

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation

    private let modes = AnalysisMode.allCases

    init(selectedMode: Binding<AnalysisMode>) {
        self._selectedMode = selectedMode
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(modes, id: \.self) { mode in
                ModeSegmentButton(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    namespace: animation
                ) {
                    selectMode(mode)
                }
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func selectMode(_ mode: AnalysisMode) {
        withAnimation(
            FluidAnimationManager.shared.createAnimation(.navigationTransition)
        ) {
            selectedMode = mode
        }

        // Medium haptic feedback with micro-interaction for mode change
        FluidAnimationManager.shared.triggerMicroInteraction(.mediumTap)
    }
}

// MARK: - Mode Segment Button

private struct ModeSegmentButton: View {
    let mode: AnalysisMode
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: 5) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)

                Text(mode.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(segmentBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
    }

    @ViewBuilder
    private var segmentBackground: some View {
        if isSelected {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [
                                LopanColors.primary.opacity(0.15),
                                LopanColors.Jewel.sapphire.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .matchedGeometryEffect(id: "modeSelection", in: namespace)

                // Glass overlay
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)

                // Border highlight
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        LopanColors.primary.opacity(0.4),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: LopanColors.primary.opacity(0.15), radius: 6, x: 0, y: 2)
        } else {
            Color.clear
        }
    }

    private var iconColor: Color {
        if isSelected {
            return LopanColors.primary
        } else {
            return LopanColors.textSecondary
        }
    }

    private var textColor: Color {
        if isSelected {
            return LopanColors.textPrimary
        } else {
            return LopanColors.textSecondary
        }
    }

    private func handleTap() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = false
            }
        }

        action()
    }
}

// MARK: - Compact Time Range Selector

/// Compact version for limited space (e.g., inside modals or sheets)
struct CompactTimeRangeSelector: View {
    @Binding var selectedRange: TimeRange

    @Environment(\.colorScheme) private var colorScheme

    init(selectedRange: Binding<TimeRange>) {
        self._selectedRange = selectedRange
    }

    public var body: some View {
        Menu {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation {
                        selectedRange = range
                    }
                } label: {
                    Label(range.displayName, systemImage: range == selectedRange ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))

                Text(selectedRange.displayName)
                    .font(.system(size: 14, weight: .medium))

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(LopanColors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(LopanColors.primary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Accessibility Enhancements

extension InsightsTimeRangeSelector {
    /// Accessibility label for time range selector
    public func accessibilityTimeRangeSelector() -> some View {
        self.accessibilityElement(children: .contain)
            .accessibilityLabel(Text("insights_time_range_selector"))
            .accessibilityHint(Text("insights_time_range_hint"))
    }
}

extension AnalysisModeCarousel {
    /// Accessibility label for mode carousel
    public func accessibilityModeCarousel() -> some View {
        self.accessibilityElement(children: .contain)
            .accessibilityLabel(Text("insights_mode_carousel"))
            .accessibilityHint(Text("insights_mode_hint"))
    }
}

// MARK: - Preview

#Preview("Time Range Selector") {
    struct PreviewWrapper: View {
        @State private var selectedRange: TimeRange = .thisWeek
        @State private var showCustomDatePicker = false

        var body: some View {
            VStack(spacing: 20) {
                InsightsTimeRangeSelector(
                    selectedRange: $selectedRange,
                    showCustomDatePicker: $showCustomDatePicker
                )

                Text("Selected: \(selectedRange.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("Analysis Mode Carousel") {
    struct PreviewWrapper: View {
        @State private var selectedMode: AnalysisMode = .region

        var body: some View {
            VStack(spacing: 20) {
                AnalysisModeCarousel(selectedMode: $selectedMode)
                    .padding()

                Text("Selected: \(selectedMode.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("Compact Selector") {
    struct PreviewWrapper: View {
        @State private var selectedRange: TimeRange = .today

        var body: some View {
            VStack(spacing: 20) {
                CompactTimeRangeSelector(selectedRange: $selectedRange)

                Text("Selected: \(selectedRange.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}