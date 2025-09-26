//
//  PerformanceTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Comprehensive performance test suite
//

import XCTest
import SwiftUI
@testable import Lopan

/// Comprehensive performance test suite targeting 60fps with large datasets
/// Tests memory efficiency, scroll performance, and system responsiveness
final class PerformanceTests: XCTestCase {

    private var testFramework: LopanTestingFramework!
    private var mockDependencies: MockAppDependencies!

    override func setUp() async throws {
        try await super.setUp()

        testFramework = LopanTestingFramework.shared
        testFramework.configure(LopanTestingFramework.TestConfiguration(
            enablePerformanceMetrics: true,
            testDataSize: .large,
            timeoutInterval: 60.0
        ))

        mockDependencies = testFramework.createMockDependencies()
    }

    override func tearDown() async throws {
        testFramework = nil
        mockDependencies = nil

        // Clean up performance monitoring
        LopanPerformanceProfiler.shared.stopMonitoring()
        LopanMemoryManager.shared.stopOptimization()

        try await super.tearDown()
    }

    // MARK: - Scroll Performance Tests

    func testVirtualListPerformanceWithLargeDataset() async throws {
        let testData = testFramework.generateTestData(for: CustomerOutOfStock.self, count: 10000)

        let result = try await testFramework.performanceTest(
            name: "VirtualList with 10K items",
            iterations: 5
        ) {
            // Simulate virtual list operations
            let stateManager = VirtualListStateManager<CustomerOutOfStock>(
                configuration: VirtualListConfiguration(
                    bufferSize: 20,
                    estimatedItemHeight: 120,
                    maxVisibleItems: 50,
                    prefetchRadius: 10,
                    recyclingEnabled: true
                )
            )

            await stateManager.updateItems(testData, viewportHeight: 800)
            return stateManager.getVisibleItemsInfo().visible
        }

        // Assert performance targets
        XCTAssertLessThan(result.averageDuration, 0.1, "VirtualList update should take < 100ms")
        XCTAssertLessThan(result.averageMemoryDelta, 50.0, "Memory delta should be < 50MB")

        print(result.summary)
    }

    func testScrollOptimizerPerformance() async throws {
        let scrollOptimizer = LopanScrollOptimizer.shared
        scrollOptimizer.startOptimization()

        let result = try await testFramework.performanceTest(
            name: "Scroll Optimizer Operations",
            iterations: 100
        ) {
            // Simulate rapid scroll events
            for i in 0..<50 {
                let velocity = CGFloat.random(in: -2000...2000)
                let visibleRange = VisibleRange(startIndex: i, endIndex: i + 10)

                scrollOptimizer.recordScrollEvent(
                    velocity: velocity,
                    contentOffset: CGPoint(x: 0, y: CGFloat(i * 120)),
                    visibleRange: visibleRange,
                    itemCount: 10000
                )
            }

            return scrollOptimizer.getOptimizationRecommendations().count
        }

        XCTAssertLessThan(result.averageDuration, 0.016, "Scroll events should process within 16ms (60fps)")
        print(result.summary)

        scrollOptimizer.stopOptimization()
    }

    // MARK: - Memory Performance Tests

    func testMemoryManagerPerformance() async throws {
        let memoryManager = LopanMemoryManager.shared
        memoryManager.startOptimization()

        let result = try await testFramework.performanceTest(
            name: "Memory Manager Operations",
            iterations: 20
        ) {
            // Create and cache many images
            for i in 0..<100 {
                let image = UIImage(systemName: "star.fill") ?? UIImage()
                memoryManager.cacheImage(image, forKey: "test_\(i)", category: "performance_test")
            }

            // Trigger cleanup
            memoryManager.performMemoryCleanup()

            return memoryManager.getMemoryStatistics().currentUsage.currentMB
        }

        XCTAssertLessThan(result.averageDuration, 0.5, "Memory operations should complete quickly")
        print(result.summary)

        memoryManager.stopOptimization()
        memoryManager.clearAllCaches()
    }

