//
//  CustomerOutOfStockService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import os

enum CustomerOutOfStockServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case sessionExpired
    case authenticationRequired
    case invalidUserCredentials
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "用户未登录，请先登录后再操作"
        case .sessionExpired:
            return "登录会话已过期，请重新登录"
        case .authenticationRequired:
            return "此操作需要身份验证"
        case .invalidUserCredentials:
            return "用户凭证无效"
        case .serviceUnavailable:
            return "服务暂时不可用，请稍后再试"
        }
    }
}

struct ReturnProcessingRequest {
    let item: CustomerOutOfStock
    let returnQuantity: Int
    let returnNotes: String?
}

@MainActor
class CustomerOutOfStockService: ObservableObject {
    private var repositoryFactory: RepositoryFactory!
    private var customerOutOfStockRepository: CustomerOutOfStockRepository!
    private var auditService: NewAuditingService!
    private var authService: AuthenticationService!
    private let cacheManager: OutOfStockCacheManager
    
    var isPlaceholder = false
    
    @Published var items: [CustomerOutOfStock] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: Error?
    @Published var hasMoreData = true
    @Published var currentPage = 0
    @Published var totalRecordsCount = 0
    
    // Current filter state
    @Published var currentCriteria: OutOfStockFilterCriteria
    
