//
//  AdvancedReportGenerator.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Report Types (报告类型)

/// Available report types
/// 可用的报告类型
enum ReportType: String, CaseIterable {
    case productionSummary = "production_summary"
    case machinePerfomance = "machine_performance"
    case shiftAnalysis = "shift_analysis"
    case qualityReport = "quality_report"
    case executiveDashboard = "executive_dashboard"
    case detailedAnalytics = "detailed_analytics"
    case comparisonReport = "comparison_report"
    case trendAnalysis = "trend_analysis"
    
    var displayName: String {
        switch self {
        case .productionSummary: return "生产总结报告"
        case .machinePerfomance: return "机台性能报告"
        case .shiftAnalysis: return "班次分析报告"
        case .qualityReport: return "质量分析报告"
        case .executiveDashboard: return "高管仪表板"
        case .detailedAnalytics: return "详细分析报告"
        case .comparisonReport: return "对比分析报告"
        case .trendAnalysis: return "趋势分析报告"
        }
    }
    
    var description: String {
        switch self {
        case .productionSummary: return "包含生产批次、完成率、效率等核心指标的总结报告"
        case .machinePerfomance: return "机台利用率、维护状态、性能指标的专项报告"
        case .shiftAnalysis: return "早晚班次对比分析，包含效率和产量数据"
        case .qualityReport: return "质量指标、缺陷率、改进建议的质量专项报告"
        case .executiveDashboard: return "面向管理层的高级别概览和关键决策支持信息"
        case .detailedAnalytics: return "包含所有维度的深度分析和技术细节"
        case .comparisonReport: return "不同时间段的对比分析和趋势变化"
        case .trendAnalysis: return "长期趋势分析和预测性洞察"
        }
    }
    
    var icon: String {
        switch self {
        case .productionSummary: return "chart.bar.doc.horizontal"
        case .machinePerfomance: return "gearshape.2.fill"
        case .shiftAnalysis: return "clock.arrow.2.circlepath"
        case .qualityReport: return "checkmark.seal.fill"
        case .executiveDashboard: return "gauge.with.dots.needle.67percent"
        case .detailedAnalytics: return "chart.line.uptrend.xyaxis"
        case .comparisonReport: return "chart.bar.xaxis"
        case .trendAnalysis: return "waveform.path.ecg"
        }
    }
}

/// Report output formats
/// 报告输出格式
enum ReportFormat: String, CaseIterable {
    case html = "html"
    case pdf = "pdf"
    case csv = "csv"
    case json = "json"
    case excel = "excel"
    
    var displayName: String {
        switch self {
        case .html: return "HTML网页"
        case .pdf: return "PDF文档"
        case .csv: return "CSV数据"
        case .json: return "JSON数据"
        case .excel: return "Excel表格"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .html: return "html"
        case .pdf: return "pdf"
        case .csv: return "csv"
        case .json: return "json"
        case .excel: return "xlsx"
        }
    }
    
    var mimeType: String {
        switch self {
        case .html: return "text/html"
        case .pdf: return "application/pdf"
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        }
    }
}

// MARK: - Report Configuration (报告配置)

/// Configuration for report generation
/// 报告生成配置
struct ReportConfiguration {
    let type: ReportType
    let format: ReportFormat
    let timePeriod: AnalyticsTimePeriod
    let customStartDate: Date?
    let customEndDate: Date?
    let includeCharts: Bool
    let includeTrendData: Bool
    let includeComparisons: Bool
    let comparisonPeriod: AnalyticsTimePeriod?
    let filterOptions: ReportFilterOptions
    let templateOptions: ReportTemplateOptions
    
    init(
        type: ReportType,
        format: ReportFormat = .html,
        timePeriod: AnalyticsTimePeriod = .thisMonth,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil,
        includeCharts: Bool = true,
        includeTrendData: Bool = true,
        includeComparisons: Bool = false,
        comparisonPeriod: AnalyticsTimePeriod? = nil,
        filterOptions: ReportFilterOptions = ReportFilterOptions(),
        templateOptions: ReportTemplateOptions = ReportTemplateOptions()
    ) {
        self.type = type
        self.format = format
        self.timePeriod = timePeriod
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.includeCharts = includeCharts
        self.includeTrendData = includeTrendData
        self.includeComparisons = includeComparisons
        self.comparisonPeriod = comparisonPeriod
        self.filterOptions = filterOptions
        self.templateOptions = templateOptions
    }
}

