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
    
    func createBatch(machineId: String, mode: ProductionMode) async -> ProductionBatch? {
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
            
            let batch = ProductionBatch(
                machineId: machineId,
                mode: mode,
                submittedBy: currentUser.id,
                submittedByName: currentUser.name
            )
            
            currentBatch = batch
            return batch
            
        } catch {
            errorMessage = "Failed to validate machine: \(error.localizedDescription)"
            return nil
        }
    }
    
    func addProductToBatch(_ batch: ProductionBatch, productName: String, primaryColorId: String, secondaryColorId: String?, stations: [Int], productId: String? = nil, stationCount: Int? = nil, gunAssignment: String? = nil) async -> Bool {
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
        
        // Validate two-color product gun assignments and station distribution
        if batch.mode == .dualColor {
            let gunAStations = stations.filter { $0 <= 6 }
            let gunBStations = stations.filter { $0 > 6 }
            
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
                gunAssignment: gunAssignment
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
        
        isLoading = true
        
        do {
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
        
        batch.status = .approved
        batch.reviewedAt = Date()
        batch.reviewedBy = currentUser.id
        batch.reviewedByName = currentUser.name
        batch.reviewNotes = notes
        
        do {
            try await productionBatchRepository.updateBatch(batch)
            
            // Apply configuration to machine
            await applyBatchToMachine(batch)
            
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
}