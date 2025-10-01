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

// MARK: - Dashboard Metrics Result
public struct DashboardMetrics {
    let statusCounts: [OutOfStockStatus: Int]
    let needsReturnCount: Int
    let dueSoonCount: Int
    let overdueCount: Int

    // Display items collected during single pass
    let topPendingItems: [CustomerOutOfStock]  // Top 50 oldest pending
    let topReturnItems: [CustomerOutOfStock]   // Top 10 items needing return
    let recentCompleted: [CustomerOutOfStock]  // Top 10 recently completed
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
    func countPartialReturnRecords(criteria: OutOfStockFilterCriteria) async throws -> Int
    func countDueSoonRecords(criteria: OutOfStockFilterCriteria) async throws -> Int
    func countOverdueRecords(criteria: OutOfStockFilterCriteria) async throws -> Int

    // OPTIMIZED: Single-pass dashboard metrics calculation
    func fetchDashboardMetrics() async throws -> DashboardMetrics

    // CRUD operations
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func addOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws  // Bulk insert
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws
}
