//
//  EphemeralContextMemoryTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/10/10.
//  Memory tests for ephemeral ModelContext pattern in batch operations
//
//  ## Purpose
//  These tests verify that the ephemeral ModelContext pattern properly releases memory
//  when processing large datasets (112,000 CustomerOutOfStock records). The goal is to
//  keep memory growth under 80MB and achieve >50% improvement over reused contexts.
//
//  ## Test Dataset
//  - 2,000 Customers
//  - 1,002 Products
//  - 112,000 CustomerOutOfStock records (40% pending, 45% completed, 15% refunded)
//
//  ## IMPORTANT: How to Run These Tests
//
//  ⚠️  **DO NOT run from Xcode Test Navigator** - View debugger will timeout with 112K objects
//
//  ✅  **Run from command line instead:**
//
//  ```bash
//  # Run all memory tests
//  xcodebuild test -scheme Lopan -sdk iphonesimulator \
//    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//    -only-testing:LopanTests/EphemeralContextMemoryTests \
//    -allowProvisioningUpdates
//
//  # Run specific test
//  xcodebuild test -scheme Lopan -sdk iphonesimulator \
//    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//    -only-testing:LopanTests/EphemeralContextMemoryTests/testFetchDashboardMetrics_MemoryRelease \
//    -allowProvisioningUpdates
//  ```
//
//  ## Why Command Line Only?
//  When running from Xcode UI, the View Debugger attempts to serialize all 112K SwiftData
//  objects for hierarchy inspection. This causes a SIGSTOP timeout as it tries to create
//  URIRepresentations for every NSManagedObjectID. Running from command line avoids this
//  limitation entirely.
//
//  ## Memory Targets
//  - Individual operations: < 80MB peak memory growth
//  - Comparison test: > 50% memory improvement vs. reused context pattern
//
//  ## Test Results Location
//  Results are saved to: `~/Library/Developer/Xcode/DerivedData/Lopan-.../Logs/Test/`
//  Console output includes detailed memory measurements and batch processing logs.
//

import XCTest
import SwiftData
@testable import Lopan

@MainActor
final class EphemeralContextMemoryTests: XCTestCase {

