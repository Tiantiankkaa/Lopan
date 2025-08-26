//
//  CustomerOutOfStockBusinessService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation
import os

/// Business logic service for Customer Out-of-Stock operations
/// Handles validation, business rules, calculations, and return processing
@MainActor
protocol CustomerOutOfStockBusinessService {
    func validateRecord(_ record: CustomerOutOfStock) throws
    func validateCreationRequest(_ request: OutOfStockCreationRequest) throws
    func processReturn(_ item: CustomerOutOfStock, quantity: Int, notes: String?) async throws
    func calculateStatistics(_ criteria: OutOfStockFilterCriteria) async throws -> OutOfStockStatistics
    func getStatusCounts(_ criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int]
    func canUserModify(_ item: CustomerOutOfStock, userId: String) -> Bool
}


@MainActor
class DefaultCustomerOutOfStockBusinessService: CustomerOutOfStockBusinessService {
    private let dataService: CustomerOutOfStockDataService
    private let authService: AuthenticationService
    private let logger = Logger(subsystem: "com.lopan.app", category: "CustomerOutOfStockBusinessService")
    
    init(
        dataService: CustomerOutOfStockDataService,
        authService: AuthenticationService
    ) {
        self.dataService = dataService
        self.authService = authService
    }
    
    // MARK: - Validation
    
    func validateRecord(_ record: CustomerOutOfStock) throws {
        guard record.quantity > 0 else {
            throw BusinessError.invalidQuantity("Quantity must be greater than 0")
        }
        
        guard let customer = record.customer else {
            throw BusinessError.missingCustomer("Customer is required")
        }
        
        guard let product = record.product else {
            throw BusinessError.missingProduct("Product is required")
        }
        
        // Validate return quantity doesn't exceed original quantity
        if record.returnQuantity > record.quantity {
            throw BusinessError.invalidReturnQuantity("Return quantity cannot exceed original quantity")
        }
        
        logger.safeInfo("Record validation passed", [
            "id": record.id,
            "customer": customer.name,
            "product": product.name
        ])
    }
    
    func validateCreationRequest(_ request: OutOfStockCreationRequest) throws {
        guard request.quantity > 0 else {
            throw BusinessError.invalidQuantity("Quantity must be greater than 0")
        }
        
        guard !request.customer.name.isEmpty else {
            throw BusinessError.missingCustomer("Customer name cannot be empty")
        }
        
        guard !request.product.name.isEmpty else {
            throw BusinessError.missingProduct("Product name cannot be empty")
        }
        
        // Business rule: Check for duplicate requests (same customer + product within 24 hours)
        // TODO: Implement duplicate checking logic
        
        logger.safeInfo("Creation request validation passed", [
            "customer": request.customer.name,
            "product": request.product.name,
            "quantity": String(request.quantity)
        ])
    }
    
    // MARK: - Business Operations
    
    func processReturn(_ item: CustomerOutOfStock, quantity: Int, notes: String?) async throws {
        logger.safeInfo("Processing return", [
            "itemId": item.id,
            "returnQuantity": String(quantity),
            "hasNotes": String(notes != nil)
        ])
        
        // Validate return quantity
        let remainingQuantity = item.quantity - item.returnQuantity
        guard quantity > 0 && quantity <= remainingQuantity else {
            throw BusinessError.invalidReturnQuantity("Invalid return quantity: \(quantity)")
        }
        
        // Update item return information
        item.returnQuantity += quantity
        item.returnNotes = combineNotes(existing: item.returnNotes, new: notes)
        item.updatedAt = Date()
        
        // Update status based on return progress
        if item.returnQuantity >= item.quantity {
            item.status = .completed
        } else if item.returnQuantity > 0 {
            item.status = .pending
        }
        
        // Save the updated item
        try await dataService.updateRecord(item)
        
        logger.safeInfo("Return processed successfully", [
            "itemId": item.id,
            "newStatus": item.status.displayName,
            "totalReturned": String(item.returnQuantity)
        ])
    }
    
