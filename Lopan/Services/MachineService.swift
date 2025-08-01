//
//  MachineService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftUI

@MainActor
class MachineService: ObservableObject, ServiceCleanupProtocol {
    // MARK: - Published Properties
    @Published var machines: [WorkshopMachine] = []
    @Published var selectedMachine: WorkshopMachine?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - Task Management
    private var isCleanedUp = false
    
    init(machineRepository: MachineRepository, auditService: NewAuditingService, authService: AuthenticationService) {
        self.machineRepository = machineRepository
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Cleanup
    func cleanup() {
        isCleanedUp = true
        
        // Clear published properties
        machines.removeAll()
        selectedMachine = nil
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Safety Checks
    private var isUserLoggedIn: Bool {
        return !isCleanedUp && authService.currentUser != nil && authService.isAuthenticated
    }
    
    // MARK: - Machine Management
    func loadMachines() async {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return }
                
                let fetchedMachines = try await machineRepository.fetchAllMachines()
                
                // Final check before updating UI
                guard !Task.isCancelled && isUserLoggedIn else { return }
                
                machines = fetchedMachines
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return
            } catch {
                guard isUserLoggedIn else { return }
                errorMessage = "Failed to load machines: \(error.localizedDescription)"
            }
            
            if isUserLoggedIn {
                isLoading = false
            }
        }
        
