//
//  BatchValidationServiceTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest
@testable import Lopan

// MARK: - Mock Repository Factory (模拟Repository工厂)
class MockRepositoryFactory: RepositoryFactory {
    var productionBatchRepository: ProductionBatchRepository = MockProductionBatchRepository()
    var machineRepository: MachineRepository = MockMachineRepository()
    var colorRepository: ColorRepository = MockColorRepository()
    var userRepository: UserRepository = MockUserRepository()
    var customerOutOfStockRepository: CustomerOutOfStockRepository = MockCustomerOutOfStockRepository()
    var packagingRepository: PackagingRepository = MockPackagingRepository()
}

// MARK: - Mock Production Batch Repository (模拟生产批次Repository)
class MockProductionBatchRepository: ProductionBatchRepository {
    var mockBatches: [ProductionBatch] = []
    var mockHasConflict = false
    
    func fetchAllBatches() async throws -> [ProductionBatch] {
        return mockBatches
    }
    
    func createBatch(_ batch: ProductionBatch) async throws {
        mockBatches.append(batch)
    }
    
    func updateBatch(_ batch: ProductionBatch) async throws {
        // Mock implementation
    }
    
    func deleteBatch(_ batchId: String) async throws {
        mockBatches.removeAll { $0.id == batchId }
    }
    
    func fetchBatch(byId id: String) async throws -> ProductionBatch? {
        return mockBatches.first { $0.id == id }
    }
    
    func fetchBatches(forDate date: Date, shift: Shift) async throws -> [ProductionBatch] {
        return mockBatches.filter { batch in
            batch.targetDate != nil && batch.shift == shift &&
            Calendar.current.isDate(batch.targetDate!, inSameDayAs: date)
        }
    }
    
    func fetchBatches(forDate date: Date) async throws -> [ProductionBatch] {
        return mockBatches.filter { batch in
            batch.targetDate != nil &&
            Calendar.current.isDate(batch.targetDate!, inSameDayAs: date)
        }
    }
    
    func fetchShiftAwareBatches() async throws -> [ProductionBatch] {
        return mockBatches.filter { $0.targetDate != nil && $0.shift != nil }
    }
    
    func fetchBatches(from startDate: Date, to endDate: Date, shift: Shift?) async throws -> [ProductionBatch] {
        return mockBatches.filter { batch in
            guard let targetDate = batch.targetDate else { return false }
            let inDateRange = targetDate >= startDate && targetDate <= endDate
            if let shift = shift {
                return inDateRange && batch.shift == shift
            }
            return inDateRange
        }
    }
    
    func hasConflictingBatches(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool {
        return mockHasConflict
    }
    
    func fetchBatchesRequiringMigration() async throws -> [ProductionBatch] {
        return mockBatches.filter { $0.targetDate == nil || $0.shift == nil }
    }
}

// MARK: - Additional Mock Repositories (其他模拟Repository)
class MockMachineRepository: MachineRepository {
    func fetchAllMachines() async throws -> [WorkshopMachine] { return [] }
    func createMachine(_ machine: WorkshopMachine) async throws {}
    func updateMachine(_ machine: WorkshopMachine) async throws {}
    func deleteMachine(_ machineId: String) async throws {}
    func fetchMachine(byId id: String) async throws -> WorkshopMachine? { return nil }
}

class MockColorRepository: ColorRepository {
    func fetchAllColors() async throws -> [ColorCard] { return [] }
    func createColor(_ color: ColorCard) async throws {}
    func updateColor(_ color: ColorCard) async throws {}
    func deleteColor(_ colorId: String) async throws {}
    func fetchColor(byId id: String) async throws -> ColorCard? { return nil }
}

class MockUserRepository: UserRepository {
    func fetchAllUsers() async throws -> [User] { return [] }
    func createUser(_ user: User) async throws {}
    func updateUser(_ user: User) async throws {}
    func deleteUser(_ userId: String) async throws {}
    func fetchUser(byId id: String) async throws -> User? { return nil }
}

class MockCustomerOutOfStockRepository: CustomerOutOfStockRepository {
    func fetchAllCustomerOutOfStocks() async throws -> [CustomerOutOfStock] { return [] }
    func createCustomerOutOfStock(_ item: CustomerOutOfStock) async throws {}
    func updateCustomerOutOfStock(_ item: CustomerOutOfStock) async throws {}
    func deleteCustomerOutOfStock(_ itemId: String) async throws {}
    func fetchCustomerOutOfStock(byId id: String) async throws -> CustomerOutOfStock? { return nil }
}

class MockPackagingRepository: PackagingRepository {
    func fetchAllPackagingRecords() async throws -> [PackagingRecord] { return [] }
    func createPackagingRecord(_ record: PackagingRecord) async throws {}
    func updatePackagingRecord(_ record: PackagingRecord) async throws {}
    func deletePackagingRecord(_ recordId: String) async throws {}
}

// MARK: - BatchValidationService Unit Tests (批次验证服务单元测试)
@MainActor
final class BatchValidationServiceTests: XCTestCase {
    
