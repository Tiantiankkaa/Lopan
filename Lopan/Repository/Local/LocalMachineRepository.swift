//
//  LocalMachineRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalMachineRepository: MachineRepository {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Machine CRUD
    func fetchAllMachines() async throws -> [WorkshopMachine] {
        let descriptor = FetchDescriptor<WorkshopMachine>(
            sortBy: [SortDescriptor(\.machineNumber)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchMachine(byId id: String) async throws -> WorkshopMachine? {
        let descriptor = FetchDescriptor<WorkshopMachine>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchMachineById(_ id: String) async throws -> WorkshopMachine? {
        let descriptor = FetchDescriptor<WorkshopMachine>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchMachine(byNumber number: Int) async throws -> WorkshopMachine? {
        let descriptor = FetchDescriptor<WorkshopMachine>(
            predicate: #Predicate { $0.machineNumber == number }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchActiveMachines() async throws -> [WorkshopMachine] {
        let descriptor = FetchDescriptor<WorkshopMachine>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.machineNumber)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchMachinesWithStatus(_ status: MachineStatus) async throws -> [WorkshopMachine] {
        let descriptor = FetchDescriptor<WorkshopMachine>(
            predicate: #Predicate { $0.status == status },
            sortBy: [SortDescriptor(\.machineNumber)]
        )
        return try context.fetch(descriptor)
    }
    
    func addMachine(_ machine: WorkshopMachine) async throws {
        context.insert(machine)
        
        // Create stations after machine is inserted
        for stationNumber in 1...12 {
            let station = WorkshopStation(stationNumber: stationNumber, machineId: machine.id)
            context.insert(station)
            machine.stations.append(station)
        }
        
        // Create guns after machine is inserted
        let gunA = WorkshopGun(name: "Gun A", stationRangeStart: 1, stationRangeEnd: 6, machineId: machine.id)
        let gunB = WorkshopGun(name: "Gun B", stationRangeStart: 7, stationRangeEnd: 12, machineId: machine.id)
        
        context.insert(gunA)
        context.insert(gunB)
        machine.guns.append(gunA)
        machine.guns.append(gunB)
        
        try context.save()
    }
    
    func updateMachine(_ machine: WorkshopMachine) async throws {
        machine.updatedAt = Date()
        try context.save()
    }
    
    func deleteMachine(_ machine: WorkshopMachine) async throws {
        context.delete(machine)
        try context.save()
    }
    
    // MARK: - Station Operations
    func fetchStations(for machineId: String) async throws -> [WorkshopStation] {
        let descriptor = FetchDescriptor<WorkshopStation>(
            predicate: #Predicate { $0.machineId == machineId },
            sortBy: [SortDescriptor(\.stationNumber)]
        )
        return try context.fetch(descriptor)
    }
    
    func updateStation(_ station: WorkshopStation) async throws {
        station.updatedAt = Date()
        try context.save()
    }
    
    // MARK: - Gun Operations
    func fetchGuns(for machineId: String) async throws -> [WorkshopGun] {
        let descriptor = FetchDescriptor<WorkshopGun>(
            predicate: #Predicate { $0.machineId == machineId },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    func updateGun(_ gun: WorkshopGun) async throws {
        gun.updatedAt = Date()
        try context.save()
    }
    
    // MARK: - Batch-aware Machine Queries
    func fetchMachinesWithoutPendingApprovalBatches() async throws -> [WorkshopMachine] {
        do {
            // Fetch all machines first
            let allMachines = try await fetchAllMachines()
            
            // If no machines exist, return empty array
            guard !allMachines.isEmpty else {
                return []
            }
            
            // Fetch all production batches safely
            let allBatchesDescriptor = FetchDescriptor<ProductionBatch>()
            let allBatches = try context.fetch(allBatchesDescriptor)
            
            // Filter to pending batches in memory (safe even if allBatches is empty)
            let pendingBatches = allBatches.filter { $0.status == BatchStatus.pending }
            
            // Get machine IDs with pending approval batches
            let machinesWithPendingBatches = Set(pendingBatches.map { $0.machineId })
            
            // Filter machines that:
            // 1. Don't have pending approval batches
            // 2. Are in running status only (for batch creation)
            // 3. Are active
            return allMachines.filter { machine in
                !machinesWithPendingBatches.contains(machine.id) &&
                machine.status == .running &&
                machine.isActive
            }
            
        } catch {
            // If there's any error, log it but still try to return running machines as fallback
            print("Error in fetchMachinesWithoutPendingApprovalBatches: \(error)")
            // Fallback to running machines only if batch filtering fails
            return try await fetchMachinesWithStatus(.running).filter { $0.isActive }
        }
    }
}