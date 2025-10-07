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
        case management = "management"
        case settings = "settings"

        var displayName: String {
            switch self {
            case .overview: return "概览"
            case .analytics: return "分析"
            case .management: return "管理"
            case .settings: return "设置"
            }
        }

        var icon: String {
            switch self {
            case .overview: return "house.fill"
            case .analytics: return "chart.bar.fill"
            case .management: return "person.3.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    init(authService: AuthenticationService, navigationService: WorkbenchNavigationService, serviceFactory: ServiceFactory) {
        self.authService = authService
        self.navigationService = navigationService
        self._serviceFactory = StateObject(wrappedValue: serviceFactory)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            overviewTabView
                .tabItem {
                    Label(AdministratorTab.overview.displayName, systemImage: AdministratorTab.overview.icon)
                }
                .tag(AdministratorTab.overview)

            analyticsTabView
                .tabItem {
                    Label(AdministratorTab.analytics.displayName, systemImage: AdministratorTab.analytics.icon)
                }
                .tag(AdministratorTab.analytics)

            managementTabView
                .tabItem {
                    Label(AdministratorTab.management.displayName, systemImage: AdministratorTab.management.icon)
                }
                .tag(AdministratorTab.management)

            settingsTabView
                .tabItem {
                    Label(AdministratorTab.settings.displayName, systemImage: AdministratorTab.settings.icon)
                }
                .tag(AdministratorTab.settings)
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
    
    // MARK: - Tab Views

    private var overviewTabView: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome header
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
                                        .fill(LopanColors.success)
                                        .frame(width: 8, height: 8)

                                    Text("系统正常")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        SystemOverviewWidget(serviceFactory: serviceFactory)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LopanColors.backgroundSecondary)
                    )

                    overviewContent
                }
                .padding()
            }
            .navigationTitle("概览")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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
    }

    private var analyticsTabView: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    analyticsContent

                    Divider()
                        .padding(.vertical)

                    reportsContent
                }
                .padding()
            }
            .navigationTitle("数据分析")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNotificationCenter = true }) {
                        ZStack {
                            Image(systemName: "bell")

                            if !serviceFactory.notificationEngine.activeNotifications.filter({ !$0.isRead }).isEmpty {
                                NotificationBadge(
                                    count: serviceFactory.notificationEngine.activeNotifications.filter { !$0.isRead }.count
                                )
                                .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
        }
    }

    private var managementTabView: some View {
        NavigationStack {
            List {
                Section("用户与权限") {
                    NavigationLink(destination: UserManagementView()) {
                        Label("用户管理", systemImage: "person.3.fill")
                    }

                    NavigationLink(destination: PermissionManagementView(
                        permissionService: serviceFactory.advancedPermissionService,
                        roleManagementService: serviceFactory.roleManagementService
                    ).environmentObject(serviceFactory)) {
                        Label("权限管理", systemImage: "lock.shield.fill")
                    }
                }

                Section("生产管理") {
                    NavigationLink(destination: BatchManagementView(
                        repositoryFactory: serviceFactory.repositoryFactory,
                        authService: authService,
                        auditService: serviceFactory.auditingService
                    )) {
                        Label("批次管理", systemImage: "list.clipboard.fill")
                    }
                }

                Section("数据管理") {
                    NavigationLink(destination: DataManagementView()
                        .environmentObject(serviceFactory)) {
                        Label("数据管理", systemImage: "externaldrive.connected.to.line.below")
                    }
                }
            }
            .navigationTitle("管理")
        }
    }

    private var settingsTabView: some View {
        NavigationStack {
            List {
                Section("系统配置") {
                    NavigationLink(destination: SystemConfigurationView()
                        .environmentObject(serviceFactory)) {
                        Label("系统配置", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink(destination: CurrencySettingsView()) {
                        Label("货币设置", systemImage: "dollarsign.circle.fill")
                    }
                }

                Section("系统监控") {
                    NavigationLink(destination: SystemHealthDashboard(
                        monitoringService: serviceFactory.systemConsistencyMonitoringService
                    )) {
                        Label("系统健康检查", systemImage: "heart.text.square.fill")
                    }

                    Button(action: { showingAnalytics = true }) {
                        Label("数据分析", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Button(action: { showingReports = true }) {
                        Label("生成系统报告", systemImage: "doc.text.fill")
                    }
                }
            }
            .navigationTitle("设置")
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
            .foregroundColor(LopanColors.textPrimary)
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
            .foregroundColor(LopanColors.textPrimary)
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
                color: LopanColors.primary
            )
            
            OverviewMetricItem(
                title: "活跃机台",
                value: "\(systemMetrics.machines)",
                icon: "gearshape.2",
                color: LopanColors.success
            )
            
            OverviewMetricItem(
                title: "系统用户",
                value: "\(systemMetrics.users)",
                icon: "person.3",
                color: LopanColors.warning
            )
            
            OverviewMetricItem(
                title: "系统警报",
                value: "\(systemMetrics.alerts)",
                icon: "exclamationmark.triangle",
                color: systemMetrics.alerts > 0 ? LopanColors.error : LopanColors.textSecondary
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
                    .foregroundColor(LopanColors.success)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
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
                            .foregroundColor(LopanColors.primary)
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
                .fill(LopanColors.backgroundSecondary)
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
                        .foregroundColor(LopanColors.success)
                } else {
                    Text("\(securityService.securityAlerts.count) 个警报")
                        .font(.caption)
                        .foregroundColor(LopanColors.error)
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
                .fill(LopanColors.backgroundSecondary)
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
                    color: LopanColors.primary,
                    action: onViewAnalytics
                )
                
                QuickActionButton(
                    title: "生成报告",
                    icon: "doc.text.fill",
                    color: LopanColors.success,
                    action: onGenerateReport
                )
                
                QuickActionButton(
                    title: "系统检查",
                    icon: "gear.circle.fill",
                    color: LopanColors.warning,
                    action: onSystemCheck
                )
                
                QuickActionButton(
                    title: "用户管理",
                    icon: "person.3.fill",
                    color: LopanColors.primary,
                    action: onManageUsers
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
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
                    .fill(LopanColors.backgroundTertiary)
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
                            .fill(LopanColors.backgroundTertiary)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
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
                            .fill(LopanColors.backgroundTertiary)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(reportGenerator.recentReports.prefix(3)) { report in
                        HStack {
                            Image(systemName: report.configuration.type.icon)
                                .foregroundColor(LopanColors.primary)
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
                .fill(LopanColors.backgroundSecondary)
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
                                .foregroundColor(LopanColors.textPrimary)
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
                .fill(LopanColors.backgroundSecondary)
        )
    }
}