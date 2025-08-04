import Foundation

/// Repository protocol for batch operation data access
protocol BatchOperationRepository {
    
    // MARK: - Batch Template Operations
    
    /// Fetches all available batch templates
    func fetchBatchTemplates() async throws -> [BatchTemplate]
    
    /// Fetches batch templates filtered by criteria
    func fetchBatchTemplates(
        applicableToMachine machineId: String?,
        priority: TemplatePriority?,
        isActive: Bool?
    ) async throws -> [BatchTemplate]
    
    /// Creates a new batch template
    func createBatchTemplate(_ template: BatchTemplate) async throws
    
    /// Updates an existing batch template
    func updateBatchTemplate(_ template: BatchTemplate) async throws
    
    /// Deletes a batch template (soft delete by setting isActive = false)
    func deleteBatchTemplate(id: String) async throws
    
    /// Applies a template to create batches for specific machines
    func applyTemplate(
        _ template: BatchTemplate,
        to machineIds: [String],
        targetDate: Date,
        coordinatorId: String
    ) async throws -> [ProductionBatch]
    
    // MARK: - Approval Group Operations
    
    /// Fetches approval groups for a specific date
    func fetchApprovalGroups(for date: Date) async throws -> [ApprovalGroup]
    
    /// Fetches approval groups by status
    func fetchApprovalGroups(status: GroupApprovalStatus) async throws -> [ApprovalGroup]
    
    /// Fetches approval groups assigned to a coordinator
    func fetchApprovalGroups(coordinatorId: String) async throws -> [ApprovalGroup]
    
    /// Creates a new approval group
    func createApprovalGroup(_ group: ApprovalGroup) async throws
    
    /// Updates an approval group
    func updateApprovalGroup(_ group: ApprovalGroup) async throws
    
    /// Adds batches to an approval group
    func addBatches(batchIds: [String], to groupId: String) async throws
    
    /// Removes batches from an approval group
    func removeBatches(batchIds: [String], from groupId: String) async throws
    
    /// Groups related batches automatically based on criteria
    func createOptimalBatchGroups(
        for date: Date,
        coordinatorId: String
    ) async throws -> [ApprovalGroup]
    
    // MARK: - Machine Readiness Operations
    
    /// Fetches machine readiness states for a specific date
    func fetchMachineReadinessStates(for date: Date) async throws -> [MachineReadinessState]
    
    /// Fetches readiness state for a specific machine and date
    func fetchMachineReadinessState(
        machineId: String,
        date: Date
    ) async throws -> MachineReadinessState?
    
    /// Updates machine readiness state
    func updateMachineReadinessState(_ state: MachineReadinessState) async throws
    
    /// Marks machine as ready for production
    func markMachineAsReady(
        machineId: String,
        date: Date,
        updatedBy: String
    ) async throws
    
    /// Marks machine as in use with batch assignment
    func markMachineInUse(
        machineId: String,
        batchId: String,
        date: Date
    ) async throws
    
    // MARK: - Conflict Detection and Resolution
    
    /// Detects conflicts for machines on a specific date
    func detectMachineConflicts(for date: Date) async throws -> [ConfigurationConflict]
    
    /// Detects conflicts within an approval group
    func detectConflicts(in group: ApprovalGroup) async throws -> [ConfigurationConflict]
    
    /// Validates batch compatibility for grouping
    func validateBatchCompatibility(batchIds: [String]) async throws -> [ConfigurationConflict]
    
    /// Resolves conflicts automatically where possible
    func autoResolveConflicts(_ conflicts: [ConfigurationConflict]) async throws -> [ConflictResolution]
    
    /// Records manual conflict resolution
    func recordConflictResolution(_ resolution: ConflictResolution) async throws
    
    // MARK: - Batch Operations
    
    /// Validates no duplicate approvals exist for machines/date
    func validateNoDuplicateApprovals(
        machineIds: [String],
        date: Date
    ) async throws -> [String] // Returns machine IDs with existing approvals
    
    /// Performs bulk batch approval
    func batchApprove(
        groupId: String,
        approverUserId: String,
        notes: String?
    ) async throws -> BatchApprovalResult
    
    /// Copies configuration from one date to another
    func copyConfiguration(
        from sourceDate: Date,
        to targetDate: Date,
        machineIds: [String]?,
        coordinatorId: String
    ) async throws -> [ProductionBatch]
    
    /// Fetches approval history for analysis
    func fetchApprovalHistory(
        machineId: String?,
        dateRange: DateInterval,
        coordinatorId: String?
    ) async throws -> [ApprovalGroup]
    
    // MARK: - Analytics and Reporting
    
    /// Fetches approval metrics for dashboard
    func fetchApprovalMetrics(
        dateRange: DateInterval,
        coordinatorId: String?
    ) async throws -> ApprovalMetrics
    
    /// Fetches machine utilization statistics
    func fetchMachineUtilization(
        dateRange: DateInterval,
        machineIds: [String]?
    ) async throws -> [MachineUtilizationMetric]
    
    /// Fetches template usage statistics
    func fetchTemplateUsageStatistics() async throws -> [TemplateUsageMetric]
}