/// Filter options for reports
/// 报告筛选选项
struct ReportFilterOptions {
    let machineIds: [String]
    let shiftTypes: [Shift]
    let statusTypes: [BatchStatus]
    let minimumBatchDuration: TimeInterval?
    let maximumBatchDuration: TimeInterval?
    let includeOnlyCompleted: Bool
    
    init(
        machineIds: [String] = [],
        shiftTypes: [Shift] = [],
        statusTypes: [BatchStatus] = [],
        minimumBatchDuration: TimeInterval? = nil,
        maximumBatchDuration: TimeInterval? = nil,
        includeOnlyCompleted: Bool = false
    ) {
        self.machineIds = machineIds
        self.shiftTypes = shiftTypes
        self.statusTypes = statusTypes
        self.minimumBatchDuration = minimumBatchDuration
        self.maximumBatchDuration = maximumBatchDuration
        self.includeOnlyCompleted = includeOnlyCompleted
    }
}

/// Template styling options
/// 模板样式选项
struct ReportTemplateOptions {
    let companyName: String
    let reportTitle: String?
    let includeHeader: Bool
    let includeFooter: Bool
    let includeTOC: Bool
    let colorScheme: ReportColorScheme
    let logoImagePath: String?
    let customCSS: String?
    
    init(
        companyName: String = "Lopan 生产管理系统",
        reportTitle: String? = nil,
        includeHeader: Bool = true,
        includeFooter: Bool = true,
        includeTOC: Bool = true,
        colorScheme: ReportColorScheme = .modern,
        logoImagePath: String? = nil,
        customCSS: String? = nil
    ) {
        self.companyName = companyName
        self.reportTitle = reportTitle
        self.includeHeader = includeHeader
        self.includeFooter = includeFooter
        self.includeTOC = includeTOC
        self.colorScheme = colorScheme
        self.logoImagePath = logoImagePath
        self.customCSS = customCSS
    }
}

enum ReportColorScheme: String, CaseIterable {
    case modern = "modern"
    case classic = "classic"
    case minimal = "minimal"
    case corporate = "corporate"
    
    var displayName: String {
        switch self {
        case .modern: return "现代风格"
        case .classic: return "经典风格"
        case .minimal: return "简约风格"
        case .corporate: return "企业风格"
        }
    }
}

// MARK: - Generated Report (生成的报告)

/// Container for generated report
/// 生成报告的容器
struct GeneratedReport: Identifiable {
    let id = UUID()
    let configuration: ReportConfiguration
    let content: Data
    let fileName: String
    let generatedAt: Date
    let fileSize: Int64
    let metadata: ReportMetadata
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

/// Metadata for generated reports
/// 生成报告的元数据
struct ReportMetadata {
    let generationDuration: TimeInterval
    let dataPointsIncluded: Int
    let chartsGenerated: Int
    let tablesIncluded: Int
    let metricsCalculated: Int
    let generatedBy: String
    let reportVersion: String
    
    init(
        generationDuration: TimeInterval,
        dataPointsIncluded: Int = 0,
        chartsGenerated: Int = 0,
        tablesIncluded: Int = 0,
        metricsCalculated: Int = 0,
        generatedBy: String,
        reportVersion: String = "1.0"
    ) {
        self.generationDuration = generationDuration
        self.dataPointsIncluded = dataPointsIncluded
        self.chartsGenerated = chartsGenerated
        self.tablesIncluded = tablesIncluded
        self.metricsCalculated = metricsCalculated
        self.generatedBy = generatedBy
        self.reportVersion = reportVersion
    }
}

// MARK: - Advanced Report Generator (高级报告生成器)

/// Advanced report generation service with multiple formats and templates
/// 支持多种格式和模板的高级报告生成服务
@MainActor
class AdvancedReportGenerator: ObservableObject {
    
    // MARK: - Dependencies
    private let analyticsEngine: ProductionAnalyticsEngine
    private let auditService: EnhancedSecurityAuditService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var recentReports: [GeneratedReport] = []
    @Published var reportTemplates: [ReportType: String] = [:]
    
    // MARK: - Configuration
    private let maxRecentReports = 50
    private let tempDirectory: URL
    
    init(
        analyticsEngine: ProductionAnalyticsEngine,
        auditService: EnhancedSecurityAuditService,
        authService: AuthenticationService
    ) {
        self.analyticsEngine = analyticsEngine
        self.auditService = auditService
        self.authService = authService
        
        // Create temporary directory for report generation
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LopanReports", isDirectory: true)
        
        // Create temp directory if it doesn't exist
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Load report templates
        loadReportTemplates()
    }
    
    // MARK: - Report Generation
    
