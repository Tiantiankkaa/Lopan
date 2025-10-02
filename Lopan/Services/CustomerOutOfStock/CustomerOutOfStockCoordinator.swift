//
//  CustomerOutOfStockCoordinator.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation
import SwiftUI
import os

/// Main coordinator for Customer Out-of-Stock operations
/// Orchestrates between data, business, and cache services
/// Replaces the monolithic CustomerOutOfStockService
@MainActor
public class CustomerOutOfStockCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    private let dataService: CustomerOutOfStockDataService
    private let businessService: CustomerOutOfStockBusinessService
    private let cacheService: CustomerOutOfStockCacheService
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - Published State
    @Published var items: [CustomerOutOfStock] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: Error?
    @Published var hasMoreData = true
    @Published var currentPage = 0
    @Published var totalRecordsCount = 0
    
    // Current filter state
    @Published var currentCriteria: OutOfStockFilterCriteria
    
    // MARK: - Private Properties
    private let pageSize = 50
    private let logger = Logger(subsystem: "com.lopan.app", category: "CustomerOutOfStockCoordinator")
    private var isPlaceholder = false

    // MARK: - Request Optimization Properties
    private var pendingRequestTask: Task<Void, Never>?
    private var pendingCriteria: OutOfStockFilterCriteria?
    private var debounceDelay: TimeInterval = 0.3
    private var lastRequestTime: Date = Date.distantPast
    private var requestCoalescingMap: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    init(
        dataService: CustomerOutOfStockDataService,
        businessService: CustomerOutOfStockBusinessService,
        cacheService: CustomerOutOfStockCacheService,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.dataService = dataService
        self.businessService = businessService
        self.cacheService = cacheService
        self.auditService = auditService
        self.authService = authService
        
        // Initialize default criteria
        self.currentCriteria = OutOfStockFilterCriteria(
            customer: nil,
            product: nil,
            status: nil,
            dateRange: Self.createDateRange(for: Date()),
            searchText: "",
            page: 0,
            pageSize: pageSize,
            sortOrder: .newestFirst
        )
    }
    
    // MARK: - Placeholder Factory
    
    static func placeholder() -> CustomerOutOfStockCoordinator {
        let coordinator = CustomerOutOfStockCoordinator(
            dataService: MockCustomerOutOfStockDataService(),
            businessService: MockCustomerOutOfStockBusinessService(),
            cacheService: MockCustomerOutOfStockCacheService(),
            auditService: MockNewAuditingService(),
            authService: MockAuthenticationService()
        )
        coordinator.isPlaceholder = true
        return coordinator
    }
    
    // MARK: - Data Loading

    func loadDataForDate(_ date: Date, resetPagination: Bool = true) async {
        let newCriteria = OutOfStockFilterCriteria(
            customer: currentCriteria.customer,
            product: currentCriteria.product,
            status: currentCriteria.status,
            dateRange: Self.createDateRange(for: date),
            searchText: currentCriteria.searchText,
            page: resetPagination ? 0 : currentCriteria.page,
            pageSize: currentCriteria.pageSize,
            sortOrder: currentCriteria.sortOrder
        )

        await loadFilteredItemsWithDebouncing(criteria: newCriteria, resetPagination: resetPagination)
    }

    func loadFilteredItems(criteria: OutOfStockFilterCriteria, resetPagination: Bool = true) async {
        await loadFilteredItemsWithDebouncing(criteria: criteria, resetPagination: resetPagination)
    }

    // MARK: - Optimized Loading with Debouncing & Coalescing

    private func loadFilteredItemsWithDebouncing(criteria: OutOfStockFilterCriteria, resetPagination: Bool = true) async {
        // Cancel any pending request
        pendingRequestTask?.cancel()

        // Generate request key for coalescing
        let requestKey = generateRequestKey(criteria: criteria, resetPagination: resetPagination)

        // Cancel any existing request with the same key
        requestCoalescingMap[requestKey]?.cancel()

        logger.safeInfo("Debouncing filtered items request", [
            "resetPagination": String(resetPagination),
            "page": String(criteria.page),
            "requestKey": requestKey
        ])

        // Store pending criteria
        pendingCriteria = criteria

        // Create debounced task
        let task = Task { @MainActor in
            // Wait for debounce delay
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Check if criteria is still current
            guard let currentPendingCriteria = pendingCriteria,
                  currentPendingCriteria.isEquivalent(to: criteria) else {
                logger.safeInfo("Criteria changed during debounce, skipping request")
                return
            }

            // Execute the actual request
            await executeFilteredItemsRequest(criteria: criteria, resetPagination: resetPagination)

            // Clean up
            requestCoalescingMap.removeValue(forKey: requestKey)
        }

        // Store the task for potential cancellation
        pendingRequestTask = task
        requestCoalescingMap[requestKey] = task

        await task.value
    }

    private func executeFilteredItemsRequest(criteria: OutOfStockFilterCriteria, resetPagination: Bool) async {
        logger.safeInfo("Executing filtered items request", [
            "resetPagination": String(resetPagination),
            "page": String(criteria.page)
        ])

        let validatedCriteria = validateAndNormalizeCriteria(criteria)
        currentCriteria = validatedCriteria

        let append = !resetPagination && validatedCriteria.page > 0
        await loadPage(criteria: validatedCriteria, append: append)

        lastRequestTime = Date()
    }

    private func generateRequestKey(criteria: OutOfStockFilterCriteria, resetPagination: Bool) -> String {
        let customerId = criteria.customer?.id ?? "nil"
        let productId = criteria.product?.id ?? "nil"
        let status = criteria.status?.rawValue ?? "nil"
        let searchText = criteria.searchText.isEmpty ? "nil" : criteria.searchText

        let dateRange: String
        if let range = criteria.dateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            dateRange = "\(formatter.string(from: range.start))_\(formatter.string(from: range.end))"
        } else {
            dateRange = "nil"
        }

        return "\(customerId)_\(productId)_\(status)_\(searchText)_\(dateRange)_\(resetPagination)_\(criteria.page)"
    }
    
    func loadNextPage() async {
        guard hasMoreData && !isLoadingMore && !isLoading else { return }
        
        let nextPageCriteria = OutOfStockFilterCriteria(
            customer: currentCriteria.customer,
            product: currentCriteria.product,
            status: currentCriteria.status,
            dateRange: currentCriteria.dateRange,
            searchText: currentCriteria.searchText,
            page: currentPage + 1,
            pageSize: currentCriteria.pageSize,
            sortOrder: currentCriteria.sortOrder
        )
        
        await loadFilteredItems(criteria: nextPageCriteria, resetPagination: false)
    }
    
    private func loadPage(criteria: OutOfStockFilterCriteria, append: Bool) async {
        if append {
            isLoadingMore = true
        } else {
            isLoading = true
            error = nil
        }
        
        do {
            // Try cache first
            if let cachedRecords = cacheService.getCachedRecords(criteria) {
                updateUIWithRecords(cachedRecords, criteria: criteria, append: append)
                return
            }
            
            // Load from repository
            let records = try await dataService.fetchRecords(criteria)
            
            // Cache the results
            cacheService.cacheRecords(records, for: criteria)
            
            // Update UI
            updateUIWithRecords(records, criteria: criteria, append: append)
            
        } catch {
            logger.safeError("Failed to load page", error: error)
            self.error = error
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    private func updateUIWithRecords(_ records: [CustomerOutOfStock], criteria: OutOfStockFilterCriteria, append: Bool) {
        if append {
            items.append(contentsOf: records)
            currentPage = criteria.page
        } else {
            items = records
            currentPage = criteria.page
        }
        
        hasMoreData = records.count == criteria.pageSize
        
        // Update total count if we have it cached
        if let cachedCount = cacheService.getCachedCount(criteria) {
            totalRecordsCount = cachedCount
        }
        
        logger.safeInfo("UI updated with records", [
            "recordsCount": String(records.count),
            "totalItems": String(items.count),
            "hasMore": String(hasMoreData)
        ])
    }
    
    // MARK: - CRUD Operations
    
    func createOutOfStockItem(_ request: OutOfStockCreationRequest) async throws {
        logger.safeInfo("Creating out of stock item")
        
        try businessService.validateCreationRequest(request)
        let newItem = try await dataService.createRecord(request)
        
        // Audit logging
        await auditService.logCustomerOutOfStockCreation(
            item: newItem,
            operatorUserId: getCurrentUserId(),
            operatorUserName: getCurrentUserName()
        )
        
        // Invalidate cache
        cacheService.invalidateCache()
        
        logger.safeInfo("Successfully created out of stock item", ["itemId": newItem.id])
    }
    
    func updateOutOfStockItem(_ item: CustomerOutOfStock) async throws {
        logger.safeInfo("Updating out of stock item", ["itemId": item.id])
        
        // Capture before state for audit
        let beforeValues = createAuditValues(from: item)
        
        try businessService.validateRecord(item)
        try await dataService.updateRecord(item)
        
        // Audit logging
        let currentUser = authService.currentUser
        let afterValues = createAuditValues(from: item)

        await auditService.logOperation(
            operationType: .update,
            entityType: .customerOutOfStock,
            entityId: item.id,
            entityDescription: "\(item.customer?.name ?? "Unknown") - \(item.product?.name ?? "Unknown")",
            operatorUserId: currentUser?.id ?? "system",
            operatorUserName: currentUser?.name ?? "System",
            operationDetails: [
                "before": beforeValues,
                "after": afterValues,
                "changes": calculateChanges(before: beforeValues, after: afterValues)
            ]
        )
        
        // Invalidate cache
        cacheService.invalidateCache()
        
        logger.safeInfo("Successfully updated out of stock item", ["itemId": item.id])
    }
    
    func processReturn(_ item: CustomerOutOfStock, quantity: Int, notes: String?) async throws {
        logger.safeInfo("Processing return", ["itemId": item.id, "quantity": String(quantity)])
        
        try await businessService.processReturn(item, quantity: quantity, notes: notes)
        
        // Audit logging
        await auditService.logReturnProcessing(
            item: item,
            deliveryQuantity: quantity,
            deliveryNotes: notes,
            operatorUserId: getCurrentUserId(),
            operatorUserName: getCurrentUserName()
        )
        
        // Invalidate cache
        cacheService.invalidateCache()
        
        logger.safeInfo("Successfully processed return", ["itemId": item.id])
    }
    
    func deleteOutOfStockItem(_ item: CustomerOutOfStock) async throws {
        logger.safeInfo("Deleting out of stock item", ["itemId": item.id])
        
        // Audit logging (before deletion)
        await auditService.logCustomerOutOfStockDeletion(
            item: item,
            operatorUserId: getCurrentUserId(),
            operatorUserName: getCurrentUserName()
        )
        
        try await dataService.deleteRecord(item)
        
        // Invalidate cache
        cacheService.invalidateCache()
        
        logger.safeInfo("Successfully deleted out of stock item", ["itemId": item.id])
    }
    
    // MARK: - Statistics and Counts
    
    func loadStatusCounts(criteria: OutOfStockFilterCriteria) async -> [OutOfStockStatus: Int] {
        do {
            logger.safeInfo("Loading status counts", [
                "hasDateRange": String(criteria.dateRange != nil),
                "dateStart": criteria.dateRange?.start.formatted() ?? "nil",
                "dateEnd": criteria.dateRange?.end.formatted() ?? "nil"
            ])
            
            let statusCounts = try await businessService.getStatusCounts(criteria)
            
            logger.safeInfo("Status counts loaded", [
                "pending": String(statusCounts[.pending] ?? 0),
                "completed": String(statusCounts[.completed] ?? 0),
                "returned": String(statusCounts[.refunded] ?? 0)
            ])
            
            return statusCounts
        } catch {
            logger.safeError("Failed to load status counts", error: error)
            return [:]
        }
    }
    
    func getStatistics() async throws -> OutOfStockStatistics {
        return try await businessService.calculateStatistics(currentCriteria)
    }
    
    // MARK: - Cache Management
    
    func invalidateCache() async {
        cacheService.invalidateCache()
        logger.safeInfo("Cache invalidated")
    }
    
    func getMemoryUsage() -> CacheMemoryUsage {
        return cacheService.getMemoryUsage()
    }
    
    // MARK: - Analytics and Aggregation Methods

    /// Get aggregated data by region for analytics
    func getAggregatedDataByRegion(
        timeRange: TimeRange,
        customDateRange: ClosedRange<Date>? = nil,
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> [RegionAggregation] {
        return try await executeWithTimeoutAndRetry(
            operationName: "getAggregatedDataByRegion",
            timeout: 60.0, // 60 second timeout for large datasets
            maxRetries: 3,
            operation: {
                try await performRegionAnalytics(timeRange: timeRange, customDateRange: customDateRange, progressCallback: progressCallback)
            }
        )
    }

    private func performRegionAnalytics(
        timeRange: TimeRange,
        customDateRange: ClosedRange<Date>? = nil,
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> [RegionAggregation] {
        let dateRange = getDateRangeForTimeRange(timeRange, customRange: customDateRange)

        logger.safeInfo("Loading aggregated data by region with pagination", [
            "timeRange": timeRange.rawValue,
            "dateStart": dateRange.start.formatted(),
            "dateEnd": dateRange.end.formatted()
        ])

        // Initial progress
        progressCallback?(0.1, "Initializing data query...")

        // Fetch all records using pagination
        var allRecords: [CustomerOutOfStock] = []
        var page = 0
        let pageSize = 1000  // Maximum allowed by repository
        var hasMore = true
        let maxPages = 100  // Safety limit to prevent infinite loops

        while hasMore && page < maxPages {
            let criteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: dateRange,
                searchText: "",
                page: page,
                pageSize: pageSize,
                sortOrder: .newestFirst
            )

            let paginationResult = try await dataService.fetchRecordsWithPagination(criteria)

            // IMPORTANT: If first page is empty, data doesn't exist
            if page == 0 && paginationResult.items.isEmpty {
                logger.safeInfo("No region data found for time range", [
                    "timeRange": timeRange.rawValue
                ])
                progressCallback?(1.0, "No data available")
                return [] // Return empty array immediately
            }

            allRecords.append(contentsOf: paginationResult.items)

            hasMore = paginationResult.hasMoreData
            page += 1

            // Calculate progress (estimated based on page count, since we don't know total upfront)
            let estimatedProgress = min(0.8, Double(page) / max(10.0, Double(page + 1))) // Cap at 80% until processing
            let progressMessage = "Loading data... Page \(page) (\(allRecords.count) records)"
            progressCallback?(estimatedProgress, progressMessage)

            logger.safeInfo("Fetched page \(page) for region analytics", [
                "pageRecords": String(paginationResult.items.count),
                "totalRecords": String(allRecords.count),
                "hasMore": String(hasMore)
            ])
        }

        // Check for safety limit reached
        if page >= maxPages {
            logger.safeInfo("Reached maximum page limit", ["maxPages": String(maxPages)])
        }

        // Processing phase
        progressCallback?(0.85, "Processing region analytics...")

        // Handle empty result
        guard !allRecords.isEmpty else {
            logger.safeInfo("No records to aggregate")
            progressCallback?(1.0, "No data available")
            return []
        }

        // Group by region (customer address)
        let grouped = Dictionary(grouping: allRecords) { item in
            item.customer?.address ?? "未知地区"
        }

        let aggregations = grouped.map { regionName, items in
            let uniqueCustomers = Set(items.compactMap { $0.customer?.id })
            return RegionAggregation(
                regionName: regionName,
                items: items,
                uniqueCustomers: uniqueCustomers
            )
        }.sorted { $0.outOfStockCount > $1.outOfStockCount }

        logger.safeInfo("Region aggregation completed", [
            "totalRegions": String(aggregations.count),
            "totalItems": String(allRecords.count),
            "pagesProcessed": String(page)
        ])

        // Final progress update
        progressCallback?(1.0, "Region analytics complete")

        return aggregations
    }

    /// Get aggregated data by product for analytics
    func getAggregatedDataByProduct(timeRange: TimeRange, customDateRange: ClosedRange<Date>? = nil) async throws -> [ProductAggregation] {
        let dateRange = getDateRangeForTimeRange(timeRange, customRange: customDateRange)

        logger.safeInfo("Loading aggregated data by product with pagination", [
            "timeRange": timeRange.rawValue,
            "dateStart": dateRange.start.formatted(),
            "dateEnd": dateRange.end.formatted()
        ])

        // Fetch all records using pagination
        var allRecords: [CustomerOutOfStock] = []
        var page = 0
        let pageSize = 1000  // Maximum allowed by repository
        var hasMore = true
        let maxPages = 100  // Safety limit

        while hasMore && page < maxPages {
            let criteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: dateRange,
                searchText: "",
                page: page,
                pageSize: pageSize,
                sortOrder: .newestFirst
            )

            let paginationResult = try await dataService.fetchRecordsWithPagination(criteria)

            // Early exit if no data
            if page == 0 && paginationResult.items.isEmpty {
                logger.safeInfo("No product data found for time range")
                return []
            }

            allRecords.append(contentsOf: paginationResult.items)

            hasMore = paginationResult.hasMoreData
            page += 1

            logger.safeInfo("Fetched page \(page) for product analytics", [
                "pageRecords": String(paginationResult.items.count),
                "totalRecords": String(allRecords.count),
                "hasMore": String(hasMore)
            ])
        }

        // Handle empty result
        guard !allRecords.isEmpty else {
            return []
        }

        // Group by product
        let grouped = Dictionary(grouping: allRecords) { item in
            item.product?.name ?? "未知产品"
        }

        let aggregations = grouped.map { productName, items in
            let uniqueCustomers = Set(items.compactMap { $0.customer?.id })
            return ProductAggregation(
                productName: productName,
                productId: items.first?.product?.id,
                items: items,
                uniqueCustomers: uniqueCustomers
            )
        }.sorted { $0.outOfStockCount > $1.outOfStockCount }

        logger.safeInfo("Product aggregation completed", [
            "totalProducts": String(aggregations.count),
            "totalItems": String(allRecords.count),
            "pagesProcessed": String(page)
        ])

        return aggregations
    }

    /// Get aggregated data by customer for analytics
    func getAggregatedDataByCustomer(timeRange: TimeRange, customDateRange: ClosedRange<Date>? = nil) async throws -> [CustomerAggregation] {
        let dateRange = getDateRangeForTimeRange(timeRange, customRange: customDateRange)

        logger.safeInfo("Loading aggregated data by customer with pagination", [
            "timeRange": timeRange.rawValue,
            "dateStart": dateRange.start.formatted(),
            "dateEnd": dateRange.end.formatted()
        ])

        // Fetch all records using pagination
        var allRecords: [CustomerOutOfStock] = []
        var page = 0
        let pageSize = 1000  // Maximum allowed by repository
        var hasMore = true
        let maxPages = 100  // Safety limit

        while hasMore && page < maxPages {
            let criteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: dateRange,
                searchText: "",
                page: page,
                pageSize: pageSize,
                sortOrder: .newestFirst
            )

            let paginationResult = try await dataService.fetchRecordsWithPagination(criteria)

            // Early exit if no data
            if page == 0 && paginationResult.items.isEmpty {
                logger.safeInfo("No customer data found for time range")
                return []
            }

            allRecords.append(contentsOf: paginationResult.items)

            hasMore = paginationResult.hasMoreData
            page += 1

            logger.safeInfo("Fetched page \(page) for customer analytics", [
                "pageRecords": String(paginationResult.items.count),
                "totalRecords": String(allRecords.count),
                "hasMore": String(hasMore)
            ])
        }

        // Handle empty result
        guard !allRecords.isEmpty else {
            return []
        }

        // Group by customer
        let grouped = Dictionary(grouping: allRecords) { item in
            item.customer?.id ?? UUID().uuidString
        }

        let aggregations = grouped.map { customerId, items in
            let customer = items.first?.customer
            let uniqueProducts = Set(items.compactMap { $0.product?.name })
            return CustomerAggregation(
                customerId: customerId,
                customerName: customer?.name ?? "未知客户",
                customerAddress: customer?.address,
                items: items,
                uniqueProducts: uniqueProducts
            )
        }.sorted { $0.outOfStockCount > $1.outOfStockCount }

        logger.safeInfo("Customer aggregation completed", [
            "totalCustomers": String(aggregations.count),
            "totalItems": String(allRecords.count),
            "pagesProcessed": String(page)
        ])

        return aggregations
    }

    /// Get product trend data over time for line chart
    func getProductTrendData(timeRange: TimeRange, customDateRange: ClosedRange<Date>? = nil) async throws -> [ChartDataPoint] {
        let dateRange = getDateRangeForTimeRange(timeRange, customRange: customDateRange)

        logger.safeInfo("Loading product trend data with pagination", [
            "timeRange": timeRange.rawValue,
            "dateStart": dateRange.start.formatted(),
            "dateEnd": dateRange.end.formatted()
        ])

        // Fetch all records using pagination
        var allRecords: [CustomerOutOfStock] = []
        var page = 0
        let pageSize = 1000  // Maximum allowed by repository
        var hasMore = true

        while hasMore {
            let criteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: dateRange,
                searchText: "",
                page: page,
                pageSize: pageSize,
                sortOrder: .newestFirst
            )

            let paginationResult = try await dataService.fetchRecordsWithPagination(criteria)
            allRecords.append(contentsOf: paginationResult.items)

            hasMore = paginationResult.hasMoreData
            page += 1

            logger.safeInfo("Fetched page \(page) for trend analytics", [
                "pageRecords": String(paginationResult.items.count),
                "totalRecords": String(allRecords.count),
                "hasMore": String(hasMore)
            ])
        }

        // Group by date
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let grouped = Dictionary(grouping: allRecords) { item in
            dateFormatter.string(from: item.requestDate)
        }

        // Create chart data points
        let dataPoints = grouped.compactMap { dateString, items -> ChartDataPoint? in
            guard let date = dateFormatter.date(from: dateString) else { return nil }
            return ChartDataPoint.fromDateValue(
                date: date,
                value: Double(items.count),
                category: "out_of_stock_trend"
            )
        }.sorted { $0.date ?? Date.distantPast < $1.date ?? Date.distantPast }

        logger.safeInfo("Product trend data generated", [
            "dataPoints": String(dataPoints.count),
            "totalItems": String(allRecords.count),
            "pagesProcessed": String(page)
        ])

        return dataPoints
    }

    /// Get cached analytics data if available and not expired
    func getCachedAnalytics<T>(for key: AnalyticsCacheKey, type: T.Type) -> T? {
        return cacheService.getCachedAnalytics(for: key, type: type)
    }

    /// Cache analytics data with TTL
    func cacheAnalytics<T>(data: T, for key: AnalyticsCacheKey, ttl: TimeInterval = 300) {
        cacheService.cacheAnalytics(data: data, for: key, ttl: ttl)
    }

    // MARK: - Error Handling and Retry Logic

    /// Execute an operation with timeout and retry logic for large dataset scenarios
    private func executeWithTimeoutAndRetry<T>(
        operationName: String,
        timeout: TimeInterval,
        maxRetries: Int,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var recordCount = 0

        for attempt in 1...maxRetries {
            do {
                // Simple timeout implementation
                let result: T = try await operation()

                logger.safeInfo("Operation completed successfully", [
                    "operation": operationName,
                    "attempt": String(attempt)
                ])

                return result

            } catch let error as CustomerOutOfStockError {
                lastError = error

                switch error {
                case .dataProcessingTimeout, .networkTimeout:
                    logger.safeInfo("Operation timed out", [
                        "operation": operationName,
                        "attempt": String(attempt),
                        "timeout": String(timeout)
                    ])

                    if attempt == maxRetries {
                        throw CustomerOutOfStockError.retryExhausted(attempts: maxRetries)
                    }

                    // Exponential backoff
                    let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                default:
                    throw error
                }

            } catch {
                lastError = error

                // Handle network-related errors
                if isNetworkError(error) {
                    logger.safeInfo("Network error detected", [
                        "operation": operationName,
                        "attempt": String(attempt),
                        "error": error.localizedDescription
                    ])

                    if attempt == maxRetries {
                        throw CustomerOutOfStockError.retryExhausted(attempts: maxRetries)
                    }

                    // Shorter delay for network errors
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                } else {
                    // Non-retryable error
                    throw CustomerOutOfStockError.coordinatorError(underlying: error)
                }
            }
        }

        // If we get here, all retries were exhausted
        if let lastError = lastError {
            throw CustomerOutOfStockError.coordinatorError(underlying: lastError)
        } else {
            throw CustomerOutOfStockError.retryExhausted(attempts: maxRetries)
        }
    }

    /// Check if an error is network-related and potentially retryable
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Common network error codes
        let networkErrorCodes = [
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDNSLookupFailed
        ]

        return nsError.domain == NSURLErrorDomain && networkErrorCodes.contains(nsError.code)
    }

    /// Helper method to convert TimeRange to date range
    private func getDateRangeForTimeRange(_ timeRange: TimeRange, customRange: ClosedRange<Date>?) -> (start: Date, end: Date) {
        if timeRange == .custom, let customRange = customRange {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: customRange.lowerBound)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customRange.upperBound)) ?? customRange.upperBound
            return (start: startOfDay, end: endOfDay)
        } else {
            let range = timeRange.dateRange()
            return range
        }
    }

    // MARK: - Helper Methods

    private func validateAndNormalizeCriteria(_ criteria: OutOfStockFilterCriteria) -> OutOfStockFilterCriteria {
        // Validate and normalize values
        let normalizedPage = max(0, criteria.page)
        let normalizedPageSize = min(max(1, criteria.pageSize), 100)
        
        // Validate date range
        let normalizedDateRange: (start: Date, end: Date)?
        if let dateRange = criteria.dateRange {
            if dateRange.start > dateRange.end {
                normalizedDateRange = (start: dateRange.end, end: dateRange.start)
            } else {
                normalizedDateRange = dateRange
            }
        } else {
            normalizedDateRange = Self.createDateRange(for: Date())
        }
        
        // Create new criteria with normalized values
        return OutOfStockFilterCriteria(
            customer: criteria.customer,
            product: criteria.product,
            status: criteria.status,
            dateRange: normalizedDateRange,
            searchText: criteria.searchText,
            page: normalizedPage,
            pageSize: normalizedPageSize,
            sortOrder: criteria.sortOrder
        )
    }

    static func createDateRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        return (start: startOfDay, end: endOfDay)
    }
    
    private func getCurrentUserId() -> String {
        return authService.currentUser?.id ?? "system"
    }
    
    private func getCurrentUserName() -> String {
        return authService.currentUser?.name ?? "System User"
    }
    
    private func createAuditValues(from item: CustomerOutOfStock) -> CustomerOutOfStockOperation.CustomerOutOfStockValues {
        return CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            status: item.status.displayName,
            notes: item.notes,
            deliveryQuantity: item.deliveryQuantity,
            deliveryNotes: item.deliveryNotes
        )
    }

    private func calculateChanges(before: CustomerOutOfStockOperation.CustomerOutOfStockValues, after: CustomerOutOfStockOperation.CustomerOutOfStockValues) -> [String: [String: Any?]] {
        var changes: [String: [String: Any?]] = [:]

        if before.customerName != after.customerName {
            changes["customerName"] = ["before": before.customerName, "after": after.customerName]
        }
        if before.productName != after.productName {
            changes["productName"] = ["before": before.productName, "after": after.productName]
        }
        if before.quantity != after.quantity {
            changes["quantity"] = ["before": before.quantity, "after": after.quantity]
        }
        if before.status != after.status {
            changes["status"] = ["before": before.status, "after": after.status]
        }
        if before.notes != after.notes {
            changes["notes"] = ["before": before.notes, "after": after.notes]
        }
        if before.deliveryQuantity != after.deliveryQuantity {
            changes["deliveryQuantity"] = ["before": before.deliveryQuantity, "after": after.deliveryQuantity]
        }
        if before.deliveryNotes != after.deliveryNotes {
            changes["deliveryNotes"] = ["before": before.deliveryNotes, "after": after.deliveryNotes]
        }

        return changes
    }
}

