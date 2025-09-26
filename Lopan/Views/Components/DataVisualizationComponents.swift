//
//  DataVisualizationComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import Charts

// MARK: - Chart Data Models (图表数据模型)

/// Generic chart data point
/// 通用图表数据点
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let label: String
    let category: String
    let color: Color
    let date: Date?
    
    init(x: Double, y: Double, label: String = "", category: String = "default", color: Color = LopanColors.primary, date: Date? = nil) {
        self.x = x
        self.y = y
        self.label = label
        self.category = category
        self.color = color
        self.date = date
    }
}

/// Pie chart data segment
/// 饼图数据段
struct PieChartSegment: Identifiable {
    let id = UUID()
    let value: Double
    let label: String
    let color: Color
    let percentage: Double
    
    init(value: Double, label: String, color: Color) {
        self.value = value
        self.label = label
        self.color = color
        self.percentage = 0 // Will be calculated by the chart
    }
}

/// Bar chart data item
/// 条形图数据项
struct BarChartItem: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let color: Color
    let subCategory: String?
    
    init(category: String, value: Double, color: Color = LopanColors.primary, subCategory: String? = nil) {
        self.category = category
        self.value = value
        self.color = color
        self.subCategory = subCategory
    }
}

// MARK: - Shared Analytics Surface

struct AnalyticsSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(LopanSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                    .stroke(LopanColors.border.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: LopanColors.shadow, radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if #available(iOS 26.0, *) {
            LiquidGlassMaterial(type: .card, cornerRadius: LopanCornerRadius.card)
        } else if #available(iOS 17.0, *) {
            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                .fill(.ultraThinMaterial)
        } else {
            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                .fill(LopanColors.backgroundSecondary)
        }
    }
}

@inline(__always)
private func analyticsLocalized(_ key: String) -> String {
    key.localized
}

// MARK: - Production Metrics Chart (生产指标图表)

/// Comprehensive production metrics visualization
/// 综合生产指标可视化
struct ProductionMetricsChart: View {
    let metrics: ProductionMetrics
    @State private var selectedMetric: MetricType = .batchCompletion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let chartHeight: CGFloat = 320

    enum MetricType: CaseIterable, Identifiable {
        case batchCompletion, machineUtilization, productivity, quality, shiftComparison

        var id: Self { self }

        var titleKey: LocalizedStringKey {
            switch self {
            case .batchCompletion: return "analytics_metrics_selector_batch_completion"
            case .machineUtilization: return "analytics_metrics_selector_machine_utilization"
            case .productivity: return "analytics_metrics_selector_productivity"
            case .quality: return "analytics_metrics_selector_quality"
            case .shiftComparison: return "analytics_metrics_selector_shift"
            }
        }

        var icon: String {
            switch self {
            case .batchCompletion: return "list.clipboard"
            case .machineUtilization: return "gearshape.2"
            case .productivity: return "speedometer"
            case .quality: return "checkmark.seal"
            case .shiftComparison: return "clock.arrow.2.circlepath"
            }
        }
    }

    var body: some View {
        AnalyticsSurface {
            VStack(spacing: LopanSpacing.contentSpacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LopanSpacing.sm) {
                        ForEach(MetricType.allCases) { metric in
                            MetricSelectorButton(
                                titleKey: metric.titleKey,
                                icon: metric.icon,
                                isSelected: selectedMetric == metric,
                                action: { selectedMetric = metric }
                            )
                        }
                    }
                    .padding(.vertical, LopanSpacing.xxxs)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("analytics_metrics_selector_accessibility_label"))
                .accessibilityHint(Text("analytics_metrics_selector_accessibility_hint"))

                chartContent
                    .frame(height: chartHeight)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: selectedMetric)
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch selectedMetric {
        case .batchCompletion:
            BatchCompletionChart(metrics: metrics)
        case .machineUtilization:
            MachineUtilizationChart(metrics: metrics)
        case .productivity:
            ProductivityChart(metrics: metrics)
        case .quality:
            QualityChart(metrics: metrics)
        case .shiftComparison:
            ShiftComparisonChart(metrics: metrics)
        }
    }
}

