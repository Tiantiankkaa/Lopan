//
//  LopanTestingFramework.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Comprehensive unit testing framework
//

import XCTest
import SwiftUI
import SwiftData
import Combine
@testable import Lopan

/// Comprehensive testing framework for Lopan production app
/// Provides mock infrastructure, test utilities, and automated coverage tracking
@MainActor
public final class LopanTestingFramework {

    // MARK: - Singleton

    public static let shared = LopanTestingFramework()

    // MARK: - Test Infrastructure

    private var testContainer: ModelContainer?
    private var mockDependencies: MockAppDependencies?
    private var testCoverage: TestCoverageTracker = TestCoverageTracker()

    // MARK: - Configuration

    public struct TestConfiguration {
        var enablePerformanceMetrics = true
        var enableMemoryTracking = true
        var enableNetworkMocking = true
        var testDataSize: TestDataSize = .medium
        var timeoutInterval: TimeInterval = 30.0
    }

    public enum TestDataSize {
        case small  // 10-50 records
        case medium // 100-500 records
        case large  // 1000-5000 records
        case huge   // 10000+ records

        var recordCount: Int {
            switch self {
            case .small: return 25
            case .medium: return 250
            case .large: return 2500
            case .huge: return 10000
            }
        }
    }

    private var configuration = TestConfiguration()

    // MARK: - Initialization

    private init() {
        setupTestInfrastructure()
    }

    // MARK: - Public Interface

    /// Configure testing framework
    public func configure(_ config: TestConfiguration) {
        self.configuration = config
    }

    /// Create test container with in-memory storage
    public func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            User.self,
            Customer.self,
            Product.self,
            ProductionBatch.self,
            CustomerOutOfStock.self,
            PackagingRecord.self,
            ColorCard.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(for: schema, configurations: [configuration])
        testContainer = container
        return container
    }

    /// Create mock dependencies for testing
    public func createMockDependencies() -> MockAppDependencies {
        if let existing = mockDependencies {
            return existing
        }

        let deps = MockAppDependencies()
        mockDependencies = deps
        return deps
    }

    /// Generate test data for specific entity
    public func generateTestData<T: PersistentModel>(
        for type: T.Type,
        count: Int? = nil
    ) -> [T] {
        let actualCount = count ?? configuration.testDataSize.recordCount

        switch type {
        case is User.Type:
            return generateUsers(count: actualCount) as! [T]
        case is Customer.Type:
            return generateCustomers(count: actualCount) as! [T]
        case is Product.Type:
            return generateProducts(count: actualCount) as! [T]
        case is ProductionBatch.Type:
            return generateProductionBatches(count: actualCount) as! [T]
        case is CustomerOutOfStock.Type:
            return generateOutOfStockRecords(count: actualCount) as! [T]
        case is PackagingRecord.Type:
            return generatePackagingRecords(count: actualCount) as! [T]
        case is ColorCard.Type:
            return generateColorCards(count: actualCount) as! [T]
        default:
            fatalError("Unsupported test data type: \(type)")
        }
    }

    /// Run performance test with metrics
    public func performanceTest<T>(
        name: String,
        iterations: Int = 10,
        operation: () async throws -> T
    ) async throws -> PerformanceTestResult<T> {
        var results: [T] = []
        var durations: [TimeInterval] = []
        var memoryUsages: [Double] = []

        for i in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            let startMemory = getCurrentMemoryUsage()

            let result = try await operation()

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let endMemory = getCurrentMemoryUsage()

            results.append(result)
            durations.append(duration)
            memoryUsages.append(endMemory - startMemory)

            // Log progress
            print("🏃‍♂️ Performance test '\(name)' - Iteration \(i + 1)/\(iterations): \(duration * 1000, specifier: "%.2f")ms")
        }

        return PerformanceTestResult(
            name: name,
            iterations: iterations,
            results: results,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            minDuration: durations.min() ?? 0,
            maxDuration: durations.max() ?? 0,
            averageMemoryDelta: memoryUsages.reduce(0, +) / Double(memoryUsages.count)
        )
    }

    /// Track test coverage for methods and classes
    public func trackCoverage(for identifier: String, file: String = #file, function: String = #function) {
        testCoverage.recordExecution(identifier: identifier, file: file, function: function)
    }

    /// Get comprehensive coverage report
    public func getCoverageReport() -> TestCoverageReport {
        return testCoverage.generateReport()
    }
}

// MARK: - Mock Dependencies

@MainActor
public class MockAppDependencies: HasUserRepository, HasCustomerRepository, HasProductRepository {

    public let users: UserRepository
    public let customers: CustomerRepository
    public let products: ProductRepository
    public let outOfStock: CustomerOutOfStockRepository
    public let batches: ProductionBatchRepository
    public let packaging: PackagingRecordRepository

