//
//  InsightsDataModels.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Data models for Customer Out-of-Stock Insights analytics
//

import SwiftUI
import Foundation

// MARK: - Time Range Models

/// Time range options for analytics filtering
enum TimeRange: String, CaseIterable, Identifiable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case custom = "custom"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .today: return "insights_time_range_today"
        case .yesterday: return "insights_time_range_yesterday"
        case .thisWeek: return "insights_time_range_this_week"
        case .lastWeek: return "insights_time_range_last_week"
        case .thisMonth: return "insights_time_range_this_month"
        case .lastMonth: return "insights_time_range_last_month"
        case .custom: return "insights_time_range_custom"
        }
    }

    var displayName: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .custom: return "自定义"
        }
    }

    func dateRange(from referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        switch self {
        case .today:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            return (start: today, end: tomorrow)

        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            return (start: yesterday, end: today)

        case .thisWeek:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)!
            return (start: weekInterval.start, end: weekInterval.end)

        case .lastWeek:
            let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: referenceDate)!
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeekDate)!
            return (start: weekInterval.start, end: weekInterval.end)

        case .thisMonth:
            let monthInterval = calendar.dateInterval(of: .month, for: referenceDate)!
            return (start: monthInterval.start, end: monthInterval.end)

        case .lastMonth:
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: referenceDate)!
            let monthInterval = calendar.dateInterval(of: .month, for: lastMonthDate)!
            return (start: monthInterval.start, end: monthInterval.end)

        case .custom:
            // This will be overridden by custom date selection
            return (start: today, end: calendar.date(byAdding: .day, value: 1, to: today)!)
        }
    }
}

// MARK: - Analysis Mode

/// Analysis modes for different types of insights
enum AnalysisMode: String, CaseIterable, Identifiable {
    case region = "region"
    case product = "product"
    case customer = "customer"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .region: return "insights_mode_region"
        case .product: return "insights_mode_product"
        case .customer: return "insights_mode_customer"
        }
    }

    var displayName: String {
        switch self {
        case .region: return "地区分析"
        case .product: return "产品分析"
        case .customer: return "客户分析"
        }
    }

    var systemImage: String {
        switch self {
        case .region: return "map"
        case .product: return "cube.box"
        case .customer: return "person.2"
        }
    }
}

// MARK: - Region Analytics Models

/// Region-specific analytics data
struct RegionAnalyticsData {
    let regionDistribution: [PieChartSegment]
    let regionDetails: [RegionDetail]
    let totalRegions: Int
    let topRegion: RegionDetail?
    let totalItems: Int
    let averageItemsPerRegion: Double

    init(
        regionDistribution: [PieChartSegment] = [],
        regionDetails: [RegionDetail] = [],
        totalRegions: Int = 0,
        topRegion: RegionDetail? = nil,
        totalItems: Int = 0
    ) {
        self.regionDistribution = regionDistribution
        self.regionDetails = regionDetails
        self.totalRegions = totalRegions
        self.topRegion = topRegion
        self.totalItems = totalItems
        self.averageItemsPerRegion = totalRegions > 0 ? Double(totalItems) / Double(totalRegions) : 0
    }
}

/// Individual region detail
struct RegionDetail: Identifiable, Hashable {
    let id = UUID()
    let regionName: String
    let outOfStockCount: Int
    let customerCount: Int
    let percentage: Double
    let trend: InsightsTrendDirection
    let lastActivityDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RegionDetail, rhs: RegionDetail) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Product Analytics Models

/// Product-specific analytics data
struct ProductAnalyticsData {
    let productDistribution: [BarChartItem]
    let productTrends: [ChartDataPoint]
    let productDetails: [ProductDetail]
    let topProducts: [ProductDetail]
    let totalProducts: Int
    let totalItems: Int
    let averageItemsPerProduct: Double

    init(
        productDistribution: [BarChartItem] = [],
        productTrends: [ChartDataPoint] = [],
        productDetails: [ProductDetail] = [],
        topProducts: [ProductDetail] = [],
        totalProducts: Int = 0,
        totalItems: Int = 0
    ) {
        self.productDistribution = productDistribution
        self.productTrends = productTrends
        self.productDetails = productDetails
        self.topProducts = topProducts
        self.totalProducts = totalProducts
        self.totalItems = totalItems
        self.averageItemsPerProduct = totalProducts > 0 ? Double(totalItems) / Double(totalProducts) : 0
    }
}

