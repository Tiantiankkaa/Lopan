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
    
    enum DetailViewType: String, CaseIterable {
        case production = "production"
        case machines = "machines"
        case quality = "quality"
        case shifts = "shifts"
        case trends = "trends"
        
        var displayName: String {
            switch self {
            case .production: return "生产详情"
            case .machines: return "机台分析"
            case .quality: return "质量分析"
            case .shifts: return "班次对比"
            case .trends: return "趋势分析"
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
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header section with time period selector
                    headerSection
                    
                    // Key metrics overview
                    if let metrics = currentMetrics {
                        AnalyticsOverviewWidget(metrics: metrics)
                    }
                    
                    // Main analytics charts
                    if let metrics = currentMetrics {
                        ProductionMetricsChart(metrics: metrics)
                    }
                    
                    // Comparison section
                    if let comparison = comparisonMetrics {
                        comparisonSection(comparison: comparison)
                    }
                    
                    // Quick actions
                    quickActionsSection
                    
                    // Recent reports
                    recentReportsSection
                    
                    // System health integration
                    systemHealthSection
                }
                .padding()
            }
            .navigationTitle("数据分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("生成报告") {
                            showingReportGenerator = true
                        }
                        
                        Button("刷新数据") {
                            Task {
                                await refreshAnalytics()
                            }
                        }
                        
                        Button("导出数据") {
                            Task {
                                await exportAnalyticsData()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("详细视图") {
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
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定") {
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
    }
    
    // MARK: - Header Section (头部区域)
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("分析仪表板")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoadingData {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Time period selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsTimePeriod.allCases.filter { $0 != .custom }, id: \.self) { period in
                        TimePeriodButton(
                            period: period,
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
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Comparison Section (对比区域)
    
    private func comparisonSection(comparison: AnalyticsComparison) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("对比分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: comparison.overallTrend.icon)
                        .foregroundColor(comparison.overallTrend.color)
                    
                    Text(comparison.overallTrend.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(comparison.overallTrend.color)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ComparisonMetricCard(
                    title: "批次完成率",
                    currentValue: comparison.currentPeriod.batchCompletionRate,
                    previousValue: comparison.comparisonPeriod.batchCompletionRate,
                    format: .percentage
                )
                
                ComparisonMetricCard(
                    title: "机台利用率",
                    currentValue: comparison.currentPeriod.machineUtilizationRate,
                    previousValue: comparison.comparisonPeriod.machineUtilizationRate,
                    format: .percentage
                )
                
                ComparisonMetricCard(
                    title: "生产效率",
                    currentValue: comparison.currentPeriod.productivityIndex,
                    previousValue: comparison.comparisonPeriod.productivityIndex,
                    format: .percentage
                )
                
                ComparisonMetricCard(
                    title: "质量评分",
                    currentValue: comparison.currentPeriod.qualityScore,
                    previousValue: comparison.comparisonPeriod.qualityScore,
                    format: .score
                )
            }
            
            // Insights
            if !comparison.improvements.isEmpty || !comparison.concerns.isEmpty {
                insightsSection(comparison: comparison)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func insightsSection(comparison: AnalyticsComparison) -> VStack<TupleView<(some View, some View)>> {
        VStack(alignment: .leading, spacing: 12) {
            Text("洞察建议")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                if !comparison.improvements.isEmpty {
                    ForEach(comparison.improvements.prefix(2), id: \.self) { improvement in
                        InsightRow(
                            icon: "arrow.up.circle.fill",
                            color: .green,
                            text: improvement
                        )
                    }
                }
                
                if !comparison.concerns.isEmpty {
                    ForEach(comparison.concerns.prefix(2), id: \.self) { concern in
                        InsightRow(
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            text: concern
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section (快速操作区域)
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速操作")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DetailViewType.allCases, id: \.self) { detailType in
                    QuickActionCard(
                        title: detailType.displayName,
                        icon: detailType.icon,
                        action: {
                            selectedDetailType = detailType
                            showingDetailView = true
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Recent Reports Section (最近报告区域)
    
    private var recentReportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近报告")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("查看全部") {
                    showingReportGenerator = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if reportGenerator.recentReports.isEmpty {
                Text("暂无报告")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(reportGenerator.recentReports.prefix(3)) { report in
                        RecentReportRow(report: report)
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
    
    // MARK: - System Health Section (系统健康区域)
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("系统状态")
                .font(.headline)
                .foregroundColor(.primary)
            
            let analytics = securityAuditService.getSecurityAnalytics()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                SystemHealthCard(
                    title: "今日事件",
                    value: "\(analytics.totalEvents24h)",
                    icon: "doc.text.fill",
                    color: .blue
                )
                
                SystemHealthCard(
                    title: "严重警报",
                    value: "\(analytics.criticalEvents24h)",
                    icon: "exclamationmark.triangle.fill",
                    color: analytics.criticalEvents24h > 0 ? .red : .green
                )
                
                SystemHealthCard(
                    title: "威胁检测",
                    value: analytics.threatDetectionEnabled ? "启用" : "禁用",
                    icon: "shield.fill",
                    color: analytics.threatDetectionEnabled ? .green : .orange
                )
                
                SystemHealthCard(
                    title: "风险等级",
                    value: analytics.riskLevel.displayName,
                    icon: "gauge.with.dots.needle.67percent",
                    color: analytics.riskLevel.color
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
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
            errorMessage = "初始化分析数据失败: \(error.localizedDescription)"
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
                errorMessage = "刷新分析数据失败: \(error.localizedDescription)"
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
            errorMessage = "导出数据失败: \(error.localizedDescription)"
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
    let period: AnalyticsTimePeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Comparison metric card
/// 对比指标卡片
struct ComparisonMetricCard: View {
    let title: String
    let currentValue: Double
    let previousValue: Double
    let format: MetricFormat
    
    enum MetricFormat {
        case percentage
        case score
        case count
    }
    
    private var formattedCurrentValue: String {
        switch format {
        case .percentage:
            return "\(String(format: "%.1f", currentValue * 100))%"
        case .score:
            return String(format: "%.2f", currentValue)
        case .count:
            return String(format: "%.0f", currentValue)
        }
    }
    
    private var changeValue: Double {
        previousValue == 0 ? 0 : (currentValue - previousValue) / previousValue
    }
    
    private var changeColor: Color {
        if changeValue > 0.05 { return .green }
        else if changeValue < -0.05 { return .red }
        else { return .gray }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(formattedCurrentValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 4) {
                Image(systemName: changeValue > 0 ? "arrow.up" : changeValue < 0 ? "arrow.down" : "minus")
                    .font(.caption2)
                    .foregroundColor(changeColor)
                
                Text("\(String(format: "%.1f", abs(changeValue) * 100))%")
                    .font(.caption2)
                    .foregroundColor(changeColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

/// Insight row
/// 洞察行
struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
        }
    }
}

/// Quick action card
/// 快速操作卡片
struct QuickActionCard: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Recent report row
/// 最近报告行
struct RecentReportRow: View {
    let report: GeneratedReport
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: report.configuration.type.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(report.configuration.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formatDate(report.generatedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(report.fileSizeFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button("查看") {
                // Handle report viewing
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
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
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Analytics Detail Navigation View (分析详情导航视图)

/// Navigation view for detailed analytics
/// 详细分析的导航视图
struct AnalyticsDetailNavigationView: View {
    let analyticsEngine: ProductionAnalyticsEngine
    let currentMetrics: ProductionMetrics?
    
    var body: some View {
        NavigationView {
            List {
                if let metrics = currentMetrics {
                    Section("详细分析") {
                        NavigationLink("生产性能详情") {
                            ProductionPerformanceDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("机台效率分析") {
                            MachineEfficiencyDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("质量指标详情") {
                            QualityMetricsDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("班次对比分析") {
                            ShiftComparisonDetailView(metrics: metrics)
                        }
                        
                        NavigationLink("趋势预测分析") {
                            TrendPredictionDetailView(metrics: metrics)
                        }
                    }
                    
                    Section("数据导出") {
                        Button("导出为Excel") {
                            // Handle Excel export
                        }
                        
                        Button("导出为PDF") {
                            // Handle PDF export
                        }
                        
                        Button("导出为CSV") {
                            // Handle CSV export
                        }
                    }
                }
            }
            .navigationTitle("详细分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Placeholder Detail Views (占位详情视图)

struct ProductionPerformanceDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("生产性能详细分析")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if !metrics.trendData.isEmpty {
                    ProductionMetricsChart(metrics: metrics)
                }
                
                // Additional detailed analysis components would go here
            }
            .padding()
        }
        .navigationTitle("生产性能")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MachineEfficiencyDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("机台效率详细分析")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Machine efficiency specific analysis would go here
            }
            .padding()
        }
        .navigationTitle("机台效率")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QualityMetricsDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("质量指标详细分析")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Quality metrics specific analysis would go here
            }
            .padding()
        }
        .navigationTitle("质量指标")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShiftComparisonDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("班次对比详细分析")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Shift comparison specific analysis would go here
            }
            .padding()
        }
        .navigationTitle("班次对比")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrendPredictionDetailView: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("趋势预测详细分析")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Trend prediction specific analysis would go here
            }
            .padding()
        }
        .navigationTitle("趋势预测")
        .navigationBarTitleDisplayMode(.inline)
    }
}