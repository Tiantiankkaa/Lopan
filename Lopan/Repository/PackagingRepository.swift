//
//  PackagingRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

public protocol PackagingRepository {
    // PackagingRecord operations
    func fetchPackagingRecords() async throws -> [PackagingRecord]
    func fetchPackagingRecord(by id: String) async throws -> PackagingRecord?
    func fetchPackagingRecords(for teamId: String) async throws -> [PackagingRecord]
    func fetchPackagingRecords(for date: Date) async throws -> [PackagingRecord]
    func addPackagingRecord(_ record: PackagingRecord) async throws
    func updatePackagingRecord(_ record: PackagingRecord) async throws
    func deletePackagingRecord(_ record: PackagingRecord) async throws
    
    // PackagingTeam operations
    func fetchPackagingTeams() async throws -> [PackagingTeam]
    func fetchPackagingTeam(by id: String) async throws -> PackagingTeam?
    func addPackagingTeam(_ team: PackagingTeam) async throws
    func updatePackagingTeam(_ team: PackagingTeam) async throws
    func deletePackagingTeam(_ team: PackagingTeam) async throws
}