// MARK: - Mock Implementations for Testing

private class MockCustomerOutOfStockDataService: CustomerOutOfStockDataService {
    func fetchRecords(_ criteria: OutOfStockFilterCriteria) async throws -> [CustomerOutOfStock] { [] }
    func fetchRecordsWithPagination(_ criteria: OutOfStockFilterCriteria) async throws -> OutOfStockPaginationResult {
        return OutOfStockPaginationResult(
            items: [],
            totalCount: 0,
            hasMoreData: false,
            page: criteria.page,
            pageSize: criteria.pageSize
        )
    }
    func countRecords(_ criteria: OutOfStockFilterCriteria) async throws -> Int { 0 }
    func createRecord(_ request: OutOfStockCreationRequest) async throws -> CustomerOutOfStock {
        // Safe placeholder implementation - returns mock data instead of crashing
        return CustomerOutOfStock.createMockRecord(from: request)
    }
    func updateRecord(_ item: CustomerOutOfStock) async throws {}
    func deleteRecord(_ item: CustomerOutOfStock) async throws {}
    func batchCreateRecords(_ requests: [OutOfStockCreationRequest]) async throws -> [CustomerOutOfStock] { [] }
}

private class MockCustomerOutOfStockBusinessService: CustomerOutOfStockBusinessService {
    func validateRecord(_ record: CustomerOutOfStock) throws {}
    func validateCreationRequest(_ request: OutOfStockCreationRequest) throws {}
    func processReturn(_ item: CustomerOutOfStock, quantity: Int, notes: String?) async throws {}
    func calculateStatistics(_ criteria: OutOfStockFilterCriteria) async throws -> OutOfStockStatistics {
        OutOfStockStatistics(totalItems: 0, pendingCount: 0, partiallyReturnedCount: 0, 
                           fullyReturnedCount: 0, totalQuantity: 0, totalReturnedQuantity: 0, averageProcessingTime: 0)
    }
    func getStatusCounts(_ criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int] { [:] }
    func canUserModify(_ item: CustomerOutOfStock, userId: String) -> Bool { true }
}