    init() {
        self.users = MockUserRepository()
        self.customers = MockCustomerRepository()
        self.products = MockProductRepository()
        self.outOfStock = MockCustomerOutOfStockRepository()
        self.batches = MockProductionBatchRepository()
        self.packaging = MockPackagingRecordRepository()
    }
}

// MARK: - Mock Repositories

public class MockUserRepository: UserRepository {
    private var users: [User] = []
    private var shouldThrow = false
    private var delay: TimeInterval = 0

    public func configure(shouldThrow: Bool = false, delay: TimeInterval = 0) {
        self.shouldThrow = shouldThrow
        self.delay = delay
    }

    public func fetch() async throws -> [User] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldThrow {
            throw MockError.simulatedFailure
        }

        return users
    }

    public func create(_ user: User) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        users.append(user)
    }

    public func update(_ user: User) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        }
    }

    public func delete(id: User.ID) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        users.removeAll { $0.id == id }
    }

    public func preloadTestData(_ testUsers: [User]) {
        users = testUsers
    }
}

public class MockCustomerRepository: CustomerRepository {
    private var customers: [Customer] = []
    private var shouldThrow = false

    public func configure(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }

    public func fetch() async throws -> [Customer] {
        if shouldThrow { throw MockError.simulatedFailure }
        return customers
    }

    public func create(_ customer: Customer) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        customers.append(customer)
    }

    public func update(_ customer: Customer) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index] = customer
        }
    }

    public func delete(id: Customer.ID) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        customers.removeAll { $0.id == id }
    }

    public func preloadTestData(_ testCustomers: [Customer]) {
        customers = testCustomers
    }
}

public class MockProductRepository: ProductRepository {
    private var products: [Product] = []
    private var shouldThrow = false

    public func configure(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }

    public func fetch() async throws -> [Product] {
        if shouldThrow { throw MockError.simulatedFailure }
        return products
    }

    public func create(_ product: Product) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        products.append(product)
    }

    public func update(_ product: Product) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        }
    }

    public func delete(id: Product.ID) async throws {
        if shouldThrow { throw MockError.simulatedFailure }
        products.removeAll { $0.id == id }
    }

    public func preloadTestData(_ testProducts: [Product]) {
        products = testProducts
    }
}

public class MockCustomerOutOfStockRepository: CustomerOutOfStockRepository {
    private var records: [CustomerOutOfStock] = []

    public func fetch() async throws -> [CustomerOutOfStock] {
        return records
    }

    public func create(_ record: CustomerOutOfStock) async throws {
        records.append(record)
    }

    public func update(_ record: CustomerOutOfStock) async throws {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        }
    }

    public func delete(id: CustomerOutOfStock.ID) async throws {
        records.removeAll { $0.id == id }
    }

    public func preloadTestData(_ testRecords: [CustomerOutOfStock]) {
        records = testRecords
    }
}

public class MockProductionBatchRepository: ProductionBatchRepository {
    private var batches: [ProductionBatch] = []

    public func fetch() async throws -> [ProductionBatch] {
        return batches
    }

    public func create(_ batch: ProductionBatch) async throws {
        batches.append(batch)
    }

    public func update(_ batch: ProductionBatch) async throws {
        if let index = batches.firstIndex(where: { $0.id == batch.id }) {
            batches[index] = batch
        }
    }

    public func delete(id: ProductionBatch.ID) async throws {
        batches.removeAll { $0.id == id }
    }

    public func preloadTestData(_ testBatches: [ProductionBatch]) {
        batches = testBatches
    }
}

public class MockPackagingRecordRepository: PackagingRecordRepository {
    private var records: [PackagingRecord] = []

    public func fetch() async throws -> [PackagingRecord] {
        return records
    }

    public func create(_ record: PackagingRecord) async throws {
        records.append(record)
    }

    public func update(_ record: PackagingRecord) async throws {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        }
    }

    public func delete(id: PackagingRecord.ID) async throws {
        records.removeAll { $0.id == id }
    }

    public func preloadTestData(_ testRecords: [PackagingRecord]) {
        records = testRecords
    }
}

// MARK: - Test Data Generation

extension LopanTestingFramework {

    private func generateUsers(count: Int) -> [User] {
        let roles: [UserRole] = [.salesperson, .warehouseKeeper, .workshopManager, .administrator]

        return (1...count).map { i in
            User(
                username: "testuser\(i)",
                role: roles[i % roles.count],
                firstName: "Test",
                lastName: "User \(i)",
                email: "testuser\(i)@lopan.com",
                isActive: true
            )
        }
    }

