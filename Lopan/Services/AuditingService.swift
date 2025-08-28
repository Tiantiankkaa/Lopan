//
//  AuditingService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import Foundation
import os

// MARK: - Audit Operation Types

enum AuditOperation: String, CaseIterable {
    case create = "CREATE"
    case read = "READ"
    case update = "UPDATE"
    case delete = "DELETE"
    case login = "LOGIN"
    case logout = "LOGOUT"
    case access = "ACCESS"
    case export = "EXPORT"
    case importData = "IMPORT"
    case sync = "SYNC"
}

@MainActor
public class AuditingService {
    private let auditRepository: AuditRepository
    private let logger = Logger(subsystem: "com.lopan.app", category: "AuditingService")
    
    init(auditRepository: AuditRepository) {
        self.auditRepository = auditRepository
    }
    
    // MARK: - Main Logging Methods
    
    /// Log a general operation
    func logOperation(
        operationType: OperationType,
        entityType: EntityType,
        entityId: String,
        entityDescription: String,
        operatorUserId: String,
        operatorUserName: String,
        operationDetails: [String: Any],
        batchId: String? = nil,
        relatedEntityIds: [String] = []
    ) async {
        let detailsJson = convertToJsonString(operationDetails)
        
        let auditLog = AuditLog(
            operationType: operationType,
            entityType: entityType,
            entityId: entityId,
            entityDescription: entityDescription,
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: detailsJson,
            deviceInfo: getDeviceInfo(),
            batchId: batchId,
            relatedEntityIds: relatedEntityIds
        )
        
        do {
            try await auditRepository.addAuditLog(auditLog)
        } catch {
            logger.safeError("Failed to save audit log", error: error)
        }
    }
    
    // MARK: - Customer Out of Stock Specific Logging
    
    /// Log creation of a customer out-of-stock record
    func logCustomerOutOfStockCreation(
        item: CustomerOutOfStock,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let afterValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            status: item.status.displayName,
            notes: item.notes,
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
        
        let operation = CustomerOutOfStockOperation(
            beforeValues: nil,
            afterValues: afterValues,
            changedFields: ["all"],
            additionalInfo: "新创建缺货记录"
        )
        
        let details: [String: Any] = [
            "operation": try! convertToDict(operation),
            "productDisplayName": item.productDisplayName
        ]
        
        await logOperation(
            operationType: .create,
            entityType: .customerOutOfStock,
            entityId: item.id,
            entityDescription: "\(item.customer?.name ?? "未知客户") - \(item.productDisplayName)",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: details
        )
    }
    
    /// Log update of a customer out-of-stock record
    func logCustomerOutOfStockUpdate(
        item: CustomerOutOfStock,
        beforeValues: CustomerOutOfStockOperation.CustomerOutOfStockValues,
        changedFields: [String],
        operatorUserId: String,
        operatorUserName: String,
        additionalInfo: String? = nil
    ) async {
        let afterValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            status: item.status.displayName,
            notes: item.notes,
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
        
        let operation = CustomerOutOfStockOperation(
            beforeValues: beforeValues,
            afterValues: afterValues,
            changedFields: changedFields,
            additionalInfo: additionalInfo
        )
        
        let details: [String: Any] = [
            "operation": try! convertToDict(operation),
            "productDisplayName": item.productDisplayName
        ]
        
        await logOperation(
            operationType: .update,
            entityType: .customerOutOfStock,
            entityId: item.id,
            entityDescription: "\(item.customer?.name ?? "未知客户") - \(item.productDisplayName)",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: details
        )
    }
    
    /// Log status change specifically
    func logCustomerOutOfStockStatusChange(
        item: CustomerOutOfStock,
        fromStatus: OutOfStockStatus,
        toStatus: OutOfStockStatus,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let details: [String: Any] = [
            "fromStatus": fromStatus.displayName,
            "toStatus": toStatus.displayName,
            "statusChangeReason": "状态变更",
            "productDisplayName": item.productDisplayName
        ]
        
        await logOperation(
            operationType: .statusChange,
            entityType: .customerOutOfStock,
            entityId: item.id,
            entityDescription: "\(item.customer?.name ?? "未知客户") - \(item.productDisplayName)",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: details
        )
    }
    