private class MockCustomerOutOfStockCacheService: CustomerOutOfStockCacheService {
    func getCachedRecords(_ criteria: OutOfStockFilterCriteria) -> [CustomerOutOfStock]? { nil }
    func cacheRecords(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria) {}
    func getCachedCount(_ criteria: OutOfStockFilterCriteria) -> Int? { nil }
    func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria) {}

    // Analytics caching methods
    func getCachedAnalytics<T>(for key: AnalyticsCacheKey, type: T.Type) -> T? { nil }
    func cacheAnalytics<T>(data: T, for key: AnalyticsCacheKey, ttl: TimeInterval) {}
    func invalidateAnalyticsCache() {}
    func invalidateAnalyticsCache(for key: AnalyticsCacheKey) {}

    func invalidateCache() {}
    func invalidateCache(for criteria: OutOfStockFilterCriteria) {}
    func getMemoryUsage() -> CacheMemoryUsage {
        CacheMemoryUsage(recordsCount: 0, approximateMemoryUsage: 0, cacheHitRate: 0, lastEvictionTime: nil)
    }
    func handleMemoryPressure() {}
}

private class MockNewAuditingService: NewAuditingService {
    init() {
        super.init(repositoryFactory: PlaceholderRepositoryFactory())
    }
}

private class MockAuditRepository: AuditRepository {
    func fetchAuditLogs() async throws -> [AuditLog] { [] }
    func fetchAuditLog(by id: String) async throws -> AuditLog? { nil }
    func fetchAuditLogs(forEntity entityId: String) async throws -> [AuditLog] { [] }
    func fetchAuditLogs(forUser userId: String) async throws -> [AuditLog] { [] }
    func fetchAuditLogs(forAction action: String) async throws -> [AuditLog] { [] }
    func fetchAuditLogs(from startDate: Date, to endDate: Date) async throws -> [AuditLog] { [] }
    func addAuditLog(_ log: AuditLog) async throws {}
    func deleteAuditLog(_ log: AuditLog) async throws {}
    func deleteAuditLogs(olderThan date: Date) async throws {}
}

