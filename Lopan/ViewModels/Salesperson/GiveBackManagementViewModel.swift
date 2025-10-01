//
//  GiveBackManagementViewModel.swift
//  Lopan
//
//  Created to improve data loading efficiency for Return Goods Management.
//

import Foundation
import SwiftData

@MainActor
final class GiveBackManagementViewModel: ObservableObject {
    struct FilterState: Equatable {
        var searchText: String = ""
        var returnStatus: ReturnStatus? = nil
        var customer: Customer? = nil
        var address: String? = nil
        var isFilteringByDate: Bool = false
        var selectedDate: Date = Date()
        
        static let `default` = FilterState()
        
        static func == (lhs: FilterState, rhs: FilterState) -> Bool {
            let calendar = Calendar.current
            return lhs.searchText == rhs.searchText &&
                lhs.returnStatus == rhs.returnStatus &&
                lhs.customer?.id == rhs.customer?.id &&
                lhs.address == rhs.address &&
                lhs.isFilteringByDate == rhs.isFilteringByDate &&
                (!lhs.isFilteringByDate || calendar.isDate(lhs.selectedDate, inSameDayAs: rhs.selectedDate))
        }
    }
    
    struct ReturnOverviewStatistics {
        var totalCount: Int = 0
        var needsReturn: Int = 0
        var partialReturn: Int = 0
        var completedReturn: Int = 0
    }

    @Published private(set) var items: [CustomerOutOfStock] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMoreData = true
    @Published private(set) var totalMatchingCount: Int = 0
    @Published private(set) var availableCustomers: [Customer] = []
    @Published private(set) var availableAddresses: [String] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var error: Error?
    @Published private(set) var overviewStatistics = ReturnOverviewStatistics()
    
    private var repository: CustomerOutOfStockRepository?
    private var isConfigured = false
    private let pageSize = 50
    private var nextPageToLoad = 0
    private var currentFilter: FilterState = .default
    private var isFetchingPage = false
    private var customerCache: [String: Customer] = [:]
    private var addressCache: Set<String> = []
    private var statisticsTask: Task<Void, Never>?
    private var baseCriteriaForStatistics: OutOfStockFilterCriteria?
    
    func configure(repository: CustomerOutOfStockRepository) {
        guard !isConfigured else { return }
        self.repository = repository
        isConfigured = true
    }
    
    func refresh(with filter: FilterState, force: Bool = false) async {
        guard isConfigured else { return }
        if !force && filter == currentFilter && !items.isEmpty {
            return
        }
        currentFilter = filter
        nextPageToLoad = 0
        hasMoreData = true
        customerCache.removeAll()
        addressCache.removeAll()
        statisticsTask?.cancel()
        baseCriteriaForStatistics = buildCriteria(for: filter, page: 0)
        overviewStatistics = ReturnOverviewStatistics()
        await loadPage(reset: true)
    }
    
    func loadMoreIfNeeded(for item: CustomerOutOfStock) async {
        guard hasMoreData else { return }
        guard !isLoadingMore && !isLoading && !isFetchingPage else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let thresholdIndex = max(items.count - 5, 0)
        if index >= thresholdIndex {
            await loadPage(reset: false)
        }
    }
    
    private func loadPage(reset: Bool) async {
        guard let repository else { return }
        if isFetchingPage { return }
        isFetchingPage = true
        error = nil
        
        if reset {
            isLoading = true
            items = []
        } else {
            isLoadingMore = true
        }
        
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
            isFetchingPage = false
        }
        
        var aggregatedItems: [CustomerOutOfStock] = []
        var page = nextPageToLoad
        var hasMore = false
        var totalCount = totalMatchingCount
        var shouldContinue = true
        
        while shouldContinue {
            do {
                let criteria = buildCriteria(for: currentFilter, page: page)
                let result = try await repository.fetchOutOfStockRecords(
                    criteria: criteria,
                    page: page,
                    pageSize: pageSize
                )
                page = result.page + 1
                hasMore = result.hasMoreData
                totalCount = result.totalCount
                updateCaches(with: result.items)
                let filtered = applyPostFetchFilters(result.items, filter: currentFilter)
                if !filtered.isEmpty {
                    aggregatedItems.append(contentsOf: filtered)
                }
                
                shouldContinue = false

                if reset {
                    if aggregatedItems.count < pageSize && hasMore {
                        shouldContinue = true
                    } else if filtered.isEmpty && hasMore {
                        shouldContinue = true
                    }
                } else {
                    if filtered.isEmpty && hasMore {
                        shouldContinue = true
                    }
                }

                if !shouldContinue {
                    nextPageToLoad = page
                    hasMoreData = hasMore
                    totalMatchingCount = totalCount
                    lastUpdated = Date()
                    if reset {
                        scheduleStatisticsUpdate(totalCount: totalCount)
                    }
                    break
                }
            } catch {
                self.error = error
                aggregatedItems.removeAll()
                hasMoreData = false
                totalMatchingCount = 0
                lastUpdated = Date()
                return
            }
        }
        
