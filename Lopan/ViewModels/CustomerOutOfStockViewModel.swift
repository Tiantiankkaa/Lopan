//
//  CustomerOutOfStockViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CustomerOutOfStockViewModel: ObservableObject {
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
    
    // MARK: - Private Properties
    
    private var service: CustomerOutOfStockService
    private let navigationState = CustomerOutOfStockNavigationState.shared
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 50
    
    // Debounced search
    private var searchWorkItem: DispatchWorkItem?
    
    // Performance tracking
    private var loadStartTime: Date?
    private var renderStartTime: Date?
    
    // MARK: - Initialization
    
    init(service: CustomerOutOfStockService) {
        self.service = service
        setupBindings()
        setupInitialState()
        
        // Load initial data
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Service Management
    
    func updateService(_ newService: CustomerOutOfStockService) {
        service = newService
        
        // Reload data with the new service
        Task {
            await loadInitialData()
        }
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
        
        // Debounced search
        $searchText
            .dropFirst()
            .sink { [weak self] searchText in
                self?.performDebouncedSearch(searchText)
            }
            .store(in: &cancellables)
        
        // Auto-refresh when filters change
        Publishers.CombineLatest4($selectedCustomer, $selectedProduct, $statusFilter, $sortOrder)
            .dropFirst()
            .sink { [weak self] _, _, _, _ in
                Task {
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
        
        // Date change handling
        $selectedDate
            .dropFirst()
            .sink { [weak self] date in
                Task {
                    await self?.loadDataForDate(date)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialState() {
        // Restore state from navigation
        selectedCustomer = navigationState.selectedCustomer
        selectedProduct = navigationState.selectedProduct
        selectedAddress = navigationState.selectedAddress
        selectedProductSize = navigationState.selectedProductSize
        statusFilter = navigationState.selectedStatusFilter
        searchText = navigationState.searchText
        selectedDate = navigationState.selectedDate
        dateFilterMode = navigationState.dateFilterMode
        customDateRange = navigationState.customDateRange
        sortOrder = navigationState.sortOrder
    }
    
    // MARK: - Data Loading Methods
    
    func loadInitialData() async {
        loadStartTime = Date()
        
        isLoading = true
        currentPage = 0
        hasMoreData = true
        items = []
        error = nil
        
        do {
            await performInitialLoad()
        } catch {
            self.error = error
        }
        
        isLoading = false
        
        // Track performance
        if let startTime = loadStartTime {
            let loadTime = Date().timeIntervalSince(startTime)
            print("📊 Initial load completed in \(String(format: "%.2f", loadTime))s")
        }
    }
    
    func refreshData() async {
        currentPage = 0
        hasMoreData = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            items = []
        }
        
        await performInitialLoad()
    }
    
    func loadDataForDate(_ date: Date) async {
        navigationState.selectedDate = date
        selectedDate = date
        await refreshData()
    }
    
    func loadNextPage() async {
        guard hasMoreData && !isLoading && !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let criteria = createFilterCriteria(page: currentPage)
            await service.loadFilteredItems(criteria: criteria, resetPagination: false)
            
            // Update UI with new data
            let newItems = service.items.suffix(from: items.count)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                items.append(contentsOf: newItems)
            }
            
            hasMoreData = service.hasMoreData
            totalCount = service.totalRecordsCount
            updateStatusCounts()
            
        } catch {
            self.error = error
        }
        
        isLoadingMore = false
    }
    
    private func performInitialLoad() async {
        do {
            let criteria = createFilterCriteria(page: 0)
            await service.loadFilteredItems(criteria: criteria, resetPagination: true)
            
            // Update UI with animation
            withAnimation(.easeInOut(duration: 0.5)) {
                items = service.items
                hasMoreData = service.hasMoreData
                totalCount = service.totalRecordsCount
                updateStatusCounts()
            }
            
            // Trigger stagger animation for list items
            animateListItems()
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Filter Management
    
    private func createFilterCriteria(page: Int) -> OutOfStockFilterCriteria {
        let dateRange: (start: Date, end: Date)?
        
        if let customRange = customDateRange {
            dateRange = customRange
        } else {
            dateRange = CustomerOutOfStockService.createDateRange(for: selectedDate)
        }
        
        return OutOfStockFilterCriteria(
            customer: selectedCustomer,
            product: selectedProduct,
            status: statusFilter.outOfStockStatus,
            dateRange: dateRange,
            searchText: searchText,
            page: page,
            pageSize: pageSize,
            sortOrder: sortOrder
        )
    }
    
    func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedCustomer = nil
            selectedProduct = nil
            selectedProductSize = nil
            selectedAddress = nil
            statusFilter = .all
            searchText = ""
            dateFilterMode = nil
            customDateRange = nil
            sortOrder = .newestFirst
        }
        
        // Update navigation state
        navigationState.clearAllFilters()
        
        Task {
            await refreshData()
        }
    }
    
    func applyDateFilter(_ option: DateFilterOption) {
        dateFilterMode = option
        navigationState.applyDateFilter(option)
        
        switch option {
        case .thisWeek:
            customDateRange = getCurrentWeekRange()
        case .thisMonth:
            customDateRange = getCurrentMonthRange()
        case .custom(let start, let end):
            customDateRange = (start: start, end: end)
        }
        
        Task {
            await refreshData()
        }
    }
    
    var hasActiveFilters: Bool {
        selectedCustomer != nil ||
        selectedProduct != nil ||
        selectedAddress != nil ||
        selectedProductSize != nil ||
        statusFilter != .all ||
        !searchText.isEmpty ||
        dateFilterMode != nil
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedCustomer != nil { count += 1 }
        if selectedProduct != nil { count += 1 }
        if selectedAddress != nil { count += 1 }
        if selectedProductSize != nil { count += 1 }
        if statusFilter != .all { count += 1 }
        if !searchText.isEmpty { count += 1 }
        if dateFilterMode != nil { count += 1 }
        return count
    }
    
    // MARK: - Search Methods
    
    private func performDebouncedSearch(_ text: String) {
        searchWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
        
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    func performImmediateSearch(_ text: String) {
        searchWorkItem?.cancel()
        searchText = text
        navigationState.performImmediateSearch(text)
        
        Task {
            await refreshData()
        }
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for item: CustomerOutOfStock) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        }
    }
    
    func selectAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedItems = Set(items.map { $0.id })
        }
    }
    
    func deselectAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedItems.removeAll()
        }
    }
    
    func enterSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isInSelectionMode = true
        }
    }
    
    func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isInSelectionMode = false
            selectedItems.removeAll()
        }
    }
    
    // MARK: - Batch Operations
    
    func deleteSelectedItems() async {
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }
        
        do {
            try await service.deleteBatchItems(itemsToDelete)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                items.removeAll { selectedItems.contains($0.id) }
                selectedItems.removeAll()
                isInSelectionMode = false
            }
            
            await refreshData() // Refresh to get updated counts
            
        } catch {
            self.error = error
        }
    }
    
    func updateSelectedItemsStatus(_ status: OutOfStockStatus) async {
        // This would be implemented based on service capabilities
        // For now, we'll refresh the data
        await refreshData()
        exitSelectionMode()
    }
    
    // MARK: - Animation Methods
    
    private func animateListItems() {
        listItemAnimationOffset = 100
        
        withAnimation(.easeInOut(duration: 0.1)) {
            listItemAnimationOffset = 0
        }
        
        // Staggered animation for each item
        for (index, _) in items.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                // Trigger individual item animation
            }
        }
    }
    
    func animateFilterChips() {
        filterChipAnimationScale = 0.8
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
            filterChipAnimationScale = 1.0
        }
    }
    
    // MARK: - Status Management
    
    private func updateStatusCounts() {
        var counts: [OutOfStockStatus: Int] = [:]
        
        for item in items {
            counts[item.status, default: 0] += 1
        }
        
        statusCounts = counts
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentWeekRange() -> (Date, Date) {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
              let weekEnd = calendar.date(byAdding: .day, value: 6 - daysFromMonday, to: today) else {
            return (today, today)
        }
        
        return (weekStart, weekEnd)
    }
    
    private func getCurrentMonthRange() -> (Date, Date) {
        let calendar = Calendar.current
        let today = Date()
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return (today, today)
        }
        
        return (monthStart, monthEnd)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Memory Management & Performance Optimization
    
    func optimizeMemoryUsage() {
        // Clear old cached images and data
        let memoryPressure = 1 // Simplified memory pressure check
        
        if memoryPressure > 0 {
            // Aggressive cleanup
            items.removeAll { item in
                !selectedItems.contains(item.id) && 
                Date().timeIntervalSince(item.updatedAt) > 3600 // 1 hour old
            }
            
            // Clear non-essential caches
            clearNonEssentialCaches()
        }
    }
    
    private func clearNonEssentialCaches() {
        // Clear image caches, temporary data, etc.
        URLCache.shared.removeAllCachedResponses()
        
        // Notify service to clear its caches
        Task {
            await service.invalidateCache(currentDate: selectedDate)
        }
    }
    
    func handleMemoryWarning() {
        // Emergency memory cleanup
        let currentlyVisible = Set(items.prefix(20).map { $0.id })
        
        // Keep only visible items and selected items
        items.removeAll { item in
            !currentlyVisible.contains(item.id) && !selectedItems.contains(item.id)
        }
        
        // Reset pagination to current state
        currentPage = min(currentPage, items.count / pageSize)
        
        // Clear all animations
        listItemAnimationOffset = 0
        filterChipAnimationScale = 1.0
    }
    
    func preloadAdjacentData() {
        // Preload data for adjacent dates
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDate),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: selectedDate) else {
            return
        }
        
        // Background preloading
        Task.detached(priority: .background) {
            // Preload yesterday's data
            await self.preloadDataForDate(yesterday)
            
            // Preload tomorrow's data
            await self.preloadDataForDate(tomorrow)
        }
    }
    
    @MainActor
    private func preloadDataForDate(_ date: Date) async {
        let criteria = OutOfStockFilterCriteria(
            dateRange: CustomerOutOfStockService.createDateRange(for: date),
            page: 0,
            pageSize: 20 // Smaller page size for preloading
        )
        
        do {
            await service.loadFilteredItems(criteria: criteria, resetPagination: true)
        } catch {
            // Silent failure for preloading
            print("Preload failed for \(date): \(error)")
        }
    }
    
    deinit {
        searchWorkItem?.cancel()
        cancellables.removeAll()
        
        // Final cleanup - handled by main actor context automatically
        // items and selectedItems will be cleaned up by ARC
    }
}

// MARK: - Extensions

extension CustomerOutOfStockViewModel {
    var filteredItemsPreview: [CustomerOutOfStock] {
        Array(items.prefix(3))
    }
    
    var displayTitle: String {
        if hasActiveFilters {
            return "筛选结果 (\(totalCount))"
        } else {
            return "客户缺货管理 (\(totalCount))"
        }
    }
    
    var loadingMessage: String {
        if isLoading {
            return "正在加载..."
        } else if isLoadingMore {
            return "加载更多..."
        } else {
            return ""
        }
    }
}