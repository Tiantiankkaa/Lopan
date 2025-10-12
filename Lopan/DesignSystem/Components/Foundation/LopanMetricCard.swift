//
//  LopanMetricCard.swift
//  Lopan
//
//  Created by Factory on 2025/12/31.
//

import SwiftUI

/// Reusable metric card component for displaying key metrics and stats
/// Supports various layouts, trends, and interactive states
public struct LopanMetricCard<Content: View>: View {
    // MARK: - Properties
    let title: String
    let value: String?
    let subtitle: String?
    let trend: TrendIndicator?
    let icon: String?
    let iconColor: Color
    let content: (() -> Content)?
    let action: (() -> Void)?
    
    // MARK: - Types
    public struct TrendIndicator {
        let value: Double
        let label: String?
        
        public init(value: Double, label: String? = nil) {
            self.value = value
            self.label = label
        }
        
        var icon: String {
            if value > 0.001 { return "arrow.up" }
            else if value < -0.001 { return "arrow.down" }
            else { return "minus" }
        }
        
        var color: Color {
            if value > 0.001 { return LopanColors.success }
            else if value < -0.001 { return LopanColors.error }
            else { return LopanColors.textSecondary }
        }
        
        var backgroundColor: Color {
            if value > 0.001 { return LopanColors.success.opacity(0.12) }
            else if value < -0.001 { return LopanColors.error.opacity(0.12) }
            else { return LopanColors.backgroundSecondary }
        }
        
        var displayText: String {
            let percent = Int(value * 100)
            let prefix = percent > 0 ? "+" : ""
            if let label = label {
                return "\(prefix)\(percent)% \(label)"
            }
            return "\(prefix)\(percent)%"
        }
    }
    
    // MARK: - Initializers
    public init(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        trend: TrendIndicator? = nil,
        icon: String? = nil,
        iconColor: Color = LopanColors.primary,
        action: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.trend = trend
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
        self.content = content
    }
    
    public init(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        trend: TrendIndicator? = nil,
        icon: String? = nil,
        iconColor: Color = LopanColors.primary,
        action: (() -> Void)? = nil
    ) where Content == EmptyView {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.trend = trend
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
        self.content = nil
    }
    
    // MARK: - Body
    public var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            // Header
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                        .frame(width: 24, height: 24)
                }
                
                Text(title)
                    .lopanTitleMedium()
                    .foregroundColor(LopanColors.textPrimary)
                
                Spacer()
                
                if let trend = trend {
                    trendBadge(trend)
                }
            }
            
            // Value
            if let value = value {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(LopanColors.textPrimary)
            }
            
            // Custom Content
            if let content = content {
                content()
            }
            
            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .lopanLabelMedium()
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LopanSpacing.cardPadding)
        .background(LopanColors.surface)
        .cornerRadius(LopanCornerRadius.card)
        .lopanShadow(LopanShadows.card)
    }
    
    private func trendBadge(_ trend: TrendIndicator) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .lopanLabelSmall()
            Text(trend.displayText)
                .lopanLabelSmall()
        }
        .foregroundColor(trend.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trend.backgroundColor)
        .cornerRadius(12)
    }
}

// MARK: - Convenience Extensions

public extension LopanMetricCard where Content == EmptyView {
    /// Creates a simple metric card with title and value
    static func simple(
        title: String,
        value: String,
        icon: String? = nil,
        iconColor: Color = LopanColors.primary,
        action: (() -> Void)? = nil
    ) -> LopanMetricCard {
        LopanMetricCard(
            title: title,
            value: value,
            icon: icon,
            iconColor: iconColor,
            action: action
        )
    }
    
    /// Creates a metric card with trend indicator
    static func withTrend(
        title: String,
        value: String,
        trend: Double,
        trendLabel: String? = nil,
        icon: String? = nil,
        iconColor: Color = LopanColors.primary,
        action: (() -> Void)? = nil
    ) -> LopanMetricCard {
        LopanMetricCard(
            title: title,
            value: value,
            trend: TrendIndicator(value: trend, label: trendLabel),
            icon: icon,
            iconColor: iconColor,
            action: action
        )
    }
}

// MARK: - Preview

#if DEBUG
struct LopanMetricCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Simple metric
            LopanMetricCard.simple(
                title: "Total Sales",
                value: "₦ 125,430.00",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: LopanColors.success
            )
            
            // With trend
            LopanMetricCard.withTrend(
                title: "Daily Revenue",
                value: "₦ 45,200.00",
                trend: 0.15,
                trendLabel: "vs yesterday",
                icon: "dollarsign.circle",
                iconColor: LopanColors.primary
            )
            
            // Custom content
            LopanMetricCard(
                title: "Products",
                icon: "cube.box",
                iconColor: LopanColors.warning
            ) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("42").font(.title2.bold())
                        Text("Active").font(.caption).foregroundColor(LopanColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("5").font(.title2.bold())
                        Text("Low Stock").font(.caption).foregroundColor(LopanColors.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
