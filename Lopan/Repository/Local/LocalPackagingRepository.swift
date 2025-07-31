//
//  LocalPackagingRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalPackagingRepository: PackagingRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - PackagingRecord operations
    
    func fetchPackagingRecords() async throws -> [PackagingRecord] {
        let descriptor = FetchDescriptor<PackagingRecord>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchPackagingRecord(by id: String) async throws -> PackagingRecord? {
        let descriptor = FetchDescriptor<PackagingRecord>()
        let records = try modelContext.fetch(descriptor)
        return records.first { $0.id == id }
    }
    
    func fetchPackagingRecords(for teamId: String) async throws -> [PackagingRecord] {
        let descriptor = FetchDescriptor<PackagingRecord>()
        let records = try modelContext.fetch(descriptor)
        return records.filter { $0.teamId == teamId }
    }
    
    func fetchPackagingRecords(for date: Date) async throws -> [PackagingRecord] {
        let descriptor = FetchDescriptor<PackagingRecord>()
        let records = try modelContext.fetch(descriptor)
        let calendar = Calendar.current
        return records.filter { record in
            calendar.isDate(record.packageDate, inSameDayAs: date)
        }
    }
    
    func addPackagingRecord(_ record: PackagingRecord) async throws {
        modelContext.insert(record)
        try modelContext.save()
    }
    
    func updatePackagingRecord(_ record: PackagingRecord) async throws {
        try modelContext.save()
    }
    
    func deletePackagingRecord(_ record: PackagingRecord) async throws {
        modelContext.delete(record)
        try modelContext.save()
    }
    
    // MARK: - PackagingTeam operations
    
    func fetchPackagingTeams() async throws -> [PackagingTeam] {
        let descriptor = FetchDescriptor<PackagingTeam>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchPackagingTeam(by id: String) async throws -> PackagingTeam? {
        let descriptor = FetchDescriptor<PackagingTeam>()
        let teams = try modelContext.fetch(descriptor)
        return teams.first { $0.id == id }
    }
    
    func addPackagingTeam(_ team: PackagingTeam) async throws {
        modelContext.insert(team)
        try modelContext.save()
    }
    
    func updatePackagingTeam(_ team: PackagingTeam) async throws {
        try modelContext.save()
    }
    
    func deletePackagingTeam(_ team: PackagingTeam) async throws {
        modelContext.delete(team)
        try modelContext.save()
    }
}