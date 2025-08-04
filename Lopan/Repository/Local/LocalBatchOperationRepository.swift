import Foundation
import SwiftData

/// Local SwiftData implementation of BatchOperationRepository
final class LocalBatchOperationRepository: BatchOperationRepository {
    
    private let modelContext: ModelContext
    private let auditingService: NewAuditingService
    private let conflictDetector: ConflictDetectionEngine
    
    init(
        modelContext: ModelContext,
        auditingService: NewAuditingService
    ) {
        self.modelContext = modelContext
        self.auditingService = auditingService
        self.conflictDetector = ConflictDetectionEngine(modelContext: modelContext)
    }
    
    // MARK: - Batch Template Operations
    
    func fetchBatchTemplates() async throws -> [BatchTemplate] {
        let descriptor = FetchDescriptor<BatchTemplate>(
            sortBy: [SortDescriptor(\.lastModifiedAt, order: .reverse)]
        )
        let allTemplates = try modelContext.fetch(descriptor)
        return allTemplates.filter { $0.isActive }
    }
    
    func fetchBatchTemplates(
        applicableToMachine machineId: String?,
        priority: TemplatePriority?,
        isActive: Bool?
    ) async throws -> [BatchTemplate] {
        // Fetch all templates and filter in memory for simplicity
        let descriptor = FetchDescriptor<BatchTemplate>(
            sortBy: [SortDescriptor(\.lastModifiedAt, order: .reverse)]
        )
        
        let allTemplates = try modelContext.fetch(descriptor)
        
        // Apply filters in memory
        let filteredTemplates = allTemplates.filter { template in
            // Filter by active status
            if let isActiveValue = isActive, template.isActive != isActiveValue {
                return false
            }
            
            // Filter by priority
            if let priorityValue = priority, template.priority != priorityValue {
                return false
            }
            
            // Filter by machine applicability
            if let machineId = machineId {
                if !template.applicableMachines.isEmpty && !template.applicableMachines.contains(machineId) {
                    return false
                }
            }
            
            return true
        }
        
        return filteredTemplates.sorted { $0.priority.order > $1.priority.order }
    }
    
