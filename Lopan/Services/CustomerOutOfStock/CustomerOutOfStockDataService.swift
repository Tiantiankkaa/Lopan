//
//  CustomerOutOfStockDataService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation
import os

/// Data access service for Customer Out-of-Stock operations
/// Handles repository operations, data persistence, and basic CRUD
@MainActor
protocol CustomerOutOfStockDataService {
    func fetchRecords(_ criteria: OutOfStockFilterCriteria) async throws -> [CustomerOutOfStock]
    func countRecords(_ criteria: OutOfStockFilterCriteria) async throws -> Int
    func createRecord(_ request: OutOfStockCreationRequest) async throws -> CustomerOutOfStock
    func updateRecord(_ item: CustomerOutOfStock) async throws
    func deleteRecord(_ item: CustomerOutOfStock) async throws
    func batchCreateRecords(_ requests: [OutOfStockCreationRequest]) async throws -> [CustomerOutOfStock]
}

@MainActor
class DefaultCustomerOutOfStockDataService: CustomerOutOfStockDataService {
    private let repository: CustomerOutOfStockRepository
    private let customerRepository: CustomerRepository
    private let productRepository: ProductRepository
    private let logger = Logger(subsystem: "com.lopan.app", category: "CustomerOutOfStockDataService")
    
    init(
        repository: CustomerOutOfStockRepository,
        customerRepository: CustomerRepository,
        productRepository: ProductRepository
    ) {
        self.repository = repository
        self.customerRepository = customerRepository
        self.productRepository = productRepository
    }
    
    // MARK: - Data Operations
    
    func fetchRecords(_ criteria: OutOfStockFilterCriteria) async throws -> [CustomerOutOfStock] {
        do {
            logger.safeInfo("Fetching records", [
                "customer": criteria.customer?.name ?? "all",
                "product": criteria.product?.name ?? "all", 
                "status": criteria.status?.displayName ?? "all",
                "page": String(criteria.page),
                "pageSize": String(criteria.pageSize)
            ])
            
            let result = try await repository.fetchOutOfStockRecords(
                criteria: criteria,
                page: criteria.page,
                pageSize: criteria.pageSize
            )
            let records = result.items
            
            logger.safeInfo("Successfully fetched records", ["count": String(records.count)])
            return records
        } catch {
            logger.safeError("Failed to fetch records", error: error, [
                "criteria": String(describing: criteria)
            ])
            throw error
        }
    }
    
    func countRecords(_ criteria: OutOfStockFilterCriteria) async throws -> Int {
        do {
            let count = try await repository.countOutOfStockRecords(criteria: criteria)
            logger.safeInfo("Record count fetched", ["count": String(count)])
            return count
        } catch {
            logger.safeError("Failed to count records", error: error)
            throw error
        }
    }
    
    func createRecord(_ request: OutOfStockCreationRequest) async throws -> CustomerOutOfStock {
        do {
            logger.safeInfo("Creating new record", [
                "customer": request.customer?.name ?? "unknown",
                "product": request.product?.name ?? "unknown",
                "quantity": String(request.quantity)
            ])
            
            let newItem = CustomerOutOfStock(
                customer: request.customer,
                product: request.product,
                productSize: request.productSize,
                quantity: request.quantity,
                notes: request.notes,
                createdBy: getCurrentUserId()
            )
            
            try await repository.addOutOfStockRecord(newItem)
            let savedItem = newItem
            logger.safeInfo("Successfully created record", ["id": savedItem.id])
            return savedItem
        } catch {
            logger.safeError("Failed to create record", error: error)
            throw error
        }
    }
    
    func updateRecord(_ item: CustomerOutOfStock) async throws {
        do {
            logger.safeInfo("Updating record", ["id": item.id])
            try await repository.updateOutOfStockRecord(item)
            logger.safeInfo("Successfully updated record", ["id": item.id])
        } catch {
            logger.safeError("Failed to update record", error: error, ["id": item.id])
            throw error
        }
    }
    
    func deleteRecord(_ item: CustomerOutOfStock) async throws {
        do {
            logger.safeInfo("Deleting record", ["id": item.id])
            try await repository.deleteOutOfStockRecord(item)
            logger.safeInfo("Successfully deleted record", ["id": item.id])
        } catch {
            logger.safeError("Failed to delete record", error: error, ["id": item.id])
            throw error
        }
    }
    
    func batchCreateRecords(_ requests: [OutOfStockCreationRequest]) async throws -> [CustomerOutOfStock] {
        do {
            logger.safeInfo("Batch creating records", ["count": String(requests.count)])
            
            // Process in background and return to main thread for UI updates
            return try await withThrowingTaskGroup(of: [CustomerOutOfStock].self) { group in
                let batchSize = 10
                
                // Pre-get user ID to avoid actor issues in concurrent tasks
                let currentUserId = getCurrentUserId()
                
                // Split into concurrent batches
                for batch in requests.batched(into: batchSize) {
                    group.addTask {
                        var batchResults: [CustomerOutOfStock] = []
                        
                        for request in batch {
                            let newItem = CustomerOutOfStock(
                                customer: request.customer,
                                product: request.product,
                                productSize: request.productSize,
                                quantity: request.quantity,
                                notes: request.notes,
                                createdBy: currentUserId
                            )
                            
                            try await self.repository.addOutOfStockRecord(newItem)
                            batchResults.append(newItem)
                        }
                        
                        return batchResults
                    }
                }
                
                // Collect all results
                var allResults: [CustomerOutOfStock] = []
                for try await batchResults in group {
                    allResults.append(contentsOf: batchResults)
                }
                
                logger.safeInfo("Successfully batch created records", ["count": String(allResults.count)])
                return allResults
            }
        } catch {
            logger.safeError("Failed to batch create records", error: error)
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String {
        // TODO: Get from authentication service
        return "system_user"
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func batched(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}