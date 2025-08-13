//
//  ProductionBatchService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftUI

@MainActor
class ProductionBatchService: ObservableObject {
    // MARK: - Published Properties
    @Published var batches: [ProductionBatch] = []
    @Published var pendingBatches: [ProductionBatch] = []
    @Published var currentBatch: ProductionBatch?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let productionBatchRepository: ProductionBatchRepository
    private let machineRepository: MachineRepository
    private let colorRepository: ColorRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - Timer for cleanup
    private var cleanupTimer: Timer?
    
    init(
        productionBatchRepository: ProductionBatchRepository,
        machineRepository: MachineRepository,
        colorRepository: ColorRepository,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.productionBatchRepository = productionBatchRepository
        self.machineRepository = machineRepository
        self.colorRepository = colorRepository
        self.auditService = auditService
        self.authService = authService
    }
    
    deinit {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    // MARK: - Service Lifecycle
    
    func startService() {
        startCleanupTimer()
    }
    
    func stopService() {
        stopCleanupTimer()
    }
    
    // MARK: - Batch Management
    func loadBatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            batches = try await productionBatchRepository.fetchAllBatches()
        } catch {
            errorMessage = "Failed to load batches: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadPendingBatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            pendingBatches = try await productionBatchRepository.fetchPendingBatches()
        } catch {
            errorMessage = "Failed to load pending batches: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createBatch(machineId: String, mode: ProductionMode, approvalTargetDate: Date = Date()) async -> ProductionBatch? {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to create production batches"
            return nil
        }
        