        if reset {
            items = aggregatedItems
        } else {
            let existingIds = Set(items.map { $0.id })
            let uniqueItems = aggregatedItems.filter { !existingIds.contains($0.id) }
            items.append(contentsOf: uniqueItems)
        }
    }

    private func buildCriteria(for filter: FilterState, page: Int) -> OutOfStockFilterCriteria {
        var dateRange: (start: Date, end: Date)? = nil
        if filter.isFilteringByDate {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: filter.selectedDate)
            if let end = calendar.date(byAdding: .day, value: 1, to: start) {
                dateRange = (start: start, end: end)
            }
        }
        
        return OutOfStockFilterCriteria(
            customer: filter.customer,
            product: nil,
            status: filter.returnStatus?.mappedOutOfStockStatus,
            dateRange: dateRange,
            searchText: filter.searchText,
            page: page,
            pageSize: pageSize,
            sortOrder: .newestFirst
        )
    }
    
    private func applyPostFetchFilters(_ items: [CustomerOutOfStock], filter: FilterState) -> [CustomerOutOfStock] {
        var filtered = items
        
        if let address = filter.address, !address.isEmpty {
            filtered = filtered.filter { record in
                if let customer = record.customer {
                    return customer.address == address
                }
                return record.customerAddress == address
            }
        }
        
        if let returnStatus = filter.returnStatus {
            filtered = filtered.filter { matchesReturnStatus(record: $0, status: returnStatus) }
        }
        
        return filtered
    }

    private func matchesReturnStatus(record: CustomerOutOfStock, status: ReturnStatus) -> Bool {
        switch status {
        case .needsReturn:
            return record.status == .pending && record.returnQuantity < record.quantity
        case .partialReturn:
            return record.returnQuantity > 0 && record.returnQuantity < record.quantity
        case .completed:
            return record.returnQuantity >= record.quantity
        }
    }
    
    private func updateCaches(with items: [CustomerOutOfStock]) {
        for item in items {
            if let customer = item.customer {
                customerCache[customer.id] = customer
            }
            let address = item.customer?.address ?? item.customerAddress
            if !address.isEmpty {
                addressCache.insert(address)
            }
        }
        availableCustomers = customerCache.values.sorted { $0.name < $1.name }
        availableAddresses = addressCache.sorted()
    }

    private func scheduleStatisticsUpdate(totalCount: Int) {
        guard let repository, let baseCriteriaForStatistics else { return }
        statisticsTask?.cancel()
        let criteria = baseCriteriaForStatistics
        let preview = makePreviewStatistics(totalCount: totalCount)
        overviewStatistics = preview
        statisticsTask = Task { [weak self] in
            guard let self else { return }
            let stats = await self.computeOverviewStatistics(
                repository: repository,
                criteria: criteria,
                totalCount: totalCount
            )
            await MainActor.run {
                self.overviewStatistics = stats
            }
        }
    }

    private func makePreviewStatistics(totalCount: Int) -> ReturnOverviewStatistics {
        let needs = items.filter { $0.status == .pending && $0.returnQuantity == 0 }.count
        let partial = items.filter { $0.status == .pending && $0.returnQuantity > 0 && $0.returnQuantity < $0.quantity }.count
        let completed = items.filter { $0.status != .pending && $0.returnQuantity >= $0.quantity }.count
        return ReturnOverviewStatistics(
            totalCount: totalCount,
            needsReturn: needs,
            partialReturn: partial,
            completedReturn: completed
        )
    }

    private func computeOverviewStatistics(
        repository: CustomerOutOfStockRepository,
        criteria: OutOfStockFilterCriteria,
        totalCount: Int
    ) async -> ReturnOverviewStatistics {
        var result = ReturnOverviewStatistics(totalCount: totalCount)

        do {
            let statusCounts = try await repository.countOutOfStockRecordsByStatus(criteria: criteria)
            let pendingCount = statusCounts[.pending] ?? 0
            let returnedCount = statusCounts[.returned] ?? 0
            let completedCount = statusCounts[.completed] ?? 0

            let partialCount = try await repository.countPartialReturnRecords(criteria: criteria)

            let needsCount = max(0, pendingCount - partialCount)
            let finalCompleted = max(0, returnedCount + completedCount)

            result.needsReturn = needsCount
            result.partialReturn = partialCount
            result.completedReturn = finalCompleted

        } catch {
            // Fallback to current in-memory items if repository aggregation fails
            let pending = items.filter { $0.status == .pending && $0.returnQuantity == 0 }.count
            let partial = items.filter { $0.status == .pending && $0.returnQuantity > 0 && $0.returnQuantity < $0.quantity }.count
            let completed = items.filter { $0.status != .pending && $0.returnQuantity >= $0.quantity }.count

            result.needsReturn = pending
            result.partialReturn = partial
            result.completedReturn = completed
        }

        return result
    }
}

private extension ReturnStatus {
    var mappedOutOfStockStatus: OutOfStockStatus? {
        switch self {
        case .needsReturn, .partialReturn:
            return .pending
        case .completed:
            return .returned
        }
    }
}
