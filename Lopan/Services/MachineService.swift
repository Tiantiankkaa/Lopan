//
//  MachineService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftUI

@MainActor
class MachineService: ObservableObject {
    // MARK: - Published Properties
    @Published var machines: [WorkshopMachine] = []
    @Published var selectedMachine: WorkshopMachine?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    init(machineRepository: MachineRepository, auditService: NewAuditingService, authService: AuthenticationService) {
        self.machineRepository = machineRepository
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Machine Management
    func loadMachines() async {
        isLoading = true
        errorMessage = nil
        
        do {
            machines = try await machineRepository.fetchAllMachines()
        } catch {
            errorMessage = "Failed to load machines: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addMachine() async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can add machines"
            return false
        }
        
        isLoading = true
        
        do {
            let nextNumber = (machines.map(\.machineNumber).max() ?? 0) + 1
            let newMachine = WorkshopMachine(machineNumber: nextNumber, createdBy: currentUser.id)
            try await machineRepository.addMachine(newMachine)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .create,
                entityType: .machine,
                entityId: newMachine.id,
                entityDescription: "Machine #\(newMachine.machineNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "machineNumber": newMachine.machineNumber,
                    "createdBy": currentUser.name
                ]
            )
            
            await loadMachines()
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to add machine: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func deleteMachine(_ machine: WorkshopMachine) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can delete machines"
            return false
        }
        
        guard machine.canBeDeleted else {
            errorMessage = "Cannot delete machine with active production or running status"
            return false
        }
        
        isLoading = true
        