    /// Log return processing
    func logReturnProcessing(
        item: CustomerOutOfStock,
        returnQuantity: Int,
        returnNotes: String?,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let details: [String: Any] = [
            "returnQuantity": returnQuantity,
            "returnNotes": returnNotes ?? "",
            "previousReturnQuantity": item.returnQuantity - returnQuantity,
            "newTotalReturnQuantity": item.returnQuantity,
            "remainingQuantity": item.remainingQuantity,
            "productDisplayName": item.productDisplayName
        ]
        
        await logOperation(
            operationType: .returnProcess,
            entityType: .customerOutOfStock,
            entityId: item.id,
            entityDescription: "\(item.customer?.name ?? "未知客户") - \(item.productDisplayName)",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: details
        )
    }
    
    /// Log deletion
    func logCustomerOutOfStockDeletion(
        item: CustomerOutOfStock,
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let beforeValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            status: item.status.displayName,
            notes: item.notes,
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
        
        let operation = CustomerOutOfStockOperation(
            beforeValues: beforeValues,
            afterValues: nil,
            changedFields: ["deleted"],
            additionalInfo: "删除缺货记录"
        )
        
        let details: [String: Any] = [
            "operation": try! convertToDict(operation),
            "productDisplayName": item.productDisplayName
        ]
        
        await logOperation(
            operationType: .delete,
            entityType: .customerOutOfStock,
            entityId: item.id,
            entityDescription: "\(item.customer?.name ?? "未知客户") - \(item.productDisplayName)",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: details
        )
    }
    
    // MARK: - Batch Operations
    
    /// Log batch operations
    func logBatchOperation(
        operationType: OperationType,
        entityType: EntityType,
        affectedItems: [String],
        entityDescriptions: [String],
        changeDetails: [String: Any],
        operatorUserId: String,
        operatorUserName: String
    ) async {
        let batchId = UUID().uuidString
        
        let batchOperation = BatchOperation(
            affectedItems: affectedItems,
            operationType: operationType.rawValue,
            changeDetails: changeDetails,
            totalCount: affectedItems.count
        )
        
        let details: [String: Any] = [
            "batchOperation": try! convertToDict(batchOperation),
            "affectedEntityDescriptions": entityDescriptions
        ]
        
        await logOperation(
            operationType: operationType,
            entityType: entityType,
            entityId: batchId,
            entityDescription: "批量操作: \(affectedItems.count)个项目",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: details,
            batchId: batchId,
            relatedEntityIds: affectedItems
        )
    }
    
    // MARK: - Helper Methods
    
    private func convertToJsonString(_ dict: [String: Any]) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
    
    private func convertToDict<T: Codable>(_ object: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(object)
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        return dict ?? [:]
    }
    
    private func getDeviceInfo() -> String {
        #if os(iOS)
        return "iOS Device"
        #elseif os(macOS)
        return "macOS Device"
        #else
        return "Unknown Device"
        #endif
    }
    
    // MARK: - Use Case Compatible Methods
    
    func logOperation(
        operation: AuditOperation,
        entityType: String,
        entityId: String?,
        performedBy: String,
        details: String
    ) async {
        // This is a simplified version for Use Cases compatibility
        // In a real implementation, you would need a ModelContext
        print("AUDIT: [\(operation.rawValue)] \(entityType) \(entityId ?? "N/A") by \(performedBy) - \(details)")
    }
    
    func logError(
        operation: AuditOperation,
        entityType: String,
        entityId: String?,
        error: Error,
        details: String,
        performedBy: String? = nil
    ) async {
        let userInfo = performedBy != nil ? " by \(performedBy!)" : ""
        print("AUDIT ERROR: [\(operation.rawValue)] \(entityType) \(entityId ?? "N/A")\(userInfo) - \(details): \(error.localizedDescription)")
    }
    
    func logAccess(
        operation: AuditOperation,
        entityType: String,
        entityId: String?,
        details: String
    ) async {
        print("AUDIT ACCESS: [\(operation.rawValue)] \(entityType) \(entityId ?? "N/A") - \(details)")
    }
}

