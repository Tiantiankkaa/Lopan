//
//  RegionInsightsView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Region-focused insights view with pie chart and detailed table
//

import SwiftUI
import Foundation

/// Region insights view showing distribution and details by region
struct RegionInsightsView: View {

    // MARK: - Properties

    let data: RegionAnalyticsData

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedRegion: RegionDetail?
    @State private var showingRegionDetails = false
    @State private var animateCharts = false
    @State private var selectedChartType: ChartType = .donut
    @State private var selectedSegment: PieChartSegment?

    // MARK: - Layout Constants

    private let summaryCardHeight: CGFloat = 80
    private let minChartWidth: CGFloat = 200

    // Adaptive chart height based on data count
    private var chartHeight: CGFloat {
        let itemCount = data.regionDistribution.count
        if itemCount <= 6 {
            return 280  // Compact for small datasets
        } else if itemCount <= 10 {
            return 400  // Medium for moderate datasets
        } else {
            return 450  // Large for 10+ (Top 10 + Others)
        }
    }

    // Maximum height for bar chart component
    private var barChartMaxHeight: CGFloat {
        let itemCount = data.regionDistribution.count
        if itemCount <= 6 {
            return 300
        } else if itemCount <= 10 {
            return 450
        } else {
            return 500  // Extra space for Top 10 + Others
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: LopanSpacing.contentSpacing) {
                // Pie Chart Section
                pieChartSection
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .background(LopanColors.backgroundPrimary)
        .navigationTitle("地区分析")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            animateCharts = true
        }
        .sheet(isPresented: $showingRegionDetails) {
            regionDetailsSheet
        }
    }



    // MARK: - Pie Chart Section