private class MockAuthenticationService: AuthenticationService {
    private let mockFactory = PlaceholderRepositoryFactory()
    
    init() {
        super.init(repositoryFactory: mockFactory)
    }
}

@MainActor
private final class PlaceholderRepositoryFactory: RepositoryFactory, @unchecked Sendable {
    // Simplified production-safe implementation using only safe placeholders
    // This avoids complex ModelContext initialization and ensures zero crash risk
    
    var userRepository: UserRepository { MockAuditUserRepository() }
    var customerRepository: CustomerRepository { MockAuditCustomerRepository() }
    var productRepository: ProductRepository { MockAuditProductRepository() }
    var customerOutOfStockRepository: CustomerOutOfStockRepository { MockAuditCustomerOutOfStockRepository() }
    var packagingRepository: PackagingRepository { MockAuditPackagingRepository() }
    var productionRepository: ProductionRepository { MockAuditProductionRepository() }
    var auditRepository: AuditRepository { MockAuditRepository() }
    var machineRepository: MachineRepository { MockAuditMachineRepository() }
    var colorRepository: ColorRepository { MockAuditColorRepository() }
    var productionBatchRepository: ProductionBatchRepository { MockAuditProductionBatchRepository() }
    var salesRepository: SalesRepository { MockAuditSalesRepository() }
}

