//
//  QuickStatCard.swift
//  Lopan
//
//  Extracted from CustomerOutOfStockDashboard
//  iOS 26 UI/UX compliant reusable statistics card component
//

import SwiftUI
import Foundation
import os.log

/// A reusable quick statistics card component for displaying metrics
/// Follows iOS 26 design guidelines with Dynamic Type support and accessibility
public struct QuickStatCard: View {
    // MARK: - Properties

    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Trend?
    let associatedStatus: OutOfStockStatus?
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void

    // Modern visual enhancement properties
    private let cardStyle: CardStyle
    private let enhancementLevel: VisualEnhancementLevel
    @State private var isPressed = false
    @State private var animatedValue: Double = 0
    @StateObject private var visualComposer = VisualEffectsComposer.shared

    private var cardCornerRadius: CGFloat { 12 }

    /// Determines card style based on color and status
    private var computedCardStyle: CardStyle {
        if color == LopanColors.success { return .success }
        if color == LopanColors.warning { return .warning }
        if color == LopanColors.error { return .error }
        if color == LopanColors.primary { return .primary }
        return .neutral
    }

    // MARK: - Trend Type

    public enum Trend {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return LopanColors.success
            case .down: return LopanColors.error
            case .stable: return LopanColors.textSecondary
            }
        }
    }

    // MARK: - Initializer

    public init(
        title: String,
        value: String,
        icon: String,
        color: Color = LopanColors.primary,
        trend: Trend? = nil,
        associatedStatus: OutOfStockStatus? = nil,
        isSelected: Bool = false,
        isLocked: Bool = false,
        cardStyle: CardStyle? = nil,
        enhancementLevel: VisualEnhancementLevel = .adaptive,
        onTap: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
        self.associatedStatus = associatedStatus
        self.isSelected = isSelected
        self.isLocked = isLocked
        self.cardStyle = cardStyle ?? {
            if color == LopanColors.success { return .success }
            if color == LopanColors.warning { return .warning }
            if color == LopanColors.error { return .error }
            if color == LopanColors.primary { return .primary }
            return .neutral
        }()
        self.enhancementLevel = enhancementLevel
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        Button(action: {
            onTap()
            triggerHapticFeedback()
        }) {
            modernCardContent
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .allowsHitTesting(!isLocked)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            animateValueIfNeeded()
        }
        .onChange(of: value) { _ in
            animateValueIfNeeded()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(isLocked ? "数据加载中" : "双击查看详情")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Modern Card Content

    @ViewBuilder
    private var modernCardContent: some View {
        VStack(spacing: 10) {
            // Enhanced header with icon and trend
            HStack {
                ZStack {
                    // Icon glow effect
                    if visualComposer.enhancementLevel != .minimal && !isLocked {
                        Circle()
                            .fill(jewelToneColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .blur(radius: 4)
                    }

                    Image(systemName: icon)
                        .imageScale(.medium)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                        .shadow(color: jewelToneColor.opacity(0.3), radius: 4)
                }

                Spacer()

                if let trend = trend {
                    trendBadge(trend)
                }
            }

            // Enhanced value and title
            VStack(spacing: 4) {
                // Animated value
                AnimatedNumberText(value: value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(
                        visualComposer.enhancementLevel == .minimal
                            ? primaryTextColor : primaryTextColor
                    )
                    .overlay(
                        visualComposer.enhancementLevel != .minimal ?
                        LinearGradient(
                            colors: [primaryTextColor, jewelToneColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            AnimatedNumberText(value: value)
                                .font(.title2.weight(.bold))
                                .monospacedDigit()
                        ) : nil
                    )
                    .minimumScaleFactor(0.6)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(modernCardBackground)
        .overlay(modernCardBorder)
        .opacity(isLocked ? 0.7 : 1.0)
    }

    // MARK: - Modern Card Background

    @ViewBuilder
    private var modernCardBackground: some View {
        ZStack {
            // Base background
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemBackground))

            // Glassmorphic overlay
            if visualComposer.enhancementLevel != .minimal {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius)
                            .fill(gradientOverlay)
                    )
            }

            // Neumorphic effect for pressed state
            if isPressed && visualComposer.enhancementLevel == .premium {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.5), radius: 5, x: -2, y: -2)
            }
        }
        .elevationShadow(isSelected ? .floating : .elevated)
    }

    // MARK: - Modern Card Border

    @ViewBuilder
    private var modernCardBorder: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .stroke(
                isSelected
                    ? jewelToneColor.opacity(0.8)
                    : (visualComposer.enhancementLevel == .minimal
                        ? Color.clear
                        : jewelToneColor.opacity(0.3)),
                lineWidth: isSelected ? 2.5 : 1
            )
    }

    // MARK: - Color Computed Properties

    private var jewelToneColor: Color {
        visualComposer.jewelTone(for: computedCardStyle)
    }

    private var gradientOverlay: LinearGradient {
        LinearGradient(
            colors: [
                jewelToneColor.opacity(0.1),
                jewelToneColor.opacity(0.05),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconColor: Color {
        if isLocked {
            return jewelToneColor.opacity(0.4)
        }
        return isSelected ? LopanColors.textPrimary : jewelToneColor
    }

    private var primaryTextColor: Color {
        if isLocked {
            return LopanColors.textSecondary
        }
        return isSelected ? LopanColors.textPrimary : LopanColors.textPrimary
    }

    private var secondaryTextColor: Color {
        if isLocked {
            return LopanColors.textSecondary.opacity(0.6)
        }
        return isSelected ? LopanColors.textPrimary.opacity(0.8) : LopanColors.textSecondary
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func trendBadge(_ trend: Trend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend.icon)
                .font(.caption2)
            if visualComposer.enhancementLevel != .minimal {
                Text("5.2%") // Example percentage - would be dynamic in real implementation
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(trend.color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(trend.color.opacity(0.3), lineWidth: 0.5)
                )
        )
        .foregroundStyle(trend.color)
    }

    // MARK: - Helper Methods

    private func animateValueIfNeeded() {
        guard let doubleValue = Double(value) else { return }

        if visualComposer.enhancementLevel != .minimal && !visualComposer.isReducedMotionEnabled {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedValue = doubleValue
            }
        } else {
            animatedValue = doubleValue
        }
    }

    private func triggerHapticFeedback() {
        if visualComposer.enhancementLevel == .premium {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Preview Provider

#Preview("QuickStatCard - Default") {
    VStack(spacing: 16) {
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
                trend: .stable
            )
        }

        HStack(spacing: 12) {
            QuickStatCard(
                title: "已完成",
                value: "95",
                icon: "checkmark.circle.fill",
                color: LopanColors.success,
                trend: .up,
                isSelected: true
            )

            QuickStatCard(
                title: "已退货",
                value: "19",
                icon: "arrow.uturn.left",
                color: LopanColors.error,
                trend: .down
            )
        }
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
}

#Preview("QuickStatCard - Locked State") {
    HStack(spacing: 12) {
        QuickStatCard(
            title: "Loading",
            value: "---",
            icon: "hourglass",
            color: LopanColors.info,
            isLocked: true
        )

        QuickStatCard(
            title: "处理中",
            value: "...",
            icon: "arrow.trianglehead.2.clockwise",
            color: LopanColors.warning,
            isLocked: true
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
}

#Preview("QuickStatCard - Dynamic Type XL") {
    HStack(spacing: 12) {
        QuickStatCard(
            title: "超大字体测试",
            value: "9999",
            icon: "textformat.size",
            color: LopanColors.primary,
            trend: .up
        )

        QuickStatCard(
            title: "动态类型",
            value: "888",
            icon: "textformat",
            color: LopanColors.success
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .environment(\.dynamicTypeSize, .xxxLarge)
}