    func createBatchTemplate(_ template: BatchTemplate) async throws {
        modelContext.insert(template)
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .create,
            entityType: .productionBatch,
            entityId: template.id,
            entityDescription: "Batch Template: \(template.name)",
            operatorUserId: template.createdBy,
            operatorUserName: template.createdBy,
            operationDetails: [
                "templateName": template.name,
                "applicableMachines": template.applicableMachines.joined(separator: ","),
                "priority": template.priority.rawValue
            ]
        )
    }
    
    func updateBatchTemplate(_ template: BatchTemplate) async throws {
        template.lastModifiedAt = Date()
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .update,
            entityType: .productionBatch,
            entityId: template.id,
            entityDescription: "Batch Template: \(template.name)",
            operatorUserId: template.createdBy,
            operatorUserName: template.createdBy,
            operationDetails: [
                "templateName": template.name,
                "isActive": String(template.isActive)
            ]
        )
    }
    
    func deleteBatchTemplate(id: String) async throws {
        let descriptor = FetchDescriptor<BatchTemplate>()
        let templates = try modelContext.fetch(descriptor)
        
        guard let template = templates.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound("BatchTemplate with id \(id) not found")
        }
        
        template.isActive = false
        template.lastModifiedAt = Date()
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .delete,
            entityType: .productionBatch,
            entityId: id,
            entityDescription: "Batch Template: \(template.name)",
            operatorUserId: "system",
            operatorUserName: "System",
            operationDetails: ["templateName": template.name]
        )
    }
    
    func applyTemplate(
        _ template: BatchTemplate,
        to machineIds: [String],
        targetDate: Date,
        coordinatorId: String
    ) async throws -> [ProductionBatch] {
        var createdBatches: [ProductionBatch] = []
        
        for machineId in machineIds {
            // Verify machine is applicable for this template
            if !template.applicableMachines.isEmpty && 
               !template.applicableMachines.contains(machineId) {
                continue
            }
            
            let batch = ProductionBatch(
                machineId: machineId,
                mode: .singleColor, // Default mode
                submittedBy: coordinatorId,
                submittedByName: coordinatorId
            )
            
            // Apply template products
            for productTemplate in template.productTemplates.sorted(by: { $0.order < $1.order }) {
                let productConfig = ProductConfig(
                    batchId: batch.id,
                    productName: productTemplate.productName,
                    primaryColorId: productTemplate.defaultColorId,
                    occupiedStations: productTemplate.defaultStationNumbers,
                    expectedOutput: 1000,
                    priority: productTemplate.order,
                    productId: productTemplate.productId
                )
                batch.products.append(productConfig)
            }
            
            modelContext.insert(batch)
            createdBatches.append(batch)
        }
        
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .create,
            entityType: .productionBatch,
            entityId: template.id,
            entityDescription: "Applied Template: \(template.name)",
            operatorUserId: coordinatorId,
            operatorUserName: coordinatorId,
            operationDetails: [
                "templateName": template.name,
                "machineCount": String(machineIds.count),
                "batchCount": String(createdBatches.count),
                "targetDate": ISO8601DateFormatter().string(from: targetDate)
            ]
        )
        
        return createdBatches
    }
    
    // MARK: - Approval Group Operations
    
    func fetchApprovalGroups(for date: Date) async throws -> [ApprovalGroup] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<ApprovalGroup>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        
        let allGroups = try modelContext.fetch(descriptor)
        return allGroups.filter { group in
            group.targetDate >= startOfDay && group.targetDate < endOfDay
        }
    }
    
    func fetchApprovalGroups(status: GroupApprovalStatus) async throws -> [ApprovalGroup] {
        let descriptor = FetchDescriptor<ApprovalGroup>(
            sortBy: [
                SortDescriptor(\.submittedAt, order: .forward)
            ]
        )
        
        let allGroups = try modelContext.fetch(descriptor)
        return allGroups.filter { $0.groupStatus == status }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func fetchApprovalGroups(coordinatorId: String) async throws -> [ApprovalGroup] {
        let descriptor = FetchDescriptor<ApprovalGroup>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        
        let allGroups = try modelContext.fetch(descriptor)
        return allGroups.filter { $0.coordinatorUserId == coordinatorId }
    }
    
    func createApprovalGroup(_ group: ApprovalGroup) async throws {
        modelContext.insert(group)
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .create,
            entityType: .productionBatch,
            entityId: group.id,
            entityDescription: "Approval Group: \(group.groupName)",
            operatorUserId: group.coordinatorUserId,
            operatorUserName: group.coordinatorUserId,
            operationDetails: [
                "groupName": group.groupName,
                "batchCount": String(group.batchIds.count),
                "targetDate": ISO8601DateFormatter().string(from: group.targetDate),
                "priority": group.priority.rawValue
            ]
        )
    }
    
    func updateApprovalGroup(_ group: ApprovalGroup) async throws {
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .update,
            entityType: .productionBatch,
            entityId: group.id,
            entityDescription: "Approval Group: \(group.groupName)",
            operatorUserId: group.coordinatorUserId,
            operatorUserName: group.coordinatorUserId,
            operationDetails: [
                "groupName": group.groupName,
                "status": group.groupStatus.rawValue,
                "batchCount": String(group.batchIds.count)
            ]
        )
    }
    
    func addBatches(batchIds: [String], to groupId: String) async throws {
        let descriptor = FetchDescriptor<ApprovalGroup>()
        let allGroups = try modelContext.fetch(descriptor)
        
        guard let group = allGroups.first(where: { $0.id == groupId }) else {
            throw RepositoryError.notFound("ApprovalGroup with id \(groupId) not found")
        }
        
        let newBatchIds = batchIds.filter { !group.batchIds.contains($0) }
        group.batchIds.append(contentsOf: newBatchIds)
        
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .update,
            entityType: .productionBatch,
            entityId: groupId,
            entityDescription: "Add Batches to Group: \(group.groupName)",
            operatorUserId: group.coordinatorUserId,
            operatorUserName: group.coordinatorUserId,
            operationDetails: [
                "addedBatchIds": newBatchIds.joined(separator: ","),
                "totalBatchCount": String(group.batchIds.count)
            ]
        )
    }
    
    func removeBatches(batchIds: [String], from groupId: String) async throws {
        let descriptor = FetchDescriptor<ApprovalGroup>()
        let allGroups = try modelContext.fetch(descriptor)
        
        guard let group = allGroups.first(where: { $0.id == groupId }) else {
            throw RepositoryError.notFound("ApprovalGroup with id \(groupId) not found")
        }
        
        group.batchIds.removeAll { batchIds.contains($0) }
        
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .update,
            entityType: .productionBatch,
            entityId: groupId,
            entityDescription: "Remove Batches from Group",
            operatorUserId: group.coordinatorUserId,
            operatorUserName: group.coordinatorUserId,
            operationDetails: [
                "removedBatchIds": batchIds.joined(separator: ","),
                "remainingBatchCount": String(group.batchIds.count)
            ]
        )
    }
    
    func createOptimalBatchGroups(
        for date: Date,
        coordinatorId: String
    ) async throws -> [ApprovalGroup] {
        // Fetch all pending batches for the date
        let batchDescriptor = FetchDescriptor<ProductionBatch>()
        let allBatches = try modelContext.fetch(batchDescriptor)
        let pendingBatches = allBatches.filter { $0.status == .pending }
        
        // Group batches by similar characteristics
        let groupedBatches = try await groupBatchesBySimilarity(pendingBatches)
        
        var createdGroups: [ApprovalGroup] = []
        
        for (index, batchGroup) in groupedBatches.enumerated() {
            let group = ApprovalGroup(
                groupName: "自动批次组 \(index + 1)",
                targetDate: date,
                batchIds: batchGroup.map { $0.id },
                coordinatorUserId: coordinatorId,
                priority: determinePriority(for: batchGroup)
            )
            
            try await createApprovalGroup(group)
            createdGroups.append(group)
        }
        
        return createdGroups
    }
    
    // MARK: - Machine Readiness Operations
    
    func fetchMachineReadinessStates(for date: Date) async throws -> [MachineReadinessState] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<MachineReadinessState>(
            sortBy: [SortDescriptor(\.machineId)]
        )
        
        let allStates = try modelContext.fetch(descriptor)
        return allStates.filter { state in
            state.targetDate >= startOfDay && state.targetDate < endOfDay
        }
    }
    
    func fetchMachineReadinessState(
        machineId: String,
        date: Date
    ) async throws -> MachineReadinessState? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<MachineReadinessState>()
        let allStates = try modelContext.fetch(descriptor)
        
        return allStates.first { state in
            state.machineId == machineId &&
            state.targetDate >= startOfDay && 
            state.targetDate < endOfDay
        }
    }
    
    func updateMachineReadinessState(_ state: MachineReadinessState) async throws {
        state.lastStatusUpdate = Date()
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .update,
            entityType: .machine,
            entityId: state.id,
            entityDescription: "Machine Readiness Update",
            operatorUserId: state.statusUpdatedBy,
            operatorUserName: state.statusUpdatedBy,
            operationDetails: [
                "machineId": state.machineId,
                "status": state.readinessStatus.rawValue,
                "targetDate": ISO8601DateFormatter().string(from: state.targetDate),
                "healthScore": String(format: "%.2f", state.healthScore)
            ]
        )
    }
    
    func markMachineAsReady(
        machineId: String,
        date: Date,
        updatedBy: String
    ) async throws {
        if let existingState = try await fetchMachineReadinessState(machineId: machineId, date: date) {
            existingState.readinessStatus = .ready
            existingState.actualReadyTime = Date()
            existingState.statusUpdatedBy = updatedBy
            try await updateMachineReadinessState(existingState)
        } else {
            let newState = MachineReadinessState(
                machineId: machineId,
                targetDate: date,
                readinessStatus: .ready,
                statusUpdatedBy: updatedBy
            )
            newState.actualReadyTime = Date()
            modelContext.insert(newState)
            try modelContext.save()
        }
    }
    
    func markMachineInUse(
        machineId: String,
        batchId: String,
        date: Date
    ) async throws {
        if let state = try await fetchMachineReadinessState(machineId: machineId, date: date) {
            state.readinessStatus = .inUse
            state.pendingBatchId = batchId
            try await updateMachineReadinessState(state)
        }
    }
    
    // MARK: - Conflict Detection and Resolution
    
    func detectMachineConflicts(for date: Date) async throws -> [ConfigurationConflict] {
        let states = try await fetchMachineReadinessStates(for: date)
        let approvalGroups = try await fetchApprovalGroups(for: date)
        
        return try await conflictDetector.detectConflicts(
            machineStates: states,
            approvalGroups: approvalGroups,
            targetDate: date
        )
    }
    
    func detectConflicts(in group: ApprovalGroup) async throws -> [ConfigurationConflict] {
        return try await conflictDetector.detectGroupConflicts(group)
    }
    
    func validateBatchCompatibility(batchIds: [String]) async throws -> [ConfigurationConflict] {
        return try await conflictDetector.validateBatchCompatibility(batchIds)
    }
    
    func autoResolveConflicts(_ conflicts: [ConfigurationConflict]) async throws -> [ConflictResolution] {
        var resolutions: [ConflictResolution] = []
        
        for conflict in conflicts.filter({ $0.canAutoResolve }) {
            if let resolution = try await conflictDetector.attemptAutoResolution(conflict) {
                try await recordConflictResolution(resolution)
                resolutions.append(resolution)
            }
        }
        
        return resolutions
    }
    
    func recordConflictResolution(_ resolution: ConflictResolution) async throws {
        modelContext.insert(resolution)
        try modelContext.save()
        
        try await auditingService.logOperation(
            operationType: .create,
            entityType: .productionBatch,
            entityId: resolution.id,
            entityDescription: "Conflict Resolution",
            operatorUserId: resolution.resolvedBy,
            operatorUserName: resolution.resolvedBy,
            operationDetails: [
                "conflictType": resolution.conflictType.rawValue,
                "resolutionStrategy": resolution.resolutionStrategy.rawValue,
                "impactedMachines": resolution.impactedMachineIds.joined(separator: ",")
            ]
        )
    }
    
    // MARK: - Additional Operations
    
    func validateNoDuplicateApprovals(
        machineIds: [String],
        date: Date
    ) async throws -> [String] {
        let states = try await fetchMachineReadinessStates(for: date)
        
        return machineIds.filter { machineId in
            states.contains { state in
                state.machineId == machineId && 
                state.lastApprovedBatchId != nil
            }
        }
    }
    
    func batchApprove(
        groupId: String,
        approverUserId: String,
        notes: String?
    ) async throws -> BatchApprovalResult {
        let startTime = Date()
        
        guard let group = try await fetchApprovalGroups(coordinatorId: approverUserId)
            .first(where: { $0.id == groupId }) else {
            throw RepositoryError.notFound("ApprovalGroup not found")
        }
        
        var approvedBatchIds: [String] = []
        var failedBatchIds: [String] = []
        var warnings: [String] = []
        
        // Validate group before approval
        let validationErrors = try await validateGroupForSubmission(group)
        if !validationErrors.isEmpty {
            warnings.append(contentsOf: validationErrors)
        }
        
        // Process each batch in the group
        for batchId in group.batchIds {
            do {
                // Here you would approve individual batches
                // This is a simplified implementation
                approvedBatchIds.append(batchId)
            } catch {
                failedBatchIds.append(batchId)
                warnings.append("Failed to approve batch \(batchId): \(error.localizedDescription)")
            }
        }
        
        // Update group status
        if failedBatchIds.isEmpty {
            group.groupStatus = .fullyApproved
            group.approvedAt = Date()
            group.approvedBy = approverUserId
        } else if !approvedBatchIds.isEmpty {
            group.groupStatus = .partiallyApproved
        }
        
        if let notes = notes {
            group.notes = notes
        }
        
        try await updateApprovalGroup(group)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return BatchApprovalResult(
            groupId: groupId,
            approvedBatchIds: approvedBatchIds,
            failedBatchIds: failedBatchIds,
            warnings: warnings,
            processedAt: Date(),
            totalProcessingTime: processingTime
        )
    }
    
    func copyConfiguration(
        from sourceDate: Date,
        to targetDate: Date,
        machineIds: [String]?,
        coordinatorId: String
    ) async throws -> [ProductionBatch] {
        let calendar = Calendar.current
        let sourceStartOfDay = calendar.startOfDay(for: sourceDate)
        let sourceEndOfDay = calendar.date(byAdding: .day, value: 1, to: sourceStartOfDay)!
        
        // Fetch approved batches from source date
        let descriptor = FetchDescriptor<ProductionBatch>(
            sortBy: [SortDescriptor(\.submittedAt, order: .forward)]
        )
        let allBatches = try modelContext.fetch(descriptor)
        
        // Filter for approved batches from source date
        let sourceBatches = allBatches.filter { batch in
            guard batch.status == .approved,
                  batch.submittedAt >= sourceStartOfDay && batch.submittedAt < sourceEndOfDay else {
                return false
            }
            
            // Filter by specific machines if provided
            if let machineIds = machineIds {
                return machineIds.contains(batch.machineId)
            }
            return true
        }
        
        // Create new batches for target date
        var copiedBatches: [ProductionBatch] = []
        
        for sourceBatch in sourceBatches {
            // Create a new batch with copied configuration
            let newBatch = ProductionBatch(
                machineId: sourceBatch.machineId,
                mode: sourceBatch.mode,
                submittedBy: coordinatorId,
                submittedByName: coordinatorId
            )
            
            // Copy product configurations
            for sourceProduct in sourceBatch.products {
                let newProduct = ProductConfig(
                    batchId: newBatch.id,
                    productName: sourceProduct.productName,
                    primaryColorId: sourceProduct.primaryColorId,
                    occupiedStations: sourceProduct.occupiedStations,
                    expectedOutput: sourceProduct.expectedOutput,
                    priority: sourceProduct.priority,
                    productId: sourceProduct.productId
                )
                
                // Copy optional properties
                newProduct.secondaryColorId = sourceProduct.secondaryColorId
                newProduct.gunAssignment = sourceProduct.gunAssignment
                
                newBatch.products.append(newProduct)
            }
            
            // Reset status to pending for new batch
            newBatch.status = .pending
            
            // Insert into context
            modelContext.insert(newBatch)
            copiedBatches.append(newBatch)
        }
        
        // Save all new batches
        try modelContext.save()
        
        // Log the copy operation
        try await auditingService.logOperation(
            operationType: .create,
            entityType: .productionBatch,
            entityId: "COPY_OPERATION_\(UUID().uuidString)",
            entityDescription: "Configuration Copy Operation",
            operatorUserId: coordinatorId,
            operatorUserName: coordinatorId,
            operationDetails: [
                "sourceDate": ISO8601DateFormatter().string(from: sourceDate),
                "targetDate": ISO8601DateFormatter().string(from: targetDate),
                "sourceBatchCount": String(sourceBatches.count),
                "copiedBatchCount": String(copiedBatches.count),
                "machineIds": machineIds?.joined(separator: ",") ?? "ALL"
            ]
        )
        
        return copiedBatches
    }
    
    func fetchApprovalHistory(
        machineId: String?,
        dateRange: DateInterval,
        coordinatorId: String?
    ) async throws -> [ApprovalGroup] {
        let descriptor = FetchDescriptor<ApprovalGroup>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        
        let allGroups = try modelContext.fetch(descriptor)
        
        return allGroups.filter { group in
            // Filter by date range
            guard group.targetDate >= dateRange.start && group.targetDate <= dateRange.end else {
                return false
            }
            
            // Filter by coordinator if specified
            if let coordinatorId = coordinatorId {
                guard group.coordinatorUserId == coordinatorId else {
                    return false
                }
            }
            
            return true
        }
    }
    
    // MARK: - Analytics Implementation Stubs
    
    func fetchApprovalMetrics(
        dateRange: DateInterval,
        coordinatorId: String?
    ) async throws -> ApprovalMetrics {
        // Fetch approval groups in the date range
        let descriptor = FetchDescriptor<ApprovalGroup>(
            sortBy: [SortDescriptor(\.submittedAt, order: .forward)]
        )
        let allGroups = try modelContext.fetch(descriptor)
        
        // Filter by date range and coordinator
        let filteredGroups = allGroups.filter { group in
            let inRange = group.targetDate >= dateRange.start && group.targetDate <= dateRange.end
            if let coordinatorId = coordinatorId {
                return inRange && group.coordinatorUserId == coordinatorId
            }
            return inRange
        }
        
        // Calculate metrics
        let totalGroups = filteredGroups.count
        let approvedGroups = filteredGroups.filter { $0.groupStatus == .fullyApproved }.count
        let rejectedGroups = filteredGroups.filter { $0.groupStatus == .rejected }.count
        let pendingGroups = filteredGroups.filter { $0.groupStatus == .pendingReview }.count
        
        // Calculate average approval time
        let approvedGroupsWithTimes = filteredGroups.compactMap { group -> TimeInterval? in
            guard let submittedAt = group.submittedAt,
                  let approvedAt = group.approvedAt else { return nil }
            return approvedAt.timeIntervalSince(submittedAt)
        }
        let averageApprovalTime = approvedGroupsWithTimes.isEmpty ? 0 : 
            approvedGroupsWithTimes.reduce(0, +) / Double(approvedGroupsWithTimes.count)
        
        // Fetch conflicts for resolution rate
        let conflictDescriptor = FetchDescriptor<ConflictResolution>()
        let allResolutions = try modelContext.fetch(conflictDescriptor)
        let dateFilteredResolutions = allResolutions.filter { resolution in
            resolution.resolvedAt >= dateRange.start && resolution.resolvedAt <= dateRange.end
        }
        
        let totalConflicts = dateFilteredResolutions.count
        let autoResolvedConflicts = dateFilteredResolutions.filter { 
            $0.resolutionStrategy == .automatic 
        }.count
        let conflictResolutionRate = totalConflicts > 0 ? 
            Double(autoResolvedConflicts) / Double(totalConflicts) : 0
        
        // Calculate machine utilization (simplified)
        let machineStatesDescriptor = FetchDescriptor<MachineReadinessState>()
        let allStates = try modelContext.fetch(machineStatesDescriptor)
        let activeStates = allStates.filter { state in
            state.targetDate >= dateRange.start && state.targetDate <= dateRange.end &&
            state.readinessStatus == .inUse
        }
        let machineUtilizationRate = allStates.isEmpty ? 0 : 
            Double(activeStates.count) / Double(allStates.count)
        
        // Top conflict types
        let conflictTypes = Dictionary(grouping: dateFilteredResolutions) { $0.conflictType }
        let topConflictTypes = conflictTypes.map { (type, resolutions) in
            type // Just return the conflict type for now
        }.prefix(5)
        
        return ApprovalMetrics(
            dateRange: dateRange,
            totalGroups: totalGroups,
            approvedGroups: approvedGroups,
            rejectedGroups: rejectedGroups,
            pendingGroups: pendingGroups,
            averageApprovalTime: averageApprovalTime,
            conflictResolutionRate: conflictResolutionRate,
            machineUtilizationRate: machineUtilizationRate,
            topConflictTypes: Array(topConflictTypes)
        )
    }
    
    func fetchMachineUtilization(
        dateRange: DateInterval,
        machineIds: [String]?
    ) async throws -> [MachineUtilizationMetric] {
        // Fetch machine readiness states in the date range
        let descriptor = FetchDescriptor<MachineReadinessState>(
            sortBy: [SortDescriptor(\.machineId)]
        )
        let allStates = try modelContext.fetch(descriptor)
        
        // Filter by date range and specific machines if provided
        let filteredStates = allStates.filter { state in
            let inRange = state.targetDate >= dateRange.start && state.targetDate <= dateRange.end
            if let machineIds = machineIds {
                return inRange && machineIds.contains(state.machineId)
            }
            return inRange
        }
        
        // Group by machine ID
        let statesByMachine = Dictionary(grouping: filteredStates) { $0.machineId }
        
        var metrics: [MachineUtilizationMetric] = []
        
        for (machineId, states) in statesByMachine {
            let inUseStates = states.filter { $0.readinessStatus == .inUse }
            let maintenanceStates = states.filter { $0.readinessStatus == .maintenance }
            let readyStates = states.filter { $0.readinessStatus == .ready }
            
            // Calculate utilization percentages (simplified calculation)
            let stateCount = Double(states.count)
            let utilizationRate = states.isEmpty ? 0 : Double(inUseStates.count) / stateCount
            let maintenanceRate = states.isEmpty ? 0 : Double(maintenanceStates.count) / stateCount
            let readyRate = states.isEmpty ? 0 : Double(readyStates.count) / stateCount
            
            // Calculate average health score
            let totalHealthScore = states.map { $0.healthScore }.reduce(0, +)
            let averageHealthScore = states.isEmpty ? 0 : totalHealthScore / stateCount
            
            // Count total batches processed
            let batchesProcessed = inUseStates.compactMap { $0.pendingBatchId }.count
            
            let metric = MachineUtilizationMetric(
                machineId: machineId,
                dateRange: dateRange,
                totalAvailableTime: dateRange.duration,
                actualUsageTime: dateRange.duration * utilizationRate,
                maintenanceTime: dateRange.duration * maintenanceRate,
                idleTime: dateRange.duration * readyRate,
                batchCount: batchesProcessed,
                averageBatchDuration: batchesProcessed > 0 ? dateRange.duration / Double(batchesProcessed) : 0
            )
            metrics.append(metric)
        }
        
        return metrics.sorted { $0.machineId < $1.machineId }
    }
    
    func fetchTemplateUsageStatistics() async throws -> [TemplateUsageMetric] {
        // Fetch all batch templates
        let templateDescriptor = FetchDescriptor<BatchTemplate>(
            sortBy: [SortDescriptor(\.lastModifiedAt, order: .reverse)]
        )
        let allTemplates = try modelContext.fetch(templateDescriptor)
        
        // Fetch audit logs to track template usage
        let auditDescriptor = FetchDescriptor<AuditLog>()
        let auditLogs = try modelContext.fetch(auditDescriptor)
        
        // Filter for template application events
        let templateUsageLogs = auditLogs.filter { log in
            log.operationType == .create && 
            log.entityType == .productionBatch &&
            log.operationDetails.contains("Applied Template:")
        }
        
        return allTemplates.map { template in
            // Count how many times this template was used
            let usageCount = templateUsageLogs.filter { log in
                log.operationDetails.contains(template.name)
            }.count
            
            // Calculate success rate (simplified - assumes all applications were successful)
            let successRate: Double = usageCount > 0 ? 1.0 : 0.0
            
            // Find last usage date
            let lastUsageDate = templateUsageLogs
                .filter { log in log.operationDetails.contains(template.name) }
                .max { $0.timestamp < $1.timestamp }?.timestamp
            
            // Calculate average machines per usage
            let machinesPerUsage = template.applicableMachines.isEmpty ? 0 : 
                Double(template.applicableMachines.count)
            
            return TemplateUsageMetric(
                templateId: template.id,
                templateName: template.name,
                usageCount: usageCount,
                successRate: successRate,
                averageProcessingTime: 0.0, // Could be calculated from audit logs
                lastUsedDate: lastUsageDate,
                popularMachines: template.applicableMachines
            )
        }.sorted { $0.usageCount > $1.usageCount }
    }
    
    // MARK: - Helper Methods
    
    private func groupBatchesBySimilarity(_ batches: [ProductionBatch]) async throws -> [[ProductionBatch]] {
        // Simple grouping by device type and production mode
        let grouped = Dictionary(grouping: batches) { batch in
            "\(batch.machineId)-\(batch.mode.rawValue)"
        }
        
        return Array(grouped.values)
    }
    
    private func determinePriority(for batches: [ProductionBatch]) -> ApprovalPriority {
        // Simple priority determination logic
        return batches.count > 5 ? .high : .medium
    }
}

