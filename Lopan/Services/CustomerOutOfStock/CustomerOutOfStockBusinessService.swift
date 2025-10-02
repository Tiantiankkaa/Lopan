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
        
        // Validate delivery quantity doesn't exceed original quantity
        if record.deliveryQuantity > record.quantity {
            throw BusinessError.invalidReturnQuantity("Delivery quantity cannot exceed original quantity")
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
        
        guard let customer = request.customer, !customer.name.isEmpty else {
            throw BusinessError.missingCustomer("Customer name cannot be empty")
        }
        
        guard let product = request.product, !product.name.isEmpty else {
            throw BusinessError.missingProduct("Product name cannot be empty")
        }
        
        // Business rule: Check for duplicate requests (same customer + product within 24 hours)
        // TODO: Implement duplicate checking logic
        
        logger.safeInfo("Creation request validation passed", [
            "customer": customer.name,
            "product": product.name,
            "quantity": String(request.quantity)
        ])
    }
    
    // MARK: - Business Operations
    
    func processReturn(_ item: CustomerOutOfStock, quantity: Int, notes: String?) async throws {
        logger.safeInfo("Processing delivery", [
            "itemId": item.id,
            "deliveryQuantity": String(quantity),
            "hasNotes": String(notes != nil)
        ])

        // Validate delivery quantity
        let remainingQuantity = item.quantity - item.deliveryQuantity
        guard quantity > 0 && quantity <= remainingQuantity else {
            throw BusinessError.invalidReturnQuantity("Invalid return quantity: \(quantity)")
        }
        
        // Update item delivery information
        item.deliveryQuantity += quantity
        item.deliveryNotes = combineNotes(existing: item.deliveryNotes, new: notes)
        item.updatedAt = Date()

        // Update status to completed when delivering
        item.status = .completed
        
        // Save the updated item
        try await dataService.updateRecord(item)
        
        logger.safeInfo("Delivery processed successfully", [
            "itemId": item.id,
            "newStatus": item.status.displayName,
            "totalDelivered": String(item.deliveryQuantity)
        ])
    }
    
    func calculateStatistics(_ criteria: OutOfStockFilterCriteria) async throws -> OutOfStockStatistics {
        let records = try await dataService.fetchRecords(criteria)
        
        // Perform single-pass calculation to avoid multiple array iterations
        return await withTaskGroup(of: OutOfStockStatistics.self) { group in
            group.addTask {
                var pendingCount = 0
                var partiallyDeliveredCount = 0
                var fullyDeliveredCount = 0
                var totalQuantity = 0
                var totalDeliveredQuantity = 0
                var totalProcessingTime: TimeInterval = 0
                var completedItemsCount = 0
                
                // Single pass through all records
                for record in records {
                    // Count by status
                    switch record.status {
                    case .pending:
                        pendingCount += 1
                    case .completed:
                        fullyDeliveredCount += 1
                        completedItemsCount += 1
                        totalProcessingTime += record.updatedAt.timeIntervalSince(record.requestDate)
                    case .refunded:
                        fullyDeliveredCount += 1
                        completedItemsCount += 1
                        totalProcessingTime += record.updatedAt.timeIntervalSince(record.requestDate)
                    }
                    
                    // Check for partial deliveries
                    if record.deliveryQuantity > 0 && record.deliveryQuantity < record.quantity {
                        partiallyDeliveredCount += 1
                    }

                    totalQuantity += record.quantity
                    totalDeliveredQuantity += record.deliveryQuantity
                }
                
                let averageProcessingTime = completedItemsCount > 0 ? 
                    totalProcessingTime / Double(completedItemsCount) : 0
                
                return OutOfStockStatistics(
                    totalItems: records.count,
                    pendingCount: pendingCount,
                    partiallyDeliveredCount: partiallyDeliveredCount,
                    fullyDeliveredCount: fullyDeliveredCount,
                    totalQuantity: totalQuantity,
                    totalDeliveredQuantity: totalDeliveredQuantity,
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
                totalItems: 0, pendingCount: 0, partiallyDeliveredCount: 0,
                fullyDeliveredCount: 0, totalQuantity: 0, totalDeliveredQuantity: 0,
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
            "returned": String(statusCounts[.refunded] ?? 0)
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