    var sut: BatchValidationService!
    var mockRepositoryFactory: MockRepositoryFactory!
    var mockAuthService: MockAuthenticationService!
    var mockTimeProvider: MockTimeProvider!
    var mockDateShiftPolicy: StandardDateShiftPolicy!
    var mockBatch: ProductionBatch!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test date (10:30 AM)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 10, minute: 30, second: 0
        )
        let testDate = calendar.date(from: components)!
        
        mockTimeProvider = MockTimeProvider(fixedDate: testDate)
        mockDateShiftPolicy = StandardDateShiftPolicy(timeProvider: mockTimeProvider)
        mockRepositoryFactory = MockRepositoryFactory()
        mockAuthService = MockAuthenticationService(mockUser: User(
            name: "Test User",
            email: "test@example.com",
            role: .workshopManager,
            phone: "1234567890"
        ))
        
        sut = BatchValidationService(
            repositoryFactory: mockRepositoryFactory,
            authService: mockAuthService,
            dateShiftPolicy: mockDateShiftPolicy,
            timeProvider: mockTimeProvider
        )
        
        // Create mock batch
        mockBatch = ProductionBatch(
            machineId: "machine1",
            mode: .singleColor,
            submittedBy: "test_user",
            submittedByName: "Test User",
            batchNumber: "B001"
        )
        mockBatch.targetDate = testDate
        mockBatch.shift = .morning
        mockBatch.submittedAt = testDate
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockRepositoryFactory = nil
        mockAuthService = nil
        mockTimeProvider = nil
        mockDateShiftPolicy = nil
        mockBatch = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Cross-Time-Point Validation Tests (跨时间点验证测试)
    
    func testValidateCrossTimePointOperation_EditOperation_BeforeCutoff_ShouldBeValid() async throws {
        // Given: Current time is before cutoff (10:30 AM) and batch created at same time
        mockBatch.submittedAt = mockTimeProvider.now
        
        // When: Validating cross-time-point edit operation
        let result = await sut.validateCrossTimePointOperation(
            batch: mockBatch,
            operation: .edit
        )
        
        // Then: Should be valid (same time context)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.recommendedAction, .allowOperation)
    }
    