    func testMemoryLeakDetection() async throws {
        let initialMemory = getCurrentMemoryUsage()

        // Create and release many objects
        for iteration in 0..<10 {
            autoreleasepool {
                let testData = testFramework.generateTestData(for: Product.self, count: 1000)

                // Use the data briefly
                let filteredData = testData.filter { $0.isActive }
                XCTAssertGreaterThan(filteredData.count, 0)
            }

            // Force garbage collection
            if iteration % 3 == 0 {
                // Trigger memory pressure to force cleanup
                LopanMemoryManager.shared.performMemoryCleanup()
            }
        }

        let finalMemory = getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory

        XCTAssertLessThan(memoryGrowth, 100.0, "Memory growth should be < 100MB after releasing objects")
        print("Memory growth: \(memoryGrowth, specifier: "%.2f")MB")
    }

    // MARK: - Database Performance Tests

    func testSwiftDataBatchOperations() async throws {
        let container = try testFramework.createTestContainer()
        let context = ModelContext(container)

        let testUsers = testFramework.generateTestData(for: User.self, count: 5000)

        let result = try await testFramework.performanceTest(
            name: "SwiftData Batch Insert 5K Users",
            iterations: 3
        ) {
            for user in testUsers {
                context.insert(user)
            }

            try context.save()
            return testUsers.count
        }

        XCTAssertLessThan(result.averageDuration, 2.0, "Batch insert should complete within 2 seconds")
        print(result.summary)
    }

