//
//  ModernStatCard.swift
//  Lopan
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI

/// Modern statistic card with glass morphism effect and micro-animations
/// Following iOS 17+ design patterns with accessibility support
struct ModernStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let trend: StatCardTrendDirection?
    let trendValue: String?
    
    @State private var isAnimated = false
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color,
        trend: StatCardTrendDirection? = nil,
        trendValue: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
        self.trendValue = trendValue
    }
    
    var body: some View {
        VStack(spacing: LopanSpacing.sm) {
            // Header with icon and trend
            HStack {
                iconView
                Spacer()
                if let trend = trend, let trendValue = trendValue {
                    trendView(trend: trend, value: trendValue)
                }
            }
            
            // Main content
            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                // Value with animated counting
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.bouncy, value: value)
                
                // Title
                Text(title)
                    .font(LopanTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(LopanColors.textPrimary)
                
                // Subtitle if provided
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(LopanTypography.bodySmall)
                        .foregroundStyle(LopanColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LopanSpacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.card))
        .lopanShadow(LopanShadows.sm)
        .scaleEffect(isAnimated ? 1.0 : 0.95)
        .opacity(isAnimated ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.bouncy(duration: 0.8).delay(Double.random(in: 0...0.3))) {
                isAnimated = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
    
    // MARK: - Icon View
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .symbolEffect(.pulse.byLayer, value: isAnimated)
        }
    }
    
    // MARK: - Trend View
    
    private func trendView(trend: StatCardTrendDirection, value: String) -> some View {
        HStack(spacing: LopanSpacing.xs) {
            Image(systemName: trend.iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(trend.color)
            
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(trend.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(trend.color.opacity(0.1))
        )
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        ZStack {
            // Base background with glass morphism
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            LopanColors.surface,
                            color.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle border
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            color.opacity(0.1),
                            color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        return title
    }
    
    private var accessibilityValue: String {
        var result = value
        if let subtitle = subtitle {
            result += ", \(subtitle)"
        }
        if let trend = trend, let trendValue = trendValue {
            result += ", \(trend.description) \(trendValue)"
        }
        return result
    }
}

// MARK: - Trend Direction

enum StatCardTrendDirection {
    case up, down, stable
    
    var iconName: String {
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
        case .stable: return LopanColors.secondary
        }
    }
    
    var description: String {
        switch self {
        case .up: return "增长"
        case .down: return "下降"
        case .stable: return "持平"
        }
    }
}

// MARK: - Loading State Card

struct LoadingStatCard: View {
    let title: String
    let icon: String
    let color: Color
    
    @State private var isAnimating = false
    
    var body: some View {
        ModernStatCard(
            title: title,
            value: "---",
            icon: icon,
            color: color
        )
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Shimmer Effect Modifier

private struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: isAnimating ? 1 : 0, anchor: .leading)
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            )
            .onAppear {
                isAnimating = true
            }
    }
}


// MARK: - Preview

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: LopanSpacing.md) {
            ModernStatCard(
                title: "总包装数",
                value: "1,234",
                subtitle: "今日完成",
                icon: "cube.box.fill",
                color: LopanColors.primary,
                trend: .up,
                trendValue: "+12%"
            )
            
            ModernStatCard(
                title: "活跃团队",
                value: "8",
                subtitle: "参与团队",
                icon: "person.2.fill",
                color: LopanColors.success,
                trend: .stable,
                trendValue: "0%"
            )
            
            ModernStatCard(
                title: "效率指标",
                value: "95.2%",
                subtitle: "完成率",
                icon: "chart.line.uptrend.xyaxis",
                color: LopanColors.info,
                trend: .down,
                trendValue: "-2.1%"
            )
            
            LoadingStatCard(
                title: "加载中",
                icon: "clock.fill",
                color: LopanColors.secondary
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}