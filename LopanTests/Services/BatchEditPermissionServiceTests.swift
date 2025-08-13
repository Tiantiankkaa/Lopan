//
//  BatchEditPermissionServiceTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest
@testable import Lopan

// MARK: - Mock Authentication Service (模拟认证服务)
class MockAuthenticationService: AuthenticationService {
    var currentUser: User?
    
    init(mockUser: User?) {
        self.currentUser = mockUser
    }
    
    func login(userId: String, password: String) async throws -> Bool {
        return true
    }
    
    func logout() {
        currentUser = nil
    }
    
    func hasPermission(_ permission: String) -> Bool {
        return true
    }
}

// MARK: - BatchEditPermissionService Unit Tests (批次编辑权限服务单元测试)
@MainActor
final class BatchEditPermissionServiceTests: XCTestCase {
    
    var sut: StandardBatchEditPermissionService!
    var mockAuthService: MockAuthenticationService!
    var mockUser: User!
    var mockBatch: ProductionBatch!
    var mockProduct: ProductConfig!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create mock user with appropriate permissions
        mockUser = User(
            name: "Test User",
            email: "test@example.com",
            role: .workshopManager,
            phone: "1234567890"
        )
        
        mockAuthService = MockAuthenticationService(mockUser: mockUser)
        sut = StandardBatchEditPermissionService(authService: mockAuthService)
        
        // Create mock batch
        mockBatch = ProductionBatch(
            machineId: "machine1",
            mode: .singleColor,
            submittedBy: "test_user",
            submittedByName: "Test User",
            batchNumber: "B001"
        )
        