struct MetricSelectorButton: View {
    let titleKey: LocalizedStringKey
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LopanSpacing.xxxs) {
                Image(systemName: icon)
                    .font(.caption)

                Text(titleKey)
                    .font(.caption)
                    .fontWeight(.medium)
            }
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

struct BatchCompletionChart: View {
    let metrics: ProductionMetrics

    private var completionRateText: String {
        metrics.batchCompletionRate.formatted(.percent.precision(.fractionLength(1)))
    }

    private var completionDescription: String {
        String(format: analyticsLocalized("analytics_metrics_batch_completion_value"), completionRateText)
    }

    private var chartData: [BarChartItem] {
        [
            BarChartItem(category: analyticsLocalized("analytics_metrics_status_completed"), value: Double(metrics.completedBatches), color: LopanColors.success),
            BarChartItem(category: analyticsLocalized("analytics_metrics_status_in_progress"), value: Double(metrics.activeBatches), color: LopanColors.info),
            BarChartItem(category: analyticsLocalized("analytics_metrics_status_rejected"), value: Double(metrics.rejectedBatches), color: LopanColors.error)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("analytics_metrics_batch_distribution_title")
                    .font(.headline)
                    .foregroundColor(LopanColors.textPrimary)

                Spacer()

                Text(completionDescription)
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
            }

            if #available(iOS 16.0, *) {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Count", item.value)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                LegacyBarChart(data: chartData)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("analytics_metrics_batch_distribution_title"))
        .accessibilityValue(Text(completionDescription))
    }
}

struct MachineUtilizationChart: View {
    let metrics: ProductionMetrics

    private var utilizationText: String {
        metrics.machineUtilizationRate.formatted(.percent.precision(.fractionLength(1)))
    }

    private var utilizationDescription: String {
        String(format: analyticsLocalized("analytics_metrics_machine_utilization_value"), utilizationText)
    }

    private var utilizationData: [PieChartSegment] {
        let running = max(0, Double(metrics.activeMachines) * metrics.machineUtilizationRate)
        let idle = max(0, Double(metrics.activeMachines) - running)
        let inactive = max(0, Double(metrics.totalMachines - metrics.activeMachines))

        return [
            PieChartSegment(value: running, label: analyticsLocalized("analytics_metrics_machine_state_running"), color: LopanColors.success),
            PieChartSegment(value: idle, label: analyticsLocalized("analytics_metrics_machine_state_idle"), color: LopanColors.warning),
            PieChartSegment(value: inactive, label: analyticsLocalized("analytics_metrics_machine_state_inactive"), color: LopanColors.error)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("analytics_metrics_machine_overview_title")
                    .font(.headline)
                    .foregroundColor(LopanColors.textPrimary)

                Spacer()

                Text(utilizationDescription)
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
            }

            HStack(spacing: LopanSpacing.xl) {
                if #available(iOS 16.0, *) {
                    Chart(utilizationData) { segment in
                        SectorMark(
                            angle: .value("Value", segment.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(segment.color)
                    }
                    .frame(width: 150, height: 150)
                } else {
                    LegacyPieChart(data: utilizationData)
                        .frame(width: 150, height: 150)
                }

                VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                    ForEach(utilizationData) { segment in
                        HStack(spacing: LopanSpacing.xxxs) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 12, height: 12)

                            Text(segment.label)
                                .font(.caption)
                                .foregroundColor(LopanColors.textPrimary)

                            Spacer()

                            Text(Int(segment.value).formatted())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("analytics_metrics_machine_overview_title"))
        .accessibilityValue(Text(utilizationDescription))
    }
}

struct ProductivityChart: View {
    let metrics: ProductionMetrics

    private var productivityText: String {
        metrics.productivityIndex.formatted(.percent.precision(.fractionLength(1)))
    }

    private var productivityDescription: String {
        String(format: analyticsLocalized("analytics_metrics_productivity_value"), productivityText)
    }

