//
//  CustomerOutOfStockNavigationState.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/21.
//

import Foundation
import SwiftUI

class CustomerOutOfStockNavigationState: ObservableObject {
    static let shared = CustomerOutOfStockNavigationState()
    
    // MARK: - Published State Properties
    
    @Published var selectedDate: Date = Date()
    @Published var dateFilterMode: DateFilterOption? = nil
    @Published var selectedCustomer: Customer? = nil
    @Published var selectedProduct: Product? = nil
    @Published var selectedAddress: String? = nil
    @Published var selectedProductSize: ProductSize? = nil
    @Published var selectedStatusFilter: StatusFilter = .all
    @Published var searchText: String = ""
    @Published var scrollPosition: String? = nil
    @Published var lastRefreshTime: Date? = nil
    @Published var showingAdvancedFilters: Bool = false
    @Published var customDateRange: (start: Date, end: Date)? = nil
    @Published var sortOrder: SortOrder = .newestFirst
    
    // MARK: - Cache Management
    
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private var navigationStartTime: Date? = nil
    
    private init() {
        // Private init to enforce singleton
    }
    
    // MARK: - State Management Methods
    
    func markNavigationStart() {
        navigationStartTime = Date()
    }
    
    func shouldRefreshData() -> Bool {
        guard let lastRefresh = lastRefreshTime else { 
            // First time loading, need to refresh
            return true 
        }
        
        // Only refresh if data is genuinely stale (older than cache expiration)
        let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceRefresh > cacheExpirationInterval
    }
    
    func markDataRefreshed() {
        lastRefreshTime = Date()
        navigationStartTime = nil
    }
    
    // MARK: - Filter Management Methods
    
    func resetFiltersIfNoData() {
        // 如果没有数据，重置日期筛选条件
        dateFilterMode = nil
        customDateRange = nil
        // 保留其他筛选条件（客户、产品等），因为用户可能仍想使用它们
    }
    
    func shouldResetDateFilter() -> Bool {
        return dateFilterMode != nil
    }
    
    // MARK: - Filter State Helpers
    
    var hasActiveFilters: Bool {
        return selectedCustomer != nil || 
               selectedProduct != nil || 
               selectedAddress != nil || 
               selectedProductSize != nil || 
               dateFilterMode != nil ||
               !searchText.isEmpty
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedCustomer != nil { count += 1 }
        if selectedProduct != nil { count += 1 }
        if selectedAddress != nil { count += 1 }
        if selectedProductSize != nil { count += 1 }
        if dateFilterMode != nil { count += 1 }
        if !searchText.isEmpty { count += 1 }
        return count
    }
    
    var filterSummaryText: String {
        var components: [String] = []
        
        if let customer = selectedCustomer {
            components.append("客户: \(customer.name)")
        }
        
        if let product = selectedProduct {
            components.append("产品: \(product.name)")
        }
        
        if let address = selectedAddress {
            components.append("地址: \(address)")
        }
        
        if let size = selectedProductSize {
            components.append("尺寸: \(size.size)")
        }
        
        if selectedStatusFilter != .all {
            components.append("状态: \(selectedStatusFilter.displayName)")
        }
        
        if let filterMode = dateFilterMode {
            components.append("日期: \(filterMode.displayName)")
        }
        
        if !searchText.isEmpty {
            components.append("搜索: \(searchText)")
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Reset Methods
    
    func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedCustomer = nil
            selectedProduct = nil
            selectedAddress = nil
            selectedProductSize = nil
            dateFilterMode = nil
            customDateRange = nil
            selectedStatusFilter = .all
            searchText = ""
            showingAdvancedFilters = false
            sortOrder = .newestFirst
        }
    }
    
    func resetToDefaults() {
        selectedDate = Date()
        clearAllFilters()
        scrollPosition = nil
        lastRefreshTime = nil
        navigationStartTime = nil
    }
    
