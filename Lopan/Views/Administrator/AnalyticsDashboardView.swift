//
//  AnalyticsDashboardView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Analytics Dashboard View (分析仪表板视图)

/// Comprehensive analytics dashboard for production management
/// 生产管理的综合分析仪表板
struct AnalyticsDashboardView: View {
    @StateObject private var analyticsEngine: ProductionAnalyticsEngine
    @StateObject private var reportGenerator: AdvancedReportGenerator
    @StateObject private var securityAuditService: EnhancedSecurityAuditService
    @State private var selectedTimePeriod: AnalyticsTimePeriod = .thisMonth
    @State private var currentMetrics: ProductionMetrics?
    @State private var comparisonMetrics: AnalyticsComparison?
    @State private var isLoadingData = false
    @State private var showingReportGenerator = false
    @State private var showingDetailView = false
    @State private var selectedDetailType: DetailViewType?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum DetailViewType: String, CaseIterable {
        case production = "production"
        case machines = "machines"
        case quality = "quality"
        case shifts = "shifts"
        case trends = "trends"
        
        var titleKey: LocalizedStringKey {
            switch self {
            case .production: return "admin_analytics_detail_production"
            case .machines: return "admin_analytics_detail_machines"
            case .quality: return "admin_analytics_detail_quality"
            case .shifts: return "admin_analytics_detail_shifts"
            case .trends: return "admin_analytics_detail_trends"
            }
        }
        
        var icon: String {
            switch self {
            case .production: return "chart.bar.doc.horizontal"
            case .machines: return "gearshape.2.fill"
            case .quality: return "checkmark.seal.fill"
            case .shifts: return "clock.arrow.2.circlepath"
            case .trends: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    private func localizedTimePeriodTitle(_ period: AnalyticsTimePeriod) -> LocalizedStringKey {
        switch period {
        case .today: return "admin_analytics_period_today"
        case .yesterday: return "admin_analytics_period_yesterday"
        case .thisWeek: return "admin_analytics_period_this_week"
        case .lastWeek: return "admin_analytics_period_last_week"
        case .thisMonth: return "admin_analytics_period_this_month"
        case .lastMonth: return "admin_analytics_period_last_month"
        case .thisQuarter: return "admin_analytics_period_this_quarter"
        case .lastQuarter: return "admin_analytics_period_last_quarter"
        case .thisYear: return "admin_analytics_period_this_year"
        case .custom: return "admin_analytics_period_custom"
        }
    }

    private func localizedTrendTitle(_ trend: AnalyticsTrend) -> LocalizedStringKey {
        switch trend {
        case .improving: return "admin_analytics_trend_improving"
        case .declining: return "admin_analytics_trend_declining"
        case .stable: return "admin_analytics_trend_stable"
        }
    }

    private func localizedBinaryState(_ isEnabled: Bool) -> String {
        isEnabled ? "admin_analytics_status_enabled".localized : "admin_analytics_status_disabled".localized
    }

    private func localizedRiskSeverity(_ severity: SecurityEventSeverity) -> String {
        switch severity {
        case .info: return "admin_analytics_risk_info".localized
        case .warning: return "admin_analytics_risk_warning".localized
        case .error: return "admin_analytics_risk_error".localized
        case .critical: return "admin_analytics_risk_critical".localized
        case .fatal: return "admin_analytics_risk_fatal".localized
        }
    }

    init(serviceFactory: ServiceFactory) {
        let analyticsEngine = ProductionAnalyticsEngine(
            machineRepository: serviceFactory.repositoryFactory.machineRepository,
            productionBatchRepository: serviceFactory.repositoryFactory.productionBatchRepository,
            auditService: serviceFactory.auditingService,
            authService: serviceFactory.authenticationService
        )
        
        let securityAuditService = EnhancedSecurityAuditService(
            baseAuditService: serviceFactory.auditingService,
            authService: serviceFactory.authenticationService
        )
        
        let reportGenerator = AdvancedReportGenerator(
            analyticsEngine: analyticsEngine,
            auditService: securityAuditService,
            authService: serviceFactory.authenticationService
        )
        
        self._analyticsEngine = StateObject(wrappedValue: analyticsEngine)
        self._reportGenerator = StateObject(wrappedValue: reportGenerator)
        self._securityAuditService = StateObject(wrappedValue: securityAuditService)
    }
    
    var body: some View {
        ScrollView {
                VStack(spacing: LopanSpacing.contentSpacing) {
                    headerSection

                    if let metrics = currentMetrics {
                        AnalyticsOverviewWidget(metrics: metrics)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(Text("admin_analytics_overview_accessibility_label"))
                    }

                    if let metrics = currentMetrics {
                        ProductionMetricsChart(metrics: metrics)
                            .accessibilityLabel(Text("admin_analytics_chart_accessibility_label"))
                            .accessibilityHint(Text("admin_analytics_chart_accessibility_hint"))
                    }

                    if let comparison = comparisonMetrics {
                        comparisonSection(comparison: comparison)
                    }

                    quickActionsSection

                    recentReportsSection

                    systemHealthSection
                }
                .padding(.horizontal, LopanSpacing.screenPadding)
                .padding(.vertical, LopanSpacing.lg)
            }
            .scrollIndicators(.hidden)
            .background(LopanColors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(navigationTitleKey)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("admin_analytics_menu_generate_report".localized) {
                            showingReportGenerator = true
                        }

                        Button("admin_analytics_menu_refresh".localized) {
                            Task {
                                await refreshAnalytics()
                            }
                        }

                        Button("admin_analytics_menu_export".localized) {
                            Task {
                                await exportAnalyticsData()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button("admin_analytics_toolbar_detail".localized) {
                        showingDetailView = true
                    }
                }
            }
            .refreshable {
                await refreshAnalytics()
            }
            .sheet(isPresented: $showingReportGenerator) {
                ReportGeneratorView(
                    reportGenerator: reportGenerator,
                    currentMetrics: currentMetrics
                )
            }
            .sheet(isPresented: $showingDetailView) {
                AnalyticsDetailNavigationView(
                    analyticsEngine: analyticsEngine,
                    currentMetrics: currentMetrics
                )
            }
            .alert(navigationErrorTitleKey, isPresented: $showingErrorAlert) {
                Button(navigationErrorDismissKey) {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await initializeAnalytics()
            }
    }
    
    private var navigationTitleKey: LocalizedStringKey { "admin_analytics_navigation_title" }
    private var navigationErrorTitleKey: LocalizedStringKey { "admin_analytics_error_title" }
    private var navigationErrorDismissKey: LocalizedStringKey { "admin_analytics_error_dismiss" }
    
    // MARK: - Header Section (头部区域)
    
    private var headerSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.md) {
                HStack(alignment: .center, spacing: LopanSpacing.sm) {
                    VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                        Text("admin_analytics_header_title")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(LopanColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        Text(localizedTimePeriodTitle(selectedTimePeriod))
                            .font(.subheadline)
                            .foregroundColor(LopanColors.textSecondary)
                    }

                    Spacer()

                    if isLoadingData {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .accessibilityLabel(Text("admin_analytics_loading_label"))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LopanSpacing.sm) {
                        ForEach(AnalyticsTimePeriod.allCases.filter { $0 != .custom }, id: \.self) { period in
                            TimePeriodButton(
                                titleKey: localizedTimePeriodTitle(period),
                                isSelected: selectedTimePeriod == period,
                                action: {
                                    selectedTimePeriod = period
                                    Task {
                                        await refreshAnalytics()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, LopanSpacing.xxxs)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("admin_analytics_time_range_accessibility_label"))
                .accessibilityHint(Text("admin_analytics_time_range_accessibility_hint"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("admin_analytics_header_accessibility_label"))
        .accessibilityHint(Text("admin_analytics_header_accessibility_hint"))
    }
    
    // MARK: - Comparison Section (对比区域)
    
    private func comparisonSection(comparison: AnalyticsComparison) -> some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                HStack(spacing: LopanSpacing.sm) {
                    Text("admin_analytics_comparison_title")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    HStack(spacing: LopanSpacing.xxxs) {
                        Image(systemName: comparison.overallTrend.icon)
                            .foregroundColor(comparison.overallTrend.color)
                        Text(localizedTrendTitle(comparison.overallTrend))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(comparison.overallTrend.color)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("admin_analytics_comparison_trend_accessibility_label"))
                    .accessibilityValue(Text(localizedTrendTitle(comparison.overallTrend)))
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LopanSpacing.gridSpacing), count: 2), spacing: LopanSpacing.gridSpacing) {
                    ComparisonMetricCard(
                        titleKey: "admin_analytics_metric_batch_completion",
                        currentValue: comparison.currentPeriod.batchCompletionRate,
                        previousValue: comparison.comparisonPeriod.batchCompletionRate,
                        format: .percentage,
                        reduceMotion: reduceMotion
                    )

                    ComparisonMetricCard(
                        titleKey: "admin_analytics_metric_machine_utilization",
                        currentValue: comparison.currentPeriod.machineUtilizationRate,
                        previousValue: comparison.comparisonPeriod.machineUtilizationRate,
                        format: .percentage,
                        reduceMotion: reduceMotion
                    )

                    ComparisonMetricCard(
                        titleKey: "admin_analytics_metric_productivity",
                        currentValue: comparison.currentPeriod.productivityIndex,
                        previousValue: comparison.comparisonPeriod.productivityIndex,
                        format: .percentage,
                        reduceMotion: reduceMotion
                    )

                    ComparisonMetricCard(
                        titleKey: "admin_analytics_metric_quality_score",
                        currentValue: comparison.currentPeriod.qualityScore,
                        previousValue: comparison.comparisonPeriod.qualityScore,
                        format: .score,
                        reduceMotion: reduceMotion
                    )
                }

                if !comparison.improvements.isEmpty || !comparison.concerns.isEmpty {
                    insightsSection(comparison: comparison)
                }
            }
        }
    }
    
    private func insightsSection(comparison: AnalyticsComparison) -> some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            Text("admin_analytics_insights_title")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textPrimary)

            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                if !comparison.improvements.isEmpty {
                    ForEach(comparison.improvements.prefix(2), id: \.self) { improvement in
                        InsightRow(
                            icon: "arrow.up.circle.fill",
                            color: LopanColors.success,
                            text: improvement
                        )
                    }
                }

                if !comparison.concerns.isEmpty {
                    ForEach(comparison.concerns.prefix(2), id: \.self) { concern in
                        InsightRow(
                            icon: "exclamationmark.triangle.fill",
                            color: LopanColors.warning,
                            text: concern
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section (快速操作区域)
    
    private var quickActionsSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("admin_analytics_quick_actions_title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(LopanColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LopanSpacing.gridSpacing), count: 2), spacing: LopanSpacing.gridSpacing) {
                    ForEach(DetailViewType.allCases, id: \.self) { detailType in
                        QuickActionCard(
                            titleKey: detailType.titleKey,
                            icon: detailType.icon,
                            action: {
                                selectedDetailType = detailType
                                showingDetailView = true
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Reports Section (最近报告区域)
    
    private var recentReportsSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                HStack {
                    Text("admin_analytics_recent_reports_title")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Button("admin_analytics_recent_reports_view_all".localized) {
                        showingReportGenerator = true
                    }
                    .font(.caption)
                    .foregroundColor(LopanColors.info)
                    .accessibilityHint(Text("admin_analytics_recent_reports_view_all_hint"))
                }

                if reportGenerator.recentReports.isEmpty {
                    Text("admin_analytics_recent_reports_empty")
                        .font(.footnote)
                        .foregroundColor(LopanColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                                .fill(LopanColors.backgroundSecondary)
                        )
                        .accessibilityLabel(Text("admin_analytics_recent_reports_empty"))
                } else {
                    VStack(spacing: LopanSpacing.xs) {
                        ForEach(reportGenerator.recentReports.prefix(3)) { report in
                            RecentReportRow(report: report)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - System Health Section (系统健康区域)
    
    private var systemHealthSection: some View {
        let analytics = securityAuditService.getSecurityAnalytics()

        return AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("admin_analytics_system_health_title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(LopanColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LopanSpacing.gridSpacing), count: 2), spacing: LopanSpacing.gridSpacing) {
                    SystemHealthCard(
                        titleKey: "admin_analytics_system_health_events_today",
                        value: analytics.totalEvents24h.formatted(),
                        icon: "doc.text.fill",
                        color: LopanColors.info
                    )

                    SystemHealthCard(
                        titleKey: "admin_analytics_system_health_critical_alerts",
                        value: analytics.criticalEvents24h.formatted(),
                        icon: "exclamationmark.triangle.fill",
                        color: analytics.criticalEvents24h > 0 ? LopanColors.error : LopanColors.success
                    )

                    SystemHealthCard(
                        titleKey: "admin_analytics_system_health_threat_detection",
                        value: localizedBinaryState(analytics.threatDetectionEnabled),
                        icon: "shield.fill",
                        color: analytics.threatDetectionEnabled ? LopanColors.success : LopanColors.warning
                    )

                    SystemHealthCard(
                        titleKey: "admin_analytics_system_health_risk_level",
                        value: localizedRiskSeverity(analytics.riskLevel),
                        icon: "gauge.with.dots.needle.67percent",
                        color: analytics.riskLevel.color
                    )
                }
            }
        }
    }
    
    // MARK: - Data Operations (数据操作)
    
    private func initializeAnalytics() async {
        isLoadingData = true
        
        do {
            // Start real-time analytics
            analyticsEngine.startRealtimeAnalytics()
            
            // Load initial data
            await refreshAnalytics()
            
        } catch {
            errorMessage = String(format: "admin_analytics_error_initialize_failed".localized, error.localizedDescription)
            showingErrorAlert = true
        }
        
        isLoadingData = false
    }
    
    private func refreshAnalytics() async {
        isLoadingData = true
        
        do {
            // Calculate current metrics
            let metrics = await analyticsEngine.calculateMetrics(for: selectedTimePeriod)
            
            await MainActor.run {
                currentMetrics = metrics
            }
            
            // Calculate comparison if possible
            if let comparisonPeriod = getComparisonPeriod(for: selectedTimePeriod) {
                let comparison = await analyticsEngine.compareMetrics(
                    current: selectedTimePeriod,
                    comparison: comparisonPeriod
                )
                
                await MainActor.run {
                    comparisonMetrics = comparison
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = String(format: "admin_analytics_error_refresh_failed".localized, error.localizedDescription)
                showingErrorAlert = true
            }
        }
        
        await MainActor.run {
            isLoadingData = false
        }
    }
    
    private func exportAnalyticsData() async {
        guard let metrics = currentMetrics else { return }
        
        do {
            let configuration = ReportConfiguration(
                type: .detailedAnalytics,
                format: .json,
                timePeriod: selectedTimePeriod,
                includeCharts: false,
                includeTrendData: true,
                includeComparisons: comparisonMetrics != nil
            )
            
            let report = try await reportGenerator.generateReport(configuration: configuration)
            let savedURL = try await reportGenerator.saveReportToStorage(report)
            
            // Show success message or share sheet
            print("Analytics data exported to: \(savedURL)")
            
        } catch {
            errorMessage = String(format: "admin_analytics_error_export_failed".localized, error.localizedDescription)
            showingErrorAlert = true
        }
    }
    
    private func getComparisonPeriod(for period: AnalyticsTimePeriod) -> AnalyticsTimePeriod? {
        switch period {
        case .today: return .yesterday
        case .thisWeek: return .lastWeek
        case .thisMonth: return .lastMonth
        case .thisQuarter: return .lastQuarter
        default: return nil
        }
    }
}

// MARK: - Supporting Views (支持视图)

/// Time period selection button
/// 时间段选择按钮
struct TimePeriodButton: View {
    let titleKey: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, LopanSpacing.sm)
                .padding(.vertical, LopanSpacing.xs)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? LopanColors.info : LopanColors.backgroundSecondary)
                )
                .foregroundColor(isSelected ? LopanColors.textOnPrimary : LopanColors.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(Text(isSelected ? "admin_common_selected".localized : "admin_common_not_selected".localized))
    }
}

/// Comparison metric card
/// 对比指标卡片
struct ComparisonMetricCard: View {
    let titleKey: LocalizedStringKey
    let currentValue: Double
    let previousValue: Double
    let format: MetricFormat
    let reduceMotion: Bool

    enum MetricFormat {
        case percentage
        case score
        case count
    }

    private var formattedCurrentValue: String {
        switch format {
        case .percentage:
            return currentValue.formatted(.percent.precision(.fractionLength(1)))
        case .score:
            return currentValue.formatted(.number.precision(.fractionLength(2)))
        case .count:
            return currentValue.formatted(.number.precision(.fractionLength(0)))
        }
    }

    private var changeRatio: Double? {
        guard previousValue != 0 else { return nil }
        return (currentValue - previousValue) / abs(previousValue)
    }

    private var changeSymbol: String {
        guard let changeRatio else { return "minus" }
        if changeRatio > 0 { return "arrow.up" }
        if changeRatio < 0 { return "arrow.down" }
        return "minus"
    }

    private var changeColor: Color {
        guard let changeRatio else { return LopanColors.textSecondary }
        if changeRatio > 0.05 { return LopanColors.success }
        if changeRatio < -0.05 { return LopanColors.error }
        return LopanColors.textSecondary
    }

    private var changePercentText: String {
        guard let changeRatio else { return "--" }
        return changeRatio.formatted(.percent.precision(.fractionLength(1)))
    }

    private var changeAccessibilityDescription: String {
        guard let changeRatio else { return "admin_analytics_metric_change_no_data".localized }
        return String(format: "admin_analytics_metric_change_value".localized, changePercentText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            Text(titleKey)
                .font(.footnote)
                .foregroundColor(LopanColors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            valueView

            HStack(spacing: LopanSpacing.xxxs) {
                Image(systemName: changeSymbol)
                    .font(.caption2)
                    .foregroundColor(changeColor)

                Text(changePercentText)
                    .font(.caption2)
                    .foregroundColor(changeColor)
            }
            .accessibilityLabel(Text(changeAccessibilityDescription))
        }
        .padding(LopanSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                .fill(LopanColors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                .stroke(LopanColors.border.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(Text(formattedCurrentValue))
        .accessibilityHint(Text(changeAccessibilityDescription))
    }

    @ViewBuilder
    private var valueView: some View {
        if #available(iOS 17.0, *) {
            Text(formattedCurrentValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.textPrimary)
                .contentTransition(.numericText(value: currentValue))
                .transaction { transaction in
                    transaction.animation = reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                }
        } else {
            Text(formattedCurrentValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.textPrimary)
        }
    }
}

/// Insight row
/// 洞察行
struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: LopanSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(text)
                .font(.caption)
                .foregroundColor(LopanColors.textPrimary)
                .lineLimit(2)

            Spacer()
        }
    }
}

/// Quick action card
/// 快速操作卡片
struct QuickActionCard: View {
    let titleKey: LocalizedStringKey
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: LopanSpacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(LopanColors.info)
                
                Text(titleKey)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                    .fill(LopanColors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
    }
}

/// Recent report row
/// 最近报告行
struct RecentReportRow: View {
    let report: GeneratedReport
    
    var body: some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: report.configuration.type.icon)
                .font(.title3)
                .foregroundColor(LopanColors.info)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(report.configuration.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(formatDate(report.generatedAt))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textSecondary)
            }
            
            Spacer()
            
            Text(report.fileSizeFormatted)
                .font(.caption2)
                .foregroundColor(LopanColors.textSecondary)
            
            Button("admin_analytics_recent_reports_view".localized) {
                // Handle report viewing
            }
            .font(.caption)
            .foregroundColor(LopanColors.info)
        }
        .padding(.vertical, LopanSpacing.xxxs)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// System health card
/// 系统健康卡片
struct SystemHealthCard: View {
    let titleKey: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: LopanSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: LopanSpacing.xxxs) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(titleKey)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LopanSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                .fill(LopanColors.backgroundSecondary)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(Text(value))
    }
}

// MARK: - Analytics Detail Navigation View (分析详情导航视图)

/// Navigation view for detailed analytics
/// 详细分析的导航视图
struct AnalyticsDetailNavigationView: View {
    let analyticsEngine: ProductionAnalyticsEngine
    let currentMetrics: ProductionMetrics?
    
    var body: some View {
        NavigationStack {
            List {
                if let metrics = currentMetrics {
                    Section("admin_analytics_detail_section_title") {
                        NavigationLink("admin_analytics_detail_link_production".localized) {
                            ProductionPerformanceDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("admin_analytics_detail_link_machines".localized) {
                            MachineEfficiencyDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("admin_analytics_detail_link_quality".localized) {
                            QualityMetricsDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("admin_analytics_detail_link_shifts".localized) {
                            ShiftComparisonDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("admin_analytics_detail_link_trends".localized) {
                            TrendPredictionDetailView(metrics: metrics)
                        }
                    }
                    
                    Section("admin_analytics_detail_export_section") {
                        Button("admin_analytics_detail_export_excel".localized) {
                            // Handle Excel export
                        }
                        
                        Button("admin_analytics_detail_export_pdf".localized) {
                            // Handle PDF export
                        }
                        
                        Button("admin_analytics_detail_export_csv".localized) {
                            // Handle CSV export
                        }
                    }
                }
            }
            .navigationTitle("admin_analytics_detail_navigation_title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Placeholder Detail Views (占位详情视图)

struct ProductionPerformanceDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.contentSpacing) {
                Text("admin_analytics_detail_production_heading")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if !metrics.trendData.isEmpty {
                    ProductionMetricsChart(metrics: metrics)
                }
                
                // Additional detailed analysis components would go here
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .navigationTitle("admin_analytics_detail_production_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MachineEfficiencyDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.contentSpacing) {
                Text("admin_analytics_detail_machines_heading")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Machine efficiency specific analysis would go here
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .navigationTitle("admin_analytics_detail_machines_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QualityMetricsDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.contentSpacing) {
                Text("admin_analytics_detail_quality_heading")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Quality metrics specific analysis would go here
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .navigationTitle("admin_analytics_detail_quality_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShiftComparisonDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.contentSpacing) {
                Text("admin_analytics_detail_shifts_heading")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Shift comparison specific analysis would go here
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .navigationTitle("admin_analytics_detail_shifts_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrendPredictionDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.contentSpacing) {
                Text("admin_analytics_detail_trends_heading")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Trend prediction specific analysis would go here
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .navigationTitle("admin_analytics_detail_trends_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