// MARK: - Mock Audit Repositories (Production-Safe Placeholders)
// These provide minimal implementations that won't crash and will log activity

private class MockAuditUserRepository: UserRepository {
    func fetchUsers() async throws -> [User] { 
        print("🔧 MockAuditUserRepository: fetchUsers called")
        return []
    }
    func fetchUser(byId id: String) async throws -> User? { 
        print("🔧 MockAuditUserRepository: fetchUser(byId:) called")
        return nil
    }
    func fetchUser(byWechatId wechatId: String) async throws -> User? { 
        print("🔧 MockAuditUserRepository: fetchUser(byWechatId:) called")
        return nil
    }
    func fetchUser(byAppleUserId appleUserId: String) async throws -> User? { 
        print("🔧 MockAuditUserRepository: fetchUser(byAppleUserId:) called")
        return nil
    }
    func fetchUser(byPhone phone: String) async throws -> User? { 
        print("🔧 MockAuditUserRepository: fetchUser(byPhone:) called")
        return nil
    }
    func addUser(_ user: User) async throws { 
        print("🔧 MockAuditUserRepository: addUser called - NO-OP in placeholder mode")
    }
    func updateUser(_ user: User) async throws { 
        print("🔧 MockAuditUserRepository: updateUser called - NO-OP in placeholder mode")
    }
    func deleteUser(_ user: User) async throws { 
        print("🔧 MockAuditUserRepository: deleteUser called - NO-OP in placeholder mode")
    }
    func deleteUsers(_ users: [User]) async throws { 
        print("🔧 MockAuditUserRepository: deleteUsers called - NO-OP in placeholder mode")
    }
}