    private var pieChartSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.md) {
                // Header with chart type selector (stays static)
                VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                    Text("地区分布")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)

                    ChartTypeSelector.forAnalysisMode(
                        .region,
                        selectedType: $selectedChartType,
                        style: .pills
                    )
                }

                // Chart content with smooth transition
                chartContentView
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.4) : .spring(response: 0.55, dampingFraction: 0.75),
            value: data.dataChangeID
        )
    }

    @ViewBuilder
    private var chartContentView: some View {
        ZStack {
            if data.regionDistribution.isEmpty {
                emptyChartView
            } else {
                VStack(spacing: LopanSpacing.md) {
                    // Stats Card (for donut chart only)
                    if selectedChartType == .donut {
                        DonutChartStatsCard(
                            totalValue: totalValue,
                            selectedSegment: selectedSegment,
                            itemCount: data.regionDistribution.count
                        )
                    }

                    // Dynamic Chart based on selection
                    chartView
                        .frame(height: selectedChartType == .donut ? chartHeight * 0.7 : chartHeight * 0.85)
                }
            }
        }
        .transition(
            reduceMotion ? .opacity : .asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .scale(scale: 1.15).combined(with: .opacity)
            )
        )
        .id(data.dataChangeID)
    }

    @ViewBuilder
    private var chartView: some View {
        switch selectedChartType {
        case .donut:
            EnhancedDonutChart(
                data: data.regionDistribution,
                animate: animateCharts,
                showCenterContent: false,
                selectedSegment: $selectedSegment
            )
        case .horizontalBar:
            EnhancedHorizontalBarChart(
                data: data.regionDistribution.map { segment in
                    BarChartItem(
                        category: segment.label,
                        value: segment.value,
                        color: segment.color
                    )
                },
                animate: animateCharts,
                maxHeight: barChartMaxHeight
            )
        default:
            // Fallback to donut chart
            EnhancedDonutChart(
                data: data.regionDistribution,
                animate: animateCharts,
                showCenterContent: false,
                selectedSegment: $selectedSegment
            )
        }
    }

    // MARK: - Empty States

    private var emptyChartView: some View {
        VStack(spacing: LopanSpacing.md) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(LopanColors.textSecondary)

            Text("暂无数据")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(height: chartHeight)
    }

    private var emptyDataView: some View {
        VStack(spacing: LopanSpacing.sm) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundColor(LopanColors.textSecondary)

            Text("暂无地区数据")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.xl)
    }

    // MARK: - Region Details Sheet

    private var regionDetailsSheet: some View {
        NavigationStack {
            RegionDetailSheet(region: selectedRegion)
                .navigationTitle(selectedRegion?.regionName ?? "地区详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingRegionDetails = false
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helper Methods

    private func calculateContentHeight() -> CGFloat {
        // Calculate dynamic height based on content and screen size
        return chartHeight + LopanSpacing.contentSpacing + 200 // Base height for top regions
    }

    private var totalValue: Int {
        Int(data.regionDistribution.reduce(0) { $0 + $1.value })
    }

}

// MARK: - Summary Card Component

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: InsightsTrendDirection?

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Spacer()

                if let trend = trend {
                    Image(systemName: trend.systemImage)
                        .font(.caption)
                        .foregroundColor(trend.color)
                }
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                .lineLimit(1)
        }
        .padding(LopanSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Region Ranking Row

private struct RegionRankingRow: View {
    let rank: Int
    let region: RegionDetail
    let totalItems: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LopanSpacing.sm) {
                // Rank Badge
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(rankColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(region.regionName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(region.customerCount) 客户")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(region.outOfStockCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(String(format: "%.0f%%", region.percentage * 100))
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }

                Image(systemName: region.trend.systemImage)
                    .font(.caption)
                    .foregroundColor(region.trend.color)
                    .frame(width: 16)
            }
            .padding(.horizontal, LopanSpacing.sm)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                    .fill(LopanColors.backgroundSecondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return LopanColors.warning // Gold
        case 2: return LopanColors.textSecondary // Silver
        case 3: return LopanColors.accent // Bronze
        default: return LopanColors.primary
        }
    }
}

// MARK: - Region Details Row

private struct RegionDetailsRow: View {
    let region: RegionDetail
    let totalItems: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(region.regionName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(region.outOfStockCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 60)

                Text("\(region.customerCount)")
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
                    .frame(width: 60)

                Text(String(format: "%.0f%%", region.percentage * 100))
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
                    .frame(width: 50)

                Image(systemName: region.trend.systemImage)
                    .font(.caption)
                    .foregroundColor(region.trend.color)
                    .frame(width: 40)
            }
            .padding(.horizontal, LopanSpacing.sm)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                    .fill(Color.clear)
            )
            .overlay(
                Rectangle()
                    .fill(LopanColors.border.opacity(0.3))
                    .frame(height: 0.5),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Region Detail Sheet

private struct RegionDetailSheet: View {
    let region: RegionDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                if let region = region {
                    // Region Header
                    VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                        Text(region.regionName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("地区概览")
                            .font(.headline)
                            .foregroundColor(LopanColors.textSecondary)
                    }

                    // Statistics Cards
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: LopanSpacing.md
                    ) {
                        SummaryCard(
                            title: "缺货总数",
                            value: "\(region.outOfStockCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: LopanColors.warning,
                            trend: region.trend
                        )

                        SummaryCard(
                            title: "涉及客户",
                            value: "\(region.customerCount)",
                            icon: "person.2.fill",
                            color: LopanColors.primary,
                            trend: nil
                        )
                    }

                    // Additional Details
                    VStack(alignment: .leading, spacing: LopanSpacing.md) {
                        Text("详细信息")
                            .font(.headline)
                            .fontWeight(.semibold)

                        if let lastActivity = region.lastActivityDate {
                            InsightsRegionDetailRow(
                                title: "最近活动",
                                value: DateFormatter.shortDateTime.string(from: lastActivity),
                                icon: "clock"
                            )
                        }

                        InsightsRegionDetailRow(
                            title: "占比",
                            value: String(format: "%.0f%%", region.percentage * 100),
                            icon: "chart.pie"
                        )

                        InsightsRegionDetailRow(
                            title: "趋势",
                            value: region.trend.displayName,
                            icon: region.trend.systemImage
                        )
                    }

                    Spacer()
                } else {
                    Text("数据加载中...")
                        .foregroundColor(LopanColors.textSecondary)
                }
            }
            .padding(LopanSpacing.screenPadding)
        }
    }
}

private struct InsightsRegionDetailRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(LopanColors.primary)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, LopanSpacing.xs)
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
struct RegionInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RegionInsightsView(
                data: RegionAnalyticsData(
                    regionDistribution: [
                        PieChartSegment(value: 45, label: "上海", color: LopanColors.primary),
                        PieChartSegment(value: 30, label: "北京", color: LopanColors.success),
                        PieChartSegment(value: 25, label: "广州", color: LopanColors.warning)
                    ],
                    regionDetails: [
                        RegionDetail(regionName: "上海", outOfStockCount: 45, customerCount: 12, percentage: 0.45, trend: .up, lastActivityDate: Date()),
                        RegionDetail(regionName: "北京", outOfStockCount: 30, customerCount: 8, percentage: 0.30, trend: .stable, lastActivityDate: Date()),
                        RegionDetail(regionName: "广州", outOfStockCount: 25, customerCount: 6, percentage: 0.25, trend: .down, lastActivityDate: Date())
                    ],
                    totalRegions: 3,
                    topRegion: nil,
                    totalItems: 100
                )
            )
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationStack {
            RegionInsightsView(
                data: RegionAnalyticsData()
            )
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode - Empty State")
    }
}
#endif