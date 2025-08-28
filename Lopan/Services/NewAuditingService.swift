//
//  NewAuditingService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
public class NewAuditingService {
    private let auditRepository: AuditRepository?
    private let modelContext: ModelContext?
    
    init(repositoryFactory: RepositoryFactory) {
        self.auditRepository = repositoryFactory.auditRepository
        self.modelContext = nil
    }
    
    // Alternative initializer for direct ModelContext usage
    init(modelContext: ModelContext) {
        self.auditRepository = nil
        self.modelContext = modelContext
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
            if let repository = auditRepository {
                try await repository.addAuditLog(auditLog)
            } else if let context = modelContext {
                context.insert(auditLog)
                try context.save()
            }
        } catch {
            print("❌ Failed to save audit log: \(error)")
        }
    }
    
    /// Log entity creation
    func logCreate(
        entityType: EntityType,
        entityId: String,
        entityDescription: String,
        operatorUserId: String,
        operatorUserName: String,
        createdData: [String: Any],
        batchId: String? = nil
    ) async {
        await logOperation(
            operationType: .create,
            entityType: entityType,
            entityId: entityId,
            entityDescription: entityDescription,
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: [
                "created_data": createdData,
                "timestamp": Date().timeIntervalSince1970
            ],
            batchId: batchId
        )
    }
    
    /// Log entity update with before/after values
    func logUpdate(
        entityType: EntityType,
        entityId: String,
        entityDescription: String,
        operatorUserId: String,
        operatorUserName: String,
        beforeData: [String: Any],
        afterData: [String: Any],
        changedFields: [String],
        batchId: String? = nil
    ) async {
        await logOperation(
            operationType: .update,
            entityType: entityType,
            entityId: entityId,
            entityDescription: entityDescription,
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: [
                "before_data": beforeData,
                "after_data": afterData,
                "changed_fields": changedFields,
                "timestamp": Date().timeIntervalSince1970
            ],
            batchId: batchId
        )
    }
    
    /// Log entity deletion
    func logDelete(
        entityType: EntityType,
        entityId: String,
        entityDescription: String,
        operatorUserId: String,
        operatorUserName: String,
        deletedData: [String: Any],
        batchId: String? = nil,
        relatedEntityIds: [String] = []
    ) async {
        await logOperation(
            operationType: .delete,
            entityType: entityType,
            entityId: entityId,
            entityDescription: entityDescription,
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: [
                "deleted_data": deletedData,
                "timestamp": Date().timeIntervalSince1970
            ],
            batchId: batchId,
            relatedEntityIds: relatedEntityIds
        )
    }
    
    /// Log batch operations
    func logBatchOperation(
        operationType: OperationType,
        entityType: EntityType,
        batchId: String,
        operatorUserId: String,
        operatorUserName: String,
        affectedEntityIds: [String],
        operationSummary: [String: Any]
    ) async {
        await logOperation(
            operationType: operationType,
            entityType: entityType,
            entityId: batchId,
            entityDescription: "Batch \(operationType.rawValue) - \(affectedEntityIds.count) items",
            operatorUserId: operatorUserId,
            operatorUserName: operatorUserName,
            operationDetails: [
                "batch_summary": operationSummary,
                "affected_count": affectedEntityIds.count,
                "affected_entities": affectedEntityIds,
                "timestamp": Date().timeIntervalSince1970
            ],
            batchId: batchId,
            relatedEntityIds: affectedEntityIds
        )
    }
    
    // MARK: - Query Methods
    
    /// Get audit logs for a specific entity
    func getAuditLogs(for entityId: String) async throws -> [AuditLog] {
        if let repository = auditRepository {
            return try await repository.fetchAuditLogs(forEntity: entityId)
        } else if let context = modelContext {
            // Fetch directly from context if no repository available
            let descriptor = FetchDescriptor<AuditLog>(
                predicate: #Predicate<AuditLog> { $0.entityId == entityId },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            return try context.fetch(descriptor)
        }
        return []
    }
    
    /// Get audit logs by user
    func getAuditLogs(by userId: String) async throws -> [AuditLog] {
        if let repository = auditRepository {
            return try await repository.fetchAuditLogs(forUser: userId)
        } else if let context = modelContext {
            // Fetch directly from context if no repository available
            let descriptor = FetchDescriptor<AuditLog>(
                predicate: #Predicate<AuditLog> { $0.userId == userId },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            return try context.fetch(descriptor)
        }
        return []
    }
    
    /// Get audit logs in date range
    func getAuditLogs(from startDate: Date, to endDate: Date) async throws -> [AuditLog] {
        if let repository = auditRepository {
            return try await repository.fetchAuditLogs(from: startDate, to: endDate)
        } else if let context = modelContext {
            // Fetch directly from context if no repository available
            let descriptor = FetchDescriptor<AuditLog>(
                predicate: #Predicate<AuditLog> { log in
                    log.timestamp >= startDate && log.timestamp <= endDate
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            return try context.fetch(descriptor)
        }
        return []
    }
    
    /// Clean up old audit logs
    func cleanupOldLogs(olderThan date: Date) async throws {
        if let repository = auditRepository {
            try await repository.deleteAuditLogs(olderThan: date)
        } else if let context = modelContext {
            // Delete directly from context if no repository available
            let descriptor = FetchDescriptor<AuditLog>(
                predicate: #Predicate<AuditLog> { $0.timestamp < date }
            )
            let logsToDelete = try context.fetch(descriptor)
            for log in logsToDelete {
                context.delete(log)
            }
            try context.save()
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToJsonString(_ dictionary: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize operation details\"}"
        }
    }
    
    private func getDeviceInfo() -> String {
        return """
        {
            "platform": "iOS",
            "app_version": "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")",
            "build_number": "\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")",
            "timestamp": \(Date().timeIntervalSince1970)
        }
        """
    }
    
    // MARK: - Filter Operation Logging
    
    /// Log filter operations for security auditing
    func logFilterOperation(
        userId: String,
        userName: String,
        filterType: String,
        filterValue: String,
        entityType: EntityType = .customerOutOfStock,
        resultCount: Int,
        additionalContext: [String: Any] = [:]
    ) async {
        let details: [String: Any] = [
            "filter_type": filterType,
            "filter_value": filterValue,
            "result_count": resultCount,
            "timestamp": Date().timeIntervalSince1970,
            "additional_context": additionalContext
        ]
        
        await logOperation(
            operationType: .read,
            entityType: entityType,
            entityId: "filter_\(UUID().uuidString.prefix(8))",
            entityDescription: "Filter applied: \(filterType) = \(filterValue) (returned \(resultCount) items)",
            operatorUserId: userId,
            operatorUserName: userName,
            operationDetails: details
        )
    }
    
    // MARK: - Generic Event Logging
    
    /// Log a generic event with action, entityId, and details
    func logEvent(
        action: String,
        entityId: String,
        details: String
    ) async {
        // Map action string to OperationType
        let operationType: OperationType
        switch action.uppercased() {
        case let str where str.contains("CREATE"):
            operationType = .create
        case let str where str.contains("UPDATE"):
            operationType = .update
        case let str where str.contains("DELETE"):
            operationType = .delete
        default:
            operationType = .read // Default fallback
        }
        
        // Create and save audit log
        await logOperation(
            operationType: operationType,
            entityType: .customerOutOfStock, // Default to customerOutOfStock for this ViewModel
            entityId: entityId,
            entityDescription: details,
            operatorUserId: "system", // Could be enhanced to get current user
            operatorUserName: "System",
            operationDetails: [
                "action": action,
                "details": details,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
}