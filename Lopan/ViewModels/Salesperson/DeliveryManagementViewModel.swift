//
//  DeliveryManagementViewModel.swift
//  Lopan
//
//  Created to improve data loading efficiency for Delivery Management.
//

import Foundation
import SwiftData

@MainActor
final class DeliveryManagementViewModel: ObservableObject {
    struct FilterState: Equatable {
        var searchText: String = ""
        var deliveryStatus: DeliveryStatus? = nil
        var customer: Customer? = nil
        var address: String? = nil
        var isFilteringByDate: Bool = false
        var selectedDate: Date = Date()

        static let `default` = FilterState()

        static func == (lhs: FilterState, rhs: FilterState) -> Bool {
            let calendar = Calendar.current
            return lhs.searchText == rhs.searchText &&
                lhs.deliveryStatus == rhs.deliveryStatus &&
                lhs.customer?.id == rhs.customer?.id &&
                lhs.address == rhs.address &&
                lhs.isFilteringByDate == rhs.isFilteringByDate &&
                (!lhs.isFilteringByDate || calendar.isDate(lhs.selectedDate, inSameDayAs: rhs.selectedDate))
        }
    }

    struct DeliveryOverviewStatistics {
        var totalCount: Int = 0
        var needsDelivery: Int = 0
        var partialDelivery: Int = 0
        var completedDelivery: Int = 0
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
    @Published private(set) var overviewStatistics = DeliveryOverviewStatistics()
    @Published private(set) var isLoadingStatistics = false
    @Published private(set) var statisticsLoaded = false

    private var repository: CustomerOutOfStockRepository?
    private var modelContainer: ModelContainer?
    private var isConfigured = false
    private let pageSize = 50
    private var nextPageToLoad = 0
    private var currentFilter: FilterState = .default
    private var isFetchingPage = false
    private var customerCache: [String: Customer] = [:]
    private var addressCache: Set<String> = []
    private var statisticsTask: Task<Void, Never>?

    func configure(repository: CustomerOutOfStockRepository, modelContainer: ModelContainer) {
        guard !isConfigured else { return }
        self.repository = repository
        self.modelContainer = modelContainer
        isConfigured = true
    }

    deinit {
        // Cancel any pending statistics task to prevent crashes
        statisticsTask?.cancel()
    }
    
    func refresh(with filter: FilterState, force: Bool = false) async {
        guard isConfigured else { return }
        if !force && filter == currentFilter && !items.isEmpty {
            return
        }

        // Cancel any pending statistics task when refreshing with new filters
        statisticsTask?.cancel()

        currentFilter = filter
        nextPageToLoad = 0
        hasMoreData = true
        customerCache.removeAll()
        addressCache.removeAll()
        overviewStatistics = DeliveryOverviewStatistics()
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
            statisticsLoaded = false
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

        do {
            let criteria = buildCriteria(for: currentFilter, page: reset ? 0 : nextPageToLoad)

            if reset {
                // INSTANT: Fetch only the first page immediately
                let result = try await repository.fetchDeliveryManagementMetrics(
                    criteria: criteria,
                    page: 0,
                    pageSize: pageSize
                )

                // Update UI immediately with items
                items = result.items
                updateCaches(with: result.items)
                nextPageToLoad = 1
                hasMoreData = result.hasMoreData
                lastUpdated = Date()

                // Placeholder statistics (totalCount = -1 means loading)
                overviewStatistics = DeliveryOverviewStatistics(
                    totalCount: -1,  // -1 indicates loading
                    needsDelivery: 0,
                    partialDelivery: 0,
                    completedDelivery: 0
                )

                // Cancel any existing statistics task
                statisticsTask?.cancel()

                // BACKGROUND: Load full statistics asynchronously
                // Use regular Task (inherits MainActor) with yields for thread safety
                statisticsTask = Task { [weak self] in
                    guard let self else { return }

                    // Delay to allow UI to fully render before statistics load
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

                    // Check if task was cancelled during sleep
                    guard !Task.isCancelled else {
                        print("📊 [ViewModel] Statistics task cancelled before starting")
                        return
                    }

                    await self.loadStatistics(criteria: criteria)
                }

            } else {
                // Load more: use pagination
                var aggregatedItems: [CustomerOutOfStock] = []
                var page = nextPageToLoad
                var hasMore = false
                var totalCount = totalMatchingCount
                var shouldContinue = true

                while shouldContinue {
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

                    shouldContinue = filtered.isEmpty && hasMore

                    if !shouldContinue {
                        nextPageToLoad = page
                        hasMoreData = hasMore
                        totalMatchingCount = totalCount
                        lastUpdated = Date()
                        break
                    }
                }

                let existingIds = Set(items.map { $0.id })
                let uniqueItems = aggregatedItems.filter { !existingIds.contains($0.id) }
                items.append(contentsOf: uniqueItems)

                // Update statistics preview for load-more
                overviewStatistics = makePreviewStatistics(totalCount: totalCount)
            }
        } catch {
            self.error = error
            if reset {
                items = []
            }
            hasMoreData = false
            totalMatchingCount = 0
            lastUpdated = Date()
        }
    }

