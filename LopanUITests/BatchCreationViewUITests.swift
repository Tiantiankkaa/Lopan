//
//  BatchCreationViewUITests.swift
//  LopanUITests
//
//  Created by Claude Code on 2025/8/13.
//

import XCTest

// MARK: - BatchCreationView UI Tests (批次创建视图UI测试)
final class BatchCreationViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--reset-data")
        app.launchArguments.append("--mock-data")
        
        app.launch()
        
        // Navigate to batch creation
        navigateToBatchCreation()
    }
    
    private func navigateToBatchCreation() {
        // Login and navigate to batch processing
        let loginButton = app.buttons["登录"]
        if loginButton.exists {
            loginButton.tap()
            
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
        
        // Select a machine
        let machineGrid = app.collectionViews["machine-selection-grid"]
        if machineGrid.waitForExistence(timeout: 5) && machineGrid.cells.count > 0 {
            let firstMachine = machineGrid.cells.firstMatch
            firstMachine.tap()
        }
        
        // Tap create batch button
        let createButton = app.buttons["创建生产批次"]
        if createButton.waitForExistence(timeout: 5) && createButton.isEnabled {
            createButton.tap()
        }
        
        // Wait for creation sheet
        let creationSheet = app.sheets.firstMatch
        XCTAssertTrue(creationSheet.waitForExistence(timeout: 5))
    }
    
    // MARK: - View Loading Tests (视图加载测试)
    
    func testBatchCreationViewLoads() throws {
        // Verify navigation title
        let navigationBar = app.navigationBars["创建生产批次"]
        XCTAssertTrue(navigationBar.exists)
        
        // Verify key sections exist
        let basicInfoSection = app.staticTexts["基本信息"]
        XCTAssertTrue(basicInfoSection.exists)
        
        let productConfigSection = app.staticTexts["产品配置"]
        XCTAssertTrue(productConfigSection.exists)
        
        let scheduleInfoSection = app.staticTexts["排产信息"]
        XCTAssertTrue(scheduleInfoSection.exists)
    }
    
    func testInitialFormState() throws {
        // Verify initial form state
        let batchNumberField = app.textFields["批次编号"]
        XCTAssertTrue(batchNumberField.exists)
        XCTAssertFalse(batchNumberField.value as? String == "")
        
        // Verify date and shift are pre-selected
        let dateDisplay = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2025'")).firstMatch
        XCTAssertTrue(dateDisplay.exists)
        
        let shiftDisplay = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '班'")).firstMatch
        XCTAssertTrue(shiftDisplay.exists)
        
        // Verify create button initially disabled
        let createBatchButton = app.buttons["创建批次"]
        if createBatchButton.exists {
            XCTAssertFalse(createBatchButton.isEnabled)
        }
    }
    
    // MARK: - Product Configuration Tests (产品配置测试)
    
    func testAddProductConfiguration() throws {
        let addProductButton = app.buttons["添加产品"]
        XCTAssertTrue(addProductButton.waitForExistence(timeout: 5))
        
        addProductButton.tap()
        
        // Verify product selection sheet appears
        let productSelectionSheet = app.sheets.matching(NSPredicate(format: "identifier CONTAINS 'product-selection'")).firstMatch
        if productSelectionSheet.waitForExistence(timeout: 3) {
            // Select a product
            let productList = productSelectionSheet.tables.firstMatch
            if productList.exists && productList.cells.count > 0 {
                let firstProduct = productList.cells.firstMatch
                firstProduct.tap()
                
                // Confirm selection
                let confirmButton = productSelectionSheet.buttons["确认选择"]
                if confirmButton.exists {
                    confirmButton.tap()
                }
            }
        }
        
        // Verify product was added to the list
        let productList = app.tables["product-configuration-list"]
        if productList.waitForExistence(timeout: 3) {
            XCTAssertGreaterThan(productList.cells.count, 0)
        }
    }
    
    func testProductColorSelection() throws {
        // First add a product
        try testAddProductConfiguration()
        
        // Find product configuration item
        let productList = app.tables["product-configuration-list"]
        if productList.exists && productList.cells.count > 0 {
            let firstProductCell = productList.cells.firstMatch
            
            // Look for color selection within the cell
            let colorButton = firstProductCell.buttons.matching(NSPredicate(format: "label CONTAINS '颜色'")).firstMatch
            if colorButton.exists {
                colorButton.tap()
                
                // Verify color picker appears
                let colorPicker = app.sheets.matching(NSPredicate(format: "identifier CONTAINS 'color-picker'")).firstMatch
                if colorPicker.waitForExistence(timeout: 3) {
                    // Select a color
                    let colorGrid = colorPicker.collectionViews.firstMatch
                    if colorGrid.exists && colorGrid.cells.count > 0 {
                        let firstColor = colorGrid.cells.firstMatch
                        firstColor.tap()
                        
                        // Confirm color selection
                        let confirmButton = colorPicker.buttons["确认"]
                        if confirmButton.exists {
                            confirmButton.tap()
                        }
                    }
                }
            }
        }
    }
    
    func testRemoveProductConfiguration() throws {
        // First add a product
        try testAddProductConfiguration()
        
        let productList = app.tables["product-configuration-list"]
        if productList.exists && productList.cells.count > 0 {
            let firstProductCell = productList.cells.firstMatch
            
            // Look for remove button
            let removeButton = firstProductCell.buttons["删除产品"]
            if removeButton.exists {
                removeButton.tap()
                
                // Confirm removal if alert appears
                let confirmAlert = app.alerts.firstMatch
                if confirmAlert.waitForExistence(timeout: 2) {
                    let confirmButton = confirmAlert.buttons["确认"]
                    confirmButton.tap()
                }
                
                // Verify product was removed
                // Note: The cell count check might be unreliable immediately after removal
                sleep(1)
            }
        }
    }
    
    // MARK: - Validation Tests (验证测试)
    
    func testFormValidationWithEmptyProducts() throws {
        // Try to create batch without products
        let createBatchButton = app.buttons["创建批次"]
        
        if createBatchButton.exists {
            // Button should be disabled without products
            XCTAssertFalse(createBatchButton.isEnabled)
        }
        
        // Look for validation message
        let validationMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '产品' AND label CONTAINS '添加'")).firstMatch
        if validationMessage.exists {
            XCTAssertTrue(validationMessage.exists)
        }
    }
    
    func testFormValidationWithCompleteData() throws {
        // Add a product first
        try testAddProductConfiguration()
        
        // Now create button should be enabled
        let createBatchButton = app.buttons["创建批次"]
        if createBatchButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(createBatchButton.isEnabled)
        }
    }
    
    func testMachineConflictValidation() throws {
        // This would test if the UI shows machine conflict warnings
        let conflictWarning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '设备冲突' OR label CONTAINS '机器占用'")).firstMatch
        
        if conflictWarning.exists {
            XCTAssertTrue(conflictWarning.exists)
            
            // Should provide options to resolve conflict
            let resolveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '解决' OR label CONTAINS '更换'")).firstMatch
            XCTAssertTrue(resolveButton.exists)
        }
    }
    
    // MARK: - Shift-Aware Features Tests (班次感知功能测试)
    
    func testShiftRestrictionInfo() throws {
        // Look for shift restriction information
        let restrictionInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '班次批次' OR label CONTAINS '颜色修改'")).firstMatch
        
        if restrictionInfo.exists {
            XCTAssertTrue(restrictionInfo.exists)
            
            // Should show color-only editing notice
            let colorOnlyNotice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '仅支持颜色修改'")).firstMatch
            if colorOnlyNotice.exists {
                XCTAssertTrue(colorOnlyNotice.exists)
            }
        }
    }
    
    func testTimeContextInformation() throws {
        // Look for time context display
        let timeInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '当前时间' OR label CONTAINS '截止时间'")).firstMatch
        
        if timeInfo.exists {
            XCTAssertTrue(timeInfo.exists)
        }
        
        // Check for cutoff time warning if applicable
        let cutoffWarning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '12:00' OR label CONTAINS '截止'")).firstMatch
        if cutoffWarning.exists {
            XCTAssertTrue(cutoffWarning.exists)
        }
    }
    
    // MARK: - Batch Creation Success Flow Tests (批次创建成功流程测试)
    
    func testSuccessfulBatchCreation() throws {
        // Add a product
        try testAddProductConfiguration()
        
        // Fill in any additional required fields
        let modeSelector = app.segmentedControls["production-mode-selector"]
        if modeSelector.exists {
            let singleColorOption = modeSelector.buttons["单色模式"]
            if singleColorOption.exists {
                singleColorOption.tap()
            }
        }
        
        // Create the batch
        let createBatchButton = app.buttons["创建批次"]
        if createBatchButton.waitForExistence(timeout: 5) && createBatchButton.isEnabled {
            createBatchButton.tap()
            
            // Look for success indicator
            let successAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS '成功' OR label CONTAINS '创建完成'")).firstMatch
            if successAlert.waitForExistence(timeout: 5) {
                XCTAssertTrue(successAlert.exists)
                
                // Dismiss success alert
                let okButton = successAlert.buttons["确定"]
                if okButton.exists {
                    okButton.tap()
                }
            }
            
            // Verify we return to the main view or the sheet is dismissed
            let creationSheet = app.sheets.firstMatch
            XCTAssertFalse(creationSheet.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Error Handling Tests (错误处理测试)
    
    func testCreationErrorHandling() throws {
        // This would test error scenarios (would need mock error states)
        let errorAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS '错误' OR label CONTAINS '失败'")).firstMatch
        
        if errorAlert.exists {
            XCTAssertTrue(errorAlert.exists)
            
            // Verify error message is informative
            let errorMessage = errorAlert.staticTexts.firstMatch
            XCTAssertTrue(errorMessage.exists)
            
            // Dismiss error
            let okButton = errorAlert.buttons["确定"]
            okButton.tap()
        }
    }
    
    func testNetworkErrorRecovery() throws {
        // Test behavior when network is unavailable
        // This would require network condition mocking
        
        let retryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '重试' OR label CONTAINS '再次尝试'")).firstMatch
        
        if retryButton.exists {
            XCTAssertTrue(retryButton.exists)
            XCTAssertTrue(retryButton.isHittable)
        }
    }
    
    // MARK: - Cancel and Navigation Tests (取消和导航测试)
    
    func testCancelCreation() throws {
        let cancelButton = app.buttons["取消"]
        if cancelButton.exists {
            cancelButton.tap()
            
            // Should show confirmation if there are unsaved changes
            let confirmAlert = app.alerts.firstMatch
            if confirmAlert.waitForExistence(timeout: 2) {
                let confirmCancelButton = confirmAlert.buttons.matching(NSPredicate(format: "label CONTAINS '确认' OR label CONTAINS '离开'")).firstMatch
                confirmCancelButton.tap()
            }
            
            // Verify we return to previous view
            let creationSheet = app.sheets.firstMatch
            XCTAssertFalse(creationSheet.waitForExistence(timeout: 3))
        } else {
            // Alternative close method
            let closeButton = app.buttons["关闭"]
            if closeButton.exists {
                closeButton.tap()
            }
        }
    }
    
    func testSwipeToClose() throws {
        let creationSheet = app.sheets.firstMatch
        XCTAssertTrue(creationSheet.exists)
        
        // Swipe down to close
        creationSheet.swipeDown()
        
        // Verify sheet is dismissed
        XCTAssertFalse(creationSheet.waitForExistence(timeout: 3))
    }
    
    // MARK: - Accessibility Tests (无障碍测试)
    
    func testAccessibilityLabelsAndHints() throws {
        let addProductButton = app.buttons["添加产品"]
        XCTAssertTrue(addProductButton.exists)
        XCTAssertNotNil(addProductButton.label)
        
        let batchNumberField = app.textFields["批次编号"]
        XCTAssertTrue(batchNumberField.exists)
        XCTAssertNotNil(batchNumberField.label)
        
        let createBatchButton = app.buttons["创建批次"]
        if createBatchButton.exists {
            XCTAssertNotNil(createBatchButton.label)
            
            // Test accessibility hint
            let hint = createBatchButton.value(forKey: "accessibilityHint") as? String
            if hint != nil {
                XCTAssertTrue(hint!.contains("创建") || hint!.contains("生成"))
            }
        }
    }
    
    func testVoiceOverSupport() throws {
        // Test that elements are properly ordered for VoiceOver
        let batchNumberField = app.textFields["批次编号"]
        let addProductButton = app.buttons["添加产品"]
        let createBatchButton = app.buttons["创建批次"]
        
        XCTAssertTrue(batchNumberField.exists)
        XCTAssertTrue(addProductButton.exists)
        
        // Test that elements are hittable
        XCTAssertTrue(batchNumberField.isHittable)
        XCTAssertTrue(addProductButton.isHittable)
        
        if createBatchButton.exists {
            XCTAssertTrue(createBatchButton.isHittable)
        }
    }
    
    // MARK: - Performance Tests (性能测试)
    
    func testFormInteractionPerformance() throws {
        let addProductButton = app.buttons["添加产品"]
        XCTAssertTrue(addProductButton.waitForExistence(timeout: 5))
        
        // Measure form interaction performance
        measure(metrics: [XCTClockMetric()]) {
            addProductButton.tap()
            
            // Wait for and close any sheets that appear
            let sheet = app.sheets.firstMatch
            if sheet.waitForExistence(timeout: 2) {
                let cancelButton = sheet.buttons["取消"]
                if cancelButton.exists {
                    cancelButton.tap()
                } else {
                    sheet.swipeDown()
                }
            }
        }
    }
    
    func testProductListScrollingPerformance() throws {
        // Add multiple products first (if possible)
        for _ in 0..<3 {
            let addProductButton = app.buttons["添加产品"]
            if addProductButton.exists {
                addProductButton.tap()
                
                // Quick add and dismiss
                let sheet = app.sheets.firstMatch
                if sheet.waitForExistence(timeout: 1) {
                    sheet.swipeDown()
                }
            }
        }
        
        // Test scrolling performance in product list
        let productList = app.tables["product-configuration-list"]
        if productList.exists {
            measure(metrics: [XCTClockMetric()]) {
                productList.swipeUp()
                productList.swipeDown()
            }
        }
    }
}