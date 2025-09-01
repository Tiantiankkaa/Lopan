//
//  QuickActionMenu.swift
//  Lopan
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI
import SwiftData

/// Modern quick action menu for warehouse keeper workbench
/// Provides easy access to workbench switching, settings, and common operations
struct QuickActionMenu: View {
    let selectedTab: WarehouseTab
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies
    
    @State private var isLoading = false
    @State private var showingWorkbenchSelector = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: LopanSpacing.lg) {
                // Header with current tab info
                headerView
                
                // Quick actions based on selected tab
                LazyVStack(spacing: LopanSpacing.md) {
                    ForEach(quickActions, id: \.id) { action in
                        QuickActionRow(
                            action: action,
                            onTap: {
                                handleAction(action)
                            }
                        )
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // System actions
                systemActionsView
                
                Spacer(minLength: LopanSpacing.lg)
            }
            .padding(LopanSpacing.lg)
            .navigationTitle("快捷操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingWorkbenchSelector) {
            WorkbenchSelectorView(
                authService: authService,
                navigationService: navigationService
            )
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: LopanSpacing.sm) {
            // Current tab indicator
            HStack(spacing: LopanSpacing.sm) {
                Image(systemName: selectedTab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(LopanColors.roleWarehouseKeeper)
                
                Text(selectedTab.title)
                    .font(LopanTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(LopanColors.textPrimary)
                
                Spacer()
            }
            
            // Current user info
            if let user = authService.currentUser {
                HStack(spacing: LopanSpacing.sm) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(LopanColors.textSecondary)
                    
                    Text(user.name)
                        .font(LopanTypography.bodyMedium)
                        .foregroundStyle(LopanColors.textSecondary)
                    
                    Text("·")
                        .font(LopanTypography.bodyMedium)
                        .foregroundStyle(LopanColors.textSecondary)
                    
                    Text("仓库管理员")
                        .font(LopanTypography.bodyMedium)
                        .foregroundStyle(LopanColors.roleWarehouseKeeper)
                    
                    Spacer()
                }
            }
        }
        .padding(LopanSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(LopanColors.roleWarehouseKeeper.opacity(0.05))
                .strokeBorder(
                    LopanColors.roleWarehouseKeeper.opacity(0.1),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - System Actions
    
    private var systemActionsView: some View {
        VStack(spacing: LopanSpacing.md) {
            // Workbench operations
            QuickActionRow(
                action: QuickAction(
                    title: "切换工作台",
                    subtitle: "访问其他角色工作台",
                    icon: "arrow.triangle.2.circlepath",
                    color: LopanColors.primary,
                    type: .navigation
                ),
                onTap: {
                    showingWorkbenchSelector = true
                }
            )
            
            // Data refresh
            QuickActionRow(
                action: QuickAction(
                    title: "刷新数据",
                    subtitle: "重新加载最新信息",
                    icon: "arrow.clockwise",
                    color: LopanColors.info,
                    type: .action,
                    isLoading: isLoading
                ),
                onTap: {
                    refreshData()
                }
            )
            
            // Settings (if available)
            if authService.currentUser?.isAdministrator == true {
                QuickActionRow(
                    action: QuickAction(
                        title: "系统设置",
                        subtitle: "管理系统配置和权限",
                        icon: "gearshape.fill",
                        color: LopanColors.secondary,
                        type: .navigation
                    ),
                    onTap: {
                        // Navigate to system settings
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Quick Actions Generator
    
    private var quickActions: [QuickAction] {
        switch selectedTab {
        case .packaging:
            return packagingQuickActions
        case .tasks:
            return taskQuickActions
        case .team:
            return teamQuickActions
        case .analytics:
            return analyticsQuickActions
        case .products:
            return productQuickActions
        }
    }
    
    private var packagingQuickActions: [QuickAction] {
        [
            QuickAction(
                title: "新增包装记录",
                subtitle: "快速记录包装数据",
                icon: "plus.circle.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                title: "批量导入",
                subtitle: "从 Excel 导入包装数据",
                icon: "square.and.arrow.down.fill",
                color: LopanColors.info,
                type: .importData
            ),
            QuickAction(
                title: "导出报表",
                subtitle: "生成包装统计报表",
                icon: "square.and.arrow.up.fill",
                color: LopanColors.warning,
                type: .export
            )
        ]
    }
    
    private var taskQuickActions: [QuickAction] {
        [
            QuickAction(
                title: "创建提醒",
                subtitle: "设置新的任务提醒",
                icon: "bell.badge.plus.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                title: "批量处理",
                subtitle: "批量完成或延期任务",
                icon: "checklist",
                color: LopanColors.info,
                type: .action
            )
        ]
    }
    
    private var teamQuickActions: [QuickAction] {
        [
            QuickAction(
                title: "添加成员",
                subtitle: "邀请新的团队成员",
                icon: "person.badge.plus.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                title: "分工管理",
                subtitle: "调整团队工作分配",
                icon: "person.2.gobackward",
                color: LopanColors.info,
                type: .action
            )
        ]
    }
    
    private var analyticsQuickActions: [QuickAction] {
        [
            QuickAction(
                title: "生成报表",
                subtitle: "创建自定义分析报表",
                icon: "doc.text.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                title: "数据导出",
                subtitle: "导出统计数据到 Excel",
                icon: "tablecells.badge.ellipsis",
                color: LopanColors.warning,
                type: .export
            )
        ]
    }
    
    private var productQuickActions: [QuickAction] {
        [
            QuickAction(
                title: "同步产品数据",
                subtitle: "从销售部门更新产品信息",
                icon: "arrow.triangle.2.circlepath",
                color: LopanColors.info,
                type: .sync
            ),
            QuickAction(
                title: "产品搜索",
                subtitle: "快速查找产品信息",
                icon: "magnifyingglass",
                color: LopanColors.primary,
                type: .search
            )
        ]
    }
    
    // MARK: - Action Handlers
    
    private func handleAction(_ action: QuickAction) {
        // Add haptic feedback
        HapticFeedback.medium()
        
        // Log action for analytics
        Task {
            await appDependencies.auditingService.logEvent(
                action: "quick_action_selected",
                entityId: authService.currentUser?.id ?? "unknown_user",
                details: "Quick action: \(action.title) in \(selectedTab.rawValue) tab (type: \(action.type.rawValue))"
            )
        }
        
        // Handle action based on type
        switch action.type {
        case .create, .importData, .export, .sync, .search:
            // Close menu and let parent handle navigation
            dismiss()
        case .action:
            // Handle inline actions
            performInlineAction(action)
        case .navigation:
            // Handle navigation
            break
        }
    }
    
    private func performInlineAction(_ action: QuickAction) {
        // Implement inline actions that don't require navigation
        switch action.title {
        case "批量处理":
            // Handle batch processing
            break
        case "分工管理":
            // Handle team assignment
            break
        default:
            break
        }
    }
    
    private func refreshData() {
        isLoading = true
        HapticFeedback.light()
        
        Task {
            // Simulate data refresh
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                isLoading = false
                // Show success feedback
                HapticFeedback.success()
            }
        }
    }
}

// MARK: - Quick Action Row Component

private struct QuickActionRow: View {
    let action: QuickAction
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LopanSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    if action.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(action.color)
                    } else {
                        Image(systemName: action.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(action.color)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                    Text(action.title)
                        .font(LopanTypography.titleSmall)
                        .fontWeight(.medium)
                        .foregroundStyle(LopanColors.textPrimary)
                    
                    Text(action.subtitle)
                        .font(LopanTypography.bodySmall)
                        .foregroundStyle(LopanColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LopanColors.textTertiary)
            }
            .padding(LopanSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                    .fill(LopanColors.surface)
                    .strokeBorder(
                        LopanColors.border.opacity(isPressed ? 0.3 : 0.1),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action.isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(LopanAnimation.cardHover) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement()
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }
}

// MARK: - Supporting Types

struct QuickAction {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let type: ActionType
    let isLoading: Bool
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        type: ActionType,
        isLoading: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.type = type
        self.isLoading = isLoading
    }
    
    enum ActionType: String {
        case create, importData, export, sync, search, action, navigation
    }
}

// MARK: - Haptic Feedback Extension
// Using HapticFeedback from LopanAnimation design system

// MARK: - Preview

#Preview {
    QuickActionMenu(
        selectedTab: .packaging,
        authService: {
            let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
            return AuthenticationService(repositoryFactory: repositoryFactory)
        }(),
        navigationService: WorkbenchNavigationService()
    )
}