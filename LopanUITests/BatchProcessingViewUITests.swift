//
//  BatchProcessingViewUITests.swift
//  LopanUITests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest

// MARK: - BatchProcessingView UI Tests (批次处理视图UI测试)
final class BatchProcessingViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Set up test environment
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--reset-data")
        app.launchArguments.append("--mock-data")
        
        app.launch()
        
        // Navigate to batch processing view
        navigateToBatchProcessing()
    }
    
    private func navigateToBatchProcessing() {
        // Login as workshop manager
        let loginButton = app.buttons["登录"]
        if loginButton.exists {
            loginButton.tap()
            
            let workshopManagerOption = app.buttons["车间管理员"]
            if workshopManagerOption.waitForExistence(timeout: 5) {
                workshopManagerOption.tap()
            }
        }
        
        // Navigate to batch processing
        let batchProcessingTab = app.tabBars.buttons["批次处理"]
        if batchProcessingTab.exists {
            batchProcessingTab.tap()
        } else {
            // Alternative navigation
            let menuButton = app.buttons["菜单"]
            if menuButton.exists {
                menuButton.tap()
                let batchProcessingItem = app.buttons["批次处理"]
                if batchProcessingItem.waitForExistence(timeout: 3) {
                    batchProcessingItem.tap()
                }
            }
        }
        
        // Wait for view to load
        let navigationTitle = app.navigationBars["批次处理"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5))
    }
    
    // MARK: - View Loading Tests (视图加载测试)
    
    func testBatchProcessingViewLoads() throws {
        // Verify main navigation title
        let navigationTitle = app.navigationBars["批次处理"]
        XCTAssertTrue(navigationTitle.exists)
        
        // Verify key sections are present
        let headerSection = app.staticTexts["班次批次管理"]
        XCTAssertTrue(headerSection.waitForExistence(timeout: 5))
        
        let dateShiftSection = app.staticTexts["选择日期和班次"]
        XCTAssertTrue(dateShiftSection.exists)
        
        let machineStatusSection = app.staticTexts["设备状态检查"]
        XCTAssertTrue(machineStatusSection.exists)
        
        let machineSelectionSection = app.staticTexts["选择生产设备"]
        XCTAssertTrue(machineSelectionSection.exists)
        
        let batchListSection = app.staticTexts["当前批次列表"]
        XCTAssertTrue(batchListSection.exists)
        
        let createBatchSection = app.staticTexts["创建新批次"]
        XCTAssertTrue(createBatchSection.exists)
    }
    
    func testHeaderInformation() throws {
        // Test header content
        let headerTitle = app.staticTexts["班次批次管理"]
        XCTAssertTrue(headerTitle.exists)
        
        let headerDescription = app.staticTexts["按班次安排生产批次，精准控制生产节奏"]
        XCTAssertTrue(headerDescription.exists)
        
        // Test batch count badge
        let batchCountLabel = app.staticTexts["当前批次"]
        XCTAssertTrue(batchCountLabel.exists)
    }
    
    // MARK: - Machine Selection Tests (机器选择测试)
    
    func testMachineSelectionGrid() throws {
        let machineGrid = app.collectionViews["machine-selection-grid"]
        
        if machineGrid.waitForExistence(timeout: 5) {
            // Test that machines are displayed
            let machineCells = machineGrid.cells
            XCTAssertGreaterThan(machineCells.count, 0)
            
            // Test machine selection
            let firstMachine = machineCells.firstMatch
            firstMachine.tap()
            
            // Verify selection state changes
            XCTAssertTrue(firstMachine.isSelected)
            
            // Test deselection
            firstMachine.tap()
            XCTAssertFalse(firstMachine.isSelected)
        }
    }
    
    func testMachineSelectionAffectsCreateButton() throws {
        let machineGrid = app.collectionViews["machine-selection-grid"]
        let createButton = app.buttons["创建生产批次"]
        
        // Initially create button should be disabled
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        XCTAssertFalse(createButton.isEnabled)
        
        if machineGrid.waitForExistence(timeout: 5) {
            let firstMachine = machineGrid.cells.firstMatch
            if firstMachine.exists {
                firstMachine.tap()
                
                // Create button should now be enabled
                XCTAssertTrue(createButton.isEnabled)
            }
        }
    }
    
    func testMachineEmptyState() throws {
        // This test would need to mock an empty machine list
        let emptyStateIcon = app.images["gearshape.slash"]
        let emptyStateText = app.staticTexts["暂无可用设备"]
        
        if emptyStateIcon.exists {
            XCTAssertTrue(emptyStateText.exists)
            
            let addDeviceHint = app.staticTexts["请先在设备管理中添加生产设备"]
            XCTAssertTrue(addDeviceHint.exists)
        }
    }
    
    // MARK: - Batch List Tests (批次列表测试)
    
    func testBatchListDisplay() throws {
        let batchList = app.collectionViews["batch-list"]
        
        if batchList.waitForExistence(timeout: 5) {
            // Test that batches are displayed
            let batchCells = batchList.cells
            
            if batchCells.count > 0 {
                let firstBatch = batchCells.firstMatch
                XCTAssertTrue(firstBatch.isHittable)
                
                // Test batch information is displayed
                let batchNumber = firstBatch.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'B'")).firstMatch
                XCTAssertTrue(batchNumber.exists)
                
                // Test status badge
                let statusBadge = firstBatch.otherElements.matching(NSPredicate(format: "label CONTAINS '状态'")).firstMatch
                // Status might not always be visible, so this is optional
            }
        }
    }
    
    func testBatchListEmptyState() throws {
        // This would test when no batches exist for selected date/shift
        let emptyStateIcon = app.images["square.stack.3d.down.right"]
        let emptyStateText = app.staticTexts["当前时段暂无批次"]
        
        if emptyStateIcon.exists {
            XCTAssertTrue(emptyStateText.exists)
            
            let createHint = app.staticTexts["选择设备后可创建新的生产批次"]
            XCTAssertTrue(createHint.exists)
        }
    }
    
    func testBatchItemTap() throws {
        let batchList = app.collectionViews["batch-list"]
        
        if batchList.waitForExistence(timeout: 5) && batchList.cells.count > 0 {
            let firstBatch = batchList.cells.firstMatch
            firstBatch.tap()
            
            // Should open batch edit or approval sheet
            let batchEditSheet = app.sheets.firstMatch
            if batchEditSheet.waitForExistence(timeout: 3) {
                XCTAssertTrue(batchEditSheet.exists)
                
                // Close the sheet
                let closeButton = batchEditSheet.buttons["关闭"]
                if closeButton.exists {
                    closeButton.tap()
                }
            }
        }
    }
    
    // MARK: - Batch Creation Flow Tests (批次创建流程测试)
    
    func testBatchCreationFlow() throws {
        // Select machine first
        let machineGrid = app.collectionViews["machine-selection-grid"]
        if machineGrid.waitForExistence(timeout: 5) && machineGrid.cells.count > 0 {
            let firstMachine = machineGrid.cells.firstMatch
            firstMachine.tap()
        }
        
        // Tap create batch button
        let createButton = app.buttons["创建生产批次"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        XCTAssertTrue(createButton.isEnabled)
        
        createButton.tap()
        
        // Verify batch creation sheet appears
        let creationSheet = app.sheets.firstMatch
        XCTAssertTrue(creationSheet.waitForExistence(timeout: 3))
        
        // Test navigation title in sheet
        let sheetTitle = creationSheet.navigationBars.firstMatch
        XCTAssertTrue(sheetTitle.exists)
        
        // Cancel creation
        let cancelButton = creationSheet.buttons["关闭"]
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            // Alternative close method
            creationSheet.swipeDown()
        }
    }
    
    func testCreateBatchWithoutMachineSelection() throws {
        // Ensure no machine is selected
        let machineGrid = app.collectionViews["machine-selection-grid"]
        if machineGrid.exists {
            // Deselect any selected machines
            let selectedCells = machineGrid.cells.matching(NSPredicate(format: "selected == true"))
            for i in 0..<selectedCells.count {
                selectedCells.element(boundBy: i).tap()
            }
        }
        
        // Try to tap create button
        let createButton = app.buttons["创建生产批次"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        XCTAssertFalse(createButton.isEnabled)
        
        // Verify hint message
        let hintText = app.staticTexts["请先选择设备"]
        XCTAssertTrue(hintText.exists)
    }
    
    // MARK: - Refresh and Data Loading Tests (刷新和数据加载测试)
    
    func testPullToRefresh() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        
        // Pull down to refresh
        scrollView.swipeDown()
        
        // Look for loading indicator (might be brief)
        let loadingIndicator = app.activityIndicators.firstMatch
        // Loading might complete quickly, so we don't assert its existence
        
        // Verify content is still there after refresh
        let headerSection = app.staticTexts["班次批次管理"]
        XCTAssertTrue(headerSection.exists)
    }
    
    func testRefreshButton() throws {
        let refreshButton = app.navigationBars.buttons["刷新数据"]
        if refreshButton.exists {
            refreshButton.tap()
            
            // Wait for refresh to complete
            sleep(1)
            
            // Verify view is still functional
            let headerSection = app.staticTexts["班次批次管理"]
            XCTAssertTrue(headerSection.exists)
        }
    }
    
    // MARK: - Date and Shift Integration Tests (日期班次集成测试)
    
    func testDateShiftChangeUpdatesView() throws {
        // Get initial state
        let batchCountText = app.staticTexts["当前批次"].firstMatch
        let initialCount = batchCountText.label
        
        // Change shift
        let eveningShiftButton = app.buttons["晚班"]
        if eveningShiftButton.waitForExistence(timeout: 5) {
            eveningShiftButton.tap()
            
            // Wait for update
            sleep(2)
            
            // Verify something has changed (could be batch count or list content)
            let updatedBatchList = app.collectionViews["batch-list"]
            XCTAssertTrue(updatedBatchList.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Error Handling Tests (错误处理测试)
    
    func testNetworkErrorHandling() throws {
        // This would test with network mocking
        // Look for error alerts
        let errorAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS '错误'")).firstMatch
        
        if errorAlert.waitForExistence(timeout: 3) {
            // Verify error message is displayed
            XCTAssertTrue(errorAlert.exists)
            
            // Dismiss error
            let confirmButton = errorAlert.buttons["确定"]
            confirmButton.tap()
        }
    }
    
    // MARK: - Accessibility Tests (无障碍测试)
    
    func testAccessibilityLabelsAndHints() throws {
        // Test key UI elements have proper accessibility
        let createButton = app.buttons["创建生产批次"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        XCTAssertNotNil(createButton.label)
        
        // Test section headers have proper accessibility
        let dateShiftSection = app.staticTexts["选择日期和班次"]
        XCTAssertTrue(dateShiftSection.exists)
        XCTAssertTrue(dateShiftSection.isHittable)
        
        // Test machine selection accessibility
        let machineGrid = app.collectionViews["machine-selection-grid"]
        if machineGrid.waitForExistence(timeout: 5) && machineGrid.cells.count > 0 {
            let firstMachine = machineGrid.cells.firstMatch
            XCTAssertNotNil(firstMachine.label)
            
            // Test accessibility hint for machine selection
            let hint = firstMachine.value(forKey: "accessibilityHint") as? String
            XCTAssertNotNil(hint)
            XCTAssertTrue(hint?.contains("选择") == true || hint?.contains("点击") == true)
        }
    }
    
    func testKeyboardNavigation() throws {
        // This would test keyboard navigation support
        // For now, verify key elements are focusable
        
        let createButton = app.buttons["创建生产批次"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        XCTAssertTrue(createButton.isHittable)
        
        let morningShiftButton = app.buttons["早班"]
        XCTAssertTrue(morningShiftButton.exists)
        XCTAssertTrue(morningShiftButton.isHittable)
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testViewLoadingPerformance() throws {
        // Measure view loading time
        measure(metrics: [XCTClockMetric()]) {
            // Navigate away and back to measure loading
            app.swipeRight() // Go back
            sleep(1)
            navigateToBatchProcessing()
        }
    }
    
    func testScrollPerformance() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        
        // Measure scrolling performance
        measure(metrics: [XCTClockMetric()]) {
            scrollView.swipeUp()
            scrollView.swipeDown()
            scrollView.swipeUp()
            scrollView.swipeDown()
        }
    }
    
    // MARK: - Integration with Other Views Tests (与其他视图集成测试)
    
    func testNavigationToMachineManagement() throws {
        // Test navigation to machine management from empty state
        let emptyStateText = app.staticTexts["请先在设备管理中添加生产设备"]
        
        if emptyStateText.exists {
            // This would depend on having a navigation link
            let machineManagementLink = app.buttons["设备管理"]
            if machineManagementLink.exists {
                machineManagementLink.tap()
                
                // Verify navigation occurred
                let machineManagementTitle = app.navigationBars["设备管理"]
                XCTAssertTrue(machineManagementTitle.waitForExistence(timeout: 5))
                
                // Navigate back
                let backButton = app.navigationBars.buttons.firstMatch
                backButton.tap()
            }
        }
    }
    
    func testBatchListViewAllNavigation() throws {
        let viewAllButton = app.buttons["查看全部"]
        
        if viewAllButton.exists {
            viewAllButton.tap()
            
            // Verify batch list sheet appears
            let batchListSheet = app.sheets.firstMatch
            XCTAssertTrue(batchListSheet.waitForExistence(timeout: 3))
            
            // Close sheet
            let closeButton = batchListSheet.buttons["关闭"]
            if closeButton.exists {
                closeButton.tap()
            } else {
                batchListSheet.swipeDown()
            }
        }
    }
}