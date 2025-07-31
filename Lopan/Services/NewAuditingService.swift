//
//  NewAuditingService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
class NewAuditingService {
    private let auditRepository: AuditRepository
    
    init(repositoryFactory: RepositoryFactory) {
        self.auditRepository = repositoryFactory.auditRepository
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
        return try await auditRepository.fetchAuditLogs(forEntity: entityId)
    }
    
    /// Get audit logs by user
    func getAuditLogs(by userId: String) async throws -> [AuditLog] {
        return try await auditRepository.fetchAuditLogs(forUser: userId)
    }
    
    /// Get audit logs in date range
    func getAuditLogs(from startDate: Date, to endDate: Date) async throws -> [AuditLog] {
        return try await auditRepository.fetchAuditLogs(from: startDate, to: endDate)
    }
    
    /// Clean up old audit logs
    func cleanupOldLogs(olderThan date: Date) async throws {
        try await auditRepository.deleteAuditLogs(olderThan: date)
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
}