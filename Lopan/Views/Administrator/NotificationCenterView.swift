//
//  NotificationCenterView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Notification Center Main View (通知中心主视图)

/// Comprehensive notification center for administrators
/// 管理员的综合通知中心
struct NotificationCenterView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State private var selectedTab = NotificationTab.notifications
    @State private var showingSettings = false
    @State private var showingQuickNotification: NotificationMessage?
    
    enum NotificationTab: String, CaseIterable {
        case notifications = "notifications"
        case alerts = "alerts"
        case rules = "rules"
        case analytics = "analytics"
        
        var title: String {
            switch self {
            case .notifications: return "通知"
            case .alerts: return "警报"
            case .rules: return "规则"
            case .analytics: return "分析"
            }
        }
        
        var icon: String {
            switch self {
            case .notifications: return "bell"
            case .alerts: return "exclamationmark.triangle"
            case .rules: return "gear"
            case .analytics: return "chart.bar"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker
                
                // Content based on selected tab
                tabContent
            }
            .navigationTitle("通知中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NotificationSettingsView()
                    .environmentObject(appDependencies.serviceFactory)
            }
            .overlay(
                // Quick notification overlay
                Group {
                    if let notification = showingQuickNotification {
                        QuickNotificationOverlay(
                            notification: notification,
                            onDismiss: {
                                showingQuickNotification = nil
                            },
                            onTap: {
                                showingQuickNotification = nil
                                selectedTab = .notifications
                            }
                        )
                        .padding()
                        .zIndex(1000)
                    }
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickNotificationReceived)) { notification in
            if let userInfo = notification.userInfo,
               let notificationData = userInfo["notification"] as? NotificationMessage {
                showingQuickNotification = notificationData
            }
        }
    }
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(NotificationTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.title)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .background(
                    Rectangle()
                        .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                )
            }
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .notifications:
            if let notificationEngine = getNotificationEngine() {
                NotificationListView(notificationEngine: notificationEngine)
            } else {
                Text("通知服务不可用")
                    .foregroundColor(.secondary)
            }
        case .alerts:
            if let alertService = getRealTimeAlertService() {
                AlertDashboardView(alertService: alertService)
            } else {
                Text("警报服务不可用")
                    .foregroundColor(.secondary)
            }
        case .rules:
            NotificationRulesView()
                .environmentObject(appDependencies.serviceFactory)
        case .analytics:
            NotificationAnalyticsView()
                .environmentObject(appDependencies.serviceFactory)
        }
    }
    
    private func getNotificationEngine() -> NotificationEngine? {
        return appDependencies.serviceFactory.notificationEngine
    }
    
    private func getRealTimeAlertService() -> RealTimeAlertService? {
        return appDependencies.serviceFactory.realTimeAlertService
    }
}

// MARK: - Notification Rules Management (通知规则管理)

/// View for managing notification rules and alert rules
/// 管理通知规则和警报规则的视图
struct NotificationRulesView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State private var showingNewRule = false
    @State private var selectedRule: AlertRule?
    @State private var alertRules: [AlertRule] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("通知规则")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("新建规则") {
                    showingNewRule = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            
            // Rules list
            List {
                ForEach(alertRules) { rule in
                    NotificationRuleRow(
                        rule: rule,
                        onEdit: { selectedRule = rule },
                        onToggle: { toggleRule(rule) },
                        onDelete: { deleteRule(rule) }
                    )
                }
            }
            .listStyle(.plain)
        }
        .sheet(isPresented: $showingNewRule) {
            NewNotificationRuleView { rule in
                alertRules.append(rule)
            }
        }
        .sheet(item: $selectedRule) { rule in
            EditNotificationRuleView(rule: rule) { updatedRule in
                if let index = alertRules.firstIndex(where: { $0.id == rule.id }) {
                    alertRules[index] = updatedRule
                }
            }
        }
        .onAppear {
            loadRules()
        }
    }
    
    private func loadRules() {
        // Load rules from service
        // For now, create some sample rules
        alertRules = createSampleRules()
    }
    
    private func toggleRule(_ rule: AlertRule) {
        // Toggle rule active state
    }
    
    private func deleteRule(_ rule: AlertRule) {
        alertRules.removeAll { $0.id == rule.id }
    }
    
    private func createSampleRules() -> [AlertRule] {
        return [
            AlertRule(
                name: "机台温度监控",
                description: "监控机台温度异常",
                source: .machine,
                severity: .warning,
                conditions: [
                    AlertCondition(
                        id: UUID().uuidString,
                        type: .threshold,
                        field: "temperature",
                        comparisonOperator: .greaterThan,
                        value: "80",
                        aggregationType: nil,
                        timeWindow: nil
                    )
                ],
                createdBy: "system"
            ),
            AlertRule(
                name: "批次超时警报",
                description: "批次运行时间超过预期",
                source: .production,
                severity: .error,
                conditions: [
                    AlertCondition(
                        id: UUID().uuidString,
                        type: .threshold,
                        field: "batch_duration",
                        comparisonOperator: .greaterThan,
                        value: "14400",
                        aggregationType: nil,
                        timeWindow: nil
                    )
                ],
                createdBy: "system"
            )
        ]
    }
}

