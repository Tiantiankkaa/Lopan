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

// MARK: - Display Item DTO (Value Type for crossing actor boundaries)
/// Lightweight DTO representing CustomerOutOfStock data for display purposes
/// Safe to pass across actor boundaries (no SwiftData dependencies)
public struct OutOfStockDisplayItem: Identifiable, Sendable {
    public let id: String
    public let status: OutOfStockStatus
    public let requestDate: Date
    public let actualCompletionDate: Date?
    public let updatedAt: Date
    public let deliveryDate: Date?
    public let deliveryQuantity: Int
    public let quantity: Int
    public let customerDisplayName: String
    public let productDisplayName: String

    // Computed properties
    public var remainingQuantity: Int {
        quantity - deliveryQuantity
    }

    public var hasPartialDelivery: Bool {
        deliveryQuantity > 0 && deliveryQuantity < quantity
    }

    /// Initialize from SwiftData model (within actor context)
    public init(from model: CustomerOutOfStock) {
        self.id = model.id
        self.status = model.status
        self.requestDate = model.requestDate
        self.actualCompletionDate = model.actualCompletionDate
        self.updatedAt = model.updatedAt
        self.deliveryDate = model.deliveryDate
        self.deliveryQuantity = model.deliveryQuantity
        self.quantity = model.quantity
        // Capture computed properties while in context
        self.customerDisplayName = model.customerDisplayName
        self.productDisplayName = model.productDisplayName
    }
}

// MARK: - Dashboard Metrics Result
public struct DashboardMetrics {
    let statusCounts: [OutOfStockStatus: Int]
    let needsReturnCount: Int
    let recentPendingCount: Int  // Pending items < 7 days old
    let dueSoonCount: Int
    let overdueCount: Int

    // Display items collected during single pass (DTOs safe for cross-actor use)
    let topPendingItems: [OutOfStockDisplayItem]  // Top 50 oldest pending (< 7 days)
    let topReturnItems: [OutOfStockDisplayItem]   // Top 10 items needing return
    let recentCompleted: [OutOfStockDisplayItem]  // Top 10 recently completed
}

// MARK: - Delivery Management Metrics Result
public struct DeliveryManagementMetrics {
    let items: [CustomerOutOfStock]
    let totalCount: Int
    let hasMoreData: Bool
    let page: Int
    let pageSize: Int

    // Statistics collected during single pass
    // Logic matches ViewModel for consistency
    let needsDeliveryCount: Int      // status == .pending && deliveryQuantity == 0
    let partialDeliveryCount: Int    // status == .pending && 0 < deliveryQuantity < quantity
    let completedDeliveryCount: Int  // deliveryQuantity >= quantity
}

// MARK: - Delivery Statistics (Background Loading)
public struct DeliveryStatistics {
    let totalCount: Int
    let needsDeliveryCount: Int
    let partialDeliveryCount: Int
    let completedDeliveryCount: Int
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

    // OPTIMIZED: Single-pass delivery management metrics calculation
    func fetchDeliveryManagementMetrics(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> DeliveryManagementMetrics

    // OPTIMIZED: Background statistics calculation (non-blocking)
    func fetchDeliveryStatistics(
        criteria: OutOfStockFilterCriteria
    ) async throws -> DeliveryStatistics

    // CRUD operations
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func addOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws  // Bulk insert
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws
}