    private var trendData: [ChartDataPoint] {
        guard !metrics.trendData.isEmpty else { return [] }

        return metrics.trendData.enumerated().map { index, point in
            ChartDataPoint(
                x: Double(index),
                y: point.value,
                label: DateFormatter.shortDate.string(from: point.date),
                category: "productivity",
                color: LopanColors.info,
                date: point.date
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("analytics_metrics_productivity_title")
                    .font(.headline)
                    .foregroundColor(LopanColors.textPrimary)

                Spacer()

                Text(productivityDescription)
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
            }

            if #available(iOS 16.0, *), !trendData.isEmpty {
                Chart(trendData) { point in
                    LineMark(
                        x: .value("Time", point.x),
                        y: .value("Productivity", point.y)
                    )
                    .foregroundStyle(LopanColors.info)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Time", point.x),
                        y: .value("Productivity", point.y)
                    )
                    .foregroundStyle(LopanColors.info.opacity(0.1))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        if let index = value.as(Double.self),
                           index < Double(trendData.count) {
                            AxisValueLabel {
                                Text(trendData[Int(index)].label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
            } else {
                Text("analytics_metrics_productivity_no_data")
                    .font(.footnote)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("analytics_metrics_productivity_title"))
        .accessibilityValue(Text(productivityDescription))
    }
}

struct QualityChart: View {
    let metrics: ProductionMetrics

    private var qualityScoreText: String {
        metrics.qualityScore.formatted(.percent.precision(.fractionLength(1)))
    }

    private var qualityScoreDescription: String {
        String(format: analyticsLocalized("analytics_metrics_quality_score_value"), qualityScoreText)
    }

    private var qualityData: [BarChartItem] {
        let qualityPercentage = metrics.qualityScore * 100
        let defectPercentage = max(0, 100 - qualityPercentage)

        return [
            BarChartItem(category: analyticsLocalized("analytics_metrics_quality_passed"), value: qualityPercentage, color: LopanColors.success),
            BarChartItem(category: analyticsLocalized("analytics_metrics_quality_defects"), value: defectPercentage, color: LopanColors.error)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("analytics_metrics_quality_title")
                    .font(.headline)
                    .foregroundColor(LopanColors.textPrimary)

                Spacer()

                Text(qualityScoreDescription)
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
            }

            VStack(spacing: LopanSpacing.md) {
                QualityGauge(score: metrics.qualityScore)

                HStack(spacing: LopanSpacing.xl) {
                    QualityMetricCard(
                        titleKey: "analytics_metrics_quality_rejected_batches",
                        valueText: metrics.rejectedBatches.formatted(),
                        icon: "xmark.circle.fill",
                        tint: LopanColors.error
                    )

                    QualityMetricCard(
                        titleKey: "analytics_metrics_quality_pass_rate",
                        valueText: qualityScoreText,
                        icon: "checkmark.circle.fill",
                        tint: LopanColors.success
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("analytics_metrics_quality_title"))
        .accessibilityValue(Text(qualityScoreDescription))
    }
}

struct ShiftComparisonChart: View {
    let metrics: ProductionMetrics

    private var totalBatches: Int {
        metrics.morningShiftBatches + metrics.eveningShiftBatches
    }

    private var morningRatio: Double {
        totalBatches > 0 ? Double(metrics.morningShiftBatches) / Double(totalBatches) : 0
    }

    private var eveningRatio: Double {
        totalBatches > 0 ? Double(metrics.eveningShiftBatches) / Double(totalBatches) : 0
    }

    private var shiftData: [BarChartItem] {
        [
            BarChartItem(category: analyticsLocalized("analytics_metrics_shift_morning"), value: Double(metrics.morningShiftBatches), color: LopanColors.warning),
            BarChartItem(category: analyticsLocalized("analytics_metrics_shift_evening"), value: Double(metrics.eveningShiftBatches), color: LopanColors.accent)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            Text("analytics_metrics_shift_title")
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)

            HStack(spacing: LopanSpacing.xl) {
                if #available(iOS 16.0, *) {
                    Chart(shiftData) { item in
                        BarMark(
                            x: .value("Shift", item.category),
                            y: .value("Batches", item.value)
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 150)
                } else {
                    LegacyBarChart(data: shiftData)
                        .frame(height: 150)
                }

                VStack(alignment: .leading, spacing: LopanSpacing.md) {
                    ShiftStatCard(
                        titleKey: "analytics_metrics_shift_morning_batches",
                        valueText: metrics.morningShiftBatches.formatted(),
                        ratio: morningRatio,
                        tint: LopanColors.warning
                    )

                    ShiftStatCard(
                        titleKey: "analytics_metrics_shift_evening_batches",
                        valueText: metrics.eveningShiftBatches.formatted(),
                        ratio: eveningRatio,
                        tint: LopanColors.accent
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("analytics_metrics_shift_title"))
    }
}

struct QualityGauge: View {
    let score: Double
    @State private var animatedScore: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scoreText: String {
        score.formatted(.percent.precision(.fractionLength(1)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(LopanColors.backgroundSecondary, lineWidth: 10)

            Circle()
                .trim(from: 0, to: animatedScore)
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: LopanSpacing.xxxs) {
                Text(scoreText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)

                Text("analytics_metrics_quality_gauge_label")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .frame(width: 120, height: 120)
        .onAppear {
            if reduceMotion {
                animatedScore = score
            } else {
                withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                    animatedScore = score
                }
            }
        }
    }

    private var gaugeColor: Color {
        if score >= 0.9 { return LopanColors.success }
        else if score >= 0.7 { return LopanColors.warning }
        else { return LopanColors.error }
    }
}

struct QualityMetricCard: View {
    let titleKey: LocalizedStringKey
    let valueText: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: LopanSpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(tint)

            Text(valueText)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.textPrimary)

            Text(titleKey)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(LopanSpacing.cardPadding)
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
        .accessibilityValue(Text(valueText))
    }
}

struct ShiftStatCard: View {
    let titleKey: LocalizedStringKey
    let valueText: String
    let ratio: Double
    let tint: Color

    private var percentageText: String {
        ratio.formatted(.percent.precision(.fractionLength(1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xxxs) {
            HStack {
                Text(titleKey)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)

                Spacer()

                Text(valueText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(tint)
            }

            Text(String(format: analyticsLocalized("analytics_metrics_shift_percentage"), percentageText))
                .font(.caption2)
                .foregroundColor(LopanColors.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: analyticsLocalized("analytics_metrics_shift_stat_accessibility"), valueText, percentageText)))
    }
}

struct AnalyticsOverviewWidget: View {
    let metrics: ProductionMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: LopanSpacing.gridSpacing),
        GridItem(.flexible(), spacing: LopanSpacing.gridSpacing)
    ]

    var body: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("analytics_overview_title")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                        .accessibilityLabel(Text("analytics_overview_date_range_accessibility"))
                        .accessibilityValue(Text(dateRangeText))
                }

                LazyVGrid(columns: columns, spacing: LopanSpacing.gridSpacing) {
                    ForEach(metricItems) { item in
                        AnalyticsOverviewMetricCard(item: item, reduceMotion: reduceMotion)
                    }
                }
            }
        }
    }

    private var metricItems: [AnalyticsOverviewMetricItem] {
        [
            AnalyticsOverviewMetricItem(
                titleKey: "analytics_overview_metric_batch_completion",
                valueText: metrics.batchCompletionRate.formatted(.percent.precision(.fractionLength(1))),
                numericValue: metrics.batchCompletionRate,
                icon: "list.clipboard.fill",
                tint: LopanColors.success
            ),
            AnalyticsOverviewMetricItem(
                titleKey: "analytics_overview_metric_machine_utilization",
                valueText: metrics.machineUtilizationRate.formatted(.percent.precision(.fractionLength(1))),
                numericValue: metrics.machineUtilizationRate,
                icon: "gearshape.2.fill",
                tint: LopanColors.info
            ),
            AnalyticsOverviewMetricItem(
                titleKey: "analytics_overview_metric_productivity",
                valueText: metrics.productivityIndex.formatted(.percent.precision(.fractionLength(1))),
                numericValue: metrics.productivityIndex,
                icon: "speedometer",
                tint: LopanColors.accent
            ),
            AnalyticsOverviewMetricItem(
                titleKey: "analytics_overview_metric_quality",
                valueText: metrics.qualityScore.formatted(.percent.precision(.fractionLength(1))),
                numericValue: metrics.qualityScore,
                icon: "checkmark.seal.fill",
                tint: LopanColors.success
            )
        ]
    }

    private var dateRangeText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: metrics.startDate, to: metrics.endDate)
    }
}

