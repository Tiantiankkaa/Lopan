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
        return try modelContext.fetch(descriptor)
    }
    
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock? {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try modelContext.fetch(descriptor)
        return records.first { $0.id == id }
    }
    
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try modelContext.fetch(descriptor)
        return records.filter { $0.customer?.id == customer.id }
    }
    
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try modelContext.fetch(descriptor)
        return records.filter { $0.product?.id == product.id }
    }
    
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        modelContext.insert(record)
        try modelContext.save()
    }
    
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        try modelContext.save()
    }
    
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        modelContext.delete(record)
        try modelContext.save()
    }
    
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws {
        for record in records {
            modelContext.delete(record)
        }
        try modelContext.save()
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
            
            print("📊 [Repository] Executing fetch with predicate: \(predicate != nil)")
            
            // Perform the fetch operation with error handling
            let fetchedItems: [CustomerOutOfStock]
            do {
                fetchedItems = try modelContext.fetch(paginatedDescriptor)
                print("📊 [Repository] Successfully fetched \(fetchedItems.count) items")
            } catch {
                print("❌ [Repository] Fetch failed: \(error)")
                // Try a fallback approach without predicate if status filter fails
                if criteria.status != nil {
                    print("📊 [Repository] Retrying without status filter...")
                    var fallbackDescriptor = FetchDescriptor<CustomerOutOfStock>(sortBy: [sortDescriptor])
                    fallbackDescriptor.fetchLimit = fetchLimit
                    fallbackDescriptor.fetchOffset = offset
                    
                    let allItems = try modelContext.fetch(fallbackDescriptor)
                    // Filter in memory for status
                    if let statusFilter = criteria.status {
                        let filteredItems = allItems.filter { $0.status == statusFilter }
                        print("📊 [Repository] Fallback filtering: \(filteredItems.count) items match status")
                        fetchedItems = Array(filteredItems.prefix(pageSize))
                    } else {
                        fetchedItems = allItems
                    }
                } else {
                    throw error
                }
            }
            
            // Get total count for pagination (with error handling)
            let totalCount: Int
            do {
                totalCount = try await countForNonSearchCriteria(criteria: criteria)
            } catch {
                print("⚠️ [Repository] Count operation failed, using fetched items count: \(error)")
                totalCount = fetchedItems.count
            }
            
            let hasMoreData = fetchedItems.count == pageSize
            
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
            let records = try modelContext.fetch(descriptor)
            
            // Apply text search filtering in memory if needed
            let filteredRecords: [CustomerOutOfStock]
            if !criteria.searchText.isEmpty {
                filteredRecords = records.filter { record in
                    matchesTextSearch(record: record, searchText: criteria.searchText)
                }
            } else {
                filteredRecords = records
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
            let orphanedRecords = try modelContext.fetch(descriptor)
            
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
        // Efficient counting for non-search operations
        let predicate = buildPredicate(from: criteria)
        let descriptor = FetchDescriptor<CustomerOutOfStock>(predicate: predicate)
        let records = try modelContext.fetch(descriptor)
        return records.count
    }
    
    // MARK: - Private Helper Methods
    
    private func buildPredicate(from criteria: OutOfStockFilterCriteria) -> Predicate<CustomerOutOfStock>? {
        // Simplified predicate builder to avoid SwiftData thread issues
        print("📊 [Repository] Building predicate - Status: \(criteria.status?.displayName ?? "none"), Date: \(criteria.dateRange != nil)")
        
        do {
            try validateStatusFilter(criteria.status)
        } catch {
            print("❌ [Repository] Status validation failed in buildPredicate: \(error)")
            return nil
        }
        
        let hasStatusFilter = criteria.status != nil
        let hasDateFilter = criteria.dateRange != nil
        
        // Use simplified approach - create single predicate instead of combining multiple
        if hasStatusFilter && hasDateFilter {
            let targetStatus = criteria.status!
            let dateStart = criteria.dateRange!.start
            let dateEnd = criteria.dateRange!.end
            
            print("📊 [Repository] Creating combined status+date predicate for: \(targetStatus)")
            
            // Use direct enum comparison instead of rawValue
            return #Predicate<CustomerOutOfStock> { item in
                item.status == targetStatus &&
                item.requestDate >= dateStart && 
                item.requestDate <= dateEnd
            }
        } else if hasStatusFilter {
            let targetStatus = criteria.status!
            
            print("📊 [Repository] Creating status-only predicate for: \(targetStatus)")
            
            // Use direct enum comparison for better SwiftData compatibility
            return #Predicate<CustomerOutOfStock> { item in
                item.status == targetStatus
            }
        } else if hasDateFilter {
            let dateStart = criteria.dateRange!.start
            let dateEnd = criteria.dateRange!.end
            
            print("📊 [Repository] Creating date-only predicate")
            
            return #Predicate<CustomerOutOfStock> { item in
                item.requestDate >= dateStart && item.requestDate <= dateEnd
            }
        }
        
        print("📊 [Repository] No predicate needed")
        return nil
    }
    
    private func buildEnhancedPredicate(from criteria: OutOfStockFilterCriteria) -> Predicate<CustomerOutOfStock>? {
        // Enhanced predicate builder - only database-supported filters (no text search at DB level)
        do {
            try validateStatusFilter(criteria.status)
        } catch {
            print("Status validation failed in buildEnhancedPredicate: \(error)")
            return nil
        }
        
        let hasDateFilter = criteria.dateRange != nil
        let hasStatusFilter = criteria.status != nil
        
        // Build predicate with only database-supported filters
        if hasDateFilter && hasStatusFilter {
            let dateStart = criteria.dateRange!.start
            let dateEnd = criteria.dateRange!.end
            let statusRawValue = criteria.status!.rawValue
            
            return #Predicate<CustomerOutOfStock> { item in
                item.requestDate >= dateStart && item.requestDate <= dateEnd &&
                item.status.rawValue == statusRawValue
            }
        } else if hasDateFilter {
            let dateStart = criteria.dateRange!.start
            let dateEnd = criteria.dateRange!.end
            
            return #Predicate<CustomerOutOfStock> { item in
                item.requestDate >= dateStart && item.requestDate <= dateEnd
            }
        } else if hasStatusFilter {
            let statusRawValue = criteria.status!.rawValue
            
            return #Predicate<CustomerOutOfStock> { item in
                item.status.rawValue == statusRawValue
            }
        }
        
        // No database-level filtering needed - text search handled in memory
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
    
}