//
//  ReportGeneratorView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Report Generator View (报告生成器视图)

/// Comprehensive report generation interface
/// 综合报告生成界面
struct ReportGeneratorView: View {
    @ObservedObject var reportGenerator: AdvancedReportGenerator
    let currentMetrics: ProductionMetrics?
    
    @State private var selectedReportType: ReportType = .productionSummary
    @State private var selectedFormat: ReportFormat = .html
    @State private var selectedTimePeriod: AnalyticsTimePeriod = .thisMonth
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var includeCharts = true
    @State private var includeTrendData = true
    @State private var includeComparisons = false
    @State private var comparisonPeriod: AnalyticsTimePeriod = .lastMonth
    @State private var reportTitle = ""
    @State private var isGenerating = false
    @State private var showingGeneratedReport = false
    @State private var generatedReport: GeneratedReport?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var selectedTab: ReportTab = .configure
    
    @Environment(\.dismiss) private var dismiss
    
    enum ReportTab: String, CaseIterable {
        case configure = "configure"
        case preview = "preview"
        case history = "history"
        
        var displayName: String {
            switch self {
            case .configure: return "配置"
            case .preview: return "预览"
            case .history: return "历史"
            }
        }
        
        var icon: String {
            switch self {
            case .configure: return "gear"
            case .preview: return "eye"
            case .history: return "clock"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                switch selectedTab {
                case .configure:
                    configurationView
                case .preview:
                    previewView
                case .history:
                    historyView
                }
            }
            .navigationTitle("报告生成器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        Task {
                            await generateReport()
                        }
                    }
                    .disabled(isGenerating || selectedTab != .configure)
                }
            }
            .sheet(isPresented: $showingGeneratedReport) {
                if let report = generatedReport {
                    GeneratedReportView(report: report)
                }
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
        }
    }
    
    // MARK: - Tab Selector (标签选择器)
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ReportTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tab.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(selectedTab == tab ? LopanColors.primary.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Configuration View (配置视图)
    
    private var configurationView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Report type selection
                reportTypeSection
                
                // Time period selection
                timePeriodSection
                
                // Format and options
                formatOptionsSection
                
                // Template options
                templateOptionsSection
                
                // Generate button
                generateButtonSection
            }
            .padding()
        }
    }
    
    private var reportTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("报告类型")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    ReportTypeCard(
                        type: type,
                        isSelected: selectedReportType == type,
                        action: { selectedReportType = type }
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
    
    private var timePeriodSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("时间范围")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Period selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsTimePeriod.allCases, id: \.self) { period in
                        TimePeriodChip(
                            period: period,
                            isSelected: selectedTimePeriod == period,
                            action: { selectedTimePeriod = period }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Custom date range (if custom selected)
            if selectedTimePeriod == .custom {
                VStack(spacing: 12) {
                    DatePicker("开始日期", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $customEndDate, displayedComponents: .date)
                }
                .padding()
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
    
    private var formatOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("格式和选项")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Format selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("输出格式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ReportFormat.allCases, id: \.self) { format in
                                FormatChip(
                                    format: format,
                                    isSelected: selectedFormat == format,
                                    action: { selectedFormat = format }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                
                // Content options
                VStack(alignment: .leading, spacing: 12) {
                    Text("内容选项")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 8) {
                        OptionToggle(
                            title: "包含图表",
                            description: "在报告中包含可视化图表",
                            isOn: $includeCharts
                        )
                        
                        OptionToggle(
                            title: "包含趋势数据",
                            description: "显示历史趋势和变化",
                            isOn: $includeTrendData
                        )
                        
                        OptionToggle(
                            title: "包含对比分析",
                            description: "与上一期间进行对比分析",
                            isOn: $includeComparisons
                        )
                    }
                }
                
                // Comparison period selection (if comparisons enabled)
                if includeComparisons {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("对比期间")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("对比期间", selection: $comparisonPeriod) {
                            ForEach(getAvailableComparisonPeriods(), id: \.self) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
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
    
    private var templateOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("模板设置")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("报告标题")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("输入自定义标题（可选）", text: $reportTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("样式主题")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        ForEach(ReportColorScheme.allCases, id: \.self) { scheme in
                            ColorSchemeChip(scheme: scheme)
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
    
    private var generateButtonSection: some View {
        VStack(spacing: 16) {
            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("正在生成报告...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if reportGenerator.generationProgress > 0 {
                        ProgressView(value: reportGenerator.generationProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("\(String(format: "%.0f", reportGenerator.generationProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                )
            } else {
                Button("生成报告") {
                    Task {
                        await generateReport()
                    }
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
    }
    
    // MARK: - Preview View (预览视图)
    
    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("报告预览")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                if let metrics = currentMetrics {
                    ReportPreviewCard(
                        reportType: selectedReportType,
                        metrics: metrics,
                        format: selectedFormat,
                        timePeriod: selectedTimePeriod
                    )
                    .padding(.horizontal)
                } else {
                    Text("暂无数据可预览")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.tertiarySystemBackground))
                        )
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - History View (历史视图)
    
    private var historyView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if reportGenerator.recentReports.isEmpty {
                    Text("暂无报告历史")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.tertiarySystemBackground))
                        )
                } else {
                    ForEach(reportGenerator.recentReports) { report in
                        ReportHistoryCard(
                            report: report,
                            onView: { showReportDetail(report) },
                            onDelete: { deleteReport(report) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions (操作)
    
    private func generateReport() async {
        isGenerating = true
        
        do {
            let configuration = ReportConfiguration(
                type: selectedReportType,
                format: selectedFormat,
                timePeriod: selectedTimePeriod,
                customStartDate: selectedTimePeriod == .custom ? customStartDate : nil,
                customEndDate: selectedTimePeriod == .custom ? customEndDate : nil,
                includeCharts: includeCharts,
                includeTrendData: includeTrendData,
                includeComparisons: includeComparisons,
                comparisonPeriod: includeComparisons ? comparisonPeriod : nil,
                templateOptions: ReportTemplateOptions(
                    reportTitle: reportTitle.isEmpty ? nil : reportTitle
                )
            )
            
            let report = try await reportGenerator.generateReport(configuration: configuration)
            
            await MainActor.run {
                generatedReport = report
                showingGeneratedReport = true
                isGenerating = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "生成报告失败: \(error.localizedDescription)"
                showingErrorAlert = true
                isGenerating = false
            }
        }
    }
    
    private func showReportDetail(_ report: GeneratedReport) {
        generatedReport = report
        showingGeneratedReport = true
    }
    
    private func deleteReport(_ report: GeneratedReport) {
        reportGenerator.deleteReport(report)
    }
    
    private func getAvailableComparisonPeriods() -> [AnalyticsTimePeriod] {
        switch selectedTimePeriod {
        case .today: return [.yesterday]
        case .thisWeek: return [.lastWeek]
        case .thisMonth: return [.lastMonth]
        case .thisQuarter: return [.lastQuarter]
        default: return [.lastMonth, .lastQuarter]
        }
    }
}

// MARK: - Supporting Views (支持视图)

/// Report type selection card
/// 报告类型选择卡片
struct ReportTypeCard: View {
    let type: ReportType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? LopanColors.primary : Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? LopanColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Time period chip
/// 时间段芯片
struct TimePeriodChip: View {
    let period: AnalyticsTimePeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? LopanColors.primary : Color(.tertiarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Format selection chip
/// 格式选择芯片
struct FormatChip: View {
    let format: ReportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(format.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? LopanColors.primary : Color(.tertiarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Option toggle
/// 选项开关
struct OptionToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

/// Color scheme chip
/// 颜色主题芯片
struct ColorSchemeChip: View {
    let scheme: ReportColorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(schemeColor)
                .frame(width: 30, height: 20)
            
            Text(scheme.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var schemeColor: Color {
        switch scheme {
        case .modern: return .blue
        case .classic: return .brown
        case .minimal: return .gray
        case .corporate: return .indigo
        }
    }
}

/// Report preview card
/// 报告预览卡片
struct ReportPreviewCard: View {
    let reportType: ReportType
    let metrics: ProductionMetrics
    let format: ReportFormat
    let timePeriod: AnalyticsTimePeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reportType.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(format.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(timePeriod.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            
            Text(reportType.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Preview content based on metrics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("预计内容:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    PreviewMetric(title: "批次", value: "\(metrics.totalBatches)")
                    PreviewMetric(title: "完成率", value: "\(String(format: "%.1f", metrics.batchCompletionRate * 100))%")
                    PreviewMetric(title: "机台", value: "\(metrics.totalMachines)")
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

/// Preview metric
/// 预览指标
struct PreviewMetric: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

/// Report history card
/// 报告历史卡片
struct ReportHistoryCard: View {
    let report: GeneratedReport
    let onView: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Report icon
            Image(systemName: report.configuration.type.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LopanColors.primary.opacity(0.1))
                )
            
            // Report info
            VStack(alignment: .leading, spacing: 4) {
                Text(report.configuration.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Text(formatDate(report.generatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(report.configuration.format.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(report.fileSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button("查看", action: onView)
                    .font(.caption)
                    .foregroundColor(LopanColors.info)
                
                Button("删除", action: onDelete)
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Generated Report View (生成报告视图)

/// View for displaying generated reports
/// 显示生成报告的视图
struct GeneratedReportView: View {
    let report: GeneratedReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Report info
                    reportInfoSection
                    
                    // Metadata
                    metadataSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("生成的报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var reportInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: report.configuration.type.icon)
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.configuration.type.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(report.fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(report.configuration.type.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("报告详情")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                MetadataRow(title: "生成时间", value: formatDate(report.generatedAt))
                MetadataRow(title: "文件大小", value: report.fileSizeFormatted)
                MetadataRow(title: "输出格式", value: report.configuration.format.displayName)
                MetadataRow(title: "时间范围", value: report.configuration.timePeriod.displayName)
                MetadataRow(title: "生成耗时", value: "\(String(format: "%.2f", report.metadata.generationDuration))秒")
                MetadataRow(title: "数据点数", value: "\(report.metadata.dataPointsIncluded)")
                MetadataRow(title: "生成者", value: report.metadata.generatedBy)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button("查看报告内容") {
                // Handle viewing report content
                // This would typically open the report in a web view or appropriate viewer
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
            
            HStack(spacing: 12) {
                Button("分享") {
                    // Handle sharing
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LopanColors.primary, lineWidth: 1)
                )
                
                Button("保存到文件") {
                    // Handle saving to files
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LopanColors.primary, lineWidth: 1)
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Metadata row
/// 元数据行
struct MetadataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}
