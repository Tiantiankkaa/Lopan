//
//  MachineRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
protocol MachineRepository {
    // MARK: - Machine CRUD
    func fetchAllMachines() async throws -> [WorkshopMachine]
    func fetchMachine(byId id: String) async throws -> WorkshopMachine?
    func fetchMachineById(_ id: String) async throws -> WorkshopMachine?
    func fetchMachine(byNumber number: Int) async throws -> WorkshopMachine?
    func fetchActiveMachines() async throws -> [WorkshopMachine]
    func fetchMachinesWithStatus(_ status: MachineStatus) async throws -> [WorkshopMachine]
    func addMachine(_ machine: WorkshopMachine) async throws
    func updateMachine(_ machine: WorkshopMachine) async throws
    func deleteMachine(_ machine: WorkshopMachine) async throws
    
    // MARK: - Station Operations
    func fetchStations(for machineId: String) async throws -> [WorkshopStation]
    func updateStation(_ station: WorkshopStation) async throws
    
    // MARK: - Gun Operations
    func fetchGuns(for machineId: String) async throws -> [WorkshopGun]
    func updateGun(_ gun: WorkshopGun) async throws
    
    // MARK: - Batch-aware Machine Queries
    func fetchMachinesWithoutPendingApprovalBatches() async throws -> [WorkshopMachine]
}