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
class CustomerOutOfStockCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    private let dataService: CustomerOutOfStockDataService
    private let businessService: CustomerOutOfStockBusinessService
    private let cacheService: CustomerOutOfStockCacheService
    private let auditService: AuditingService
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
    
    // MARK: - Initialization
    
    init(
        dataService: CustomerOutOfStockDataService,
        businessService: CustomerOutOfStockBusinessService,
        cacheService: CustomerOutOfStockCacheService,
        auditService: AuditingService,
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
            auditService: MockAuditingService(),
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
        
        await loadFilteredItems(criteria: newCriteria, resetPagination: resetPagination)
    }
    
    func loadFilteredItems(criteria: OutOfStockFilterCriteria, resetPagination: Bool = true) async {
        logger.safeInfo("Loading filtered items", [
            "resetPagination": String(resetPagination),
            "page": String(criteria.page)
        ])
        
        let validatedCriteria = validateAndNormalizeCriteria(criteria)
        currentCriteria = validatedCriteria
        
        let append = !resetPagination && validatedCriteria.page > 0
        await loadPage(criteria: validatedCriteria, append: append)
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
        await auditService.logCustomerOutOfStockUpdate(
            item: item,
            beforeValues: beforeValues,
            changedFields: ["updated"], // TODO: Track actual changed fields
            operatorUserId: getCurrentUserId(),
            operatorUserName: getCurrentUserName()
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
            returnQuantity: quantity,
            returnNotes: notes,
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
            return try await businessService.getStatusCounts(criteria)
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
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
    }
}

// MARK: - Mock Implementations for Testing

private class MockCustomerOutOfStockDataService: CustomerOutOfStockDataService {
    func fetchRecords(_ criteria: OutOfStockFilterCriteria) async throws -> [CustomerOutOfStock] { [] }
    func countRecords(_ criteria: OutOfStockFilterCriteria) async throws -> Int { 0 }
    func createRecord(_ request: OutOfStockCreationRequest) async throws -> CustomerOutOfStock { 
        fatalError("Mock implementation") 
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
    func invalidateCache() {}
    func invalidateCache(for criteria: OutOfStockFilterCriteria) {}
    func getMemoryUsage() -> CacheMemoryUsage { 
        CacheMemoryUsage(recordsCount: 0, approximateMemoryUsage: 0, cacheHitRate: 0, lastEvictionTime: nil) 
    }
    func handleMemoryPressure() {}
}

private class MockAuditingService: AuditingService {
    init() {
        super.init(auditRepository: MockAuditRepository())
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

private class PlaceholderRepositoryFactory: RepositoryFactory {
    // Use placeholder implementations for now
    var userRepository: UserRepository { fatalError("Mock not implemented") }
    var customerRepository: CustomerRepository { fatalError("Mock not implemented") }
    var productRepository: ProductRepository { fatalError("Mock not implemented") }
    var customerOutOfStockRepository: CustomerOutOfStockRepository { fatalError("Mock not implemented") }
    var packagingRepository: PackagingRepository { fatalError("Mock not implemented") }
    var productionRepository: ProductionRepository { fatalError("Mock not implemented") }
    var auditRepository: AuditRepository = MockAuditRepository()
    var machineRepository: MachineRepository { fatalError("Mock not implemented") }
    var colorRepository: ColorRepository { fatalError("Mock not implemented") }
    var productionBatchRepository: ProductionBatchRepository { fatalError("Mock not implemented") }
}