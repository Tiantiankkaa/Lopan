//
//  EnhancedEmptyStateView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import SwiftUI

// MARK: - Empty State Types

enum EmptyStateType {
    case noData
    case noSearchResults
    case noFilterResults
    case networkError
    case permissionDenied
    case maintenance
    case firstTime
    
    var defaultIcon: String {
        switch self {
        case .noData:
            return "tray"
        case .noSearchResults:
            return "magnifyingglass"
        case .noFilterResults:
            return "line.3.horizontal.decrease.circle"
        case .networkError:
            return "wifi.slash"
        case .permissionDenied:
            return "lock.shield"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .firstTime:
            return "hand.wave"
        }
    }
    
    var defaultTitle: String {
        switch self {
        case .noData:
            return "暂无数据"
        case .noSearchResults:
            return "无搜索结果"
        case .noFilterResults:
            return "无筛选结果"
        case .networkError:
            return "网络连接失败"
        case .permissionDenied:
            return "权限不足"
        case .maintenance:
            return "系统维护中"
        case .firstTime:
            return "欢迎使用"
        }
    }
    
    var defaultMessage: String {
        switch self {
        case .noData:
            return "还没有任何数据，点击添加按钮开始添加"
        case .noSearchResults:
            return "未找到匹配的结果，请尝试其他搜索词"
        case .noFilterResults:
            return "当前筛选条件下没有匹配项，请调整筛选条件"
        case .networkError:
            return "请检查网络连接后重试"
        case .permissionDenied:
            return "您没有访问此功能的权限"
        case .maintenance:
            return "系统正在维护中，请稍后再试"
        case .firstTime:
            return "这里将显示您的数据，让我们开始添加第一条记录吧"
        }
    }
}

// MARK: - Empty State Action

struct EmptyStateAction {
    let title: String
    let action: () -> Void
    let style: ActionStyle
    let accessibilityHint: String?
    
    enum ActionStyle {
        case primary
        case secondary
        case destructive
    }
    
    init(
        title: String,
        style: ActionStyle = .primary,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
}

// MARK: - Enhanced Empty State View

struct EnhancedEmptyStateView: View {
    let type: EmptyStateType
    let title: String?
    let message: String?
    let icon: String?
    let actions: [EmptyStateAction]
    let customContent: AnyView?
    
    init(
        type: EmptyStateType,
        title: String? = nil,
        message: String? = nil,
        icon: String? = nil,
        actions: [EmptyStateAction] = [],
        customContent: AnyView? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.icon = icon
        self.actions = actions
        self.customContent = customContent
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: icon ?? type.defaultIcon)
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.secondary)
                .accessibilityHidden(true) // Decorative icon
            
            // Text content
            VStack(spacing: 12) {
                DynamicText(
                    title ?? type.defaultTitle,
                    style: .title2,
                    alignment: .center
                )
                .fontWeight(.medium)
                
                DynamicText(
                    message ?? type.defaultMessage,
                    style: .body,
                    alignment: .center
                )
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
            
            // Custom content
            if let customContent = customContent {
                customContent
            }
            
            // Actions
            if !actions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(actions.indices, id: \.self) { index in
                        let action = actions[index]
                        EmptyStateActionButton(action: action)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title ?? type.defaultTitle). \(message ?? type.defaultMessage)")
    }
}

// MARK: - Empty State Action Button

struct EmptyStateActionButton: View {
    let action: EmptyStateAction
    