    /// Generate comprehensive report based on configuration
    /// 基于配置生成综合报告
    func generateReport(configuration: ReportConfiguration) async throws -> GeneratedReport {
        let startTime = Date()
        
        guard !isGenerating else {
            throw ReportGenerationError.generationInProgress
        }
        
        isGenerating = true
        generationProgress = 0.0
        
        defer {
            isGenerating = false
            generationProgress = 0.0
        }
        
        do {
            // Log report generation start
            try? await auditService.logSecurityEvent(
                category: SecurityEventCategory.systemOperation,
                severity: SecurityEventSeverity.info,
                eventName: "report_generation_started",
                description: "开始生成报告: \(configuration.type.displayName)",
                details: [
                    "report_type": configuration.type.rawValue,
                    "format": configuration.format.rawValue,
                    "time_period": configuration.timePeriod.rawValue
                ]
            )
            
            // Step 1: Gather analytics data (20%)
            generationProgress = 0.2
            let metrics = await analyticsEngine.calculateMetrics(
                for: configuration.timePeriod,
                customStart: configuration.customStartDate,
                customEnd: configuration.customEndDate
            )
            
            // Step 2: Gather comparison data if needed (40%)
            generationProgress = 0.4
            var comparisonData: AnalyticsComparison?
            if configuration.includeComparisons, let comparisonPeriod = configuration.comparisonPeriod {
                comparisonData = await analyticsEngine.compareMetrics(
                    current: configuration.timePeriod,
                    comparison: comparisonPeriod
                )
            }
            
            // Step 3: Generate report content (70%)
            generationProgress = 0.7
            let reportContent = try await generateReportContent(
                configuration: configuration,
                metrics: metrics,
                comparison: comparisonData
            )
            
            // Step 4: Convert to specified format (90%)
            generationProgress = 0.9
            let finalContent = try await convertToFormat(
                content: reportContent,
                format: configuration.format,
                configuration: configuration
            )
            
            // Step 5: Create report file (100%)
            generationProgress = 1.0
            let fileName = generateFileName(for: configuration)
            let generationDuration = Date().timeIntervalSince(startTime)
            
            let metadata = ReportMetadata(
                generationDuration: generationDuration,
                dataPointsIncluded: metrics.trendData.count,
                chartsGenerated: configuration.includeCharts ? getChartCount(for: configuration.type) : 0,
                tablesIncluded: getTableCount(for: configuration.type),
                metricsCalculated: getMetricsCount(for: configuration.type),
                generatedBy: authService.currentUser?.name ?? "System"
            )
            
            let report = GeneratedReport(
                configuration: configuration,
                content: finalContent,
                fileName: fileName,
                generatedAt: Date(),
                fileSize: Int64(finalContent.count),
                metadata: metadata
            )
            
            // Add to recent reports
            recentReports.insert(report, at: 0)
            if recentReports.count > maxRecentReports {
                recentReports.removeLast()
            }
            
            // Log successful generation
            try? await auditService.logSecurityEvent(
                category: SecurityEventCategory.systemOperation,
                severity: SecurityEventSeverity.info,
                eventName: "report_generation_completed",
                description: "报告生成完成: \(configuration.type.displayName)",
                details: [
                    "report_id": report.id.uuidString,
                    "file_size": "\(report.fileSize)",
                    "generation_duration": "\(String(format: "%.2f", generationDuration))s",
                    "data_points": "\(metadata.dataPointsIncluded)"
                ]
            )
            
            return report
            
        } catch {
            try? await auditService.logSecurityEvent(
                category: SecurityEventCategory.systemOperation,
                severity: SecurityEventSeverity.error,
                eventName: "report_generation_failed",
                description: "报告生成失败: \(error.localizedDescription)",
                details: [
                    "report_type": configuration.type.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }
    
    // MARK: - Content Generation
    
    /// Generate report content based on type and metrics
    /// 基于类型和指标生成报告内容
    private func generateReportContent(
        configuration: ReportConfiguration,
        metrics: ProductionMetrics,
        comparison: AnalyticsComparison?
    ) async throws -> ReportContent {
        
        switch configuration.type {
        case .productionSummary:
            return generateProductionSummary(metrics: metrics, comparison: comparison, config: configuration)
        case .machinePerfomance:
            return generateMachinePerformanceReport(metrics: metrics, comparison: comparison, config: configuration)
        case .shiftAnalysis:
            return generateShiftAnalysisReport(metrics: metrics, comparison: comparison, config: configuration)
        case .qualityReport:
            return generateQualityReport(metrics: metrics, comparison: comparison, config: configuration)
        case .executiveDashboard:
            return generateExecutiveDashboard(metrics: metrics, comparison: comparison, config: configuration)
        case .detailedAnalytics:
            return generateDetailedAnalytics(metrics: metrics, comparison: comparison, config: configuration)
        case .comparisonReport:
            return generateComparisonReport(metrics: metrics, comparison: comparison, config: configuration)
        case .trendAnalysis:
            return generateTrendAnalysis(metrics: metrics, comparison: comparison, config: configuration)
        }
    }
    
    // MARK: - Specific Report Generators
    
    private func generateProductionSummary(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        // Executive Summary
        sections.append(ReportSection(
            title: "执行摘要",
            content: """
            报告期间: \(formatDateRange(start: metrics.startDate, end: metrics.endDate))
            
            关键指标概览:
            • 总批次数: \(metrics.totalBatches)
            • 完成率: \(String(format: "%.1f", metrics.batchCompletionRate * 100))%
            • 机台利用率: \(String(format: "%.1f", metrics.machineUtilizationRate * 100))%
            • 生产效率指数: \(String(format: "%.1f", metrics.productivityIndex * 100))%
            """,
            type: .summary
        ))
        
        // Production Metrics
        sections.append(ReportSection(
            title: "生产指标详情",
            content: generateProductionMetricsTable(metrics: metrics),
            type: .table
        ))
        
        // Machine Utilization
        sections.append(ReportSection(
            title: "机台利用分析",
            content: generateMachineUtilizationContent(metrics: metrics),
            type: .analysis
        ))
        
        // Trend Analysis
        if config.includeTrendData && !metrics.trendData.isEmpty {
            sections.append(ReportSection(
                title: "趋势分析",
                content: generateTrendAnalysisContent(trendData: metrics.trendData),
                type: .chart
            ))
        }
        
        // Comparison Analysis
        if let comparison = comparison {
            sections.append(ReportSection(
                title: "对比分析",
                content: generateComparisonContent(comparison: comparison),
                type: .comparison
            ))
        }
        
        return ReportContent(
            title: config.templateOptions.reportTitle ?? "生产总结报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [
                "generated_at": ISO8601DateFormatter().string(from: Date()),
                "period": config.timePeriod.displayName,
                "total_batches": "\(metrics.totalBatches)",
                "completion_rate": "\(String(format: "%.1f", metrics.batchCompletionRate * 100))%"
            ]
        )
    }
    
    private func generateMachinePerformanceReport(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        sections.append(ReportSection(
            title: "机台性能概览",
            content: """
            机台总数: \(metrics.totalMachines)
            活跃机台: \(metrics.activeMachines)
            利用率: \(String(format: "%.1f", metrics.machineUtilizationRate * 100))%
            平均运行时间: \(formatDuration(metrics.averageMachineUptime))
            效率评分: \(String(format: "%.1f", metrics.machineEfficiencyScore * 100))/100
            """,
            type: .summary
        ))
        
        sections.append(ReportSection(
            title: "性能指标分析",
            content: generateMachinePerformanceTable(metrics: metrics),
            type: .table
        ))
        
        return ReportContent(
            title: "机台性能报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    private func generateShiftAnalysisReport(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        sections.append(ReportSection(
            title: "班次对比分析",
            content: """
            早班批次数: \(metrics.morningShiftBatches)
            晚班批次数: \(metrics.eveningShiftBatches)
            班次效率对比: \(String(format: "%.1f", metrics.shiftEfficiencyComparison * 100))% (早班占比)
            """,
            type: .summary
        ))
        
        return ReportContent(
            title: "班次分析报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    private func generateQualityReport(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        sections.append(ReportSection(
            title: "质量指标概览",
            content: """
            质量评分: \(String(format: "%.1f", metrics.qualityScore * 100))/100
            拒绝批次: \(metrics.rejectedBatches)
            拒绝率: \(String(format: "%.1f", (Double(metrics.rejectedBatches) / Double(metrics.totalBatches)) * 100))%
            """,
            type: .summary
        ))
        
        return ReportContent(
            title: "质量分析报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    private func generateExecutiveDashboard(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        sections.append(ReportSection(
            title: "关键绩效指标",
            content: generateKPIContent(metrics: metrics),
            type: .summary
        ))
        
