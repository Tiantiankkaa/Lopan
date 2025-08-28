//
//  ProductionBatchService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftUI

@MainActor
public class ProductionBatchService: ObservableObject, ServiceCleanupProtocol {
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
    
    // MARK: - Shift-aware Dependencies (班次相关依赖)
    private let dateShiftPolicy: DateShiftPolicy
    private let timeProvider: TimeProvider
    private let machineService: MachineService?
    
    // MARK: - Notification Dependencies (通知依赖)
    private weak var notificationEngine: NotificationEngine?
    
    // MARK: - Permission Dependencies (权限依赖)
    private weak var permissionService: AdvancedPermissionService?
    
    // MARK: - Timer for cleanup
    private var cleanupTimer: Timer?
    
    init(
        productionBatchRepository: ProductionBatchRepository,
        machineRepository: MachineRepository,
        colorRepository: ColorRepository,
        auditService: NewAuditingService,
        authService: AuthenticationService,
        dateShiftPolicy: DateShiftPolicy = StandardDateShiftPolicy(),
        timeProvider: TimeProvider = SystemTimeProvider(),
        machineService: MachineService? = nil,
        notificationEngine: NotificationEngine? = nil,
        permissionService: AdvancedPermissionService? = nil
    ) {
        self.productionBatchRepository = productionBatchRepository
        self.machineRepository = machineRepository
        self.colorRepository = colorRepository
        self.auditService = auditService
        self.authService = authService
        self.dateShiftPolicy = dateShiftPolicy
        self.timeProvider = timeProvider
        self.machineService = machineService
        self.notificationEngine = notificationEngine
        self.permissionService = permissionService
    }
    
