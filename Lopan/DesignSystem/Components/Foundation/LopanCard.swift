//
//  LopanCard.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Modern card component system for Lopan production management app
/// Supports different variants, interactive states, and glass morphism effects
struct LopanCard<Content: View>: View {
    // MARK: - Properties
    let content: Content
    let variant: CardVariant
    let padding: CGFloat
    let isInteractive: Bool
    let onTap: (() -> Void)?
    let accessibilityLabel: String?
    let accessibilityHint: String?

    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Initializers
    init(
        variant: CardVariant = .elevated,
        padding: CGFloat = LopanSpacing.cardPadding,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.padding = padding
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isInteractive {
                Button(action: {
                    LopanHapticEngine.shared.perform(.buttonTap)
                    onTap?()
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(LopanAnimation.cardHover) {
                        isPressed = pressing
                    }
                }, perform: {})
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                    .fill(variant.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                            .stroke(variant.borderColor, lineWidth: variant.borderWidth)
                    )
            )
            .lopanShadow(variant.shadow(isPressed: isPressed, isHovered: isHovered))
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .onHover { hovering in
                withAnimation(LopanAnimation.cardHover) {
                    isHovered = hovering && isInteractive
                }
            }
            .modifier(
                ConditionalAccessibilityModifier(
                    isInteractive: isInteractive,
                    accessibilityLabel: accessibilityLabel,
                    accessibilityHint: accessibilityHint
                )
            )
    }
}

// MARK: - Helper Modifiers

private struct ConditionalAccessibilityModifier: ViewModifier {
    let isInteractive: Bool
    let accessibilityLabel: String?
    let accessibilityHint: String?

    func body(content: Content) -> some View {
        if isInteractive {
            content
                .lopanAccessibility(
                    role: .card,
                    label: accessibilityLabel ?? "卡片",
                    hint: accessibilityHint ?? "点击查看详情"
                )
                .lopanMinimumTouchTarget()
        } else if let label = accessibilityLabel {
            content
                .lopanAccessibilityGroup(
                    label: label,
                    hint: accessibilityHint
                )
        } else {
            content
        }
    }
}

// MARK: - Card Variants
extension LopanCard {
    enum CardVariant {
        case flat
        case elevated
        case outline
        case glass
        case surface
        
        var backgroundColor: Color {
            switch self {
            case .flat, .elevated, .surface:
                return LopanColors.surface
            case .outline:
                return LopanColors.background
            case .glass:
                return LopanColors.glassMorphism
            }
        }
        
        var borderColor: Color {
            switch self {
            case .outline:
                return LopanColors.border
            case .glass:
                return LopanColors.glassMorphismStrong
            default:
                return LopanColors.clear
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .outline, .glass:
                return 1
            default:
                return 0
            }
        }
        
        func shadow(isPressed: Bool, isHovered: Bool) -> ShadowStyle {
            switch self {
            case .flat:
                return LopanShadows.none
            case .elevated:
                if isPressed {
                    return LopanShadows.cardPressed
                } else if isHovered {
                    return LopanShadows.cardHover
                } else {
                    return LopanShadows.card
                }
            case .outline:
                return isHovered ? LopanShadows.sm : LopanShadows.none
            case .glass:
                return isHovered ? LopanShadows.md : LopanShadows.sm
            case .surface:
                return isHovered ? LopanShadows.sm : LopanShadows.xs
            }
        }
    }
}


// MARK: - Specialized Card Components
struct LopanStatCard: View {
    let title: String
    let value: String
    let icon: String?
    let color: Color
    let trend: Trend?
    
    enum Trend {
        case up(String)
        case down(String)
        case neutral(String)
        
        var color: Color {
            switch self {
            case .up: return LopanColors.success
            case .down: return LopanColors.error
            case .neutral: return LopanColors.secondary
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
        
        var text: String {
            switch self {
            case .up(let text), .down(let text), .neutral(let text):
                return text
            }
        }
    }
    
    var body: some View {
        LopanCard(
            variant: .elevated,
            accessibilityLabel: statAccessibilityLabel,
            accessibilityHint: "统计数据卡片"
        ) {
            LopanAdaptiveVStack(alignment: .leading, spacing: LopanSpacing.sm) {
                LopanAdaptiveHStack(breakpointBehavior: .stack) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)
                            .lopanAccessibility(
                                role: .statistic,
                                label: "图标",
                                hint: "统计指标图标"
                            )
                    }

                    Spacer()

                    if let trend = trend {
                        LopanAdaptiveHStack(spacing: LopanSpacing.xxs) {
                            Image(systemName: trend.icon)
                                .font(.caption)
                            Text(trend.text)
                                .lopanCaption()
                        }
                        .foregroundColor(trend.color)
                        .lopanAdaptivePadding(.horizontal, LopanSpacing.xs)
                        .lopanAdaptivePadding(.vertical, LopanSpacing.xxs)
                        .background(trend.color.opacity(0.1))
                        .badgeCornerRadius()
                        .lopanAccessibility(
                            role: .statistic,
                            label: trendAccessibilityLabel(trend),
                            hint: "趋势指标"
                        )
                    }
                }

                Text(value)
                    .lopanHeadlineMedium(maxLines: 1)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
                    .lopanAccessibility(
                        role: .statistic,
                        label: "数值",
                        value: value
                    )

                Text(title)
                    .lopanBodySmall(maxLines: 2)
                    .foregroundColor(LopanColors.textSecondary)
                    .lopanAccessibility(
                        role: .statistic,
                        label: "标题",
                        value: title
                    )
            }
            .lopanAdaptiveMinHeight(100)
        }
    }

    private func trendAccessibilityLabel(_ trend: Trend) -> String {
        let trendType = switch trend {
        case .up: "上升"
        case .down: "下降"
        case .neutral: "持平"
        }
        return "\(trendType) \(trend.text)"
    }

    private var statAccessibilityLabel: String {
        var components = [title, value]
        if let trend = trend {
            let trendType = switch trend {
            case .up: "上升"
            case .down: "下降"
            case .neutral: "持平"
            }
            components.append("\(trendType) \(trend.text)")
        }
        return components.joined(separator: "，")
    }
}

