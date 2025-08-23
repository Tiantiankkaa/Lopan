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
    @Published var isAnyMachineRunning: Bool = false
    @Published var runningMachineCount: Int = 0
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private weak var notificationEngine: NotificationEngine?
    private weak var permissionService: AdvancedPermissionService?
    
    // MARK: - Machine Status Cache (机器状态缓存)
    private var machineStatusCache: MachineStatusCache?
    private let statusCacheTimeout: TimeInterval = 30 // 30 seconds cache
    
    // MARK: - Task Management
    private var isCleanedUp = false
    
    init(machineRepository: MachineRepository, auditService: NewAuditingService, authService: AuthenticationService, notificationEngine: NotificationEngine? = nil, permissionService: AdvancedPermissionService? = nil) {
        self.machineRepository = machineRepository
        self.auditService = auditService
        self.authService = authService
        self.notificationEngine = notificationEngine
        self.permissionService = permissionService
    }
    
    // MARK: - Cleanup
    func cleanup() {
        isCleanedUp = true
        
        // Clear published properties
        machines.removeAll()
        selectedMachine = nil
        isLoading = false
        errorMessage = nil
        isAnyMachineRunning = false
        runningMachineCount = 0
        
        // Clear cache
        machineStatusCache = nil
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
                updateRunningMachineStatus()
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
                        "machineNumber": "\(newMachine.machineNumber)",
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
                        "machineNumber": "\(machine.machineNumber)",
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
                        "machineNumber": "\(machine.machineNumber)",
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
                        "machineNumber": "\(machine.machineNumber)",
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
    
    // MARK: - Machine Running Status (机器运行状态)
    
    /// Check if any machine is currently running (cached for 30 seconds)
    /// 检查是否有任何机器正在运行（缓存30秒）
    func isAnyMachineRunning() async -> Bool {
        // Check cache first
        if let cache = machineStatusCache, !cache.isExpired {
            return cache.hasRunningMachines
        }
        
        // Refresh cache
        await refreshMachineStatusCache()
        return machineStatusCache?.hasRunningMachines ?? false
    }
    
    /// Get count of running machines (cached)
    /// 获取运行中的机器数量（缓存）
    func getRunningMachineCount() async -> Int {
        // Check cache first
        if let cache = machineStatusCache, !cache.isExpired {
            return cache.runningCount
        }
        
        // Refresh cache
        await refreshMachineStatusCache()
        return machineStatusCache?.runningCount ?? 0
    }
    
    /// Check if specific machines can accept color modifications
    /// 检查特定机器是否可以接受颜色修改
    func canModifyColors(machineId: String) async -> Bool {
        guard isUserLoggedIn else { return false }
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            if let machine = machines.first(where: { $0.id == machineId }) {
                return machine.status == .running && machine.isActive
            }
            return false
        } catch {
            return false
        }
    }
    
    /// Get detailed machine status information
    /// 获取详细的机器状态信息
    func getMachineStatusSummary() async -> MachineStatusSummary {
        guard isUserLoggedIn else {
            return MachineStatusSummary(total: 0, running: 0, stopped: 0, maintenance: 0, error: 0)
        }
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            let activeMachines = machines.filter { $0.isActive }
            
            let running = activeMachines.filter { $0.status == .running }.count
            let stopped = activeMachines.filter { $0.status == .stopped }.count
            let maintenance = activeMachines.filter { $0.status == .maintenance }.count
            let error = activeMachines.filter { $0.status == .error }.count
            
            return MachineStatusSummary(
                total: activeMachines.count,
                running: running,
                stopped: stopped,
                maintenance: maintenance,
                error: error
            )
        } catch {
            return MachineStatusSummary(total: 0, running: 0, stopped: 0, maintenance: 0, error: 0)
        }
    }
    
    // MARK: - Private Cache Methods (私有缓存方法)
    
    private func refreshMachineStatusCache() async {
        guard isUserLoggedIn else { return }
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            let activeMachines = machines.filter { $0.isActive }
            let runningMachines = activeMachines.filter { $0.status == .running }
            
            machineStatusCache = MachineStatusCache(
                timestamp: Date(),
                hasRunningMachines: !runningMachines.isEmpty,
                runningCount: runningMachines.count,
                totalActiveCount: activeMachines.count
            )
            
            // Update published properties for UI binding
            await MainActor.run {
                isAnyMachineRunning = !runningMachines.isEmpty
                runningMachineCount = runningMachines.count
            }
            
        } catch {
            machineStatusCache = MachineStatusCache(
                timestamp: Date(),
                hasRunningMachines: false,
                runningCount: 0,
                totalActiveCount: 0
            )
            
            await MainActor.run {
                isAnyMachineRunning = false
                runningMachineCount = 0
            }
        }
    }
    
    private func updateRunningMachineStatus() {
        let activeMachines = machines.filter { $0.isActive }
        let runningMachines = activeMachines.filter { $0.status == .running }
        
        isAnyMachineRunning = !runningMachines.isEmpty
        runningMachineCount = runningMachines.count
        
        // Update cache with current data
        machineStatusCache = MachineStatusCache(
            timestamp: Date(),
            hasRunningMachines: !runningMachines.isEmpty,
            runningCount: runningMachines.count,
            totalActiveCount: activeMachines.count
        )
    }
    
    /// Force refresh machine status (bypass cache)
    /// 强制刷新机器状态（绕过缓存）
    func forceRefreshMachineStatus() async {
        await refreshMachineStatusCache()
    }
    
    // MARK: - Batch-Machine Synchronization Methods (批次-机器同步方法)
    
    /// Get the current active batch for a machine
    /// 获取机器当前的活跃批次
    func getCurrentBatch(for machineId: String) async -> ProductionBatch? {
        guard isUserLoggedIn else { return nil }
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == machineId }),
                  let batchId = machine.currentBatchId else {
                return nil
            }
            
            // We need a batch repository to fetch the batch details
            // For now, return nil - this would need ProductionBatchRepository injection
            return nil
            
        } catch {
            return nil
        }
    }
    
    /// Update machine with batch information
    /// 使用批次信息更新机器
    func updateMachineWithBatch(_ machine: WorkshopMachine, batch: ProductionBatch) async -> Bool {
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to update machine batch configuration"
            return false
        }
        
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                guard isUserLoggedIn else { return false }
                
                // Update machine configuration
                machine.currentBatchId = batch.id
                machine.currentProductionMode = batch.mode
                machine.lastConfigurationUpdate = Date()
                machine.status = .running
                machine.updatedAt = Date()
                
                // Update station statuses based on batch products
                for station in machine.stations {
                    let isOccupied = batch.products.contains { product in
                        product.occupiedStations.contains(station.stationNumber)
                    }
                    
                    if isOccupied {
                        station.status = .running
                        let occupyingProduct = batch.products.first { product in
                            product.occupiedStations.contains(station.stationNumber)
                        }
                        station.currentProductId = occupyingProduct?.productId
                    } else {
                        station.status = .idle
                        station.currentProductId = nil
                    }
                    station.updatedAt = Date()
                }
                
                // Save changes
                try await machineRepository.updateMachine(machine)
                for station in machine.stations {
                    try await machineRepository.updateStation(station)
                }
                
                // Audit log
                try await auditService.logOperation(
                    operationType: .productionConfigChange,
                    entityType: .machine,
                    entityId: machine.id,
                    entityDescription: "Machine #\(machine.machineNumber) batch update",
                    operatorUserId: currentUser.id,
                    operatorUserName: currentUser.name,
                    operationDetails: [
                        "action": "update_machine_with_batch",
                        "machineNumber": "\(machine.machineNumber)",
                        "batchId": batch.id,
                        "batchNumber": batch.batchNumber,
                        "mode": batch.mode.rawValue,
                        "stationsOccupied": batch.totalStationsUsed,
                        "updatedBy": currentUser.name
                    ]
                )
                
                return true
                
            } catch is CancellationError {
                return false
            } catch {
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to update machine with batch: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        return result
    }
    
    /// Clear batch from machine
    /// 从机器清除批次
    func clearBatchFromMachine(_ machine: WorkshopMachine) async -> Bool {
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to clear machine batch"
            return false
        }
        
        let originalBatchId = machine.currentBatchId
        let originalMode = machine.currentProductionMode
        
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                guard isUserLoggedIn else { return false }
                
                // Clear machine batch configuration
                machine.currentBatchId = nil
                machine.currentProductionMode = nil
                machine.lastConfigurationUpdate = Date()
                machine.status = .stopped
                machine.updatedAt = Date()
                
                // Reset all stations to idle
                for station in machine.stations {
                    station.status = .idle
                    station.currentProductId = nil
                    station.updatedAt = Date()
                }
                
                // Save changes
                try await machineRepository.updateMachine(machine)
                for station in machine.stations {
                    try await machineRepository.updateStation(station)
                }
                
                // Audit log
                try await auditService.logOperation(
                    operationType: .productionConfigChange,
                    entityType: .machine,
                    entityId: machine.id,
                    entityDescription: "Machine #\(machine.machineNumber) batch cleared",
                    operatorUserId: currentUser.id,
                    operatorUserName: currentUser.name,
                    operationDetails: [
                        "action": "clear_machine_batch",
                        "machineNumber": "\(machine.machineNumber)",
                        "previousBatchId": originalBatchId ?? "none",
                        "previousMode": originalMode?.rawValue ?? "none",
                        "clearedBy": currentUser.name
                    ]
                )
                
                return true
                
            } catch is CancellationError {
                return false
            } catch {
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to clear machine batch: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        return result
    }
    
    /// Get machines with active batches
    /// 获取有活跃批次的机器
    func getMachinesWithActiveBatches() async -> [WorkshopMachine] {
        guard isUserLoggedIn else { return [] }
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            return machines.filter { $0.hasActiveProductionBatch }
        } catch {
            return []
        }
    }
    
    /// Validate machine-batch consistency
    /// 验证机器-批次一致性
    func validateMachineBatchConsistency() async -> [String] {
        guard isUserLoggedIn else { return [] }
        
        var inconsistencies: [String] = []
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            
            for machine in machines {
                // Check if machine has currentBatchId but status is not running
                if machine.currentBatchId != nil && machine.status != .running {
                    inconsistencies.append("Machine #\(machine.machineNumber) has active batch but status is '\(machine.status.displayName)'")
                }
                
                // Check if machine status is running but has no currentBatchId
                if machine.status == .running && machine.currentBatchId == nil {
                    inconsistencies.append("Machine #\(machine.machineNumber) is running but has no active batch")
                }
                
                // Check station consistency
                let runningStations = machine.stations.filter { $0.status == .running }
                let hasRunningStations = !runningStations.isEmpty
                
                if machine.currentBatchId != nil && !hasRunningStations {
                    inconsistencies.append("Machine #\(machine.machineNumber) has active batch but no running stations")
                }
                
                if machine.currentBatchId == nil && hasRunningStations {
                    inconsistencies.append("Machine #\(machine.machineNumber) has no active batch but has running stations")
                }
            }
            
        } catch {
            inconsistencies.append("Failed to validate machine-batch consistency: \(error.localizedDescription)")
        }
        
        return inconsistencies
    }
    
    /// Get machine utilization rate based on active stations
    /// 基于活跃工位获取机器利用率
    func getMachineUtilizationRate(_ machine: WorkshopMachine) -> Double {
        let totalStations = machine.stations.count
        guard totalStations > 0 else { return 0.0 }
        
        let runningStations = machine.stations.filter { $0.status == .running }.count
        return Double(runningStations) / Double(totalStations) * 100.0
    }
    
    /// Update machine utilization rate
    /// 更新机器利用率
    func updateMachineUtilizationRate(_ machine: WorkshopMachine) async -> Bool {
        guard isUserLoggedIn else { return false }
        
        let newUtilizationRate = getMachineUtilizationRate(machine)
        
        if abs(machine.utilizationRate - newUtilizationRate) > 0.01 { // Only update if significant change
            machine.utilizationRate = newUtilizationRate
            machine.updatedAt = Date()
            
            do {
                try await machineRepository.updateMachine(machine)
                return true
            } catch {
                errorMessage = "Failed to update machine utilization rate: \(error.localizedDescription)"
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Notification Integration (通知集成)
    
    /// Send machine error notification
    /// 发送机台错误通知
    func sendMachineErrorNotification(machine: WorkshopMachine, errorMessage: String) async {
        guard let notificationEngine = notificationEngine else { return }
        
        do {
            try await notificationEngine.sendNotification(
                templateId: "machine_error",
                parameters: [
                    "machineNumber": "\(machine.machineNumber)",
                    "errorMessage": errorMessage
                ],
                relatedEntityId: machine.id,
                relatedEntityType: "WorkshopMachine"
            )
        } catch {
            print("Failed to send machine error notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - Machine Status Cache (机器状态缓存)
private struct MachineStatusCache {
    let timestamp: Date
    let hasRunningMachines: Bool
    let runningCount: Int
    let totalActiveCount: Int
    
    private let cacheTimeout: TimeInterval = 30 // 30 seconds
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > cacheTimeout
    }
}

// MARK: - Machine Status Summary (机器状态摘要)
struct MachineStatusSummary {
    let total: Int
    let running: Int
    let stopped: Int
    let maintenance: Int
    let error: Int
    
    var hasRunningMachines: Bool {
        return running > 0
    }
    
    var statusText: String {
        if total == 0 {
            return "无活动机器"
        }
        return "总计: \(total), 运行: \(running), 停止: \(stopped), 维护: \(maintenance), 故障: \(error)"
    }
    
    var canCreateBatch: Bool {
        return hasRunningMachines
    }
}