    private let pageSize = 50 // [rule:§3+.2 API Contract] Increased to match Dashboard initial load size
    private var backgroundQueue = DispatchQueue(label: "customerOutOfStock.processing", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.lopan.app", category: "CustomerOutOfStockService")
    
    init(
        repositoryFactory: RepositoryFactory,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.repositoryFactory = repositoryFactory
        self.customerOutOfStockRepository = repositoryFactory.customerOutOfStockRepository
        self.auditService = auditService
        self.authService = authService
        self.cacheManager = OutOfStockCacheManager()
        self.isPlaceholder = false
        self.currentCriteria = OutOfStockFilterCriteria(
            dateRange: Self.createDateRange(for: Date()),
            page: 0,
            pageSize: pageSize
        )
    }
    
    static func placeholder() -> CustomerOutOfStockService {
        let service = CustomerOutOfStockService.__placeholder()
        return service
    }
    
    private init() {
        self.cacheManager = OutOfStockCacheManager()
        self.isPlaceholder = true
        self.currentCriteria = OutOfStockFilterCriteria(
            dateRange: Self.createDateRange(for: Date()),
            page: 0,
            pageSize: pageSize
        )
    }
    
    private static func __placeholder() -> CustomerOutOfStockService {
        return CustomerOutOfStockService()
    }
    
    func initialize(
        repositoryFactory: RepositoryFactory,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        guard isPlaceholder else { return }
        self.repositoryFactory = repositoryFactory
        self.customerOutOfStockRepository = repositoryFactory.customerOutOfStockRepository
        self.auditService = auditService
        self.authService = authService
        self.isPlaceholder = false
    }
    
    // MARK: - Data Loading with Pagination and Caching
    
    func loadDataForDate(_ date: Date, resetPagination: Bool = true) async {
        if resetPagination {
            currentPage = 0
            items = []
            hasMoreData = true
            totalRecordsCount = 0
        }
        
        // Update criteria for the new date
        currentCriteria = OutOfStockFilterCriteria(
            customer: currentCriteria.customer,
            product: currentCriteria.product,
            status: currentCriteria.status,
            dateRange: Self.createDateRange(for: date),
            searchText: currentCriteria.searchText,
            page: currentPage,
            pageSize: pageSize,
            sortOrder: CustomerOutOfStockNavigationState.shared.sortOrder
        )
        
        await loadPage(criteria: currentCriteria, date: date, append: false)
    }
    
    func loadFilteredItems(criteria: OutOfStockFilterCriteria, resetPagination: Bool = true) async {
        logger.safeInfo("Loading filtered items", [
            "status": criteria.status?.displayName ?? "all",
            "has_date_filter": criteria.dateRange != nil ? "yes" : "no",
            "has_search": !criteria.searchText.isEmpty ? "yes" : "no"
        ])
        
        // Try incremental filtering first for status-only changes
        if resetPagination {
            let usedIncrementalFiltering = await tryIncrementalStatusFiltering(criteria: criteria)
            if usedIncrementalFiltering {
                logger.info("Used incremental status filtering optimization")
                return
            }
        }
        
        // Validate and normalize criteria before processing
        let normalizedCriteria = validateAndNormalizeCriteria(criteria)
        
        let isStatusFilterChange = resetPagination && normalizedCriteria.status != currentCriteria.status
        let isCustomerFilterChange = resetPagination && normalizedCriteria.customer?.id != currentCriteria.customer?.id
        let isProductFilterChange = resetPagination && normalizedCriteria.product?.id != currentCriteria.product?.id
        let isSearchTextChange = resetPagination && normalizedCriteria.searchText != currentCriteria.searchText
        
        if resetPagination {
            currentPage = 0
            // Force clear items array immediately to prevent stale data display
            await MainActor.run {
                items = []
                totalRecordsCount = 0
                isLoading = true
            }
            hasMoreData = true // [rule:§3+.2 API Contract] Always assume more data initially
            logger.info("Reset pagination for filtered items")
            
            // Clear cache when any significant filter changes to ensure fresh data
            if isStatusFilterChange || isCustomerFilterChange || isProductFilterChange || isSearchTextChange {
                let targetDate = normalizedCriteria.dateRange?.start ?? Date()
                logger.info("Filter changed, clearing cache")
                await cacheManager.invalidateCache(for: targetDate)
            }
        } else {
            // Update currentPage from criteria to ensure page state synchronization
            currentPage = normalizedCriteria.page
        }
        
        // Enhanced date validation to prevent cross-date contamination
        let requestedDate = normalizedCriteria.dateRange?.start ?? Date()
        let currentDate = currentCriteria.dateRange?.start ?? Date()
        let calendar = Calendar.current
        
        // If switching dates, force reset pagination and clear cache
        if !calendar.isDate(requestedDate, inSameDayAs: currentDate) && resetPagination {
            logger.info("Date filter changed, clearing cache")
            await cacheManager.invalidateCache(for: requestedDate)
            
            // Also clear previous date cache to prevent memory buildup
            await cacheManager.invalidateCache(for: currentDate)
        }
        
        // Update current criteria with normalized version
        currentCriteria = normalizedCriteria
        await loadPage(criteria: normalizedCriteria, date: requestedDate, append: !resetPagination)
        
        logger.safeInfo("Loaded filtered items", [
            "item_count": String(items.count),
            "has_more": String(hasMoreData),
            "total_count": String(totalRecordsCount)
        ])
    }
    
    // MARK: - Criteria Validation and Normalization
    
    private func validateAndNormalizeCriteria(_ criteria: OutOfStockFilterCriteria) -> OutOfStockFilterCriteria {
        // Ensure date range is properly normalized to start of day
        var normalizedDateRange = criteria.dateRange
        if let dateRange = criteria.dateRange {
            let calendar = Calendar.current
            let normalizedStart = calendar.startOfDay(for: dateRange.start)
            let normalizedEnd = calendar.startOfDay(for: dateRange.end)
            normalizedDateRange = (start: normalizedStart, end: normalizedEnd)
        }
        
        // Trim whitespace from search text
        let normalizedSearchText = criteria.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let normalizedCriteria = OutOfStockFilterCriteria(
            customer: criteria.customer,
            product: criteria.product,
            status: criteria.status,
            dateRange: normalizedDateRange,
            searchText: normalizedSearchText,
            page: criteria.page,
            pageSize: criteria.pageSize,
            sortOrder: criteria.sortOrder
        )
        
        logger.info("Normalized filter criteria")
        
        return normalizedCriteria
    }
    
    // MARK: - Cache Key Date Validation
    
    private func validateCacheKeyDate(criteria: OutOfStockFilterCriteria, fallbackDate: Date) -> Date {
        // Use criteria's dateRange start if available and valid
        if let dateRangeStart = criteria.dateRange?.start {
            let calendar = Calendar.current
            // Ensure the date is normalized to start of day for consistent caching
            return calendar.startOfDay(for: dateRangeStart)
        }
        
        // Fallback to provided date (also normalize to start of day)
        let calendar = Calendar.current
        return calendar.startOfDay(for: fallbackDate)
    }
    
    func loadNextPage() async {
        guard hasMoreData && !isLoading && !isLoadingMore else { return }
        
        currentPage += 1
        let nextPageCriteria = OutOfStockFilterCriteria(
            customer: currentCriteria.customer,
            product: currentCriteria.product,
            status: currentCriteria.status,
            dateRange: currentCriteria.dateRange,
            searchText: currentCriteria.searchText,
            page: currentPage,
            pageSize: pageSize
        )
        
        await loadPage(criteria: nextPageCriteria, date: currentCriteria.dateRange?.start ?? Date(), append: true)
    }
    
    private func loadPage(criteria: OutOfStockFilterCriteria, date: Date, append: Bool) async {
        logger.safeInfo("Loading page", [
            "page": String(criteria.page),
            "append": String(append),
            "status": criteria.status?.displayName ?? "all"
        ])
        
        if append {
            isLoadingMore = true
        } else {
            isLoading = true
        }
        
        defer {
            if append {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        }
        
        do {
            // Enhanced cache key generation with better date validation
            let cacheKeyDate = validateCacheKeyDate(criteria: criteria, fallbackDate: date)
            let cacheKey = OutOfStockCacheKey(
                date: cacheKeyDate,
                criteria: criteria,
                page: criteria.page
            )
            
            logger.info("Creating cache key")
            
            // Try to get from cache first
            if let cachedPage = await cacheManager.getCachedPage(for: cacheKey) {
                logger.info("Cache hit")
                await updateUIWithData(cachedPage, append: append)
                return
            }
            
            logger.info("Cache miss, fetching from repository")
            
            // Fetch from repository - the repository itself handles thread safety
            let result = try await customerOutOfStockRepository.fetchOutOfStockRecords(
                criteria: criteria,
                page: criteria.page,
                pageSize: criteria.pageSize
            )
            
            // Convert to thread-safe DTOs and create cached page (must be on main thread)
            await MainActor.run {
                do {
                    let cachedPage = cacheManager.createCachedPage(
                        from: result.items,
                        totalCount: result.totalCount,
                        hasMoreData: result.hasMoreData
                    )
                    
                    // Cache the result asynchronously
                    Task {
                        await cacheManager.cachePage(cachedPage, for: cacheKey)
                        
                        // Also cache base data (without status filter) for fast status switching
                        if !append && criteria.page == 0 {
                            await self.cacheBaseDataIfApplicable(cachedPage, criteria: criteria)
                        }
                    }
                    
                    // Update UI immediately with the data
                    Task { @MainActor in
                        await self.updateUIWithData(cachedPage, append: append)
                    }
                } catch {
                    // If caching fails, still update UI with data
                    logger.safeError("Cache conversion failed", error: error)
                    let simpleCachedPage = self.createFallbackCachedPage(from: result)
                    Task { @MainActor in
                        await self.updateUIWithData(simpleCachedPage, append: append)
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                logger.safeError("Error loading page", error: error)
            }
        }
    }
    
    @MainActor
    private func updateUIWithData(_ page: CachedOutOfStockPage, append: Bool) {
        // Convert DTOs back to CustomerOutOfStock models for UI compatibility
        let newItems = convertDTOsToModelsForDisplay(page.items)
        
        if append {
            // 去重：过滤掉已存在的ID，防止ForEach重复ID警告
            let existingIds = Set(items.map { $0.id })
            let uniqueNewItems = newItems.filter { !existingIds.contains($0.id) }
            
            logger.safeInfo("Appending items", [
                "unique_items": String(uniqueNewItems.count),
                "total_new_items": String(newItems.count)
            ])
            items.append(contentsOf: uniqueNewItems)
            
            // For append operations, trust the repository's hasMoreData flag [rule:§3+.2 API Contract]
            hasMoreData = page.hasMoreData
            
            // Service layer protection for append operations too
            if items.count < page.totalCount && !page.hasMoreData {
                logger.safeWarning("Correcting hasMoreData flag", [
                    "current_items": String(items.count),
                    "total_count": String(page.totalCount)
                ])
                hasMoreData = true
            }
            
            logger.safeInfo("After append state", [
                "items_count": String(items.count),
                "total_count": String(page.totalCount),
                "has_more_data": String(hasMoreData)
            ])
        } else {
            // For initial/replacement loads, validate data consistency before updating UI
            if !newItems.isEmpty {
                // Validate that all items fall within the current filter criteria date range
                if let dateRange = currentCriteria.dateRange {
                    let calendar = Calendar.current
                    let rangeStart = calendar.startOfDay(for: dateRange.start)
                    let rangeEnd = calendar.startOfDay(for: dateRange.end)
                    var dateValidationFailed = false
                    
                    // Check if this is a single-day filter or a multi-day range
                    let daysBetween = calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0
                    let isSingleDayFilter = daysBetween <= 1
                    
                    for item in newItems {
                        let itemDate = calendar.startOfDay(for: item.requestDate)
                        
                        if isSingleDayFilter {
                            // For single-day filters (today, yesterday), use exact match
                            if itemDate != rangeStart {
                                logger.warning("Single-day validation failed")
                                dateValidationFailed = true
                                break
                            }
                        } else {
                            // For multi-day ranges (week, month), use range validation
                            if itemDate < rangeStart || itemDate >= rangeEnd {
                                logger.warning("Range validation failed")
                                dateValidationFailed = true
                                break
                            }
                        }
                    }
                    
                    // If validation failed, reject the data and keep UI empty
                    if dateValidationFailed {
                        logger.warning("Rejecting mismatched data")
                        items = []
                        totalRecordsCount = 0
                        hasMoreData = false
                        return
                    } else {
                        logger.info("Date validation passed")
                    }
                }
            }
            
            // For initial/replacement loads, always use the new data (even if empty)
            items = newItems
            totalRecordsCount = page.totalCount
            
            // For initial/replacement loads, validate and trust the repository's hasMoreData flag [rule:§3+.2 API Contract]  
            hasMoreData = page.hasMoreData
            
            // Service layer protection: If we have fewer items than total count, there must be more data
            if newItems.count < page.totalCount && !page.hasMoreData {
                logger.safeWarning("Correcting hasMoreData flag for initial load", [
                    "items_count": String(newItems.count),
                    "total_count": String(page.totalCount)
                ])
                hasMoreData = true
            }
            
            logger.safeInfo("Initial/replacement load complete", [
                "items_count": String(newItems.count),
                "total_count": String(page.totalCount),
                "has_more_data": String(hasMoreData)
            ])
            
            // Explicitly log when empty results are loaded (important for debugging date filtering issues)
            if newItems.isEmpty && page.totalCount == 0 {
                logger.info("Empty result set loaded")
            } else if !newItems.isEmpty {
                // Log first item's date for debugging
                let firstItemDate = Calendar.current.startOfDay(for: newItems[0].requestDate)
                logger.info("Validated data loaded")
            }
        }
        
        logger.safeInfo("Final load state", [
            "items_count": String(items.count),
            "total_count": String(totalRecordsCount),
            "has_more_data": String(hasMoreData),
            "current_page": String(currentPage)
        ])
        
        // Force UI refresh
        objectWillChange.send()
        
        // Log filter operation for security auditing (only on new data load, not append)
        if !append && !isPlaceholder {
            Task {
                await logCurrentFilterOperation(resultCount: page.items.count)
            }
        }
    }
    
    // MARK: - Date Range Helpers
    
    static func createDateRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return (start: startOfDay, end: endOfDay)
    }
    
    // MARK: - Status Count Management
    
    func loadStatusCounts(criteria: OutOfStockFilterCriteria) async -> [OutOfStockStatus: Int] {
        guard !isPlaceholder else { return [:] }
        
        // Check cache first for ultra-fast response
        if let cachedCounts = cacheManager.getCachedStatusCounts(for: criteria) {
            logger.info("Using cached status counts")
            return cachedCounts
        }
        
        do {
            let statusCounts = try await customerOutOfStockRepository.countOutOfStockRecordsByStatus(criteria: criteria)
            logger.info("Loaded status counts")
            
            // Cache the result for future use
            cacheManager.cacheStatusCounts(statusCounts, for: criteria)
            
            return statusCounts
        } catch {
            logger.safeError("Failed to load status counts", error: error)
            return [:]
        }
    }
    
    func loadUnfilteredTotalCount(criteria: OutOfStockFilterCriteria) async -> Int {
        guard !isPlaceholder else { return 0 }
        
        do {
            // Create criteria without status or search filters [rule:§3.2 Repository Protocol]
            let unfilteredCriteria = OutOfStockFilterCriteria(
                dateRange: criteria.dateRange,
                page: 0,
                pageSize: 1
            )
            
            let result = try await customerOutOfStockRepository.fetchOutOfStockRecords(
                criteria: unfilteredCriteria,
                page: 0,
                pageSize: 1
            )
            
            logger.info("Loaded unfiltered total count")
            return result.totalCount
        } catch {
            logger.safeError("Failed to load unfiltered total count", error: error)
            return 0
        }
    }
    
    func getFilteredCount(criteria: OutOfStockFilterCriteria) async -> Int {
        guard !isPlaceholder else { return 0 }
        
        // Check cache first for ultra-fast response
        if let cachedCount = cacheManager.getCachedCount(for: criteria) {
            logger.info("Using cached filtered count")
            return cachedCount
        }
        
        do {
            let result = try await customerOutOfStockRepository.fetchOutOfStockRecords(
                criteria: criteria,
                page: 0,
                pageSize: 1
            )
            
            // Cache the result for future use
            cacheManager.cacheCount(result.totalCount, for: criteria)
            
            logger.info("Loaded filtered count for preview")
            return result.totalCount
        } catch {
            logger.safeError("Failed to get filtered count", error: error)
            return 0
        }
    }
    
    /// Fast path for "clear all" counts - uses dedicated caching
    func getClearAllFilteredCount() async -> Int {
        guard !isPlaceholder else { return 0 }
        
        // Check special "clear all" cache first
        if let cachedCount = cacheManager.getCachedClearAllCount() {
            logger.info("Using cached clear all count")
            return cachedCount
        }
        
        let clearAllCriteria = OutOfStockFilterCriteria(
            customer: nil,
            product: nil,
            status: nil,
            dateRange: nil,
            searchText: "",
            page: 0,
            pageSize: 1
        )
        
        do {
            let result = try await customerOutOfStockRepository.fetchOutOfStockRecords(
                criteria: clearAllCriteria,
                page: 0,
                pageSize: 1
            )
            
            // Cache with highest priority
            cacheManager.cacheClearAllCount(result.totalCount)
            
            logger.info("Loaded clear all count")
            return result.totalCount
        } catch {
            logger.safeError("Failed to get clear all count", error: error)
            return 0
        }
    }
    
    // MARK: - Cache Management
    
    func invalidateCache(currentDate: Date) async {
        await cacheManager.clearAllCaches()
        await loadDataForDate(currentDate)
    }
    
    func invalidateCacheForDate(_ date: Date) async {
        await cacheManager.invalidateCache(for: date)
    }
    
    // MARK: - Single Item Creation
    
    func createOutOfStockItem(_ request: OutOfStockCreationRequest) async throws {
        let currentUser = try getCurrentUser()
        
        let item = CustomerOutOfStock(
            customer: request.customer,
            product: request.product,
            productSize: request.productSize,
            quantity: request.quantity,
            notes: request.notes,
            createdBy: currentUser.id
        )
        
        try await customerOutOfStockRepository.addOutOfStockRecord(item)
        
        // Log the creation
        await auditService.logCustomerOutOfStockCreation(
            item: item,
            operatorUserId: currentUser.id,
            operatorUserName: currentUser.name
        )
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    // MARK: - Batch Creation
    
    func createMultipleOutOfStockItems(_ requests: [OutOfStockCreationRequest]) async throws {
        let currentUser = try getCurrentUser()
        var createdItems: [CustomerOutOfStock] = []
        
        for request in requests {
            let item = CustomerOutOfStock(
                customer: request.customer,
                product: request.product,
                productSize: request.productSize,
                quantity: request.quantity,
                notes: request.notes,
                createdBy: currentUser.id
            )
            
            try await customerOutOfStockRepository.addOutOfStockRecord(item)
            createdItems.append(item)
            
            // Log creation immediately
            await auditService.logCustomerOutOfStockCreation(
                item: item,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name
            )
        }
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    // MARK: - Item Updates
    
    func updateOutOfStockItem(
        _ item: CustomerOutOfStock,
        customer: Customer?,
        product: Product?,
        productSize: ProductSize?,
        quantity: Int,
        notes: String?
    ) async throws {
        let currentUser = try getCurrentUser()
        
        // Capture before values for audit
        let beforeValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            status: item.status.displayName,
            notes: item.notes,
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
        
        // Track changed fields
        var changedFields: [String] = []
        
        if item.customer?.id != customer?.id {
            changedFields.append("customer")
            item.customer = customer
        }
        
        if item.product?.id != product?.id {
            changedFields.append("product")
            item.product = product
        }
        
        if item.productSize != productSize {
            changedFields.append("productSize")
            item.productSize = productSize
        }
        
        if item.quantity != quantity {
            changedFields.append("quantity")
            item.quantity = quantity
        }
        
        let newNotes = notes?.isEmpty == true ? nil : notes
        if item.notes != newNotes {
            changedFields.append("notes")
            item.notes = newNotes
        }
        
        item.updatedAt = Date()
        
        // Log changes if any
        if !changedFields.isEmpty {
            await auditService.logCustomerOutOfStockUpdate(
                item: item,
                beforeValues: beforeValues,
                changedFields: changedFields,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                additionalInfo: "字段更新: \(changedFields.joined(separator: ", "))"
            )
        }
        
        try await customerOutOfStockRepository.updateOutOfStockRecord(item)
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    // MARK: - Return Processing
    
    func processReturn(_ request: ReturnProcessingRequest) async throws {
        let currentUser = try getCurrentUser()
        let item = request.item
        
        // Validate return quantity
        guard request.returnQuantity > 0 && request.returnQuantity <= item.remainingQuantity else {
            throw ServiceError.invalidReturnQuantity
        }
        
        // Update return information
        item.returnQuantity += request.returnQuantity
        item.returnDate = Date()
        item.returnNotes = request.returnNotes
        item.updatedAt = Date()
        
        // Update status based on return progress
        if item.returnQuantity >= item.quantity {
            item.status = .completed
        }
        
        // Log return processing
        await auditService.logReturnProcessing(
            item: item,
            returnQuantity: request.returnQuantity,
            returnNotes: request.returnNotes,
            operatorUserId: currentUser.id,
            operatorUserName: currentUser.name
        )
        
        try await customerOutOfStockRepository.updateOutOfStockRecord(item)
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    // MARK: - Batch Return Processing
    
    func processBatchReturns(_ requests: [ReturnProcessingRequest]) async throws {
        let currentUser = try getCurrentUser()
        
        for request in requests {
            let item = request.item
            
            // Validate return quantity
            guard request.returnQuantity > 0 && request.returnQuantity <= item.remainingQuantity else {
                continue // Skip invalid items
            }
            
            // Update return information
            item.returnQuantity += request.returnQuantity
            item.returnDate = Date()
            item.returnNotes = request.returnNotes
            item.updatedAt = Date()
            
            // Update status based on return progress
            if item.returnQuantity >= item.quantity {
                item.status = .completed
            }
            
            // Log return processing
            await auditService.logReturnProcessing(
                item: item,
                returnQuantity: request.returnQuantity,
                returnNotes: request.returnNotes,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name
            )
            
            // Update each item immediately
            try await customerOutOfStockRepository.updateOutOfStockRecord(item)
        }
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    // MARK: - Item Deletion
    
    func deleteOutOfStockItem(_ item: CustomerOutOfStock) async throws {
        let currentUser = try getCurrentUser()
        
        // Log deletion
        await auditService.logCustomerOutOfStockDeletion(
            item: item,
            operatorUserId: currentUser.id,
            operatorUserName: currentUser.name
        )
        
        try await customerOutOfStockRepository.deleteOutOfStockRecord(item)
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    // MARK: - Batch Operations
    
    func deleteBatchItems(_ items: [CustomerOutOfStock]) async throws {
        let currentUser = try getCurrentUser()
        
        // Log batch deletion and delete items
        for item in items {
            await auditService.logCustomerOutOfStockDeletion(
                item: item,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name
            )
        }
        
        try await customerOutOfStockRepository.deleteOutOfStockRecords(items)
        
        // Note: Data refresh should be handled by the calling view/state manager
        await invalidateCache(currentDate: Date())
    }
    
    /// Cache base data (without status filter) for incremental filtering
    private func cacheBaseDataIfApplicable(_ page: CachedOutOfStockPage, criteria: OutOfStockFilterCriteria) async {
        // Only cache base data if this is a full load without status filtering
        guard criteria.status == nil else {
            logger.info("Not caching base data - has status filter")
            return
        }
        
        // Create base criteria (same as original but ensure no status filter)
        let baseCriteria = OutOfStockFilterCriteria(
            customer: criteria.customer,
            product: criteria.product,
            status: nil,
            dateRange: criteria.dateRange,
            searchText: criteria.searchText,
            page: criteria.page,
            pageSize: criteria.pageSize,
            sortOrder: criteria.sortOrder
        )
        
        cacheManager.cacheBaseData(page.items, for: baseCriteria)
        logger.info("Cached base data for incremental filtering")
    }
    
    /// Try to apply status filtering on cached base data for ultra-fast switching
    private func tryIncrementalStatusFiltering(criteria: OutOfStockFilterCriteria) async -> Bool {
        // Only use incremental filtering if this is a status-only change
        guard let statusFilter = criteria.status,
              criteria.searchText.isEmpty else {
            logger.info("Incremental filtering not applicable")
            return false
        }
        
        // Try to get base data from cache (without status filter)
        let baseCriteria = OutOfStockFilterCriteria(
            customer: criteria.customer,
            product: criteria.product,
            status: nil, // No status filter for base data
            dateRange: criteria.dateRange,
            searchText: criteria.searchText,
            page: 0,
            pageSize: criteria.pageSize,
            sortOrder: criteria.sortOrder
        )
        
        // Check if we have cached base data
        if let baseItems = cacheManager.getCachedBaseData(for: baseCriteria) {
            logger.info("Found cached base data")
            
            // Apply status filtering in memory
            let filteredItems = baseItems.filter { dto in
                OutOfStockStatus(rawValue: dto.status) == statusFilter
            }
            logger.safeInfo("Status filtering result", [
                "filtered_count": String(filteredItems.count),
                "status": statusFilter.displayName
            ])
            
            // Create a cached page with filtered results
            let filteredPage = CachedOutOfStockPage(
                items: filteredItems,
                totalCount: filteredItems.count,
                hasMoreData: false // All data is already loaded for status filtering
            )
            
            // Update current criteria
            currentCriteria = criteria
            
            // Update UI with filtered results
            await updateUIWithData(filteredPage, append: false)
            return true
        }
        
        logger.info("No cached base data found, falling back to full load")
        return false
    }
    
    /// Create fallback cached page when DTO conversion fails
    private func createFallbackCachedPage(from result: OutOfStockPaginationResult) -> CachedOutOfStockPage {
        // Create DTOs directly without caching to avoid thread issues
        let dtoItems = result.items.map { item in
            CustomerOutOfStockDTO(from: item)
        }
        return CachedOutOfStockPage(
            items: dtoItems,
            totalCount: result.totalCount,
            hasMoreData: result.hasMoreData,
            priority: .normal
        )
    }
    
    /// Convert DTOs back to CustomerOutOfStock models for UI compatibility (main thread only)
    @MainActor
    private func convertDTOsToModelsForDisplay(_ dtos: [CustomerOutOfStockDTO]) -> [CustomerOutOfStock] {
        // This is a temporary solution for display compatibility
        // In a full refactor, we'd update the UI to work with DTOs directly
        return dtos.compactMap { dto in
            // Embed display names in notes field for orphaned record handling
            let displayInfo = createDisplayInfoString(
                customerName: dto.customerDisplayName,
                customerAddress: dto.customerDisplayAddress,
                customerPhone: dto.customerDisplayPhone,
                productName: dto.productDisplayName
            )
            
            // Combine display info with original notes
            let combinedNotes = combineNotesWithDisplayInfo(originalNotes: dto.notes, displayInfo: displayInfo)
            
            // Create a display-only CustomerOutOfStock (without relationships)
            let item = CustomerOutOfStock(
                customer: nil, // We'll use the cached name from notes via display info
                product: nil,  // We'll use the cached name from notes via display info
                quantity: dto.quantity,
                notes: combinedNotes,
                createdBy: dto.createdBy
            )
            item.id = dto.id
            item.status = OutOfStockStatus(rawValue: dto.status) ?? .pending
            item.requestDate = dto.requestDate
            item.actualCompletionDate = dto.actualCompletionDate
            item.updatedAt = dto.updatedAt
            item.returnQuantity = dto.returnQuantity
            item.returnDate = dto.returnDate
            item.returnNotes = dto.returnNotes
            return item
        }
    }
    
    /// Create display info string to embed in notes
    private func createDisplayInfoString(customerName: String, customerAddress: String, customerPhone: String, productName: String) -> String {
        return "DISPLAY_INFO:{\(customerName)|\(customerAddress)|\(customerPhone)|\(productName)}"
    }
    
    /// Combine original notes with display info, filtering out existing display info
    private func combineNotesWithDisplayInfo(originalNotes: String?, displayInfo: String) -> String {
        // Filter out any existing DISPLAY_INFO from original notes
        let cleanedNotes: String
        if let notes = originalNotes {
            // Remove existing DISPLAY_INFO pattern
            let pattern = "DISPLAY_INFO:\\{[^}]*\\}\\s*"
            cleanedNotes = notes.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleanedNotes = ""
        }
        
        // Combine display info with cleaned notes
        if cleanedNotes.isEmpty {
            return displayInfo
        } else {
            return "\(displayInfo) \(cleanedNotes)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUser() throws -> (id: String, name: String) {
        guard let currentUser = authService.currentUser else {
            throw CustomerOutOfStockServiceError.userNotAuthenticated
        }
        
        // 验证用户session是否有效
        if !authService.isSessionValid() {
            throw CustomerOutOfStockServiceError.sessionExpired
        }
        
        return (id: currentUser.id, name: currentUser.name)
    }
    
    func getItemsByCustomer(_ customer: Customer) -> [CustomerOutOfStock] {
        return items.filter { $0.customer?.id == customer.id }
    }
    
    func getReturnableItems() -> [CustomerOutOfStock] {
        return items.filter { $0.needsReturn || $0.hasPartialReturn }
    }
    
    func getItemsGroupedByCustomer() -> [String: [CustomerOutOfStock]] {
        return Dictionary(grouping: getReturnableItems()) { item in
            item.customer?.name ?? "未知客户"
        }
    }
    
    // MARK: - Audit Logging Helper
    
    private func logCurrentFilterOperation(resultCount: Int) async {
        guard !isPlaceholder else { return }
        
        // 安全地获取用户信息，如果认证失败则跳过日志记录
        guard let currentUser = try? getCurrentUser() else {
            logger.safeWarning("Cannot log filter operation - user not authenticated")
            return
        }
        let status = currentCriteria.status?.rawValue ?? "all"
        
        var additionalContext: [String: Any] = [:]
        if let customer = currentCriteria.customer {
            additionalContext["customer_id"] = customer.id
            additionalContext["customer_name"] = customer.name
        }
        if let product = currentCriteria.product {
            additionalContext["product_id"] = product.id
            additionalContext["product_name"] = product.name
        }
        if let dateRange = currentCriteria.dateRange {
            additionalContext["date_start"] = dateRange.start.timeIntervalSince1970
            additionalContext["date_end"] = dateRange.end.timeIntervalSince1970
        }
        if !currentCriteria.searchText.isEmpty {
            additionalContext["search_text"] = currentCriteria.searchText
        }
        
        await auditService.logFilterOperation(
            userId: currentUser.id,
            userName: currentUser.name,
            filterType: "OutOfStockStatus",
            filterValue: status,
            resultCount: resultCount,
            additionalContext: additionalContext
        )
    }
}

// MARK: - Service Errors
enum ServiceError: Error, LocalizedError {
    case invalidReturnQuantity
    case itemNotFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidReturnQuantity:
            return "还货数量无效"
        case .itemNotFound:
            return "记录不存在"
        case .unauthorized:
            return "没有权限执行此操作"
        }
    }
}

// MARK: - Audit Service Extensions
extension NewAuditingService {
    func logCustomerOutOfStockCreation(
        item: CustomerOutOfStock,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        // Implementation would depend on your audit service structure
        let logger = Logger(subsystem: "com.lopan.app", category: "AuditService")
        logger.safeInfo("Audit: Customer out of stock item created", [
            "product": item.productDisplayName,
            "customer_name": item.customer?.name ?? "Unknown"
        ])
    }
    
    func logCustomerOutOfStockUpdate(
        item: CustomerOutOfStock,
        beforeValues: CustomerOutOfStockOperation.CustomerOutOfStockValues,
        changedFields: [String],
        operatorUserId: String,
        operatorUserName: String,
        additionalInfo: String
    ) async {
        let logger = Logger(subsystem: "com.lopan.app", category: "AuditService")
        logger.safeInfo("Audit: Customer out of stock item updated", [
            "additional_info": additionalInfo
        ])
    }
    
    func logCustomerOutOfStockDeletion(
        item: CustomerOutOfStock,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let logger = Logger(subsystem: "com.lopan.app", category: "AuditService")
        logger.safeInfo("Audit: Customer out of stock item deleted", [
            "product": item.productDisplayName,
            "customer_name": item.customer?.name ?? "Unknown"
        ])
    }
    
    func logReturnProcessing(
        item: CustomerOutOfStock,
        returnQuantity: Int,
        returnNotes: String?,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let logger = Logger(subsystem: "com.lopan.app", category: "AuditService")
        logger.safeInfo("Audit: Return processed", [
            "return_quantity": String(returnQuantity),
            "product": item.productDisplayName
        ])
    }
}