        do {
            try await machineRepository.deleteMachine(machine)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .delete,
                entityType: .machine,
                entityId: machine.id,
                entityDescription: "Machine #\(machine.machineNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "machineNumber": machine.machineNumber,
                    "deletedBy": currentUser.name
                ]
            )
            
            await loadMachines()
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to delete machine: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func updateMachineStatus(_ machine: WorkshopMachine, newStatus: MachineStatus) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to change machine status"
            return false
        }
        
        let oldStatus = machine.status
        machine.status = newStatus
        machine.updatedAt = Date()
        
        do {
            try await machineRepository.updateMachine(machine)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .statusChange,
                entityType: .machine,
                entityId: machine.id,
                entityDescription: "Machine #\(machine.machineNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "oldStatus": oldStatus.rawValue,
                    "newStatus": newStatus.rawValue,
                    "changedBy": currentUser.name
                ]
            )
            
            return true
            
        } catch {
            machine.status = oldStatus // Revert on error
            errorMessage = "Failed to update machine status: \(error.localizedDescription)"
            return false
        }
    }
    
    func toggleMachineActive(_ machine: WorkshopMachine) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can enable/disable machines"
            return false
        }
        
        machine.isActive.toggle()
        machine.updatedAt = Date()
        
        do {
            try await machineRepository.updateMachine(machine)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .update,
                entityType: .machine,
                entityId: machine.id,
                entityDescription: "Machine #\(machine.machineNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "action": machine.isActive ? "enabled" : "disabled",
                    "changedBy": currentUser.name
                ]
            )
            
            return true
            
        } catch {
            machine.isActive.toggle() // Revert on error
            errorMessage = "Failed to update machine: \(error.localizedDescription)"
            return false
        }
    }
    
    func updateStationStatus(_ station: WorkshopStation, newStatus: StationStatus) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to change station status"
            return false
        }
        
        let oldStatus = station.status
        station.status = newStatus
        station.updatedAt = Date()
        
        // Clear workstation occupancy if setting to idle
        if newStatus == .idle {
            station.currentProductId = nil
        }
        
        do {
            try await machineRepository.updateStation(station)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .statusChange,
                entityType: .workstation,
                entityId: station.id,
                entityDescription: "Station #\(station.stationNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "machineId": station.machineId,
                    "stationNumber": station.stationNumber,
                    "oldStatus": oldStatus.rawValue,
                    "newStatus": newStatus.rawValue,
                    "changedBy": currentUser.name
                ]
            )
            
            // Reload machines to reflect changes
            await loadMachines()
            return true
            
        } catch {
            station.status = oldStatus // Revert on error
            errorMessage = "Failed to update station status: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Batch Operations
    func batchUpdateStationStatus(_ stations: [WorkshopStation], newStatus: StationStatus) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to change station status"
            return false
        }
        
        let stationUpdates = stations.map { ($0, $0.status) } // Store original status for rollback
        
        // Update all stations
        for station in stations {
            station.status = newStatus
            station.updatedAt = Date()
            
            // Clear workstation occupancy if setting to idle
            if newStatus == .idle {
                station.currentProductId = nil
            }
        }
        
        do {
            // Update all stations in repository
            for station in stations {
                try await machineRepository.updateStation(station)
            }
            
            // Audit log for batch operation
            try await auditService.logOperation(
                operationType: .batchUpdate,
                entityType: .workstation,
                entityId: "batch_\(UUID().uuidString)",
                entityDescription: "Batch update \(stations.count) stations",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "stationCount": stations.count,
                    "newStatus": newStatus.rawValue,
                    "stationNumbers": stations.map(\.stationNumber),
                    "changedBy": currentUser.name
                ]
            )
            
            // Reload machines to reflect changes
            await loadMachines()
            return true
            
        } catch {
            // Rollback on error
            for (station, originalStatus) in stationUpdates {
                station.status = originalStatus
            }
            errorMessage = "Failed to batch update station status: \(error.localizedDescription)"
            return false
        }
    }
    
    func resetMachineToIdle(_ machine: WorkshopMachine) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to reset machine"
            return false
        }
        
        let originalMachineStatus = machine.status
        let originalStationStatuses = machine.stations.map { ($0, $0.status) }
        
        // Reset machine status to stopped
        machine.status = .stopped
        machine.updatedAt = Date()
        machine.currentProductionCount = 0
        machine.utilizationRate = 0.0
        
        // Reset all stations to idle
        for station in machine.stations {
            station.status = .idle
            station.currentProductId = nil
            station.updatedAt = Date()
        }
        
        do {
            // Update machine
            try await machineRepository.updateMachine(machine)
            
            // Update all stations
            for station in machine.stations {
                try await machineRepository.updateStation(station)
            }
            
            // Audit log
            try await auditService.logOperation(
                operationType: .reset,
                entityType: .machine,
                entityId: machine.id,
                entityDescription: "Machine #\(machine.machineNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "machineNumber": machine.machineNumber,
                    "originalMachineStatus": originalMachineStatus.rawValue,
                    "resetStationsCount": machine.stations.count,
                    "resetBy": currentUser.name
                ]
            )
            
            // Reload machines to reflect changes
            await loadMachines()
            return true
            
        } catch {
            // Rollback on error
            machine.status = originalMachineStatus
            for (station, originalStatus) in originalStationStatuses {
                station.status = originalStatus
            }
            errorMessage = "Failed to reset machine: \(error.localizedDescription)"
            return false
        }
    }
    
    func updateMachineBasicSettings(_ machine: WorkshopMachine, curingTime: Int, moldOpeningTimes: Int) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to update machine settings"
            return false
        }
        
        let oldCuringTime = machine.curingTime
        let oldMoldOpeningTimes = machine.moldOpeningTimes
        
        machine.curingTime = curingTime
        machine.moldOpeningTimes = moldOpeningTimes
        machine.updatedAt = Date()
        
        do {
            try await machineRepository.updateMachine(machine)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .update,
                entityType: .machine,
                entityId: machine.id,
                entityDescription: "Machine #\(machine.machineNumber) basic settings",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "machineNumber": machine.machineNumber,
                    "oldCuringTime": oldCuringTime,
                    "newCuringTime": curingTime,
                    "oldMoldOpeningTimes": oldMoldOpeningTimes,
                    "newMoldOpeningTimes": moldOpeningTimes,
                    "updatedBy": currentUser.name
                ]
            )
            
            return true
            
        } catch {
            // Revert on error
            machine.curingTime = oldCuringTime
            machine.moldOpeningTimes = oldMoldOpeningTimes
            errorMessage = "Failed to update machine basic settings: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Utility Methods
    func clearError() {
        errorMessage = nil
    }
}