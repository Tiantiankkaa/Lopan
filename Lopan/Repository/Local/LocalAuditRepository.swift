//
//  LocalAuditRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalAuditRepository: AuditRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAuditLogs() async throws -> [AuditLog] {
        let descriptor = FetchDescriptor<AuditLog>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchAuditLog(by id: String) async throws -> AuditLog? {
        let descriptor = FetchDescriptor<AuditLog>()
        let logs = try modelContext.fetch(descriptor)
        return logs.first { $0.id == id }
    }
    
    func fetchAuditLogs(forEntity entityId: String) async throws -> [AuditLog] {
        let descriptor = FetchDescriptor<AuditLog>()
        let logs = try modelContext.fetch(descriptor)
        return logs.filter { $0.entityId == entityId }
    }
    
    func fetchAuditLogs(forUser userId: String) async throws -> [AuditLog] {
        let descriptor = FetchDescriptor<AuditLog>()
        let logs = try modelContext.fetch(descriptor)
        return logs.filter { $0.userId == userId }
    }
    
    func fetchAuditLogs(forAction action: String) async throws -> [AuditLog] {
        let descriptor = FetchDescriptor<AuditLog>()
        let logs = try modelContext.fetch(descriptor)
        return logs.filter { $0.action == action }
    }
    
    func fetchAuditLogs(from startDate: Date, to endDate: Date) async throws -> [AuditLog] {
        let descriptor = FetchDescriptor<AuditLog>()
        let logs = try modelContext.fetch(descriptor)
        return logs.filter { log in
            log.timestamp >= startDate && log.timestamp <= endDate
        }
    }
    
    func addAuditLog(_ log: AuditLog) async throws {
        modelContext.insert(log)
        try modelContext.save()
    }
    
    func deleteAuditLog(_ log: AuditLog) async throws {
        modelContext.delete(log)
        try modelContext.save()
    }
    
    func deleteAuditLogs(olderThan date: Date) async throws {
        let descriptor = FetchDescriptor<AuditLog>()
        let logs = try modelContext.fetch(descriptor)
        let logsToDelete = logs.filter { $0.timestamp < date }
        
        for log in logsToDelete {
            modelContext.delete(log)
        }
        try modelContext.save()
    }
}