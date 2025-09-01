//
//  TabBarIcon.swift
//  Lopan
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI

/// Custom tab bar icon with modern animations and accessibility features
/// Following iOS 17+ design patterns with fluid animations and haptic feedback
struct TabBarIcon: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badge: String?
    
    @State private var isPressed = false
    @State private var animationOffset: CGFloat = 0
    
    init(
        icon: String,
        title: String,
        isSelected: Bool,
        badge: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.badge = badge
    }
    
    var body: some View {
        VStack(spacing: LopanSpacing.xs) {
            ZStack {
                // Icon background with selection state
                Circle()
                    .fill(backgroundGradient)
                    .frame(width: iconBackgroundSize, height: iconBackgroundSize)
                    .scaleEffect(isSelected ? 1.1 : 0.9)
                    .opacity(isSelected ? 1.0 : 0.3)
                
                // Main icon
                Image(systemName: icon)
                    .font(.system(
                        size: iconSize,
                        weight: isSelected ? .semibold : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: isSelected)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Badge indicator
                if let badge = badge {
                    VStack {
                        HStack {
                            Spacer()
                            BadgeView(text: badge)
                                .offset(x: 8, y: -8)
                        }
                        Spacer()
                    }
                }
                
                // Selection indicator
                if isSelected {
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LopanColors.roleWarehouseKeeper)
                            .frame(width: 20, height: 2)
                            .offset(y: 4)
                            .animation(.spring(.bouncy, blendDuration: 0.3), value: isSelected)
                    }
                }
            }
            .offset(y: animationOffset)
            
            // Title
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(titleColor)
                .opacity(isSelected ? 1.0 : 0.7)
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .animation(LopanAnimation.tabTransition, value: isSelected)
        .animation(LopanAnimation.cardHover, value: isPressed)
        .onAppear {
            if isSelected {
                triggerBounceAnimation()
            }
        }
        .onChange(of: isSelected) { _, selected in
            if selected {
                triggerBounceAnimation()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    // MARK: - Computed Properties
    
    private var iconSize: CGFloat {
        isSelected ? 22 : 20
    }
    
    private var iconBackgroundSize: CGFloat {
        isSelected ? 32 : 28
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                LopanColors.roleWarehouseKeeper.opacity(0.15),
                LopanColors.roleWarehouseKeeper.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var iconColor: Color {
        isSelected ? LopanColors.roleWarehouseKeeper : LopanColors.textSecondary
    }
    
    private var titleColor: Color {
        isSelected ? LopanColors.roleWarehouseKeeper : LopanColors.textSecondary
    }
    
    private var accessibilityLabel: String {
        if let badge = badge {
            return "\(title)，\(badge) 项待处理"
        }
        return title
    }
    
    private var accessibilityHint: String {
        isSelected ? "当前选中的标签页" : "点击切换到 \(title)"
    }
    
    // MARK: - Animations
    
    private func triggerBounceAnimation() {
        withAnimation(.bouncy(duration: 0.6, extraBounce: 0.3)) {
            animationOffset = -4
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.bouncy(duration: 0.4, extraBounce: 0.2)) {
                animationOffset = 0
            }
        }
    }
}

// MARK: - Badge Component

private struct BadgeView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(LopanColors.error)
                    .shadow(color: LopanColors.error.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(0.9)
    }
}

// MARK: - Long Press Menu Support

extension TabBarIcon {
    /// Creates a tab bar icon with long press menu support
    static func withQuickActions(
        icon: String,
        title: String,
        isSelected: Bool,
        badge: String? = nil,
        quickActions: [TabQuickAction]
    ) -> some View {
        TabBarIcon(icon: icon, title: title, isSelected: isSelected, badge: badge)
            .contextMenu {
                ForEach(quickActions, id: \.id) { action in
                    Button(action: action.action) {
                        Label(action.title, systemImage: action.icon)
                    }
                }
            }
    }
}

// MARK: - Quick Action Model

struct TabQuickAction {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            TabBarIcon(
                icon: "cube.box.fill",
                title: "包装管理",
                isSelected: true
            )
            
            TabBarIcon(
                icon: "bell.badge.fill",
                title: "任务提醒",
                isSelected: false,
                badge: "3"
            )
            
            TabBarIcon(
                icon: "person.2.fill",
                title: "团队管理",
                isSelected: false
            )
        }
        
        HStack(spacing: 40) {
            TabBarIcon(
                icon: "chart.bar.fill",
                title: "统计分析",
                isSelected: false
            )
            
            TabBarIcon(
                icon: "info.circle.fill",
                title: "产品信息",
                isSelected: false
            )
        }
    }
    .padding(40)
    .background(Color(.systemBackground))
}