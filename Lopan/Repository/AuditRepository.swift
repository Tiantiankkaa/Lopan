//
//  AuditRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

public protocol AuditRepository {
    func fetchAuditLogs() async throws -> [AuditLog]
    func fetchAuditLog(by id: String) async throws -> AuditLog?
    func fetchAuditLogs(forEntity entityId: String) async throws -> [AuditLog]
    func fetchAuditLogs(forUser userId: String) async throws -> [AuditLog]
    func fetchAuditLogs(forAction action: String) async throws -> [AuditLog]
    func fetchAuditLogs(from startDate: Date, to endDate: Date) async throws -> [AuditLog]
    func addAuditLog(_ log: AuditLog) async throws
    func deleteAuditLog(_ log: AuditLog) async throws
    func deleteAuditLogs(olderThan date: Date) async throws
}