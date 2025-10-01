//
//  SalesRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import Foundation

/// Repository protocol for managing daily sales entries
@MainActor
public protocol SalesRepository: AnyObject, Sendable {
    /// Fetch all sales entries for a specific date
    /// - Parameter date: The date to fetch sales for (will be normalized to start of day)
    /// - Returns: Array of sales entries for the specified date
    /// - Throws: RepositoryError if the fetch fails
    func fetchSalesEntries(forDate date: Date) async throws -> [DailySalesEntry]

    /// Fetch sales entries within a date range for a specific salesperson
    /// - Parameters:
    ///   - startDate: Start date of the range (inclusive)
    ///   - endDate: End date of the range (inclusive)
    ///   - salespersonId: ID of the salesperson
    /// - Returns: Array of sales entries within the date range
    /// - Throws: RepositoryError if the fetch fails
    func fetchSalesEntries(from startDate: Date, to endDate: Date, salespersonId: String) async throws -> [DailySalesEntry]

    /// Create a new sales entry
    /// - Parameter entry: The sales entry to create
    /// - Throws: RepositoryError if the creation fails
    func createSalesEntry(_ entry: DailySalesEntry) async throws

    /// Update an existing sales entry
    /// - Parameter entry: The sales entry to update
    /// - Throws: RepositoryError if the update fails
    func updateSalesEntry(_ entry: DailySalesEntry) async throws

    /// Delete a sales entry by ID
    /// - Parameter id: The ID of the sales entry to delete
    /// - Throws: RepositoryError if the deletion fails
    func deleteSalesEntry(id: String) async throws

    /// Calculate total sales amount for a specific date and salesperson
    /// - Parameters:
    ///   - date: The date to calculate sales for
    ///   - salespersonId: ID of the salesperson
    /// - Returns: Total sales amount for the specified date
    /// - Throws: RepositoryError if the calculation fails
    func calculateDailySalesTotal(forDate date: Date, salespersonId: String) async throws -> Decimal
}
