//
//  QuickStatCard.swift
//  Lopan
//
//  Extracted from CustomerOutOfStockDashboard
//  iOS 26 UI/UX compliant reusable statistics card component
//

import SwiftUI

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

    private var cardCornerRadius: CGFloat { 12 }

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
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .allowsHitTesting(!isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text("切换状态筛选"))
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 8) {
            // Header with icon and trend
            HStack {
                Image(systemName: icon)
                    .imageScale(.medium)
                    .foregroundStyle(isSelected ? LopanColors.textPrimary : (isLocked ? color.opacity(0.4) : color))

                Spacer()

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? LopanColors.textPrimary.opacity(0.85) : (isLocked ? trend.color.opacity(0.4) : trend.color))
                }
            }

            // Value and title
            VStack(spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? LopanColors.textPrimary : (isLocked ? LopanColors.textSecondary : LopanColors.textPrimary))
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.footnote)
                    .foregroundStyle(isSelected ? LopanColors.textPrimary.opacity(0.9) : LopanColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(isSelected ? color : LopanColors.background)
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(isSelected ? color.opacity(0.9) : LopanColors.clear, lineWidth: isSelected ? 2 : 0)
        )
        .opacity(isLocked ? 0.8 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isSelected)
    }

    // MARK: - Shadow Properties

    private var shadowColor: Color {
        if isSelected {
            return color.opacity(0.28)
        }
        return LopanColors.textPrimary.opacity(isLocked ? 0.03 : 0.06)
    }

    private var shadowRadius: CGFloat {
        isSelected ? 8 : (isLocked ? 2 : 4)
    }

    private var shadowY: CGFloat {
        isSelected ? 4 : (isLocked ? 1 : 2)
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