        await task.value
    }
    
    func addMachine() async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can add machines"
            return false
        }
        
        isLoading = true
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return false }
                
                let nextNumber = (machines.map(\.machineNumber).max() ?? 0) + 1
                let newMachine = WorkshopMachine(machineNumber: nextNumber, createdBy: currentUser.id)
                
                try await machineRepository.addMachine(newMachine)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
                if isUserLoggedIn {
                    isLoading = false
                }
                return true
                
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return false
            } catch {
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to add machine: \(error.localizedDescription)"
                isLoading = false
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func deleteMachine(_ machine: WorkshopMachine) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
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
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return false }
                
                try await machineRepository.deleteMachine(machine)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
                if isUserLoggedIn {
                    isLoading = false
                }
                return true
                
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return false
            } catch {
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to delete machine: \(error.localizedDescription)"
                isLoading = false
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func updateMachineStatus(_ machine: WorkshopMachine, newStatus: MachineStatus) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to change machine status"
            return false
        }
        
        let oldStatus = machine.status
        machine.status = newStatus
        machine.updatedAt = Date()
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { 
                    machine.status = oldStatus // Revert on logout
                    return false 
                }
                
                try await machineRepository.updateMachine(machine)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                machine.status = oldStatus
                return false
            } catch {
                machine.status = oldStatus // Revert on error
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to update machine status: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func toggleMachineActive(_ machine: WorkshopMachine) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can enable/disable machines"
            return false
        }
        
        let originalState = machine.isActive
        machine.isActive.toggle()
        machine.updatedAt = Date()
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { 
                    machine.isActive = originalState // Revert on logout
                    return false 
                }
                
                try await machineRepository.updateMachine(machine)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                machine.isActive = originalState
                return false
            } catch {
                machine.isActive = originalState // Revert on error
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to update machine: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func updateStationStatus(_ station: WorkshopStation, newStatus: StationStatus) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to change station status"
            return false
        }
        
        let oldStatus = station.status
        let oldProductId = station.currentProductId
        station.status = newStatus
        station.updatedAt = Date()
        
        // Clear workstation occupancy if setting to idle
        if newStatus == .idle {
            station.currentProductId = nil
        }
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { 
                    // Revert changes on logout
                    station.status = oldStatus
                    station.currentProductId = oldProductId
                    return false 
                }
                
                try await machineRepository.updateStation(station)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                station.status = oldStatus
                station.currentProductId = oldProductId
                return false
            } catch {
                // Revert changes on error
                station.status = oldStatus
                station.currentProductId = oldProductId
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to update station status: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    // MARK: - Batch Operations
    func batchUpdateStationStatus(_ stations: [WorkshopStation], newStatus: StationStatus) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to change station status"
            return false
        }
        
        let stationUpdates = stations.map { ($0, $0.status, $0.currentProductId) } // Store original values for rollback
        
        // Update all stations
        for station in stations {
            station.status = newStatus
            station.updatedAt = Date()
            
            // Clear workstation occupancy if setting to idle
            if newStatus == .idle {
                station.currentProductId = nil
            }
        }
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else {
                    // Rollback changes on logout
                    for (station, originalStatus, originalProductId) in stationUpdates {
                        station.status = originalStatus
                        station.currentProductId = originalProductId
                    }
                    return false 
                }
                
                // Update all stations in repository
                for station in stations {
                    guard !Task.isCancelled && isUserLoggedIn else {
                        // Rollback if cancelled mid-operation
                        for (station, originalStatus, originalProductId) in stationUpdates {
                            station.status = originalStatus
                            station.currentProductId = originalProductId
                        }
                        return false
                    }
                    try await machineRepository.updateStation(station)
                }
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - rollback changes
                for (station, originalStatus, originalProductId) in stationUpdates {
                    station.status = originalStatus
                    station.currentProductId = originalProductId
                }
                return false
            } catch {
                // Rollback on error
                for (station, originalStatus, originalProductId) in stationUpdates {
                    station.status = originalStatus
                    station.currentProductId = originalProductId
                }
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to batch update station status: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func resetMachineToIdle(_ machine: WorkshopMachine) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to reset machine"
            return false
        }
        
        let originalMachineStatus = machine.status
        let originalProductionCount = machine.currentProductionCount
        let originalUtilizationRate = machine.utilizationRate
        let originalStationStatuses = machine.stations.map { ($0, $0.status, $0.currentProductId) }
        
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
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else {
                    // Rollback changes on logout
                    machine.status = originalMachineStatus
                    machine.currentProductionCount = originalProductionCount
                    machine.utilizationRate = originalUtilizationRate
                    for (station, originalStatus, originalProductId) in originalStationStatuses {
                        station.status = originalStatus
                        station.currentProductId = originalProductId
                    }
                    return false 
                }
                
                // Update machine
                try await machineRepository.updateMachine(machine)
                
                // Check before updating stations
                guard !Task.isCancelled && isUserLoggedIn else {
                    // Rollback if cancelled mid-operation
                    machine.status = originalMachineStatus
                    machine.currentProductionCount = originalProductionCount
                    machine.utilizationRate = originalUtilizationRate
                    for (station, originalStatus, originalProductId) in originalStationStatuses {
                        station.status = originalStatus
                        station.currentProductId = originalProductId
                    }
                    return false
                }
                
                // Update all stations
                for station in machine.stations {
                    guard !Task.isCancelled && isUserLoggedIn else {
                        // Rollback if cancelled mid-operation
                        machine.status = originalMachineStatus
                        machine.currentProductionCount = originalProductionCount
                        machine.utilizationRate = originalUtilizationRate
                        for (station, originalStatus, originalProductId) in originalStationStatuses {
                            station.status = originalStatus
                            station.currentProductId = originalProductId
                        }
                        return false
                    }
                    try await machineRepository.updateStation(station)
                }
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - rollback changes
                machine.status = originalMachineStatus
                machine.currentProductionCount = originalProductionCount
                machine.utilizationRate = originalUtilizationRate
                for (station, originalStatus, originalProductId) in originalStationStatuses {
                    station.status = originalStatus
                    station.currentProductId = originalProductId
                }
                return false
            } catch {
                // Rollback on error
                machine.status = originalMachineStatus
                machine.currentProductionCount = originalProductionCount
                machine.utilizationRate = originalUtilizationRate
                for (station, originalStatus, originalProductId) in originalStationStatuses {
                    station.status = originalStatus
                    station.currentProductId = originalProductId
                }
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to reset machine: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func updateMachineBasicSettings(_ machine: WorkshopMachine, curingTime: Int, moldOpeningTimes: Int) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
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
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else {
                    // Revert changes on logout
                    machine.curingTime = oldCuringTime
                    machine.moldOpeningTimes = oldMoldOpeningTimes
                    return false 
                }
                
                try await machineRepository.updateMachine(machine)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                machine.curingTime = oldCuringTime
                machine.moldOpeningTimes = oldMoldOpeningTimes
                return false
            } catch {
                // Revert on error
                machine.curingTime = oldCuringTime
                machine.moldOpeningTimes = oldMoldOpeningTimes
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to update machine basic settings: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    // MARK: - Utility Methods
    func clearError() {
        errorMessage = nil
    }
}