    func resetDateToToday() {
        selectedDate = Date()
        dateFilterMode = nil
        customDateRange = nil
    }
    
    // MARK: - Filter Validation and Conflict Resolution
    
    func validateFilterCombinations() -> [String] {
        var conflicts: [String] = []
        
        // Check customer/address conflicts
        if let customer = selectedCustomer, 
           let address = selectedAddress,
           customer.address != address {
            conflicts.append("所选客户与地址不匹配")
        }
        
        // Check product/size conflicts
        if let product = selectedProduct,
           let size = selectedProductSize,
           !(product.sizes?.contains { $0.id == size.id } ?? false) {
            conflicts.append("所选产品不包含该尺寸")
        }
        
        return conflicts
    }
    
    func resolveFilterConflicts() {
        let conflicts = validateFilterCombinations()
        
        if conflicts.contains("所选客户与地址不匹配") {
            selectedAddress = nil
        }
        
        if conflicts.contains("所选产品不包含该尺寸") {
            selectedProductSize = nil
        }
    }
    
    // MARK: - Date Filter Helpers
    
    func applyDateFilter(_ option: DateFilterOption) {
        dateFilterMode = option
        
        switch option {
        case .today:
            customDateRange = nil // For today, we don't need a custom range
            
        case .thisWeek:
            let (start, end) = getCurrentWeekRange()
            customDateRange = (start: start, end: end)
            
        case .thisMonth:
            let (start, end) = getCurrentMonthRange()
            customDateRange = (start: start, end: end)
            
        case .custom(let start, let end):
            customDateRange = (start: start, end: end)
        }
    }
    
    private func getCurrentWeekRange() -> (Date, Date) {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Monday is 2 in weekday, Sunday is 1
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
    
    // MARK: - Search Helpers
    
    private var searchDebounceTimer: Timer?
    
    func setSearchText(_ newText: String) {
        searchDebounceTimer?.invalidate()
        
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.searchText = newText
            }
        }
    }
    
    func performImmediateSearch(_ newText: String) {
        searchDebounceTimer?.invalidate()
        searchText = newText
    }
    
    // MARK: - Performance Optimizations
    
    private let prefetchQueue = DispatchQueue(label: "navigationState.prefetch", qos: .utility)
    
    func prefetchAdjacentDates() {
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }
            
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: self.selectedDate)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: self.selectedDate)
            
            // This would trigger background data prefetch in the service
            // Implementation depends on service architecture
        }
    }
    
    // MARK: - Memory Management
    
    func performMemoryOptimization() {
        // Clear any cached data older than 1 hour
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) > 3600 {
            // Could trigger cache cleanup in connected services
        }
    }
}

// MARK: - Supporting Enums

extension CustomerOutOfStockNavigationState {
    enum StatusFilter: CaseIterable {
        case all
        case pending
        case completed
        case returned
        
        var outOfStockStatus: OutOfStockStatus? {
            switch self {
            case .pending: return .pending
            case .completed: return .completed
            case .returned: return .returned
            default: return nil
            }
        }
        
        var displayName: String {
            switch self {
            case .all: return "全部"
            case .pending: return "待处理"
            case .completed: return "已完成"
            case .returned: return "已退货"
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .pending: return "clock"
            case .completed: return "checkmark.circle"
            case .returned: return "arrow.uturn.backward"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case newestFirst = "newest_first"
        case oldestFirst = "oldest_first"
        
        var displayName: String {
            switch self {
            case .newestFirst: return "最新优先"
            case .oldestFirst: return "最早优先"
            }
        }
        
        var icon: String {
            switch self {
            case .newestFirst: return "arrow.down.circle.fill"
            case .oldestFirst: return "arrow.up.circle.fill"
            }
        }
        
        var isDescending: Bool {
            switch self {
            case .newestFirst: return true
            case .oldestFirst: return false
            }
        }
    }
}

// DateFilterOption is imported from DateFilterOptions.swift