// MARK: - Supporting Classes

private class ConflictDetectionEngine {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func detectConflicts(
        machineStates: [MachineReadinessState],
        approvalGroups: [ApprovalGroup],
        targetDate: Date
    ) async throws -> [ConfigurationConflict] {
        var conflicts: [ConfigurationConflict] = []
        
        // 1. Detect machine availability conflicts
        for state in machineStates {
            if !state.isAvailable && state.pendingBatchId != nil {
                conflicts.append(
                    ConfigurationConflict(
                        type: .machineUnavailable,
                        severity: .high,
                        description: "设备 \(state.machineId) 不可用但有待处理批次",
                        affectedMachineIds: [state.machineId]
                    )
                )
            }
            
            // Check for low health score
            if state.healthScore < 0.7 && state.readinessStatus == .ready {
                conflicts.append(
                    ConfigurationConflict(
                        type: .machineUnavailable,
                        severity: .medium,
                        description: "设备 \(state.machineId) 健康度低 (\(Int(state.healthScore * 100))%)",
                        affectedMachineIds: [state.machineId]
                    )
                )
            }
        }
        
        // 2. Detect resource conflicts between approval groups
        let allBatchIds = approvalGroups.flatMap { $0.batchIds }
        let duplicateBatchIds = Dictionary(grouping: allBatchIds) { $0 }
            .filter { $1.count > 1 }
            .keys
        
        if !duplicateBatchIds.isEmpty {
            conflicts.append(
                ConfigurationConflict(
                    type: .resourceConstraint,
                    severity: .high,
                    description: "批次重复分配: \(duplicateBatchIds.joined(separator: ", "))",
                    affectedMachineIds: []
                )
            )
        }
        
        // 3. Detect machine overallocation
        let machineAllocation = Dictionary(grouping: machineStates) { $0.machineId }
        for (machineId, states) in machineAllocation {
            let simultaneousAllocations = states.filter { state in
                state.readinessStatus == .inUse || state.pendingBatchId != nil
            }
            
            if simultaneousAllocations.count > 1 {
                conflicts.append(
                    ConfigurationConflict(
                        type: .resourceConstraint,
                        severity: .high,
                        description: "设备 \(machineId) 被多个批次同时占用",
                        affectedMachineIds: [machineId]
                    )
                )
            }
        }
        
        // 4. Detect scheduling conflicts based on priority
        let highPriorityGroups = approvalGroups.filter { $0.priority == .high }
        let mediumPriorityGroups = approvalGroups.filter { $0.priority == .medium }
        
        if highPriorityGroups.count > 3 {
            conflicts.append(
                ConfigurationConflict(
                    type: .configurationInvalid,
                    severity: .medium,
                    description: "高优先级任务过多 (\(highPriorityGroups.count) 个)，可能影响调度",
                    affectedMachineIds: []
                )
            )
        }
        
        return conflicts
    }
    