/// Individual product detail
struct ProductDetail: Identifiable, Hashable {
    let id = UUID()
    let productId: String?
    let productName: String
    let outOfStockCount: Int
    let customersAffected: Int
    let lastRequestDate: Date?
    let trend: InsightsTrendDirection
    let averageQuantity: Double

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ProductDetail, rhs: ProductDetail) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Customer Analytics Models

/// Customer-specific analytics data
struct CustomerAnalyticsData {
    let customerDistribution: [PieChartSegment]
    let customerDetails: [CustomerDetail]
    let totalCustomers: Int
    let totalItems: Int
    let averageItemsPerCustomer: Double
    let topCustomer: CustomerDetail?

    init(
        customerDistribution: [PieChartSegment] = [],
        customerDetails: [CustomerDetail] = [],
        totalCustomers: Int = 0,
        totalItems: Int = 0,
        topCustomer: CustomerDetail? = nil
    ) {
        self.customerDistribution = customerDistribution
        self.customerDetails = customerDetails
        self.totalCustomers = totalCustomers
        self.totalItems = totalItems
        self.averageItemsPerCustomer = totalCustomers > 0 ? Double(totalItems) / Double(totalCustomers) : 0
        self.topCustomer = topCustomer
    }
}

/// Individual customer detail with expandable product list
struct CustomerDetail: Identifiable, Hashable {
    let id = UUID()
    let customerId: String?
    let customerName: String
    let customerAddress: String?
    let outOfStockCount: Int
    let productItems: [CustomerProductItem]
    let lastRequestDate: Date?
    let trend: InsightsTrendDirection

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CustomerDetail, rhs: CustomerDetail) -> Bool {
        lhs.id == rhs.id
    }
}

/// Product item within customer details
struct CustomerProductItem: Identifiable, Hashable {
    let id = UUID()
    let productName: String
    let quantity: Int
    let requestDate: Date
    let status: OutOfStockStatus

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CustomerProductItem, rhs: CustomerProductItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Trend Analysis

/// Trend direction for insights analytics
enum InsightsTrendDirection: String, CaseIterable {
    case up = "up"
    case down = "down"
    case stable = "stable"
    case noData = "no_data"

    var displayName: String {
        switch self {
        case .up: return "上升"
        case .down: return "下降"
        case .stable: return "稳定"
        case .noData: return "无数据"
        }
    }

    var color: Color {
        switch self {
        case .up: return LopanColors.success
        case .down: return LopanColors.error
        case .stable: return LopanColors.info
        case .noData: return LopanColors.textSecondary
        }
    }

    var systemImage: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .noData: return "minus"
        }
    }
}

// MARK: - Aggregation Helpers

/// Region aggregation for data processing
struct RegionAggregation {
    let regionName: String
    let items: [CustomerOutOfStock]
    let uniqueCustomers: Set<String>

    var outOfStockCount: Int { items.count }
    var customerCount: Int { uniqueCustomers.count }
}

/// Product aggregation for data processing
struct ProductAggregation {
    let productName: String
    let productId: String?
    let items: [CustomerOutOfStock]
    let uniqueCustomers: Set<String>

    var outOfStockCount: Int { items.count }
    var customersAffected: Int { uniqueCustomers.count }
    var totalQuantity: Int { items.reduce(0) { $0 + $1.quantity } }
    var averageQuantity: Double {
        items.isEmpty ? 0 : Double(totalQuantity) / Double(items.count)
    }
}

/// Customer aggregation for data processing
struct CustomerAggregation {
    let customerId: String?
    let customerName: String
    let customerAddress: String?
    let items: [CustomerOutOfStock]
    let uniqueProducts: Set<String>

    var outOfStockCount: Int { items.count }
    var productCount: Int { uniqueProducts.count }
}

// MARK: - Cache Models

