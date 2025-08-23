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
    
    init(x: Double, y: Double, label: String = "", category: String = "default", color: Color = .blue, date: Date? = nil) {
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
    
    init(category: String, value: Double, color: Color = .blue, subCategory: String? = nil) {
        self.category = category
        self.value = value
        self.color = color
        self.subCategory = subCategory
    }
}

// MARK: - Production Metrics Chart (生产指标图表)

/// Comprehensive production metrics visualization
/// 综合生产指标可视化
struct ProductionMetricsChart: View {
    let metrics: ProductionMetrics
    @State private var selectedMetric: MetricType = .batchCompletion
    @State private var animationProgress: Double = 0
    
    enum MetricType: String, CaseIterable {
        case batchCompletion = "batch_completion"
        case machineUtilization = "machine_utilization"
        case productivity = "productivity"
        case quality = "quality"
        case shiftComparison = "shift_comparison"
        
        var displayName: String {
            switch self {
            case .batchCompletion: return "批次完成率"
            case .machineUtilization: return "机台利用率"
            case .productivity: return "生产效率"
            case .quality: return "质量指标"
            case .shiftComparison: return "班次对比"
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
        VStack(spacing: 20) {
            // Metric selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        MetricSelectorButton(
                            metric: metric,
                            isSelected: selectedMetric == metric,
                            action: { selectedMetric = metric }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Chart content
            Group {
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
            .frame(height: 300)
            .animation(.easeInOut(duration: 0.5), value: selectedMetric)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Metric Selector Button (指标选择按钮)

struct MetricSelectorButton: View {
    let metric: ProductionMetricsChart.MetricType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.caption)
                
                Text(metric.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Specific Chart Components (具体图表组件)

/// Batch completion rate visualization
/// 批次完成率可视化
struct BatchCompletionChart: View {
    let metrics: ProductionMetrics
    
    private var chartData: [BarChartItem] {
        [
            BarChartItem(category: "已完成", value: Double(metrics.completedBatches), color: .green),
            BarChartItem(category: "执行中", value: Double(metrics.activeBatches), color: .blue),
            BarChartItem(category: "已拒绝", value: Double(metrics.rejectedBatches), color: .red)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("批次状态分布")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(String(format: "%.1f", metrics.batchCompletionRate * 100))% 完成率")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                // Fallback for iOS 15
                LegacyBarChart(data: chartData)
            }
        }
    }
}

/// Machine utilization visualization
/// 机台利用率可视化
struct MachineUtilizationChart: View {
    let metrics: ProductionMetrics
    
    private var utilizationData: [PieChartSegment] {
        let runningMachines = Double(metrics.activeMachines) * metrics.machineUtilizationRate
        let idleMachines = Double(metrics.activeMachines) - runningMachines
        let inactiveMachines = Double(metrics.totalMachines - metrics.activeMachines)
        
        return [
            PieChartSegment(value: runningMachines, label: "运行中", color: .green),
            PieChartSegment(value: idleMachines, label: "空闲", color: .orange),
            PieChartSegment(value: inactiveMachines, label: "非活跃", color: .red)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("机台利用状况")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(String(format: "%.1f", metrics.machineUtilizationRate * 100))% 利用率")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                // Pie chart
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
                
                // Legend
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(utilizationData) { segment in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 12, height: 12)
                            
                            Text(segment.label)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(Int(segment.value))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// Productivity trends visualization
/// 生产效率趋势可视化
struct ProductivityChart: View {
    let metrics: ProductionMetrics
    
    private var trendData: [ChartDataPoint] {
        guard !metrics.trendData.isEmpty else {
            return []
        }
        
        return metrics.trendData.enumerated().map { index, point in
            ChartDataPoint(
                x: Double(index),
                y: point.value,
                label: DateFormatter.shortDate.string(from: point.date),
                category: "productivity",
                color: .blue,
                date: point.date
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("生产效率趋势")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("效率指数: \(String(format: "%.1f", metrics.productivityIndex * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if #available(iOS 16.0, *), !trendData.isEmpty {
                Chart(trendData) { point in
                    LineMark(
                        x: .value("Time", point.x),
                        y: .value("Productivity", point.y)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.x),
                        y: .value("Productivity", point.y)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
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
                LegacyLineChart(data: trendData)
            }
        }
    }
}

/// Quality metrics visualization
/// 质量指标可视化
struct QualityChart: View {
    let metrics: ProductionMetrics
    
    private var qualityData: [BarChartItem] {
        let qualityPercentage = metrics.qualityScore * 100
        let defectPercentage = 100 - qualityPercentage
        
        return [
            BarChartItem(category: "合格", value: qualityPercentage, color: .green),
            BarChartItem(category: "缺陷", value: defectPercentage, color: .red)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("质量指标")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("质量评分:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", metrics.qualityScore * 100))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(metrics.qualityScore >= 0.9 ? .green : metrics.qualityScore >= 0.7 ? .orange : .red)
                }
            }
            
            VStack(spacing: 12) {
                // Quality score gauge
                QualityGauge(score: metrics.qualityScore)
                
                // Quality metrics details
                HStack(spacing: 20) {
                    QualityMetricCard(
                        title: "拒绝批次",
                        value: "\(metrics.rejectedBatches)",
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                    
                    QualityMetricCard(
                        title: "合格率",
                        value: "\(String(format: "%.1f", metrics.qualityScore * 100))%",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
        }
    }
}

/// Shift comparison visualization
/// 班次对比可视化
struct ShiftComparisonChart: View {
    let metrics: ProductionMetrics
    
    private var shiftData: [BarChartItem] {
        [
            BarChartItem(category: "早班", value: Double(metrics.morningShiftBatches), color: .orange),
            BarChartItem(category: "晚班", value: Double(metrics.eveningShiftBatches), color: .purple)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("班次对比")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                // Comparison chart
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
                
                // Shift statistics
                VStack(alignment: .leading, spacing: 12) {
                    ShiftStatCard(
                        title: "早班批次",
                        value: "\(metrics.morningShiftBatches)",
                        percentage: metrics.morningShiftBatches + metrics.eveningShiftBatches > 0 ?
                            Double(metrics.morningShiftBatches) / Double(metrics.morningShiftBatches + metrics.eveningShiftBatches) * 100 : 0,
                        color: .orange
                    )
                    
                    ShiftStatCard(
                        title: "晚班批次",
                        value: "\(metrics.eveningShiftBatches)",
                        percentage: metrics.morningShiftBatches + metrics.eveningShiftBatches > 0 ?
                            Double(metrics.eveningShiftBatches) / Double(metrics.morningShiftBatches + metrics.eveningShiftBatches) * 100 : 0,
                        color: .purple
                    )
                }
            }
        }
    }
}

// MARK: - Supporting UI Components (支持UI组件)

/// Quality score gauge
/// 质量评分仪表
struct QualityGauge: View {
    let score: Double
    @State private var animatedScore: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.tertiarySystemBackground), lineWidth: 10)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: animatedScore)
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animatedScore)
            
            // Score text
            VStack {
                Text("\(String(format: "%.1f", score * 100))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("质量评分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                animatedScore = score
            }
        }
    }
    
    private var gaugeColor: Color {
        if score >= 0.9 { return .green }
        else if score >= 0.7 { return .orange }
        else { return .red }
    }
}

/// Quality metric card
/// 质量指标卡片
struct QualityMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

/// Shift statistics card
/// 班次统计卡片
struct ShiftStatCard: View {
    let title: String
    let value: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            ProgressView(value: percentage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 0.5)
            
            Text("\(String(format: "%.1f", percentage))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Legacy Chart Components (兼容旧版本的图表组件)

/// Legacy bar chart for iOS 15 compatibility
/// iOS 15兼容的条形图
struct LegacyBarChart: View {
    let data: [BarChartItem]
    
    var body: some View {
        let maxValue = data.map { $0.value }.max() ?? 1
        
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(data) { item in
                VStack(spacing: 4) {
                    Text("\(Int(item.value))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color)
                        .frame(width: 40, height: CGFloat(item.value / maxValue * 100))
                    
                    Text(item.category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                .fill(Color(.systemBackground))
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
            .stroke(Color.blue, lineWidth: 2)
        }
        .frame(height: 200)
    }
}

// MARK: - Analytics Overview Widget (分析概览小组件)

/// Compact analytics overview for dashboard
/// 仪表板的紧凑分析概览
struct AnalyticsOverviewWidget: View {
    let metrics: ProductionMetrics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("生产概览")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatDateRange(start: metrics.startDate, end: metrics.endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                OverviewMetricCard(
                    title: "批次完成率",
                    value: "\(String(format: "%.1f", metrics.batchCompletionRate * 100))%",
                    icon: "list.clipboard.fill",
                    color: metrics.batchCompletionRate >= 0.8 ? .green : .orange
                )
                
                OverviewMetricCard(
                    title: "机台利用率",
                    value: "\(String(format: "%.1f", metrics.machineUtilizationRate * 100))%",
                    icon: "gearshape.2.fill",
                    color: metrics.machineUtilizationRate >= 0.7 ? .green : .orange
                )
                
                OverviewMetricCard(
                    title: "生产效率",
                    value: "\(String(format: "%.1f", metrics.productivityIndex * 100))%",
                    icon: "speedometer",
                    color: metrics.productivityIndex >= 0.8 ? .green : .orange
                )
                
                OverviewMetricCard(
                    title: "质量评分",
                    value: "\(String(format: "%.1f", metrics.qualityScore * 100))",
                    icon: "checkmark.seal.fill",
                    color: metrics.qualityScore >= 0.9 ? .green : .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

/// Overview metric card
/// 概览指标卡片
struct OverviewMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
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

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
}