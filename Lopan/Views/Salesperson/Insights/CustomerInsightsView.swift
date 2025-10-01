//
//  CustomerInsightsView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Customer-focused insights view with pie chart and expandable customer list
//

import SwiftUI
import Foundation

/// Customer insights view showing distribution and expandable details by customer
struct CustomerInsightsView: View {

    // MARK: - Properties

    let data: CustomerAnalyticsData

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedCustomer: CustomerDetail?
    @State private var showingCustomerDetails = false
    @State private var animateCharts = false
    @State private var expandedCustomers: Set<UUID> = []
    @State private var searchText = ""
    @State private var selectedChartType: ChartType = .donut
    @State private var selectedSegment: PieChartSegment?

    // MARK: - Layout Constants

    private let summaryCardHeight: CGFloat = 80
    private let chartHeight: CGFloat = 250

    // MARK: - Computed Properties

    private var filteredCustomers: [CustomerDetail] {
        if searchText.isEmpty {
            return data.customerDetails
        } else {
            return data.customerDetails.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText) ||
                ($0.customerAddress?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
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
        .navigationTitle("客户分析")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索客户...")
        .onAppear {
            animateCharts = true
        }
        .sheet(isPresented: $showingCustomerDetails) {
            customerDetailsSheet
        }
    }



    // MARK: - Pie Chart Section

    private var pieChartSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.md) {
                // Header with chart type selector (stays static)
                VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                    Text("客户分布")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)