        if let comparison = comparison {
            sections.append(ReportSection(
                title: "趋势概览",
                content: """
                整体趋势: \(comparison.overallTrend.displayName)
                
                改进点:
                \(comparison.improvements.map { "• \($0)" }.joined(separator: "\n"))
                
                关注点:
                \(comparison.concerns.map { "• \($0)" }.joined(separator: "\n"))
                """,
                type: .analysis
            ))
        }
        
        return ReportContent(
            title: "高管仪表板",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    private func generateDetailedAnalytics(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        // Include all metrics in detailed format
        sections.append(contentsOf: [
            generateProductionSummary(metrics: metrics, comparison: comparison, config: config).sections,
            generateMachinePerformanceReport(metrics: metrics, comparison: comparison, config: config).sections,
            generateShiftAnalysisReport(metrics: metrics, comparison: comparison, config: config).sections,
            generateQualityReport(metrics: metrics, comparison: comparison, config: config).sections
        ].flatMap { $0 })
        
        return ReportContent(
            title: "详细分析报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    private func generateComparisonReport(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        if let comparison = comparison {
            sections.append(ReportSection(
                title: "对比分析结果",
                content: generateComparisonContent(comparison: comparison),
                type: .comparison
            ))
        } else {
            sections.append(ReportSection(
                title: "对比分析",
                content: "未提供对比数据，无法生成对比分析。",
                type: .text
            ))
        }
        
        return ReportContent(
            title: "对比分析报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    private func generateTrendAnalysis(metrics: ProductionMetrics, comparison: AnalyticsComparison?, config: ReportConfiguration) -> ReportContent {
        var sections: [ReportSection] = []
        
        sections.append(ReportSection(
            title: "趋势分析",
            content: generateTrendAnalysisContent(trendData: metrics.trendData),
            type: .chart
        ))
        
        return ReportContent(
            title: "趋势分析报告",
            subtitle: formatDateRange(start: metrics.startDate, end: metrics.endDate),
            sections: sections,
            metadata: [:]
        )
    }
    
    // MARK: - Content Generation Helpers
    
    private func generateProductionMetricsTable(metrics: ProductionMetrics) -> String {
        return """
        | 指标 | 数值 | 占比/评级 |
        |------|------|-----------|
        | 总批次数 | \(metrics.totalBatches) | - |
        | 已完成批次 | \(metrics.completedBatches) | \(String(format: "%.1f", metrics.batchCompletionRate * 100))% |
        | 活跃批次 | \(metrics.activeBatches) | - |
        | 拒绝批次 | \(metrics.rejectedBatches) | \(String(format: "%.1f", (Double(metrics.rejectedBatches) / Double(metrics.totalBatches)) * 100))% |
        | 平均批次时长 | \(formatDuration(metrics.averageBatchDuration)) | - |
        | 生产总时间 | \(formatDuration(metrics.totalProductionHours)) | - |
        | 计划生产时间 | \(formatDuration(metrics.plannedProductionHours)) | - |
        | 实际生产时间 | \(formatDuration(metrics.actualProductionHours)) | - |
        | 生产效率指数 | \(String(format: "%.3f", metrics.productivityIndex)) | \(String(format: "%.1f", metrics.productivityIndex * 100))% |
        | 质量评分 | \(String(format: "%.3f", metrics.qualityScore)) | \(String(format: "%.1f", metrics.qualityScore * 100))/100 |
        """
    }
    
    private func generateMachineUtilizationContent(metrics: ProductionMetrics) -> String {
        return """
        机台利用率分析：
        
        • 总机台数：\(metrics.totalMachines)
        • 活跃机台数：\(metrics.activeMachines)
        • 利用率：\(String(format: "%.1f", metrics.machineUtilizationRate * 100))%
        • 平均运行时间：\(formatDuration(metrics.averageMachineUptime))
        • 效率评分：\(String(format: "%.1f", metrics.machineEfficiencyScore * 100))/100
        
        利用率评估：
        \(metrics.machineUtilizationRate >= 0.8 ? "✓ 利用率优秀" : metrics.machineUtilizationRate >= 0.6 ? "⚠ 利用率良好，有改进空间" : "⚠ 利用率较低，需要优化")
        """
    }
    
    private func generateMachinePerformanceTable(metrics: ProductionMetrics) -> String {
        return """
        | 性能指标 | 当前值 | 评估 |
        |----------|--------|------|
        | 机台利用率 | \(String(format: "%.1f", metrics.machineUtilizationRate * 100))% | \(metrics.machineUtilizationRate >= 0.8 ? "优秀" : metrics.machineUtilizationRate >= 0.6 ? "良好" : "需改进") |
        | 平均运行时间 | \(formatDuration(metrics.averageMachineUptime)) | - |
        | 效率评分 | \(String(format: "%.1f", metrics.machineEfficiencyScore * 100))/100 | \(metrics.machineEfficiencyScore >= 0.8 ? "优秀" : metrics.machineEfficiencyScore >= 0.6 ? "良好" : "需改进") |
        | 活跃机台比例 | \(String(format: "%.1f", Double(metrics.activeMachines) / Double(metrics.totalMachines) * 100))% | - |
        """
    }
    
    private func generateKPIContent(metrics: ProductionMetrics) -> String {
        return """
        关键绩效指标 (KPI) 仪表板
        
        📊 生产完成率: \(String(format: "%.1f", metrics.batchCompletionRate * 100))%
        🏭 机台利用率: \(String(format: "%.1f", metrics.machineUtilizationRate * 100))%
        ⚡ 生产效率: \(String(format: "%.1f", metrics.productivityIndex * 100))%
        ✅ 质量评分: \(String(format: "%.1f", metrics.qualityScore * 100))/100
        
        📈 总体表现: \(evaluateOverallPerformance(metrics: metrics))
        """
    }
    
    private func generateTrendAnalysisContent(trendData: [AnalyticsTrendPoint]) -> String {
        guard !trendData.isEmpty else {
            return "暂无趋势数据可供分析。"
        }
        
        let recentValues = trendData.suffix(7).map { $0.value }
        let average = recentValues.reduce(0, +) / Double(recentValues.count)
        let isIncreasing = recentValues.last! > recentValues.first!
        
        return """
        趋势分析：
        
        • 数据点数量：\(trendData.count)
        • 最近7天平均值：\(String(format: "%.2f", average))
        • 趋势方向：\(isIncreasing ? "📈 上升" : "📉 下降")
        • 最新值：\(String(format: "%.2f", trendData.last?.value ?? 0))
        • 最高值：\(String(format: "%.2f", trendData.map { $0.value }.max() ?? 0))
        • 最低值：\(String(format: "%.2f", trendData.map { $0.value }.min() ?? 0))
        """
    }
    
    private func generateComparisonContent(comparison: AnalyticsComparison) -> String {
        return """
        对比分析结果：
        
        📊 整体趋势：\(comparison.overallTrend.displayName)
        
        💪 改进点：
        \(comparison.improvements.isEmpty ? "暂无明显改进" : comparison.improvements.map { "• \($0)" }.joined(separator: "\n"))
        
        ⚠️ 关注点：
        \(comparison.concerns.isEmpty ? "暂无关注点" : comparison.concerns.map { "• \($0)" }.joined(separator: "\n"))
        
        💡 建议措施：
        \(comparison.recommendations.isEmpty ? "继续保持当前水平" : comparison.recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
    
    // MARK: - Format Conversion
    
    /// Convert report content to specified format
    /// 将报告内容转换为指定格式
    private func convertToFormat(content: ReportContent, format: ReportFormat, configuration: ReportConfiguration) async throws -> Data {
        switch format {
        case .html:
            return try generateHTMLReport(content: content, configuration: configuration)
        case .pdf:
            return try await generatePDFReport(content: content, configuration: configuration)
        case .csv:
            return try generateCSVReport(content: content, configuration: configuration)
        case .json:
            return try generateJSONReport(content: content, configuration: configuration)
        case .excel:
            return try generateExcelReport(content: content, configuration: configuration)
        }
    }
    
    private func generateHTMLReport(content: ReportContent, configuration: ReportConfiguration) throws -> Data {
        let template = getHTMLTemplate(for: configuration.templateOptions.colorScheme)
        let htmlContent = renderHTMLContent(content: content, template: template, options: configuration.templateOptions)
        
        guard let data = htmlContent.data(using: .utf8) else {
            throw ReportGenerationError.contentConversionFailed
        }
        
        return data
    }
    
    private func generatePDFReport(content: ReportContent, configuration: ReportConfiguration) async throws -> Data {
        // First generate HTML, then convert to PDF
        let htmlData = try generateHTMLReport(content: content, configuration: configuration)
        
        // In a real implementation, you would use a PDF generation library
        // For now, return the HTML data as placeholder
        return htmlData
    }
    
    private func generateCSVReport(content: ReportContent, configuration: ReportConfiguration) throws -> Data {
        var csvLines: [String] = []
        
        // Header
        csvLines.append("Section,Content Type,Data")
        
        // Add content sections as CSV rows
        for section in content.sections {
            let cleanContent = section.content.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ",", with: ";")
            csvLines.append("\"\(section.title)\",\"\(section.type.rawValue)\",\"\(cleanContent)\"")
        }
        
        let csvString = csvLines.joined(separator: "\n")
        guard let data = csvString.data(using: .utf8) else {
            throw ReportGenerationError.contentConversionFailed
        }
        
        return data
    }
    
    private func generateJSONReport(content: ReportContent, configuration: ReportConfiguration) throws -> Data {
        let reportData: [String: Any] = [
            "title": content.title,
            "subtitle": content.subtitle,
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "configuration": [
                "type": configuration.type.rawValue,
                "format": configuration.format.rawValue,
                "time_period": configuration.timePeriod.rawValue
            ],
            "sections": content.sections.map { section in
                [
                    "title": section.title,
                    "type": section.type.rawValue,
                    "content": section.content
                ]
            },
            "metadata": content.metadata
        ]
        
        return try JSONSerialization.data(withJSONObject: reportData, options: .prettyPrinted)
    }
    
    private func generateExcelReport(content: ReportContent, configuration: ReportConfiguration) throws -> Data {
        // Placeholder implementation - would use a library like xlsxwriter
        // For now, return CSV data
        return try generateCSVReport(content: content, configuration: configuration)
    }
    
    // MARK: - Template Management
    
    private func loadReportTemplates() {
        // Load HTML templates for different report types
        // In a real implementation, these would be loaded from files
        reportTemplates = [
            .productionSummary: getHTMLTemplate(for: .modern),
            .machinePerfomance: getHTMLTemplate(for: .corporate),
            .executiveDashboard: getHTMLTemplate(for: .minimal)
        ]
    }
    
    private func getHTMLTemplate(for scheme: ReportColorScheme) -> String {
        let baseTemplate = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>{TITLE}</title>
            <style>
                {CSS_STYLES}
            </style>
        </head>
        <body>
            {HEADER}
            <main>
                <h1>{TITLE}</h1>
                <h2>{SUBTITLE}</h2>
                {CONTENT}
            </main>
            {FOOTER}
        </body>
        </html>
        """
        
        return baseTemplate
    }
    
    private func renderHTMLContent(content: ReportContent, template: String, options: ReportTemplateOptions) -> String {
        var html = template
        
        // Replace placeholders
        html = html.replacingOccurrences(of: "{TITLE}", with: content.title)
        html = html.replacingOccurrences(of: "{SUBTITLE}", with: content.subtitle)
        html = html.replacingOccurrences(of: "{CSS_STYLES}", with: getCSSStyles(for: options.colorScheme))
        html = html.replacingOccurrences(of: "{HEADER}", with: options.includeHeader ? generateHeader(options: options) : "")
        html = html.replacingOccurrences(of: "{FOOTER}", with: options.includeFooter ? generateFooter(options: options) : "")
        
        // Generate content sections
        let sectionsHTML = content.sections.map { section in
            """
            <section>
                <h3>\(section.title)</h3>
                <div class="content-\(section.type.rawValue)">
                    \(formatContentForHTML(section.content, type: section.type))
                </div>
            </section>
            """
        }.joined(separator: "\n")
        
        html = html.replacingOccurrences(of: "{CONTENT}", with: sectionsHTML)
        
        return html
    }
    
    private func getCSSStyles(for scheme: ReportColorScheme) -> String {
        let baseStyles = """
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; }
        h3 { color: #007AFF; margin-top: 25px; }
        section { margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .content-summary { background: #f8f9fa; padding: 15px; border-radius: 5px; }
        .content-analysis { background: #fff3cd; padding: 15px; border-radius: 5px; }
        .content-comparison { background: #d4edda; padding: 15px; border-radius: 5px; }
        """
        
        return baseStyles
    }
    
    private func generateHeader(options: ReportTemplateOptions) -> String {
        return """
        <header style="text-align: center; border-bottom: 1px solid #ddd; padding-bottom: 20px; margin-bottom: 30px;">
            <h1 style="margin: 0; color: #007AFF;">\(options.companyName)</h1>
            <p style="margin: 5px 0; color: #666;">生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))</p>
        </header>
        """
    }
    
    private func generateFooter(options: ReportTemplateOptions) -> String {
        return """
        <footer style="text-align: center; border-top: 1px solid #ddd; padding-top: 20px; margin-top: 40px; color: #666; font-size: 14px;">
            <p>© \(Calendar.current.component(.year, from: Date())) \(options.companyName). 此报告由Lopan生产管理系统自动生成。</p>
        </footer>
        """
    }
    
    private func formatContentForHTML(_ content: String, type: ReportSectionType) -> String {
        switch type {
        case .table:
            return convertMarkdownTableToHTML(content)
        case .summary, .analysis, .comparison, .text:
            return content.replacingOccurrences(of: "\n", with: "<br>")
        case .chart:
            return content.replacingOccurrences(of: "\n", with: "<br>")
        }
    }
    
    private func convertMarkdownTableToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard lines.count >= 3 else { return markdown }
        
        var html = "<table>\n"
        
        // Header row
        if let headerLine = lines.first {
            let headers = headerLine.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            html += "<thead><tr>"
            for header in headers {
                html += "<th>\(header)</th>"
            }
            html += "</tr></thead>\n"
        }
        
        // Data rows (skip header and separator)
        html += "<tbody>\n"
        for line in lines.dropFirst(2) {
            let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            html += "<tr>"
            for cell in cells {
                html += "<td>\(cell)</td>"
            }
            html += "</tr>\n"
        }
        html += "</tbody></table>"
        
        return html
    }
    
    // MARK: - Helper Methods
    
    private func generateFileName(for configuration: ReportConfiguration) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let reportName = configuration.type.rawValue
        let periodName = configuration.timePeriod.rawValue
        let format = configuration.format.fileExtension
        
        return "\(reportName)_\(periodName)_\(timestamp).\(format)"
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func evaluateOverallPerformance(metrics: ProductionMetrics) -> String {
        let score = (metrics.batchCompletionRate + metrics.machineUtilizationRate + metrics.productivityIndex + metrics.qualityScore) / 4
        
        if score >= 0.9 { return "优秀 🌟" }
        else if score >= 0.75 { return "良好 👍" }
        else if score >= 0.6 { return "一般 ⚠️" }
        else { return "需改进 🔧" }
    }
    
    private func getChartCount(for type: ReportType) -> Int {
        switch type {
        case .productionSummary: return 3
        case .machinePerfomance: return 2
        case .shiftAnalysis: return 2
        case .qualityReport: return 1
        case .executiveDashboard: return 4
        case .detailedAnalytics: return 8
        case .comparisonReport: return 2
        case .trendAnalysis: return 3
        }
    }
    
    private func getTableCount(for type: ReportType) -> Int {
        switch type {
        case .productionSummary: return 2
        case .machinePerfomance: return 3
        case .shiftAnalysis: return 1
        case .qualityReport: return 2
        case .executiveDashboard: return 1
        case .detailedAnalytics: return 8
        case .comparisonReport: return 2
        case .trendAnalysis: return 1
        }
    }
    
    private func getMetricsCount(for type: ReportType) -> Int {
        switch type {
        case .productionSummary: return 12
        case .machinePerfomance: return 8
        case .shiftAnalysis: return 6
        case .qualityReport: return 5
        case .executiveDashboard: return 15
        case .detailedAnalytics: return 25
        case .comparisonReport: return 20
        case .trendAnalysis: return 10
        }
    }
    
    // MARK: - Export and Sharing
    
    /// Save report to device storage
    /// 将报告保存到设备存储
    func saveReportToStorage(_ report: GeneratedReport) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportsDirectory = documentsPath.appendingPathComponent("Reports", isDirectory: true)
        
        // Create reports directory if it doesn't exist
        try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        
        let fileURL = reportsDirectory.appendingPathComponent(report.fileName)
        try report.content.write(to: fileURL)
        
        try? await auditService.logSecurityEvent(
            category: SecurityEventCategory.systemOperation,
            severity: .info,
            eventName: "report_saved",
            description: "报告已保存: \(report.fileName)",
            details: [
                "report_id": report.id.uuidString,
                "file_path": fileURL.path
            ]
        )
        
        return fileURL
    }
    