    func testSwiftDataQueryPerformance() async throws {
        let container = try testFramework.createTestContainer()
        let context = ModelContext(container)

        // Pre-populate with test data
        let testCustomers = testFramework.generateTestData(for: Customer.self, count: 10000)
        for customer in testCustomers {
            context.insert(customer)
        }
        try context.save()

        let result = try await testFramework.performanceTest(
            name: "SwiftData Query 10K Customers",
            iterations: 10
        ) {
            let descriptor = FetchDescriptor<Customer>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\.name)]
            )

            return try context.fetch(descriptor).count
        }

        XCTAssertLessThan(result.averageDuration, 0.1, "Query should execute within 100ms")
        print(result.summary)
    }

    // MARK: - Network Performance Tests

    func testNetworkRequestPerformance() async throws {
        let mockClient = MockNetworkClient()

        // Mock successful responses
        for i in 0..<100 {
            let responseData = """
            {"id": \(i), "name": "Test Item \(i)", "status": "active"}
            """.data(using: .utf8)!

            mockClient.mockResponse(for: "https://api.test.com/items/\(i)", data: responseData)
        }

        let result = try await testFramework.performanceTest(
            name: "100 Network Requests",
            iterations: 5
        ) {
            return try await withTaskGroup(of: Data.self, returning: Int.self) { group in
                for i in 0..<100 {
                    group.addTask {
                        return try await mockClient.get(url: "https://api.test.com/items/\(i)")
                    }
                }

                var count = 0
                for try await _ in group {
                    count += 1
                }
                return count
            }
        }

        XCTAssertLessThan(result.averageDuration, 1.0, "100 concurrent requests should complete within 1 second")
        print(result.summary)
    }

    // MARK: - UI Performance Tests

    func testViewTransitionPerformance() async throws {
        let profiler = LopanPerformanceProfiler.shared
        profiler.startMonitoring()

        let result = try await testFramework.performanceTest(
            name: "View Transitions",
            iterations: 20
        ) {
            // Simulate view transitions
            let transitionDuration = CFTimeInterval.random(in: 0.05...0.25)
            profiler.recordViewTransition(
                from: "TestViewA",
                to: "TestViewB",
                duration: transitionDuration
            )

            return transitionDuration
        }

        XCTAssertLessThan(result.averageDuration, 0.001, "Recording view transitions should be instant")

        // Check that no performance alerts were generated for normal transitions
        let alertCount = profiler.performanceAlerts.count
        XCTAssertEqual(alertCount, 0, "No performance alerts should be generated for normal transitions")

        print(result.summary)
        profiler.stopMonitoring()
    }

    // MARK: - Animation Performance Tests

    func testAnimationFrameRate() async throws {
        let profiler = LopanPerformanceProfiler.shared
        profiler.startMonitoring()

        // Simulate animation frames
        let result = try await testFramework.performanceTest(
            name: "Animation Frame Monitoring",
            iterations: 1
        ) {
            // Simulate 2 seconds of animation at target 60fps
            let targetFrameCount = 120
            var frameCount = 0

            let startTime = CFAbsoluteTimeGetCurrent()

            while frameCount < targetFrameCount {
                // Simulate frame processing time
                try await Task.sleep(nanoseconds: 8_333_333) // ~120fps to test monitoring
                frameCount += 1
            }

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            return Int(60.0 / duration * 2.0) // Calculate effective FPS
        }

        // Check that frame rate monitoring captured the animation
        let currentFPS = profiler.currentMetrics.currentFPS
        XCTAssertGreaterThan(currentFPS, 50.0, "Frame rate monitoring should detect high FPS")

        print("Detected FPS: \(currentFPS)")
        print(result.summary)

        profiler.stopMonitoring()
    }

    // MARK: - Load Testing

    func testHighConcurrencyOperations() async throws {
        let result = try await testFramework.performanceTest(
            name: "High Concurrency Operations",
            iterations: 3
        ) {
            return try await withTaskGroup(of: Int.self, returning: Int.self) { group in
                // Spawn 50 concurrent tasks
                for i in 0..<50 {
                    group.addTask {
                        let data = testFramework.generateTestData(for: Product.self, count: 100)

                        // Simulate processing
                        let activeProducts = data.filter { $0.isActive }
                        let sortedProducts = activeProducts.sorted { $0.name < $1.name }

                        return sortedProducts.count
                    }
                }

                var totalCount = 0
                for try await count in group {
                    totalCount += count
                }

                return totalCount
            }
        }

        XCTAssertLessThan(result.averageDuration, 5.0, "High concurrency operations should complete within 5 seconds")
        print(result.summary)
    }

    // MARK: - App Launch Performance

    func testAppLaunchSimulation() async throws {
        let result = try await testFramework.performanceTest(
            name: "App Launch Simulation",
            iterations: 5
        ) {
            // Simulate app launch steps
            let profiler = LopanPerformanceProfiler.shared
            let memoryManager = LopanMemoryManager.shared

            // Start services
            profiler.startMonitoring()
            memoryManager.startOptimization()

            // Load initial data
            let users = testFramework.generateTestData(for: User.self, count: 50)
            let customers = testFramework.generateTestData(for: Customer.self, count: 200)
            let products = testFramework.generateTestData(for: Product.self, count: 500)

            // Process initial data
            let activeUsers = users.filter { $0.isActive }
            let activeCustomers = customers.filter { $0.isActive }
            let activeProducts = products.filter { $0.isActive }

            // Stop services
            profiler.stopMonitoring()
            memoryManager.stopOptimization()
            memoryManager.clearAllCaches()

            return activeUsers.count + activeCustomers.count + activeProducts.count
        }

        XCTAssertLessThan(result.averageDuration, 1.5, "App launch simulation should complete within 1.5 seconds")
        print(result.summary)
    }

    // MARK: - Helper Methods

    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Double(info.resident_size) / (1024 * 1024) : 0.0
    }
}

// MARK: - Repository Protocol Extensions for Testing

extension MockUserRepository: HasUserRepository {
    public var users: UserRepository { self }
}

extension MockCustomerRepository: HasCustomerRepository {
    public var customers: CustomerRepository { self }
}

extension MockProductRepository: HasProductRepository {
    public var products: ProductRepository { self }
}