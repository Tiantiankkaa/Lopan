//
//  CompactStatIndicator.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Compact segmented-style status indicator for dashboard stats
//

import SwiftUI
import UIKit

/// A compact, pill-shaped status indicator that displays a value with icon and title.
/// Designed to replace larger status cards with minimal space usage while maintaining functionality.
public struct CompactStatIndicator: View {

    // MARK: - Public Properties

    let title: String
    let value: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let isPrimary: Bool
    let onTap: () -> Void

    // MARK: - Environment & Metrics

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 6
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var minCapsuleWidth: CGFloat = 80

    // MARK: - Private State

    @State private var isPressed = false

    // MARK: - Initializer

    public init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        isSelected: Bool = false,
        isPrimary: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.isPrimary = isPrimary
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        Button(action: handleTap) {
            indicatorContent
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(isSelected ? "已选中，点击取消筛选" : "点击筛选\(title)记录")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Indicator Content

    private var indicatorContent: some View {
        VStack(spacing: 3) {
            // Icon centered at top (Line 1)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity)

            // Prominent number in middle (Line 2)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText(value: numericValue))
                .frame(maxWidth: .infinity)

            // Small title at bottom (Line 3)
            Text(title)
                .font(.caption2.weight(.regular))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity)
        .frame(minWidth: minCapsuleWidth)
        .frame(height: 60)
        .background(indicatorBackground)
        .overlay(indicatorBorder)
    }

    // MARK: - Visual Components

    private var indicatorBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundColor)
    }

    private var indicatorBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    // MARK: - Computed Properties

    // Numeric value for smooth transition animations
    private var numericValue: Double {
        Double(value.filter { $0.isNumber }) ?? 0
    }

    private var iconColor: Color {
        if isSelected {
            return color
        }
        return LopanColors.textSecondary.opacity(colorScheme == .dark ? 0.8 : 0.7)
    }

    private var textColor: Color {
        if isSelected {
            return color
        }
        return LopanColors.textPrimary
    }

    private var subtitleColor: Color {
        if isSelected {
            return color.opacity(colorScheme == .dark ? 0.8 : 0.9)
        }
        return LopanColors.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return color.opacity(colorScheme == .dark ? 0.15 : 0.08)
        }
        return LopanColors.backgroundSecondary.opacity(colorScheme == .dark ? 0.6 : 0.8)
    }

    private var borderColor: Color {
        if isSelected {
            return color.opacity(colorScheme == .dark ? 0.6 : 0.4)
        }
        return LopanColors.border.opacity(0.3)
    }

    private var borderWidth: CGFloat {
        isSelected ? 1.5 : 0.5
    }

    // MARK: - Actions

    private func handleTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        onTap()
    }
}

// MARK: - Preview Provider

#Preview("CompactStatIndicator - Individual") {
    VStack(spacing: 16) {
        CompactStatIndicator(
            title: "总计",
            value: "142",
            icon: "circle.fill",
            color: LopanColors.primary,
            isSelected: true,
            isPrimary: true
        )

        CompactStatIndicator(
            title: "待处理",
            value: "28",
            icon: "clock.fill",
            color: LopanColors.warning
        )

        CompactStatIndicator(
            title: "已完成",
            value: "96",
            icon: "checkmark.circle.fill",
            color: LopanColors.success,
            isSelected: false
        )

        CompactStatIndicator(
            title: "已退货",
            value: "18",
            icon: "arrow.uturn.left",
            color: LopanColors.error
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("CompactStatIndicator - Horizontal Layout") {
    HStack(spacing: 8) {
        CompactStatIndicator(
            title: "总计",
            value: "142",
            icon: "circle.fill",
            color: LopanColors.primary,
            isSelected: true,
            isPrimary: true
        )

        CompactStatIndicator(
            title: "待处理",
            value: "28",
            icon: "clock.fill",
            color: LopanColors.warning
        )

        CompactStatIndicator(
            title: "已完成",
            value: "96",
            icon: "checkmark.circle.fill",
            color: LopanColors.success
        )

        CompactStatIndicator(
            title: "已退货",
            value: "18",
            icon: "arrow.uturn.left",
            color: LopanColors.error
        )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .frame(height: 48)
    .background(Color(.systemGroupedBackground))
}