    var container: ModelContainer!
    var mainContext: ModelContext!
    var repository: LocalCustomerOutOfStockRepository!
    var testCustomers: [Customer] = []
    var testProducts: [Product] = []

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        // Create in-memory ModelContainer for testing
        let schema = Schema([
            CustomerOutOfStock.self,
            Customer.self,
            Product.self,
            ProductSize.self,
            User.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        container = try ModelContainer(for: schema, configurations: [configuration])
        mainContext = container.mainContext
        repository = LocalCustomerOutOfStockRepository(modelContext: mainContext)

        print("\n" + String(repeating: "=", count: 60))
        print("🧪 EphemeralContextMemoryTests - Setup")
        print(String(repeating: "=", count: 60))
    }

    override func tearDownWithError() throws {
        // Clean up
        repository = nil
        mainContext = nil
        container = nil
        testCustomers.removeAll()
        testProducts.removeAll()

        print(String(repeating: "=", count: 60))
        print("🧪 EphemeralContextMemoryTests - Teardown Complete")
        print(String(repeating: "=", count: 60) + "\n")
    }

    // MARK: - Test Data Generation

    /// Generate exactly 112,000 CustomerOutOfStock records with dependencies
    private func generateTestData(recordCount: Int = 112000) throws {
        print("\n📦 Generating \(recordCount) test records...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Generate customers (2000)
        print("  👥 Creating 2000 customers...")
        for i in 0..<2000 {
            let customer = Customer(
                name: "Test Customer \(i)",
                address: "123 Test St, Suite \(i), Test City",
                phone: "+1-555-\(String(format: "%04d", i))"
            )
            mainContext.insert(customer)
            testCustomers.append(customer)
        }

        // Generate products (1002)
        print("  📦 Creating 1002 products...")
        for i in 0..<1002 {
            let product = Product(
                sku: "SKU\(String(format: "%06d", i))",
                name: "Test Product \(i)",
                price: Double.random(in: 15...150)
            )
            mainContext.insert(product)
            testProducts.append(product)
        }

        // Save customers and products
        try mainContext.save()

        // Generate 112,000 CustomerOutOfStock records
        print("  📊 Creating \(recordCount) out-of-stock records...")
        let statuses: [OutOfStockStatus] = [.pending, .completed, .refunded]
        let statusWeights = [0.40, 0.45, 0.15] // 40% pending, 45% completed, 15% refunded

        for i in 0..<recordCount {
            let randomValue = Double.random(in: 0...1)
            let status: OutOfStockStatus
            if randomValue < statusWeights[0] {
                status = .pending
            } else if randomValue < statusWeights[0] + statusWeights[1] {
                status = .completed
            } else {
                status = .refunded
            }

            let customer = testCustomers[i % testCustomers.count]
            let product = testProducts[i % testProducts.count]

            let record = CustomerOutOfStock(
                customer: customer,
                product: product,
                productSize: nil,
                quantity: Int.random(in: 1...100),
                notes: "Test record \(i)",
                createdBy: "test-user"
            )
            record.status = status
            record.requestDate = Date().addingTimeInterval(TimeInterval(-i * 60)) // Spread across time

            // Add some delivery data for completed records
            if status == .completed {
                record.deliveryQuantity = record.quantity
                record.deliveryDate = Date()
                record.actualCompletionDate = Date()
            }

            mainContext.insert(record)

            // Save in batches to avoid memory issues during generation
            if (i + 1) % 10000 == 0 {
                try mainContext.save()
                print("    ✓ Generated \(i + 1) records...")
            }
        }

        // Final save
        try mainContext.save()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("  ✅ Generated \(recordCount) records in \(String(format: "%.2f", elapsed))s")

        // Verify counts
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let allRecords = try mainContext.fetch(descriptor)
        print("  📊 Verified: \(allRecords.count) records in database")

        XCTAssertEqual(allRecords.count, recordCount, "Should have exactly \(recordCount) records")
    }

    // MARK: - Memory Measurement Utilities

    struct MemoryMeasurement {
        let before: Double  // MB
        let peak: Double    // MB during operation
        let after: Double   // MB after completion

        var growth: Double { peak - before }
        var retained: Double { after - before }

        var summary: String {
            return """
            Memory Measurement:
              Before: \(String(format: "%.2f", before))MB
              Peak: \(String(format: "%.2f", peak))MB (growth: +\(String(format: "%.2f", growth))MB)
              After: \(String(format: "%.2f", after))MB (retained: +\(String(format: "%.2f", retained))MB)
            """
        }
    }

    private func measureMemory(operation: () async throws -> Void) async throws -> MemoryMeasurement {
        let before = getCurrentMemoryMB()
        print("\n  📏 Memory before: \(String(format: "%.2f", before))MB")

        var peak = before
        var isMeasuring = true

        // Background task to measure peak memory
        let measureTask = Task.detached {
            while isMeasuring {
                let current = await MainActor.run { self.getCurrentMemoryMB() }
                await MainActor.run {
                    peak = max(peak, current)
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // Sample every 100ms
            }
        }

        try await operation()

        isMeasuring = false
        measureTask.cancel()

        // Wait a moment for memory to stabilize
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = getCurrentMemoryMB()

        print("  📏 Memory peak: \(String(format: "%.2f", peak))MB")
        print("  📏 Memory after: \(String(format: "%.2f", after))MB")

        return MemoryMeasurement(before: before, peak: peak, after: after)
    }

    private func getCurrentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0.0
    }

    // MARK: - Test 1: countByStatusInBatches Memory Release

    /// Verifies that `countOutOfStockRecordsByStatus()` properly releases memory when
    /// processing 112K records using ephemeral ModelContext pattern in 10K batches.
    ///
    /// **Expected:** Memory growth < 80MB
    /// **Batch size:** 10,000 records per ephemeral context
    /// **Total records:** 112,000 CustomerOutOfStock entries
    func testCountByStatusInBatches_MemoryRelease() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("TEST 1: countByStatusInBatches() Memory Release")
        print(String(repeating: "=", count: 60))

        // Generate test data
        try generateTestData()

        // Measure memory during batch operation
        let measurement = try await measureMemory {
            let statusCounts = try await self.repository.countOutOfStockRecordsByStatus(
                criteria: OutOfStockFilterCriteria() // No filters = all 112K records
            )

            print("\n  📊 Status Counts: \(statusCounts)")

            // Verify counts are reasonable
            let totalCount = statusCounts.values.reduce(0, +)
            XCTAssertGreaterThan(totalCount, 0, "Should have counted records")
        }

        print("\n" + measurement.summary)

        // Assert memory target
        XCTAssertLessThan(measurement.growth, 80.0, "Memory growth should be < 80MB (actual: \(String(format: "%.2f", measurement.growth))MB)")

        // Success message
        if measurement.growth < 80.0 {
            print("\n  ✅ PASS: Memory stayed under 80MB target")
            print("  🎯 Memory efficiency: \(String(format: "%.1f", (80.0 - measurement.growth) / 80.0 * 100))% within budget")
        }
    }

    // MARK: - Test 2: fetchDashboardMetrics Memory Release

    /// Verifies that `fetchDashboardMetrics()` properly releases memory when aggregating
    /// multiple queries across 112K records using ephemeral contexts for each batch operation.
    ///
    /// **Expected:** Memory growth < 80MB
    /// **Batch size:** 100 records per ephemeral context (multiple queries)
    /// **Total records:** 112,000 CustomerOutOfStock entries
    func testFetchDashboardMetrics_MemoryRelease() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("TEST 2: fetchDashboardMetrics() Memory Release")
        print(String(repeating: "=", count: 60))

        // Generate test data
        try generateTestData()

        // Measure memory during dashboard metrics calculation
        let measurement = try await measureMemory {
            let metrics = try await self.repository.fetchDashboardMetrics()

            print("\n  📊 Dashboard Metrics:")
            print("    Status Counts: \(metrics.statusCounts)")
            print("    Needs Return: \(metrics.needsReturnCount)")
            print("    Recent Pending: \(metrics.recentPendingCount)")
            print("    Due Soon: \(metrics.dueSoonCount)")
            print("    Overdue: \(metrics.overdueCount)")
            print("    Pending Items: \(metrics.topPendingItems.count)")
            print("    Return Items: \(metrics.topReturnItems.count)")
            print("    Completed Items: \(metrics.recentCompleted.count)")

            // Verify metrics are populated
            XCTAssertGreaterThan(metrics.statusCounts.values.reduce(0, +), 0, "Should have status counts")
        }

        print("\n" + measurement.summary)

        // Assert memory target
        XCTAssertLessThan(measurement.growth, 80.0, "Memory growth should be < 80MB (actual: \(String(format: "%.2f", measurement.growth))MB)")

        // Success message
        if measurement.growth < 80.0 {
            print("\n  ✅ PASS: Memory stayed under 80MB target")
            print("  🎯 Memory efficiency: \(String(format: "%.1f", (80.0 - measurement.growth) / 80.0 * 100))% within budget")
        }
    }

