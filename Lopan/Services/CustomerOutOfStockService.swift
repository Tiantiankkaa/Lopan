//
//  CustomerOutOfStockService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation

struct OutOfStockCreationRequest {
    let customer: Customer
    let product: Product
    let productSize: ProductSize?
    let quantity: Int
    let notes: String?
}

struct OutOfStockFilterCriteria {
    let customer: Customer?
    let product: Product?
    let status: OutOfStockStatus?
    let dateRange: (start: Date, end: Date)?
    let searchText: String
    let page: Int
    let pageSize: Int
    let sortOrder: CustomerOutOfStockNavigationState.SortOrder
    
    init(
        customer: Customer? = nil,
        product: Product? = nil,
        status: OutOfStockStatus? = nil,
        dateRange: (start: Date, end: Date)? = nil,
        searchText: String = "",
        page: Int = 0,
        pageSize: Int = 50,
        sortOrder: CustomerOutOfStockNavigationState.SortOrder = .newestFirst
    ) {
        self.customer = customer
        self.product = product
        self.status = status
        self.dateRange = dateRange
        self.searchText = searchText
        self.page = page
        self.pageSize = pageSize
        self.sortOrder = sortOrder
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
    
    private let pageSize = 20 // [rule:§3+.2 API Contract] Reduced to enable better pagination triggering
    private var backgroundQueue = DispatchQueue(label: "customerOutOfStock.processing", qos: .userInitiated)
    
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
        if resetPagination {
            currentPage = 0
            // Force clear items array immediately to prevent stale data display
            await MainActor.run {
                items = []
                totalRecordsCount = 0
            }
            hasMoreData = true // [rule:§3+.2 API Contract] Always assume more data initially
            print("📊 [Service] Reset pagination for filtered items - criteria has status: \(criteria.status?.displayName ?? "None")")
        } else {
            // 从criteria更新currentPage，确保页码状态同步
            currentPage = criteria.page
        }
        
        // Validate date criteria to prevent cross-date contamination
        let requestedDate = criteria.dateRange?.start ?? Date()
        let currentDate = currentCriteria.dateRange?.start ?? Date()
        let calendar = Calendar.current
        
        // If switching dates, force reset pagination and clear cache
        if !calendar.isDate(requestedDate, inSameDayAs: currentDate) && resetPagination {
            print("📅 [Service] Date changed from \(currentDate) to \(requestedDate), clearing cache")
            await invalidateCacheForDate(requestedDate)
        }
        
        currentCriteria = criteria
        await loadPage(criteria: criteria, date: requestedDate, append: !resetPagination)
        
        print("📊 [Service] Loaded filtered items: \(items.count), hasMore: \(hasMoreData), totalCount: \(totalRecordsCount)")
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
            // Create cache key using criteria's dateRange for consistency
            let cacheKeyDate = criteria.dateRange?.start ?? date
            let cacheKey = OutOfStockCacheKey(
                date: cacheKeyDate,
                criteria: criteria,
                page: criteria.page
            )
            
            print("📊 [Service] Creating cache key with date=\(cacheKeyDate), status=\(criteria.status?.displayName ?? "all")")
            
            // Try to get from cache first
            if let cachedPage = await cacheManager.getCachedPage(for: cacheKey) {
                await updateUIWithData(cachedPage, append: append)
                return
            }
            
            // Fetch from repository
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
                    }
                    
