//
//  BatchCreationFlowTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest
@testable import Lopan

// MARK: - Batch Creation Flow Integration Tests (批次创建流程集成测试)
@MainActor
final class BatchCreationFlowTests: XCTestCase {
    
    var repositoryFactory: MockRepositoryFactory!
    var authService: MockAuthenticationService!
    var auditService: MockAuditingService!
    var batchService: ProductionBatchService!
    var validationService: BatchValidationService!
    var timeProvider: MockTimeProvider!
    var dateShiftPolicy: StandardDateShiftPolicy!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up test time (10:30 AM)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 10, minute: 30, second: 0
        )
        let testTime = calendar.date(from: components)!
        
        timeProvider = MockTimeProvider(fixedDate: testTime)
        dateShiftPolicy = StandardDateShiftPolicy(timeProvider: timeProvider)
        
        repositoryFactory = MockRepositoryFactory()
        
        let mockUser = User(
            name: "Workshop Manager",
            email: "workshop@example.com",
            role: .workshopManager,
            phone: "1234567890"
        )
        authService = MockAuthenticationService(mockUser: mockUser)
        auditService = MockAuditingService()
        
        batchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: authService
        )
        
        validationService = BatchValidationService(
            repositoryFactory: repositoryFactory,
            authService: authService,
            dateShiftPolicy: dateShiftPolicy,
            timeProvider: timeProvider
        )
    }
    
    override func tearDownWithError() throws {
        repositoryFactory = nil
        authService = nil
        auditService = nil
        batchService = nil
        validationService = nil
        timeProvider = nil
        dateShiftPolicy = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Happy Path Tests (正常流程测试)
    
    func testCompleteShiftBatchCreationFlow() async throws {
        // Given: Valid shift batch parameters
        let targetDate = timeProvider.now
        let shift = Shift.morning
        let machineId = "machine1"
        
        let productConfigs = [
            ProductConfig(
                batchId: "", // Will be set later
                productName: "Test Product",
                primaryColorId: "red",
                occupiedStations: [1, 2, 3]
            )
        ]
        
        // Step 1: Validate allowed shifts
        let allowedShifts = dateShiftPolicy.allowedShifts(for: targetDate, currentTime: timeProvider.now)
        XCTAssertTrue(allowedShifts.contains(shift))
        
        // Step 2: Check machine availability
        let mockRepo = repositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        mockRepo.mockHasConflict = false
        
        let isAvailable = await validationService.validateMachineAvailability(
            machineId: machineId,
            date: targetDate,
            shift: shift,
            excludingBatchId: nil
        )
        XCTAssertTrue(isAvailable)
        
        // Step 3: Create shift-aware batch
        let batch = await batchService.createShiftAwareBatch(
            machineId: machineId,
            targetDate: targetDate,
            shift: shift,
            products: productConfigs
        )
        
        // Step 4: Verify batch was created correctly
        XCTAssertEqual(batch.machineId, machineId)
        XCTAssertEqual(batch.targetDate, targetDate)
        XCTAssertEqual(batch.shift, shift)
        XCTAssertTrue(batch.allowsColorModificationOnly)
        XCTAssertEqual(batch.status, .unsubmitted)
        XCTAssertEqual(batch.products.count, 1)
        
        // Step 5: Validate the created batch
        let (issues, warnings) = await validationService.performComprehensiveValidation(for: batch)
        XCTAssertTrue(issues.isEmpty, "创建的批次应该通过验证")
        
        // Step 6: Verify audit trail
        XCTAssertEqual(auditService.loggedOperations.count, 1)
        let auditLog = auditService.loggedOperations.first!
        XCTAssertEqual(auditLog.operationType, .create)
        XCTAssertEqual(auditLog.entityType, "ProductionBatch")
    }
    
    func testLegacyBatchCreationFlow() async throws {
        // Given: Legacy batch parameters (no shift info)
        let machineId = "machine2"
        
        let productConfigs = [
            ProductConfig(
                batchId: "",
                productName: "Legacy Product",
                primaryColorId: "blue",
                occupiedStations: [1, 2]
            )
        ]
        
        // When: Creating production config batch
        let batch = await batchService.createProductionConfigBatch(
            machineId: machineId,
            mode: .singleColor,
            products: productConfigs
        )
        
        // Then: Verify production config batch properties
        XCTAssertEqual(batch.machineId, machineId)
        XCTAssertNil(batch.targetDate)
        XCTAssertNil(batch.shift)
        XCTAssertFalse(batch.allowsColorModificationOnly)
        XCTAssertEqual(batch.status, .unsubmitted)
        XCTAssertEqual(batch.products.count, 1)
        
        // Verify it's not considered a shift batch
        XCTAssertFalse(batch.isShiftBatch)
    }
    
    // MARK: - Validation Integration Tests (验证集成测试)
    
    func testBatchValidationIntegrationWithTimePolicy() async throws {
        // Given: Afternoon time (after cutoff)
        let afternoonComponents = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 0, second: 0
        )
        let afternoonTime = Calendar.current.date(from: afternoonComponents)!
        timeProvider.now = afternoonTime
        
        let targetDate = afternoonTime
        let invalidShift = Shift.morning // Invalid for afternoon
        
        // When: Trying to create batch with invalid shift
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: targetDate,
            shift: invalidShift,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Test Product",
                    primaryColorId: "red",
                    occupiedStations: [1]
                )
            ]
        )
        
        // Then: Validation should catch the invalid shift
        let (issues, _) = await validationService.performComprehensiveValidation(for: batch)
        XCTAssertTrue(issues.contains { !$0.isValid && $0.message.contains("班次") })
    }
    
    func testMachineConflictValidationIntegration() async throws {
        // Given: Existing batch on machine
        let existingBatch = ProductionBatch(
            machineId: "machine1",
            mode: .singleColor,
            submittedBy: "user1",
            submittedByName: "User 1",
            batchNumber: "B001"
        )
        existingBatch.targetDate = timeProvider.now
        existingBatch.shift = .morning
        
        let mockRepo = repositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        mockRepo.mockBatches = [existingBatch]
        mockRepo.mockHasConflict = true
        
        // When: Trying to create conflicting batch
        let conflictingBatch = await batchService.createShiftAwareBatch(
            machineId: "machine1", // Same machine
            targetDate: timeProvider.now, // Same date
            shift: .morning, // Same shift
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Conflicting Product",
                    primaryColorId: "blue",
                    occupiedStations: [1]
                )
            ]
        )
        
        // Then: Machine availability check should detect conflict
        let isAvailable = await validationService.validateMachineAvailability(
            machineId: "machine1",
            date: timeProvider.now,
            shift: .morning,
            excludingBatchId: conflictingBatch.id
        )
        XCTAssertFalse(isAvailable)
        
        // And validation should report the conflict
        let (issues, _) = await validationService.performComprehensiveValidation(for: conflictingBatch)
        XCTAssertTrue(issues.contains { !$0.isValid && $0.message.contains("冲突") })
    }
    
    // MARK: - Cross-Time-Point Operation Tests (跨时间点操作测试)
    
    func testCrossTimePointEditValidation() async throws {
        // Given: Batch created before cutoff
        let morningTime = Calendar.current.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 11, minute: 0, second: 0
        ))!
        
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: morningTime,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Morning Product",
                    primaryColorId: "red",
                    occupiedStations: [1]
                )
            ]
        )
        batch.submittedAt = morningTime
        
        // When: Time moves past cutoff
        let afternoonTime = Calendar.current.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 0, second: 0
        ))!
        timeProvider.now = afternoonTime
        
        // Then: Cross-time-point validation should detect time context change
        let result = await validationService.validateCrossTimePointOperation(
            batch: batch,
            operation: .edit
        )
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.reason.contains("时间"))
        XCTAssertNotNil(result.details)
    }
    
    // MARK: - End-to-End Workflow Tests (端到端工作流测试)
    
    func testCompleteWorkflowFromCreationToSubmission() async throws {
        // Step 1: Create shift-aware batch
        let targetDate = timeProvider.now
        let shift = Shift.morning
        let machineId = "machine1"
        
        let batch = await batchService.createShiftAwareBatch(
            machineId: machineId,
            targetDate: targetDate,
            shift: shift,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Workflow Product",
                    primaryColorId: "green",
                    occupiedStations: [1, 2]
                )
            ]
        )
        
        // Step 2: Validate batch
        let (preSubmissionIssues, _) = await validationService.performComprehensiveValidation(for: batch)
        XCTAssertTrue(preSubmissionIssues.isEmpty)
        
        // Step 3: Submit batch
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        XCTAssertEqual(submittedBatch.status, .pending)
        XCTAssertNotNil(submittedBatch.submittedAt)
        
        // Step 4: Validate submitted batch
        let (postSubmissionIssues, _) = await validationService.performComprehensiveValidation(for: submittedBatch)
        XCTAssertTrue(postSubmissionIssues.isEmpty)
        
        // Step 5: Verify audit trail for complete workflow
        let createOperation = auditService.loggedOperations.first { $0.operationType == .create }
        let submitOperation = auditService.loggedOperations.first { $0.operationType == .update }
        
        XCTAssertNotNil(createOperation)
        XCTAssertNotNil(submitOperation)
        XCTAssertTrue(submitOperation!.details.contains("提交"))
    }
    
    // MARK: - Error Recovery Tests (错误恢复测试)
    
    func testErrorRecoveryDuringBatchCreation() async throws {
        // Given: Repository that will fail
        let failingRepo = FailingMockRepository()
        let failingFactory = MockRepositoryFactory()
        failingFactory.productionBatchRepository = failingRepo
        
        let failingBatchService = ProductionBatchService(
            batchRepository: failingRepo,
            auditService: auditService,
            authService: authService
        )
        
        // When: Attempting to create batch with failing repository
        do {
            _ = await failingBatchService.createShiftAwareBatch(
                machineId: "machine1",
                targetDate: timeProvider.now,
                shift: .morning,
                products: [
                    ProductConfig(
                        batchId: "",
                        productName: "Failing Product",
                        primaryColorId: "red",
                        occupiedStations: [1]
                    )
                ]
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // Then: Error should be properly handled
            XCTAssertTrue(error.localizedDescription.contains("模拟错误"))
        }
        
        // Verify no partial state was created in audit log
        let createOperations = auditService.loggedOperations.filter { $0.operationType == .create }
        XCTAssertTrue(createOperations.isEmpty)
    }
    
    // MARK: - Performance Integration Tests (性能集成测试)
    
    func testBatchCreationPerformanceWithValidation() async throws {
        let batchCount = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<batchCount {
            let batch = await batchService.createShiftAwareBatch(
                machineId: "machine\(i % 3)", // Use 3 different machines
                targetDate: timeProvider.now,
                shift: i % 2 == 0 ? .morning : .evening,
                products: [
                    ProductConfig(
                        batchId: "",
                        productName: "Perf Product \(i)",
                        primaryColorId: "color\(i % 5)",
                        occupiedStations: [i % 10 + 1]
                    )
                ]
            )
            
            // Validate each batch
            let (issues, _) = await validationService.performComprehensiveValidation(for: batch)
            XCTAssertTrue(issues.isEmpty)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(duration, 5.0, "Batch creation and validation should complete within 5 seconds")
        
        // Verify all batches were created
        let mockRepo = repositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        XCTAssertEqual(mockRepo.mockBatches.count, batchCount)
    }
}

// MARK: - Mock Failing Repository (模拟失败的存储库)

private class FailingMockRepository: ProductionBatchRepository {
    func fetchAllBatches() async throws -> [ProductionBatch] {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟错误"])
    }
    
    func createBatch(_ batch: ProductionBatch) async throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟错误"])
    }
    
    func updateBatch(_ batch: ProductionBatch) async throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟错误"])
    }
    
    func deleteBatch(_ batchId: String) async throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟错误"])
    }
    
    func fetchBatch(byId id: String) async throws -> ProductionBatch? {
        return nil
    }
    
    func fetchBatches(forDate date: Date, shift: Shift) async throws -> [ProductionBatch] {
        return []
    }
    
    func fetchBatches(forDate date: Date) async throws -> [ProductionBatch] {
        return []
    }
    
    func fetchShiftAwareBatches() async throws -> [ProductionBatch] {
        return []
    }
    
    func fetchBatches(from startDate: Date, to endDate: Date, shift: Shift?) async throws -> [ProductionBatch] {
        return []
    }
    
    func hasConflictingBatches(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool {
        return false
    }
    
    func fetchBatchesRequiringMigration() async throws -> [ProductionBatch] {
        return []
    }
}

// MARK: - Mock Auditing Service (模拟审计服务)

private class MockAuditingService: NewAuditingService {
    var loggedOperations: [AuditLog] = []
    
    override func logOperation(
        operationType: AuditOperationType,
        entityType: String,
        entityId: String,
        details: String
    ) async {
        let auditLog = AuditLog(
            operationType: operationType,
            entityType: entityType,
            entityId: entityId,
            userId: "test_user",
            userName: "Test User",
            timestamp: Date(),
            details: details
        )
        loggedOperations.append(auditLog)
    }
}