    func detectGroupConflicts(_ group: ApprovalGroup) async throws -> [ConfigurationConflict] {
        var conflicts: [ConfigurationConflict] = []
        
        // Fetch batches in the group
        let batchDescriptor = FetchDescriptor<ProductionBatch>()
        let allBatches = try modelContext.fetch(batchDescriptor)
        let groupBatches = allBatches.filter { group.batchIds.contains($0.id) }
        
        // Check for machine conflicts within the group
        let machineIds = Set(groupBatches.map { $0.machineId })
        let machineGroups = Dictionary(grouping: groupBatches) { $0.machineId }
        
        for (machineId, batches) in machineGroups {
            if batches.count > 1 {
                conflicts.append(
                    ConfigurationConflict(
                        type: .resourceConstraint,
                        severity: .high,
                        description: "设备 \(machineId) 在同一组中有多个批次冲突",
                        affectedMachineIds: [machineId]
                    )
                )
            }
        }
        
        // Check for production mode compatibility
        let productionModes = Set(groupBatches.map { $0.mode })
        if productionModes.count > 1 {
            conflicts.append(
                ConfigurationConflict(
                    type: .configurationInvalid,
                    severity: .medium,
                    description: "组内批次使用不同的生产模式",
                    affectedMachineIds: Array(machineIds)
                )
            )
        }
        
        return conflicts
    }
    