                    // Update UI immediately with the data
                    Task { @MainActor in
                        await self.updateUIWithData(cachedPage, append: append)
                    }
                } catch {
                    // If caching fails, still update UI with data
                    print("⚠️ Cache conversion failed: \(error), continuing without cache")
                    let simpleCachedPage = self.createFallbackCachedPage(from: result)
                    Task { @MainActor in
                        await self.updateUIWithData(simpleCachedPage, append: append)
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                print("Error loading page: \(error)")
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
            
            print("📊 [Service] Appending \(uniqueNewItems.count) unique items (filtered \(newItems.count - uniqueNewItems.count) duplicates)")
            items.append(contentsOf: uniqueNewItems)
            
            // For append operations, check if we have more data to load [rule:§3+.2 API Contract]
            hasMoreData = page.hasMoreData && (items.count < page.totalCount)
            
            print("📊 [Service] After append: items=\(items.count), total=\(page.totalCount), repoHasMore=\(page.hasMoreData), serviceHasMore=\(hasMoreData)")
        } else {
            // For initial/replacement loads, validate data consistency before updating UI
            if !newItems.isEmpty {
                // Validate that all items match the current filter criteria date range
                if let dateRange = currentCriteria.dateRange {
                    let expectedDate = Calendar.current.startOfDay(for: dateRange.start)
                    var dateValidationFailed = false
                    
                    for item in newItems {
                        let itemDate = Calendar.current.startOfDay(for: item.requestDate)
                        if itemDate != expectedDate {
                            print("❌ [Service] Data validation failed: Item date \(itemDate) doesn't match expected \(expectedDate)")
                            dateValidationFailed = true
                            break
                        }
                    }
                    
                    // If validation failed, reject the data and keep UI empty
                    if dateValidationFailed {
                        print("🚫 [Service] Rejecting mismatched data, keeping UI empty")
                        items = []
                        totalRecordsCount = 0
                        hasMoreData = false
                        return
                    }
                }
            }
            
            // For initial/replacement loads, always use the new data (even if empty)
            items = newItems
            totalRecordsCount = page.totalCount
            
            // For initial/replacement loads, check if we need to load more pages [rule:§3+.2 API Contract]  
            hasMoreData = page.hasMoreData && (newItems.count < page.totalCount)
            
            print("📊 [Service] Initial/replacement load: items=\(newItems.count), total=\(page.totalCount), repoHasMore=\(page.hasMoreData), serviceHasMore=\(hasMoreData)")
            
            // Explicitly log when empty results are loaded (important for debugging date filtering issues)
            if newItems.isEmpty && page.totalCount == 0 {
                print("🗂️ [Service] Empty result set loaded - no items found for current criteria")
            } else if !newItems.isEmpty {
                // Log first item's date for debugging
                let firstItemDate = Calendar.current.startOfDay(for: newItems[0].requestDate)
                print("✅ [Service] Validated data loaded for date: \(firstItemDate)")
            }
        }
        
        print("📊 [Service] Final state: items=\(items.count), total=\(totalRecordsCount), hasMore=\(hasMoreData), currentPage=\(currentPage)")
        
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
        
        do {
            let statusCounts = try await customerOutOfStockRepository.countOutOfStockRecordsByStatus(criteria: criteria)
            print("📊 [Service] Loaded status counts: \(statusCounts)")
            return statusCounts
        } catch {
            print("❌ [Service] Failed to load status counts: \(error)")
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
            
            print("📊 [Service] Loaded unfiltered total count: \(result.totalCount)")
            return result.totalCount
        } catch {
            print("❌ [Service] Failed to load unfiltered total count: \(error)")
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
        let currentUser = getCurrentUser()
        
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
        let currentUser = getCurrentUser()
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
        let currentUser = getCurrentUser()
        
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
        let currentUser = getCurrentUser()
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
        let currentUser = getCurrentUser()
        
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
        let currentUser = getCurrentUser()
        
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
        let currentUser = getCurrentUser()
        
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
    
    private func getCurrentUser() -> (id: String, name: String) {
        guard let currentUser = authService.currentUser else {
            fatalError("Attempted to access customer out-of-stock service without authentication. User must be logged in.")
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
        
        let currentUser = getCurrentUser()
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
        print("Audit: Customer out of stock item created - \(item.productDisplayName) for \(item.customer?.name ?? "Unknown")")
    }
    
    func logCustomerOutOfStockUpdate(
        item: CustomerOutOfStock,
        beforeValues: CustomerOutOfStockOperation.CustomerOutOfStockValues,
        changedFields: [String],
        operatorUserId: String,
        operatorUserName: String,
        additionalInfo: String
    ) async {
        print("Audit: Customer out of stock item updated - \(additionalInfo)")
    }
    
    func logCustomerOutOfStockDeletion(
        item: CustomerOutOfStock,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        print("Audit: Customer out of stock item deleted - \(item.productDisplayName) for \(item.customer?.name ?? "Unknown")")
    }
    
    func logReturnProcessing(
        item: CustomerOutOfStock,
        returnQuantity: Int,
        returnNotes: String?,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        print("Audit: Return processed - \(returnQuantity) items for \(item.productDisplayName)")
    }
}