private struct AnalyticsOverviewMetricItem: Identifiable {
    let id = UUID()
    let titleKey: LocalizedStringKey
    let valueText: String
    let numericValue: Double
    let icon: String
    let tint: Color
}

private struct AnalyticsOverviewMetricCard: View {
    let item: AnalyticsOverviewMetricItem
    let reduceMotion: Bool
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            Image(systemName: item.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(item.tint)
                .accessibilityHidden(true)

            valueView
                .foregroundColor(LopanColors.textPrimary)

            Text(item.titleKey)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
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
        .accessibilityLabel(Text(item.titleKey))
        .accessibilityValue(Text(item.valueText))
    }

    @ViewBuilder
    private var valueView: some View {
        if #available(iOS 17.0, *) {
            Text(item.valueText)
                .font(.title2)
                .fontWeight(.bold)
                .contentTransition(.numericText(value: item.numericValue))
                .transaction { transaction in
                    transaction.animation = reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                }
        } else {
            Text(item.valueText)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
}
/// Legacy bar chart for iOS 15 compatibility
/// iOS 15兼容的柱状图
struct LegacyBarChart: View {
    let data: [BarChartItem]

    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.value }.max() ?? 1
            let availableHeight = max(0, geometry.size.height - 40)

            HStack(alignment: .bottom, spacing: LopanSpacing.sm) {
                ForEach(data) { item in
                    VStack(spacing: LopanSpacing.xxxs) {
                        Text(Int(item.value).formatted())
                            .font(.caption2)
                            .foregroundColor(LopanColors.textSecondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color)
                            .frame(height: maxValue <= 0 ? 0 : CGFloat(item.value / maxValue) * availableHeight)

                        Text(item.category)
                            .font(.caption2)
                            .foregroundColor(LopanColors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: geometry.size.height, alignment: .bottom)
        }
        .frame(height: 200)
    }
}

/// Legacy pie chart for iOS 15 compatibility
/// iOS 15兼容的饼图
struct LegacyPieChart: View {
    let data: [PieChartSegment]
    