    func validateBatchCompatibility(_ batchIds: [String]) async throws -> [ConfigurationConflict] {
        var conflicts: [ConfigurationConflict] = []
        
        // Fetch the batches
        let batchDescriptor = FetchDescriptor<ProductionBatch>()
        let allBatches = try modelContext.fetch(batchDescriptor)
        let targetBatches = allBatches.filter { batchIds.contains($0.id) }
        
        // Check for color conflicts between batches
        var colorUsage: [String: [String]] = [:]
        
        for batch in targetBatches {
            for product in batch.products {
                let colors = [product.primaryColorId, product.secondaryColorId].compactMap { $0 }
                for color in colors {
                    if colorUsage[color] == nil {
                        colorUsage[color] = []
                    }
                    colorUsage[color]?.append(batch.machineId)
                }
            }
        }
        
        // Detect color conflicts between machines
        for (colorId, machineIds) in colorUsage {
            let uniqueMachines = Set(machineIds)
            if uniqueMachines.count > 1 {
                conflicts.append(
                    ConfigurationConflict(
                        type: .configurationInvalid,
                        severity: .medium,
                        description: "颜色 \(colorId) 在多台设备间冲突",
                        affectedMachineIds: Array(uniqueMachines)
                    )
                )
            }
        }
        
        // Check for station number conflicts
        var stationUsage: [Int: [String]] = [:]
        
        for batch in targetBatches {
            for product in batch.products {
                for station in product.occupiedStations {
                    if stationUsage[station] == nil {
                        stationUsage[station] = []
                    }
                    stationUsage[station]?.append(batch.machineId)
                }
            }
        }
        
        for (stationNumber, machineIds) in stationUsage {
            let uniqueMachines = Set(machineIds)
            if uniqueMachines.count > 1 {
                conflicts.append(
                    ConfigurationConflict(
                        type: .resourceConstraint,
                        severity: .high,
                        description: "工位 \(stationNumber) 被多台设备同时使用",
                        affectedMachineIds: Array(uniqueMachines)
                    )
                )
            }
        }
        
        return conflicts
    }
    