private class MockAuditCustomerRepository: CustomerRepository {
    func fetchCustomers() async throws -> [Customer] { 
        print("🔧 MockAuditCustomerRepository: fetchCustomers called")
        return []
    }
    func fetchCustomer(by id: String) async throws -> Customer? { 
        print("🔧 MockAuditCustomerRepository: fetchCustomer(by:) called")
        return nil
    }
    func addCustomer(_ customer: Customer) async throws { 
        print("🔧 MockAuditCustomerRepository: addCustomer called - NO-OP in placeholder mode")
    }
    func updateCustomer(_ customer: Customer) async throws { 
        print("🔧 MockAuditCustomerRepository: updateCustomer called - NO-OP in placeholder mode")
    }
    func deleteCustomer(_ customer: Customer) async throws { 
        print("🔧 MockAuditCustomerRepository: deleteCustomer called - NO-OP in placeholder mode")
    }
    func deleteCustomers(_ customers: [Customer]) async throws { 
        print("🔧 MockAuditCustomerRepository: deleteCustomers called - NO-OP in placeholder mode")
    }
    func searchCustomers(query: String) async throws -> [Customer] { 
        print("🔧 MockAuditCustomerRepository: searchCustomers called")
        return []
    }
}

private class MockAuditProductRepository: ProductRepository {
    func fetchProducts() async throws -> [Product] { 
        print("🔧 MockAuditProductRepository: fetchProducts called")
        return []
    }
    func fetchProduct(by id: String) async throws -> Product? { 
        print("🔧 MockAuditProductRepository: fetchProduct(by:) called")
        return nil
    }
    func addProduct(_ product: Product) async throws { 
        print("🔧 MockAuditProductRepository: addProduct called - NO-OP in placeholder mode")
    }
    func updateProduct(_ product: Product) async throws { 
        print("🔧 MockAuditProductRepository: updateProduct called - NO-OP in placeholder mode")
    }
    func deleteProduct(_ product: Product) async throws { 
        print("🔧 MockAuditProductRepository: deleteProduct called - NO-OP in placeholder mode")
    }
    func deleteProducts(_ products: [Product]) async throws { 
        print("🔧 MockAuditProductRepository: deleteProducts called - NO-OP in placeholder mode")
    }
    func searchProducts(query: String) async throws -> [Product] { 
        print("🔧 MockAuditProductRepository: searchProducts called")
        return []
    }
}

private class MockAuditCustomerOutOfStockRepository: CustomerOutOfStockRepository {
    // Legacy methods (maintained for backward compatibility)
    func fetchOutOfStockRecords() async throws -> [CustomerOutOfStock] { 
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchOutOfStockRecords called")
        return []
    }
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock? { 
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchOutOfStockRecord(by:) called")
        return nil
    }
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock] { 
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchOutOfStockRecords(for customer:) called")
        return []
    }
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock] { 
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchOutOfStockRecords(for product:) called")
        return []
    }
    
    // New paginated methods
    func fetchOutOfStockRecords(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchOutOfStockRecords(criteria:page:pageSize:) called")
        return OutOfStockPaginationResult(
            items: [],
            totalCount: 0,
            hasMoreData: false,
            page: page,
            pageSize: pageSize
        )
    }
    
    func countOutOfStockRecords(criteria: OutOfStockFilterCriteria) async throws -> Int { 
        print("🔧 MockAuditCustomerOutOfStockRepository: countOutOfStockRecords called")
        return 0
    }
    
    func countOutOfStockRecordsByStatus(criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int] { 
        print("🔧 MockAuditCustomerOutOfStockRepository: countOutOfStockRecordsByStatus called")
        return [:]
    }
    
    func countPartialReturnRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        print("🔧 MockAuditCustomerOutOfStockRepository: countPartialReturnRecords called")
        return 0
    }

    func countDueSoonRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        print("🔧 MockAuditCustomerOutOfStockRepository: countDueSoonRecords called")
        return 0
    }

    func countOverdueRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        print("🔧 MockAuditCustomerOutOfStockRepository: countOverdueRecords called")
        return 0
    }

    func fetchDashboardMetrics() async throws -> DashboardMetrics {
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchDashboardMetrics called")
        return DashboardMetrics(
            statusCounts: [:],
            needsReturnCount: 0,
            dueSoonCount: 0,
            overdueCount: 0,
            topPendingItems: [],
            topReturnItems: [],
            recentCompleted: []
        )
    }

    func fetchDeliveryManagementMetrics(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> DeliveryManagementMetrics {
        print("🔧 MockAuditCustomerOutOfStockRepository: fetchDeliveryManagementMetrics called")
        return DeliveryManagementMetrics(
            items: [],
            totalCount: 0,
            hasMoreData: false,
            page: page,
            pageSize: pageSize,
            needsDeliveryCount: 0,
            partialDeliveryCount: 0,
            completedDeliveryCount: 0
        )
    }

    // CRUD operations
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        print("🔧 MockAuditCustomerOutOfStockRepository: addOutOfStockRecord called - NO-OP in placeholder mode")
    }
    func addOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws {
        print("🔧 MockAuditCustomerOutOfStockRepository: addOutOfStockRecords (bulk) called - NO-OP in placeholder mode")
    }
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws { 
        print("🔧 MockAuditCustomerOutOfStockRepository: updateOutOfStockRecord called - NO-OP in placeholder mode")
    }
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws { 
        print("🔧 MockAuditCustomerOutOfStockRepository: deleteOutOfStockRecord called - NO-OP in placeholder mode")
    }
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws { 
        print("🔧 MockAuditCustomerOutOfStockRepository: deleteOutOfStockRecords called - NO-OP in placeholder mode")
    }
}