    private func generateCustomers(count: Int) -> [Customer] {
        let companies = ["TechCorp", "InnovateLtd", "GlobalSolutions", "SmartSystems", "FutureTech"]

        return (1...count).map { i in
            Customer(
                name: "Customer \(i)",
                company: companies[i % companies.count],
                email: "customer\(i)@company.com",
                phone: "+1-555-\(String(format: "%04d", i))",
                address: "123 Test Street, Suite \(i), Test City",
                isActive: true
            )
        }
    }

    private func generateProducts(count: Int) -> [Product] {
        let categories = ["Electronics", "Tools", "Parts", "Accessories", "Materials"]
        let units = ["pcs", "kg", "m", "l", "box"]

        return (1...count).map { i in
            Product(
                name: "Test Product \(i)",
                category: categories[i % categories.count],
                sku: "SKU\(String(format: "%06d", i))",
                unit: units[i % units.count],
                currentStock: Double.random(in: 0...1000),
                minimumStock: Double.random(in: 10...100),
                costPrice: Double.random(in: 1...100),
                sellingPrice: Double.random(in: 1.5...150),
                isActive: true
            )
        }
    }

    private func generateProductionBatches(count: Int) -> [ProductionBatch] {
        let statuses: [BatchStatus] = [.planned, .inProgress, .completed, .cancelled]

        return (1...count).map { i in
            ProductionBatch(
                batchNumber: "BATCH\(String(format: "%06d", i))",
                status: statuses[i % statuses.count],
                plannedStartDate: Date().addingTimeInterval(TimeInterval.random(in: -86400...86400)),
                actualStartDate: Date().addingTimeInterval(TimeInterval.random(in: -43200...43200)),
                estimatedCompletionDate: Date().addingTimeInterval(TimeInterval.random(in: 86400...172800)),
                actualCompletionDate: nil,
                totalQuantity: Int.random(in: 100...1000),
                completedQuantity: Int.random(in: 0...500),
                priority: BatchPriority.allCases.randomElement() ?? .medium,
                notes: "Test batch \(i) notes"
            )
        }
    }

    private func generateOutOfStockRecords(count: Int) -> [CustomerOutOfStock] {
        let statuses: [OutOfStockStatus] = [.pending, .completed, .returned]

        return (1...count).map { i in
            CustomerOutOfStock(
                customerName: "Customer \(i)",
                productName: "Product \(i)",
                quantityRequested: Double.random(in: 1...100),
                requestDate: Date().addingTimeInterval(TimeInterval.random(in: -86400...0)),
                status: statuses[i % statuses.count],
                urgencyLevel: UrgencyLevel.allCases.randomElement() ?? .medium,
                notes: "Test out-of-stock record \(i)"
            )
        }
    }

    private func generatePackagingRecords(count: Int) -> [PackagingRecord] {
        return (1...count).map { i in
            PackagingRecord(
                productName: "Product \(i)",
                quantity: Int.random(in: 1...100),
                packagingDate: Date().addingTimeInterval(TimeInterval.random(in: -86400...0)),
                packageType: "Box",
                weight: Double.random(in: 0.1...10.0),
                dimensions: "10x10x10",
                teamMemberName: "Team Member \(i % 5 + 1)",
                notes: "Test packaging record \(i)"
            )
        }
    }

    private func generateColorCards(count: Int) -> [ColorCard] {
        let colors = ["Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Pink", "Brown"]

        return (1...count).map { i in
            ColorCard(
                name: "\(colors[i % colors.count]) \(i)",
                hexCode: String(format: "#%06X", Int.random(in: 0...0xFFFFFF)),
                pantoneCode: "PMS \(i)",
                category: "Test Category",
                isActive: true,
                createdDate: Date().addingTimeInterval(TimeInterval.random(in: -86400...0)),
                lastUsedDate: Date().addingTimeInterval(TimeInterval.random(in: -43200...0))
            )
        }
    }

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

    private func setupTestInfrastructure() {
        // Initialize test infrastructure
        print("🧪 LopanTestingFramework initialized")
    }
}

// MARK: - Test Coverage Tracking

class TestCoverageTracker {
    private var executionCounts: [String: Int] = [:]
    private var fileExecutions: [String: Set<String>] = [:]

    func recordExecution(identifier: String, file: String, function: String) {
        executionCounts[identifier, default: 0] += 1

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        fileExecutions[fileName, default: Set()].insert(function)
    }

    func generateReport() -> TestCoverageReport {
        let totalMethods = executionCounts.count
        let executedMethods = executionCounts.values.filter { $0 > 0 }.count
        let coveragePercentage = totalMethods > 0 ? Double(executedMethods) / Double(totalMethods) * 100 : 0

        return TestCoverageReport(
            totalMethods: totalMethods,
            executedMethods: executedMethods,
            coveragePercentage: coveragePercentage,
            fileExecutions: fileExecutions,
            methodExecutions: executionCounts
        )
    }
}

