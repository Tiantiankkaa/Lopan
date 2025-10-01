//
//  ProductInsightsView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Product-focused insights view with bar chart, line chart and detailed analysis
//

import SwiftUI
import Foundation

/// Product insights view showing distribution, trends and details by product
struct ProductInsightsView: View {

    // MARK: - Properties

    let data: ProductAnalyticsData

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedProduct: ProductDetail?
    @State private var showingProductDetails = false
    @State private var animateCharts = false
    @State private var selectedChartView: ChartViewType = .distribution

    // MARK: - Chart View Types

    enum ChartViewType: String, CaseIterable, Identifiable {
        case distribution = "distribution"
        case trends = "trends"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .distribution: return "产品分布"
            case .trends: return "趋势分析"
            }
        }

        var systemImage: String {
            switch self {
            case .distribution: return "chart.bar.fill"
            case .trends: return "chart.xyaxis.line"
            }
        }
    }

    // MARK: - Layout Constants

    private let summaryCardHeight: CGFloat = 80
    private let chartHeight: CGFloat = 280
    private let trendChartHeight: CGFloat = 200

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: LopanSpacing.contentSpacing) {
                // Chart Selection and Content
                chartSection
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
        .background(LopanColors.backgroundPrimary)
        .navigationTitle("产品分析")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            animateCharts = true
        }
        .sheet(isPresented: $showingProductDetails) {
            productDetailsSheet
        }
    }


    // MARK: - Chart Section

    private var chartSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.md) {
                // Chart Type Selector (stays static)
                HStack {
                    Text("数据可视化")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Picker("Chart Type", selection: $selectedChartView) {
                        ForEach(ChartViewType.allCases) { type in
                            HStack(spacing: LopanSpacing.xs) {
                                Image(systemName: type.systemImage)
                                    .font(.caption)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
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
        Group {
            if data.productDistribution.isEmpty && data.productTrends.isEmpty {
                emptyChartView
            } else {
                switch selectedChartView {
                case .distribution:
                    distributionChartView
                case .trends:
                    trendsChartView
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
        .animation(.easeInOut(duration: 0.3), value: selectedChartView)
    }

    private var distributionChartView: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            Text("前 10 缺货产品")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)

            EnhancedBarChart(
                data: Array(data.productDistribution.prefix(10)),
                animate: animateCharts
            )
            .frame(height: chartHeight)
        }
    }

    private var trendsChartView: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            Text("缺货趋势变化")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)

            if data.productTrends.isEmpty {
                VStack(spacing: LopanSpacing.md) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 48))
                        .foregroundColor(LopanColors.textSecondary)

                    Text("暂无趋势数据")
                        .font(.subheadline)
                        .foregroundColor(LopanColors.textSecondary)
                }
                .frame(height: trendChartHeight)
            } else {
                EnhancedLineChart(
                    data: data.productTrends,
                    animate: animateCharts
                )
                .frame(height: trendChartHeight)
            }
        }
    }


    // MARK: - Empty States

    private var emptyChartView: some View {
        VStack(spacing: LopanSpacing.md) {
            Image(systemName: "chart.bar")
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
            Image(systemName: "cube.box")
                .font(.title2)
                .foregroundColor(LopanColors.textSecondary)

            Text("暂无产品数据")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.xl)
    }

    // MARK: - Product Details Sheet

    private var productDetailsSheet: some View {
        NavigationStack {
            ProductDetailSheet(product: selectedProduct)
                .navigationTitle(selectedProduct?.productName ?? "产品详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingProductDetails = false
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

// MARK: - Product Ranking Row

private struct ProductRankingRow: View {
    let rank: Int
    let product: ProductDetail
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
                    Text(product.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(product.customersAffected) 客户受影响")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.outOfStockCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("平均 \(String(format: "%.1f", product.averageQuantity))")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }

                Image(systemName: product.trend.systemImage)
                    .font(.caption)
                    .foregroundColor(product.trend.color)
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

// MARK: - Product Details Row

private struct ProductDetailsRow: View {
    let product: ProductDetail
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(product.productName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(product.outOfStockCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 60)

                Text("\(product.customersAffected)")
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
                    .frame(width: 60)

                Text(String(format: "%.1f", product.averageQuantity))
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
                    .frame(width: 60)

                Image(systemName: product.trend.systemImage)
                    .font(.caption)
                    .foregroundColor(product.trend.color)
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



// MARK: - Product Detail Sheet

private struct ProductDetailSheet: View {
    let product: ProductDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                if let product = product {
                    // Product Header
                    VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                        Text(product.productName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("产品详情")
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
                            title: "缺货次数",
                            value: "\(product.outOfStockCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: LopanColors.warning,
                            trend: product.trend
                        )

                        SummaryCard(
                            title: "涉及客户",
                            value: "\(product.customersAffected)",
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

                        if let lastRequest = product.lastRequestDate {
                            InsightsProductDetailRow(
                                title: "最近请求",
                                value: DateFormatter.shortDateTime.string(from: lastRequest),
                                icon: "clock"
                            )
                        }

                        InsightsProductDetailRow(
                            title: "平均数量",
                            value: String(format: "%.1f", product.averageQuantity),
                            icon: "number"
                        )

                        InsightsProductDetailRow(
                            title: "趋势",
                            value: product.trend.displayName,
                            icon: product.trend.systemImage
                        )

                        if let productId = product.productId {
                            InsightsProductDetailRow(
                                title: "产品ID",
                                value: productId,
                                icon: "barcode"
                            )
                        }
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

private struct InsightsProductDetailRow: View {
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
struct ProductInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProductInsightsView(
                data: ProductAnalyticsData(
                    productDistribution: [
                        BarChartItem(category: "产品A", value: 45, color: LopanColors.primary),
                        BarChartItem(category: "产品B", value: 30, color: LopanColors.success),
                        BarChartItem(category: "产品C", value: 25, color: LopanColors.warning)
                    ],
                    productTrends: [
                        ChartDataPoint.fromDateValue(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, value: 20),
                        ChartDataPoint.fromDateValue(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, value: 25),
                        ChartDataPoint.fromDateValue(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, value: 30),
                        ChartDataPoint.fromDateValue(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, value: 28),
                        ChartDataPoint.fromDateValue(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, value: 35),
                        ChartDataPoint.fromDateValue(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 40),
                        ChartDataPoint.fromDateValue(date: Date(), value: 45)
                    ],
                    productDetails: [
                        ProductDetail(productId: "P001", productName: "产品A", outOfStockCount: 45, customersAffected: 12, lastRequestDate: Date(), trend: .up, averageQuantity: 3.5),
                        ProductDetail(productId: "P002", productName: "产品B", outOfStockCount: 30, customersAffected: 8, lastRequestDate: Date(), trend: .stable, averageQuantity: 2.8),
                        ProductDetail(productId: "P003", productName: "产品C", outOfStockCount: 25, customersAffected: 6, lastRequestDate: Date(), trend: .down, averageQuantity: 4.2)
                    ],
                    topProducts: [],
                    totalProducts: 3,
                    totalItems: 100
                )
            )
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationStack {
            ProductInsightsView(
                data: ProductAnalyticsData()
            )
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode - Empty State")
    }
}
#endif