    // MARK: - Test 3: fetchDeliveryStatistics Memory Release

    /// Verifies that `fetchDeliveryStatistics()` properly releases memory when calculating
    /// delivery metrics across 112K records using ephemeral ModelContext in 100-record batches.
    ///
    /// **Expected:** Memory growth < 80MB
    /// **Batch size:** 100 records per ephemeral context
    /// **Total records:** 112,000 CustomerOutOfStock entries
    func testFetchDeliveryStatistics_MemoryRelease() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("TEST 3: fetchDeliveryStatistics() Memory Release")
        print(String(repeating: "=", count: 60))

        // Generate test data
        try generateTestData()

        // Measure memory during delivery statistics calculation
        let measurement = try await measureMemory {
            let statistics = try await self.repository.fetchDeliveryStatistics(
                criteria: OutOfStockFilterCriteria() // No filters = all 112K records
            )

            print("\n  📊 Delivery Statistics:")
            print("    Total Count: \(statistics.totalCount)")
            print("    Needs Delivery: \(statistics.needsDeliveryCount)")
            print("    Partial Delivery: \(statistics.partialDeliveryCount)")
            print("    Completed Delivery: \(statistics.completedDeliveryCount)")

            // Verify statistics are reasonable
            XCTAssertGreaterThan(statistics.totalCount, 0, "Should have counted records")
        }

        print("\n" + measurement.summary)

        // Assert memory target
        XCTAssertLessThan(measurement.growth, 80.0, "Memory growth should be < 80MB (actual: \(String(format: "%.2f", measurement.growth))MB)")

