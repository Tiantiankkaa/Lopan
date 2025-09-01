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
            logger.safeInfo("Loading status counts", [
                "hasDateRange": String(criteria.dateRange != nil),
                "dateStart": criteria.dateRange?.start.formatted() ?? "nil",
                "dateEnd": criteria.dateRange?.end.formatted() ?? "nil"
            ])
            
            let statusCounts = try await businessService.getStatusCounts(criteria)
            
            logger.safeInfo("Status counts loaded", [
                "pending": String(statusCounts[.pending] ?? 0),
                "completed": String(statusCounts[.completed] ?? 0),
                "returned": String(statusCounts[.returned] ?? 0)
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
    
    // CRUD operations
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws { 
        print("🔧 MockAuditCustomerOutOfStockRepository: addOutOfStockRecord called - NO-OP in placeholder mode")
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

