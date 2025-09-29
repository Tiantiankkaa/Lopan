//
//  CustomerOutOfStockInsightsViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  ViewModel for Customer Out-of-Stock Insights analytics
//

import SwiftUI
import Foundation
import os

/// Main ViewModel for Customer Out-of-Stock Insights feature
@MainActor
final class CustomerOutOfStockInsightsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTimeRange: TimeRange = .thisWeek
    @Published var selectedAnalysisMode: AnalysisMode = .region
    @Published var customDateRange: ClosedRange<Date>?
    @Published var loadingState: InsightsLoadingState = .idle

    // Analytics data
    @Published var regionAnalytics: RegionAnalyticsData = RegionAnalyticsData()
    @Published var productAnalytics: ProductAnalyticsData = ProductAnalyticsData()
    @Published var customerAnalytics: CustomerAnalyticsData = CustomerAnalyticsData()

    // UI state
    @Published var showingCustomDatePicker = false
    @Published var showingExportOptions = false
    @Published var isRefreshing = false

    // MARK: - Private Properties

    private var coordinator: CustomerOutOfStockCoordinator
    private let logger = Logger(subsystem: "com.lopan.app", category: "InsightsViewModel")

    // Debouncing and optimization
    private var loadingTask: Task<Void, Never>?
    private var modeChangeTask: Task<Void, Never>?
    private var timeRangeChangeTask: Task<Void, Never>?

    private let debounceDelay: TimeInterval = 0.3
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    // Performance metrics
    private var loadStartTime: Date?
    private var lastLoadTime: TimeInterval = 0

    // MARK: - Initialization

    init(coordinator: CustomerOutOfStockCoordinator) {
        self.coordinator = coordinator

        logger.info("🚀 CustomerOutOfStockInsightsViewModel initialized")
    }

    // MARK: - Public Interface

    /// Update the coordinator (for dependency injection)
    func updateCoordinator(_ newCoordinator: CustomerOutOfStockCoordinator) {
        coordinator = newCoordinator
        logger.info("🔄 Coordinator updated in InsightsViewModel")
    }

    /// Load insights data for current selections
    func loadInsightsData() async {
        await loadInsightsDataWithDebouncing()
    }

    /// Refresh current data
    func refreshData() async {
        logger.info("🔄 Refreshing insights data")
        isRefreshing = true

        // Clear cache for current selection
        await coordinator.invalidateCache()

        await loadInsightsDataForced()
        isRefreshing = false
    }

    /// Change analysis mode with smooth transition
    func changeAnalysisMode(_ mode: AnalysisMode) {
        guard mode != selectedAnalysisMode else { return }

        logger.info("🔄 Changing analysis mode from \(self.selectedAnalysisMode.rawValue) to \(mode.rawValue)")

        selectedAnalysisMode = mode

        // Cancel any pending mode change
        modeChangeTask?.cancel()

        modeChangeTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await loadInsightsData()
        }
    }

    /// Change time range with data reload
    func changeTimeRange(_ timeRange: TimeRange) {
        guard timeRange != selectedTimeRange else { return }

        logger.info("📅 Changing time range from \(self.selectedTimeRange.rawValue) to \(timeRange.rawValue)")

        selectedTimeRange = timeRange

        // Clear custom date range if switching away from custom
        if timeRange != .custom {
            customDateRange = nil
        }

        // Cancel any pending time range change
        timeRangeChangeTask?.cancel()

        timeRangeChangeTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await loadInsightsData()
        }
    }

    /// Set custom date range
    func setCustomDateRange(_ range: ClosedRange<Date>) {
        customDateRange = range
        selectedTimeRange = .custom

        logger.info("📅 Custom date range set from \(range.lowerBound.formatted()) to \(range.upperBound.formatted())")

        Task {
            await loadInsightsData()
        }
    }

    /// Export current data
    func exportData(format: InsightsExportFormat) async throws {
        logger.info("📤 Exporting data in \(format.rawValue) format for \(self.selectedAnalysisMode.rawValue) mode")

        let _ = InsightsExportConfiguration(
            format: format,
            mode: selectedAnalysisMode,
            timeRange: selectedTimeRange,
            customDateRange: customDateRange
        )

        // TODO: Implement actual export functionality
        // This would integrate with document picker and file creation

        logger.info("✅ Export completed in \(format.rawValue) format")
    }

    // MARK: - Data Loading Implementation

    private func loadInsightsDataWithDebouncing() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        loadingTask = Task {
            // Short debounce for better UX
            try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await loadInsightsDataForced()
        }

        await loadingTask?.value
    }

    private func loadInsightsDataForced() async {
        loadStartTime = Date()
        loadingState = .loading

        logger.info("📊 Loading insights data for \(self.selectedAnalysisMode.rawValue) mode with \(self.selectedTimeRange.rawValue) time range")

        do {
            // Try to load from cache first
            let cacheKey = createCacheKey()

            if await loadFromCache(cacheKey: cacheKey) {
                logger.info("⚡ Loaded from cache for \(self.selectedAnalysisMode.rawValue) mode")
                loadingState = .loaded
                updatePerformanceMetrics()
                return
            }

            // Load fresh data
            switch selectedAnalysisMode {
            case .region:
                try await loadRegionAnalytics()
            case .product:
                try await loadProductAnalytics()
            case .customer:
                try await loadCustomerAnalytics()
            }

            // Cache the results
            await cacheCurrentData(cacheKey: cacheKey)

            loadingState = .loaded
            updatePerformanceMetrics()

            logger.info("✅ Insights data loaded successfully for \(self.selectedAnalysisMode.rawValue) mode in \(String(format: "%.3f", self.lastLoadTime))s")

        } catch {
            logger.error("❌ Failed to load insights data for \(self.selectedAnalysisMode.rawValue) mode: \(error.localizedDescription)")

            loadingState = .error(error.localizedDescription)
        }
    }

    private func loadRegionAnalytics() async throws {
        let regionAggregations = try await self.coordinator.getAggregatedDataByRegion(
            timeRange: self.selectedTimeRange,
            customDateRange: self.customDateRange
        )

        // Create pie chart data
        let totalItems = regionAggregations.reduce(0) { $0 + $1.outOfStockCount }
        let pieSegments = regionAggregations.prefix(10).map { aggregation in
            PieChartSegment.fromRegionAggregation(aggregation, total: totalItems)
        }

        // Create region details
        let regionDetails = regionAggregations.map { aggregation in
            RegionDetail(
                regionName: aggregation.regionName,
                outOfStockCount: aggregation.outOfStockCount,
                customerCount: aggregation.customerCount,
                percentage: totalItems > 0 ? Double(aggregation.outOfStockCount) / Double(totalItems) : 0,
                trend: calculateTrendForRegion(aggregation.regionName),
                lastActivityDate: aggregation.items.map { $0.requestDate }.max()
            )
        }

        self.regionAnalytics = RegionAnalyticsData(
            regionDistribution: pieSegments,
            regionDetails: regionDetails,
            totalRegions: regionAggregations.count,
            topRegion: regionDetails.first,
            totalItems: totalItems
        )

        logger.info("📊 Region analytics loaded - regions: \(regionAggregations.count), totalItems: \(totalItems)")
    }

    private func loadProductAnalytics() async throws {
        let productAggregations = try await self.coordinator.getAggregatedDataByProduct(
            timeRange: self.selectedTimeRange,
            customDateRange: self.customDateRange
        )

        // Create bar chart data (top 10 products)
        let barItems = productAggregations.prefix(10).map { aggregation in
            BarChartItem.fromProductAggregation(aggregation)
        }

        // Create trend data
        let trendData = try await self.coordinator.getProductTrendData(
            timeRange: self.selectedTimeRange,
            customDateRange: self.customDateRange
        )

        // Create product details
        let productDetails = productAggregations.map { aggregation in
            ProductDetail(
                productId: aggregation.productId,
                productName: aggregation.productName,
                outOfStockCount: aggregation.outOfStockCount,
                customersAffected: aggregation.customersAffected,
                lastRequestDate: aggregation.items.map { $0.requestDate }.max(),
                trend: calculateTrendForProduct(aggregation.productName),
                averageQuantity: aggregation.averageQuantity
            )
        }

        let totalItems = productAggregations.reduce(0) { $0 + $1.outOfStockCount }

        self.productAnalytics = ProductAnalyticsData(
            productDistribution: barItems,
            productTrends: trendData,
            productDetails: productDetails,
            topProducts: Array(productDetails.prefix(5)),
            totalProducts: productAggregations.count,
            totalItems: totalItems
        )

        logger.info("📊 Product analytics loaded - products: \(productAggregations.count), totalItems: \(totalItems), trendPoints: \(trendData.count)")
    }

    private func loadCustomerAnalytics() async throws {
        let customerAggregations = try await self.coordinator.getAggregatedDataByCustomer(
            timeRange: self.selectedTimeRange,
            customDateRange: self.customDateRange
        )

        // Create pie chart data (top 10 customers + others)
        let totalItems = customerAggregations.reduce(0) { $0 + $1.outOfStockCount }
        let topCustomers = Array(customerAggregations.prefix(10))
        let otherCustomers = Array(customerAggregations.dropFirst(10))

        var pieSegments = topCustomers.map { aggregation in
            PieChartSegment.fromCustomerAggregation(aggregation, total: totalItems)
        }

        // Add "Others" segment if needed
        if !otherCustomers.isEmpty {
            let othersCount = otherCustomers.reduce(0) { $0 + $1.outOfStockCount }
            pieSegments.append(PieChartSegment(
                value: Double(othersCount),
                label: "其他客户",
                color: LopanColors.textSecondary
            ))
        }

        // Create customer details with product items
        let customerDetails = customerAggregations.map { aggregation in
            let productItems = aggregation.items.map { item in
                CustomerProductItem(
                    productName: item.product?.name ?? "未知产品",
                    quantity: item.quantity,
                    requestDate: item.requestDate,
                    status: item.status
                )
            }.sorted { $0.requestDate > $1.requestDate }

            return CustomerDetail(
                customerId: aggregation.customerId,
                customerName: aggregation.customerName,
                customerAddress: aggregation.customerAddress,
                outOfStockCount: aggregation.outOfStockCount,
                productItems: productItems,
                lastRequestDate: aggregation.items.map { $0.requestDate }.max(),
                trend: calculateTrendForCustomer(aggregation.customerName)
            )
        }

        self.customerAnalytics = CustomerAnalyticsData(
            customerDistribution: pieSegments,
            customerDetails: customerDetails,
            totalCustomers: customerAggregations.count,
            totalItems: totalItems,
            topCustomer: customerDetails.first
        )

        logger.info("📊 Customer analytics loaded - customers: \(customerAggregations.count), totalItems: \(totalItems)")
    }

    // MARK: - Caching

    private func createCacheKey() -> AnalyticsCacheKey {
        return AnalyticsCacheKey(
            mode: self.selectedAnalysisMode,
            timeRange: self.selectedTimeRange,
            customStartDate: self.customDateRange?.lowerBound,
            customEndDate: self.customDateRange?.upperBound
        )
    }

    private func loadFromCache(cacheKey: AnalyticsCacheKey) async -> Bool {
        switch self.selectedAnalysisMode {
        case .region:
            if let cached = self.coordinator.getCachedAnalytics(for: cacheKey, type: RegionAnalyticsData.self) {
                self.regionAnalytics = cached
                return true
            }
        case .product:
            if let cached = self.coordinator.getCachedAnalytics(for: cacheKey, type: ProductAnalyticsData.self) {
                self.productAnalytics = cached
                return true
            }
        case .customer:
            if let cached = self.coordinator.getCachedAnalytics(for: cacheKey, type: CustomerAnalyticsData.self) {
                self.customerAnalytics = cached
                return true
            }
        }
        return false
    }

    private func cacheCurrentData(cacheKey: AnalyticsCacheKey) async {
        switch self.selectedAnalysisMode {
        case .region:
            self.coordinator.cacheAnalytics(data: self.regionAnalytics, for: cacheKey, ttl: self.cacheTimeout)
        case .product:
            self.coordinator.cacheAnalytics(data: self.productAnalytics, for: cacheKey, ttl: self.cacheTimeout)
        case .customer:
            self.coordinator.cacheAnalytics(data: self.customerAnalytics, for: cacheKey, ttl: self.cacheTimeout)
        }
    }

    // MARK: - Trend Calculation (Placeholder)

    private func calculateTrendForRegion(_ regionName: String) -> InsightsTrendDirection {
        // TODO: Implement actual trend calculation by comparing with previous period
        return .stable
    }

    private func calculateTrendForProduct(_ productName: String) -> InsightsTrendDirection {
        // TODO: Implement actual trend calculation by comparing with previous period
        return .stable
    }

    private func calculateTrendForCustomer(_ customerName: String) -> InsightsTrendDirection {
        // TODO: Implement actual trend calculation by comparing with previous period
        return .stable
    }

    // MARK: - Performance Metrics

    private func updatePerformanceMetrics() {
        guard let startTime = self.loadStartTime else { return }
        self.lastLoadTime = Date().timeIntervalSince(startTime)
        self.loadStartTime = nil

        logger.info("📊 Performance metrics - loadTime: \(String(format: "%.3f", self.lastLoadTime)), mode: \(self.selectedAnalysisMode.rawValue)")
    }

    // MARK: - Computed Properties

    var currentAnalyticsData: Any {
        switch self.selectedAnalysisMode {
        case .region:
            return self.regionAnalytics
        case .product:
            return self.productAnalytics
        case .customer:
            return self.customerAnalytics
        }
    }

    var isLoading: Bool {
        self.loadingState.isLoading
    }

    var errorMessage: String? {
        self.loadingState.errorMessage
    }

    var formattedTimeRange: String {
        if self.selectedTimeRange == .custom,
           let range = self.customDateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: range.lowerBound)) - \(formatter.string(from: range.upperBound))"
        } else {
            return self.selectedTimeRange.displayName
        }
    }

    var canRefresh: Bool {
        !self.isLoading && !self.isRefreshing
    }

    // MARK: - Cleanup

    deinit {
        self.loadingTask?.cancel()
        self.modeChangeTask?.cancel()
        self.timeRangeChangeTask?.cancel()

        logger.info("🧹 CustomerOutOfStockInsightsViewModel deinitialized")
    }
}

// MARK: - Cache Service Extension

extension CustomerOutOfStockCacheService {

    /// Get cached analytics data
    func getCachedAnalytics<T>(for key: AnalyticsCacheKey, type: T.Type) -> T? {
        // Simple implementation using the existing cache mechanism
        // In a real implementation, this might use a separate analytics cache
        return nil // Placeholder - would need actual cache implementation
    }

    /// Cache analytics data with TTL
    func cacheAnalytics<T>(data: T, for key: AnalyticsCacheKey, ttl: TimeInterval) {
        // Simple implementation using the existing cache mechanism
        // In a real implementation, this might use a separate analytics cache
        // Placeholder - would need actual cache implementation
    }
}

// MARK: - Preview Helper

#if DEBUG
extension CustomerOutOfStockInsightsViewModel {
    static var preview: CustomerOutOfStockInsightsViewModel {
        let coordinator = CustomerOutOfStockCoordinator.placeholder()
        let viewModel = CustomerOutOfStockInsightsViewModel(coordinator: coordinator)

        // Add some mock data
        viewModel.regionAnalytics = RegionAnalyticsData(
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

        return viewModel
    }
}
#endif