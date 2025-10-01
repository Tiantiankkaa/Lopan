//
//  SalesService.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import Foundation

/// Service layer for managing daily sales entries and calculations
@MainActor
public class SalesService: ObservableObject {
    private let salesRepository: SalesRepository
    private let productRepository: ProductRepository
    private let auditingService: NewAuditingService
    private let calendar = Calendar.current

    @Published public var isLoading = false
    @Published public var error: Error?

    public init(repositoryFactory: RepositoryFactory) {
        self.salesRepository = repositoryFactory.salesRepository
        self.productRepository = repositoryFactory.productRepository
        self.auditingService = NewAuditingService(repositoryFactory: repositoryFactory)
    }

    // MARK: - Sales Entry Management

    /// Save a new sales entry
    /// - Parameters:
    ///   - entry: The sales entry to save
    ///   - createdBy: ID of the user creating the entry
    /// - Throws: Error if validation or save fails
    public func saveSalesEntry(_ entry: DailySalesEntry, createdBy: String) async throws {
        // Validate the entry
        try validateSalesEntry(entry)

        // Save to repository
        try await salesRepository.createSalesEntry(entry)

        // Log the creation
        await auditingService.logCreate(
            entityType: .product, // Using .product as closest match, could extend enum later
            entityId: entry.id,
            entityDescription: "Sales Entry - \(formatDate(entry.date))",
            operatorUserId: createdBy,
            operatorUserName: createdBy,
            createdData: [
                "date": formatDate(entry.date),
                "total_amount": entry.totalAmount,
                "items_count": entry.items?.count ?? 0
            ]
        )
    }

    /// Update an existing sales entry
    /// - Parameters:
    ///   - entry: The sales entry to update
    ///   - updatedBy: ID of the user updating the entry
    /// - Throws: Error if validation or update fails
    public func updateSalesEntry(_ entry: DailySalesEntry, updatedBy: String) async throws {
        // Validate the entry
        try validateSalesEntry(entry)

        // Update in repository
        try await salesRepository.updateSalesEntry(entry)

        // Log the update
        await auditingService.logUpdate(
            entityType: .product,
            entityId: entry.id,
            entityDescription: "Sales Entry - \(formatDate(entry.date))",
            operatorUserId: updatedBy,
            operatorUserName: updatedBy,
            beforeData: [:],
            afterData: [
                "date": formatDate(entry.date),
                "total_amount": entry.totalAmount,
                "items_count": entry.items?.count ?? 0
            ],
            changedFields: ["date", "total_amount", "items_count"]
        )
    }

    /// Delete a sales entry
    /// - Parameters:
    ///   - id: ID of the entry to delete
    ///   - deletedBy: ID of the user deleting the entry
    /// - Throws: Error if deletion fails
    public func deleteSalesEntry(id: String, deletedBy: String) async throws {
        try await salesRepository.deleteSalesEntry(id: id)

        await auditingService.logDelete(
            entityType: .product,
            entityId: id,
            entityDescription: "Sales Entry",
            operatorUserId: deletedBy,
            operatorUserName: deletedBy,
            deletedData: [:]
        )
    }

    // MARK: - Sales Calculations

    /// Calculate daily sales metrics for a specific date and salesperson
    /// - Parameters:
    ///   - date: The date to calculate sales for
    ///   - salespersonId: ID of the salesperson
    /// - Returns: DailySalesMetric with amount and trend
    /// - Throws: Error if calculation fails
    func calculateDailySales(forDate date: Date, salespersonId: String) async throws -> SalespersonDashboardViewModel.DailySalesMetric {
        // Get today's sales total
        let todayTotal = try await salesRepository.calculateDailySalesTotal(
            forDate: date,
            salespersonId: salespersonId
        )

        // Get yesterday's sales total for trend calculation
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)!
        let yesterdayTotal = try await salesRepository.calculateDailySalesTotal(
            forDate: yesterday,
            salespersonId: salespersonId
        )

        // Calculate trend
        let trend = calculateTrend(current: todayTotal, previous: yesterdayTotal)

        return SalespersonDashboardViewModel.DailySalesMetric(
            amount: todayTotal,
            trend: trend,
            comparisonText: "salesperson_overview_daily_sales_vs_yesterday".localizedKey
        )
    }

    /// Calculate trend percentage between two values
    /// - Parameters:
    ///   - current: Current value
    ///   - previous: Previous value
    /// - Returns: Trend as a decimal (e.g., 0.15 for 15% increase)
    public func calculateTrend(current: Decimal, previous: Decimal) -> Double {
        guard previous > 0 else {
            return current > 0 ? 1.0 : 0.0 // 100% increase if starting from zero, 0% if both zero
        }

        let change = current - previous
        let trendDecimal = change / previous

        return NSDecimalNumber(decimal: trendDecimal).doubleValue
    }

    // MARK: - Validation

    /// Validate a sales entry before saving
    /// - Parameter entry: The entry to validate
    /// - Throws: SalesValidationError if validation fails
    public func validateSalesEntry(_ entry: DailySalesEntry) throws {
        // Check that entry has items
        guard let items = entry.items, !items.isEmpty else {
            throw SalesValidationError.emptyItems
        }

        // Check that all items have valid quantities
        for item in items {
            guard item.quantity > 0 else {
                throw SalesValidationError.invalidQuantity(productName: item.productName)
            }

            guard item.unitPrice > 0 else {
                throw SalesValidationError.invalidPrice(productName: item.productName)
            }
        }

        // Check that date is not in the future
        let today = calendar.startOfDay(for: Date())
        let entryDate = calendar.startOfDay(for: entry.date)
        guard entryDate <= today else {
            throw SalesValidationError.futureDate
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Validation Errors

public enum SalesValidationError: LocalizedError {
    case emptyItems
    case invalidQuantity(productName: String)
    case invalidPrice(productName: String)
    case futureDate

    public var errorDescription: String? {
        switch self {
        case .emptyItems:
            return NSLocalizedString("sales_validation_empty_items", comment: "Sales entry must have at least one item")
        case .invalidQuantity(let productName):
            return String(format: NSLocalizedString("sales_validation_invalid_quantity", comment: "Invalid quantity for %@"), productName)
        case .invalidPrice(let productName):
            return String(format: NSLocalizedString("sales_validation_invalid_price", comment: "Invalid price for %@"), productName)
        case .futureDate:
            return NSLocalizedString("sales_validation_future_date", comment: "Sales date cannot be in the future")
        }
    }
}