    private func buildCriteria(for filter: FilterState, page: Int) -> OutOfStockFilterCriteria {
        var dateRange: (start: Date, end: Date)? = nil

        // Apply date filter based on user selection or delivery status
        if filter.isFilteringByDate {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: filter.selectedDate)
            if let end = calendar.date(byAdding: .day, value: 1, to: start) {
                dateRange = (start: start, end: end)
            }
        } else if filter.deliveryStatus == .needsDelivery {
            // For "needsDelivery" (pending status), limit to last 7 days
            let calendar = Calendar.current
            let now = Date()
            if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                dateRange = (start: sevenDaysAgo, end: now)
            }
        }

        // Don't map ReturnStatus to OutOfStockStatus - they are orthogonal concepts
        // ReturnStatus filters by returnQuantity (applied in applyPostFetchFilters)
        // OutOfStockStatus is about order state (pending/completed/returned to supplier)
        return OutOfStockFilterCriteria(
            customer: filter.customer,
            product: nil,
            status: nil,  // Let repository fetch all statuses, filter by returnQuantity later
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
        
        if let deliveryStatus = filter.deliveryStatus {
            filtered = filtered.filter { matchesDeliveryStatus(record: $0, status: deliveryStatus) }
        }

        return filtered
    }

    private func matchesDeliveryStatus(record: CustomerOutOfStock, status: DeliveryStatus) -> Bool {
        switch status {
        case .needsDelivery:
            // Waiting: Not completed/refunded AND no delivery recorded
            return record.status != .completed && record.status != .refunded && record.deliveryQuantity == 0
        case .partialDelivery:
            // Partial: Has delivery but not fully delivered
            return record.deliveryQuantity > 0 && record.deliveryQuantity < record.quantity
        case .completed:
            // Completed: Status marked as completed/refunded OR fully delivered
            return record.status == .completed || record.status == .refunded || record.deliveryQuantity >= record.quantity
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

    private func makePreviewStatistics(totalCount: Int) -> DeliveryOverviewStatistics {
        let needs = items.filter { $0.status != .completed && $0.status != .refunded && $0.deliveryQuantity == 0 }.count
        let partial = items.filter { $0.deliveryQuantity > 0 && $0.deliveryQuantity < $0.quantity }.count
        let completed = items.filter { $0.status == .completed || $0.status == .refunded || $0.deliveryQuantity >= $0.quantity }.count
        return DeliveryOverviewStatistics(
            totalCount: totalCount,
            needsDelivery: needs,
            partialDelivery: partial,
            completedDelivery: completed
        )
    }

    // MARK: - Background Statistics Loading (ModelActor Pattern)

    private func loadStatistics(criteria: OutOfStockFilterCriteria) async {
        guard let container = modelContainer else {
            print("❌ [ViewModel] ModelContainer not available")
            return
        }

        isLoadingStatistics = true

        do {
            // Create actor for off-MainActor computation
            let actor = DeliveryStatisticsActor(modelContainer: container)

            // Compute statistics entirely off MainActor (zero scroll impact)
            let stats = try await actor.computeStatistics(criteria: criteria)

            // Check if task was cancelled during fetch
            guard !Task.isCancelled else {
                print("📊 [ViewModel] Statistics task cancelled after fetch")
                isLoadingStatistics = false
                return
            }

            // Update UI on MainActor
            overviewStatistics = DeliveryOverviewStatistics(
                totalCount: stats.totalCount,
                needsDelivery: stats.needsDeliveryCount,
                partialDelivery: stats.partialDeliveryCount,
                completedDelivery: stats.completedDeliveryCount
            )
            totalMatchingCount = stats.totalCount
            statisticsLoaded = true
            isLoadingStatistics = false
            print("✅ [ViewModel] Statistics loaded via ModelActor (off MainActor)")
        } catch is CancellationError {
            isLoadingStatistics = false
            print("📊 [ViewModel] Statistics loading cancelled")
        } catch {
            isLoadingStatistics = false
            print("❌ [ViewModel] Failed to load statistics: \(error)")
        }
    }
}