    deinit {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    // MARK: - Service Lifecycle
    
    func startService() {
        print("🚀 ProductionBatchService: Starting service with automatic batch execution")
        startCleanupTimer()
    }
    
    func stopService() {
        stopCleanupTimer()
    }
    
    // MARK: - ServiceCleanupProtocol
    func cleanup() {
        stopService()
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
        // Use advanced permission system if available, fallback to role-based check
        if let permissionService = permissionService {
            let context = permissionService.createContext(
                targetEntityId: machineId,
                targetEntityType: "WorkshopMachine",
                additionalData: ["mode": mode.rawValue]
            )
            
            let permissionResult = await permissionService.hasPermission(.createBatch, context: context)
            guard permissionResult.isGranted else {
                errorMessage = "权限不足: \(permissionResult.reason)"
                return nil
            }
        } else {
            // Fallback to simple role-based check
            guard let currentUser = authService.currentUser,
                  currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
                errorMessage = "Insufficient permissions to create production batches"
                return nil
            }
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
            
            // Generate sequential batch number with Production Configuration type
            let batchNumber = await ProductionBatch.generateBatchNumber(using: productionBatchRepository, batchType: .productionConfig)
            
            let batch = ProductionBatch(
                machineId: machineId,
                mode: mode,
                submittedBy: authService.currentUser?.id ?? "unknown",
                submittedByName: authService.currentUser?.name ?? "Unknown User",
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
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
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
    
    // MARK: - Shift-aware Batch Creation (班次感知批次创建)
    
    /// Create a shift-aware batch with date and shift validation
    /// 创建支持班次的批次，包含日期和班次验证
    func createShiftBatch(
        machineId: String, 
        mode: ProductionMode, 
        targetDate: Date, 
        shift: Shift, 
        approvalTargetDate: Date = Date()
    ) async -> ProductionBatch? {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to create production batches"
            return nil
        }
        
        // Validate shift selection according to policy
        do {
            try dateShiftPolicy.validateShiftSelection(shift, for: targetDate, currentTime: timeProvider.now)
        } catch {
            if let shiftError = error as? ShiftSelectionError {
                errorMessage = shiftError.localizedDescription
            } else {
                errorMessage = "Invalid shift selection: \(error.localizedDescription)"
            }
            return nil
        }
        
        // Check if any machines are running (PRD requirement)
        let hasRunningMachines: Bool
        if let machineService = machineService {
            hasRunningMachines = await machineService.isAnyMachineRunning()
        } else {
            // Fallback: check directly via repository
            do {
                let machines = try await machineRepository.fetchAllMachines()
                hasRunningMachines = machines.contains { $0.status == .running && $0.isActive }
            } catch {
                errorMessage = "Failed to check machine status: \(error.localizedDescription)"
                return nil
            }
        }
        
        guard hasRunningMachines else {
            errorMessage = "无法创建批次 - 当前无生产活动，请先启动机台"
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
            
            // Generate sequential batch number with Batch Processing type
            let batchNumber = await ProductionBatch.generateBatchNumber(using: productionBatchRepository, batchType: .batchProcessing)
            
            let batch = ProductionBatch(
                machineId: machineId,
                mode: mode,
                submittedBy: authService.currentUser?.id ?? "unknown",
                submittedByName: authService.currentUser?.name ?? "Unknown User",
                approvalTargetDate: approvalTargetDate,
                batchNumber: batchNumber,
                targetDate: targetDate,
                shift: shift
            )
            
            // Save the batch to database immediately after creation
            try await productionBatchRepository.addBatch(batch)
            
            // Enhanced audit log for shift-aware batch
            try await auditService.logOperation(
                operationType: .batchSubmission,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Shift Batch \(batch.batchNumber)",
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "action": "create_shift_batch",
                    "machine_id": machineId,
                    "mode": mode.rawValue,
                    "batch_number": batchNumber,
                    "target_date": timeProvider.formatDate(targetDate),
                    "shift": shift.rawValue,
                    "shift_display": shift.displayName,
                    "cutoff_info": dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: timeProvider.now).isAfterCutoff ? "after_cutoff" : "before_cutoff"
                ]
            )
            
            currentBatch = batch
            return batch
            
        } catch {
            errorMessage = "Failed to create shift batch: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Get available shifts for a target date
    /// 获取目标日期的可用班次
    func getAvailableShifts(for targetDate: Date) -> Set<Shift> {
        return dateShiftPolicy.allowedShifts(for: targetDate, currentTime: timeProvider.now)
    }
    
    /// Get default shift for a target date
    /// 获取目标日期的默认班次
    func getDefaultShift(for targetDate: Date) -> Shift {
        return dateShiftPolicy.defaultShift(for: targetDate, currentTime: timeProvider.now)
    }
    
    /// Get shift cutoff information
    /// 获取班次截止信息
    func getShiftCutoffInfo(for targetDate: Date) -> ShiftCutoffInfo {
        return dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: timeProvider.now)
    }
    
    func addProductToBatch(_ batch: ProductionBatch, productName: String, primaryColorId: String, secondaryColorId: String?, stations: [Int], productId: String? = nil, stationCount: Int? = nil, gunAssignment: String? = nil, approvalTargetDate: Date? = nil, startTime: Date? = nil, isFromProductionConfiguration: Bool = false) async -> Bool {
        
        // MARK: - Shift-aware Color-only Validation (班次感知颜色编辑限制验证)
        // Only apply structure modification restrictions for non-production configuration contexts
        // 只有在非生产配置上下文中才应用结构修改限制
        if !isFromProductionConfiguration && batch.isShiftBatch && !batch.canModifyStructure {
            // For shift-aware batches, only color modifications are allowed
            // 对于班次批次，仅允许颜色修改
            errorMessage = "产品修改需前往\"生产配置\"进行。"
            return false
        }
        
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
        // Only validate time for non-production configuration contexts
        // 仅在非生产配置上下文中验证时间（生产配置页面只选择班次，不选择具体时间点）
        if !isFromProductionConfiguration {
            if let startTime = startTime, let approvalDate = approvalTargetDate {
                let now = Date()
                let calendar = Calendar.current
                let startDateTime = DateTimeUtilities.combineDateTime(date: approvalDate, time: startTime)
                
                // Start time must be in the future if approval date is today
                if calendar.isDate(approvalDate, inSameDayAs: now) && startDateTime <= now {
                    errorMessage = "开始时间必须是将来时间"
                    return false
                }
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
        
        // No need to reorder priorities as they have been removed
        
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
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "machineId": batch.machineId,
                    "mode": batch.mode.rawValue,
                    "productCount": batch.products.count,
                    "totalStations": batch.totalStationsUsed,
                    "submittedBy": currentUser.name,
                    "isShiftBatch": batch.isShiftBatch,
                    "targetDate": batch.targetDate?.ISO8601Format() ?? "",
                    "shift": batch.shift?.rawValue ?? "",
                    "allowsColorModificationOnly": batch.allowsColorModificationOnly
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
    
    // MARK: - Execution Functions (执行功能)
    @MainActor
    func executeBatch(_ batch: ProductionBatch, at executionTime: Date) async -> Bool {
        guard batch.canExecute else {
            errorMessage = "批次不能执行：状态必须为'待执行'"
            return false
        }
        
        // Validate execution time
        if executionTime > Date() {
            errorMessage = "执行时间不能晚于当前时间"
            return false
        }
        
        // Get all batches for validation
        do {
            let allBatches = try await productionBatchRepository.fetchAllBatches()
            
            // Use DateShiftPolicy to validate execution
            let dateShiftPolicy = StandardDateShiftPolicy()
            let validationResult = dateShiftPolicy.canExecuteBatch(
                batch: batch,
                at: executionTime,
                allBatches: allBatches
            )
            
            if !validationResult.canExecute {
                errorMessage = validationResult.reason ?? "无法执行批次"
                return false
            }
            
            // Set execution time and update status
            batch.setExecutionTime(executionTime)
            
            // Synchronize machine status with batch execution
            await syncMachineWithBatchExecution(batch)
            
            // Save changes
            try await productionBatchRepository.updateBatch(batch)
            
            // Audit log
            await auditService.logUpdate(
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "批次 \(batch.batchNumber)",
                operatorUserId: authService.currentUser?.id ?? "system",
                operatorUserName: authService.currentUser?.name ?? "系统",
                beforeData: ["status": "pendingExecution", "executionTime": "nil"],
                afterData: ["status": "active", "executionTime": "\(executionTime)"],
                changedFields: ["status", "executionTime"]
            )
            
            return true
        } catch {
            errorMessage = "执行批次失败: \(error.localizedDescription)"
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
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "action": "approved",
                    "reviewNotes": notes ?? "",
                    "reviewedBy": currentUser.name,
                    "isShiftBatch": batch.isShiftBatch,
                    "targetDate": batch.targetDate?.ISO8601Format() ?? "",
                    "shift": batch.shift?.rawValue ?? "",
                    "allowsColorModificationOnly": batch.allowsColorModificationOnly
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
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "batchNumber": batch.batchNumber,
                    "action": "rejected",
                    "reviewNotes": notes,
                    "reviewedBy": currentUser.name,
                    "isShiftBatch": batch.isShiftBatch,
                    "targetDate": batch.targetDate?.ISO8601Format() ?? "",
                    "shift": batch.shift?.rawValue ?? "",
                    "allowsColorModificationOnly": batch.allowsColorModificationOnly
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
            
            // Clear any existing batch on this machine first to prevent conflicts
            await clearMachineActiveBinding(machine)
            
            // Update machine configuration with new batch
            machine.currentBatchId = batch.id
            machine.currentProductionMode = batch.mode
            machine.lastConfigurationUpdate = Date()
            machine.status = .running
            machine.updatedAt = Date()
            
            // Update station statuses based on product configs
            for station in machine.stations {
                let isOccupied = batch.products.contains { product in
                    product.occupiedStations.contains(station.stationNumber)
                }
                
                if isOccupied {
                    station.status = .running
                    // Set the product ID for tracking
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
            
            // Update batch status to active and set execution time if not already set
            batch.status = .active
            batch.appliedAt = Date()
            if batch.executionTime == nil {
                batch.executionTime = Date()
            }
            
            // Ensure batch has proper date and shift information for inheritance queries
            if batch.targetDate == nil {
                batch.targetDate = Date()
            }
            if batch.shift == nil {
                // Determine shift based on current time
                let hour = Calendar.current.component(.hour, from: Date())
                batch.shift = hour < 12 ? .morning : .evening
            }
            
            batch.updatedAt = Date()
            
            // Save all changes
            try await machineRepository.updateMachine(machine)
            for station in machine.stations {
                try await machineRepository.updateStation(station)
            }
            try await productionBatchRepository.updateBatch(batch)
            
            print("Successfully applied batch \(batch.batchNumber) to machine \(machine.machineNumber)")
            
        } catch {
            print("Failed to apply batch to machine: \(error)")
            errorMessage = "Failed to apply batch configuration: \(error.localizedDescription)"
        }
    }
    
    /// Clear any active batch binding from a machine
    /// 清除机器的活跃批次绑定
    private func clearMachineActiveBinding(_ machine: WorkshopMachine) async {
        guard let currentBatchId = machine.currentBatchId else { return }
        
        do {
            // Find the currently active batch and mark it as completed
            let batches = try await productionBatchRepository.fetchAllBatches()
            if let activeBatch = batches.first(where: { $0.id == currentBatchId && $0.status == .active }) {
                activeBatch.status = .completed
                activeBatch.completedAt = Date()
                activeBatch.updatedAt = Date()
                try await productionBatchRepository.updateBatch(activeBatch)
                
                print("Automatically completed previous batch \(activeBatch.batchNumber) due to new batch application")
            }
            
            // Clear machine's current batch reference
            machine.currentBatchId = nil
            machine.currentProductionMode = nil
            machine.lastConfigurationUpdate = Date()
            machine.updatedAt = Date()
            
            // Reset all stations to idle
            for station in machine.stations {
                station.status = .idle
                station.currentProductId = nil
                station.updatedAt = Date()
            }
            
        } catch {
            print("Failed to clear machine active binding: \(error)")
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
    
    /// Background version of cleanup that doesn't update UI properties
    /// 后台版本的清理，不更新UI属性
    @MainActor
    private func performCleanupOldBatches() async -> Int {
        guard let currentUser = authService.currentUser else {
            return 0
        }
        
        // Fetch batches directly from repository without updating UI
        do {
            let allBatches = try await productionBatchRepository.fetchAllBatches()
            
            let now = Date()
            let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
            
            // Find batches to remove (rejected and completed older than 24 hours)
            let batchesToRemove = allBatches.filter { batch in
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
            
            return cleanupCount
        } catch {
            print("Failed to fetch batches for cleanup: \(error)")
            return 0
        }
    }
    
    /// Background version of overdue batch check that doesn't update UI properties
    /// 后台版本的过期批次检查，不更新UI属性
    @MainActor
    private func performCheckAndCompleteOverdueBatches() async -> Int {
        guard let currentUser = authService.currentUser else {
            print("❌ ProductionBatchService: No current user for auto-completion")
            return 0
        }
        
        // Fetch batches directly from repository without updating UI
        do {
            let allBatches = try await productionBatchRepository.fetchAllBatches()
            let currentTime = timeProvider.now
            print("🔍 ProductionBatchService: Checking for overdue batches at \(currentTime)")
            
            // Find all batches in pendingExecution status that have shift information
            let pendingExecutionBatches = allBatches.filter { batch in
                batch.status == .pendingExecution && 
                batch.targetDate != nil && 
                batch.shift != nil
            }
            
            print("📋 ProductionBatchService: Found \(pendingExecutionBatches.count) pending execution batches with shift info")
            
            var autoCompletedCount = 0
            
            for batch in pendingExecutionBatches {
                guard let targetDate = batch.targetDate,
                      let shift = batch.shift else { continue }
                
                print("🔄 ProductionBatchService: Checking batch \(batch.batchNumber) - \(targetDate) \(shift.displayName)")
                
                // Check if the shift is overdue
                if dateShiftPolicy.isShiftOverdue(shift, for: targetDate, currentTime: currentTime) {
                    print("⏰ ProductionBatchService: Batch \(batch.batchNumber) is overdue - auto-completing")
                    
                    // Get the auto execution time (shift start time)
                    guard let executionTime = dateShiftPolicy.getShiftAutoExecutionTime(shift, for: targetDate) else {
                        print("❌ ProductionBatchService: Could not get execution time for batch \(batch.batchNumber)")
                        continue
                    }
                    
                    // Get the shift end time for completion
                    guard let completionTime = dateShiftPolicy.getShiftEndTime(shift, for: targetDate) else {
                        print("❌ ProductionBatchService: Could not get completion time for batch \(batch.batchNumber)")
                        continue
                    }
                    
                    print("✅ ProductionBatchService: Auto-completing batch \(batch.batchNumber) with execution time \(executionTime) and completion time \(completionTime)")
                    
                    // Set the execution and completion times on the batch
                    batch.setAutoCompleted(executionTime: executionTime, completionTime: completionTime)
                    
                    // Complete the batch automatically (skip normal execution)
                    // Note: This needs to run on main actor for SwiftData operations
                    let success = await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            let result = await completeBatch(batch, isAutoCompletion: true)
                            continuation.resume(returning: result)
                        }
                    }
                    
                    if success {
                        autoCompletedCount += 1
                        print("✅ ProductionBatchService: Successfully auto-completed batch \(batch.batchNumber)")
                    } else {
                        print("❌ ProductionBatchService: Failed to auto-complete batch \(batch.batchNumber)")
                    }
                } else {
                    print("⏳ ProductionBatchService: Batch \(batch.batchNumber) is not yet overdue")
                }
            }
            
            return autoCompletedCount
        } catch {
            print("Failed to fetch batches for overdue check: \(error)")
            return 0
        }
    }
    
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
    
    /// Automatically complete overdue batches that have passed their shift time
    func checkAndExecuteOverdueBatches() async -> Int {
        guard let currentUser = authService.currentUser else {
            print("❌ ProductionBatchService: No current user for auto-execution")
            return 0
        }
        
        await loadBatches()
        let currentTime = timeProvider.now
        print("🔍 ProductionBatchService: Checking for overdue batches at \(currentTime)")
        
        // Find all batches in pendingExecution status that have shift information
        let pendingExecutionBatches = batches.filter { batch in
            batch.status == .pendingExecution && 
            batch.targetDate != nil && 
            batch.shift != nil
        }
        
        print("📋 ProductionBatchService: Found \(pendingExecutionBatches.count) pending execution batches with shift info")
        
        var autoExecutedCount = 0
        
        for batch in pendingExecutionBatches {
            guard let targetDate = batch.targetDate,
                  let shift = batch.shift else { continue }
            
            print("🔄 ProductionBatchService: Checking batch \(batch.batchNumber) - \(targetDate) \(shift.displayName)")
            
            // Check if the shift is overdue
            if dateShiftPolicy.isShiftOverdue(shift, for: targetDate, currentTime: currentTime) {
                print("⏰ ProductionBatchService: Batch \(batch.batchNumber) is overdue - auto-completing")
                
                // Get the auto execution time (shift start time)
                guard let executionTime = dateShiftPolicy.getShiftAutoExecutionTime(shift, for: targetDate) else {
                    print("❌ ProductionBatchService: Could not get execution time for batch \(batch.batchNumber)")
                    continue
                }
                
                // Get the shift end time for completion
                guard let completionTime = dateShiftPolicy.getShiftEndTime(shift, for: targetDate) else {
                    print("❌ ProductionBatchService: Could not get completion time for batch \(batch.batchNumber)")
                    continue
                }
                
                print("✅ ProductionBatchService: Auto-completing batch \(batch.batchNumber) with execution time \(executionTime) and completion time \(completionTime)")
                
                // Set the execution and completion times on the batch
                batch.setAutoCompleted(executionTime: executionTime, completionTime: completionTime)
                
                // Complete the batch automatically (skip normal execution)
                let success = await completeBatch(batch, isAutoCompletion: true)
                
                if success {
                    autoExecutedCount += 1
                    print("✅ ProductionBatchService: Successfully auto-completed batch \(batch.batchNumber)")
                } else {
                    print("❌ ProductionBatchService: Failed to auto-complete batch \(batch.batchNumber)")
                }
            } else {
                print("⏳ ProductionBatchService: Batch \(batch.batchNumber) is not yet overdue")
            }
        }
        
        if autoExecutedCount > 0 {
            await loadBatches()
        }
        
        return autoExecutedCount
    }
    
    /// Start periodic cleanup timer (runs every 30 minutes)
    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        // For development/testing: use shorter interval for faster testing
        // For production: use 30 * 60 (30 minutes)
        let interval: TimeInterval = 5 * 60 // 5 minutes for testing
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Run on MainActor to ensure thread safety with SwiftData
            Task { @MainActor [weak self] in
                print("⏰ ProductionBatchService: Running periodic cleanup and overdue batch check...")
                
                // Run operations sequentially on main thread to avoid SwiftData thread safety issues
                let cleanupCount = await self?.performCleanupOldBatches() ?? 0
                let autoCompletedCount = await self?.performCheckAndCompleteOverdueBatches() ?? 0
                
                print("📊 ProductionBatchService: Cleaned up \(cleanupCount) old batches, auto-completed \(autoCompletedCount) overdue batches")
                
                // Reload batches if any changes were made
                if cleanupCount > 0 || autoCompletedCount > 0 {
                    await self?.loadBatches()
                }
            }
        }
        print("⏱️ ProductionBatchService: Cleanup timer started (runs every \(Int(interval/60)) minutes)")
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
            
            // Batch status is already updated in applyBatchToMachine method
            // No need to update it again here
            
            // Audit log for execution
            try await auditService.logOperation(
                operationType: .productionConfigChange,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
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
    
    // MARK: - Color-only Modification Methods (仅颜色修改方法)
    
    /// Apply color modifications to a shift-aware batch
    /// 对班次批次应用颜色修改
    func applyColorModifications(_ modifications: [BatchColorModification], to batch: ProductionBatch) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to modify batch colors"
            return false
        }
        
        // Ensure this is a shift-aware batch
        guard batch.isShiftBatch else {
            errorMessage = "Color-only modifications only apply to shift-aware batches"
            return false
        }
        
        // Validate color modifications
        for modification in modifications {
            guard modification.hasChanges else { continue }
            
            // Validate colors exist
            do {
                let colors = try await colorRepository.fetchActiveColors()
                guard colors.contains(where: { $0.id == modification.currentColorId }) else {
                    errorMessage = "Current color not found: \(modification.currentColorId)"
                    return false
                }
                guard colors.contains(where: { $0.id == modification.proposedColorId }) else {
                    errorMessage = "Proposed color not found: \(modification.proposedColorId)"
                    return false
                }
            } catch {
                errorMessage = "Failed to validate colors: \(error.localizedDescription)"
                return false
            }
        }
        
        // Apply modifications (this would typically update machine configurations)
        do {
            // Save color modifications to batch metadata or separate tracking
            let modificationsData = try JSONEncoder().encode(modifications)
            batch.afterConfigSnapshot = modificationsData.base64EncodedString()
            batch.updatedAt = Date()
            
            try await productionBatchRepository.updateBatch(batch)
            
            // Audit log for color modifications
            try await auditService.logOperation(
                operationType: .batchUpdate,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Color modifications for \(batch.batchNumber)",
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "action": "apply_color_modifications",
                    "batch_number": batch.batchNumber,
                    "modification_count": modifications.filter { $0.hasChanges }.count,
                    "shift": batch.shift?.rawValue ?? "none",
                    "target_date": batch.targetDate?.description ?? "none"
                ]
            )
            
            return true
            
        } catch {
            errorMessage = "Failed to apply color modifications: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Validate that only color fields are being modified
    /// 验证仅修改颜色字段
    func validateColorOnlyModification(
        originalProduct: ProductConfig,
        modifiedProduct: ProductConfig
    ) -> Bool {
        // Check that only color fields are different
        return originalProduct.productName == modifiedProduct.productName &&
               originalProduct.occupiedStations == modifiedProduct.occupiedStations &&
               originalProduct.stationCount == modifiedProduct.stationCount &&
               originalProduct.gunAssignment == modifiedProduct.gunAssignment
    }
    
    /// Create color modification from existing product configuration
    /// 从现有产品配置创建颜色修改
    func createColorModification(
        from product: ProductConfig,
        newPrimaryColorId: String,
        newSecondaryColorId: String? = nil,
        shift: Shift
    ) -> BatchColorModification? {
        guard let currentUser = authService.currentUser else { return nil }
        
        // Use primary color as the main modification
        return BatchColorModification(
            machineId: product.batchId, // Using batchId as machine reference
            workstationId: product.stationRange,
            currentColorId: product.primaryColorId,
            proposedColorId: newPrimaryColorId,
            shift: shift,
            modifiedBy: currentUser.id,
            modifiedByName: currentUser.name
        )
    }
    
    // combineDateTime function replaced with DateTimeUtilities.combineDateTime
    
    // MARK: - Batch Completion Methods
    
    /// Complete a batch and clear machine status
    /// 完成批次并清除机器状态
    func completeBatch(_ batch: ProductionBatch, isAutoCompletion: Bool = false) async -> Bool {
        // For auto-completion, skip permission checks (system operation)
        if !isAutoCompletion {
            guard let currentUser = authService.currentUser,
                  currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
                errorMessage = "Insufficient permissions to complete batches"
                return false
            }
        }
        
        // For auto-completion, allow pendingExecution status; for manual, require active status
        if isAutoCompletion {
            guard batch.status == .pendingExecution else {
                errorMessage = "Auto-completion only applies to pending execution batches"
                return false
            }
        } else {
            guard batch.status == .active else {
                errorMessage = "Only active batches can be completed"
                return false
            }
        }
        
        do {
            let oldStatus = batch.status.rawValue
            
            if isAutoCompletion {
                // For auto-completion, we need execution time from shift policy
                // This will be set by the caller with the appropriate shift start time
                batch.status = .completed
                batch.completedAt = Date()
                batch.updatedAt = Date()
            } else {
                // For manual completion
                batch.status = .completed
                batch.completedAt = Date()
                batch.updatedAt = Date()
            }
            
            // For auto-completion of pending batches, skip machine binding operations
            // since the batch was never actually running on a machine
            if !isAutoCompletion {
                // Only clear machine binding for manual completion of active batches
                let machines = try await machineRepository.fetchAllMachines()
                if let machine = machines.first(where: { $0.id == batch.machineId }) {
                    await clearMachineBatchBinding(machine, batch: batch)
                }
            }
            
            // Save batch changes
            try await productionBatchRepository.updateBatch(batch)
            
            // Prepare audit log data
            let currentUser = authService.currentUser
            let operatorUserId = isAutoCompletion ? "system" : currentUser?.id ?? "unknown"
            let operatorUserName = isAutoCompletion ? "系统自动完成" : currentUser?.name ?? "Unknown"
            let action = isAutoCompletion ? "auto_complete_overdue_batch" : "complete_batch"
            let completedBy = isAutoCompletion ? "系统自动完成" : currentUser?.name ?? "Unknown"
            
            // Audit log
            try await auditService.logOperation(
                operationType: .statusChange,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)\(isAutoCompletion ? " (自动完成)" : "")",
                operatorUserId: operatorUserId,
                operatorUserName: operatorUserName,
                operationDetails: [
                    "action": action,
                    "batchNumber": batch.batchNumber,
                    "machineId": batch.machineId,
                    "completedBy": completedBy,
                    "oldStatus": oldStatus,
                    "newStatus": "completed",
                    "isAutoCompletion": isAutoCompletion
                ]
            )
            
            // Send batch completion notification
            await sendBatchCompletionNotification(batch: batch, isAutoCompletion: isAutoCompletion)
            
            return true
            
        } catch {
            errorMessage = "Failed to complete batch: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Clear machine batch binding when a batch is completed
    /// 批次完成时清除机器批次绑定
    private func clearMachineBatchBinding(_ machine: WorkshopMachine, batch: ProductionBatch) async {
        do {
            // Only clear if this machine is currently bound to this batch
            guard machine.currentBatchId == batch.id else { return }
            
            // Clear machine's batch reference
            machine.currentBatchId = nil
            machine.currentProductionMode = nil
            machine.lastConfigurationUpdate = Date()
            machine.status = .stopped // Set to stopped when no active batch
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
            
            print("Cleared machine \(machine.machineNumber) binding for completed batch \(batch.batchNumber)")
            
        } catch {
            print("Failed to clear machine batch binding: \(error)")
        }
    }
    
    /// Synchronize machine status with active batches
    /// 同步机器状态与活跃批次
    func synchronizeMachineStatuses() async -> Int {
        var syncCount = 0
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            let batches = try await productionBatchRepository.fetchAllBatches()
            let activeBatches = batches.filter { $0.status == .active }
            
            for machine in machines {
                var needsUpdate = false
                
                if let currentBatchId = machine.currentBatchId {
                    // Machine thinks it has an active batch - verify it exists and is active
                    let activeBatch = activeBatches.first { $0.id == currentBatchId }
                    
                    if activeBatch == nil {
                        // Machine references a batch that is no longer active - clear it
                        machine.currentBatchId = nil
                        machine.currentProductionMode = nil
                        machine.status = .stopped
                        machine.updatedAt = Date()
                        
                        // Reset stations
                        for station in machine.stations {
                            station.status = .idle
                            station.currentProductId = nil
                            station.updatedAt = Date()
                        }
                        
                        needsUpdate = true
                        print("Cleared stale batch reference from machine \(machine.machineNumber)")
                    }
                } else {
                    // Machine has no batch reference - check if there should be one
                    let machineActiveBatch = activeBatches.first { $0.machineId == machine.id }
                    
                    if let activeBatch = machineActiveBatch {
                        // There's an active batch for this machine but machine doesn't know about it
                        machine.currentBatchId = activeBatch.id
                        machine.currentProductionMode = activeBatch.mode
                        machine.status = .running
                        machine.lastConfigurationUpdate = Date()
                        machine.updatedAt = Date()
                        
                        // Update stations based on batch
                        for station in machine.stations {
                            let isOccupied = activeBatch.products.contains { product in
                                product.occupiedStations.contains(station.stationNumber)
                            }
                            station.status = isOccupied ? .running : .idle
                            station.updatedAt = Date()
                        }
                        
                        needsUpdate = true
                        print("Synchronized machine \(machine.machineNumber) with active batch \(activeBatch.batchNumber)")
                    }
                }
                
                if needsUpdate {
                    try await machineRepository.updateMachine(machine)
                    for station in machine.stations {
                        try await machineRepository.updateStation(station)
                    }
                    syncCount += 1
                }
            }
            
        } catch {
            print("Failed to synchronize machine statuses: \(error)")
        }
        
        return syncCount
    }
    
    /// Synchronize machine status when a batch is executed
    /// 批次执行时同步机器状态
    private func syncMachineWithBatchExecution(_ batch: ProductionBatch) async {
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == batch.machineId }) else {
                print("Warning: Machine not found for batch \(batch.batchNumber)")
                return
            }
            
            // Update machine with batch information
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
            
            // Update machine utilization rate
            let totalStations = machine.stations.count
            let runningStations = machine.stations.filter { $0.status == .running }.count
            machine.utilizationRate = totalStations > 0 ? Double(runningStations) / Double(totalStations) * 100.0 : 0.0
            
            // Save machine and station changes
            try await machineRepository.updateMachine(machine)
            for station in machine.stations {
                try await machineRepository.updateStation(station)
            }
            
            print("Successfully synchronized machine \(machine.machineNumber) with executed batch \(batch.batchNumber)")
            
        } catch {
            print("Failed to synchronize machine with batch execution: \(error)")
            errorMessage = "Failed to update machine status during batch execution: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Batch-Machine Validation Methods (批次-机器验证方法)
    
    /// Validate that a machine can accept a new batch
    /// 验证机器是否可以接受新批次
    func validateMachineCanAcceptBatch(_ machineId: String, proposedBatch: ProductionBatch) async -> (canAccept: Bool, reason: String?) {
        do {
            let machines = try await machineRepository.fetchAllMachines()
            guard let machine = machines.first(where: { $0.id == machineId }) else {
                return (false, "Machine not found")
            }
            
            // Check if machine is active and operational
            guard machine.isActive else {
                return (false, "Machine is disabled")
            }
            
            guard machine.status != .maintenance && machine.status != .error else {
                return (false, "Machine is in \(machine.status.displayName) status")
            }
            
            // Check if machine already has an active batch
            if machine.hasActiveProductionBatch {
                return (false, "Machine already has an active batch (\(machine.currentBatchDisplayName))")
            }
            
            // Check if machine has enough stations for the proposed batch
            let requiredStations = proposedBatch.totalStationsUsed
            let availableStations = machine.availableStations.count
            
            guard requiredStations <= availableStations else {
                return (false, "Insufficient stations: need \(requiredStations), available \(availableStations)")
            }
            
            // Check if proposed stations are actually available on this machine
            let allMachineStations = Set(machine.stations.map { $0.stationNumber })
            let proposedStations = Set(proposedBatch.products.flatMap { $0.occupiedStations })
            
            guard proposedStations.isSubset(of: allMachineStations) else {
                let invalidStations = proposedStations.subtracting(allMachineStations)
                return (false, "Invalid stations for this machine: \(invalidStations.sorted())")
            }
            
            return (true, nil)
            
        } catch {
            return (false, "Validation error: \(error.localizedDescription)")
        }
    }
    
    /// Validate batch-machine consistency across the system
    /// 验证系统中批次-机器的一致性
    func validateSystemConsistency() async -> [MachineValidationIssue] {
        var issues: [MachineValidationIssue] = []
        
        do {
            let machines = try await machineRepository.fetchAllMachines()
            let batches = try await productionBatchRepository.fetchAllBatches()
            let activeBatches = batches.filter { $0.status == .active }
            
            // Check each machine for consistency
            for machine in machines {
                if let currentBatchId = machine.currentBatchId {
                    // Machine has batch reference - verify it exists and is active
                    if let activeBatch = activeBatches.first(where: { $0.id == currentBatchId }) {
                        // Validate batch-machine relationship
                        if activeBatch.machineId != machine.id {
                            issues.append(MachineValidationIssue(
                                type: .batchMachineMismatch,
                                machineId: machine.id,
                                batchId: activeBatch.id,
                                description: "Machine \(machine.machineNumber) references batch \(activeBatch.batchNumber) but batch is assigned to different machine"
                            ))
                        }
                        
                        // Validate station consistency
                        let batchStations = Set(activeBatch.products.flatMap { $0.occupiedStations })
                        let runningStations = Set(machine.stations.filter { $0.status == .running }.map { $0.stationNumber })
                        
                        if batchStations != runningStations {
                            issues.append(MachineValidationIssue(
                                type: .stationInconsistency,
                                machineId: machine.id,
                                batchId: activeBatch.id,
                                description: "Station status mismatch: batch expects \(batchStations.sorted()), machine running \(runningStations.sorted())"
                            ))
                        }
                    } else {
                        // Machine references non-existent or non-active batch
                        issues.append(MachineValidationIssue(
                            type: .staleBatchReference,
                            machineId: machine.id,
                            batchId: currentBatchId,
                            description: "Machine \(machine.machineNumber) references non-existent or inactive batch"
                        ))
                    }
                } else if machine.status == .running {
                    // Machine is running but has no batch reference
                    let machineActiveBatch = activeBatches.first { $0.machineId == machine.id }
                    if machineActiveBatch != nil {
                        issues.append(MachineValidationIssue(
                            type: .missingBatchReference,
                            machineId: machine.id,
                            batchId: machineActiveBatch?.id,
                            description: "Machine \(machine.machineNumber) is running but missing batch reference"
                        ))
                    } else {
                        issues.append(MachineValidationIssue(
                            type: .runningWithoutBatch,
                            machineId: machine.id,
                            batchId: nil,
                            description: "Machine \(machine.machineNumber) is running without any active batch"
                        ))
                    }
                }
            }
            
            // Check each active batch for machine consistency
            for batch in activeBatches {
                if let machine = machines.first(where: { $0.id == batch.machineId }) {
                    if machine.currentBatchId != batch.id {
                        issues.append(MachineValidationIssue(
                            type: .batchWithoutMachine,
                            machineId: machine.id,
                            batchId: batch.id,
                            description: "Active batch \(batch.batchNumber) not properly linked to machine \(machine.machineNumber)"
                        ))
                    }
                } else {
                    issues.append(MachineValidationIssue(
                        type: .batchOrphanedMachine,
                        machineId: batch.machineId,
                        batchId: batch.id,
                        description: "Active batch \(batch.batchNumber) references non-existent machine"
                    ))
                }
            }
            
        } catch {
            issues.append(MachineValidationIssue(
                type: .validationError,
                machineId: nil,
                batchId: nil,
                description: "System validation failed: \(error.localizedDescription)"
            ))
        }
        
        return issues
    }
    
    /// Fix identified validation issues
    /// 修复已识别的验证问题
    func fixMachineValidationIssues(_ issues: [MachineValidationIssue]) async -> Int {
        var fixedCount = 0
        
        for issue in issues {
            let success = await fixSingleMachineValidationIssue(issue)
            if success {
                fixedCount += 1
            }
        }
        
        return fixedCount
    }
    
    private func fixSingleMachineValidationIssue(_ issue: MachineValidationIssue) async -> Bool {
        do {
            switch issue.type {
            case .staleBatchReference:
                // Clear stale batch reference from machine
                if let machineId = issue.machineId {
                    let machines = try await machineRepository.fetchAllMachines()
                    if let machine = machines.first(where: { $0.id == machineId }) {
                        machine.currentBatchId = nil
                        machine.currentProductionMode = nil
                        machine.status = .stopped
                        machine.updatedAt = Date()
                        
                        // Reset stations
                        for station in machine.stations {
                            station.status = .idle
                            station.currentProductId = nil
                            station.updatedAt = Date()
                        }
                        
                        try await machineRepository.updateMachine(machine)
                        for station in machine.stations {
                            try await machineRepository.updateStation(station)
                        }
                        
                        print("Fixed: Cleared stale batch reference from machine \(machine.machineNumber)")
                        return true
                    }
                }
                
            case .missingBatchReference:
                // Set missing batch reference on machine
                if let machineId = issue.machineId, let batchId = issue.batchId {
                    let machines = try await machineRepository.fetchAllMachines()
                    let batches = try await productionBatchRepository.fetchAllBatches()
                    
                    if let machine = machines.first(where: { $0.id == machineId }),
                       let batch = batches.first(where: { $0.id == batchId && $0.status == .active }) {
                        
                        machine.currentBatchId = batch.id
                        machine.currentProductionMode = batch.mode
                        machine.status = .running
                        machine.lastConfigurationUpdate = Date()
                        machine.updatedAt = Date()
                        
                        // Update stations based on batch
                        for station in machine.stations {
                            let isOccupied = batch.products.contains { product in
                                product.occupiedStations.contains(station.stationNumber)
                            }
                            station.status = isOccupied ? .running : .idle
                            station.updatedAt = Date()
                        }
                        
                        try await machineRepository.updateMachine(machine)
                        for station in machine.stations {
                            try await machineRepository.updateStation(station)
                        }
                        
                        print("Fixed: Set missing batch reference on machine \(machine.machineNumber)")
                        return true
                    }
                }
                
            case .runningWithoutBatch:
                // Stop machine that's running without batch
                if let machineId = issue.machineId {
                    let machines = try await machineRepository.fetchAllMachines()
                    if let machine = machines.first(where: { $0.id == machineId }) {
                        machine.status = .stopped
                        machine.updatedAt = Date()
                        
                        for station in machine.stations {
                            station.status = .idle
                            station.currentProductId = nil
                            station.updatedAt = Date()
                        }
                        
                        try await machineRepository.updateMachine(machine)
                        for station in machine.stations {
                            try await machineRepository.updateStation(station)
                        }
                        
                        print("Fixed: Stopped machine \(machine.machineNumber) that was running without batch")
                        return true
                    }
                }
                
            default:
                print("Cannot auto-fix validation issue type: \(issue.type)")
                return false
            }
            
        } catch {
            print("Failed to fix validation issue: \(error)")
        }
        
        return false
    }
    
    // MARK: - Manual Testing Methods (手动测试方法)
    
    /// Manual test method for debugging auto-execution logic
    /// 手动测试自动执行逻辑的调试方法
    func testAutoExecutionLogic() async {
        print("🧪 ProductionBatchService: Running manual auto-execution test...")
        let cleanupCount = await cleanupOldBatches()
        let autoExecutedCount = await checkAndExecuteOverdueBatches()
        print("🧪 Test Results: Cleaned up \(cleanupCount) old batches, auto-executed \(autoExecutedCount) overdue batches")
    }
    
    // MARK: - Notification Integration (通知集成)
    
    /// Send batch completion notification
    /// 发送批次完成通知
    private func sendBatchCompletionNotification(batch: ProductionBatch, isAutoCompletion: Bool) async {
        guard let notificationEngine = notificationEngine else { return }
        
        do {
            // Get machine details for the notification
            let machines = try await machineRepository.fetchAllMachines()
            let machine = machines.first { $0.id == batch.machineId }
            let machineNumber = machine?.machineNumber.description ?? batch.machineId
            
            // Calculate duration
            let startTime = batch.executionTime ?? batch.submittedAt
            let endTime = batch.completedAt ?? Date()
            let duration = endTime.timeIntervalSince(startTime)
            let durationString = formatDuration(duration)
            
            // Send notification using template
            try await notificationEngine.sendNotification(
                templateId: "batch_completed",
                parameters: [
                    "batchNumber": batch.batchNumber,
                    "machineNumber": machineNumber,
                    "duration": durationString,
                    "completionType": isAutoCompletion ? "自动完成" : "手动完成"
                ],
                relatedEntityId: batch.id,
                relatedEntityType: "ProductionBatch"
            )
            
        } catch {
            print("Failed to send batch completion notification: \(error.localizedDescription)")
        }
    }
    
    /// Format duration for display
    /// 格式化持续时间用于显示
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - Validation Models (验证模型)

enum MachineValidationIssueType {
    case batchMachineMismatch
    case stationInconsistency
    case staleBatchReference
    case missingBatchReference
    case runningWithoutBatch
    case batchWithoutMachine
    case batchOrphanedMachine
    case validationError
}

struct MachineValidationIssue {
    let type: MachineValidationIssueType
    let machineId: String?
    let batchId: String?
    let description: String
}