    func testValidateCrossTimePointOperation_EditOperation_AfterCutoff_ShouldHaveRestrictions() async throws {
        // Given: Batch created before cutoff, but now we're after cutoff
        let calendar = Calendar.current
        let morningTime = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 11, minute: 0, second: 0
        ))!
        let afternoonTime = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 0, second: 0
        ))!
        
        mockBatch.submittedAt = morningTime
        mockTimeProvider.now = afternoonTime
        
        // When: Validating cross-time-point edit operation
        let result = await sut.validateCrossTimePointOperation(
            batch: mockBatch,
            operation: .edit
        )
        
        // Then: Should have restrictions due to time context change
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.reason.contains("时间"))
        XCTAssertNotEqual(result.recommendedAction, .allowOperation)
    }
    
    func testValidateCrossTimePointOperation_SubmitOperation_ShouldValidateCurrentTimeContext() async throws {
        // Given: Batch with appropriate shift info
        mockBatch.submittedAt = mockTimeProvider.now
        
        // When: Validating submit operation
        let result = await sut.validateCrossTimePointOperation(
            batch: mockBatch,
            operation: .submit
        )
        
        // Then: Should validate based on current time context
        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.details)
    }
    
    func testValidateCrossTimePointOperation_MissingBatchInfo_ShouldBeInvalid() async throws {
        // Given: Batch without required shift info
        mockBatch.targetDate = nil
        mockBatch.shift = nil
        
        // When: Validating operation
        let result = await sut.validateCrossTimePointOperation(
            batch: mockBatch,
            operation: .edit
        )
        
        // Then: Should be invalid due to missing info
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.reason.contains("时间信息"))
    }
    
    // MARK: - Batch Validation Tests (批次验证测试)
    
    func testValidateBatch_ValidShiftBatch_ShouldPass() async throws {
        // Given: Valid shift-aware batch
        mockBatch.targetDate = mockTimeProvider.now
        mockBatch.shift = .morning
        mockBatch.status = .unsubmitted
        
        // Add a product config
        let productConfig = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "red",
            occupiedStations: [1, 2, 3]
        )
        mockBatch.products = [productConfig]
        
        // When: Validating batch
        let results = await sut.validateBatch(mockBatch)
        
        // Then: Should pass validation
        XCTAssertTrue(results.allSatisfy { $0.isValid })
    }
    
    func testValidateBatch_EmptyProductList_ShouldFail() async throws {
        // Given: Batch without products
        mockBatch.products = []
        
        // When: Validating batch
        let results = await sut.validateBatch(mockBatch)
        
        // Then: Should fail validation
        XCTAssertTrue(results.contains { !$0.isValid && $0.message.contains("产品") })
    }
    
    func testValidateBatch_InvalidShiftSelection_ShouldFail() async throws {
        // Given: Batch with morning shift but current time is after cutoff
        let afternoonTime = Calendar.current.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 0, second: 0
        ))!
        mockTimeProvider.now = afternoonTime
        
        mockBatch.targetDate = afternoonTime
        mockBatch.shift = .morning // Invalid choice for afternoon
        
        // When: Validating batch
        let results = await sut.validateBatch(mockBatch)
        
        // Then: Should fail validation
        XCTAssertTrue(results.contains { !$0.isValid && $0.message.contains("班次") })
    }
    
    // MARK: - Machine Conflict Tests (设备冲突测试)
    
    func testValidateMachineAvailability_NoConflict_ShouldPass() async throws {
        // Given: No conflicting batches
        let mockRepo = mockRepositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        mockRepo.mockHasConflict = false
        
        // When: Validating machine availability
        let isAvailable = await sut.validateMachineAvailability(
            machineId: "machine1",
            date: mockTimeProvider.now,
            shift: .morning,
            excludingBatchId: nil
        )
        
        // Then: Should be available
        XCTAssertTrue(isAvailable)
    }
    
    func testValidateMachineAvailability_HasConflict_ShouldFail() async throws {
        // Given: Conflicting batches exist
        let mockRepo = mockRepositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        mockRepo.mockHasConflict = true
        
        // When: Validating machine availability
        let isAvailable = await sut.validateMachineAvailability(
            machineId: "machine1",
            date: mockTimeProvider.now,
            shift: .morning,
            excludingBatchId: nil
        )
        
        // Then: Should not be available
        XCTAssertFalse(isAvailable)
    }
    
    // MARK: - Comprehensive Validation Tests (综合验证测试)
    
    func testPerformComprehensiveValidation_AllValid_ShouldPass() async throws {
        // Given: Valid batch setup
        mockBatch.targetDate = mockTimeProvider.now
        mockBatch.shift = .morning
        mockBatch.status = .unsubmitted
        
        let productConfig = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "red",
            occupiedStations: [1, 2, 3]
        )
        mockBatch.products = [productConfig]
        
        let mockRepo = mockRepositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        mockRepo.mockHasConflict = false
        
        // When: Performing comprehensive validation
        let (issues, warnings) = await sut.performComprehensiveValidation(for: mockBatch)
        
        // Then: Should have no critical issues
        XCTAssertTrue(issues.isEmpty)
        XCTAssertTrue(warnings.count <= 1) // May have info warnings
    }
    
    func testPerformComprehensiveValidation_MultipleIssues_ShouldReportAll() async throws {
        // Given: Batch with multiple issues
        mockBatch.products = [] // Missing products
        mockBatch.targetDate = nil // Missing date
        mockBatch.shift = nil // Missing shift
        
        let mockRepo = mockRepositoryFactory.productionBatchRepository as! MockProductionBatchRepository
        mockRepo.mockHasConflict = true // Machine conflict
        
        // When: Performing comprehensive validation
        let (issues, warnings) = await sut.performComprehensiveValidation(for: mockBatch)
        
        // Then: Should report multiple issues
        XCTAssertGreaterThan(issues.count, 1)
        XCTAssertTrue(issues.contains { $0.message.contains("产品") })
        XCTAssertTrue(issues.contains { $0.message.contains("日期") || $0.message.contains("班次") })
    }
    
    // MARK: - Time Context Validation Tests (时间上下文验证测试)
    
    func testValidateTimeContext_SameContext_ShouldPass() async throws {
        // Given: Creation time and current time in same context (both before cutoff)
        let creationTime = mockTimeProvider.now
        let currentTime = mockTimeProvider.now
        
        // When: Validating time context
        let result = await sut.validateCrossTimePointOperation(
            batch: mockBatch,
            operation: .edit
        )
        
        // Then: Should pass
        XCTAssertTrue(result.isValid)
    }
    
    func testValidateTimeContext_DifferentContext_ShouldHaveRestrictions() async throws {
        // Given: Creation time before cutoff, current time after cutoff
        let morningTime = Calendar.current.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 11, minute: 0, second: 0
        ))!
        let afternoonTime = Calendar.current.date(from: DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 0, second: 0
        ))!
        
        mockBatch.submittedAt = morningTime
        mockTimeProvider.now = afternoonTime
        
        // When: Validating time context
        let result = await sut.validateCrossTimePointOperation(
            batch: mockBatch,
            operation: .edit
        )
        
        // Then: Should have restrictions
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.details)
        XCTAssertNotNil(result.details?.availableShifts)
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testValidationPerformance() async throws {
        // Given: Setup batch with reasonable complexity
        mockBatch.targetDate = mockTimeProvider.now
        mockBatch.shift = .morning
        mockBatch.status = .unsubmitted
        
        let productConfigs = (1...5).map { i in
            ProductConfig(
                batchId: mockBatch.id,
                productName: "Product \(i)",
                primaryColorId: "color\(i)",
                occupiedStations: [i, i+1, i+2]
            )
        }
        mockBatch.products = productConfigs
        
        // When: Measuring validation performance
        await measure {
            Task {
                let _ = await sut.validateBatch(mockBatch)
                let _ = await sut.performComprehensiveValidation(for: mockBatch)
            }
        }
    }
}