                    ChartTypeSelector.forAnalysisMode(
                        .customer,
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
            if data.customerDistribution.isEmpty {
                emptyChartView
            } else {
                VStack(spacing: LopanSpacing.md) {
                    // Stats Card (for donut chart only)
                    if selectedChartType == .donut {
                        DonutChartStatsCard(
                            totalValue: totalValue,
                            selectedSegment: selectedSegment,
                            totalLabel: "总计",
                            itemCount: data.customerDistribution.count
                        )
                    }

                    // Dynamic Chart based on selection
                    customerChartView
                        .frame(height: chartHeight * 0.7)

                    // Legend
                    pieChartLegend
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
    private var customerChartView: some View {
        switch selectedChartType {
        case .donut:
            EnhancedDonutChart(
                data: data.customerDistribution,
                animate: animateCharts,
                showCenterContent: false,
                selectedSegment: $selectedSegment
            )
        case .horizontalBar:
            EnhancedHorizontalBarChart(
                data: data.customerDistribution.map { segment in
                    BarChartItem(
                        category: segment.label,
                        value: segment.value,
                        color: segment.color
                    )
                },
                animate: animateCharts,
                maxHeight: 250
            )
        default:
            // Fallback to donut chart
            EnhancedDonutChart(
                data: data.customerDistribution,
                animate: animateCharts,
                showCenterContent: false,
                selectedSegment: $selectedSegment
            )
        }
    }

    private var pieChartLegend: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("客户分布详情")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textSecondary)

                Spacer()

                Text("共 \(data.customerDistribution.count) 个客户")
                    .font(.caption)
                    .foregroundColor(LopanColors.textTertiary)
            }

            if data.customerDistribution.count <= 8 {
                // Use grid layout for smaller number of customers
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: LopanSpacing.xs
                ) {
                    ForEach(data.customerDistribution, id: \.id) { segment in
                        customerLegendItem(segment)
                    }
                }
            } else {
                // Use scrollable list for many customers
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: LopanSpacing.xs) {
                        ForEach(data.customerDistribution, id: \.id) { segment in
                            customerLegendItem(segment)
                        }
                    }
                }
                .frame(maxHeight: 200) // Limit height when many customers
            }
        }
    }

    @ViewBuilder
    private func customerLegendItem(_ segment: PieChartSegment) -> some View {
        HStack(spacing: LopanSpacing.xs) {
            Circle()
                .fill(segment.color)
                .frame(width: 10, height: 10)

            Text(segment.label)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(segment.value))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(String(format: "%.0f%%", segment.percentage * 100))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .padding(.horizontal, LopanSpacing.xs)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.xs)
                .fill(segment.color.opacity(0.05))
        )
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
            Image(systemName: "person.2")
                .font(.title2)
                .foregroundColor(LopanColors.textSecondary)

            Text("暂无客户数据")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.xl)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: LopanSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(LopanColors.textSecondary)

            Text("未找到匹配的客户")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)

            Text("尝试其他搜索关键词")
                .font(.caption)
                .foregroundColor(LopanColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.xl)
    }

    // MARK: - Customer Details Sheet

    private var customerDetailsSheet: some View {
        NavigationStack {
            CustomerDetailSheet(customer: selectedCustomer)
                .navigationTitle(selectedCustomer?.customerName ?? "客户详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingCustomerDetails = false
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helper Methods

    private func calculateContentHeight() -> CGFloat {
        return chartHeight + LopanSpacing.contentSpacing + 200 // Base height for top customers
    }

    private var totalValue: Int {
        Int(data.customerDistribution.reduce(0) { $0 + $1.value })
    }

    private func toggleCustomerExpansion(_ customerId: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedCustomers.contains(customerId) {
                expandedCustomers.remove(customerId)
            } else {
                expandedCustomers.insert(customerId)
            }
        }
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

// MARK: - Customer Ranking Row

private struct CustomerRankingRow: View {
    let rank: Int
    let customer: CustomerDetail
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
                    Text(customer.customerName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let address = customer.customerAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(customer.outOfStockCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("\(customer.productItems.count) 产品")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }

                Image(systemName: customer.trend.systemImage)
                    .font(.caption)
                    .foregroundColor(customer.trend.color)
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

// MARK: - Expandable Customer Row

private struct ExpandableCustomerRow: View {
    let customer: CustomerDetail
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onTapCustomer: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main Customer Row
            Button(action: onToggleExpansion) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.customerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let address = customer.customerAddress {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(customer.outOfStockCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("\(customer.productItems.count) 产品")
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                    }

                    Button(action: onTapCustomer) {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(LopanColors.primary)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, LopanSpacing.sm)
                .padding(.vertical, LopanSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                        .fill(isExpanded ? LopanColors.primary.opacity(0.05) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            // Expanded Product List
            if isExpanded {
                VStack(spacing: LopanSpacing.xs) {
                    ForEach(customer.productItems, id: \.id) { productItem in
                        ProductItemRow(productItem: productItem)
                    }
                }
                .padding(.horizontal, LopanSpacing.lg)
                .padding(.vertical, LopanSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                        .fill(LopanColors.backgroundSecondary.opacity(0.3))
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .overlay(
            Rectangle()
                .fill(LopanColors.border.opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Product Item Row

private struct ProductItemRow: View {
    let productItem: CustomerProductItem

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(productItem.productName)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            Text("数量: \(productItem.quantity)")
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)

            Text(productItem.requestDate, style: .date)
                .font(.caption2)
                .foregroundColor(LopanColors.textTertiary)
        }
        .padding(.horizontal, LopanSpacing.sm)
        .padding(.vertical, LopanSpacing.xs)
    }

    private var statusColor: Color {
        switch productItem.status {
        case .pending: return LopanColors.warning
        case .completed: return LopanColors.success
        case .returned: return LopanColors.error
        }
    }
}


// MARK: - Customer Detail Sheet

private struct CustomerDetailSheet: View {
    let customer: CustomerDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                if let customer = customer {
                    // Customer Header
                    VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                        Text(customer.customerName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if let address = customer.customerAddress {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(LopanColors.textSecondary)
                        }

                        Text("客户详情")
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
                            value: "\(customer.outOfStockCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: LopanColors.warning,
                            trend: customer.trend
                        )

                        SummaryCard(
                            title: "涉及产品",
                            value: "\(customer.productItems.count)",
                            icon: "cube.box.fill",
                            color: LopanColors.primary,
                            trend: nil
                        )
                    }

                    // Product List
                    VStack(alignment: .leading, spacing: LopanSpacing.md) {
                        Text("产品清单")
                            .font(.headline)
                            .fontWeight(.semibold)

                        LazyVStack(spacing: LopanSpacing.sm) {
                            ForEach(customer.productItems, id: \.id) { productItem in
                                DetailedProductItemRow(productItem: productItem)
                            }
                        }
                    }

                    // Additional Details
                    VStack(alignment: .leading, spacing: LopanSpacing.md) {
                        Text("其他信息")
                            .font(.headline)
                            .fontWeight(.semibold)

                        if let lastRequest = customer.lastRequestDate {
                            InsightsCustomerDetailRow(
                                title: "最近请求",
                                value: DateFormatter.shortDateTime.string(from: lastRequest),
                                icon: "clock"
                            )
                        }

                        InsightsCustomerDetailRow(
                            title: "趋势",
                            value: customer.trend.displayName,
                            icon: customer.trend.systemImage
                        )

                        if let customerId = customer.customerId {
                            InsightsCustomerDetailRow(
                                title: "客户ID",
                                value: customerId,
                                icon: "person.text.rectangle"
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

private struct DetailedProductItemRow: View {
    let productItem: CustomerProductItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(productItem.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack {
                    Text("数量: \(productItem.quantity)")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(LopanColors.textTertiary)

                    Text(productItem.requestDate, style: .date)
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(LopanCornerRadius.sm)
            }
        }
        .padding(.horizontal, LopanSpacing.sm)
        .padding(.vertical, LopanSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                .fill(LopanColors.backgroundSecondary.opacity(0.3))
        )
    }

    private var statusColor: Color {
        switch productItem.status {
        case .pending: return LopanColors.warning
        case .completed: return LopanColors.success
        case .returned: return LopanColors.error
        }
    }

    private var statusText: String {
        switch productItem.status {
        case .pending: return "待处理"
        case .completed: return "已完成"
        case .returned: return "已退货"
        }
    }
}

private struct InsightsCustomerDetailRow: View {
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
struct CustomerInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CustomerInsightsView(
                data: CustomerAnalyticsData(
                    customerDistribution: [
                        PieChartSegment(value: 15, label: "客户A", color: LopanColors.primary),
                        PieChartSegment(value: 12, label: "客户B", color: LopanColors.success),
                        PieChartSegment(value: 10, label: "客户C", color: LopanColors.warning),
                        PieChartSegment(value: 8, label: "其他客户", color: LopanColors.textSecondary)
                    ],
                    customerDetails: [
                        CustomerDetail(
                            customerId: "C001",
                            customerName: "客户A",
                            customerAddress: "上海市浦东新区",
                            outOfStockCount: 15,
                            productItems: [
                                CustomerProductItem(productName: "产品1", quantity: 5, requestDate: Date(), status: .pending),
                                CustomerProductItem(productName: "产品2", quantity: 10, requestDate: Date(), status: .completed)
                            ],
                            lastRequestDate: Date(),
                            trend: .up
                        ),
                        CustomerDetail(
                            customerId: "C002",
                            customerName: "客户B",
                            customerAddress: "北京市朝阳区",
                            outOfStockCount: 12,
                            productItems: [
                                CustomerProductItem(productName: "产品3", quantity: 12, requestDate: Date(), status: .pending)
                            ],
                            lastRequestDate: Date(),
                            trend: .stable
                        )
                    ],
                    totalCustomers: 2,
                    totalItems: 27,
                    topCustomer: nil
                )
            )
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        NavigationStack {
            CustomerInsightsView(
                data: CustomerAnalyticsData()
            )
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode - Empty State")
    }
}
#endif