    var body: some View {
        let total = data.reduce(0) { $0 + $1.value }
        var currentAngle: Double = 0
        
        ZStack {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, segment in
                let angle = (segment.value / total) * 360
                
                Path { path in
                    let center = CGPoint(x: 75, y: 75)
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: 60,
                        startAngle: .degrees(currentAngle),
                        endAngle: .degrees(currentAngle + angle),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .fill(segment.color)
                .onAppear {
                    currentAngle += angle
                }
            }
            
            Circle()
                .fill(LopanColors.background)
                .frame(width: 60, height: 60)
        }
    }
}

/// Legacy line chart for iOS 15 compatibility
/// iOS 15兼容的折线图
struct LegacyLineChart: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        GeometryReader { geometry in
            let maxY = data.map { $0.y }.max() ?? 1
            let minY = data.map { $0.y }.min() ?? 0
            let range = maxY - minY
            
            Path { path in
                guard let firstPoint = data.first else { return }
                
                let startX = 0.0
                let startY = geometry.size.height - CGFloat((firstPoint.y - minY) / range) * geometry.size.height
                path.move(to: CGPoint(x: startX, y: startY))
                
                for (index, point) in data.enumerated() {
                    let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                    let y = geometry.size.height - CGFloat((point.y - minY) / range) * geometry.size.height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(LopanColors.info, lineWidth: 2)
        }
        .frame(height: 200)
    }
}

// MARK: - Analytics Overview Widget (分析概览小组件)

/// Compact analytics overview for dashboard
/// 仪表板的紧凑分析概览
// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
}
