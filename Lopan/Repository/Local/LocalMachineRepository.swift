//
//  LocalMachineRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

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
}