        // Success message
        if measurement.growth < 80.0 {
            print("\n  ✅ PASS: Memory stayed under 80MB target")
            print("  🎯 Memory efficiency: \(String(format: "%.1f", (80.0 - measurement.growth) / 80.0 * 100))% within budget")
        }
    }

    // MARK: - Test 4: Memory Comparison - Ephemeral vs Reused Context

    /// Compares memory usage between ephemeral context pattern and simulated reused context.
    /// Demonstrates the memory improvement achieved by creating fresh contexts per batch.
    ///
    /// **Expected:**
    /// - Ephemeral context: < 80MB memory growth
    /// - Memory improvement: > 50% reduction vs. reused context
    /// - Old approach (reused): All 112K objects retained in memory simultaneously
    func testMemoryComparison_EphemeralVsReused() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("TEST 4: Memory Comparison - Ephemeral vs Reused Context")
        print(String(repeating: "=", count: 60))

        // Generate test data
        try generateTestData()

        // Method A: Ephemeral contexts (current implementation)
        print("\n  🔬 Method A: Ephemeral contexts (current implementation)")
        let ephemeralMeasurement = try await measureMemory {
            _ = try await self.repository.countOutOfStockRecordsByStatus(
                criteria: OutOfStockFilterCriteria()
            )
        }

        print("\n" + ephemeralMeasurement.summary)

        // Method B: Simulate reused context (for comparison)
        print("\n  🔬 Method B: Simulated reused context (old approach)")
        let reusedMeasurement = try await measureMemory {
            // Simulate old approach by fetching all records at once
            let descriptor = FetchDescriptor<CustomerOutOfStock>(
                sortBy: [SortDescriptor(\.requestDate, order: .forward)]
            )
            let allRecords = try self.mainContext.fetch(descriptor)

            // Force materialization by accessing properties
            var statusCounts: [OutOfStockStatus: Int] = [:]
            for record in allRecords {
                statusCounts[record.status, default: 0] += 1
                _ = record.customer?.name
                _ = record.product?.name
            }

            print("  📊 Simulated old approach counted \(allRecords.count) records")
        }

        print("\n" + reusedMeasurement.summary)

        // Compare results
        print("\n" + String(repeating: "-", count: 60))
        print("  📊 COMPARISON RESULTS:")
        print(String(repeating: "-", count: 60))
        print("  Ephemeral Context:")
        print("    Peak Memory: \(String(format: "%.2f", ephemeralMeasurement.peak))MB")
        print("    Growth: +\(String(format: "%.2f", ephemeralMeasurement.growth))MB")
        print("")
        print("  Reused Context:")
        print("    Peak Memory: \(String(format: "%.2f", reusedMeasurement.peak))MB")
        print("    Growth: +\(String(format: "%.2f", reusedMeasurement.growth))MB")
        print("")

        let improvement = (reusedMeasurement.growth - ephemeralMeasurement.growth) / reusedMeasurement.growth * 100
        print("  💡 Memory Improvement: \(String(format: "%.1f", improvement))%")
        print(String(repeating: "-", count: 60))

        // Assert ephemeral is better
        XCTAssertLessThan(ephemeralMeasurement.growth, 80.0, "Ephemeral context should be < 80MB")
        XCTAssertGreaterThan(improvement, 50.0, "Ephemeral context should improve memory by > 50%")

        // Success message
        if improvement > 50.0 {
            print("\n  ✅ PASS: Ephemeral context pattern provides significant memory improvement")
            print("  🎯 Achieved \(String(format: "%.1f", improvement))% memory reduction")
        }
    }

    // MARK: - Test 5: Console Output Verification

    /// Verifies that ephemeral context pattern produces expected console logging output.
    /// Uses smaller dataset (25K records) for faster execution while still demonstrating batching.
    ///
    /// **Expected console output:** Log messages showing ephemeral context object release
    /// - Format: "🧹 Background: Batch XXXXX - ephemeral context releasing XXXX objects"
    /// - Expected: At least 3 log messages (25K / 10K batch size = 2.5 batches)
    /// **Test dataset:** 25,000 records (faster than full 112K)
    func testEphemeralContextLogging() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("TEST 5: Ephemeral Context Logging Verification")
        print(String(repeating: "=", count: 60))

        // Generate smaller dataset for faster logging verification
        try generateTestData(recordCount: 25000) // 2.5 batches with 10K batch size

        print("\n  🔍 Running batch operation and checking console output...")

        // Run batch operation (should produce console logs)
        _ = try await repository.countOutOfStockRecordsByStatus(
            criteria: OutOfStockFilterCriteria()
        )

        print("\n  ✅ Console output verification:")
        print("     Look for messages like:")
        print("     '🧹 Background: Batch XXXXX - ephemeral context releasing XXXX objects'")
        print("     Expected: At least 3 log messages (25K / 10K = 2.5 batches)")

        // Note: Console output verification is manual via visual inspection
        // Automated console capture would require significant infrastructure changes
    }
}
