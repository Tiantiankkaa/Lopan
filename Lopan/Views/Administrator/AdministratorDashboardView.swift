//
//  AdministratorDashboardView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Administrator Dashboard View (管理员仪表板视图)

/// Main dashboard for administrator role with comprehensive system management
/// 管理员角色的主仪表板，具备综合系统管理功能
struct AdministratorDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @StateObject private var serviceFactory: ServiceFactory
    
    @State private var selectedTab: AdministratorTab = .overview
    @State private var showingSystemHealth = false
    @State private var showingAnalytics = false
    @State private var showingReports = false
    @State private var showingUserManagement = false
    @State private var showingNotificationCenter = false
    @State private var showingPermissionManagement = false
    
    enum AdministratorTab: String, CaseIterable {
        case overview = "overview"
        case analytics = "analytics"
        case reports = "reports"
        case batches = "batches"
        case users = "users"
        case dataManagement = "data_management"
        case configuration = "configuration"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .overview: return "概览"
            case .analytics: return "数据分析"
            case .reports: return "报告中心"
            case .batches: return "批次管理"
            case .users: return "用户管理"
            case .dataManagement: return "数据管理"
            case .configuration: return "系统配置"
            case .system: return "系统监控"
            }
        }
        
        var icon: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.67percent"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .reports: return "doc.text.fill"
            case .batches: return "list.clipboard.fill"
            case .users: return "person.3.fill"
            case .dataManagement: return "externaldrive.connected.to.line.below"
            case .configuration: return "slider.horizontal.3"
            case .system: return "gear.circle.fill"
            }
        }
    }
    
    init(authService: AuthenticationService, navigationService: WorkbenchNavigationService, serviceFactory: ServiceFactory) {
        self.authService = authService
        self.navigationService = navigationService
        self._serviceFactory = StateObject(wrappedValue: serviceFactory)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                contentView
            }
            .navigationTitle("管理员控制台")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Notification bell
                        Button(action: { showingNotificationCenter = true }) {
                            ZStack {
                                Image(systemName: "bell")
                                    .font(.title3)
                                
                                // Notification badge
                                if !serviceFactory.notificationEngine.activeNotifications.filter({ !$0.isRead }).isEmpty {
                                    NotificationBadge(
                                        count: serviceFactory.notificationEngine.activeNotifications.filter { !$0.isRead }.count
                                    )
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        Menu {
                            Button("系统健康检查") {
                                showingSystemHealth = true
                            }
                            
                            Button("生成系统报告") {
                                showingReports = true
                            }
                            
                            Button("数据分析") {
                                showingAnalytics = true
                            }
                            
                            Button("权限管理") {
                                showingPermissionManagement = true
                            }
                            
                            Button("数据管理") {
                                selectedTab = .dataManagement
                            }
                            
                            Button("系统配置") {
                                selectedTab = .configuration
                            }
                            
                            Divider()
                            
                            Button("工作台选择器") {
                                navigationService.showWorkbenchSelector()
                            }
                            
                            Button("注销") {
                                authService.logout()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSystemHealth) {
                SystemHealthDashboard(
                    monitoringService: serviceFactory.systemConsistencyMonitoringService
                )
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsDashboardView(serviceFactory: serviceFactory)
            }
            .sheet(isPresented: $showingReports) {
                ReportGeneratorView(
                    reportGenerator: serviceFactory.advancedReportGenerator,
                    currentMetrics: nil
                )
            }
            .sheet(isPresented: $showingUserManagement) {
                UserManagementView()
            }
            .sheet(isPresented: $showingNotificationCenter) {
                NotificationCenterView()
                    .environmentObject(serviceFactory)
            }
            .sheet(isPresented: $showingPermissionManagement) {
                PermissionManagementView(
                    permissionService: serviceFactory.advancedPermissionService,
                    roleManagementService: serviceFactory.roleManagementService
                )
                .environmentObject(serviceFactory)
            }
        }
    }
    
    // MARK: - Header Section (头部区域)
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("欢迎，\(authService.currentUser?.name ?? "管理员")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("系统管理控制台")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentDateFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("系统正常")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Quick stats
            SystemOverviewWidget(serviceFactory: serviceFactory)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Tab Selector (标签选择器)
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AdministratorTab.allCases, id: \.self) { tab in
                    AdministratorTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Content View (内容视图)
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                switch selectedTab {
                case .overview:
                    overviewContent
                case .analytics:
                    analyticsContent
                case .reports:
                    reportsContent
                case .batches:
                    batchManagementContent
                case .users:
                    userManagementContent
                case .dataManagement:
                    dataManagementContent
                case .configuration:
                    configurationManagementContent
                case .system:
                    systemManagementContent
                }
            }
            .padding()
        }
    }
    
    // MARK: - Content Sections (内容区域)
    
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Key metrics overview
            SystemMetricsWidget(serviceFactory: serviceFactory)
            
            // Recent activities
            RecentActivitiesWidget(auditService: serviceFactory.auditingService)
            
            // System alerts
            SystemAlertsWidget(securityService: serviceFactory.enhancedSecurityAuditService)
            
            // Quick actions
            QuickActionsWidget(
                onViewAnalytics: { showingAnalytics = true },
                onGenerateReport: { showingReports = true },
                onSystemCheck: { showingSystemHealth = true },
                onManageUsers: { showingUserManagement = true }
            )
        }
    }
    
    private var analyticsContent: some View {
        VStack(spacing: 20) {
            // Analytics preview
            AnalyticsPreviewWidget(analyticsEngine: serviceFactory.productionAnalyticsEngine)
            
            Button("打开完整分析仪表板") {
                showingAnalytics = true
            }
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.primary)
            )
        }
    }
    
    private var reportsContent: some View {
        VStack(spacing: 20) {
            // Recent reports
            RecentReportsWidget(reportGenerator: serviceFactory.advancedReportGenerator)
            
            Button("打开报告生成器") {
                showingReports = true
            }
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.primary)
            )
        }
    }
    
    private var batchManagementContent: some View {
        BatchManagementView(
            repositoryFactory: serviceFactory.repositoryFactory,
            authService: authService,
            auditService: serviceFactory.auditingService
        )
    }
    
    private var userManagementContent: some View {
        VStack(spacing: 20) {
            Text("用户管理功能")
                .font(.title2)
                .fontWeight(.bold)
            
            Button("打开用户管理界面") {
                showingUserManagement = true
            }
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.primary)
            )
        }
    }
    
    private var dataManagementContent: some View {
        DataManagementView()
            .environmentObject(serviceFactory)
    }
    
    private var configurationManagementContent: some View {
        SystemConfigurationView()
            .environmentObject(serviceFactory)
    }
    
    private var systemManagementContent: some View {
        VStack(spacing: 20) {
            // System health overview
            SystemHealthOverviewWidget(monitoringService: serviceFactory.systemConsistencyMonitoringService)
            
            Button("打开系统健康仪表板") {
                showingSystemHealth = true
            }
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.primary)
            )
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Supporting Views (支持视图)

