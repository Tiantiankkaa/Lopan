//
//  BatchApprovalFlowTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest
@testable import Lopan

// MARK: - Batch Approval Flow Integration Tests (批次审批流程集成测试)
@MainActor
final class BatchApprovalFlowTests: XCTestCase {
    
    var repositoryFactory: MockRepositoryFactory!
    var workshopManagerAuth: MockAuthenticationService!
    var administratorAuth: MockAuthenticationService!
    var auditService: MockAuditingService!
    var batchService: ProductionBatchService!
    var validationService: BatchValidationService!
    var timeProvider: MockTimeProvider!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up test time
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 10, minute: 30, second: 0
        )
        let testTime = calendar.date(from: components)!
        timeProvider = MockTimeProvider(fixedDate: testTime)
        
        repositoryFactory = MockRepositoryFactory()
        auditService = MockAuditingService()
        
        // Create workshop manager user
        let workshopManager = User(
            name: "Workshop Manager",
            email: "workshop@example.com",
            role: .workshopManager,
            phone: "1234567890"
        )
        workshopManagerAuth = MockAuthenticationService(mockUser: workshopManager)
        
        // Create administrator user
        let administrator = User(
            name: "Administrator",
            email: "admin@example.com",
            role: .administrator,
            phone: "0987654321"
        )
        administratorAuth = MockAuthenticationService(mockUser: administrator)
        
        batchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: workshopManagerAuth
        )
        
        validationService = BatchValidationService(
            repositoryFactory: repositoryFactory,
            authService: workshopManagerAuth,
            dateShiftPolicy: StandardDateShiftPolicy(timeProvider: timeProvider),
            timeProvider: timeProvider
        )
    }
    
    override func tearDownWithError() throws {
        repositoryFactory = nil
        workshopManagerAuth = nil
        administratorAuth = nil
        auditService = nil
        batchService = nil
        validationService = nil
        timeProvider = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Complete Approval Workflow Tests (完整审批工作流测试)
    
    func testCompleteShiftBatchApprovalFlow() async throws {
        // Phase 1: Workshop Manager creates and submits batch
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: timeProvider.now,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Approval Test Product",
                    primaryColorId: "green",
                    occupiedStations: [1, 2, 3]
                )
            ]
        )
        
        // Validate and submit
        let (issues, _) = await validationService.performComprehensiveValidation(for: batch)
        XCTAssertTrue(issues.isEmpty)
        
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        XCTAssertEqual(submittedBatch.status, .pending)
        XCTAssertNotNil(submittedBatch.submittedAt)
        
        // Phase 2: Administrator reviews and approves batch
        let adminBatchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: administratorAuth
        )
        
        // Simulate administrator approval
        let approvalSummary = BatchApprovalSummary(
            batchId: submittedBatch.id,
            batchNumber: submittedBatch.batchNumber,
            shift: submittedBatch.shift!,
            targetDate: submittedBatch.targetDate!,
            machineId: submittedBatch.machineId,
            totalProducts: submittedBatch.products.count,
            estimatedDuration: 240, // 4 hours
            priority: .normal,
            riskFactors: [],
            recommendations: ["按计划执行"]
        )
        
        let approvedBatch = try await adminBatchService.approveBatch(
            batchId: submittedBatch.id,
            summary: approvalSummary
        )
        
        // Verify approval results
        XCTAssertEqual(approvedBatch.status, .approved)
        XCTAssertNotNil(approvedBatch.approvedAt)
        XCTAssertEqual(approvedBatch.approvedBy, administratorAuth.currentUser?.id)
        
        // Phase 3: Verify audit trail
        let createOperation = auditService.loggedOperations.first { $0.operationType == .create }
        let submitOperation = auditService.loggedOperations.first { $0.operationType == .update && $0.details.contains("提交") }
        let approvalOperation = auditService.loggedOperations.first { $0.operationType == .update && $0.details.contains("批准") }
        
        XCTAssertNotNil(createOperation)
        XCTAssertNotNil(submitOperation)
        XCTAssertNotNil(approvalOperation)
    }
    
    func testBatchRejectionFlow() async throws {
        // Create and submit batch
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: timeProvider.now,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Rejection Test Product",
                    primaryColorId: "red",
                    occupiedStations: [1]
                )
            ]
        )
        
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        
        // Administrator rejects batch
        let adminBatchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: administratorAuth
        )
        
        let rejectionReason = "生产配置需要调整，请重新配置产品参数"
        let rejectedBatch = try await adminBatchService.rejectBatch(
            batchId: submittedBatch.id,
            reason: rejectionReason
        )
        
        // Verify rejection results
        XCTAssertEqual(rejectedBatch.status, .rejected)
        XCTAssertNotNil(rejectedBatch.rejectedAt)
        XCTAssertEqual(rejectedBatch.rejectedBy, administratorAuth.currentUser?.id)
        XCTAssertEqual(rejectedBatch.rejectionReason, rejectionReason)
        
        // Verify rejection audit trail
        let rejectionOperation = auditService.loggedOperations.first { 
            $0.operationType == .update && $0.details.contains("拒绝")
        }
        XCTAssertNotNil(rejectionOperation)
        XCTAssertTrue(rejectionOperation!.details.contains(rejectionReason))
    }
    
    // MARK: - Cross-Time-Point Approval Tests (跨时间点审批测试)
    
    func testApprovalAfterTimeContextChange() async throws {
        // Create batch in morning context
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
                    productName: "Time Context Product",
                    primaryColorId: "blue",
                    occupiedStations: [1, 2]
                )
            ]
        )
        batch.submittedAt = morningTime
        
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        
        // Time moves to afternoon (past cutoff)
        let afternoonTime = Calendar.current.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 30, second: 0
        ))!
        timeProvider.now = afternoonTime
        
        // Administrator attempts approval in different time context
        let adminValidationService = BatchValidationService(
            repositoryFactory: repositoryFactory,
            authService: administratorAuth,
            dateShiftPolicy: StandardDateShiftPolicy(timeProvider: timeProvider),
            timeProvider: timeProvider
        )
        
        // Validate cross-time-point approval
        let crossTimeResult = await adminValidationService.validateCrossTimePointOperation(
            batch: submittedBatch,
            operation: .approve
        )
        
        // Should still be valid for approval (different rules than editing)
        if crossTimeResult.isValid {
            let adminBatchService = ProductionBatchService(
                batchRepository: repositoryFactory.productionBatchRepository,
                auditService: auditService,
                authService: administratorAuth
            )
            
            let approvalSummary = BatchApprovalSummary(
                batchId: submittedBatch.id,
                batchNumber: submittedBatch.batchNumber,
                shift: submittedBatch.shift!,
                targetDate: submittedBatch.targetDate!,
                machineId: submittedBatch.machineId,
                totalProducts: submittedBatch.products.count,
                estimatedDuration: 180,
                priority: .normal,
                riskFactors: ["跨时间点审批"],
                recommendations: ["注意时间上下文变化"]
            )
            
            let approvedBatch = try await adminBatchService.approveBatch(
                batchId: submittedBatch.id,
                summary: approvalSummary
            )
            
            XCTAssertEqual(approvedBatch.status, .approved)
        } else {
            // If not valid, should have appropriate reason
            XCTAssertTrue(crossTimeResult.reason.contains("时间") || crossTimeResult.reason.contains("上下文"))
        }
    }
    
    // MARK: - Batch Priority and Scheduling Tests (批次优先级和调度测试)
    
    func testBatchApprovalWithPriorityHandling() async throws {
        // Create multiple batches with different priorities
        let highPriorityBatch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: timeProvider.now,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "High Priority Product",
                    primaryColorId: "red",
                    occupiedStations: [1]
                )
            ]
        )
        
        let normalPriorityBatch = await batchService.createShiftAwareBatch(
            machineId: "machine2",
            targetDate: timeProvider.now,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Normal Priority Product",
                    primaryColorId: "blue",
                    occupiedStations: [1]
                )
            ]
        )
        
        // Submit both batches
        let submittedHighPriority = try await batchService.submitBatch(batchId: highPriorityBatch.id)
        let submittedNormalPriority = try await batchService.submitBatch(batchId: normalPriorityBatch.id)
        
        // Approve with different priorities
        let adminBatchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: administratorAuth
        )
        
        let highPrioritySummary = BatchApprovalSummary(
            batchId: submittedHighPriority.id,
            batchNumber: submittedHighPriority.batchNumber,
            shift: submittedHighPriority.shift!,
            targetDate: submittedHighPriority.targetDate!,
            machineId: submittedHighPriority.machineId,
            totalProducts: submittedHighPriority.products.count,
            estimatedDuration: 120,
            priority: .high,
            riskFactors: [],
            recommendations: ["优先执行"]
        )
        
        let normalPrioritySummary = BatchApprovalSummary(
            batchId: submittedNormalPriority.id,
            batchNumber: submittedNormalPriority.batchNumber,
            shift: submittedNormalPriority.shift!,
            targetDate: submittedNormalPriority.targetDate!,
            machineId: submittedNormalPriority.machineId,
            totalProducts: submittedNormalPriority.products.count,
            estimatedDuration: 180,
            priority: .normal,
            riskFactors: [],
            recommendations: ["按计划执行"]
        )
        
        let approvedHighPriority = try await adminBatchService.approveBatch(
            batchId: submittedHighPriority.id,
            summary: highPrioritySummary
        )
        
        let approvedNormalPriority = try await adminBatchService.approveBatch(
            batchId: submittedNormalPriority.id,
            summary: normalPrioritySummary
        )
        
        XCTAssertEqual(approvedHighPriority.status, .approved)
        XCTAssertEqual(approvedNormalPriority.status, .approved)
        
        // Verify audit logs capture priority information
        let highPriorityAudit = auditService.loggedOperations.first { 
            $0.entityId == approvedHighPriority.id && $0.details.contains("高优先级")
        }
        XCTAssertNotNil(highPriorityAudit)
    }
    
    // MARK: - Approval Validation Tests (审批验证测试)
    
    func testApprovalValidationWithRiskFactors() async throws {
        // Create batch with potential risk factors
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: timeProvider.now,
            shift: .evening, // Evening shift might be riskier
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Risk Factor Product",
                    primaryColorId: "yellow",
                    occupiedStations: [1, 2, 3, 4, 5] // Many stations
                )
            ]
        )
        
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        
        // Administrator approval with risk assessment
        let adminBatchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: administratorAuth
        )
        
        let riskySummary = BatchApprovalSummary(
            batchId: submittedBatch.id,
            batchNumber: submittedBatch.batchNumber,
            shift: submittedBatch.shift!,
            targetDate: submittedBatch.targetDate!,
            machineId: submittedBatch.machineId,
            totalProducts: submittedBatch.products.count,
            estimatedDuration: 300,
            priority: .normal,
            riskFactors: ["晚班生产", "占用工位过多", "预计耗时较长"],
            recommendations: ["加强监控", "准备备用方案", "确保人员充足"]
        )
        
        let approvedBatch = try await adminBatchService.approveBatch(
            batchId: submittedBatch.id,
            summary: riskySummary
        )
        
        XCTAssertEqual(approvedBatch.status, .approved)
        
        // Verify risk factors are captured in audit
        let riskAudit = auditService.loggedOperations.first {
            $0.entityId == approvedBatch.id && 
            ($0.details.contains("风险") || $0.details.contains("晚班"))
        }
        XCTAssertNotNil(riskAudit)
    }
    
    // MARK: - Permission and Role Tests (权限和角色测试)
    
    func testWorkshopManagerCannotApproveBatches() async throws {
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: timeProvider.now,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Permission Test Product",
                    primaryColorId: "purple",
                    occupiedStations: [1]
                )
            ]
        )
        
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        
        // Workshop manager attempts to approve (should fail)
        let approvalSummary = BatchApprovalSummary(
            batchId: submittedBatch.id,
            batchNumber: submittedBatch.batchNumber,
            shift: submittedBatch.shift!,
            targetDate: submittedBatch.targetDate!,
            machineId: submittedBatch.machineId,
            totalProducts: submittedBatch.products.count,
            estimatedDuration: 120,
            priority: .normal,
            riskFactors: [],
            recommendations: []
        )
        
        do {
            _ = try await batchService.approveBatch(
                batchId: submittedBatch.id,
                summary: approvalSummary
            )
            XCTFail("Workshop manager should not be able to approve batches")
        } catch {
            // Expected failure
            XCTAssertTrue(error.localizedDescription.contains("权限") || 
                         error.localizedDescription.contains("permission"))
        }
    }
    
    func testOnlyAdministratorCanApproveBatches() async throws {
        let batch = await batchService.createShiftAwareBatch(
            machineId: "machine1",
            targetDate: timeProvider.now,
            shift: .morning,
            products: [
                ProductConfig(
                    batchId: "",
                    productName: "Admin Only Product",
                    primaryColorId: "gold",
                    occupiedStations: [1]
                )
            ]
        )
        
        let submittedBatch = try await batchService.submitBatch(batchId: batch.id)
        
        // Administrator can approve
        let adminBatchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: administratorAuth
        )
        
        let approvalSummary = BatchApprovalSummary(
            batchId: submittedBatch.id,
            batchNumber: submittedBatch.batchNumber,
            shift: submittedBatch.shift!,
            targetDate: submittedBatch.targetDate!,
            machineId: submittedBatch.machineId,
            totalProducts: submittedBatch.products.count,
            estimatedDuration: 150,
            priority: .normal,
            riskFactors: [],
            recommendations: []
        )
        
        let approvedBatch = try await adminBatchService.approveBatch(
            batchId: submittedBatch.id,
            summary: approvalSummary
        )
        
        XCTAssertEqual(approvedBatch.status, .approved)
        XCTAssertEqual(approvedBatch.approvedBy, administratorAuth.currentUser?.id)
    }
    
    // MARK: - Performance and Load Tests (性能和负载测试)
    
    func testBulkApprovalPerformance() async throws {
        let batchCount = 5
        var submittedBatches: [ProductionBatch] = []
        
        // Create and submit multiple batches
        for i in 0..<batchCount {
            let batch = await batchService.createShiftAwareBatch(
                machineId: "machine\(i % 2 + 1)",
                targetDate: timeProvider.now,
                shift: i % 2 == 0 ? .morning : .evening,
                products: [
                    ProductConfig(
                        batchId: "",
                        productName: "Bulk Test Product \(i)",
                        primaryColorId: "color\(i)",
                        occupiedStations: [i % 5 + 1]
                    )
                ]
            )
            
            let submitted = try await batchService.submitBatch(batchId: batch.id)
            submittedBatches.append(submitted)
        }
        
        // Measure bulk approval performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let adminBatchService = ProductionBatchService(
            batchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: administratorAuth
        )
        
        for (index, batch) in submittedBatches.enumerated() {
            let summary = BatchApprovalSummary(
                batchId: batch.id,
                batchNumber: batch.batchNumber,
                shift: batch.shift!,
                targetDate: batch.targetDate!,
                machineId: batch.machineId,
                totalProducts: batch.products.count,
                estimatedDuration: 120 + (index * 30),
                priority: .normal,
                riskFactors: [],
                recommendations: []
            )
            
            let approved = try await adminBatchService.approveBatch(
                batchId: batch.id,
                summary: summary
            )
            
            XCTAssertEqual(approved.status, .approved)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(duration, 10.0, "Bulk approval should complete within 10 seconds")
        
        // Verify all approvals were logged
        let approvalOperations = auditService.loggedOperations.filter { 
            $0.operationType == .update && $0.details.contains("批准")
        }
        XCTAssertEqual(approvalOperations.count, batchCount)
    }
}