    /// Delete generated report
    /// 删除生成的报告
    func deleteReport(_ report: GeneratedReport) {
        recentReports.removeAll { $0.id == report.id }
        
        Task {
            try? await auditService.logSecurityEvent(
                category: SecurityEventCategory.systemOperation,
                severity: SecurityEventSeverity.info,
                eventName: "report_deleted",
                description: "报告已删除: \(report.fileName)",
                details: ["report_id": report.id.uuidString]
            )
        }
    }
}

// MARK: - Supporting Structures

struct ReportContent {
    let title: String
    let subtitle: String
    let sections: [ReportSection]
    let metadata: [String: String]
}

struct ReportSection {
    let title: String
    let content: String
    let type: ReportSectionType
}

enum ReportSectionType: String {
    case summary = "summary"
    case table = "table"
    case chart = "chart"
    case analysis = "analysis"
    case comparison = "comparison"
    case text = "text"
}

// MARK: - Error Types

enum ReportGenerationError: Error, LocalizedError {
    case generationInProgress
    case contentConversionFailed
    case templateNotFound
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .generationInProgress:
            return "报告生成正在进行中"
        case .contentConversionFailed:
            return "内容格式转换失败"
        case .templateNotFound:
            return "找不到报告模板"
        case .invalidConfiguration:
            return "报告配置无效"
        }
    }
}