        // Validate machine exists and is available
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == machineId }) else {
                errorMessage = "Machine not found"
                return nil
            }
            
            guard machine.canReceiveNewTasks else {
                errorMessage = "Machine is not available for new production tasks"
                return nil
            }
            
            // Generate sequential batch number
            let batchNumber = await ProductionBatch.generateBatchNumber(using: productionBatchRepository)
            
            let batch = ProductionBatch(
                machineId: machineId,
                mode: mode,
                submittedBy: currentUser.id,
                submittedByName: currentUser.name,
                approvalTargetDate: approvalTargetDate,
                batchNumber: batchNumber
            )
            
            // Save the batch to database immediately after creation
            try await productionBatchRepository.addBatch(batch)
            
            // Audit log for batch creation
            try await auditService.logOperation(
                operationType: .batchSubmission,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "action": "create",
                    "machine_id": machineId,
                    "mode": mode.rawValue,
                    "batch_number": batchNumber
                ]
            )
            
            currentBatch = batch
            return batch
            
        } catch {
            errorMessage = "Failed to validate machine: \(error.localizedDescription)"
            return nil
        }
    }
    
    func addProductToBatch(_ batch: ProductionBatch, productName: String, primaryColorId: String, secondaryColorId: String?, stations: [Int], productId: String? = nil, stationCount: Int? = nil, gunAssignment: String? = nil, approvalTargetDate: Date? = nil, startTime: Date? = nil) async -> Bool {
        // Validation rules
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Product name cannot be empty"
            return false
        }
        
        guard stations.count >= batch.mode.minStationsPerProduct else {
            errorMessage = "Product requires at least \(batch.mode.minStationsPerProduct) stations for \(batch.mode.displayName)"
            return false
        }
        
        // Validate stations are within range (1-12)
        guard stations.allSatisfy({ $0 >= 1 && $0 <= 12 }) else {
            errorMessage = "Station numbers must be between 1 and 12"
            return false
        }
        
        // Check for station conflicts with existing products in batch
        let existingStations = batch.products.flatMap { $0.occupiedStations }
        let conflictingStations = Set(stations).intersection(Set(existingStations))
        guard conflictingStations.isEmpty else {
            errorMessage = "Stations \(conflictingStations.sorted().map(String.init).joined(separator: ", ")) are already occupied"
            return false
        }
        
        // Check total station usage doesn't exceed 12
        let totalStations = existingStations.count + stations.count
        guard totalStations <= 12 else {
            errorMessage = "Total station usage would exceed 12 stations"
            return false
        }
        
        // Check max products limit
        guard batch.products.count < batch.mode.maxProducts else {
            errorMessage = "Maximum \(batch.mode.maxProducts) products allowed for \(batch.mode.displayName)"
            return false
        }
        
        // Validate dual-color requirements
        if batch.mode == .dualColor && secondaryColorId == nil {
            errorMessage = "Dual-color production requires a secondary color"
            return false
        }
        
        if batch.mode == .singleColor && secondaryColorId != nil {
            errorMessage = "Single-color production cannot have a secondary color"
            return false
        }
        
        // Validate timing requirements
        if let startTime = startTime, let approvalDate = approvalTargetDate {
            let now = Date()
            let calendar = Calendar.current
            let startDateTime = combineDateTime(date: approvalDate, time: startTime)
            
            // Start time must be in the future if approval date is today
            if calendar.isDate(approvalDate, inSameDayAs: now) && startDateTime <= now {
                errorMessage = "开始时间必须是将来时间"
                return false
            }
        }
        
        // Enhanced single-color production mode constraints
        if batch.mode == .singleColor && gunAssignment != nil {
            // Validate gun capacity limits
            let gunAStations = [1, 2, 3, 4, 5, 6]
            let gunBStations = [7, 8, 9, 10, 11, 12]
            
            let currentGunAOccupied = batch.products.flatMap { $0.occupiedStations }.filter { $0 <= 6 }
            let currentGunBOccupied = batch.products.flatMap { $0.occupiedStations }.filter { $0 > 6 }
            
            if gunAssignment == "Gun A" {
                // Check if Gun A has enough capacity
                let newGunAStations = stations.filter { $0 <= 6 }
                let totalGunAStations = Set(currentGunAOccupied).union(Set(newGunAStations))
                
                if totalGunAStations.count > 6 {
                    errorMessage = "Gun A 容量不足 (最多6个工位，当前已占用 \(currentGunAOccupied.count) 个)"
                    return false
                }
                
                // Ensure stations are only from Gun A range
                let invalidStations = stations.filter { $0 > 6 }
                if !invalidStations.isEmpty {
                    errorMessage = "Gun A 只能使用工位 1-6"
                    return false
                }
            }
            
            if gunAssignment == "Gun B" {
                // Check if Gun B has enough capacity
                let newGunBStations = stations.filter { $0 > 6 }
                let totalGunBStations = Set(currentGunBOccupied).union(Set(newGunBStations))
                
                if totalGunBStations.count > 6 {
                    errorMessage = "Gun B 容量不足 (最多6个工位，当前已占用 \(currentGunBOccupied.count) 个)"
                    return false
                }
                
                // Ensure stations are only from Gun B range
                let invalidStations = stations.filter { $0 <= 6 }
                if !invalidStations.isEmpty {
                    errorMessage = "Gun B 只能使用工位 7-12"
                    return false
                }
            }
            
            // Check if there are existing products using the same gun
            let existingProductsWithSameGun = batch.products.filter { $0.gunAssignment == gunAssignment }
            
            if !existingProductsWithSameGun.isEmpty {
                let existingProduct = existingProductsWithSameGun.first!
                
                // Enforce same color constraint for same gun
                if existingProduct.primaryColorId != primaryColorId {
                    errorMessage = "同一喷枪的产品必须使用相同颜色"
                    return false
                }
                
                // Enforce station count consistency for same gun
                if let existingStationCount = existingProduct.stationCount,
                   let newStationCount = stationCount,
                   existingStationCount != newStationCount && newStationCount != -1 {
                    errorMessage = "同一喷枪的产品必须使用相同工位数量 (已有: \(existingStationCount) 工位)"
                    return false
                }
            }
        }
        
        // Enhanced two-color production mode constraints
        if batch.mode == .dualColor {
            let gunAStations = stations.filter { $0 <= 6 }
            let gunBStations = stations.filter { $0 > 6 }
            
            // Check if there are existing products in the batch
            if !batch.products.isEmpty {
                let existingProduct = batch.products.first!
                
                // Enforce station count consistency for two-color mode
                if let existingStationCount = existingProduct.stationCount,
                   let newStationCount = stationCount,
                   existingStationCount != newStationCount && newStationCount != -1 {
                    errorMessage = "双色生产模式中所有产品必须使用相同工位数量 (已有: \(existingStationCount) 工位)"
                    return false
                }
            }
            
            // For dual-color products, ensure both guns have stations if it's a 3+3 configuration
            if stationCount == 3 {
                if gunAStations.isEmpty || gunBStations.isEmpty {
                    errorMessage = "双色产品需要同时使用Gun A和Gun B的工位"
                    return false
                }
                
                // Ensure Gun A and Gun B colors are distinct
                if primaryColorId == secondaryColorId {
                    errorMessage = "Gun A和Gun B必须使用不同的颜色"
                    return false
                }
            } else if stationCount == 6 {
                // For 6-workstation dual-color products, they should occupy Gun B workstations
                if gunAStations.count > gunBStations.count {
                    errorMessage = "6工位双色产品应主要占用Gun B的工位"
                    return false
                }
                
                // Ensure Gun A and Gun B colors are distinct
                if primaryColorId == secondaryColorId {
                    errorMessage = "Gun A和Gun B必须使用不同的颜色"
                    return false
                }
            }
        }
        
        // Validate color IDs exist
        do {
            let colors = try await colorRepository.fetchActiveColors()
            guard colors.contains(where: { $0.id == primaryColorId }) else {
                errorMessage = "Primary color not found"
                return false
            }
            
            if let secondaryColorId = secondaryColorId {
                guard colors.contains(where: { $0.id == secondaryColorId }) else {
                    errorMessage = "Secondary color not found"
                    return false
                }
            }
            
            let productConfig = ProductConfig(
                batchId: batch.id,
                productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
                primaryColorId: primaryColorId,
                occupiedStations: stations,
                priority: batch.products.count + 1,
                secondaryColorId: secondaryColorId,
                productId: productId,
                stationCount: stationCount,
                gunAssignment: gunAssignment,
                approvalTargetDate: approvalTargetDate,
                startTime: startTime
            )
            
            batch.products.append(productConfig)
            return true
            
        } catch {
            errorMessage = "Failed to validate colors: \(error.localizedDescription)"
            return false
        }
    }
    
    func removeProductFromBatch(_ batch: ProductionBatch, productConfig: ProductConfig) -> Bool {
        batch.products.removeAll { $0.id == productConfig.id }
        
        // Reorder priorities
        for (index, product) in batch.products.enumerated() {
            product.priority = index + 1
        }
        
        return true
    }
    
    func submitBatch(_ batch: ProductionBatch) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to submit batches"
            return false
        }
        
        // Final validation
        guard batch.isValidConfiguration else {
            errorMessage = "Invalid batch configuration"
            return false
        }
        
        guard !batch.products.isEmpty else {
            errorMessage = "Batch must contain at least one product"
            return false
        }
        
        // Check for station conflicts with pending batches on the same machine
        // Use already loaded batches to avoid thread safety issues
        await loadBatches()
        let pendingBatches = batches.filter { $0.status == .pending }
        let pendingBatchesForMachine = pendingBatches.filter { $0.machineId == batch.machineId }
        
        if !pendingBatchesForMachine.isEmpty {
            let pendingStations = Set(pendingBatchesForMachine.flatMap { pendingBatch in
                pendingBatch.products.flatMap { $0.occupiedStations }
            })
            
            let currentBatchStations = Set(batch.products.flatMap { $0.occupiedStations })
            let conflictingStations = pendingStations.intersection(currentBatchStations)
            
            if !conflictingStations.isEmpty {
                let sortedConflicts = conflictingStations.sorted().map(String.init).joined(separator: ", ")
                errorMessage = "工位冲突：工位 \(sortedConflicts) 已被待审核批次占用，请修改产品配置后再提交"
                return false
            }
        }
        
        isLoading = true
        
        do {
            // Update status to pending (awaiting review) when submitting
            batch.status = .pending
            
            // Capture before/after snapshots for audit
            let machines = try await machineRepository.fetchAllMachines()
            if let machine = machines.first(where: { $0.id == batch.machineId }) {
                batch.beforeConfigSnapshot = try? JSONEncoder().encode(machine).base64EncodedString()
            }
            
            try await productionBatchRepository.addBatch(batch)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .batchSubmission,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "machineId": batch.machineId,
                    "mode": batch.mode.rawValue,
                    "productCount": batch.products.count,
                    "totalStations": batch.totalStationsUsed,
                    "submittedBy": currentUser.name
                ]
            )
            
            await loadBatches()
            await loadPendingBatches()
            currentBatch = nil
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to submit batch: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Admin Review Functions
    func approveBatch(_ batch: ProductionBatch, notes: String? = nil) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can approve batches"
            return false
        }
        
        guard batch.canBeReviewed else {
            errorMessage = "Batch cannot be reviewed in its current state"
            return false
        }
        
        batch.status = .pendingExecution
        batch.reviewedAt = Date()
        batch.reviewedBy = currentUser.id
        batch.reviewedByName = currentUser.name
        batch.reviewNotes = notes
        
        do {
            try await productionBatchRepository.updateBatch(batch)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .batchReview,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "action": "approved",
                    "reviewNotes": notes ?? "",
                    "reviewedBy": currentUser.name
                ]
            )
            
            await loadBatches()
            await loadPendingBatches()
            return true
            
        } catch {
            errorMessage = "Failed to approve batch: \(error.localizedDescription)"
            return false
        }
    }
    
    func rejectBatch(_ batch: ProductionBatch, notes: String) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            errorMessage = "Only administrators can reject batches"
            return false
        }
        
        guard batch.canBeReviewed else {
            errorMessage = "Batch cannot be reviewed in its current state"
            return false
        }
        
        guard !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Rejection reason is required"
            return false
        }
        
        batch.status = .rejected
        batch.reviewedAt = Date()
        batch.reviewedBy = currentUser.id
        batch.reviewedByName = currentUser.name
        batch.reviewNotes = notes
        batch.rejectedAt = Date()
        
        do {
            try await productionBatchRepository.updateBatch(batch)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .batchReview,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "action": "rejected",
                    "reviewNotes": notes,
                    "reviewedBy": currentUser.name
                ]
            )
            
            await loadBatches()
            await loadPendingBatches()
            return true
            
        } catch {
            errorMessage = "Failed to reject batch: \(error.localizedDescription)"
            return false
        }
    }
    
    private func applyBatchToMachine(_ batch: ProductionBatch) async {
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == batch.machineId }) else {
                return
            }
            
            // Update machine configuration
            machine.currentBatchId = batch.id
            machine.currentProductionMode = batch.mode
            machine.lastConfigurationUpdate = Date()
            machine.status = .running
            
            // Update station statuses based on product configs
            for station in machine.stations {
                let isOccupied = batch.products.contains { product in
                    product.occupiedStations.contains(station.stationNumber)
                }
                station.status = isOccupied ? .running : .idle
            }
            
            batch.status = .active
            batch.appliedAt = Date()
            
            try await machineRepository.updateMachine(machine)
            try await productionBatchRepository.updateBatch(batch)
            
        } catch {
            print("Failed to apply batch to machine: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    func validateStationAvailability(machineId: String, requestedStations: [Int]) async -> Bool {
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == machineId }) else {
                return false
            }
            
            let availableStations = machine.availableStations.map { $0.stationNumber }
            return Set(requestedStations).isSubset(of: Set(availableStations))
            
        } catch {
            return false
        }
    }
    
    func getAvailableStations(machineId: String) async -> [Int] {
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == machineId }) else {
                return []
            }
            
            return machine.availableStations.map { $0.stationNumber }.sorted()
            
        } catch {
            return []
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Batch Cleanup Methods
    
    /// Automatically removes old batches that have been in completed/rejected status for more than 24 hours
    func cleanupOldBatches() async -> Int {
        guard let currentUser = authService.currentUser else {
            return 0
        }
        
        await loadBatches()
        
        let now = Date()
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
        
        // Find batches to remove (rejected and completed older than 24 hours)
        let batchesToRemove = batches.filter { batch in
            switch batch.status {
            case .rejected:
                return batch.rejectedAt != nil && batch.rejectedAt! < twentyFourHoursAgo
            case .completed:
                return batch.completedAt != nil && batch.completedAt! < twentyFourHoursAgo
            default:
                return false
            }
        }
        
        var cleanupCount = 0
        
        for batch in batchesToRemove {
            do {
                try await productionBatchRepository.deleteBatch(id: batch.id)
                
                // Audit log for cleanup
                try await auditService.logOperation(
                    operationType: .batchDelete,
                    entityType: .productionBatch,
                    entityId: batch.id,
                    entityDescription: "Batch \(batch.batchNumber) (auto-cleanup)",
                    operatorUserId: currentUser.id,
                    operatorUserName: currentUser.name,
                    operationDetails: [
                        "batchNumber": batch.batchNumber,
                        "action": "auto_cleanup_old_batch",
                        "status": batch.status.rawValue,
                        "timestampField": batch.status == .rejected ? "rejectedAt" : "completedAt",
                        "timestamp": (batch.status == .rejected ? batch.rejectedAt : batch.completedAt)?.description ?? "",
                        "hoursAfterStatusChange": Int(now.timeIntervalSince((batch.status == .rejected ? batch.rejectedAt : batch.completedAt) ?? now) / 3600)
                    ]
                )
                
                cleanupCount += 1
            } catch {
                print("Failed to cleanup rejected batch \(batch.batchNumber): \(error)")
            }
        }
        
        if cleanupCount > 0 {
            await loadBatches()
        }
        
        return cleanupCount
    }
    
    /// Start periodic cleanup timer (runs every 30 minutes)
    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.cleanupOldBatches()
            }
        }
    }
    
    /// Stop cleanup timer
    private func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    // MARK: - Batch Execution Methods
    
    func applyBatchConfiguration(_ batch: ProductionBatch) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to execute batches"
            return false
        }
        
        guard batch.status == .pendingExecution else {
            errorMessage = "Only pending execution batches can be executed"
            return false
        }
        
        isLoading = true
        
        do {
            // Check for station conflicts with existing active batches on the same machine
            await handleStationConflicts(for: batch)
            
            // Apply configuration to machine (integrates with Device and Color Management)
            await applyBatchToMachine(batch)
            
            // Update batch status to active
            batch.status = .active
            batch.appliedAt = Date()
            
            try await productionBatchRepository.updateBatch(batch)
            
            // Audit log for execution
            try await auditService.logOperation(
                operationType: .productionConfigChange,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "machineId": batch.machineId,
                    "executedBy": currentUser.name,
                    "productCount": batch.products.count,
                    "totalStations": batch.totalStationsUsed,
                    "action": "execute_approved_batch"
                ]
            )
            
            await loadBatches()
            await loadPendingBatches()
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to execute batch: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Handle station conflicts when executing a new batch
    private func handleStationConflicts(for newBatch: ProductionBatch) async {
        // Get all active batches on the same machine
        await loadBatches()
        let activeBatches = batches.filter { batch in
            batch.machineId == newBatch.machineId && 
            batch.status == .active &&
            batch.id != newBatch.id
        }
        
        guard let currentUser = authService.currentUser else { return }
        
        // Get stations used by the new batch
        let newBatchStations = Set(newBatch.products.flatMap { $0.occupiedStations })
        
        // Check each active batch for station conflicts
        for activeBatch in activeBatches {
            let activeBatchStations = Set(activeBatch.products.flatMap { $0.occupiedStations })
            
            // If there's any station overlap, mark the old batch as completed
            if !newBatchStations.intersection(activeBatchStations).isEmpty {
                activeBatch.status = .completed
                activeBatch.completedAt = Date()
                
                do {
                    try await productionBatchRepository.updateBatch(activeBatch)
                    
                    // Audit log for auto-completion due to station conflict
                    try await auditService.logOperation(
                        operationType: .statusChange,
                        entityType: .productionBatch,
                        entityId: activeBatch.id,
                        entityDescription: "Batch \(activeBatch.batchNumber)",
                        operatorUserId: currentUser.id,
                        operatorUserName: currentUser.name,
                        operationDetails: [
                            "oldStatus": "active",
                            "newStatus": "completed",
                            "reason": "station_conflict_with_new_batch",
                            "conflictingBatch": newBatch.batchNumber,
                            "conflictingStations": Array(newBatchStations.intersection(activeBatchStations)).sorted().map(String.init).joined(separator: ",")
                        ]
                    )
                    
                } catch {
                    print("Failed to update conflicting batch \(activeBatch.batchNumber): \(error)")
                }
            }
        }
    }
    
    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents) ?? date
    }
}