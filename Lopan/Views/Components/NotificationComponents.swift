//
//  NotificationComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Notification Badge Component (通知徽章组件)

/// Notification badge for showing unread count
/// 显示未读数量的通知徽章
struct NotificationBadge: View {
    let count: Int
    let maxDisplayCount: Int
    
    init(count: Int, maxDisplayCount: Int = 99) {
        self.count = count
        self.maxDisplayCount = maxDisplayCount
    }
    
    var body: some View {
        if count > 0 {
            Text(count > maxDisplayCount ? "\(maxDisplayCount)+" : "\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 6 : 4)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule())
                .scaleEffect(count > 0 ? 1.0 : 0.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
        }
    }
}

// MARK: - Notification Item Component (通知项组件)

/// Individual notification item display
/// 单个通知项显示
struct NotificationItemView: View {
    let notification: NotificationMessage
    let onRead: () -> Void
    let onAction: (NotificationAction) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                // Category icon
                Image(systemName: notification.category.icon)
                    .foregroundColor(notification.priority.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.headline)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    Text(notification.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority indicator
                PriorityIndicator(priority: notification.priority)
                
                // Read indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Body
            Text(notification.body)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            
            // Expand/Collapse toggle
            if notification.body.count > 100 {
                Button(isExpanded ? "收起" : "展开") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Action buttons
            if !notification.actionButtons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(notification.actionButtons) { action in
                        Button(action.title) {
                            onAction(action)
                        }
                        .buttonStyle(ActionButtonStyle(style: action.style))
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(notification.isRead ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            if !notification.isRead {
                onRead()
            }
        }
    }
}

/// Priority indicator for notifications
/// 通知的优先级指示器
struct PriorityIndicator: View {
    let priority: NotificationPriority
    
    var body: some View {
        HStack(spacing: 2) {
            Text(priority.displayName)
                .font(.caption2)
                .fontWeight(.medium)
            
            Circle()
                .fill(priority.color)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priority.color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Custom button style for notification actions
/// 通知操作的自定义按钮样式
struct ActionButtonStyle: ButtonStyle {
    let style: NotificationAction.ActionStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .default:
            return .blue
        case .destructive:
            return .red
        case .cancel:
            return .gray
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .default:
            return .blue.opacity(0.1)
        case .destructive:
            return .red.opacity(0.1)
        case .cancel:
            return .gray.opacity(0.1)
        }
    }
}

// MARK: - Notification List Component (通知列表组件)

/// Scrollable list of notifications with filtering
/// 带筛选功能的可滚动通知列表
struct NotificationListView: View {
    @ObservedObject var notificationEngine: NotificationEngine
    @State private var selectedFilter: NotificationCategory?
    @State private var selectedPriority: NotificationPriority?
    @State private var showingFilters = false
    
    private var filteredNotifications: [NotificationMessage] {
        var notifications = notificationEngine.activeNotifications
        
        if let category = selectedFilter {
            notifications = notifications.filter { $0.category == category }
        }
        
        if let priority = selectedPriority {
            notifications = notifications.filter { $0.priority == priority }
        }
        
        return notifications.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with filters
            header
            
            // Notification list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredNotifications) { notification in
                        NotificationItemView(
                            notification: notification,
                            onRead: {
                                Task {
                                    await notificationEngine.markAsRead(
                                        notification.id,
                                        userId: "current_user" // This should come from auth service
                                    )
                                }
                            },
                            onAction: { action in
                                handleNotificationAction(action, for: notification)
                            }
                        )
                    }
                    
                    if filteredNotifications.isEmpty {
                        EmptyNotificationState(
                            hasFilter: selectedFilter != nil || selectedPriority != nil,
                            onClearFilters: {
                                selectedFilter = nil
                                selectedPriority = nil
                            }
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .refreshable {
                // Trigger refresh if needed
            }
        }
        .sheet(isPresented: $showingFilters) {
            NotificationFiltersView(
                selectedCategory: $selectedFilter,
                selectedPriority: $selectedPriority
            )
        }
    }
    
    private var header: some View {
        HStack {
            Text("通知")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Filter indicators
            if selectedFilter != nil || selectedPriority != nil {
                Button("清除筛选") {
                    selectedFilter = nil
                    selectedPriority = nil
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Filter button
            Button(action: { showingFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Notification badge
            NotificationBadge(
                count: notificationEngine.activeNotifications.filter { !$0.isRead }.count
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private func handleNotificationAction(_ action: NotificationAction, for notification: NotificationMessage) {
        switch action.action {
        case .navigate:
            // Handle navigation based on action data
            if let route = action.data["route"] {
                // Implement navigation logic
                print("Navigate to: \(route)")
            }
        case .approve:
            // Handle approval action
            print("Approved notification: \(notification.id)")
        case .reject:
            // Handle rejection action
            print("Rejected notification: \(notification.id)")
        case .acknowledge:
            Task {
                await notificationEngine.markAsRead(notification.id, userId: "current_user")
            }
        case .custom:
            // Handle custom actions based on action data
            if let customAction = action.data["action"] {
                print("Custom action: \(customAction)")
            }
        }
    }
}

/// Empty state for notification list
/// 通知列表的空状态
struct EmptyNotificationState: View {
    let hasFilter: Bool
    let onClearFilters: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasFilter ? "line.3.horizontal.decrease.circle" : "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(hasFilter ? "没有符合筛选条件的通知" : "暂无通知")
                .font(.headline)
                .foregroundColor(.gray)
            
            if hasFilter {
                Button("清除筛选条件", action: onClearFilters)
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Notification Filters View (通知筛选视图)

/// Filter options for notifications
/// 通知的筛选选项
struct NotificationFiltersView: View {
    @Binding var selectedCategory: NotificationCategory?
    @Binding var selectedPriority: NotificationPriority?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("按类别筛选") {
                    ForEach(NotificationCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                            
                            Text(category.displayName)
                            
                            Spacer()
                            
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                
                Section("按优先级筛选") {
                    ForEach(NotificationPriority.allCases, id: \.self) { priority in
                        HStack {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 12, height: 12)
                            
                            Text(priority.displayName)
                            
                            Spacer()
                            
                            if selectedPriority == priority {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPriority = selectedPriority == priority ? nil : priority
                        }
                    }
                }
            }
            .navigationTitle("筛选通知")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        selectedCategory = nil
                        selectedPriority = nil
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Alert Components (警报组件)

/// Alert item display for real-time alerts
/// 实时警报的警报项显示
struct AlertItemView: View {
    let alert: RealTimeAlert
    let onAcknowledge: () -> Void
    let onResolve: () -> Void
    let onEscalate: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Severity indicator
                AlertSeverityBadge(severity: alert.severity)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: alert.source.icon)
                            .font(.caption)
                        
                        Text(alert.source.displayName)
                            .font(.caption)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(alert.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                AlertStatusBadge(status: alert.status)
            }
            
            // Description
            Text(alert.description)
                .font(.body)
            
            // Affected entities
            if !alert.affectedEntities.isEmpty {
                HStack {
                    Text("影响对象:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(alert.affectedEntities.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recommended actions
            if !alert.recommendedActions.isEmpty && showingActions {
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议操作:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(alert.recommendedActions, id: \.self) { action in
                        HStack {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(action)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                if alert.status == .active {
                    Button("确认") {
                        onAcknowledge()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if alert.status == .acknowledged {
                    Button("解决") {
                        onResolve()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                if alert.severity == .critical || alert.severity == .emergency {
                    Button("升级") {
                        onEscalate()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.orange)
                }
                
                Button(showingActions ? "收起" : "详情") {
                    withAnimation {
                        showingActions.toggle()
                    }
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .foregroundColor(.blue)
                
                Spacer()
            }
        }
        .padding()
        .background(alertBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alert.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var alertBackgroundColor: Color {
        switch alert.severity {
        case .emergency:
            return Color.red.opacity(0.05)
        case .critical:
            return Color.purple.opacity(0.05)
        case .error:
            return Color.red.opacity(0.03)
        case .warning:
            return Color.orange.opacity(0.03)
        case .info:
            return Color(UIColor.systemBackground)
        }
    }
}

/// Alert severity badge
/// 警报严重程度徽章
struct AlertSeverityBadge: View {
    let severity: AlertSeverity
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: severityIcon)
                .font(.caption)
            
            Text(severity.displayName)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(severity.color)
        .cornerRadius(8)
    }
    
    private var severityIcon: String {
        switch severity {
        case .emergency:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle"
        case .info:
            return "info.circle"
        }
    }
}

/// Alert status badge
/// 警报状态徽章
struct AlertStatusBadge: View {
    let status: AlertStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.1))
            .cornerRadius(6)
    }
}

// MARK: - Alert Dashboard Component (警报仪表板组件)

/// Real-time alert dashboard
/// 实时警报仪表板
struct AlertDashboardView: View {
    @ObservedObject var alertService: RealTimeAlertService
    @State private var selectedSeverity: AlertSeverity?
    @State private var selectedSource: AlertSource?
    @State private var showingResolved = false
    
    private var filteredAlerts: [RealTimeAlert] {
        var alerts = showingResolved ? [] : alertService.activeAlerts
        
        if let severity = selectedSeverity {
            alerts = alerts.filter { $0.severity == severity }
        }
        
        if let source = selectedSource {
            alerts = alerts.filter { $0.source == source }
        }
        
        return alerts.sorted { alert1, alert2 in
            if alert1.severity != alert2.severity {
                let severity1Index = AlertSeverity.allCases.firstIndex(of: alert1.severity) ?? 0
                let severity2Index = AlertSeverity.allCases.firstIndex(of: alert2.severity) ?? 0
                return severity1Index > severity2Index
            }
            return alert1.timestamp > alert2.timestamp
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Dashboard header
            dashboardHeader
            
            // Alert statistics
            alertStatistics
            
            // Filter controls
            filterControls
            
            // Alert list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAlerts) { alert in
                        AlertItemView(
                            alert: alert,
                            onAcknowledge: {
                                Task {
                                    try? await alertService.acknowledgeAlert(
                                        alert.id,
                                        userId: "current_user",
                                        comment: "手动确认"
                                    )
                                }
                            },
                            onResolve: {
                                Task {
                                    try? await alertService.resolveAlert(
                                        alert.id,
                                        userId: "current_user",
                                        resolution: "已处理"
                                    )
                                }
                            },
                            onEscalate: {
                                Task {
                                    try? await alertService.escalateAlert(
                                        alert.id,
                                        toLevel: 1,
                                        reason: "需要上级处理"
                                    )
                                }
                            }
                        )
                    }
                    
                    if filteredAlerts.isEmpty {
                        EmptyAlertState(
                            hasFilter: selectedSeverity != nil || selectedSource != nil,
                            showingResolved: showingResolved,
                            onClearFilters: {
                                selectedSeverity = nil
                                selectedSource = nil
                            }
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
        }
    }
    
    private var dashboardHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("实时警报")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(alertService.isMonitoring ? "监控中" : "已暂停")
                    .font(.caption)
                    .foregroundColor(alertService.isMonitoring ? .green : .orange)
            }
            
            Spacer()
            
            // Monitoring toggle
            Button(alertService.isMonitoring ? "暂停监控" : "启动监控") {
                if alertService.isMonitoring {
                    alertService.stopMonitoring()
                } else {
                    alertService.startMonitoring()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var alertStatistics: some View {
        HStack(spacing: 16) {
            ForEach(AlertSeverity.allCases, id: \.self) { severity in
                let count = alertService.activeAlerts.filter { $0.severity == severity }.count
                
                VStack {
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(severity.color)
                    
                    Text(severity.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSeverity = selectedSeverity == severity ? nil : severity
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSeverity == severity ? severity.color.opacity(0.1) : Color.clear)
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var filterControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Source filters
                ForEach(AlertSource.allCases, id: \.self) { source in
                    Button(source.displayName) {
                        selectedSource = selectedSource == source ? nil : source
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(selectedSource == source ? .white : .blue)
                    .background(selectedSource == source ? Color.blue : Color.clear)
                }
                
                Divider()
                    .frame(height: 20)
                
                // Show resolved toggle
                Button(showingResolved ? "显示活跃" : "显示已解决") {
                    showingResolved.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

/// Empty state for alert dashboard
/// 警报仪表板的空状态
struct EmptyAlertState: View {
    let hasFilter: Bool
    let showingResolved: Bool
    let onClearFilters: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasFilter ? "line.3.horizontal.decrease.circle" : (showingResolved ? "checkmark.circle" : "shield.checkered"))
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(emptyMessage)
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if hasFilter {
                Button("清除筛选条件", action: onClearFilters)
                    .buttonStyle(.bordered)
            }
        }
    }
    
    private var emptyMessage: String {
        if hasFilter {
            return "没有符合筛选条件的警报"
        } else if showingResolved {
            return "暂无已解决的警报"
        } else {
            return "系统运行正常\n暂无活跃警报"
        }
    }
}

// MARK: - Quick Notification Component (快速通知组件)

/// Quick notification overlay for immediate alerts
/// 用于即时警报的快速通知覆盖层
struct QuickNotificationOverlay: View {
    let notification: NotificationMessage
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: notification.category.icon)
                    .foregroundColor(notification.priority.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(notification.body)
                        .font(.body)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .offset(y: offset)
            .opacity(opacity)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                offset = 0
                opacity = 1
            }
            
            // Auto dismiss after 5 seconds for non-critical notifications
            if notification.priority != .critical && notification.priority != .urgent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    dismissWithAnimation()
                }
            }
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            offset = -100
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct NotificationComponents_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Notification Badge Preview
            NotificationBadge(count: 5)
                .previewDisplayName("Notification Badge")
            
            // Priority Indicator Preview
            VStack {
                ForEach(NotificationPriority.allCases, id: \.self) { priority in
                    PriorityIndicator(priority: priority)
                }
            }
            .previewDisplayName("Priority Indicators")
            
            // Alert Severity Badge Preview
            VStack {
                ForEach(AlertSeverity.allCases, id: \.self) { severity in
                    AlertSeverityBadge(severity: severity)
                }
            }
            .previewDisplayName("Alert Severity Badges")
        }
    }
}
#endif