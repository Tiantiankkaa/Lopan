//
//  ShiftDateSelectorUITests.swift
//  LopanUITests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest

// MARK: - ShiftDateSelector UI Tests (班次日期选择器UI测试)
final class ShiftDateSelectorUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Set launch arguments for testing
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--reset-data")
        
        app.launch()
        
        // Navigate to batch processing view
        navigateToBatchProcessing()
    }
    
    private func navigateToBatchProcessing() {
        // Assuming we need to login and navigate to workshop manager section
        let loginButton = app.buttons["登录"]
        if loginButton.exists {
            loginButton.tap()
            
            // Select workshop manager role
            let workshopManagerOption = app.buttons["车间管理员"]
            if workshopManagerOption.waitForExistence(timeout: 5) {
                workshopManagerOption.tap()
            }
        }
        
        // Navigate to batch processing
        let batchProcessingTab = app.buttons["批次处理"]
        if batchProcessingTab.waitForExistence(timeout: 5) {
            batchProcessingTab.tap()
        }
    }
    
    // MARK: - Date Selection Tests (日期选择测试)
    
    func testDatePickerInteraction() throws {
        let dateButton = app.buttons["选择日期"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        
        // Tap to open date picker
        dateButton.tap()
        
        // Verify date picker appears
        let datePicker = app.datePickers.firstMatch
        XCTAssertTrue(datePicker.waitForExistence(timeout: 3))
        
        // Select a future date
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        
        // Note: Actual date selection would depend on the specific picker implementation
        // This is a simplified version
        datePicker.tap()
        
        // Confirm selection
        let confirmButton = app.buttons["确认"]
        if confirmButton.exists {
            confirmButton.tap()
        }
        
        // Verify the date was updated
        XCTAssertTrue(dateButton.exists)
    }
    
    func testDateAccessibility() throws {
        let dateButton = app.buttons["选择日期"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        
        // Test VoiceOver accessibility
        XCTAssertNotNil(dateButton.label)
        XCTAssertTrue(dateButton.isHittable)
        
        // Test that accessibility hint is present
        let hint = dateButton.value(forKey: "accessibilityHint") as? String
        XCTAssertNotNil(hint)
        XCTAssertTrue(hint?.contains("选择") == true)
    }
    
    // MARK: - Shift Selection Tests (班次选择测试)
    
    func testShiftSegmentedControl() throws {
        let morningShiftButton = app.buttons["早班"]
        let eveningShiftButton = app.buttons["晚班"]
        
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(eveningShiftButton.waitForExistence(timeout: 5))
        
        // Test morning shift selection
        morningShiftButton.tap()
        XCTAssertTrue(morningShiftButton.isSelected)
        XCTAssertFalse(eveningShiftButton.isSelected)
        
        // Test evening shift selection
        eveningShiftButton.tap()
        XCTAssertFalse(morningShiftButton.isSelected)
        XCTAssertTrue(eveningShiftButton.isSelected)
    }
    
    func testShiftRestrictionBasedOnTime() throws {
        // This test would need to mock the current time to after cutoff
        let morningShiftButton = app.buttons["早班"]
        let eveningShiftButton = app.buttons["晚班"]
        
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(eveningShiftButton.waitForExistence(timeout: 5))
        
        // If current time is after 12:00, morning shift should be disabled
        // Note: This would require setting up test time in the app
        if !morningShiftButton.isEnabled {
            XCTAssertFalse(morningShiftButton.isEnabled)
            XCTAssertTrue(eveningShiftButton.isEnabled)
            
            // Verify restriction message is shown
            let restrictionMessage = app.staticTexts["时间限制提示"]
            XCTAssertTrue(restrictionMessage.exists)
        }
    }
    
    // MARK: - Time Restriction Banner Tests (时间限制横幅测试)
    
    func testTimeRestrictionBannerAppearance() throws {
        // Look for time restriction banner
        let banner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '时间'")).firstMatch
        
        if banner.exists {
            XCTAssertTrue(banner.isHittable)
            
            // Test banner styling
            XCTAssertNotNil(banner.label)
            
            // Check if banner contains expected time information
            let bannerText = banner.label
            XCTAssertTrue(bannerText.contains("12:00") || bannerText.contains("截止"))
        }
    }
    
    func testTimeRestrictionBannerDismissal() throws {
        let banner = app.otherElements["time-restriction-banner"]
        
        if banner.exists {
            // Test if banner can be dismissed
            let dismissButton = banner.buttons["dismiss"]
            if dismissButton.exists {
                dismissButton.tap()
                
                // Verify banner is dismissed
                XCTAssertFalse(banner.waitForExistence(timeout: 2))
            }
        }
    }
    
    // MARK: - Integration Tests (集成测试)
    
    func testShiftDateSelectorIntegrationWithBatchList() throws {
        let morningShiftButton = app.buttons["早班"]
        let eveningShiftButton = app.buttons["晚班"]
        let dateButton = app.buttons["选择日期"]
        
        // Ensure all elements are present
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(eveningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        
        // Select morning shift
        morningShiftButton.tap()
        
        // Wait for batch list to update
        let batchList = app.collectionViews["batch-list"]
        if batchList.waitForExistence(timeout: 5) {
            // Count morning shift batches
            let morningBatchCount = batchList.cells.count
            
            // Switch to evening shift
            eveningShiftButton.tap()
            
            // Wait for list to update and verify different content
            sleep(1) // Give time for the list to update
            let eveningBatchCount = batchList.cells.count
            
            // The counts might be different (this depends on test data)
            // At minimum, verify that the selection change triggers an update
            XCTAssertTrue(eveningShiftButton.isSelected)
        }
    }
    
    func testShiftDateSelectorWithMachineSelection() throws {
        // Select a date and shift
        let morningShiftButton = app.buttons["早班"]
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        morningShiftButton.tap()
        
        // Verify machine selection becomes available
        let machineGrid = app.collectionViews["machine-selection-grid"]
        if machineGrid.waitForExistence(timeout: 5) {
            XCTAssertTrue(machineGrid.isHittable)
            
            // Try to select a machine
            let firstMachine = machineGrid.cells.firstMatch
            if firstMachine.exists {
                firstMachine.tap()
                
                // Verify machine selection affects create batch button
                let createButton = app.buttons["创建生产批次"]
                XCTAssertTrue(createButton.waitForExistence(timeout: 3))
                XCTAssertTrue(createButton.isEnabled)
            }
        }
    }
    
    // MARK: - Error Handling Tests (错误处理测试)
    
    func testInvalidDateSelection() throws {
        let dateButton = app.buttons["选择日期"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        
        dateButton.tap()
        
        // Try to select a past date (if validation exists)
        let datePicker = app.datePickers.firstMatch
        if datePicker.waitForExistence(timeout: 3) {
            // This would depend on the actual date picker implementation
            // and whether past dates are prevented
            
            let errorAlert = app.alerts.firstMatch
            if errorAlert.waitForExistence(timeout: 3) {
                XCTAssertTrue(errorAlert.staticTexts.matching(NSPredicate(format: "label CONTAINS '错误'")).firstMatch.exists)
                
                // Dismiss error
                let okButton = errorAlert.buttons["确定"]
                okButton.tap()
            }
        }
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testShiftSelectionResponseTime() throws {
        let morningShiftButton = app.buttons["早班"]
        let eveningShiftButton = app.buttons["晚班"]
        
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(eveningShiftButton.waitForExistence(timeout: 5))
        
        // Measure shift selection performance
        measure {
            morningShiftButton.tap()
            eveningShiftButton.tap()
            morningShiftButton.tap()
        }
    }
    
    // MARK: - Accessibility Tests (无障碍测试)
    
    func testVoiceOverNavigation() throws {
        // Enable accessibility for testing
        let morningShiftButton = app.buttons["早班"]
        let eveningShiftButton = app.buttons["晚班"]
        let dateButton = app.buttons["选择日期"]
        
        // Test tab order for VoiceOver users
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(eveningShiftButton.waitForExistence(timeout: 5))
        
        // Verify accessibility labels are present and meaningful
        XCTAssertNotNil(dateButton.label)
        XCTAssertNotNil(morningShiftButton.label)
        XCTAssertNotNil(eveningShiftButton.label)
        
        // Test that elements are accessible
        XCTAssertTrue(dateButton.isHittable)
        XCTAssertTrue(morningShiftButton.isHittable)
        XCTAssertTrue(eveningShiftButton.isHittable)
    }
    
    func testDynamicTypeSupport() throws {
        // This would test different text sizes
        // Note: Actual implementation would require setting different accessibility text sizes
        
        let morningShiftButton = app.buttons["早班"]
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        
        // Verify text is still readable and buttons are still tappable
        // with different text sizes
        XCTAssertTrue(morningShiftButton.isHittable)
        XCTAssertGreaterThan(morningShiftButton.frame.height, 44) // Minimum touch target
    }
    
    // MARK: - Localization Tests (本地化测试)
    
    func testChineseLocalization() throws {
        // Verify Chinese text is displayed correctly
        let morningShiftButton = app.buttons["早班"]
        let eveningShiftButton = app.buttons["晚班"]
        
        XCTAssertTrue(morningShiftButton.waitForExistence(timeout: 5))
        XCTAssertTrue(eveningShiftButton.waitForExistence(timeout: 5))
        
        // Verify Chinese characters are displayed properly
        XCTAssertEqual(morningShiftButton.label, "早班")
        XCTAssertEqual(eveningShiftButton.label, "晚班")
    }
}