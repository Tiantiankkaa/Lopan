//
//  DateShiftPolicyTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest
@testable import Lopan

// MARK: - Mock Time Provider for Testing (测试用模拟时间提供者)
class MockTimeProvider: TimeProvider {
    var now: Date
    let calendar = Calendar.current
    
    init(fixedDate: Date) {
        self.now = fixedDate
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - DateShiftPolicy Unit Tests (日期班次策略单元测试)
final class DateShiftPolicyTests: XCTestCase {
    
    var sut: StandardDateShiftPolicy!
    var mockTimeProvider: MockTimeProvider!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a fixed date for consistent testing
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 10, minute: 30, second: 0
        )
        let fixedDate = calendar.date(from: components)!
        
        mockTimeProvider = MockTimeProvider(fixedDate: fixedDate)
        sut = StandardDateShiftPolicy(timeProvider: mockTimeProvider, cutoffHour: 12)
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockTimeProvider = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Before Cutoff Tests (截止时间前测试)
    
    func testAllowedShifts_BeforeCutoff_ShouldReturnBothShifts() throws {
        // Given: Current time is 10:30 (before 12:00)
        let targetDate = Date()
        let currentTime = mockTimeProvider.now
        
        // When: Getting allowed shifts
        let allowedShifts = sut.allowedShifts(for: targetDate, currentTime: currentTime)
        
        // Then: Both shifts should be allowed
        XCTAssertEqual(allowedShifts.count, 2)
        XCTAssertTrue(allowedShifts.contains(.morning))
        XCTAssertTrue(allowedShifts.contains(.evening))
    }
    
    func testGetCutoffInfo_BeforeCutoff_ShouldIndicateBeforeCutoff() throws {
        // Given: Current time is 10:30 (before 12:00)
        let targetDate = Date()
        let currentTime = mockTimeProvider.now
        
        // When: Getting cutoff info
        let cutoffInfo = sut.getCutoffInfo(for: targetDate, currentTime: currentTime)
        
        // Then: Should indicate before cutoff
        XCTAssertFalse(cutoffInfo.isAfterCutoff)
        XCTAssertEqual(cutoffInfo.cutoffHour, 12)
        XCTAssertNotNil(cutoffInfo.remainingMinutes)
        XCTAssertGreaterThan(cutoffInfo.remainingMinutes!, 0)
    }
    
    // MARK: - After Cutoff Tests (截止时间后测试)
    
    func testAllowedShifts_AfterCutoff_ShouldReturnOnlyEveningShift() throws {
        // Given: Current time is 14:30 (after 12:00)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 30, second: 0
        )
        let afternoonTime = calendar.date(from: components)!
        mockTimeProvider.now = afternoonTime
        
        let targetDate = Date()
        
        // When: Getting allowed shifts
        let allowedShifts = sut.allowedShifts(for: targetDate, currentTime: mockTimeProvider.now)
        
        // Then: Only evening shift should be allowed
        XCTAssertEqual(allowedShifts.count, 1)
        XCTAssertFalse(allowedShifts.contains(.morning))
        XCTAssertTrue(allowedShifts.contains(.evening))
    }
    
    func testGetCutoffInfo_AfterCutoff_ShouldIndicateAfterCutoff() throws {
        // Given: Current time is 14:30 (after 12:00)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 14, minute: 30, second: 0
        )
        let afternoonTime = calendar.date(from: components)!
        mockTimeProvider.now = afternoonTime
        
        let targetDate = Date()
        
        // When: Getting cutoff info
        let cutoffInfo = sut.getCutoffInfo(for: targetDate, currentTime: mockTimeProvider.now)
        