        // Create mock product config
        mockProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "red",
            occupiedStations: [1, 2, 3]
        )
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockAuthService = nil
        mockUser = nil
        mockBatch = nil
        mockProduct = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Permission Tests (基础权限测试)
    
    func testCanEditProduct_WithValidUser_ShouldReturnTrue() throws {
        // Given: Valid user and unsubmitted batch
        mockBatch.status = .unsubmitted
        
        // When: Checking edit permission
        let canEdit = sut.canEditProduct(mockProduct, in: mockBatch)
        
        // Then: Should allow editing
        XCTAssertTrue(canEdit)
    }
    
    func testCanEditProduct_WithSubmittedBatch_ShouldReturnFalse() throws {
        // Given: Submitted batch
        mockBatch.status = .pending
        
        // When: Checking edit permission
        let canEdit = sut.canEditProduct(mockProduct, in: mockBatch)
        
        // Then: Should not allow editing
        XCTAssertFalse(canEdit)
    }
    
    func testCanEditProduct_WithNoUser_ShouldReturnFalse() throws {
        // Given: No authenticated user
        mockAuthService.currentUser = nil
        
        // When: Checking edit permission
        let canEdit = sut.canEditProduct(mockProduct, in: mockBatch)
        
        // Then: Should not allow editing
        XCTAssertFalse(canEdit)
    }
    
    // MARK: - Shift-aware Batch Tests (班次感知批次测试)
    
    func testCanEditProduct_ShiftBatch_ShouldRespectColorOnlyRestriction() throws {
        // Given: Shift-aware batch with color-only restriction
        mockBatch.targetDate = Date()
        mockBatch.shift = .morning
        mockBatch.allowsColorModificationOnly = true
        mockBatch.status = .unsubmitted
        
        // When: Checking edit permission
        let canEdit = sut.canEditProduct(mockProduct, in: mockBatch)
        
        // Then: Should still allow editing (color changes are allowed)
        XCTAssertTrue(canEdit)
    }
    
    func testGetEditRestrictionReason_ShiftBatch_ShouldReturnColorOnlyMessage() throws {
        // Given: Shift-aware batch with color-only restriction
        mockBatch.targetDate = Date()
        mockBatch.shift = .morning
        mockBatch.allowsColorModificationOnly = true
        mockBatch.status = .unsubmitted
        
        // When: Getting restriction reason
        let reason = sut.getEditRestrictionReason(for: mockBatch)
        
        // Then: Should return color-only restriction message
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("颜色修改"))
    }
    
    func testGetEditRestrictionReason_LegacyBatch_ShouldReturnNil() throws {
        // Given: Legacy batch (no shift info)
        mockBatch.targetDate = nil
        mockBatch.shift = nil
        mockBatch.status = .unsubmitted
        
        // When: Getting restriction reason
        let reason = sut.getEditRestrictionReason(for: mockBatch)
        
        // Then: Should not have restrictions
        XCTAssertNil(reason)
    }
    
    // MARK: - Validation Tests (验证测试)
    
    func testValidateEdit_ColorOnlyChange_ShouldBeAllowed() throws {
        // Given: Shift batch with color-only restriction
        mockBatch.targetDate = Date()
        mockBatch.shift = .morning
        mockBatch.allowsColorModificationOnly = true
        mockBatch.status = .unsubmitted
        
        let originalProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "red",
            occupiedStations: [1, 2, 3]
        )
        
        let modifiedProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product", // Same name
            primaryColorId: "blue", // Different color
            occupiedStations: [1, 2, 3] // Same stations
        )
        
        // When: Validating edit
        let result = sut.validateEdit(
            originalProduct: originalProduct,
            modifiedProduct: modifiedProduct,
            in: mockBatch
        )
        
        // Then: Should be allowed
        XCTAssertEqual(result, .allowed)
    }
    
    func testValidateEdit_StructuralChange_ShouldBeColorOnlyAllowed() throws {
        // Given: Shift batch with color-only restriction
        mockBatch.targetDate = Date()
        mockBatch.shift = .morning
        mockBatch.allowsColorModificationOnly = true
        mockBatch.status = .unsubmitted
        
        let originalProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "red",
            occupiedStations: [1, 2, 3]
        )
        
        let modifiedProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Modified Product", // Different name (structural)
            primaryColorId: "red", // Same color
            occupiedStations: [1, 2, 3] // Same stations
        )
        
        // When: Validating edit
        let result = sut.validateEdit(
            originalProduct: originalProduct,
            modifiedProduct: modifiedProduct,
            in: mockBatch
        )
        
        // Then: Should be color-only allowed
        if case .colorOnlyAllowed(let reason) = result {
            XCTAssertTrue(reason.contains("颜色修改"))
        } else {
            XCTFail("Expected .colorOnlyAllowed result")
        }
    }
    
    func testValidateEdit_NoPermission_ShouldBeBlocked() throws {
        // Given: No authenticated user
        mockAuthService.currentUser = nil
        
        let originalProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "red",
            occupiedStations: [1, 2, 3]
        )
        
        let modifiedProduct = ProductConfig(
            batchId: mockBatch.id,
            productName: "Test Product",
            primaryColorId: "blue",
            occupiedStations: [1, 2, 3]
        )
        
        // When: Validating edit
        let result = sut.validateEdit(
            originalProduct: originalProduct,
            modifiedProduct: modifiedProduct,
            in: mockBatch
        )
        
        // Then: Should be blocked
        if case .blocked(let reason) = result {
            XCTAssertTrue(reason.contains("权限"))
        } else {
            XCTFail("Expected .blocked result")
        }
    }
    
    // MARK: - Color Modification Detection Tests (颜色修改检测测试)
    
    func testIsOnlyColorModification_SameProductDifferentColor_ShouldReturnTrue() throws {
        let original = ProductConfig(
            batchId: "batch1",
            productName: "Product A",
            primaryColorId: "red",
            occupiedStations: [1, 2]
        )
        
        let modified = ProductConfig(
            batchId: "batch1",
            productName: "Product A", // Same
            primaryColorId: "blue", // Different
            occupiedStations: [1, 2] // Same
        )
        
        // When: Checking if only color changed
        let isOnlyColor = sut.isOnlyColorModification(original: original, modified: modified)
        
        // Then: Should detect as color-only change
        XCTAssertTrue(isOnlyColor)
    }
    
    func testIsOnlyColorModification_DifferentProductName_ShouldReturnFalse() throws {
        let original = ProductConfig(
            batchId: "batch1",
            productName: "Product A",
            primaryColorId: "red",
            occupiedStations: [1, 2]
        )
        
        let modified = ProductConfig(
            batchId: "batch1",
            productName: "Product B", // Different
            primaryColorId: "red", // Same
            occupiedStations: [1, 2] // Same
        )
        
        // When: Checking if only color changed
        let isOnlyColor = sut.isOnlyColorModification(original: original, modified: modified)
        
        // Then: Should not detect as color-only change
        XCTAssertFalse(isOnlyColor)
    }
    
    func testIsOnlyColorModification_DifferentStations_ShouldReturnFalse() throws {
        let original = ProductConfig(
            batchId: "batch1",
            productName: "Product A",
            primaryColorId: "red",
            occupiedStations: [1, 2]
        )
        
        let modified = ProductConfig(
            batchId: "batch1",
            productName: "Product A", // Same
            primaryColorId: "red", // Same
            occupiedStations: [1, 2, 3] // Different
        )
        
        // When: Checking if only color changed
        let isOnlyColor = sut.isOnlyColorModification(original: original, modified: modified)
        
        // Then: Should not detect as color-only change
        XCTAssertFalse(isOnlyColor)
    }
    
    // MARK: - Redirection Message Tests (重定向消息测试)
    
    func testGetRedirectionMessage_ModifyProductStructure_ShouldReturnCorrectMessage() throws {
        // When: Getting redirection message for structure modification
        let message = sut.getRedirectionMessage(for: .modifyProductStructure)
        
        // Then: Should return appropriate message
        XCTAssertTrue(message.contains("生产配置"))
        XCTAssertTrue(message.contains("修改"))
    }
    
    func testGetRedirectionMessage_AddProduct_ShouldReturnCorrectMessage() throws {
        // When: Getting redirection message for adding product
        let message = sut.getRedirectionMessage(for: .addProduct)
        
        // Then: Should return appropriate message
        XCTAssertTrue(message.contains("生产配置"))
        XCTAssertTrue(message.contains("添加"))
    }
    
    func testGetRedirectionMessage_ModifyColors_ShouldReturnEmptyString() throws {
        // When: Getting redirection message for color modification
        let message = sut.getRedirectionMessage(for: .modifyColors)
        
        // Then: Should return empty string (no redirection needed)
        XCTAssertEqual(message, "")
    }
    
    // MARK: - Edit Guidance Tests (编辑指导测试)
    
    func testGetEditGuidance_UnsubmittedLegacyBatch_ShouldAllowFullEdit() throws {
        // Given: Legacy batch (no shift restrictions)
        mockBatch.targetDate = nil
        mockBatch.shift = nil
        mockBatch.status = .unsubmitted
        
        // When: Getting edit guidance
        let guidance = sut.getEditGuidance(for: mockBatch)
        
        // Then: Should allow full editing
        XCTAssertTrue(guidance.canEdit)
        XCTAssertFalse(guidance.colorOnly)
        XCTAssertTrue(guidance.message.contains("完整编辑"))
    }
    
    func testGetEditGuidance_ShiftBatch_ShouldRestrictToColorOnly() throws {
        // Given: Shift-aware batch
        mockBatch.targetDate = Date()
        mockBatch.shift = .morning
        mockBatch.allowsColorModificationOnly = true
        mockBatch.status = .unsubmitted
        
        // When: Getting edit guidance
        let guidance = sut.getEditGuidance(for: mockBatch)
        
        // Then: Should restrict to color-only
        XCTAssertTrue(guidance.canEdit)
        XCTAssertTrue(guidance.colorOnly)
        XCTAssertTrue(guidance.message.contains("颜色修改"))
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testBatchEditPermissionPerformance() throws {
        mockBatch.status = .unsubmitted
        
        measure {
            for _ in 0..<1000 {
                _ = sut.canEditProduct(mockProduct, in: mockBatch)
                _ = sut.getEditRestrictionReason(for: mockBatch)
            }
        }
    }
}