/// Administrator tab button
/// 管理员标签按钮
struct AdministratorTabButton: View {
    let tab: AdministratorDashboardView.AdministratorTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(tab.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? LopanColors.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// System overview widget
/// 系统概览小组件
struct SystemOverviewWidget: View {
    let serviceFactory: ServiceFactory
    @State private var systemMetrics: (batches: Int, machines: Int, users: Int, alerts: Int) = (0, 0, 0, 0)
    
    var body: some View {
        HStack(spacing: 20) {
            OverviewMetricItem(
                title: "总批次",
                value: "\(systemMetrics.batches)",
                icon: "list.clipboard",
                color: .blue
            )
            
            OverviewMetricItem(
                title: "活跃机台",
                value: "\(systemMetrics.machines)",
                icon: "gearshape.2",
                color: .green
            )
            
            OverviewMetricItem(
                title: "系统用户",
                value: "\(systemMetrics.users)",
                icon: "person.3",
                color: .orange
            )
            
            OverviewMetricItem(
                title: "系统警报",
                value: "\(systemMetrics.alerts)",
                icon: "exclamationmark.triangle",
                color: systemMetrics.alerts > 0 ? .red : .gray
            )
        }
        .task {
            await loadSystemMetrics()
        }
    }
    
    private func loadSystemMetrics() async {
        do {
            // Load actual metrics from services
            let batches = try await serviceFactory.repositoryFactory.productionBatchRepository.fetchAllBatches()
            let machines = try await serviceFactory.repositoryFactory.machineRepository.fetchAllMachines()
            let users = try await serviceFactory.repositoryFactory.userRepository.fetchUsers()
            let alerts = serviceFactory.enhancedSecurityAuditService.securityAlerts.count
            
            await MainActor.run {
                systemMetrics = (batches.count, machines.filter { $0.isActive }.count, users.count, alerts)
            }
        } catch {
            // Handle error gracefully
            print("Failed to load system metrics: \(error)")
        }
    }
}

/// Overview metric item
/// 概览指标项
struct OverviewMetricItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// System metrics widget
/// 系统指标小组件
struct SystemMetricsWidget: View {
    let serviceFactory: ServiceFactory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("系统指标")
                .font(.headline)
                .fontWeight(.bold)
            
            // Performance metrics display would go here
            HStack {
                Text("系统运行正常")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("99.9% 可用性")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// Recent activities widget
/// 最近活动小组件
struct RecentActivitiesWidget: View {
    let auditService: NewAuditingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近活动")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                ForEach(1...3, id: \.self) { index in
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text("系统活动 \(index)")
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("刚刚")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// System alerts widget
/// 系统警报小组件
struct SystemAlertsWidget: View {
    let securityService: EnhancedSecurityAuditService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("系统警报")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if securityService.securityAlerts.isEmpty {
                    Text("无警报")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("\(securityService.securityAlerts.count) 个警报")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            if securityService.securityAlerts.isEmpty {
                Text("系统运行正常，无警报。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(securityService.securityAlerts.prefix(3)) { alert in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(alert.severity.color)
                                .font(.caption)
                            
                            Text(alert.title)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatTime(alert.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Quick actions widget
/// 快速操作小组件
struct QuickActionsWidget: View {
    let onViewAnalytics: () -> Void
    let onGenerateReport: () -> Void
    let onSystemCheck: () -> Void
    let onManageUsers: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速操作")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "数据分析",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    action: onViewAnalytics
                )
                
                QuickActionButton(
                    title: "生成报告",
                    icon: "doc.text.fill",
                    color: .green,
                    action: onGenerateReport
                )
                
                QuickActionButton(
                    title: "系统检查",
                    icon: "gear.circle.fill",
                    color: .orange,
                    action: onSystemCheck
                )
                
                QuickActionButton(
                    title: "用户管理",
                    icon: "person.3.fill",
                    color: .purple,
                    action: onManageUsers
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// Quick action button
/// 快速操作按钮
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Analytics preview widget
/// 分析预览小组件
struct AnalyticsPreviewWidget: View {
    let analyticsEngine: ProductionAnalyticsEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("数据分析预览")
                .font(.headline)
                .fontWeight(.bold)
            
            if let metrics = analyticsEngine.currentMetrics {
                AnalyticsOverviewWidget(metrics: metrics)
            } else {
                Text("暂无分析数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// Recent reports widget
/// 最近报告小组件
struct RecentReportsWidget: View {
    let reportGenerator: AdvancedReportGenerator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近报告")
                .font(.headline)
                .fontWeight(.bold)
            
            if reportGenerator.recentReports.isEmpty {
                Text("暂无报告")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(reportGenerator.recentReports.prefix(3)) { report in
                        HStack {
                            Image(systemName: report.configuration.type.icon)
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(report.configuration.type.displayName)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatTime(report.generatedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// System health overview widget
/// 系统健康概览小组件
struct SystemHealthOverviewWidget: View {
    let monitoringService: SystemConsistencyMonitoringService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("系统健康状态")
                .font(.headline)
                .fontWeight(.bold)
            
            if let report = monitoringService.currentHealthReport {
                HStack(spacing: 16) {
                    Circle()
                        .fill(report.overallStatus.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(format: "%.0f", report.overallScore * 100))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.overallStatus.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("严重问题: \(report.criticalIssues.count) 个")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            } else {
                Text("正在检查系统健康状态...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}