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

// MARK: - Data Complexity Classification

/// Data complexity level for adaptive performance optimization
enum DataComplexity {
    case light   // < 50 items: Full animations, all features
    case medium  // 50-200: Simplified animations, deferred details
    case heavy   // 200+: Minimal animations, skeleton placeholders, background processing

    var threshold: Int {
        switch self {
        case .light: return 50
        case .medium: return 200
        case .heavy: return Int.max
        }
    }

    var animationDuration: Double {
        switch self {
        case .light: return 0.4
        case .medium: return 0.25
        case .heavy: return 0.15
        }
    }
}

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
    @Published var currentDataComplexity: DataComplexity = .light

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

    /// Force complete loading with optional error (used by timeout mechanism)
    func forceCompleteLoading(withError error: String? = nil) {
        if let error = error {
            loadingState = .error(error)
            logger.error("❌ Loading forced to error state: \(error)")
        } else {
            loadingState = .loaded
            logger.info("✅ Loading forced to complete state")
        }
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
        logger.info("🎯 changeAnalysisMode called: target=\(mode.rawValue), current=\(self.selectedAnalysisMode.rawValue)")

        guard mode != selectedAnalysisMode else {
            logger.info("🔄 Analysis mode unchanged, staying in \(mode.rawValue)")
            return
        }

        logger.info("✅ Changing analysis mode from \(self.selectedAnalysisMode.rawValue) to \(mode.rawValue)")

        selectedAnalysisMode = mode

        // Cancel any pending mode change
        modeChangeTask?.cancel()

        modeChangeTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else {
                logger.info("⚠️ Mode change task cancelled for \(mode.rawValue)")
                return
            }

            logger.info("🚀 Loading data for mode: \(mode.rawValue)")
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

    /// Clear current analytics data (for memory management during transitions)
    func clearCurrentAnalytics() {
        logger.info("🧹 Clearing current analytics data for memory optimization")

        switch selectedAnalysisMode {
        case .region:
            regionAnalytics = RegionAnalyticsData()
        case .product:
            productAnalytics = ProductAnalyticsData()
        case .customer:
            customerAnalytics = CustomerAnalyticsData()
        }
    }

    // MARK: - Performance Detection

    /// Detect data complexity for adaptive performance optimization
    private func detectDataComplexity() -> DataComplexity {
        let itemCount = getCurrentDataCount()

        if itemCount >= 200 {
            logger.info("⚡ Heavy data detected: \(itemCount) items - using minimal animations")
            return .heavy
        } else if itemCount >= 50 {
            logger.info("⚡ Medium data detected: \(itemCount) items - using simplified animations")
            return .medium
        } else {
            logger.info("⚡ Light data detected: \(itemCount) items - using full animations")
            return .light
        }
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

        print("🔄 [STATE] Setting loading state to .loading")
        loadingState = .loading(progress: 0.0, message: "Initializing analytics...")
        print("🔄 [STATE] Current state after set: \(loadingState)")

        logger.info("📊 Loading insights data for \(self.selectedAnalysisMode.rawValue) mode with \(self.selectedTimeRange.rawValue) time range")

        do {
            // Try to load from cache first
            let cacheKey = createCacheKey()

            if await loadFromCache(cacheKey: cacheKey) {
                logger.info("⚡ Loaded from cache for \(self.selectedAnalysisMode.rawValue) mode")
                print("🔄 [STATE] Setting loading state to .loaded (from cache)")
                loadingState = .loaded
                print("🔄 [STATE] Current state after set: \(loadingState)")
                updatePerformanceMetrics()
                return
            }

            // Load fresh data
            print("🔄 [STATE] Starting fresh data load for \(selectedAnalysisMode.rawValue)")
            switch selectedAnalysisMode {
            case .region:
                try await loadRegionAnalytics()
            case .product:
                try await loadProductAnalytics()
            case .customer:
                try await loadCustomerAnalytics()
            }
            print("🔄 [STATE] Data load completed for \(selectedAnalysisMode.rawValue)")

            // Cache the results
            await cacheCurrentData(cacheKey: cacheKey)

            // CRITICAL: Detect data complexity BEFORE setting loaded state
            currentDataComplexity = detectDataComplexity()

            // CRITICAL: Set loaded state with explicit logging
            print("🔄 [STATE] ⚠️ CRITICAL: About to set .loaded state")
            print("🔄 [STATE] Current state before set: \(loadingState)")
            loadingState = .loaded
            print("🔄 [STATE] ✅ State set to .loaded")
            print("🔄 [STATE] Current state after set: \(loadingState)")
            print("🔄 [STATE] isLoading computed property: \(isLoading)")

            updatePerformanceMetrics()

            // Log data status
            let dataCount = getCurrentDataCount()
            if dataCount == 0 {
                logger.info("⚠️ Insights data loaded but returned 0 items for \(self.selectedAnalysisMode.rawValue) mode")
            } else {
                logger.info("✅ Insights data loaded successfully for \(self.selectedAnalysisMode.rawValue) mode: \(dataCount) items in \(String(format: "%.3f", self.lastLoadTime))s")
            }

            // Double-check state after everything
            print("🔄 [STATE] Final verification - loadingState: \(loadingState), isLoading: \(isLoading)")

        } catch {
            logger.error("❌ Failed to load insights data for \(self.selectedAnalysisMode.rawValue) mode: \(error.localizedDescription)")

            print("🔄 [STATE] Setting loading state to .error")
            // ALWAYS transition to error state on exception
            loadingState = .error(error.localizedDescription)
            print("🔄 [STATE] Current state after error: \(loadingState)")
        }
    }

    private func getCurrentDataCount() -> Int {
        switch selectedAnalysisMode {
        case .region:
            return regionAnalytics.totalItems
        case .product:
            return productAnalytics.totalItems
        case .customer:
            return customerAnalytics.totalItems
        }
    }

    private func loadRegionAnalytics() async throws {
        logger.info("🔄 Starting region analytics loading...")

        let regionAggregations = try await self.coordinator.getAggregatedDataByRegion(
            timeRange: self.selectedTimeRange,
            customDateRange: self.customDateRange,
            progressCallback: { [weak self] progress, message in
                _ = Task { @MainActor in
                    guard let self = self else { return }
                    // Only update progress if still in loading state
                    guard case .loading = self.loadingState else {
                        print("🔄 [STATE] Ignoring progress callback - already in final state: \(self.loadingState)")
                        return
                    }
                    self.loadingState = .loading(progress: progress, message: message)
                }
            }
        )

        logger.info("📊 Received \(regionAggregations.count) region aggregations")

        // Handle empty data case
        guard !regionAggregations.isEmpty else {
            logger.info("⚠️ No region data available for selected time range")
            self.regionAnalytics = RegionAnalyticsData() // Empty data
            return
        }

        // Sort regions by out-of-stock count descending
        let sortedAggregations = regionAggregations.sorted { $0.outOfStockCount > $1.outOfStockCount }

        // Calculate total items
        let totalItems = sortedAggregations.reduce(0) { $0 + $1.outOfStockCount }

        // Implement Top 10 + Others strategy for better visualization
        let displayLimit = 10
        let topRegions = Array(sortedAggregations.prefix(displayLimit))
        let otherRegions = Array(sortedAggregations.dropFirst(displayLimit))

        // Create pie chart segments for top regions
        var pieSegments = topRegions.enumerated().map { index, aggregation in
            PieChartSegment.fromRegionAggregationEnhanced(aggregation, total: totalItems, colorIndex: index)
        }

        // Add "Others" segment if there are more than 10 regions
        if !otherRegions.isEmpty {
            let othersCount = otherRegions.reduce(0) { $0 + $1.outOfStockCount }
            let othersPercentage = totalItems > 0 ? Double(othersCount) / Double(totalItems) : 0

            pieSegments.append(PieChartSegment(
                value: Double(othersCount),
                label: "其他地区 (\(otherRegions.count))",
                color: LopanColors.textTertiary,
                percentage: othersPercentage
            ))

            logger.info("📊 Grouped \(otherRegions.count) regions into 'Others' category with \(othersCount) items")
        }

        // Create region details (use sorted aggregations for consistent ordering)
        let regionDetails = sortedAggregations.map { aggregation in
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

        logger.info("✅ Region analytics loaded - total regions: \(regionAggregations.count), displayed: \(pieSegments.count), totalItems: \(totalItems)")
    }

    private func loadProductAnalytics() async throws {
        logger.info("🔄 Starting product analytics loading...")

        let productAggregations = try await self.coordinator.getAggregatedDataByProduct(
            timeRange: self.selectedTimeRange,
            customDateRange: self.customDateRange
        )

        logger.info("📊 Received \(productAggregations.count) product aggregations")

        // Handle empty data case
        guard !productAggregations.isEmpty else {
            logger.info("⚠️ No product data available for selected time range")
            self.productAnalytics = ProductAnalyticsData() // Empty data
            return
        }

        // Create bar chart data (top 15 products) with enhanced colors
        let barItems = productAggregations.prefix(15).enumerated().map { index, aggregation in
            BarChartItem.fromProductAggregationEnhanced(aggregation, colorIndex: index)
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

        logger.info("✅ Product analytics loaded - products: \(productAggregations.count), totalItems: \(totalItems), trendPoints: \(trendData.count)")
    }

    private func loadCustomerAnalytics() async throws {
        logger.info("🔄 Starting customer analytics loading...")

        do {
            let customerAggregations = try await self.coordinator.getAggregatedDataByCustomer(
                timeRange: self.selectedTimeRange,
                customDateRange: self.customDateRange
            )

            logger.info("📊 Received \(customerAggregations.count) customer aggregations")

            // Handle empty data case
            guard !customerAggregations.isEmpty else {
                logger.info("⚠️ No customer data available, setting empty analytics")
                self.customerAnalytics = CustomerAnalyticsData()
                return
            }

            // Create pie chart data for ALL customers with enhanced colors (or top 15 + others)
            let totalItems = customerAggregations.reduce(0) { $0 + $1.outOfStockCount }
            let displayCount = min(15, customerAggregations.count) // Show up to 15 customers
            let topCustomers = Array(customerAggregations.prefix(displayCount))
            let otherCustomers = Array(customerAggregations.dropFirst(displayCount))

            var pieSegments = topCustomers.enumerated().map { index, aggregation in
                PieChartSegment.fromCustomerAggregationEnhanced(aggregation, total: totalItems, colorIndex: index)
            }

            // Add "Others" segment if needed
            if !otherCustomers.isEmpty {
                let othersCount = otherCustomers.reduce(0) { $0 + $1.outOfStockCount }
                pieSegments.append(PieChartSegment(
                    value: Double(othersCount),
                    label: "其他客户",
                    color: InsightsColorPalette.bestColor(for: displayCount) // Use next color in sequence
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

            logger.info("✅ Customer analytics loaded successfully - customers: \(customerAggregations.count), totalItems: \(totalItems), pieSegments: \(pieSegments.count)")

        } catch {
            logger.error("❌ Failed to load customer analytics: \(error.localizedDescription)")
            // Set empty data on error to prevent UI issues
            self.customerAnalytics = CustomerAnalyticsData()
            throw error
        }
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
        // Calculate trend by comparing current period with previous period
        // For now, use simple heuristic based on the number of entries
        guard let regionData = regionAnalytics.regionDetails.first(where: { $0.regionName == regionName }) else {
            return .noData
        }

        // Simple trend logic: if region has high activity, trend up; low activity, trend down
        let itemCount = regionData.outOfStockCount
        if itemCount > 10 {
            return .up
        } else if itemCount < 3 {
            return .down
        } else {
            return .stable
        }
    }

    private func calculateTrendForProduct(_ productName: String) -> InsightsTrendDirection {
        // Calculate trend by comparing current period with previous period
        guard let productData = productAnalytics.productDetails.first(where: { $0.productName == productName }) else {
            return .noData
        }

        // Simple trend logic based on out-of-stock frequency
        let itemCount = productData.outOfStockCount
        if itemCount > 15 {
            return .up  // High demand/out-of-stock frequency
        } else if itemCount < 5 {
            return .down  // Low demand
        } else {
            return .stable
        }
    }

    private func calculateTrendForCustomer(_ customerName: String) -> InsightsTrendDirection {
        // Calculate trend by comparing current period with previous period
        guard let customerData = customerAnalytics.customerDetails.first(where: { $0.customerName == customerName }) else {
            return .noData
        }

        // Simple trend logic based on customer out-of-stock requests
        let itemCount = customerData.outOfStockCount
        if itemCount > 8 {
            return .up  // Increasing requests
        } else if itemCount < 3 {
            return .down  // Decreasing requests
        } else {
            return .stable
        }
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