// MARK: - Supporting Types

struct BatchApprovalResult {
    let groupId: String
    let approvedBatchIds: [String]
    let failedBatchIds: [String]
    let warnings: [String]
    let processedAt: Date
    let totalProcessingTime: TimeInterval
    
    var isFullySuccessful: Bool {
        return failedBatchIds.isEmpty
    }
    
    var successRate: Double {
        let total = approvedBatchIds.count + failedBatchIds.count
        return total > 0 ? Double(approvedBatchIds.count) / Double(total) : 0.0
    }
}

struct ApprovalMetrics {
    let dateRange: DateInterval
    let totalGroups: Int
    let approvedGroups: Int
    let rejectedGroups: Int
    let pendingGroups: Int
    let averageApprovalTime: TimeInterval
    let conflictResolutionRate: Double
    let machineUtilizationRate: Double
    let topConflictTypes: [ConflictType]
    
    var approvalRate: Double {
        return totalGroups > 0 ? Double(approvedGroups) / Double(totalGroups) : 0.0
    }
    
    var rejectionRate: Double {
        return totalGroups > 0 ? Double(rejectedGroups) / Double(totalGroups) : 0.0
    }
}

struct MachineUtilizationMetric {
    let machineId: String
    let dateRange: DateInterval
    let totalAvailableTime: TimeInterval
    let actualUsageTime: TimeInterval
    let maintenanceTime: TimeInterval
    let idleTime: TimeInterval
    let batchCount: Int
    let averageBatchDuration: TimeInterval
    
    var utilizationRate: Double {
        return totalAvailableTime > 0 ? actualUsageTime / totalAvailableTime : 0.0
    }
    
    var maintenanceRatio: Double {
        return totalAvailableTime > 0 ? maintenanceTime / totalAvailableTime : 0.0
    }
    
    var efficiency: String {
        switch utilizationRate {
        case 0.8...1.0: return "优秀"
        case 0.6..<0.8: return "良好"
        case 0.4..<0.6: return "一般"
        case 0.2..<0.4: return "较差"
        default: return "很差"
        }
    }
}

struct TemplateUsageMetric {
    let templateId: String
    let templateName: String
    let usageCount: Int
    let successRate: Double
    let averageProcessingTime: TimeInterval
    let lastUsedDate: Date?
    let popularMachines: [String] // Machine IDs where this template is most used
    
    var usageFrequency: String {
        switch usageCount {
        case 50...: return "很高"
        case 20..<50: return "高"
        case 10..<20: return "中等"
        case 5..<10: return "低"
        default: return "很低"
        }
    }
}

// MARK: - Repository Extensions for Complex Queries

extension BatchOperationRepository {
    
    /// Fetches ready machines for immediate batch assignment
    func fetchReadyMachines(for date: Date) async throws -> [String] {
        let states = try await fetchMachineReadinessStates(for: date)
        return states
            .filter { $0.isReady && !$0.isInMaintenance }
            .map { $0.machineId }
    }
    
    /// Finds optimal template for given machines and requirements
    func findOptimalTemplate(
        for machineIds: [String],
        priority: TemplatePriority?,
        productIds: [String]?
    ) async throws -> BatchTemplate? {
        let templates = try await fetchBatchTemplates(
            applicableToMachine: nil,
            priority: priority,
            isActive: true
        )
        
        // Find template that best matches the requirements
        return templates
            .filter { template in
                // Check machine compatibility
                machineIds.allSatisfy { machineId in
                    template.applicableMachines.isEmpty || 
                    template.applicableMachines.contains(machineId)
                }
            }
            .filter { template in
                // Check product compatibility if specified
                guard let requiredProducts = productIds else { return true }
                let templateProducts = template.productTemplates.map { $0.productId }
                return requiredProducts.allSatisfy { templateProducts.contains($0) }
            }
            .sorted { $0.priority.order > $1.priority.order }
            .first
    }
    
    /// Validates if batch group can be submitted for approval
    func validateGroupForSubmission(_ group: ApprovalGroup) async throws -> [String] {
        var validationErrors: [String] = []
        
        // Check if all batches exist and are valid
        for batchId in group.batchIds {
            let duplicates = try await validateNoDuplicateApprovals(
                machineIds: [batchId], // This would need proper implementation
                date: group.targetDate
            )
            if !duplicates.isEmpty {
                validationErrors.append("批次 \(batchId) 存在重复批准")
            }
        }
        
        // Check for conflicts
        let conflicts = try await detectConflicts(in: group)
        if !conflicts.isEmpty {
            validationErrors.append("发现 \(conflicts.count) 个配置冲突")
        }
        
        // Check machine readiness
        let readinessStates = try await fetchMachineReadinessStates(for: group.targetDate)
        let unavailableMachines = readinessStates
            .filter { !$0.isAvailable }
            .map { $0.machineId }
        
        if !unavailableMachines.isEmpty {
            validationErrors.append("设备不可用: \(unavailableMachines.joined(separator: ", "))")
        }
        
        return validationErrors
    }
}