        // Then: Should indicate after cutoff
        XCTAssertTrue(cutoffInfo.isAfterCutoff)
        XCTAssertEqual(cutoffInfo.cutoffHour, 12)
        XCTAssertNil(cutoffInfo.remainingMinutes)
    }
    
    // MARK: - Exact Cutoff Tests (精确截止时间测试)
    
    func testAllowedShifts_ExactlyAtCutoff_ShouldReturnOnlyEveningShift() throws {
        // Given: Current time is exactly 12:00
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 12, minute: 0, second: 0
        )
        let exactCutoffTime = calendar.date(from: components)!
        mockTimeProvider.now = exactCutoffTime
        
        let targetDate = Date()
        
        // When: Getting allowed shifts
        let allowedShifts = sut.allowedShifts(for: targetDate, currentTime: mockTimeProvider.now)
        
        // Then: Only evening shift should be allowed (cutoff is exclusive)
        XCTAssertEqual(allowedShifts.count, 1)
        XCTAssertFalse(allowedShifts.contains(.morning))
        XCTAssertTrue(allowedShifts.contains(.evening))
    }
    
    // MARK: - Edge Case Tests (边界情况测试)
    
    func testAllowedShifts_OneMinuteBeforeCutoff_ShouldReturnBothShifts() throws {
        // Given: Current time is 11:59 (1 minute before cutoff)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 11, minute: 59, second: 0
        )
        let nearCutoffTime = calendar.date(from: components)!
        mockTimeProvider.now = nearCutoffTime
        
        let targetDate = Date()
        
        // When: Getting allowed shifts
        let allowedShifts = sut.allowedShifts(for: targetDate, currentTime: mockTimeProvider.now)
        
        // Then: Both shifts should still be allowed
        XCTAssertEqual(allowedShifts.count, 2)
        XCTAssertTrue(allowedShifts.contains(.morning))
        XCTAssertTrue(allowedShifts.contains(.evening))
    }
    
    func testAllowedShifts_OneMinuteAfterCutoff_ShouldReturnOnlyEveningShift() throws {
        // Given: Current time is 12:01 (1 minute after cutoff)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 12, minute: 1, second: 0
        )
        let justAfterCutoffTime = calendar.date(from: components)!
        mockTimeProvider.now = justAfterCutoffTime
        
        let targetDate = Date()
        
        // When: Getting allowed shifts
        let allowedShifts = sut.allowedShifts(for: targetDate, currentTime: mockTimeProvider.now)
        
        // Then: Only evening shift should be allowed
        XCTAssertEqual(allowedShifts.count, 1)
        XCTAssertFalse(allowedShifts.contains(.morning))
        XCTAssertTrue(allowedShifts.contains(.evening))
    }
    
    // MARK: - Cross-Timezone Tests (跨时区测试)
    
    func testGetCutoffInfo_RemainingMinutesCalculation() throws {
        // Given: Current time is 11:30 (30 minutes before cutoff)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 11, minute: 30, second: 0
        )
        let beforeCutoffTime = calendar.date(from: components)!
        mockTimeProvider.now = beforeCutoffTime
        
        let targetDate = Date()
        
        // When: Getting cutoff info
        let cutoffInfo = sut.getCutoffInfo(for: targetDate, currentTime: mockTimeProvider.now)
        
        // Then: Should calculate remaining minutes correctly
        XCTAssertFalse(cutoffInfo.isAfterCutoff)
        XCTAssertEqual(cutoffInfo.remainingMinutes, 30)
    }
    
    // MARK: - Custom Cutoff Hour Tests (自定义截止时间测试)
    
    func testCustomCutoffHour_ShouldRespectCustomTime() throws {
        // Given: Custom cutoff at 10:00 instead of 12:00
        let customPolicy = StandardDateShiftPolicy(timeProvider: mockTimeProvider, cutoffHour: 10)
        
        // Current time is 10:30 (after custom cutoff)
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025, month: 8, day: 13,
            hour: 10, minute: 30, second: 0
        )
        let currentTime = calendar.date(from: components)!
        
        let targetDate = Date()
        
        // When: Getting allowed shifts with custom cutoff
        let allowedShifts = customPolicy.allowedShifts(for: targetDate, currentTime: currentTime)
        
        // Then: Should respect custom cutoff time
        XCTAssertEqual(allowedShifts.count, 1)
        XCTAssertFalse(allowedShifts.contains(.morning))
        XCTAssertTrue(allowedShifts.contains(.evening))
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testDateShiftPolicyPerformance() throws {
        let targetDate = Date()
        let currentTime = mockTimeProvider.now
        
        measure {
            for _ in 0..<1000 {
                _ = sut.allowedShifts(for: targetDate, currentTime: currentTime)
                _ = sut.getCutoffInfo(for: targetDate, currentTime: currentTime)
            }
        }
    }
}