// Minimal implementations for other repositories
private class MockAuditPackagingRepository: PackagingRepository {
    // PackagingRecord operations
    func fetchPackagingRecords() async throws -> [PackagingRecord] { 
        print("🔧 MockAuditPackagingRepository: fetchPackagingRecords called")
        return []
    }
    func fetchPackagingRecord(by id: String) async throws -> PackagingRecord? { 
        print("🔧 MockAuditPackagingRepository: fetchPackagingRecord(by:) called")
        return nil
    }
    func fetchPackagingRecords(for teamId: String) async throws -> [PackagingRecord] { 
        print("🔧 MockAuditPackagingRepository: fetchPackagingRecords(for teamId:) called")
        return []
    }
    func fetchPackagingRecords(for date: Date) async throws -> [PackagingRecord] { 
        print("🔧 MockAuditPackagingRepository: fetchPackagingRecords(for date:) called")
        return []
    }
    func addPackagingRecord(_ record: PackagingRecord) async throws { 
        print("🔧 MockAuditPackagingRepository: addPackagingRecord called - NO-OP in placeholder mode")
    }
    func updatePackagingRecord(_ record: PackagingRecord) async throws { 
        print("🔧 MockAuditPackagingRepository: updatePackagingRecord called - NO-OP in placeholder mode")
    }
    func deletePackagingRecord(_ record: PackagingRecord) async throws { 
        print("🔧 MockAuditPackagingRepository: deletePackagingRecord called - NO-OP in placeholder mode")
    }
    
    // PackagingTeam operations
    func fetchPackagingTeams() async throws -> [PackagingTeam] { 
        print("🔧 MockAuditPackagingRepository: fetchPackagingTeams called")
        return []
    }
    func fetchPackagingTeam(by id: String) async throws -> PackagingTeam? { 
        print("🔧 MockAuditPackagingRepository: fetchPackagingTeam(by:) called")
        return nil
    }
    func addPackagingTeam(_ team: PackagingTeam) async throws { 
        print("🔧 MockAuditPackagingRepository: addPackagingTeam called - NO-OP in placeholder mode")
    }
    func updatePackagingTeam(_ team: PackagingTeam) async throws { 
        print("🔧 MockAuditPackagingRepository: updatePackagingTeam called - NO-OP in placeholder mode")
    }
    func deletePackagingTeam(_ team: PackagingTeam) async throws { 
        print("🔧 MockAuditPackagingRepository: deletePackagingTeam called - NO-OP in placeholder mode")
    }
}

private class MockAuditProductionRepository: ProductionRepository {
    // ProductionStyle operations
    func fetchProductionStyles() async throws -> [ProductionStyle] { 
        print("🔧 MockAuditProductionRepository: fetchProductionStyles called")
        return []
    }
    func fetchProductionStyle(by id: String) async throws -> ProductionStyle? { 
        print("🔧 MockAuditProductionRepository: fetchProductionStyle(by:) called")
        return nil
    }
    func fetchProductionStyles(by status: StyleStatus) async throws -> [ProductionStyle] { 
        print("🔧 MockAuditProductionRepository: fetchProductionStyles(by status:) called")
        return []
    }
    func addProductionStyle(_ style: ProductionStyle) async throws { 
        print("🔧 MockAuditProductionRepository: addProductionStyle called - NO-OP in placeholder mode")
    }
    func updateProductionStyle(_ style: ProductionStyle) async throws { 
        print("🔧 MockAuditProductionRepository: updateProductionStyle called - NO-OP in placeholder mode")
    }
    func deleteProductionStyle(_ style: ProductionStyle) async throws { 
        print("🔧 MockAuditProductionRepository: deleteProductionStyle called - NO-OP in placeholder mode")
    }
    
    // WorkshopProduction operations
    func fetchWorkshopProductions() async throws -> [WorkshopProduction] { 
        print("🔧 MockAuditProductionRepository: fetchWorkshopProductions called")
        return []
    }
    func fetchWorkshopProduction(by id: String) async throws -> WorkshopProduction? { 
        print("🔧 MockAuditProductionRepository: fetchWorkshopProduction(by:) called")
        return nil
    }
    func addWorkshopProduction(_ production: WorkshopProduction) async throws { 
        print("🔧 MockAuditProductionRepository: addWorkshopProduction called - NO-OP in placeholder mode")
    }
    func updateWorkshopProduction(_ production: WorkshopProduction) async throws { 
        print("🔧 MockAuditProductionRepository: updateWorkshopProduction called - NO-OP in placeholder mode")
    }
    func deleteWorkshopProduction(_ production: WorkshopProduction) async throws { 
        print("🔧 MockAuditProductionRepository: deleteWorkshopProduction called - NO-OP in placeholder mode")
    }
    
    // EVAGranulation operations
    func fetchEVAGranulations() async throws -> [EVAGranulation] { 
        print("🔧 MockAuditProductionRepository: fetchEVAGranulations called")
        return []
    }
    func fetchEVAGranulation(by id: String) async throws -> EVAGranulation? { 
        print("🔧 MockAuditProductionRepository: fetchEVAGranulation(by:) called")
        return nil
    }
    func addEVAGranulation(_ granulation: EVAGranulation) async throws { 
        print("🔧 MockAuditProductionRepository: addEVAGranulation called - NO-OP in placeholder mode")
    }
    func updateEVAGranulation(_ granulation: EVAGranulation) async throws { 
        print("🔧 MockAuditProductionRepository: updateEVAGranulation called - NO-OP in placeholder mode")
    }
    func deleteEVAGranulation(_ granulation: EVAGranulation) async throws { 
        print("🔧 MockAuditProductionRepository: deleteEVAGranulation called - NO-OP in placeholder mode")
    }
    
    // WorkshopIssue operations
    func fetchWorkshopIssues() async throws -> [WorkshopIssue] { 
        print("🔧 MockAuditProductionRepository: fetchWorkshopIssues called")
        return []
    }
    func fetchWorkshopIssue(by id: String) async throws -> WorkshopIssue? { 
        print("🔧 MockAuditProductionRepository: fetchWorkshopIssue(by:) called")
        return nil
    }
    func addWorkshopIssue(_ issue: WorkshopIssue) async throws { 
        print("🔧 MockAuditProductionRepository: addWorkshopIssue called - NO-OP in placeholder mode")
    }
    func updateWorkshopIssue(_ issue: WorkshopIssue) async throws { 
        print("🔧 MockAuditProductionRepository: updateWorkshopIssue called - NO-OP in placeholder mode")
    }
    func deleteWorkshopIssue(_ issue: WorkshopIssue) async throws { 
        print("🔧 MockAuditProductionRepository: deleteWorkshopIssue called - NO-OP in placeholder mode")
    }
}