/// Cache key for analytics data
struct AnalyticsCacheKey: Hashable {
    let mode: AnalysisMode
    let timeRange: TimeRange
    let customStartDate: Date?
    let customEndDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(mode)
        hasher.combine(timeRange)
        hasher.combine(customStartDate)
        hasher.combine(customEndDate)
    }

    var stringKey: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let customDateSuffix: String
        if let startDate = customStartDate,
           let endDate = customEndDate {
            customDateSuffix = "_\(dateFormatter.string(from: startDate))_\(dateFormatter.string(from: endDate))"
        } else {
            customDateSuffix = ""
        }

        return "insights_\(mode.rawValue)_\(timeRange.rawValue)\(customDateSuffix)"
    }
}

/// Cached analytics data with TTL
struct CachedAnalyticsData {
    let data: Any
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Export Models

/// Export format options for insights
enum InsightsExportFormat: String, CaseIterable, Identifiable {
    case csv = "csv"
    case pdf = "pdf"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: return "CSV 表格"
        case .pdf: return "PDF 报告"
        }
    }

    var systemImage: String {
        switch self {
        case .csv: return "tablecells"
        case .pdf: return "doc.text"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .pdf: return "pdf"
        }
    }
}

/// Export configuration for insights
struct InsightsExportConfiguration {
    let format: InsightsExportFormat
    let mode: AnalysisMode
    let timeRange: TimeRange
    let customDateRange: ClosedRange<Date>?
    let includeCharts: Bool
    let includeSummary: Bool
    let includeDetails: Bool

    init(
        format: InsightsExportFormat,
        mode: AnalysisMode,
        timeRange: TimeRange,
        customDateRange: ClosedRange<Date>? = nil,
        includeCharts: Bool = true,
        includeSummary: Bool = true,
        includeDetails: Bool = true
    ) {
        self.format = format
        self.mode = mode
        self.timeRange = timeRange
        self.customDateRange = customDateRange
        self.includeCharts = includeCharts
        self.includeSummary = includeSummary
        self.includeDetails = includeDetails
    }
}

// MARK: - Loading States

/// Loading state for insights data
enum InsightsLoadingState: Equatable {
    case idle
    case loading
    case refreshing
    case loadingMore
    case loaded
    case error(String)

    var isLoading: Bool {
        switch self {
        case .loading, .refreshing, .loadingMore:
            return true
        default:
            return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .error(let message):
            return message
        default:
            return nil
        }
    }
}

// MARK: - Extensions

extension PieChartSegment {
    /// Create from region aggregation
    static func fromRegionAggregation(_ aggregation: RegionAggregation, total: Int) -> PieChartSegment {
        return PieChartSegment(
            value: Double(aggregation.outOfStockCount),
            label: aggregation.regionName,
            color: Self.colorForIndex(aggregation.regionName.hashValue)
        )
    }

    /// Create from customer aggregation
    static func fromCustomerAggregation(_ aggregation: CustomerAggregation, total: Int) -> PieChartSegment {
        return PieChartSegment(
            value: Double(aggregation.outOfStockCount),
            label: aggregation.customerName,
            color: Self.colorForIndex(aggregation.customerName.hashValue)
        )
    }

    private static func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [
            LopanColors.primary,
            LopanColors.success,
            LopanColors.warning,
            LopanColors.error,
            LopanColors.info,
            LopanColors.accent,
            LopanColors.premium
        ]
        return colors[abs(index) % colors.count]
    }
}

extension BarChartItem {
    /// Create from product aggregation
    static func fromProductAggregation(_ aggregation: ProductAggregation) -> BarChartItem {
        return BarChartItem(
            category: aggregation.productName,
            value: Double(aggregation.outOfStockCount),
            color: Self.colorForIndex(aggregation.productName.hashValue),
            subCategory: "客户: \(aggregation.customersAffected)"
        )
    }

    private static func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [
            LopanColors.primary,
            LopanColors.success,
            LopanColors.warning,
            LopanColors.info,
            LopanColors.accent
        ]
        return colors[abs(index) % colors.count]
    }
}

extension ChartDataPoint {
    /// Create trend data point from date and value
    static func fromDateValue(date: Date, value: Double, category: String = "trend") -> ChartDataPoint {
        return ChartDataPoint(
            x: date.timeIntervalSince1970,
            y: value,
            label: DateFormatter.insightsShortDate.string(from: date),
            category: category,
            color: LopanColors.primary,
            date: date
        )
    }
}

// MARK: - Date Formatter Extensions

private extension DateFormatter {
    static let insightsShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}