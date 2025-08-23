//
//  BatchDetailInfoTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/14.
//

import XCTest
@testable import Lopan

/// Comprehensive unit tests for BatchDetailInfo structure
/// BatchDetailInfo结构体综合单元测试
@MainActor
final class BatchDetailInfoTests: XCTestCase {
    
    // MARK: - Test Data Factory (测试数据工厂)
    
    /// Create a base ProductionBatch for testing
    /// 创建用于测试的基本ProductionBatch
    private func createBaseBatch(
        batchNumber: String = "PC-20250814-0001",
        status: BatchStatus = .completed,
        machineId: String = "machine1",
        mode: ProductionMode = .singleColor,
        batchType: BatchType = .productionConfig
    ) -> ProductionBatch {
        let batch = ProductionBatch(
            machineId: machineId,
            mode: mode,
            submittedBy: "test_user",
            submittedByName: "Test User",
            batchNumber: batchNumber
        )
        batch.status = status
        return batch
    }
    
    /// Create a shift-aware batch with specific settings
    /// 创建具有特定设置的班次感知批次
    private func createShiftBatch(
        targetDate: Date = Date(),
        shift: Shift = .morning,
        isSystemAutoCompleted: Bool = false,
        executionTime: Date? = nil,
        completedAt: Date? = nil
    ) -> ProductionBatch {
        let batch = createBaseBatch()
        batch.targetDate = targetDate
        batch.shift = shift
        batch.isSystemAutoCompleted = isSystemAutoCompleted
        batch.executionTime = executionTime
        batch.completedAt = completedAt
        batch.isShiftBatch = true
        return batch
    }
    