    func attemptAutoResolution(_ conflict: ConfigurationConflict) async throws -> ConflictResolution? {
        guard conflict.canAutoResolve else { return nil }
        
        var resolutionDetails = ""
        var resolutionStrategy: ResolutionStrategy = .automatic
        
        switch conflict.type {
        case .machineUnavailable:
            if conflict.description.contains("健康度低") {
                resolutionDetails = "推迟批次至设备维护完成"
                resolutionStrategy = .postponed
            } else {
                resolutionDetails = "重新分配到可用设备"
                resolutionStrategy = .automatic
            }
            
        case .resourceConstraint:
            if conflict.description.contains("重复分配") {
                resolutionDetails = "移除重复批次，保留优先级最高的"
                resolutionStrategy = .automatic
            } else if conflict.description.contains("同时占用") {
                resolutionDetails = "按时间顺序重新调度"
                resolutionStrategy = .automatic
            } else {
                resolutionDetails = "优化资源分配"
                resolutionStrategy = .automatic
            }
            
        case .configurationInvalid:
            if conflict.description.contains("优先级任务过多") {
                resolutionDetails = "部分任务降级为中等优先级"
                resolutionStrategy = .automatic
            } else if conflict.description.contains("不同的生产模式") {
                resolutionDetails = "统一为最常用的生产模式"
                resolutionStrategy = .automatic
            } else {
                resolutionDetails = "标准化配置参数"
                resolutionStrategy = .automatic
            }
            
        case .stationOverlap:
            resolutionDetails = "重新分配工位，避免重叠"
            resolutionStrategy = .automatic
            
        case .timeConflict:
            resolutionDetails = "调整批次时间安排"
            resolutionStrategy = .automatic
            
        case .dependencyMissing:
            resolutionDetails = "等待依赖项完成"
            resolutionStrategy = .postponed
        }
        
        return ConflictResolution(
            conflictType: conflict.type,
            conflictDescription: conflict.description,
            resolutionStrategy: resolutionStrategy,
            resolutionDetails: resolutionDetails,
            resolvedBy: "system",
            impactedMachineIds: conflict.affectedMachineIds
        )
    }
}

// MARK: - Error Types

enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case validationError(String)
    case conflictError(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return "未找到: \(message)"
        case .validationError(let message):
            return "验证错误: \(message)"
        case .conflictError(let message):
            return "冲突错误: \(message)"
        }
    }
}