struct LopanDashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        LopanCard(
            variant: .elevated,
            isInteractive: true,
            onTap: onTap,
            accessibilityLabel: "\(title)，\(subtitle)",
            accessibilityHint: "点击进入\(title)页面"
        ) {
            LopanAdaptiveVStack(spacing: LopanSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(color)
                    .lopanAccessibility(
                        role: .navigation,
                        label: "图标",
                        hint: "\(title)功能图标"
                    )

                LopanAdaptiveVStack(spacing: LopanSpacing.xs) {
                    Text(title)
                        .lopanTitleMedium(maxLines: 2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(LopanColors.textPrimary)
                        .lopanAccessibility(
                            role: .navigation,
                            label: "功能名称",
                            value: title
                        )

                    Text(subtitle)
                        .lopanBodySmall(maxLines: 3)
                        .foregroundColor(LopanColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lopanAccessibility(
                            role: .navigation,
                            label: "功能描述",
                            value: subtitle
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .lopanAdaptiveMinHeight(120)
        }
    }
}

// MARK: - Dynamic Type Previews

#Preview("Default Size") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Card Variants")
                .font(.headline)
                .padding(.bottom)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                LopanCard(variant: .elevated) {
                    Text("Elevated Card")
                        .font(LopanTypography.titleMedium)
                        .padding()
                }

                LopanCard(variant: .flat) {
                    Text("Flat Card")
                        .font(LopanTypography.titleMedium)
                        .padding()
                }

                LopanCard(variant: .outline) {
                    Text("Outline Card")
                        .font(LopanTypography.titleMedium)
                        .padding()
                }

                LopanCard(variant: .glass) {
                    Text("Glass Morphism")
                        .font(LopanTypography.titleMedium)
                        .padding()
                }
            }

            Divider()

            LopanStatCard(
                title: "生产订单统计",
                value: "1,234",
                icon: "cart.fill",
                color: LopanColors.primary,
                trend: .up("12%")
            )

            LopanDashboardCard(
                title: "客户管理",
                subtitle: "管理客户信息和订单",
                icon: "person.2.fill",
                color: LopanColors.primary
            ) { }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Card Preview at Extra Large Size")
                .font(.title2)
                .padding(.bottom)

            LopanCard(variant: .elevated, isInteractive: true, onTap: { }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Production Management System")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Comprehensive manufacturing oversight and quality control dashboard")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            LopanStatCard(
                title: "Today's Manufacturing Output Statistics",
                value: "2,847",
                icon: "gearshape.2.fill",
                color: LopanColors.success,
                trend: .up("18.5%")
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Accessibility 3") {
    ScrollView {
        VStack(spacing: 28) {
            Text("Card Preview at AX3 Size")
                .font(.title2)
                .padding(.bottom)

            LopanCard(variant: .elevated) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quality Control Dashboard")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Comprehensive inspection and approval workflow management for manufacturing excellence")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }

            LopanStatCard(
                title: "Critical Alert: Production Batch Requiring Immediate Quality Review",
                value: "47",
                icon: "exclamationmark.triangle.fill",
                color: LopanColors.warning,
                trend: .up("Priority High")
            )

            LopanDashboardCard(
                title: "Manufacturing Process Control",
                subtitle: "Complete oversight of production workflow, quality checkpoints, and batch management",
                icon: "gearshape.2.fill",
                color: LopanColors.primary
            ) { }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    ScrollView {
        VStack(spacing: 32) {
            Text("Maximum Accessibility Size")
                .font(.largeTitle)
                .padding(.bottom)

            LopanCard(variant: .elevated, isInteractive: true, onTap: { }) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Access all systems")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(24)
            }

            LopanStatCard(
                title: "Total Items",
                value: "999",
                icon: "square.stack.3d.up.fill",
                color: LopanColors.primary,
                trend: .up("Good")
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX3") {
    ScrollView {
        VStack(spacing: 28) {
            Text("Dark Mode Card Preview")
                .font(.title2)
                .padding(.bottom)

            LopanCard(variant: .glass) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Glass Morphism in Dark Mode")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Demonstrating glass effect with proper opacity and contrast for dark environments")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            LopanStatCard(
                title: "Dark Mode Production Statistics",
                value: "1,847",
                icon: "moon.fill",
                color: LopanColors.secondary,
                trend: .neutral("Stable")
            )

            LopanDashboardCard(
                title: "Night Shift Operations",
                subtitle: "Monitoring and control for after-hours manufacturing processes",
                icon: "moon.stars.fill",
                color: LopanColors.info
            ) { }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Interactive States") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Interactive Card States")
                .font(.headline)
                .padding(.bottom)

            LopanCard(
                variant: .elevated,
                isInteractive: true,
                onTap: { },
                accessibilityLabel: "Interactive Card",
                accessibilityHint: "Tap to see interaction"
            ) {
                VStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title)
                        .foregroundColor(LopanColors.primary)
                    Text("Tap Me")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("This card responds to touch")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }

            LopanCard(variant: .outline) {
                VStack(spacing: 8) {
                    Text("Non-Interactive")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Static content card")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}