    var body: some View {
        AccessibleButton(
            action: action.action,
            accessibilityLabel: action.title,
            accessibilityHint: action.accessibilityHint
        ) {
            DynamicText(action.title, style: .callout)
                .fontWeight(.medium)
                .foregroundColor(buttonTextColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(buttonBackgroundColor)
                .cornerRadius(8)
        }
    }
    
    private var buttonTextColor: Color {
        switch action.style {
        case .primary:
            return LopanColors.textOnPrimary
        case .secondary:
            return .accentColor
        case .destructive:
            return LopanColors.textOnPrimary
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch action.style {
        case .primary:
            return .accentColor
        case .secondary:
            return LopanColors.primary.opacity(0.1)
        case .destructive:
            return LopanColors.error
        }
    }
}

// MARK: - Specialized Empty States

/// Empty state for customer out of stock list
struct CustomerOutOfStockEmptyState: View {
    let hasFilter: Bool
    let onAddRecord: () -> Void
    let onClearFilter: (() -> Void)?
    
    var body: some View {
        EnhancedEmptyStateView(
            type: hasFilter ? .noFilterResults : .noData,
            title: hasFilter ? "无匹配结果" : "暂无缺货记录",
            message: hasFilter ? 
                "当前筛选条件下没有找到缺货记录\n请尝试调整筛选条件" : 
                "还没有任何缺货记录\n点击添加按钮创建第一条记录",
            actions: actions
        )
    }
    
    private var actions: [EmptyStateAction] {
        var actionList: [EmptyStateAction] = []
        
        if !hasFilter {
            actionList.append(
                EmptyStateAction(
                    title: "添加缺货记录",
                    accessibilityHint: "创建一条新的客户缺货记录",
                    action: onAddRecord
                )
            )
        } else if let onClearFilter = onClearFilter {
            actionList.append(
                EmptyStateAction(
                    title: "清除筛选条件",
                    style: .secondary,
                    accessibilityHint: "移除所有筛选条件显示全部记录",
                    action: onClearFilter
                )
            )
        }
        
        return actionList
    }
}

/// Empty state for search results
struct SearchResultsEmptyState: View {
    let searchText: String
    let onClearSearch: () -> Void
    
    var body: some View {
        EnhancedEmptyStateView(
            type: .noSearchResults,
            title: "未找到匹配结果",
            message: "没有找到与「\(searchText)」相关的记录\n请尝试其他搜索关键词",
            actions: [
                EmptyStateAction(
                    title: "清除搜索",
                    style: .secondary,
                    accessibilityHint: "清除搜索关键词显示全部记录",
                    action: onClearSearch
                )
            ]
        )
    }
}

/// Empty state for network errors
struct NetworkErrorEmptyState: View {
    let onRetry: () -> Void
    
    var body: some View {
        EnhancedEmptyStateView(
            type: .networkError,
            title: "网络连接失败",
            message: "无法连接到服务器\n请检查网络连接后重试",
            icon: "wifi.slash",
            actions: [
                EmptyStateAction(
                    title: "重新加载",
                    accessibilityHint: "重新尝试加载数据",
                    action: onRetry
                )
            ]
        )
    }
}

/// Empty state for permission denied
struct PermissionDeniedEmptyState: View {
    let featureName: String
    let onContactAdmin: (() -> Void)?
    
    var body: some View {
        EnhancedEmptyStateView(
            type: .permissionDenied,
            title: "权限不足",
            message: "您没有访问「\(featureName)」的权限\n请联系管理员获取相应权限",
            actions: contactAdminAction
        )
    }
    
    private var contactAdminAction: [EmptyStateAction] {
        guard let onContactAdmin = onContactAdmin else { return [] }
        
        return [
            EmptyStateAction(
                title: "联系管理员",
                style: .secondary,
                accessibilityHint: "联系系统管理员申请权限",
                action: onContactAdmin
            )
        ]
    }
}

/// Empty state for first-time users
struct FirstTimeUserEmptyState: View {
    let featureName: String
    let onGetStarted: () -> Void
    let onLearnMore: (() -> Void)?
    
    var body: some View {
        EnhancedEmptyStateView(
            type: .firstTime,
            title: "欢迎使用\(featureName)",
            message: "这里将显示您的\(featureName)数据\n让我们开始添加第一条记录吧",
            actions: actions
        )
    }
    
    private var actions: [EmptyStateAction] {
        var actionList = [
            EmptyStateAction(
                title: "开始使用",
                accessibilityHint: "开始使用\(featureName)功能",
                action: onGetStarted
            )
        ]
        
        if let onLearnMore = onLearnMore {
            actionList.append(
                EmptyStateAction(
                    title: "了解更多",
                    style: .secondary,
                    accessibilityHint: "了解\(featureName)功能的详细信息",
                    action: onLearnMore
                )
            )
        }
        
        return actionList
    }
}

// MARK: - Preview Extensions

#if DEBUG
struct EnhancedEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // No data state
            EnhancedEmptyStateView(
                type: .noData,
                actions: [
                    EmptyStateAction(title: "添加数据") { }
                ]
            )
            .previewDisplayName("No Data")
            
            // Search results state
            SearchResultsEmptyState(
                searchText: "测试搜索",
                onClearSearch: { }
            )
            .previewDisplayName("No Search Results")
            
            // Network error state
            NetworkErrorEmptyState(onRetry: { })
            .previewDisplayName("Network Error")
            
            // Permission denied state
            PermissionDeniedEmptyState(
                featureName: "客户管理",
                onContactAdmin: { }
            )
            .previewDisplayName("Permission Denied")
        }
    }
}
#endif