/// Individual notification rule row
/// 单个通知规则行
struct NotificationRuleRow: View {
    let rule: AlertRule
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(rule.isActive))
                        .labelsHidden()
                        .onChange(of: rule.isActive) { _ in
                            onToggle()
                        }
                }
                
                Text(rule.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    // Source badge
                    HStack(spacing: 4) {
                        Image(systemName: rule.source.icon)
                        Text(rule.source.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                    
                    // Severity badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(rule.severity.color)
                            .frame(width: 8, height: 8)
                        Text(rule.severity.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(rule.severity.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(rule.severity.color.opacity(0.1))
                    .cornerRadius(4)
                    
                    Spacer()
                    
                    // Last triggered
                    if let lastTriggered = rule.lastTriggered {
                        Text("最后触发: \(lastTriggered, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Actions
            VStack {
                Button("编辑", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("删除", action: onDelete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Rule Creation (新规则创建)

/// View for creating new notification rules
/// 创建新通知规则的视图
struct NewNotificationRuleView: View {
    let onSave: (AlertRule) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var ruleName = ""
    @State private var ruleDescription = ""
    @State private var selectedSource = AlertSource.machine
    @State private var selectedSeverity = AlertSeverity.warning
    @State private var conditions: [AlertCondition] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $ruleName)
                    TextField("描述", text: $ruleDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("警报配置") {
                    Picker("警报源", selection: $selectedSource) {
                        ForEach(AlertSource.allCases, id: \.self) { source in
                            HStack {
                                Image(systemName: source.icon)
                                Text(source.displayName)
                            }
                            .tag(source)
                        }
                    }
                    
                    Picker("严重程度", selection: $selectedSeverity) {
                        ForEach(AlertSeverity.allCases, id: \.self) { severity in
                            HStack {
                                Circle()
                                    .fill(severity.color)
                                    .frame(width: 12, height: 12)
                                Text(severity.displayName)
                            }
                            .tag(severity)
                        }
                    }
                }
                
                Section("触发条件") {
                    ForEach(conditions, id: \.id) { condition in
                        ConditionRow(condition: condition)
                    }
                    
                    Button("添加条件") {
                        addCondition()
                    }
                }
            }
            .navigationTitle("新建规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRule()
                    }
                    .disabled(ruleName.isEmpty || ruleDescription.isEmpty)
                }
            }
        }
    }
    
    private func addCondition() {
        let newCondition = AlertCondition(
            id: UUID().uuidString,
            type: .threshold,
            field: "temperature",
            comparisonOperator: .greaterThan,
            value: "80",
            aggregationType: nil,
            timeWindow: nil
        )
        conditions.append(newCondition)
    }
    
    private func saveRule() {
        let rule = AlertRule(
            name: ruleName,
            description: ruleDescription,
            source: selectedSource,
            severity: selectedSeverity,
            conditions: conditions,
            createdBy: "current_user"
        )
        
        onSave(rule)
        dismiss()
    }
}

/// Row for displaying and editing alert conditions
/// 显示和编辑警报条件的行
struct ConditionRow: View {
    let condition: AlertCondition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(condition.field)
                    .font(.headline)
                
                Text(condition.comparisonOperator.rawValue)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(condition.value)
                    .font(.body)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("类型: \(condition.type.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Edit Rule View (编辑规则视图)

/// View for editing existing notification rules
/// 编辑现有通知规则的视图
struct EditNotificationRuleView: View {
    let rule: AlertRule
    let onSave: (AlertRule) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var ruleName: String
    @State private var ruleDescription: String
    @State private var isActive: Bool
    
    init(rule: AlertRule, onSave: @escaping (AlertRule) -> Void) {
        self.rule = rule
        self.onSave = onSave
        self._ruleName = State(initialValue: rule.name)
        self._ruleDescription = State(initialValue: rule.description)
        self._isActive = State(initialValue: rule.isActive)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $ruleName)
                    TextField("描述", text: $ruleDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Toggle("启用规则", isOn: $isActive)
                }
                
                Section("规则统计") {
                    HStack {
                        Text("触发次数")
                        Spacer()
                        Text("\(rule.triggerCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastTriggered = rule.lastTriggered {
                        HStack {
                            Text("最后触发")
                            Spacer()
                            Text(lastTriggered, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(rule.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        // Create updated rule (in a real implementation, you'd properly update the rule)
        let updatedRule = AlertRule(
            name: ruleName,
            description: ruleDescription,
            source: rule.source,
            severity: rule.severity,
            conditions: rule.conditions,
            createdBy: rule.createdBy
        )
        
        onSave(updatedRule)
        dismiss()
    }
}

// MARK: - Notification Analytics (通知分析)

/// Analytics view for notification system performance
/// 通知系统性能的分析视图
struct NotificationAnalyticsView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State private var selectedTimeRange = TimeRange.day
    @State private var analytics = NotificationAnalytics()
    
    enum TimeRange: String, CaseIterable {
        case hour = "1h"
        case day = "24h"
        case week = "7d"
        case month = "30d"
        
        var displayName: String {
            switch self {
            case .hour: return "1小时"
            case .day: return "24小时"
            case .week: return "7天"
            case .month: return "30天"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time range picker
                timeRangePicker
                
                // Key metrics cards
                keyMetricsGrid
                
                // Delivery success rate chart
                deliverySuccessChart
                
                // Alert frequency chart
                alertFrequencyChart
                
                // Response time metrics
                responseTimeMetrics
            }
            .padding()
        }
    }
    
    private var timeRangePicker: some View {
        HStack {
            Text("时间范围")
                .font(.headline)
            
            Spacer()
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }
    
    private var keyMetricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            MetricCard(
                title: "总通知数",
                value: "\(analytics.totalNotifications)",
                trend: "+12%",
                color: .blue
            )
            
            MetricCard(
                title: "活跃警报",
                value: "\(analytics.activeAlerts)",
                trend: "-5%",
                color: .orange
            )
            
            MetricCard(
                title: "平均响应时间",
                value: "\(Int(analytics.averageResponseTime))分钟",
                trend: "-8%",
                color: .green
            )
            
            MetricCard(
                title: "成功传递率",
                value: "\(Int(analytics.deliverySuccessRate * 100))%",
                trend: "+2%",
                color: .purple
            )
        }
    }
    
    private var deliverySuccessChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("传递成功率")
                .font(.headline)
            
            // Placeholder for chart - in a real app, you'd use a charting library
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("传递成功率图表")
                        .foregroundColor(.secondary)
                )
        }
    }
    
    private var alertFrequencyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("警报频次")
                .font(.headline)
            
            // Placeholder for chart
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("警报频次图表")
                        .foregroundColor(.secondary)
                )
        }
    }
    
    private var responseTimeMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("响应时间分析")
                .font(.headline)
            
            VStack(spacing: 8) {
                ResponseTimeRow(severity: .critical, avgTime: 3.2, targetTime: 5.0)
                ResponseTimeRow(severity: .error, avgTime: 8.5, targetTime: 15.0)
                ResponseTimeRow(severity: .warning, avgTime: 25.0, targetTime: 30.0)
                ResponseTimeRow(severity: .info, avgTime: 45.0, targetTime: 60.0)
            }
        }
    }
}

/// Metric card for displaying key performance indicators
/// 显示关键性能指标的指标卡
struct MetricCard: View {
    let title: String
    let value: String
    let trend: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(trend)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trend.hasPrefix("+") ? .green : .red)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Row showing response time metrics for different alert severities
/// 显示不同警报严重程度响应时间指标的行
struct ResponseTimeRow: View {
    let severity: AlertSeverity
    let avgTime: Double
    let targetTime: Double
    
    private var isWithinTarget: Bool {
        avgTime <= targetTime
    }
    
    var body: some View {
        HStack {
            // Severity indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(severity.color)
                    .frame(width: 8, height: 8)
                
                Text(severity.displayName)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Time metrics
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(avgTime, specifier: "%.1f")分钟")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isWithinTarget ? .green : .red)
                
                Text("目标: \(targetTime, specifier: "%.0f")分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notification Settings (通知设置)

/// Settings view for notification preferences
/// 通知偏好设置视图
struct NotificationSettingsView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    
    @State private var enablePushNotifications = true
    @State private var enableEmailNotifications = false
    @State private var enableSMSNotifications = false
    @State private var quietHours = false
    @State private var quietStartTime = Date()
    @State private var quietEndTime = Date()
    @State private var notificationSound = "default"
    
    var body: some View {
        NavigationView {
            Form {
                Section("通知渠道") {
                    Toggle("推送通知", isOn: $enablePushNotifications)
                    Toggle("邮件通知", isOn: $enableEmailNotifications)
                    Toggle("短信通知", isOn: $enableSMSNotifications)
                }
                
                Section("免打扰时间") {
                    Toggle("启用免打扰", isOn: $quietHours)
                    
                    if quietHours {
                        DatePicker("开始时间", selection: $quietStartTime, displayedComponents: .hourAndMinute)
                        DatePicker("结束时间", selection: $quietEndTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("声音设置") {
                    Picker("通知声音", selection: $notificationSound) {
                        Text("默认").tag("default")
                        Text("警报").tag("alert")
                        Text("铃声").tag("bell")
                        Text("静音").tag("silent")
                    }
                }
                
                Section("高级设置") {
                    NavigationLink("通知优先级设置") {
                        NotificationPrioritySettingsView()
                    }
                    
                    NavigationLink("渠道配置") {
                        NotificationChannelSettingsView()
                    }
                    
                    Button("重置为默认设置") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("通知设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // Save notification settings
    }
    
    private func resetToDefaults() {
        enablePushNotifications = true
        enableEmailNotifications = false
        enableSMSNotifications = false
        quietHours = false
        notificationSound = "default"
    }
}

/// Priority-based notification settings
/// 基于优先级的通知设置
struct NotificationPrioritySettingsView: View {
    @State private var prioritySettings: [NotificationPriority: PrioritySettings] = [:]
    
    struct PrioritySettings {
        var enabledChannels: Set<NotificationChannel>
        var customSound: String
        var vibration: Bool
    }
    
    var body: some View {
        List {
            ForEach(NotificationPriority.allCases, id: \.self) { priority in
                Section(priority.displayName) {
                    // Channel toggles for this priority
                    ForEach(NotificationChannel.allCases, id: \.self) { channel in
                        Toggle(channel.displayName, isOn: bindingForChannel(priority, channel))
                    }
                }
            }
        }
        .navigationTitle("优先级设置")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func bindingForChannel(_ priority: NotificationPriority, _ channel: NotificationChannel) -> Binding<Bool> {
        Binding(
            get: {
                prioritySettings[priority]?.enabledChannels.contains(channel) ?? false
            },
            set: { enabled in
                if prioritySettings[priority] == nil {
                    prioritySettings[priority] = PrioritySettings(
                        enabledChannels: [],
                        customSound: "default",
                        vibration: true
                    )
                }
                
                if enabled {
                    prioritySettings[priority]?.enabledChannels.insert(channel)
                } else {
                    prioritySettings[priority]?.enabledChannels.remove(channel)
                }
            }
        )
    }
}

/// Channel-specific configuration
/// 渠道特定配置
struct NotificationChannelSettingsView: View {
    var body: some View {
        List {
            Section("推送通知") {
                Toggle("显示预览", isOn: .constant(true))
                Toggle("声音提醒", isOn: .constant(true))
                Toggle("震动提醒", isOn: .constant(true))
            }
            
            Section("邮件通知") {
                TextField("邮件地址", text: .constant(""))
                Toggle("HTML格式", isOn: .constant(true))
                Picker("发送频率", selection: .constant("immediate")) {
                    Text("立即").tag("immediate")
                    Text("每小时汇总").tag("hourly")
                    Text("每日汇总").tag("daily")
                }
            }
            
            Section("短信通知") {
                TextField("手机号码", text: .constant(""))
                Text("仅紧急和严重警报会发送短信")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("渠道配置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Analytics Data Models (分析数据模型)

/// Analytics data structure for notifications
/// 通知的分析数据结构
struct NotificationAnalytics {
    let totalNotifications: Int
    let activeAlerts: Int
    let averageResponseTime: TimeInterval
    let deliverySuccessRate: Double
    
    init() {
        // Mock data - in a real app, this would come from the analytics service
        self.totalNotifications = 1247
        self.activeAlerts = 12
        self.averageResponseTime = 8.5 * 60 // 8.5 minutes in seconds
        self.deliverySuccessRate = 0.94
    }
}

// MARK: - Notification Extensions (通知扩展)

extension Notification.Name {
    static let quickNotificationReceived = Notification.Name("quickNotificationReceived")
}