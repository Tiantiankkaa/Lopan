//
//  ModernDashboardCard.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Modern dashboard card component that replaces the legacy DashboardCard
/// Features glass morphism effects, micro-interactions, and improved accessibility
struct ModernDashboardCard: View {
    // MARK: - Properties
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let badge: String?
    let isEnabled: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Initializer
    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        badge: String? = nil,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.badge = badge
        self.isEnabled = isEnabled
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            if isEnabled {
                HapticFeedback.medium()
                onTap()
            }
        }) {
            ZStack {
                // Background with glass morphism effect
                RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.05),
                                color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.2),
                                        color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Content
                VStack(spacing: LopanSpacing.md) {
                    // Icon with badge
                    ZStack {
                        // Icon background
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(color)
                        
                        // Badge if present
                        if let badge = badge {
                            VStack {
                                HStack {
                                    Spacer()
                                    LopanBadge(badge, style: .primary, size: .small)
                                        .offset(x: 8, y: -8)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    // Text content
                    VStack(spacing: LopanSpacing.xs) {
                        Text(title)
                            .font(LopanTypography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(LopanColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(subtitle)
                            .font(LopanTypography.bodySmall)
                            .foregroundColor(LopanColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .padding(LopanSpacing.md)
                
                // Shimmer overlay for loading state
                if !isEnabled {
                    RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                        .fill(Color.black.opacity(0.05))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .lopanShadow(shadowStyle)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(LopanAnimation.cardHover) {
                isPressed = pressing
            }
        }, perform: {})
        .onHover { hovering in
            withAnimation(LopanAnimation.cardHover) {
                isHovered = hovering
            }
        }
        .opacity(isEnabled ? 1.0 : 0.6)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isEnabled ? .isButton : [])
    }
    
    private var shadowStyle: ShadowStyle {
        if !isEnabled {
            return LopanShadows.none
        } else if isPressed {
            return LopanShadows.cardPressed
        } else if isHovered {
            return LopanShadows.cardHover
        } else {
            return LopanShadows.card
        }
    }
}

// MARK: - Convenience Initializers
extension ModernDashboardCard {
    /// Creates a dashboard card for role-specific features
    static func roleFeature(
        title: String,
        subtitle: String,
        icon: String,
        role: UserRole,
        badge: String? = nil,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) -> ModernDashboardCard {
        let color = roleColor(for: role)
        return ModernDashboardCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            badge: badge,
            isEnabled: isEnabled,
            onTap: onTap
        )
    }
    
    /// Creates a dashboard card with status indicator
    static func withStatus(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        status: String,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) -> ModernDashboardCard {
        ModernDashboardCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            badge: status,
            isEnabled: isEnabled,
            onTap: onTap
        )
    }
    
    private static func roleColor(for role: UserRole) -> Color {
        switch role {
        case .administrator:
            return LopanColors.roleAdministrator
        case .salesperson:
            return LopanColors.roleSalesperson
        case .warehouseKeeper:
            return LopanColors.roleWarehouseKeeper
        case .workshopManager:
            return LopanColors.roleWorkshopManager
        case .evaGranulationTechnician:
            return LopanColors.roleEVATechnician
        case .workshopTechnician:
            return LopanColors.roleWorkshopTechnician
        case .unauthorized:
            return LopanColors.error
        }
    }
}

// MARK: - Dashboard Card Grid
struct DashboardCardGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: Content
    
    init(
        columns: Int = 2,
        spacing: CGFloat = LopanSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: columns),
            spacing: spacing
        ) {
            content
        }
        .padding(.horizontal, LopanSpacing.screenPadding)
    }
}

// MARK: - Loading State Card
struct LoadingDashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    @State private var isAnimating = false
    
    var body: some View {
        ModernDashboardCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            isEnabled: false
        ) {}
        .overlay(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
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
                .opacity(isAnimating ? 1 : 0)
                .animation(
                    LopanAnimation.loading,
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
        VStack(spacing: LopanSpacing.lg) {
            DashboardCardGrid(columns: 2) {
                ModernDashboardCard(
                    title: "Customer Management",
                    subtitle: "Manage customer information and orders",
                    icon: "person.2.fill",
                    color: LopanColors.primary
                ) {
                    print("Customer Management tapped")
                }
                
                ModernDashboardCard(
                    title: "Return Goods",
                    subtitle: "Process returns and exchanges",
                    icon: "arrow.uturn.left",
                    color: LopanColors.warning,
                    badge: "5"
                ) {
                    print("Return Goods tapped")
                }
                
                ModernDashboardCard.withStatus(
                    title: "Production Status",
                    subtitle: "Monitor production progress",
                    icon: "gearshape.2.fill",
                    color: LopanColors.success,
                    status: "Active"
                ) {
                    print("Production Status tapped")
                }
                
                LoadingDashboardCard(
                    title: "Analytics",
                    subtitle: "View reports and insights",
                    icon: "chart.bar.fill",
                    color: LopanColors.info
                )
            }
        }
        .padding(.vertical)
    }
}