// MARK: - Data Structures

public struct PerformanceTestResult<T> {
    let name: String
    let iterations: Int
    let results: [T]
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let averageMemoryDelta: Double

    public var summary: String {
        return """
        🏃‍♂️ Performance Test: \(name)
        Iterations: \(iterations)
        Average Duration: \(averageDuration * 1000, specifier: "%.2f")ms
        Min Duration: \(minDuration * 1000, specifier: "%.2f")ms
        Max Duration: \(maxDuration * 1000, specifier: "%.2f")ms
        Memory Delta: \(averageMemoryDelta, specifier: "%.2f")MB
        """
    }
}

public struct TestCoverageReport {
    let totalMethods: Int
    let executedMethods: Int
    let coveragePercentage: Double
    let fileExecutions: [String: Set<String>]
    let methodExecutions: [String: Int]

    public var summary: String {
        return """
        📊 Test Coverage Report
        Coverage: \(coveragePercentage, specifier: "%.1f")% (\(executedMethods)/\(totalMethods) methods)
        Files Covered: \(fileExecutions.count)
        """
    }
}

public enum MockError: Error {
    case simulatedFailure
    case networkTimeout
    case dataCorruption
    case authenticationFailure

    public var localizedDescription: String {
        switch self {
        case .simulatedFailure:
            return "Simulated test failure"
        case .networkTimeout:
            return "Network timeout during test"
        case .dataCorruption:
            return "Data corruption detected"
        case .authenticationFailure:
            return "Authentication failed during test"
        }
    }
}

// MARK: - Test Utilities

extension XCTestCase {

    /// Wait for async operation with timeout
    public func waitForAsync<T>(
        timeout: TimeInterval = 10.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw MockError.networkTimeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Assert that async operation throws specific error
    public func assertThrowsAsync<T, E: Error & Equatable>(
        _ expectedError: E,
        operation: @escaping () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected error \(expectedError) but operation succeeded", file: file, line: line)
        } catch let error as E where error == expectedError {
            // Expected error thrown
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }

    /// Assert performance within bounds
    public func assertPerformance<T>(
        maxDuration: TimeInterval,
        operation: () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertLessThanOrEqual(
            duration,
            maxDuration,
            "Operation took \(duration * 1000, specifier: "%.2f")ms, expected < \(maxDuration * 1000, specifier: "%.2f")ms",
            file: file,
            line: line
        )

        return result
    }
}

// MARK: - SwiftUI Testing Utilities

#if DEBUG
extension View {
    /// Add test identifier for UI testing
    public func testIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }

    /// Track view appearances for testing
    public func testTracked(identifier: String) -> some View {
        self.onAppear {
            LopanTestingFramework.shared.trackCoverage(for: "view_appear_\(identifier)")
        }
        .onDisappear {
            LopanTestingFramework.shared.trackCoverage(for: "view_disappear_\(identifier)")
        }
    }
}
#endif

// MARK: - Network Mocking

public class MockNetworkClient {
    public var responses: [String: Result<Data, Error>] = [:]
    public var delay: TimeInterval = 0

    public func mockResponse(for url: String, data: Data) {
        responses[url] = .success(data)
    }

    public func mockError(for url: String, error: Error) {
        responses[url] = .failure(error)
    }

    public func get(url: String) async throws -> Data {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        guard let response = responses[url] else {
            throw MockError.simulatedFailure
        }

        return try response.get()
    }
}

#Preview {
    struct TestFrameworkPreview: View {
        @State private var isRunning = false
        @State private var results = "No tests run yet"

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Lopan Testing Framework")
                        .font(.title)
                        .fontWeight(.bold)

                    ScrollView {
                        Text(results)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 400)

                    Button(action: runSampleTests) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isRunning ? "Running Tests..." : "Run Sample Tests")
                        }
                    }
                    .disabled(isRunning)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Testing Framework")
            }
        }

        private func runSampleTests() {
            isRunning = true
            results = "Starting tests...\n"

            Task {
                do {
                    // Sample test
                    let framework = LopanTestingFramework.shared
                    let testUsers = framework.generateTestData(for: User.self, count: 100)

                    results += "Generated \(testUsers.count) test users\n"

                    // Performance test
                    let performanceResult = try await framework.performanceTest(
                        name: "User Creation",
                        iterations: 5
                    ) {
                        return testUsers.count
                    }

                    results += "\n" + performanceResult.summary + "\n"

                    // Coverage report
                    let coverage = framework.getCoverageReport()
                    results += "\n" + coverage.summary

                } catch {
                    results += "\nError: \(error.localizedDescription)"
                }

                isRunning = false
            }
        }
    }

    return TestFrameworkPreview()
}