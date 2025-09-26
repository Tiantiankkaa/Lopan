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
            .navigationTitle("warehouse_quick_actions_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_done".localized) {
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
                    
                    Text("warehouse_user_role_label".localized)
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
                    identifier: "system_switch_workbench",
                    title: "warehouse_quick_action_system_switch_title".localized,
                    subtitle: "warehouse_quick_action_system_switch_subtitle".localized,
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
                    identifier: "system_refresh_data",
                    title: "warehouse_quick_action_system_refresh_title".localized,
                    subtitle: "warehouse_quick_action_system_refresh_subtitle".localized,
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
                        identifier: "system_settings",
                        title: "warehouse_quick_action_system_settings_title".localized,
                        subtitle: "warehouse_quick_action_system_settings_subtitle".localized,
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
                identifier: "packaging_add_record",
                title: "warehouse_quick_action_packaging_add_title".localized,
                subtitle: "warehouse_quick_action_packaging_add_subtitle".localized,
                icon: "plus.circle.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                identifier: "packaging_bulk_import",
                title: "warehouse_quick_action_packaging_import_title".localized,
                subtitle: "warehouse_quick_action_packaging_import_subtitle".localized,
                icon: "square.and.arrow.down.fill",
                color: LopanColors.info,
                type: .importData
            ),
            QuickAction(
                identifier: "packaging_export_report",
                title: "warehouse_quick_action_packaging_export_title".localized,
                subtitle: "warehouse_quick_action_packaging_export_subtitle".localized,
                icon: "square.and.arrow.up.fill",
                color: LopanColors.warning,
                type: .export
            )
        ]
    }
    
    private var taskQuickActions: [QuickAction] {
        [
            QuickAction(
                identifier: "tasks_create_reminder",
                title: "warehouse_quick_action_tasks_create_title".localized,
                subtitle: "warehouse_quick_action_tasks_create_subtitle".localized,
                icon: "bell.badge.plus.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                identifier: "tasks_bulk_process",
                title: "warehouse_quick_action_tasks_bulk_title".localized,
                subtitle: "warehouse_quick_action_tasks_bulk_subtitle".localized,
                icon: "checklist",
                color: LopanColors.info,
                type: .action
            )
        ]
    }
    
    private var teamQuickActions: [QuickAction] {
        [
            QuickAction(
                identifier: "team_add_member",
                title: "warehouse_quick_action_team_add_title".localized,
                subtitle: "warehouse_quick_action_team_add_subtitle".localized,
                icon: "person.badge.plus.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                identifier: "team_assignment",
                title: "warehouse_quick_action_team_assign_title".localized,
                subtitle: "warehouse_quick_action_team_assign_subtitle".localized,
                icon: "person.2.gobackward",
                color: LopanColors.info,
                type: .action
            )
        ]
    }
    
    private var analyticsQuickActions: [QuickAction] {
        [
            QuickAction(
                identifier: "analytics_generate_report",
                title: "warehouse_quick_action_analytics_report_title".localized,
                subtitle: "warehouse_quick_action_analytics_report_subtitle".localized,
                icon: "doc.text.fill",
                color: LopanColors.success,
                type: .create
            ),
            QuickAction(
                identifier: "analytics_export_data",
                title: "warehouse_quick_action_analytics_export_title".localized,
                subtitle: "warehouse_quick_action_analytics_export_subtitle".localized,
                icon: "tablecells.badge.ellipsis",
                color: LopanColors.warning,
                type: .export
            )
        ]
    }
    
    private var productQuickActions: [QuickAction] {
        [
            QuickAction(
                identifier: "products_sync",
                title: "warehouse_quick_action_products_sync_title".localized,
                subtitle: "warehouse_quick_action_products_sync_subtitle".localized,
                icon: "arrow.triangle.2.circlepath",
                color: LopanColors.info,
                type: .sync
            ),
            QuickAction(
                identifier: "products_search",
                title: "warehouse_quick_action_products_search_title".localized,
                subtitle: "warehouse_quick_action_products_search_subtitle".localized,
                icon: "magnifyingglass",
                color: LopanColors.primary,
                type: .search
            )
        ]
    }
    
    // MARK: - Action Handlers
    
    private func handleAction(_ action: QuickAction) {
        // Add haptic feedback
        LopanHapticEngine.shared.medium()
        
        // Log action for analytics
        Task {
            await appDependencies.auditingService.logEvent(
                action: "quick_action_selected",
                entityId: authService.currentUser?.id ?? "unknown_user",
                details: "Quick action: \(action.identifier) in \(selectedTab.rawValue) tab (type: \(action.type.rawValue))"
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
        switch action.identifier {
        case "tasks_bulk_process":
            // Handle batch processing
            break
        case "team_assignment":
            // Handle team assignment
            break
        default:
            break
        }
    }
    
    private func refreshData() {
        isLoading = true
        LopanHapticEngine.shared.light()
        
        Task {
            // Simulate data refresh
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                isLoading = false
                // Show success feedback
                LopanHapticEngine.shared.success()
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
    let identifier: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let type: ActionType
    let isLoading: Bool
    
    init(
        identifier: String,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        type: ActionType,
        isLoading: Bool = false
    ) {
        self.identifier = identifier
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
