//
//  CustomerOutOfStockNavigationStateTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/8/21.
//

import XCTest
@testable import Lopan

@MainActor
final class CustomerOutOfStockNavigationStateTests: XCTestCase {
    
    var navigationState: CustomerOutOfStockNavigationState!
    
    override func setUp() async throws {
        navigationState = CustomerOutOfStockNavigationState.shared
        navigationState.resetToDefaults()
    }
    
    override func tearDown() async throws {
        navigationState.resetToDefaults()
        navigationState = nil
    }
    
    // MARK: - State Preservation Tests
    
    func testStatePreservation() throws {
        // Given
        let testDate = Date()
        navigationState.selectedDate = testDate
        navigationState.selectedStatusFilter = .pending
        navigationState.searchText = "test search"
        
        // When
        navigationState.markNavigationStart()
        
        // Then
        XCTAssertEqual(navigationState.selectedDate, testDate)
        XCTAssertEqual(navigationState.selectedStatusFilter, .pending)
        XCTAssertEqual(navigationState.searchText, "test search")
        XCTAssertTrue(navigationState.hasActiveFilters)
    }
    
    func testShouldRefreshDataLogic() throws {
        // Given - fresh state
        XCTAssertTrue(navigationState.shouldRefreshData())
        
        // When - mark as refreshed
        navigationState.markDataRefreshed()
        
        // Then - should not refresh immediately
        XCTAssertFalse(navigationState.shouldRefreshData())
        
        // When - simulate navigation
        navigationState.markNavigationStart()
        
        // Then - should not refresh if recently navigated
        XCTAssertFalse(navigationState.shouldRefreshData())
    }
    
    func testActiveFiltersCount() throws {
        // Given - no filters
        XCTAssertEqual(navigationState.activeFiltersCount, 0)
        XCTAssertFalse(navigationState.hasActiveFilters)
        
        // When - add filters
        navigationState.selectedStatusFilter = .pending
        navigationState.searchText = "test"
        
        // Then - should count active filters
        XCTAssertEqual(navigationState.activeFiltersCount, 2)
        XCTAssertTrue(navigationState.hasActiveFilters)
    }
    
    func testDateFilterApplication() throws {
        // Given
        let testOption = DateFilterOption.thisWeek
        
        // When
        navigationState.applyDateFilter(testOption)
        
        // Then
        XCTAssertEqual(navigationState.dateFilterMode, testOption)
        XCTAssertNotNil(navigationState.customDateRange)
    }
    
    func testFilterSummaryText() throws {
        // Given
        navigationState.selectedStatusFilter = .pending
        navigationState.searchText = "test product"
        
        // When
        let summary = navigationState.filterSummaryText
        
        // Then
        XCTAssertTrue(summary.contains("状态: 待处理"))
        XCTAssertTrue(summary.contains("搜索: test product"))
    }
    
    func testClearAllFilters() throws {
        // Given - set some filters
        navigationState.selectedStatusFilter = .pending
        navigationState.searchText = "test"
        navigationState.showingAdvancedFilters = true
        
        // When
        navigationState.clearAllFilters()
        
        // Then
        XCTAssertEqual(navigationState.selectedStatusFilter, .all)
        XCTAssertEqual(navigationState.searchText, "")
        XCTAssertFalse(navigationState.showingAdvancedFilters)
        XCTAssertFalse(navigationState.hasActiveFilters)
    }
    
    // MARK: - Performance Tests
    
    func testFilterValidationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = navigationState.validateFilterCombinations()
            }
        }
    }
    
    func testFilterSummaryPerformance() throws {
        navigationState.selectedStatusFilter = .pending
        navigationState.searchText = "test search text"
        
        measure {
            for _ in 0..<1000 {
                _ = navigationState.filterSummaryText
            }
        }
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchDebouncing() throws {
        let expectation = XCTestExpectation(description: "Search debounce")
        
        // When
        navigationState.setSearchText("test1")
        navigationState.setSearchText("test2")
        navigationState.setSearchText("final search")
        
        // Then - only final search should be applied after debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.navigationState.searchText, "final search")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testImmediateSearch() throws {
        // When
        navigationState.performImmediateSearch("immediate test")
        
        // Then
        XCTAssertEqual(navigationState.searchText, "immediate test")
    }
}

// MARK: - Test Data Generation

extension CustomerOutOfStockNavigationStateTests {
    
    static func createTestCustomers() -> [Customer] {
        return [
            Customer(
                name: "重要客户 001",
                address: "济南中心区胜利路713号大厦",
                phone: "138****1001",
                customerLevel: .vip
            ),
            Customer(
                name: "重要客户 002", 
                address: "佛山商务区友谊路496号广场",
                phone: "138****1002",
                customerLevel: .vip
            ),
            Customer(
                name: "普通客户 003",
                address: "青岛市北区新昌路88号",
                phone: "138****1003",
                customerLevel: .normal
            )
        ]
    }
    
    static func createTestProducts() -> [Product] {
        return [
            Product(
                name: "限量商务毛衣",
                category: "服装",
                colors: ["绿色", "黑色", "酒红色", "米色"],
                sizes: [
                    ProductSize(size: "M", stockQuantity: 50),
                    ProductSize(size: "L", stockQuantity: 30),
                    ProductSize(size: "XL", stockQuantity: 20)
                ]
            ),
            Product(
                name: "热销宽松衬衫", 
                category: "服装",
                colors: ["绿色", "橙色", "红色", "米色"],
                sizes: [
                    ProductSize(size: "XXL", stockQuantity: 40),
                    ProductSize(size: "L", stockQuantity: 25),
                    ProductSize(size: "M", stockQuantity: 35)
                ]
            )
        ]
    }
    
    static func createTestOutOfStockItems(customers: [Customer], products: [Product]) -> [CustomerOutOfStock] {
        var items: [CustomerOutOfStock] = []
        
        for (customerIndex, customer) in customers.enumerated() {
            for (productIndex, product) in products.enumerated() {
                let item = CustomerOutOfStock(
                    customer: customer,
                    product: product,
                    productSize: product.sizes?.first,
                    quantity: (customerIndex + 1) * (productIndex + 1) * 15,
                    notes: "测试缺货记录 - 客户\\(customerIndex + 1) 产品\\(productIndex + 1)",
                    createdBy: "test-user"
                )
                items.append(item)
            }
        }
        
        return items
    }
}

// MARK: - Mock Extensions for Testing

extension Customer {
    static let testVIPCustomer = Customer(
        name: "测试VIP客户",
        address: "测试地址123号",
        phone: "138****0000",
        customerLevel: .vip
    )
    
    static let testNormalCustomer = Customer(
        name: "测试普通客户",
        address: "测试地址456号", 
        phone: "138****0001",
        customerLevel: .normal
    )
}

extension Product {
    static let testProduct = Product(
        name: "测试产品",
        category: "测试分类",
        colors: ["红色", "蓝色"],
        sizes: [
            ProductSize(size: "M", stockQuantity: 100),
            ProductSize(size: "L", stockQuantity: 50)
        ]
    )
}

extension CustomerOutOfStock {
    static let testItem = CustomerOutOfStock(
        customer: Customer.testVIPCustomer,
        product: Product.testProduct,
        productSize: ProductSize(size: "M", stockQuantity: 100),
        quantity: 25,
        notes: "测试缺货记录",
        createdBy: "test-user"
    )
}