    func calculateStatistics(_ criteria: OutOfStockFilterCriteria) async throws -> OutOfStockStatistics {
        let records = try await dataService.fetchRecords(criteria)
        
        // Perform single-pass calculation to avoid multiple array iterations
        return await withTaskGroup(of: OutOfStockStatistics.self) { group in
            group.addTask {
                var pendingCount = 0
                var partiallyReturnedCount = 0
                var fullyReturnedCount = 0
                var totalQuantity = 0
                var totalReturnedQuantity = 0
                var totalProcessingTime: TimeInterval = 0
                var completedItemsCount = 0
                
                // Single pass through all records
                for record in records {
                    // Count by status
                    switch record.status {
                    case .pending:
                        pendingCount += 1
                    case .completed:
                        fullyReturnedCount += 1
                        completedItemsCount += 1
                        totalProcessingTime += record.updatedAt.timeIntervalSince(record.requestDate)
                    case .cancelled:
                        break // Don't count cancelled items in statistics
                    }
                    
                    // Check for partial returns
                    if record.returnQuantity > 0 && record.returnQuantity < record.quantity {
                        partiallyReturnedCount += 1
                    }
                    
                    totalQuantity += record.quantity
                    totalReturnedQuantity += record.returnQuantity
                }
                
                let averageProcessingTime = completedItemsCount > 0 ? 
                    totalProcessingTime / Double(completedItemsCount) : 0
                
                return OutOfStockStatistics(
                    totalItems: records.count,
                    pendingCount: pendingCount,
                    partiallyReturnedCount: partiallyReturnedCount,
                    fullyReturnedCount: fullyReturnedCount,
                    totalQuantity: totalQuantity,
                    totalReturnedQuantity: totalReturnedQuantity,
                    averageProcessingTime: averageProcessingTime
                )
            }
            
            // Return the result from task group
            var result: OutOfStockStatistics? = nil
            for await taskResult in group {
                result = taskResult
                break
            }
            return result ?? OutOfStockStatistics(
                totalItems: 0, pendingCount: 0, partiallyReturnedCount: 0,
                fullyReturnedCount: 0, totalQuantity: 0, totalReturnedQuantity: 0,
                averageProcessingTime: 0
            )
        }
    }
    
    func getStatusCounts(_ criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int] {
        // Create separate criteria for each status
        var statusCounts: [OutOfStockStatus: Int] = [:]
        
        for status in OutOfStockStatus.allCases {
            let statusCriteria = OutOfStockFilterCriteria(
                customer: criteria.customer,
                product: criteria.product,
                status: status,
                dateRange: criteria.dateRange,
                searchText: criteria.searchText,
                page: criteria.page,
                pageSize: criteria.pageSize,
                sortOrder: criteria.sortOrder
            )
            let count = try await dataService.countRecords(statusCriteria)
            statusCounts[status] = count
        }
        
        logger.safeInfo("Status counts calculated", [
            "pending": String(statusCounts[.pending] ?? 0),
            "completed": String(statusCounts[.completed] ?? 0),
            "cancelled": String(statusCounts[.cancelled] ?? 0)
        ])
        
        return statusCounts
    }
    
    func canUserModify(_ item: CustomerOutOfStock, userId: String) -> Bool {
        // Business rules for modification permissions
        
        // Rule 1: User can always modify their own records
        if item.createdBy == userId {
            return true
        }
        
        // Rule 2: For now, allow all authenticated users to modify records
        // TODO: Implement proper role-based authorization with hasRole method
        guard let currentUser = authService.currentUser else {
            return false
        }
        
        // Rule 3: Allow modifications if user is authenticated and either owns the record or is the current user
        if currentUser.id == userId {
            return true
        }
        
        // Rule 4: Regular users can only modify pending items within 24 hours
        let hoursSinceCreation = Date().timeIntervalSince(item.requestDate) / 3600
        return item.status == .pending && hoursSinceCreation <= 24
    }
    
    // MARK: - Helper Methods
    
    private func combineNotes(existing: String?, new: String?) -> String? {
        switch (existing, new) {
        case (nil, nil):
            return nil
        case (let existing?, nil):
            return existing
        case (nil, let new?):
            return new
        case (let existing?, let new?):
            return "\(existing)\n\n[追加] \(new)"
        }
    }
}

// MARK: - Business Errors

enum BusinessError: Error, LocalizedError {
    case invalidQuantity(String)
    case invalidReturnQuantity(String)
    case missingCustomer(String)
    case missingProduct(String)
    case unauthorizedOperation(String)
    case duplicateRecord(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidQuantity(let message),
             .invalidReturnQuantity(let message),
             .missingCustomer(let message),
             .missingProduct(let message),
             .unauthorizedOperation(let message),
             .duplicateRecord(let message):
            return message
        }
    }
}