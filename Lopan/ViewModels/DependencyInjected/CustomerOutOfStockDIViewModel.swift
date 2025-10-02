//
//  CustomerOutOfStockDIViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation
import SwiftUI
import Combine

/// Customer Out of Stock ViewModel using Dependency Injection
@MainActor
class CustomerOutOfStockDIViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var items: [CustomerOutOfStock] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: Error?
    @Published var hasMoreData = true
    @Published var currentPage = 0
    @Published var totalCount = 0
    @Published var statusCounts: [OutOfStockStatus: Int] = [:]
    
    // Filter states
    @Published var searchText = ""
    @Published var selectedCustomer: Customer?
    @Published var selectedProduct: Product?
    @Published var selectedProductSize: ProductSize?
    @Published var selectedAddress: String?
    @Published var statusFilter: CustomerOutOfStockNavigationState.StatusFilter = .all
    @Published var selectedDate = Date()
    @Published var dateFilterMode: DateFilterOption?
    @Published var customDateRange: (start: Date, end: Date)?
    @Published var sortOrder: CustomerOutOfStockNavigationState.SortOrder = .newestFirst
    
    // UI States
    @Published var showingFilterSheet = false
    @Published var showingAddSheet = false
    @Published var selectedItems: Set<String> = []
    @Published var isInSelectionMode = false
    @Published var showingDeleteConfirmation = false
    @Published var showingBatchOperations = false
    
    // Animation states
    @Published var listItemAnimationOffset: CGFloat = 100
    @Published var filterChipAnimationScale: CGFloat = 0.8
    
    // MARK: - Dependencies
    
    private let dependencies: CustomerOutOfStockDependencies
    private let navigationState = CustomerOutOfStockNavigationState.shared
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 50
    
    // Debounced search
    private let searchDebouncer = Debouncer(delay: 0.3)
    
    // Performance tracking
    private var loadStartTime: Date?
    private var renderStartTime: Date?
    
    // MARK: - Initialization
    
    init(dependencies: CustomerOutOfStockDependencies) {
        self.dependencies = dependencies
        setupBindings()
        setupInitialState()
        
        // Load initial data
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Dependency Access
    
    private var customerOutOfStockService: CustomerOutOfStockService {
        dependencies.customerOutOfStockService
    }
    
    private var customerRepository: CustomerRepository {
        dependencies.customerRepository
    }
    
    private var productRepository: ProductRepository {
        dependencies.productRepository
    }
    
    private var auditingService: NewAuditingService {
        dependencies.auditingService
    }
    
    private var authenticationService: AuthenticationService {
        dependencies.authenticationService
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Sync with navigation state
        navigationState.$selectedDate
            .sink { [weak self] date in
                self?.selectedDate = date
            }
            .store(in: &cancellables)
        
        navigationState.$selectedCustomer
            .sink { [weak self] customer in
                self?.selectedCustomer = customer
            }
            .store(in: &cancellables)
        
        navigationState.$selectedProduct
            .sink { [weak self] product in
                self?.selectedProduct = product
            }
            .store(in: &cancellables)
        
        // Search text debouncing
        $searchText
            .dropFirst()
            .sink { [weak self] searchText in
                self?.searchDebouncer.debounce { [weak self] in
                    Task { @MainActor in
                        await self?.performSearch(searchText)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Filter change handling
        Publishers.CombineLatest4($statusFilter, $selectedCustomer, $selectedProduct, $dateFilterMode)
            .dropFirst()
            .sink { [weak self] _, _, _, _ in
                Task { [weak self] in
                    await self?.applyFilters()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialState() {
        // Sync initial state with navigation
        selectedDate = navigationState.selectedDate
        selectedCustomer = navigationState.selectedCustomer
        selectedProduct = navigationState.selectedProduct
        
        // Setup animations
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            listItemAnimationOffset = 0
            filterChipAnimationScale = 1.0
        }
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() async {
        loadStartTime = Date()
        isLoading = true
        currentPage = 0
        hasMoreData = true
        error = nil
        
        await loadData(refresh: true)
    }
    
    func loadMoreData() async {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        currentPage += 1
        await loadData(refresh: false)
    }
    
    private func loadData(refresh: Bool) async {
        do {
            let criteria = buildFilterCriteria()
            let result = try await customerOutOfStockService.fetchOutOfStockRecords(
                criteria: criteria,
                page: currentPage,
                pageSize: pageSize
            )
            
            if refresh {
                items = result.items
            } else {
                items.append(contentsOf: result.items)
            }
            
            totalCount = result.totalCount
            hasMoreData = result.hasMoreData
            
            // Load status counts
            await loadStatusCounts()
            
            // Performance tracking
            if let startTime = loadStartTime {
                let loadTime = Date().timeIntervalSince(startTime)
                print("📊 Data loaded in \(String(format: "%.2f", loadTime))s - \(items.count) items")
            }
            
        } catch {
            self.error = error
            print("❌ Failed to load data: \(error)")
        }
        
        isLoading = false
        isLoadingMore = false
        loadStartTime = nil
    }
    
    private func loadStatusCounts() async {
        do {
            let criteria = buildFilterCriteria()
            statusCounts = try await customerOutOfStockService.countOutOfStockRecordsByStatus(criteria: criteria)
        } catch {
            print("❌ Failed to load status counts: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func createRecord(_ record: CustomerOutOfStock) async {
        do {
            let createdRecord = try await customerOutOfStockService.createRecord(record)
            
            // Add to the beginning of the list
            items.insert(createdRecord, at: 0)
            totalCount += 1
            
            // Update status counts
            await loadStatusCounts()
            
            // Log audit event
            await auditingService.logEvent(
                action: "CREATE_OUT_OF_STOCK_RECORD",
                entityId: createdRecord.id,
                details: "Created out of stock record for \(record.customer?.name ?? "unknown customer")"
            )
            
        } catch {
            self.error = error
            print("❌ Failed to create record: \(error)")
        }
    }
    
    func updateRecord(_ record: CustomerOutOfStock) async {
        do {
            let updatedRecord = try await customerOutOfStockService.updateRecord(record)
            
            // Update in list
            if let index = items.firstIndex(where: { $0.id == record.id }) {
                items[index] = updatedRecord
            }
            
            // Update status counts
            await loadStatusCounts()
            
            // Log audit event
            await auditingService.logEvent(
                action: "UPDATE_OUT_OF_STOCK_RECORD",
                entityId: updatedRecord.id,
                details: "Updated out of stock record status to \(updatedRecord.status.rawValue)"
            )
            
        } catch {
            self.error = error
            print("❌ Failed to update record: \(error)")
        }
    }
    
    func deleteRecords(_ recordIds: [String]) async {
        do {
            let recordsToDelete = items.filter { recordIds.contains($0.id) }
            try await customerOutOfStockService.deleteRecords(recordsToDelete.map { $0.id })
            
            // Remove from list
            items.removeAll { recordIds.contains($0.id) }
            totalCount -= recordIds.count
            
            // Clear selection
            selectedItems.removeAll()
            isInSelectionMode = false
            
            // Update status counts
            await loadStatusCounts()
            
            // Log audit event
            await auditingService.logEvent(
                action: "DELETE_OUT_OF_STOCK_RECORDS",
                entityId: recordIds.joined(separator: ","),
                details: "Deleted \(recordIds.count) out of stock records"
            )
            
        } catch {
            self.error = error
            print("❌ Failed to delete records: \(error)")
        }
    }
    
    // MARK: - Batch Operations
    
    func batchUpdateStatus(_ status: OutOfStockStatus, for recordIds: [String]) async {
        do {
            var recordsToUpdate = items.filter { recordIds.contains($0.id) }
            for i in recordsToUpdate.indices {
                recordsToUpdate[i].status = status
                recordsToUpdate[i].updatedAt = Date()
                if let currentUser = authenticationService.currentUser {
                    recordsToUpdate[i].updatedBy = currentUser.id
                }
            }
            
            let updatedRecords = try await customerOutOfStockService.batchUpdateRecords(recordsToUpdate)
            
            // Update items in the list
            for updatedRecord in updatedRecords {
                if let index = items.firstIndex(where: { $0.id == updatedRecord.id }) {
                    items[index] = updatedRecord
                }
            }
            
            // Clear selection
            selectedItems.removeAll()
            isInSelectionMode = false
            
            // Update status counts
            await loadStatusCounts()
            
            // Log audit event
            await auditingService.logEvent(
                action: "BATCH_UPDATE_STATUS",
                entityId: recordIds.joined(separator: ","),
                details: "Updated \(recordIds.count) records to status: \(status.rawValue)"
            )
            
        } catch {
            self.error = error
            print("❌ Failed to batch update status: \(error)")
        }
    }
    
    // MARK: - Search & Filtering
    
    private func performSearch(_ searchText: String) async {
        self.searchText = searchText
        await loadInitialData()
    }
    
    func applyFilters() async {
        await loadInitialData()
    }
    
    func clearFilters() async {
        searchText = ""
        selectedCustomer = nil
        selectedProduct = nil
        selectedProductSize = nil
        selectedAddress = nil
        statusFilter = .all
        dateFilterMode = nil
        customDateRange = nil
        
        await loadInitialData()
    }
    
    private func buildFilterCriteria() -> OutOfStockFilterCriteria {
        var criteria = OutOfStockFilterCriteria()
        criteria.searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        criteria.customer = selectedCustomer
        criteria.product = selectedProduct
        
        // Status filter
        switch statusFilter {
        case .all:
            criteria.status = nil
        case .pending:
            criteria.status = .pending
        case .completed:
            criteria.status = .completed
        case .refunded:
            criteria.status = .refunded
        }
        
        // Date filter
        if let dateMode = dateFilterMode {
            switch dateMode {
            case .today:
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
                criteria.dateRange = (start: startOfDay, end: endOfDay)
            case .thisWeek:
                let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek) ?? Date()
                criteria.dateRange = (start: startOfWeek, end: endOfWeek)
            case .thisMonth:
                let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
                let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? Date()
                criteria.dateRange = (start: startOfMonth, end: endOfMonth)
            case .custom:
                criteria.dateRange = customDateRange
            }
        }
        
        return criteria
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for recordId: String) {
        if selectedItems.contains(recordId) {
            selectedItems.remove(recordId)
        } else {
            selectedItems.insert(recordId)
        }
        
        if selectedItems.isEmpty {
            isInSelectionMode = false
        }
    }
    
    func selectAllVisible() {
        selectedItems = Set(items.map { $0.id })
        isInSelectionMode = true
    }
    
    func deselectAll() {
        selectedItems.removeAll()
        isInSelectionMode = false
    }
    
    // MARK: - Utility Methods
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func getSelectedRecords() -> [CustomerOutOfStock] {
        return items.filter { selectedItems.contains($0.id) }
    }
    
    // MARK: - Analytics
    
    func getAnalytics() async -> CustomerOutOfStockAnalytics? {
        do {
            let criteria = buildFilterCriteria()
            let stats = try await customerOutOfStockService.calculateStatistics(criteria: criteria)
            
            // Convert [String: Any] to CustomerOutOfStockAnalytics
            let totalRecords = stats["totalCount"] as? Int ?? 0
            let statusBreakdown = stats["statusBreakdown"] as? [OutOfStockStatus: Int] ?? [:]
            let averageCompletionTime = stats["averageCompletionTime"] as? TimeInterval
            let topCustomers = stats["topCustomers"] as? [Customer] ?? []
            let topProducts = stats["topProducts"] as? [Product] ?? []
            let trends = stats["trends"] as? [Date: Int] ?? [:]
            
            return CustomerOutOfStockAnalytics(
                totalRecords: totalRecords,
                statusBreakdown: statusBreakdown,
                averageCompletionTime: averageCompletionTime,
                topCustomers: topCustomers,
                topProducts: topProducts,
                trends: trends
            )
        } catch {
            print("❌ Failed to load analytics: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

struct CustomerOutOfStockAnalytics {
    let totalRecords: Int
    let statusBreakdown: [OutOfStockStatus: Int]
    let averageCompletionTime: TimeInterval?
    let topCustomers: [Customer]
    let topProducts: [Product]
    let trends: [Date: Int] // Daily trend data
}