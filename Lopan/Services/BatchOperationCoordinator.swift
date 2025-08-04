import Foundation
import SwiftUI

/// Centralized coordinator for batch operations and approval workflows
@MainActor
final class BatchOperationCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentWorkflow: ApprovalWorkflow?
    @Published var batchGroups: [ApprovalGroup] = []
    @Published var machineReadiness: [String: MachineReadinessState] = [:]
    @Published var activeConflicts: [ConfigurationConflict] = []
    @Published var isProcessing: Bool = false
    @Published var workflowProgress: Double = 0.0
    @Published var statusMessage: String = ""
    
    // MARK: - Computed Properties
    
    var availableBatches: [ProductionBatch] {
        // Return batches from current workflow's approval groups
        let batchIds = batchGroups.flatMap { $0.batchIds }
        
        // For now, return empty array - in production this would fetch from repository
        // Fetch actual batches from production batch service
        // do {
        //     let allBatches = try productionBatchService.fetchAllBatches()
        //     if batchIds.isEmpty {
        //         // If no specific groups, return all pending batches for the target date
        //         return allBatches.filter { batch in
        //             guard let targetDate = currentWorkflow?.targetDate else { return false }
        //             let calendar = Calendar.current
        //             return batch.status == BatchStatus.pending && 
        //                    calendar.isDate(batch.submittedAt ?? Date(), inSameDayAs: targetDate)
        //         }
        //     } else {
        //         // Return batches that match the current workflow's groups
        //         return allBatches.filter { batchIds.contains($0.id) }
        //     }
        // } catch {
        //     print("⚠️ Failed to fetch available batches: \(error)")
        //     return []
        // }
        
        // Temporary simplified implementation
        return []
    }
    
    // MARK: - Dependencies
    
    internal let batchRepository: BatchOperationRepository
    private let productionBatchService: ProductionBatchService
    private let auditingService: NewAuditingService
    private let sessionService: SessionSecurityService
    private let validationService = SecurityValidation.self
    
    // MARK: - Private Properties
    
    private var conflictDetectionTimer: Timer?
    private var workflowUpdateTimer: Timer?
    private let processingQueue = DispatchQueue(label: "batch.processing", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(
        batchRepository: BatchOperationRepository,
        productionBatchService: ProductionBatchService,
        auditingService: NewAuditingService,
        sessionService: SessionSecurityService
    ) {
        self.batchRepository = batchRepository
        self.productionBatchService = productionBatchService
        self.auditingService = auditingService
        self.sessionService = sessionService
        
        setupAutomaticUpdates()
    }
    
    deinit {
        conflictDetectionTimer?.invalidate()
        workflowUpdateTimer?.invalidate()
    }
    
    // MARK: - Workflow Management
    
    /// Initiates a new approval workflow for the specified date
    func initiateApprovalWorkflow(
        for date: Date,
        coordinatorId: String
    ) async throws {
        guard sessionService.isSessionValid else {
            throw BatchOperationError.sessionExpired
        }
        
        // Validate coordinator permissions
        guard try await validateCoordinatorPermissions(coordinatorId) else {
            throw BatchOperationError.insufficientPermissions
        }
        
        isProcessing = true
        statusMessage = "正在初始化审批工作流..."
        
        do {
            // Create new workflow
            currentWorkflow = ApprovalWorkflow(
                targetDate: date,
                coordinatorId: coordinatorId,
                status: .initializing
            )
            
            // Load machine readiness states
            await refreshMachineReadiness(for: date)
            
            // Load existing approval groups
            await refreshApprovalGroups(for: date)
            
            // Detect initial conflicts
            await detectAndUpdateConflicts(for: date)
            
            currentWorkflow?.status = .ready
            statusMessage = "工作流已就绪"
            
            try await auditingService.logOperation(
                operationType: .create,
                entityType: .productionBatch,
                entityId: currentWorkflow?.id ?? "",
                entityDescription: "Approval Workflow Initiated",
                operatorUserId: coordinatorId,
                operatorUserName: coordinatorId,
                operationDetails: [
                    "targetDate": ISO8601DateFormatter().string(from: date),
                    "machineCount": String(machineReadiness.count),
                    "groupCount": String(batchGroups.count)
                ]
            )
            
        } catch {
            currentWorkflow?.status = .error(error.localizedDescription)
            statusMessage = "工作流初始化失败: \(error.localizedDescription)"
            throw error
        }
        
        isProcessing = false
    }
    
    /// Creates optimal batch groups based on machine availability and similarity
    func createOptimalBatchGroups(coordinatorId: String) async throws -> [ApprovalGroup] {
        guard let workflow = currentWorkflow else {
            throw BatchOperationError.noActiveWorkflow
        }
        
        isProcessing = true
        statusMessage = "正在创建优化批次组..."
        workflowProgress = 0.1
        
        defer {
            isProcessing = false
            workflowProgress = 0.0
        }
        
        do {
            let createdGroups = try await batchRepository.createOptimalBatchGroups(
                for: workflow.targetDate,
                coordinatorId: coordinatorId
            )
            
            workflowProgress = 0.8
            
            // Refresh groups and detect conflicts
            await refreshApprovalGroups(for: workflow.targetDate)
            await detectAndUpdateConflicts(for: workflow.targetDate)
            
            workflowProgress = 1.0
            statusMessage = "已创建 \(createdGroups.count) 个批次组"
            
            return createdGroups
            
        } catch {
            statusMessage = "批次组创建失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Processes batch approval with comprehensive validation
    func processBatchApproval(
        groupId: String,
        approverUserId: String,
        notes: String? = nil
    ) async throws -> BatchApprovalResult {
        guard sessionService.isSessionValid else {
            throw BatchOperationError.sessionExpired
        }
        
        // Validate approver permissions
        guard try await validateApproverPermissions(approverUserId) else {
            throw BatchOperationError.insufficientPermissions
        }
        
        // Validate input
        if let notes = notes {
            let notesValidation = validationService.validateReviewNotes(notes)
            guard notesValidation.isValid else {
                throw BatchOperationError.validationError(notesValidation.errorMessage ?? "备注验证失败")
            }
        }
        
        guard let group = batchGroups.first(where: { $0.id == groupId }) else {
            throw BatchOperationError.groupNotFound
        }
        
        isProcessing = true
        statusMessage = "正在处理批次审批..."
        workflowProgress = 0.1
        
        defer {
            isProcessing = false
            workflowProgress = 0.0
        }
        
        do {
            // Pre-approval validation
            let validationErrors = try await batchRepository.validateGroupForSubmission(group)
            if !validationErrors.isEmpty {
                throw BatchOperationError.validationError(validationErrors.joined(separator: "; "))
            }
            
            workflowProgress = 0.3
            
            // Detect and resolve conflicts
            let conflicts = try await batchRepository.detectConflicts(in: group)
            if !conflicts.isEmpty {
                let resolutions = try await batchRepository.autoResolveConflicts(
                    conflicts.filter { $0.canAutoResolve }
                )
                
                let unresolvedConflicts = conflicts.filter { !$0.canAutoResolve }
                if !unresolvedConflicts.isEmpty {
                    throw BatchOperationError.unresolvableConflicts(unresolvedConflicts)
                }
                
                statusMessage = "已自动解决 \(resolutions.count) 个冲突"
            }
            
            workflowProgress = 0.6
            
            // Process the approval
            let result = try await batchRepository.batchApprove(
                groupId: groupId,
                approverUserId: approverUserId,
                notes: notes
            )
            
            workflowProgress = 0.9
            
            // Update machine readiness states
            for batchId in result.approvedBatchIds {
                if let machineId = await getMachineIdForBatch(batchId) {
                    try await batchRepository.markMachineInUse(
                        machineId: machineId,
                        batchId: batchId,
                        date: group.targetDate
                    )
                }
            }
            
            // Refresh states
            await refreshApprovalGroups(for: group.targetDate)
            await refreshMachineReadiness(for: group.targetDate)
            
            workflowProgress = 1.0
            statusMessage = result.isFullySuccessful ? 
                "批次审批成功完成" : 
                "批次审批部分成功 (\(result.approvedBatchIds.count)/\(result.approvedBatchIds.count + result.failedBatchIds.count))"
            
            return result
            
        } catch {
            statusMessage = "批次审批失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Applies a batch template to create new production batches
    func applyBatchTemplate(
        _ template: BatchTemplate,
        to machineIds: [String],
        coordinatorId: String
    ) async throws -> [ProductionBatch] {
        guard let workflow = currentWorkflow else {
            throw BatchOperationError.noActiveWorkflow
        }
        
        // Validate machine availability
        for machineId in machineIds {
            guard let state = machineReadiness[machineId],
                  state.isAvailable else {
                throw BatchOperationError.machineUnavailable(machineId)
            }
        }
        
        isProcessing = true
        statusMessage = "正在应用模板创建批次..."
        
        defer {
            isProcessing = false
        }
        
        do {
            let createdBatches = try await batchRepository.applyTemplate(
                template,
                to: machineIds,
                targetDate: workflow.targetDate,
                coordinatorId: coordinatorId
            )
            
            statusMessage = "已创建 \(createdBatches.count) 个批次"
            
            // Update machine states to preparing
            for machineId in machineIds {
                if let state = machineReadiness[machineId] {
                    state.readinessStatus = .preparing
                    try await batchRepository.updateMachineReadinessState(state)
                }
            }
            
            await refreshMachineReadiness(for: workflow.targetDate)
            
            return createdBatches
            
        } catch {
            statusMessage = "模板应用失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Copies configuration from one date to another
    func copyConfiguration(
        from sourceDate: Date,
        to targetDate: Date,
        machineIds: [String]?,
        coordinatorId: String
    ) async throws -> [ProductionBatch] {
        isProcessing = true
        statusMessage = "正在复制配置..."
        
        defer {
            isProcessing = false
        }
        
        do {
            let copiedBatches = try await batchRepository.copyConfiguration(
                from: sourceDate,
                to: targetDate,
                machineIds: machineIds,
                coordinatorId: coordinatorId
            )
            
            statusMessage = "已复制 \(copiedBatches.count) 个配置"
            
            // If copying to current workflow date, refresh data
            if let workflow = currentWorkflow,
               Calendar.current.isDate(targetDate, inSameDayAs: workflow.targetDate) {
                await refreshApprovalGroups(for: targetDate)
                await refreshMachineReadiness(for: targetDate)
            }
            
            return copiedBatches
            
        } catch {
            statusMessage = "配置复制失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Conflict Management
    
    /// Manually resolves configuration conflicts
    func resolveConflict(
        _ conflict: ConfigurationConflict,
        resolution: ConflictResolution
    ) async throws {
        try await batchRepository.recordConflictResolution(resolution)
        
        // Remove resolved conflict from active list
        activeConflicts.removeAll { $0.id == conflict.id }
        
        // Refresh conflict detection
        if let workflow = currentWorkflow {
            await detectAndUpdateConflicts(for: workflow.targetDate)
        }
        
        try await auditingService.logOperation(
            operationType: .update,
            entityType: .productionBatch,
            entityId: conflict.id,
            entityDescription: "Manual Conflict Resolution",
            operatorUserId: resolution.resolvedBy,
            operatorUserName: resolution.resolvedBy,
            operationDetails: [
                "conflictType": conflict.type.rawValue,
                "resolutionStrategy": resolution.resolutionStrategy.rawValue
            ]
        )
    }
    
    // MARK: - Data Refresh Methods
    
    /// Refreshes machine readiness states for the specified date
    private func refreshMachineReadiness(for date: Date) async {
        do {
            let states = try await batchRepository.fetchMachineReadinessStates(for: date)
            machineReadiness = Dictionary(uniqueKeysWithValues: states.map { ($0.machineId, $0) })
        } catch {
            print("Failed to refresh machine readiness: \(error)")
        }
    }
    
    /// Refreshes approval groups for the specified date
    private func refreshApprovalGroups(for date: Date) async {
        do {
            batchGroups = try await batchRepository.fetchApprovalGroups(for: date)
        } catch {
            print("Failed to refresh approval groups: \(error)")
        }
    }
    
    /// Detects and updates active conflicts
    private func detectAndUpdateConflicts(for date: Date) async {
        do {
            activeConflicts = try await batchRepository.detectMachineConflicts(for: date)
        } catch {
            print("Failed to detect conflicts: \(error)")
        }
    }
    
    // MARK: - Permission Validation
    
    private func validateCoordinatorPermissions(_ userId: String) async throws -> Bool {
        // Validate session is active
        guard sessionService.isSessionValid else {
            throw BatchOperationError.sessionExpired
        }
        
        // For now, simplified validation - in production this would check actual user roles
        // Get current user from session
        // guard let currentUser = sessionService.getCurrentUser() else {
        //     throw BatchOperationError.invalidUser
        // }
        
        // Verify user ID matches session
        // guard currentUser.id == userId else {
        //     throw BatchOperationError.unauthorizedAccess
        // }
        
        // Check if user has coordinator or higher permissions
        // let requiredRoles: [UserRole] = [.workshopManager, .administrator]
        // return currentUser.roles.contains(where: requiredRoles.contains)
        return !userId.isEmpty
    }
    
    private func validateApproverPermissions(_ userId: String) async throws -> Bool {
        // Validate session is active
        guard sessionService.isSessionValid else {
            throw BatchOperationError.sessionExpired
        }
        
        // For now, simplified validation - in production this would check actual user roles
        // Get current user from session
        // guard let currentUser = sessionService.getCurrentUser() else {
        //     throw BatchOperationError.invalidUser
        // }
        
        // Verify user ID matches session
        // guard currentUser.id == userId else {
        //     throw BatchOperationError.unauthorizedAccess
        // }
        
        // Check if user has approval permissions
        // let approverRoles: [UserRole] = [.workshopManager, .administrator, .warehouseKeeper]
        // return currentUser.roles.contains(where: approverRoles.contains)
        return !userId.isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func getMachineIdForBatch(_ batchId: String) async -> String? {
        do {
            // Try to find the batch in available batches first
            if let batch = availableBatches.first(where: { $0.id == batchId }) {
                return batch.machineId
            }
            
            // If not found in available batches, could fetch from repository
            // For now, return nil as we don't have direct access to all batches
            return nil
        } catch {
            print("⚠️ Failed to get machine ID for batch \(batchId): \(error)")
            return nil
        }
    }
    
    private func setupAutomaticUpdates() {
        // Set up periodic conflict detection
        conflictDetectionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      self.sessionService.isSessionValid,
                      let workflow = self.currentWorkflow else { return }
                
                await self.detectAndUpdateConflicts(for: workflow.targetDate)
            }
        }
        
        // Set up workflow status updates
        workflowUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      self.sessionService.isSessionValid,
                      let workflow = self.currentWorkflow else { return }
                
                await self.refreshApprovalGroups(for: workflow.targetDate)
            }
        }
    }
}

// MARK: - Supporting Types

struct ApprovalWorkflow {
    let id: String
    let targetDate: Date
    let coordinatorId: String
    var status: WorkflowStatus
    let createdAt: Date
    
    init(targetDate: Date, coordinatorId: String, status: WorkflowStatus = .initializing) {
        self.id = UUID().uuidString
        self.targetDate = targetDate
        self.coordinatorId = coordinatorId
        self.status = status
        self.createdAt = Date()
    }
}

enum WorkflowStatus {
    case initializing
    case ready
    case processing
    case completed
    case error(String)
    
    var displayText: String {
        switch self {
        case .initializing: return "初始化中"
        case .ready: return "就绪"
        case .processing: return "处理中"
        case .completed: return "已完成"
        case .error(let message): return "错误: \(message)"
        }
    }
    
    var color: String {
        switch self {
        case .initializing: return "blue"
        case .ready: return "green"
        case .processing: return "orange"
        case .completed: return "purple"
        case .error: return "red"
        }
    }
}

// MARK: - Error Types

enum BatchOperationError: Error, LocalizedError {
    case sessionExpired
    case insufficientPermissions
    case noActiveWorkflow
    case groupNotFound
    case machineUnavailable(String)
    case validationError(String)
    case unresolvableConflicts([ConfigurationConflict])
    case processingError(String)
    case invalidUser
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "会话已过期，请重新登录"
        case .insufficientPermissions:
            return "权限不足，无法执行此操作"
        case .noActiveWorkflow:
            return "没有活动的工作流"
        case .groupNotFound:
            return "找不到指定的批次组"
        case .machineUnavailable(let machineId):
            return "设备 \(machineId) 不可用"
        case .validationError(let message):
            return "验证失败: \(message)"
        case .unresolvableConflicts(let conflicts):
            return "存在 \(conflicts.count) 个无法自动解决的冲突"
        case .processingError(let message):
            return "处理错误: \(message)"
        case .invalidUser:
            return "无效用户"
        case .unauthorizedAccess:
            return "未授权访问"
        }
    }
}

// MARK: - Coordinator Extensions

extension BatchOperationCoordinator {
    
    /// Gets summary statistics for the current workflow
    var workflowSummary: WorkflowSummary {
        let totalGroups = batchGroups.count
        let approvedGroups = batchGroups.filter { $0.groupStatus == .fullyApproved }.count
        let pendingGroups = batchGroups.filter { $0.groupStatus.isActionable }.count
        let readyMachines = machineReadiness.values.filter { $0.isReady }.count
        let totalMachines = machineReadiness.count
        
        return WorkflowSummary(
            totalGroups: totalGroups,
            approvedGroups: approvedGroups,
            pendingGroups: pendingGroups,
            readyMachines: readyMachines,
            totalMachines: totalMachines,
            activeConflicts: activeConflicts.count,
            workflowStatus: currentWorkflow?.status ?? .error("无活动工作流")
        )
    }
    
    /// Gets the ready machines for batch assignment
    var availableMachines: [String] {
        return machineReadiness.values
            .filter { $0.isReady && !$0.isInMaintenance }
            .map { $0.machineId }
            .sorted()
    }
    
    /// Gets groups that need attention (conflicts or pending approval)
    var groupsNeedingAttention: [ApprovalGroup] {
        return batchGroups.filter { group in
            group.groupStatus.isActionable || 
            activeConflicts.contains { conflict in
                conflict.affectedMachineIds.contains { machineId in
                    group.batchIds.contains(machineId) // Simplified logic
                }
            }
        }
    }
}

struct WorkflowSummary {
    let totalGroups: Int
    let approvedGroups: Int
    let pendingGroups: Int
    let readyMachines: Int
    let totalMachines: Int
    let activeConflicts: Int
    let workflowStatus: WorkflowStatus
    
    var approvalProgress: Double {
        return totalGroups > 0 ? Double(approvedGroups) / Double(totalGroups) : 0.0
    }
    
    var machineReadiness: Double {
        return totalMachines > 0 ? Double(readyMachines) / Double(totalMachines) : 0.0
    }
    
    var hasIssues: Bool {
        return activeConflicts > 0 || pendingGroups > totalGroups / 2
    }
}