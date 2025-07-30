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
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Initializers
    init(
        variant: CardVariant = .elevated,
        padding: CGFloat = LopanSpacing.cardPadding,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.padding = padding
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isInteractive {
                Button(action: {
                    HapticFeedback.light()
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
                return Color.clear
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
        LopanCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    if let trend = trend {
                        HStack(spacing: LopanSpacing.xxs) {
                            Image(systemName: trend.icon)
                                .font(.caption)
                            Text(trend.text)
                                .font(LopanTypography.caption)
                        }
                        .foregroundColor(trend.color)
                        .padding(.horizontal, LopanSpacing.xs)
                        .padding(.vertical, LopanSpacing.xxs)
                        .background(trend.color.opacity(0.1))
                        .badgeCornerRadius()
                    }
                }
                
                Text(value)
                    .font(LopanTypography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(title)
                    .font(LopanTypography.bodySmall)
                    .foregroundColor(LopanColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

struct LopanDashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        LopanCard(variant: .elevated, isInteractive: true, onTap: onTap) {
            VStack(spacing: LopanSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(color)
                
                VStack(spacing: LopanSpacing.xs) {
                    Text(title)
                        .font(LopanTypography.titleMedium)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text(subtitle)
                        .font(LopanTypography.bodySmall)
                        .foregroundColor(LopanColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: LopanSpacing.md) {
            LopanCard(variant: .elevated) {
                Text("Elevated Card")
                    .font(LopanTypography.titleMedium)
            }
            
            LopanCard(variant: .flat) {
                Text("Flat Card")
                    .font(LopanTypography.titleMedium)
            }
            
            LopanCard(variant: .outline) {
                Text("Outline Card")
                    .font(LopanTypography.titleMedium)
            }
            
            LopanCard(variant: .glass) {
                Text("Glass Card")
                    .font(LopanTypography.titleMedium)
            }
            
            LopanStatCard(
                title: "Total Orders",
                value: "1,234",
                icon: "cart.fill",
                color: LopanColors.primary,
                trend: .up("12%")
            )
            
            LopanDashboardCard(
                title: "Customer Management",
                subtitle: "Manage customer information",
                icon: "person.2.fill",
                color: LopanColors.primary
            ) {
                print("Dashboard card tapped")
            }
        }
        .padding()
    }
}