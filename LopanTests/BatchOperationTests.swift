import XCTest
import SwiftData
@testable import Lopan

/// Comprehensive test suite for batch operation functionality
final class BatchOperationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var batchRepository: LocalBatchOperationRepository!
    var auditingService: NewAuditingService!
    var coordinator: BatchOperationCoordinator!
    var sessionService: SessionSecurityService!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory model container for testing
        let schema = Schema([
            BatchTemplate.self,
            ApprovalGroup.self,
            MachineReadinessState.self,
            ConflictResolution.self,
            ProductionBatch.self,
            AuditLog.self,
            User.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Initialize services
        auditingService = NewAuditingService(modelContext: modelContext)
        sessionService = SessionSecurityService(auditingService: auditingService)
        batchRepository = LocalBatchOperationRepository(
            modelContext: modelContext,
            auditingService: auditingService
        )
        
        // Create mock production batch service
        let mockProductionService = MockProductionBatchService()
        
        coordinator = BatchOperationCoordinator(
            batchRepository: batchRepository,
            productionBatchService: mockProductionService,
            auditingService: auditingService,
            sessionService: sessionService
        )
        
        // Insert test data
        try insertTestData()
    }
    
    override func tearDownWithError() throws {
        coordinator = nil
        batchRepository = nil
        auditingService = nil
        sessionService = nil
        modelContext = nil
        modelContainer = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Batch Template Tests
    
    func testCreateBatchTemplate() async throws {
        // Given
        let template = createTestBatchTemplate(
            name: "标准生产模板",
            applicableMachines: ["MACHINE_001", "MACHINE_002"]
        )
        
        // When
        try await batchRepository.createBatchTemplate(template)
        
        // Then
        let fetchedTemplates = try await batchRepository.fetchBatchTemplates()
        XCTAssertEqual(fetchedTemplates.count, 2) // 1 from test data + 1 new
        
        let createdTemplate = fetchedTemplates.first { $0.name == "标准生产模板" }
        XCTAssertNotNil(createdTemplate)
        XCTAssertEqual(createdTemplate?.applicableMachines, ["MACHINE_001", "MACHINE_002"])
        XCTAssertTrue(createdTemplate?.isActive ?? false)
    }
    
    func testFetchBatchTemplatesWithFilters() async throws {
        // Given - Test data already inserted
        
        // When - Fetch templates for specific machine
        let machineTemplates = try await batchRepository.fetchBatchTemplates(
            applicableToMachine: "MACHINE_001",
            priority: nil,
            isActive: true
        )
        
        // Then
        XCTAssertEqual(machineTemplates.count, 1)
        XCTAssertTrue(machineTemplates.first?.applicableMachines.contains("MACHINE_001") ?? false)
        
        // When - Fetch by priority
        let highPriorityTemplates = try await batchRepository.fetchBatchTemplates(
            applicableToMachine: nil,
            priority: .high,
            isActive: true
        )
        
        // Then
        XCTAssertTrue(highPriorityTemplates.allSatisfy { $0.priority == .high })
    }
    
    func testApplyBatchTemplate() async throws {
        // Given
        let template = try await batchRepository.fetchBatchTemplates().first!
        let machineIds = ["MACHINE_001", "MACHINE_002"]
        let targetDate = Date()
        let coordinatorId = "COORDINATOR_001"
        
        // When
        let createdBatches = try await batchRepository.applyTemplate(
            template,
            to: machineIds,
            targetDate: targetDate,
            coordinatorId: coordinatorId
        )
        
        // Then
        XCTAssertEqual(createdBatches.count, 2)
        XCTAssertEqual(Set(createdBatches.map { $0.deviceId }), Set(machineIds))
        
        // Verify each batch has template products
        for batch in createdBatches {
            XCTAssertEqual(batch.productConfigs.count, template.productTemplates.count)
        }
    }
    
    // MARK: - Approval Group Tests
    
    func testCreateApprovalGroup() async throws {
        // Given
        let group = createTestApprovalGroup(
            name: "测试批次组",
            targetDate: Date(),
            batchIds: ["BATCH_001", "BATCH_002"]
        )
        
        // When
        try await batchRepository.createApprovalGroup(group)
        
        // Then
        let fetchedGroups = try await batchRepository.fetchApprovalGroups(for: Date())
        XCTAssertEqual(fetchedGroups.count, 1)
        
        let createdGroup = fetchedGroups.first
        XCTAssertEqual(createdGroup?.groupName, "测试批次组")
        XCTAssertEqual(createdGroup?.batchIds.count, 2)
        XCTAssertEqual(createdGroup?.groupStatus, .draft)
    }
    
    func testAddAndRemoveBatchesFromGroup() async throws {
        // Given
        let group = createTestApprovalGroup(
            name: "测试组",
            targetDate: Date(),
            batchIds: ["BATCH_001"]
        )
        try await batchRepository.createApprovalGroup(group)
        
        // When - Add batches
        try await batchRepository.addBatches(
            batchIds: ["BATCH_002", "BATCH_003"],
            to: group.id
        )
        
        // Then
        let updatedGroup = try await batchRepository.fetchApprovalGroups(for: Date()).first!
        XCTAssertEqual(updatedGroup.batchIds.count, 3)
        XCTAssertTrue(updatedGroup.batchIds.contains("BATCH_002"))
        XCTAssertTrue(updatedGroup.batchIds.contains("BATCH_003"))
        
        // When - Remove batches
        try await batchRepository.removeBatches(
            batchIds: ["BATCH_002"],
            from: group.id
        )
        
        // Then
        let finalGroup = try await batchRepository.fetchApprovalGroups(for: Date()).first!
        XCTAssertEqual(finalGroup.batchIds.count, 2)
        XCTAssertFalse(finalGroup.batchIds.contains("BATCH_002"))
    }
    
    func testCreateOptimalBatchGroups() async throws {
        // Given
        let targetDate = Date()
        let coordinatorId = "COORDINATOR_001"
        
        // Create some test batches in the database
        let batch1 = createTestProductionBatch(deviceId: "MACHINE_001")
        let batch2 = createTestProductionBatch(deviceId: "MACHINE_002")
        modelContext.insert(batch1)
        modelContext.insert(batch2)
        try modelContext.save()
        
        // When
        let groups = try await batchRepository.createOptimalBatchGroups(
            for: targetDate,
            coordinatorId: coordinatorId
        )
        
        // Then
        XCTAssertGreaterThan(groups.count, 0)
        XCTAssertTrue(groups.allSatisfy { $0.coordinatorUserId == coordinatorId })
        XCTAssertTrue(groups.allSatisfy { Calendar.current.isDate($0.targetDate, inSameDayAs: targetDate) })
    }
    
    // MARK: - Machine Readiness Tests
    
    func testMachineReadinessOperations() async throws {
        // Given
        let machineId = "MACHINE_001"
        let targetDate = Date()
        let updatedBy = "TECHNICIAN_001"
        
        // When - Mark machine as ready
        try await batchRepository.markMachineAsReady(
            machineId: machineId,
            date: targetDate,
            updatedBy: updatedBy
        )
        
        // Then
        let readinessState = try await batchRepository.fetchMachineReadinessState(
            machineId: machineId,
            date: targetDate
        )
        
        XCTAssertNotNil(readinessState)
        XCTAssertEqual(readinessState?.readinessStatus, .ready)
        XCTAssertEqual(readinessState?.statusUpdatedBy, updatedBy)
        XCTAssertNotNil(readinessState?.actualReadyTime)
        
        // When - Mark machine in use
        try await batchRepository.markMachineInUse(
            machineId: machineId,
            batchId: "BATCH_001",
            date: targetDate
        )
        
        // Then
        let updatedState = try await batchRepository.fetchMachineReadinessState(
            machineId: machineId,
            date: targetDate
        )
        
        XCTAssertEqual(updatedState?.readinessStatus, .inUse)
        XCTAssertEqual(updatedState?.pendingBatchId, "BATCH_001")
    }
    
    func testFetchMachineReadinessStates() async throws {
        // Given
        let targetDate = Date()
        let states = [
            createTestMachineReadinessState(machineId: "MACHINE_001", date: targetDate, status: .ready),
            createTestMachineReadinessState(machineId: "MACHINE_002", date: targetDate, status: .notReady),
            createTestMachineReadinessState(machineId: "MACHINE_003", date: targetDate, status: .maintenance)
        ]
        
        for state in states {
            modelContext.insert(state)
        }
        try modelContext.save()
        
        // When
        let fetchedStates = try await batchRepository.fetchMachineReadinessStates(for: targetDate)
        
        // Then
        XCTAssertEqual(fetchedStates.count, 3)
        
        let readyMachines = fetchedStates.filter { $0.readinessStatus == .ready }
        XCTAssertEqual(readyMachines.count, 1)
        XCTAssertEqual(readyMachines.first?.machineId, "MACHINE_001")
    }
    
    // MARK: - Conflict Detection Tests
    
    func testConflictDetection() async throws {
        // Given
        let targetDate = Date()
        
        // Create overlapping machine states (conflict scenario)
        let state1 = createTestMachineReadinessState(
            machineId: "MACHINE_001",
            date: targetDate,
            status: .inUse
        )
        state1.pendingBatchId = "BATCH_001"
        state1.lastApprovedBatchId = "BATCH_002" // Conflict: different batches
        
        modelContext.insert(state1)
        try modelContext.save()
        
        // When
        let conflicts = try await batchRepository.detectMachineConflicts(for: targetDate)
        
        // Then
        XCTAssertGreaterThan(conflicts.count, 0)
        
        let machineConflicts = conflicts.filter { conflict in
            conflict.affectedMachineIds.contains("MACHINE_001")
        }
        XCTAssertGreaterThan(machineConflicts.count, 0)
    }
    
    func testAutoResolveConflicts() async throws {
        // Given
        let autoResolvableConflict = ConfigurationConflict(
            type: .stationOverlap,
            severity: .medium,
            description: "工位重叠冲突",
            affectedMachineIds: ["MACHINE_001"],
            suggestedResolution: "调整工位分配",
            canAutoResolve: true
        )
        
        // When
        let resolutions = try await batchRepository.autoResolveConflicts([autoResolvableConflict])
        
        // Then
        XCTAssertEqual(resolutions.count, 1)
        XCTAssertEqual(resolutions.first?.conflictType, .stationOverlap)
        XCTAssertEqual(resolutions.first?.resolutionStrategy, .automatic)
    }
    
    // MARK: - Batch Approval Tests
    
    func testBatchApprovalWorkflow() async throws {
        // Given
        let group = createTestApprovalGroup(
            name: "审批测试组",
            targetDate: Date(),
            batchIds: ["BATCH_001", "BATCH_002"]
        )
        try await batchRepository.createApprovalGroup(group)
        
        let approverUserId = "APPROVER_001"
        let notes = "测试审批备注"
        
        // When
        let result = try await batchRepository.batchApprove(
            groupId: group.id,
            approverUserId: approverUserId,
            notes: notes
        )
        
        // Then
        XCTAssertTrue(result.isFullySuccessful)
        XCTAssertEqual(result.approvedBatchIds.count, 2)
        XCTAssertTrue(result.failedBatchIds.isEmpty)
        XCTAssertGreaterThan(result.totalProcessingTime, 0)
        
        // Verify group status updated
        let updatedGroup = try await batchRepository.fetchApprovalGroups(for: Date()).first!
        XCTAssertEqual(updatedGroup.groupStatus, .fullyApproved)
        XCTAssertEqual(updatedGroup.approvedBy, approverUserId)
        XCTAssertNotNil(updatedGroup.approvedAt)
    }
    
    func testValidateNoDuplicateApprovals() async throws {
        // Given
        let targetDate = Date()
        let machineIds = ["MACHINE_001", "MACHINE_002"]
        
        // Create machine state with existing approval
        let state = createTestMachineReadinessState(
            machineId: "MACHINE_001",
            date: targetDate,
            status: .ready
        )
        state.lastApprovedBatchId = "EXISTING_BATCH"
        modelContext.insert(state)
        try modelContext.save()
        
        // When
        let duplicates = try await batchRepository.validateNoDuplicateApprovals(
            machineIds: machineIds,
            date: targetDate
        )
        
        // Then
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates.first, "MACHINE_001")
    }
    
    // MARK: - Security Integration Tests
    
    func testSecurityValidationInBatchOperations() async throws {
        // Test input validation for approval notes
        let invalidNotes = String(repeating: "A", count: 600) // Exceeds limit
        let validation = SecurityValidation.validateReviewNotes(invalidNotes)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertNotNil(validation.errorMessage)
        
        // Test valid notes
        let validNotes = "这是一个有效的审批备注"
        let validValidation = SecurityValidation.validateReviewNotes(validNotes)
        
        XCTAssertTrue(validValidation.isValid)
        XCTAssertNil(validValidation.errorMessage)
    }
    
    func testSessionValidationInCoordinator() async throws {
        // Given - Create valid session
        let userId = "TEST_USER"
        let token = sessionService.createSession(for: userId, userRole: .administrator)
        
        // When - Initiate workflow with valid session
        try await coordinator.initiateApprovalWorkflow(
            for: Date(),
            coordinatorId: userId
        )
        
        // Then
        XCTAssertNotNil(coordinator.currentWorkflow)
        XCTAssertEqual(coordinator.currentWorkflow?.coordinatorId, userId)
        
        // When - Invalidate session and try operation
        sessionService.invalidateSession()
        
        // Then - Should throw session expired error
        do {
            try await coordinator.processBatchApproval(
                groupId: "TEST_GROUP",
                approverUserId: userId
            )
            XCTFail("Expected session expired error")
        } catch BatchOperationError.sessionExpired {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBulkOperationPerformance() throws {
        // Measure performance of creating multiple batch templates
        measure {
            let expectation = XCTestExpectation(description: "Bulk template creation")
            
            Task {
                for i in 0..<50 {
                    let template = createTestBatchTemplate(
                        name: "性能测试模板_\(i)",
                        applicableMachines: ["MACHINE_\(i % 10)"]
                    )
                    
                    try await batchRepository.createBatchTemplate(template)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testConcurrentApprovalOperations() async throws {
        // Test concurrent approval operations
        let groups = (0..<5).map { i in
            createTestApprovalGroup(
                name: "并发测试组_\(i)",
                targetDate: Date(),
                batchIds: ["BATCH_\(i)_001"]
            )
        }
        
        // Create groups
        for group in groups {
            try await batchRepository.createApprovalGroup(group)
        }
        
        // Concurrent approval operations
        await withTaskGroup(of: Void.self) { taskGroup in
            for group in groups {
                taskGroup.addTask {
                    do {
                        _ = try await self.batchRepository.batchApprove(
                            groupId: group.id,
                            approverUserId: "CONCURRENT_APPROVER",
                            notes: "并发测试"
                        )
                    } catch {
                        print("Concurrent approval failed: \(error)")
                    }
                }
            }
        }
        
        // Verify all groups were processed
        let approvedGroups = try await batchRepository.fetchApprovalGroups(status: .fullyApproved)
        XCTAssertGreaterThanOrEqual(approvedGroups.count, groups.count)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyBatchGroupHandling() async throws {
        // Test creating group with no batches
        let emptyGroup = createTestApprovalGroup(
            name: "空批次组",
            targetDate: Date(),
            batchIds: []
        )
        
        try await batchRepository.createApprovalGroup(emptyGroup)
        
        // Attempt to approve empty group
        let result = try await batchRepository.batchApprove(
            groupId: emptyGroup.id,
            approverUserId: "APPROVER_001",
            notes: nil
        )
        
        XCTAssertTrue(result.approvedBatchIds.isEmpty)
        XCTAssertTrue(result.failedBatchIds.isEmpty)
        XCTAssertTrue(result.isFullySuccessful) // Empty group should be considered successful
    }
    
    func testInvalidMachineIdHandling() async throws {
        // Test applying template to non-existent machine
        let template = try await batchRepository.fetchBatchTemplates().first!
        let invalidMachineIds = ["INVALID_MACHINE_001"]
        
        // Should not throw error but create batches anyway
        let batches = try await batchRepository.applyTemplate(
            template,
            to: invalidMachineIds,
            targetDate: Date(),
            coordinatorId: "COORDINATOR_001"
        )
        
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches.first?.deviceId, "INVALID_MACHINE_001")
    }
    
    // MARK: - Helper Methods
    
    private func insertTestData() throws {
        // Insert test batch template
        let template = createTestBatchTemplate(
            name: "测试模板",
            applicableMachines: ["MACHINE_001", "MACHINE_002"]
        )
        modelContext.insert(template)
        
        // Insert test user
        let user = User(
            id: "TEST_USER",
            name: "测试用户",
            role: .administrator,
            isActive: true
        )
        modelContext.insert(user)
        
        try modelContext.save()
    }
    
    private func createTestBatchTemplate(
        name: String,
        applicableMachines: [String]
    ) -> BatchTemplate {
        let template = BatchTemplate(
            name: name,
            description: "测试用批次模板",
            createdBy: "TEST_USER",
            applicableMachines: applicableMachines,
            priority: .high
        )
        
        // Add test product templates
        let productTemplate = ProductTemplate(
            productId: "PRODUCT_001",
            productName: "测试产品",
            defaultColorId: "COLOR_001",
            defaultGunId: "GUN_001",
            defaultStationNumbers: [1, 2, 3]
        )
        template.productTemplates.append(productTemplate)
        
        return template
    }
    
    private func createTestApprovalGroup(
        name: String,
        targetDate: Date,
        batchIds: [String]
    ) -> ApprovalGroup {
        return ApprovalGroup(
            groupName: name,
            targetDate: targetDate,
            batchIds: batchIds,
            coordinatorUserId: "TEST_COORDINATOR"
        )
    }
    
    private func createTestMachineReadinessState(
        machineId: String,
        date: Date,
        status: MachineReadiness
    ) -> MachineReadinessState {
        return MachineReadinessState(
            machineId: machineId,
            targetDate: date,
            readinessStatus: status,
            statusUpdatedBy: "TEST_TECHNICIAN"
        )
    }
    
    private func createTestProductionBatch(deviceId: String) -> ProductionBatch {
        return ProductionBatch(
            deviceId: deviceId,
            productionMode: .automatic,
            coordinatorId: "TEST_COORDINATOR"
        )
    }
}

// MARK: - Mock Services

class MockProductionBatchService: ProductionBatchService {
    // Implement required ProductionBatchService methods for testing
    // This would be a simplified version for testing purposes
    
    override func submitBatch(_ batch: ProductionBatch) async throws {
        batch.isSubmitted = true
        batch.submittedAt = Date()
        batch.approvalStatus = .pending
    }
}

// MARK: - Test Extensions

extension BatchOperationTests {
    
    /// Tests the complete batch approval workflow from creation to approval
    func testCompleteWorkflowIntegration() async throws {
        // Given - Setup complete workflow
        let targetDate = Date()
        let coordinatorId = "WORKFLOW_COORDINATOR"
        
        // Create session
        let token = sessionService.createSession(for: coordinatorId, userRole: .administrator)
        XCTAssertTrue(sessionService.validateSession(token: token, userId: coordinatorId))
        
        // Initialize workflow
        try await coordinator.initiateApprovalWorkflow(
            for: targetDate,
            coordinatorId: coordinatorId
        )
        
        XCTAssertNotNil(coordinator.currentWorkflow)
        
        // Create optimal batch groups
        let groups = try await coordinator.createOptimalBatchGroups(coordinatorId: coordinatorId)
        XCTAssertGreaterThan(groups.count, 0)
        
        // Process approval for first group
        if let firstGroup = groups.first {
            let result = try await coordinator.processBatchApproval(
                groupId: firstGroup.id,
                approverUserId: coordinatorId,
                notes: "集成测试审批"
            )
            
            XCTAssertTrue(result.isFullySuccessful)
        }
        
        // Verify workflow completion
        let summary = coordinator.workflowSummary
        XCTAssertGreaterThanOrEqual(summary.approvedGroups, 0)
        XCTAssertNotNil(summary.workflowStatus)
    }
}

// MARK: - Performance and Load Testing

extension BatchOperationTests {
    
    func testHighVolumeDataHandling() async throws {
        // Test handling of large numbers of batches and machines
        let machineCount = 100
        let batchesPerMachine = 10
        
        // Create machine readiness states
        let targetDate = Date()
        for i in 0..<machineCount {
            let state = createTestMachineReadinessState(
                machineId: "LOAD_MACHINE_\(String(format: "%03d", i))",
                date: targetDate,
                status: .ready
            )
            modelContext.insert(state)
        }
        
        // Create batches
        var allBatchIds: [String] = []
        for i in 0..<machineCount {
            for j in 0..<batchesPerMachine {
                let batch = createTestProductionBatch(
                    deviceId: "LOAD_MACHINE_\(String(format: "%03d", i))"
                )
                batch.id = "LOAD_BATCH_\(i)_\(j)"
                allBatchIds.append(batch.id)
                modelContext.insert(batch)
            }
        }
        
        try modelContext.save()
        
        // Create large approval group
        let largeGroup = createTestApprovalGroup(
            name: "大容量测试组",
            targetDate: targetDate,
            batchIds: Array(allBatchIds.prefix(500)) // Test with 500 batches
        )
        
        // Measure performance
        let startTime = Date()
        try await batchRepository.createApprovalGroup(largeGroup)
        let creationTime = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time (< 2 seconds)
        XCTAssertLessThan(creationTime, 2.0)
        
        // Test fetching performance
        let fetchStartTime = Date()
        let fetchedStates = try await batchRepository.fetchMachineReadinessStates(for: targetDate)
        let fetchTime = Date().timeIntervalSince(fetchStartTime)
        
        XCTAssertEqual(fetchedStates.count, machineCount)
        XCTAssertLessThan(fetchTime, 1.0) // Should fetch quickly
    }
}

// MARK: - Error Handling Tests

extension BatchOperationTests {
    
    func testErrorRecoveryMechanisms() async throws {
        // Test recovery from various error conditions
        
        // 1. Test network/database error simulation
        // (In real implementation, you would mock network failures)
        
        // 2. Test validation error handling
        let invalidTemplate = createTestBatchTemplate(
            name: "", // Invalid empty name
            applicableMachines: []
        )
        
        // Should handle validation gracefully
        do {
            try await batchRepository.createBatchTemplate(invalidTemplate)
            // If no error thrown, verify the template was cleaned up or rejected
        } catch {
            // Expected behavior for invalid input
            XCTAssertTrue(error.localizedDescription.contains("验证") || 
                         error.localizedDescription.contains("validation"))
        }
        
        // 3. Test conflict resolution failure handling
        let unresolvableConflict = ConfigurationConflict(
            type: .machineUnavailable,
            severity: .critical,
            description: "设备完全故障",
            canAutoResolve: false
        )
        
        let resolutions = try await batchRepository.autoResolveConflicts([unresolvableConflict])
        XCTAssertTrue(resolutions.isEmpty) // Should not auto-resolve
    }
}