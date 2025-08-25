//
//  LocalCustomerOutOfStockRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalCustomerOutOfStockRepository: CustomerOutOfStockRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchOutOfStockRecords() async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        return try await MainActor.run {
            return try modelContext.fetch(descriptor)
        }
    }
    
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock? {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try await MainActor.run {
            return try modelContext.fetch(descriptor)
        }
        return records.first { $0.id == id }
    }
    
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try await MainActor.run {
            return try modelContext.fetch(descriptor)
        }
        return records.filter { $0.customer?.id == customer.id }
    }
    
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try await MainActor.run {
            return try modelContext.fetch(descriptor)
        }
        return records.filter { $0.product?.id == product.id }
    }
    
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        try await MainActor.run {
            modelContext.insert(record)
            try modelContext.save()
        }
    }
    
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        try await MainActor.run {
            try modelContext.save()
        }
    }
    
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        try await MainActor.run {
            modelContext.delete(record)
            try modelContext.save()
        }
    }
    
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws {
        try await MainActor.run {
            for record in records {
                modelContext.delete(record)
            }
            try modelContext.save()
        }
    }
    
    // MARK: - Paginated Methods
    
    func fetchOutOfStockRecords(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        
        print("📊 [Repository] fetchOutOfStockRecords called - Page: \(page), Status: \(criteria.status?.displayName ?? "All")")
        
        do {
            // Input validation
            guard page >= 0 else {
                throw NSError(domain: "CustomerOutOfStockRepository", code: 1001, 
                             userInfo: [NSLocalizedDescriptionKey: "Page number cannot be negative"])
            }
            
            guard pageSize > 0 && pageSize <= 1000 else {
                throw NSError(domain: "CustomerOutOfStockRepository", code: 1002,
                             userInfo: [NSLocalizedDescriptionKey: "Page size must be between 1 and 1000"])
            }
            
            // Use two-phase search when text search is present
            if !criteria.searchText.isEmpty {
                print("📊 [Repository] Using two-phase search for text query")
                return try await fetchWithTwoPhaseSearch(criteria: criteria, page: page, pageSize: pageSize)
            } else {
                print("📊 [Repository] Using database pagination for non-search query")
                // Use original database pagination for non-search operations
                return try await fetchWithDatabasePagination(criteria: criteria, page: page, pageSize: pageSize)
            }
        } catch {
            print("❌ [Repository] fetchOutOfStockRecords failed: \(error)")
            
            // Re-throw with more context for debugging
            throw NSError(domain: "LocalCustomerOutOfStockRepository", code: 1000,
                         userInfo: [
                            NSLocalizedDescriptionKey: "Failed to fetch out-of-stock records: \(error.localizedDescription)",
                            NSLocalizedRecoverySuggestionErrorKey: "This could be due to invalid filter criteria or database access issues.",
                            NSUnderlyingErrorKey: error
                         ])
        }
    }
    
    private func fetchWithTwoPhaseSearch(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        
        // Phase 1: Get ALL matching active records (no pagination at DB level)
        let activeRecords = try await fetchAllMatchingActiveRecords(criteria: criteria)
        
        // Phase 2: Get orphaned records
        let orphanedRecords = try await fetchMatchingOrphanedRecords(
            searchText: criteria.searchText,
            dateRange: criteria.dateRange,
            status: criteria.status
        )
        
        // Combine and sort all results by date based on criteria sort order
        let allResults = (activeRecords + orphanedRecords)
            .sorted { 
                if criteria.sortOrder.isDescending {
                    return $0.requestDate > $1.requestDate
                } else {
                    return $0.requestDate < $1.requestDate
                }
            }
        
        // Apply pagination in memory on complete result set with bounds checking
        guard !allResults.isEmpty else {
            return OutOfStockPaginationResult(
                items: [],
                totalCount: 0,
                hasMoreData: false,
                page: page,
                pageSize: pageSize
            )
        }
        
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, allResults.count)
        
        // Bounds checking for array indexing
        guard startIndex >= 0 && startIndex < allResults.count else {
            // Requested page is beyond available results
            return OutOfStockPaginationResult(
                items: [],
                totalCount: allResults.count,
                hasMoreData: false,
                page: page,
                pageSize: pageSize
            )
        }
        
        // Safe array slicing with additional bounds checking
        guard endIndex > startIndex && endIndex <= allResults.count else {
            return OutOfStockPaginationResult(
                items: [],
                totalCount: allResults.count,
                hasMoreData: false,
                page: page,
                pageSize: pageSize
            )
        }
        
        let paginatedResults = Array(allResults[startIndex..<endIndex])
        
        return OutOfStockPaginationResult(
            items: paginatedResults,
            totalCount: allResults.count,
            hasMoreData: endIndex < allResults.count,
            page: page,
            pageSize: pageSize
        )
    }
    
    @MainActor
    private func fetchWithDatabasePagination(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        // Ensure we're on the main thread for ModelContext operations
        print("📊 [Repository] Fetching with database pagination - Page: \(page), Status: \(criteria.status?.displayName ?? "All")")
        
        // If status, customer, or product filtering is needed, use memory-based approach to avoid SwiftData predicate issues
        if criteria.status != nil || criteria.customer != nil || criteria.product != nil {
            return try await fetchWithMemoryFiltering(criteria: criteria, page: page, pageSize: pageSize)
        }
        
        // For non-status filtering (date-only or no filters), use safe database pagination
        do {
            let predicate = buildPredicate(from: criteria)
            
            // Create sort descriptor based on criteria
            let sortDescriptor = SortDescriptor<CustomerOutOfStock>(
                \.requestDate,
                order: criteria.sortOrder.isDescending ? .reverse : .forward
            )
            
            // Calculate pagination
            let offset = page * pageSize
            let fetchLimit = pageSize
            
            // Create paginated fetch descriptor
            var paginatedDescriptor: FetchDescriptor<CustomerOutOfStock>
            if let predicate = predicate {
                paginatedDescriptor = FetchDescriptor<CustomerOutOfStock>(
                    predicate: predicate,
                    sortBy: [sortDescriptor]
                )
            } else {
                paginatedDescriptor = FetchDescriptor<CustomerOutOfStock>(
                    sortBy: [sortDescriptor]
                )
            }
            paginatedDescriptor.fetchLimit = fetchLimit
            paginatedDescriptor.fetchOffset = offset
            
            print("📊 [Repository] Executing safe fetch with predicate: \(predicate != nil)")
            
            // Perform the fetch operation with error handling - ensure main thread execution
            let fetchedItems = try await MainActor.run {
                return try modelContext.fetch(paginatedDescriptor)
            }
            
            print("📊 [Repository] Successfully fetched \(fetchedItems.count) items")
            
            // Get total count for pagination
            let totalCount = try await countForNonSearchCriteria(criteria: criteria)
            
            // Calculate hasMoreData based on total count and current position [rule:§3+.2 API Contract]
            let currentOffset = page * pageSize
            let hasMoreData = (currentOffset + fetchedItems.count) < totalCount
            
            return OutOfStockPaginationResult(
                items: fetchedItems,
                totalCount: totalCount,
                hasMoreData: hasMoreData,
                page: page,
                pageSize: pageSize
            )
            
        } catch {
            print("❌ [Repository] Database pagination failed: \(error)")
            throw NSError(domain: "LocalCustomerOutOfStockRepository", code: 1001,
                         userInfo: [NSLocalizedDescriptionKey: "Database fetch operation failed: \(error.localizedDescription)"])
        }
    }
    
    @MainActor
    private func fetchWithMemoryFiltering(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        print("📊 [Repository] Using memory-based filtering for status: \(criteria.status?.displayName ?? "none")")
        
        // Create sort descriptor based on criteria
        let sortDescriptor = SortDescriptor<CustomerOutOfStock>(
            \.requestDate,
            order: criteria.sortOrder.isDescending ? .reverse : .forward
        )
        
        // Step 1: Get all matching items with date filter only (safe)
        var allItemsDescriptor: FetchDescriptor<CustomerOutOfStock>
        
        if let dateRange = criteria.dateRange {
            let dateStart = dateRange.start
            let dateEnd = dateRange.end
            allItemsDescriptor = FetchDescriptor<CustomerOutOfStock>(
                predicate: #Predicate<CustomerOutOfStock> { item in
                    item.requestDate >= dateStart && 
                    item.requestDate <= dateEnd
                },
                sortBy: [sortDescriptor]
            )
        } else {
            allItemsDescriptor = FetchDescriptor<CustomerOutOfStock>(
                sortBy: [sortDescriptor]
            )
        }
        
        let allMatchingItems = try await MainActor.run {
            return try modelContext.fetch(allItemsDescriptor)
        }
        
        // Step 2: Apply status, customer, and product filtering in memory (safe operations)
        var filteredItems = allMatchingItems
        
        // Apply status filtering
        if let statusFilter = criteria.status {
            filteredItems = filteredItems.filter { $0.status == statusFilter }
            print("📊 [Repository] Memory filtering: \(filteredItems.count) of \(allMatchingItems.count) items match status \(statusFilter.displayName)")
        }
        
        // Apply customer filtering
        if let customerFilter = criteria.customer {
            filteredItems = filteredItems.filter { $0.customer?.id == customerFilter.id }
            print("📊 [Repository] Memory filtering: \(filteredItems.count) items match customer \(customerFilter.name)")
        }
        
        // Apply product filtering
        if let productFilter = criteria.product {
            filteredItems = filteredItems.filter { $0.product?.id == productFilter.id }
            print("📊 [Repository] Memory filtering: \(filteredItems.count) items match product \(productFilter.name)")
        }
        
        // Step 3: Apply pagination to filtered results
        let offset = page * pageSize
        let startIndex = offset
        let endIndex = min(startIndex + pageSize, filteredItems.count)
        
        let paginatedItems: [CustomerOutOfStock]
        if startIndex < filteredItems.count {
            paginatedItems = Array(filteredItems[startIndex..<endIndex])
        } else {
            paginatedItems = []
        }
        
        // Calculate hasMoreData based on filtered total count and current position
        let hasMoreData = (offset + paginatedItems.count) < filteredItems.count
        
        print("📊 [Repository] Memory filtering results: \(filteredItems.count) total matches, returning \(paginatedItems.count) items for page \(page), hasMore: \(hasMoreData)")
        
        return OutOfStockPaginationResult(
            items: paginatedItems,
            totalCount: filteredItems.count,
            hasMoreData: hasMoreData,
            page: page,
            pageSize: pageSize
        )
    }
    
    func countOutOfStockRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        // Use different counting strategy for search vs non-search operations
        if !criteria.searchText.isEmpty {
            // For search operations, we need to count all matching records (active + orphaned)
            let activeRecords = try await fetchAllMatchingActiveRecords(criteria: criteria)
            let orphanedRecords = try await fetchMatchingOrphanedRecords(
                searchText: criteria.searchText,
                dateRange: criteria.dateRange,
                status: criteria.status
            )
            return activeRecords.count + orphanedRecords.count
        } else {
            // For non-search operations, use efficient database counting
            return try await countForNonSearchCriteria(criteria: criteria)
        }
    }
    
    // MARK: - Search Helper Methods
    
    private func fetchAllMatchingActiveRecords(criteria: OutOfStockFilterCriteria) async throws -> [CustomerOutOfStock] {
        do {
            // Build predicate with only database-supported filters (no text search)
            let predicate = buildEnhancedPredicate(from: criteria)
            
            var descriptor: FetchDescriptor<CustomerOutOfStock>
            let sortOrder = criteria.sortOrder.isDescending ? SortOrder.reverse : SortOrder.forward
            if let predicate = predicate {
                descriptor = FetchDescriptor<CustomerOutOfStock>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.requestDate, order: sortOrder)]
                )
            } else {
                descriptor = FetchDescriptor<CustomerOutOfStock>(
                    sortBy: [SortDescriptor(\.requestDate, order: sortOrder)]
                )
            }
            
            // Get all records matching database-level filters
            let records = try await MainActor.run {
                return try modelContext.fetch(descriptor)
            }
            
            // Apply text search, customer, and product filtering in memory if needed
            var filteredRecords = records
            
            // Apply text search filtering
            if !criteria.searchText.isEmpty {
                filteredRecords = filteredRecords.filter { record in
                    matchesTextSearch(record: record, searchText: criteria.searchText)
                }
            }
            
            // Apply customer filtering
            if let customerFilter = criteria.customer {
                filteredRecords = filteredRecords.filter { $0.customer?.id == customerFilter.id }
                print("📊 [Repository] Search filtering: \(filteredRecords.count) items match customer \(customerFilter.name)")
            }
            
            // Apply product filtering
            if let productFilter = criteria.product {
                filteredRecords = filteredRecords.filter { $0.product?.id == productFilter.id }
                print("📊 [Repository] Search filtering: \(filteredRecords.count) items match product \(productFilter.name)")
            }
            
            // Safety check for large datasets
            if filteredRecords.count > 10000 {
                print("Warning: Large search result set (\(filteredRecords.count) records). Consider adding more specific filters.")
            }
            
            return filteredRecords
            
        } catch {
            print("Error fetching active records: \(error)")
            throw NSError(domain: "CustomerOutOfStockRepository", code: 2001,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch active records: \(error.localizedDescription)"])
        }
    }
    
    private func fetchMatchingOrphanedRecords(
        searchText: String,
        dateRange: (start: Date, end: Date)?,
        status: OutOfStockStatus?
    ) async throws -> [CustomerOutOfStock] {
        
        // Input validation
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        do {
            // Build predicate for orphaned records (customer == nil)
            var orphanPredicate: Predicate<CustomerOutOfStock>?
            
            if let dateRange = dateRange, let status = status {
                // Both date and status filters
                let dateStart = dateRange.start
                let dateEnd = dateRange.end
                let statusRawValue = status.rawValue
                
                orphanPredicate = #Predicate<CustomerOutOfStock> { item in
                    item.customer == nil &&
                    item.requestDate >= dateStart &&
                    item.requestDate <= dateEnd &&
                    item.status.rawValue == statusRawValue
                }
            } else if let dateRange = dateRange {
                // Only date filter
                let dateStart = dateRange.start
                let dateEnd = dateRange.end
                
                orphanPredicate = #Predicate<CustomerOutOfStock> { item in
                    item.customer == nil &&
                    item.requestDate >= dateStart &&
                    item.requestDate <= dateEnd
                }
            } else if let status = status {
                // Only status filter
                let statusRawValue = status.rawValue
                
                orphanPredicate = #Predicate<CustomerOutOfStock> { item in
                    item.customer == nil &&
                    item.status.rawValue == statusRawValue
                }
            } else {
                // No additional filters - just orphaned records
                orphanPredicate = #Predicate<CustomerOutOfStock> { item in
                    item.customer == nil
                }
            }
            
            guard let predicate = orphanPredicate else {
                return []
            }
            
            let descriptor = FetchDescriptor<CustomerOutOfStock>(predicate: predicate)
            let orphanedRecords = try await MainActor.run {
                return try modelContext.fetch(descriptor)
            }
            
            // Filter by cached customer name in notes using in-memory text search
            let filteredRecords = orphanedRecords.filter { item in
                // Check cached customer name from notes
                if let cachedName = safeExtractCustomerName(from: item) {
                    if cachedName.lowercased().contains(searchText.lowercased()) {
                        return true
                    }
                }
                
                // Also check notes field directly
                if let notes = item.notes {
                    if notes.lowercased().contains(searchText.lowercased()) {
                        return true
                    }
                }
                
                return false
            }
            
            return filteredRecords
            
        } catch {
            print("Error fetching orphaned records: \(error)")
            throw NSError(domain: "CustomerOutOfStockRepository", code: 2002,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch orphaned records: \(error.localizedDescription)"])
        }
    }
    
    private func safeExtractCustomerName(from item: CustomerOutOfStock) -> String? {
        // Safe wrapper around extractCustomerNameFromNotes
        // The method doesn't throw, but we add safety for any future changes
        return item.extractCustomerNameFromNotes()
    }
    
    private func matchesTextSearch(record: CustomerOutOfStock, searchText: String) -> Bool {
        let searchTextLowercase = searchText.lowercased()
        
        // Check customer name
        if let customer = record.customer {
            if customer.name.lowercased().contains(searchTextLowercase) {
                return true
            }
        }
        
        // Check product name
        if let product = record.product {
            if product.name.lowercased().contains(searchTextLowercase) {
                return true
            }
        }
        
        // Check notes
        if let notes = record.notes {
            if notes.lowercased().contains(searchTextLowercase) {
                return true
            }
        }
        
        return false
    }
    
    private func countForNonSearchCriteria(criteria: OutOfStockFilterCriteria) async throws -> Int {
        // Safe counting - use memory filtering when status, customer, or product is involved
        if criteria.status != nil || criteria.customer != nil || criteria.product != nil {
            // Use memory-based filtering for complex filters to avoid SwiftData predicate issues
            var allItemsDescriptor: FetchDescriptor<CustomerOutOfStock>
            
            if let dateRange = criteria.dateRange {
                let dateStart = dateRange.start
                let dateEnd = dateRange.end
                allItemsDescriptor = FetchDescriptor<CustomerOutOfStock>(
                    predicate: #Predicate<CustomerOutOfStock> { item in
                        item.requestDate >= dateStart && 
                        item.requestDate <= dateEnd
                    }
                )
            } else {
                allItemsDescriptor = FetchDescriptor<CustomerOutOfStock>()
            }
            
            let allItems = try await MainActor.run {
                return try modelContext.fetch(allItemsDescriptor)
            }
            
            // Apply all filters in memory
            var filteredItems = allItems
            
            if let statusFilter = criteria.status {
                filteredItems = filteredItems.filter { $0.status == statusFilter }
                print("📊 [Repository] Memory count: \(filteredItems.count) items match status \(statusFilter.displayName)")
            }
            
            if let customerFilter = criteria.customer {
                filteredItems = filteredItems.filter { $0.customer?.id == customerFilter.id }
                print("📊 [Repository] Memory count: \(filteredItems.count) items match customer \(customerFilter.name)")
            }
            
            if let productFilter = criteria.product {
                filteredItems = filteredItems.filter { $0.product?.id == productFilter.id }
                print("📊 [Repository] Memory count: \(filteredItems.count) items match product \(productFilter.name)")
            }
            
            return filteredItems.count
        } else {
            // For date-only filtering, use optimized batch counting to avoid loading all records
            return try await performOptimizedCount(criteria: criteria)
        }
    }
    
    /// Optimized counting that batches the work to avoid memory spikes
    private func performOptimizedCount(criteria: OutOfStockFilterCriteria) async throws -> Int {
        let batchSize = 1000
        var totalCount = 0
        var offset = 0
        
        print("📊 [Repository] Starting optimized count with batching (batchSize: \(batchSize))")
        
        while true {
            // Create descriptor with limit and offset for batching
            let predicate = buildPredicate(from: criteria)
            var descriptor = FetchDescriptor<CustomerOutOfStock>(predicate: predicate)
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset
            
            let batchCount = try await MainActor.run {
                let records = try modelContext.fetch(descriptor)
                return records.count
            }
            
            totalCount += batchCount
            print("📊 [Repository] Batch \(offset/batchSize + 1): counted \(batchCount) records (total: \(totalCount))")
            
            // If we got fewer records than batch size, we've reached the end
            if batchCount < batchSize {
                break
            }
            
            offset += batchSize
            
            // Add small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms pause between batches
        }
        
        print("📊 [Repository] Optimized count completed: \(totalCount) total records")
        return totalCount
    }
    
    // MARK: - Private Helper Methods
    
    private func buildPredicate(from criteria: OutOfStockFilterCriteria) -> Predicate<CustomerOutOfStock>? {
        // Safe predicate builder - only include date filtering, status filtering done in memory
        print("📊 [Repository] Building predicate - Status: \(criteria.status?.displayName ?? "none") (will filter in memory), Date: \(criteria.dateRange != nil)")
        
        // Only create date-based predicates as they are safe in SwiftData
        if let dateRange = criteria.dateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            print("📅 [Repository] Date range: \(formatter.string(from: dateRange.start)) to \(formatter.string(from: dateRange.end))")
            
            // Validate that the date range makes sense
            if dateRange.start >= dateRange.end {
                print("⚠️ [Repository] Invalid date range: start date is not before end date")
                return nil
            }
            
            let dateStart = dateRange.start
            let dateEnd = dateRange.end
            
            print("📊 [Repository] Creating date-only predicate for range: \(dateStart) to \(dateEnd)")
            
            return #Predicate<CustomerOutOfStock> { item in
                item.requestDate >= dateStart && item.requestDate <= dateEnd
            }
        }
        
        print("📊 [Repository] No date filter - will fetch all records and filter by status in memory")
        return nil
    }
    
    private func buildEnhancedPredicate(from criteria: OutOfStockFilterCriteria) -> Predicate<CustomerOutOfStock>? {
        // Safe enhanced predicate builder - only date filtering, status filtering done in memory
        let hasDateFilter = criteria.dateRange != nil
        
        // Only build date-based predicates to avoid SwiftData enum issues
        if hasDateFilter {
            let dateStart = criteria.dateRange!.start
            let dateEnd = criteria.dateRange!.end
            
            return #Predicate<CustomerOutOfStock> { item in
                item.requestDate >= dateStart && item.requestDate <= dateEnd
            }
        }
        
        // No database-level filtering needed - status and text search handled in memory
        return nil
    }
    
    private func combinePredicatesWithAND(_ predicates: [Predicate<CustomerOutOfStock>]) -> Predicate<CustomerOutOfStock>? {
        guard !predicates.isEmpty else { return nil }
        guard predicates.count > 1 else { return predicates.first }
        
        // For SwiftData, we need to create combined predicates manually
        // This is a simplified approach - for complex combinations, we may need to restructure
        if predicates.count >= 2 {
            // For now, return the first predicate and apply others in memory if needed
            // This is a limitation of SwiftData's predicate system
            return predicates.first
        }
        
        return predicates.first
    }
    
    // MARK: - Validation Helper Methods
    
    private func validateStatusFilter(_ status: OutOfStockStatus?) throws {
        guard let status = status else { return }
        
        // Ensure the status is a valid enum case
        guard OutOfStockStatus.allCases.contains(status) else {
            throw RepositoryError.invalidInput("Invalid status: \(status)")
        }
    }
    
    private func validatePaginationParameters(page: Int, pageSize: Int) throws {
        guard page >= 0 else {
            throw RepositoryError.invalidInput("Invalid page parameters: page=\(page), pageSize=\(pageSize)")
        }
        
        guard pageSize > 0 && pageSize <= 1000 else {
            throw RepositoryError.invalidInput("Invalid page size: \(pageSize)")
        }
    }
    
    // MARK: - Status Count Methods
    
    @MainActor
    func countOutOfStockRecordsByStatus(criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int] {
        print("📊 [Repository] Counting records by status with criteria...")
        
        do {
            // Use similar logic as countForNonSearchCriteria but group by status
            if !criteria.searchText.isEmpty {
                // For search operations, we need to count all matching records (active + orphaned)
                let activeRecords = try await fetchAllMatchingActiveRecords(criteria: criteria)
                let orphanedRecords = try await fetchMatchingOrphanedRecords(
                    searchText: criteria.searchText,
                    dateRange: criteria.dateRange,
                    status: criteria.status
                )
                
                // Count by status
                var statusCounts: [OutOfStockStatus: Int] = [:]
                let allRecords = activeRecords + orphanedRecords
                
                for record in allRecords {
                    statusCounts[record.status, default: 0] += 1
                }
                
                return statusCounts
                
            } else {
                // For non-search operations, use efficient database counting
                return try await countByStatusForNonSearchCriteria(criteria: criteria)
            }
            
        } catch {
            print("❌ [Repository] Failed to count by status: \(error)")
            throw NSError(domain: "LocalCustomerOutOfStockRepository", code: 3001,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to count records by status: \(error.localizedDescription)"])
        }
    }
    
    @MainActor
    private func countByStatusForNonSearchCriteria(criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int] {
        // Use safe approach - only date filtering in predicate
        var allItemsDescriptor: FetchDescriptor<CustomerOutOfStock>
        
        if let dateRange = criteria.dateRange {
            let dateStart = dateRange.start
            let dateEnd = dateRange.end
            allItemsDescriptor = FetchDescriptor<CustomerOutOfStock>(
                predicate: #Predicate<CustomerOutOfStock> { item in
                    item.requestDate >= dateStart && 
                    item.requestDate <= dateEnd
                }
            )
        } else {
            allItemsDescriptor = FetchDescriptor<CustomerOutOfStock>()
        }
        
        let records = try await MainActor.run {
            return try modelContext.fetch(allItemsDescriptor)
        }
        
        // Count by status in memory (safe)
        var statusCounts: [OutOfStockStatus: Int] = [:]
        for record in records {
            statusCounts[record.status, default: 0] += 1
        }
        
        print("📊 [Repository] Memory-based count by status: \(statusCounts)")
        return statusCounts
    }
    
}