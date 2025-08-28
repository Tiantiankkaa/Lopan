//
//  CustomerOutOfStockRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

// MARK: - Pagination Result
public struct OutOfStockPaginationResult {
    let items: [CustomerOutOfStock]
    let totalCount: Int
    let hasMoreData: Bool
    let page: Int
    let pageSize: Int
}

public protocol CustomerOutOfStockRepository {
    // Legacy methods (maintained for backward compatibility)
    func fetchOutOfStockRecords() async throws -> [CustomerOutOfStock]
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock?
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock]
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock]
    
    // New paginated methods
    func fetchOutOfStockRecords(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult
    
    func countOutOfStockRecords(criteria: OutOfStockFilterCriteria) async throws -> Int
    
    func countOutOfStockRecordsByStatus(criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int]
    
    // CRUD operations
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws
}