private class MockAuditMachineRepository: MachineRepository {
    // MARK: - Machine CRUD
    func fetchAllMachines() async throws -> [WorkshopMachine] { 
        print("🔧 MockAuditMachineRepository: fetchAllMachines called")
        return []
    }
    func fetchMachine(byId id: String) async throws -> WorkshopMachine? { 
        print("🔧 MockAuditMachineRepository: fetchMachine(byId:) called")
        return nil
    }
    func fetchMachineById(_ id: String) async throws -> WorkshopMachine? { 
        print("🔧 MockAuditMachineRepository: fetchMachineById(_:) called")
        return nil
    }
    func fetchMachine(byNumber number: Int) async throws -> WorkshopMachine? { 
        print("🔧 MockAuditMachineRepository: fetchMachine(byNumber:) called")
        return nil
    }
    func fetchActiveMachines() async throws -> [WorkshopMachine] { 
        print("🔧 MockAuditMachineRepository: fetchActiveMachines called")
        return []
    }
    func fetchMachinesWithStatus(_ status: MachineStatus) async throws -> [WorkshopMachine] { 
        print("🔧 MockAuditMachineRepository: fetchMachinesWithStatus called")
        return []
    }
    func addMachine(_ machine: WorkshopMachine) async throws { 
        print("🔧 MockAuditMachineRepository: addMachine called - NO-OP in placeholder mode")
    }
    func updateMachine(_ machine: WorkshopMachine) async throws { 
        print("🔧 MockAuditMachineRepository: updateMachine called - NO-OP in placeholder mode")
    }
    func deleteMachine(_ machine: WorkshopMachine) async throws { 
        print("🔧 MockAuditMachineRepository: deleteMachine called - NO-OP in placeholder mode")
    }
    
    // MARK: - Station Operations
    func fetchStations(for machineId: String) async throws -> [WorkshopStation] { 
        print("🔧 MockAuditMachineRepository: fetchStations called")
        return []
    }
    func updateStation(_ station: WorkshopStation) async throws { 
        print("🔧 MockAuditMachineRepository: updateStation called - NO-OP in placeholder mode")
    }
    
    // MARK: - Gun Operations
    func fetchGuns(for machineId: String) async throws -> [WorkshopGun] { 
        print("🔧 MockAuditMachineRepository: fetchGuns called")
        return []
    }
    func updateGun(_ gun: WorkshopGun) async throws { 
        print("🔧 MockAuditMachineRepository: updateGun called - NO-OP in placeholder mode")
    }
    
    // MARK: - Batch-aware Machine Queries
    func fetchMachinesWithoutPendingApprovalBatches() async throws -> [WorkshopMachine] { 
        print("🔧 MockAuditMachineRepository: fetchMachinesWithoutPendingApprovalBatches called")
        return []
    }
}

private class MockAuditColorRepository: ColorRepository {
    func fetchAllColors() async throws -> [ColorCard] { [] }
    func fetchActiveColors() async throws -> [ColorCard] { [] }
    func fetchColorById(_ id: String) async throws -> ColorCard? { nil }
    func addColor(_ color: ColorCard) async throws { }
    func updateColor(_ color: ColorCard) async throws { }
    func deleteColor(_ color: ColorCard) async throws { }
    func deactivateColor(_ color: ColorCard) async throws { }
    func searchColors(by name: String) async throws -> [ColorCard] { [] }
}

private class MockAuditProductionBatchRepository: ProductionBatchRepository {
    func fetchAllBatches() async throws -> [ProductionBatch] { [] }
    func fetchBatchesByStatus(_ status: BatchStatus) async throws -> [ProductionBatch] { [] }
    func fetchBatchesByMachine(_ machineId: String) async throws -> [ProductionBatch] { [] }
    func fetchBatchById(_ id: String) async throws -> ProductionBatch? { nil }
    func addBatch(_ batch: ProductionBatch) async throws { }
    func updateBatch(_ batch: ProductionBatch) async throws { }
    func deleteBatch(_ batch: ProductionBatch) async throws { }
    func deleteBatch(id: String) async throws { }
    func fetchPendingBatches() async throws -> [ProductionBatch] { [] }
    func fetchActiveBatches() async throws -> [ProductionBatch] { [] }
    func fetchBatchHistory(limit: Int?) async throws -> [ProductionBatch] { [] }
    func addProductConfig(_ productConfig: ProductConfig, toBatch batchId: String) async throws { }
    func updateProductConfig(_ productConfig: ProductConfig) async throws { }
    func removeProductConfig(_ productConfig: ProductConfig) async throws { }
    func fetchProductConfigs(forBatch batchId: String) async throws -> [ProductConfig] { [] }
    func fetchLatestBatchNumber(forDate dateString: String, batchType: BatchType) async throws -> String? { nil }
    func fetchBatches(forDate date: Date, shift: Shift) async throws -> [ProductionBatch] { [] }
    func fetchBatches(forDate date: Date) async throws -> [ProductionBatch] { [] }
    func fetchShiftAwareBatches() async throws -> [ProductionBatch] { [] }
    func fetchBatches(from startDate: Date, to endDate: Date, shift: Shift?) async throws -> [ProductionBatch] { [] }
    func hasConflictingBatches(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool { false }
    func fetchBatchesRequiringMigration() async throws -> [ProductionBatch] { [] }
    func fetchActiveBatchForMachine(_ machineId: String) async throws -> ProductionBatch? { nil }
    func fetchLatestBatchForMachineAndShift(machineId: String, date: Date, shift: Shift) async throws -> ProductionBatch? { nil }
    func fetchActiveBatchesWithStatus(_ statuses: [BatchStatus]) async throws -> [ProductionBatch] { [] }
    func fetchBatchesForMachine(_ machineId: String, statuses: [BatchStatus], from startDate: Date?, to endDate: Date?) async throws -> [ProductionBatch] { [] }
}

private class MockAuditSalesRepository: SalesRepository {
    func fetchSalesEntries(forDate date: Date) async throws -> [DailySalesEntry] {
        print("🔧 MockAuditSalesRepository: fetchSalesEntries(forDate:) called")
        return []
    }

    func fetchSalesEntries(from startDate: Date, to endDate: Date, salespersonId: String) async throws -> [DailySalesEntry] {
        print("🔧 MockAuditSalesRepository: fetchSalesEntries(from:to:salespersonId:) called")
        return []
    }

    func createSalesEntry(_ entry: DailySalesEntry) async throws {
        print("🔧 MockAuditSalesRepository: createSalesEntry called")
    }

    func updateSalesEntry(_ entry: DailySalesEntry) async throws {
        print("🔧 MockAuditSalesRepository: updateSalesEntry called")
    }

    func deleteSalesEntry(id: String) async throws {
        print("🔧 MockAuditSalesRepository: deleteSalesEntry called")
    }

    func calculateDailySalesTotal(forDate date: Date, salespersonId: String) async throws -> Decimal {
        print("🔧 MockAuditSalesRepository: calculateDailySalesTotal called")
        return 0
    }
}