    /// Create test dates for consistent testing
    /// 创建用于一致性测试的测试日期
    private var testDates: (base: Date, shiftStart: Date, completion: Date) {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 14,
            hour: 12, minute: 0, second: 0
        ))!
        
        let shiftStartDate = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 14,
            hour: 7, minute: 0, second: 0
        ))! // Morning shift start time
        
        let completionDate = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 14,
            hour: 19, minute: 0, second: 0
        ))! // Evening completion
        
        return (baseDate, shiftStartDate, completionDate)
    }
    
    // MARK: - Initialization Tests (初始化测试)
    
    func testInitialization_WithBasicBatch_ShouldCopyAllProperties() {
        // Given: A basic ProductionBatch
        let batch = createBaseBatch()
        batch.reviewedAt = Date()
        batch.reviewedBy = "reviewer"
        batch.reviewedByName = "Reviewer Name"
        batch.reviewNotes = "Test review notes"
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: All properties should be copied correctly
        XCTAssertEqual(detailInfo.id, batch.id)
        XCTAssertEqual(detailInfo.batchNumber, batch.batchNumber)
        XCTAssertEqual(detailInfo.status, batch.status)
        XCTAssertEqual(detailInfo.machineId, batch.machineId)
        XCTAssertEqual(detailInfo.mode, batch.mode)
        XCTAssertEqual(detailInfo.submittedBy, batch.submittedBy)
        XCTAssertEqual(detailInfo.submittedByName, batch.submittedByName)
        XCTAssertEqual(detailInfo.reviewedAt, batch.reviewedAt)
        XCTAssertEqual(detailInfo.reviewedBy, batch.reviewedBy)
        XCTAssertEqual(detailInfo.reviewedByName, batch.reviewedByName)
        XCTAssertEqual(detailInfo.reviewNotes, batch.reviewNotes)
    }
    
    // MARK: - Auto-Completion Detection Tests (自动完成检测测试)
    
    func testIsAutoCompleted_SystemAutoCompletedFlag_ShouldReturnTrue() {
        // Given: Batch with explicit system auto-completed flag
        let batch = createShiftBatch(isSystemAutoCompleted: true)
        batch.status = .completed
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should detect as auto-completed
        XCTAssertTrue(detailInfo.isAutoCompleted)
    }
    
    func testIsAutoCompleted_ShiftStartTimeExecution_ShouldReturnTrue() {
        // Given: Batch executed at shift start time
        let dates = testDates
        let batch = createShiftBatch(
            targetDate: dates.base,
            shift: .morning,
            executionTime: dates.shiftStart
        )
        batch.status = .completed
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should detect as auto-completed (intelligent detection)
        XCTAssertTrue(detailInfo.isAutoCompleted)
    }
    
    func testIsAutoCompleted_CompletedWithoutExecutionTime_ShouldReturnTrue() {
        // Given: Completed batch without execution time (legacy auto-completed)
        let dates = testDates
        let batch = createShiftBatch()
        batch.status = .completed
        batch.executionTime = nil
        batch.completedAt = dates.completion
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should detect as auto-completed
        XCTAssertTrue(detailInfo.isAutoCompleted)
    }
    
    // MARK: - Execution Type Information Tests (执行类型信息测试)
    
    func testExecutionTypeInfo_SystemAutoCompletedWithShift_ShouldShowShiftInfo() {
        // Given: System auto-completed batch with shift information
        let batch = createShiftBatch(
            shift: .evening,
            isSystemAutoCompleted: true
        )
        batch.status = .completed
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should show system auto-execution with shift details
        XCTAssertNotNil(detailInfo.executionTypeInfo)
        XCTAssertEqual(detailInfo.executionTypeInfo?.type, "系统自动执行")
        XCTAssertTrue(detailInfo.executionTypeInfo?.details.contains("班次时间") == true)
    }
    
    func testExecutionTypeInfo_SystemAutoCompletedWithoutShift_ShouldShow12Hours() {
        // Given: System auto-completed batch without shift information
        let batch = createBaseBatch()
        batch.isSystemAutoCompleted = true
        batch.status = .completed
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should show 12-hour runtime
        XCTAssertNotNil(detailInfo.executionTypeInfo)
        XCTAssertEqual(detailInfo.executionTypeInfo?.type, "系统自动执行")
        XCTAssertTrue(detailInfo.executionTypeInfo?.details.contains("12h") == true)
    }
    
    // MARK: - Runtime Duration Tests (运行时长测试)
    
    func testFormattedRuntimeDuration_SystemAutoCompleted_ShouldReturn12Hours() {
        // Given: System auto-completed batch
        let batch = createShiftBatch(isSystemAutoCompleted: true)
        batch.status = .completed
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should return fixed 12 hours
        XCTAssertEqual(detailInfo.formattedRuntimeDuration, "12h")
    }
    
    func testFormattedRuntimeDuration_ManualExecution_ShouldCalculateActualDuration() {
        // Given: Manual execution with 6 hours runtime
        let calendar = Calendar.current
        let startTime = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 14,
            hour: 8, minute: 0, second: 0
        ))!
        let endTime = calendar.date(from: DateComponents(
            year: 2025, month: 8, day: 14,
            hour: 14, minute: 0, second: 0
        ))!
        
        let batch = createShiftBatch(
            executionTime: startTime,
            completedAt: endTime
        )
        batch.status = .completed
        batch.isSystemAutoCompleted = false
        
        // When: Initializing BatchDetailInfo
        let detailInfo = BatchDetailInfo(from: batch)
        
        // Then: Should calculate actual 6-hour duration
        XCTAssertEqual(detailInfo.formattedRuntimeDuration, "6h")
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testPerformance_InitializationWithComplexBatch_ShouldBeEfficient() {
        // Given: Complex batch with all properties set
        let dates = testDates
        let batch = createShiftBatch(
            targetDate: dates.base,
            shift: .evening,
            isSystemAutoCompleted: false,
            executionTime: dates.shiftStart,
            completedAt: dates.completion
        )
        batch.reviewedAt = dates.base
        batch.reviewedBy = "reviewer"
        batch.reviewedByName = "Reviewer Name"
        batch.reviewNotes = "Detailed review notes"
        
        // When: Measuring performance
        measure {
            for _ in 0..<1000 {
                let _ = BatchDetailInfo(from: batch)
            }
        }
        
        // Performance should be acceptable for UI usage
    }
}