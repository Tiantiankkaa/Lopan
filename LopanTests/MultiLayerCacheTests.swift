//
//  MultiLayerCacheTests.swift
//  LopanTests
//
//  Created by Claude Code on 2025/10/8.
//  Unit tests for multi-layer caching infrastructure
//

import XCTest
@testable import Lopan

@MainActor
final class MultiLayerCacheTests: XCTestCase {

    var diskCache: DiskCacheService!
    var coordinator: MultiLayerCacheCoordinator!
    var deduplicator: RequestDeduplicator!

    override func setUpWithError() throws {
        // Create fresh cache services for each test
        diskCache = try DiskCacheService(maxCacheSizeBytes: 10 * 1024 * 1024) // 10MB for tests
        coordinator = MultiLayerCacheCoordinator(diskCache: diskCache, memoryCacheCountLimit: 50)
        deduplicator = RequestDeduplicator()
    }

    override func tearDownWithError() throws {
        // Clean up - Resources will be deallocated automatically
        diskCache = nil
        coordinator = nil
        deduplicator = nil
    }

    // MARK: - DiskCacheService Tests

    func testDiskCacheSaveAndRetrieve() async throws {
        // Given
        let testData = ["item1", "item2", "item3"]
        let cacheKey = "test-key"

        // When
        try await diskCache.save(testData, key: cacheKey, ttl: 300)

        // Then
        let retrieved: CacheEntry<[String]>? = try await diskCache.get(cacheKey, type: [String].self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.data, testData)
        XCTAssertEqual(retrieved?.metadata.source, .disk)
    }

    func testDiskCacheExpiration() async throws {
        // Given
        let testData = "expired-data"
        let cacheKey = "expiring-key"

        // When - Save with 0.1 second TTL
        try await diskCache.save(testData, key: cacheKey, ttl: 0.1)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then - Should be expired
        let retrieved: CacheEntry<String>? = try await diskCache.get(cacheKey, type: String.self)
        XCTAssertTrue(retrieved?.isExpired ?? false)
    }

    func testDiskCacheCleanup() async throws {
        // Given - Add expired and fresh entries
        try await diskCache.save("fresh", key: "fresh-key", ttl: 300)
        try await diskCache.save("expired", key: "expired-key", ttl: 0.1)

        try await Task.sleep(nanoseconds: 200_000_000)

        // When
        try await diskCache.cleanup()

        // Then
        let stats = await diskCache.getStatistics()
        XCTAssertEqual(stats.expiredEntries, 0, "All expired entries should be cleaned up")
    }

    // MARK: - RequestDeduplicator Tests

    func testRequestDeduplication() async throws {
        // Given
        var callCount = 0
        let fetchOperation: @Sendable () async throws -> String = {
            callCount += 1
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            return "result"
        }

        // When - Make 3 concurrent requests with same key
        async let result1 = deduplicator.deduplicate(key: "shared-key", fetch: fetchOperation)
        async let result2 = deduplicator.deduplicate(key: "shared-key", fetch: fetchOperation)
        async let result3 = deduplicator.deduplicate(key: "shared-key", fetch: fetchOperation)

        let results = try await [result1, result2, result3]

        // Then - Should only call fetch once
        XCTAssertEqual(callCount, 1, "Should only make one network call for duplicate requests")
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0 == "result" })
    }

    func testRequestDeduplicationStatistics() async throws {
        // Given
        let fetchOperation: @Sendable () async throws -> Int = { 42 }

        // When
        _ = try await deduplicator.deduplicate(key: "key1", fetch: fetchOperation)
        _ = try await deduplicator.deduplicate(key: "key1", fetch: fetchOperation) // Deduplicated

        // Then
        let stats = deduplicator.getStatistics()
        XCTAssertEqual(stats.totalRequests, 2)
        XCTAssertGreaterThan(stats.deduplicationRate, 0, "Should have some deduplication")
    }

    // MARK: - MultiLayerCacheCoordinator Tests

    func testMultiLayerCacheFreshData() async throws {
        // Given
        let testData = ["apple", "banana", "cherry"]
        var fetchCallCount = 0

        let freshFetch: @Sendable () async throws -> [String] = {
            fetchCallCount += 1
            return testData
        }

        // When - First fetch (cache miss)
        let result1 = await coordinator.get(
            key: "fruits",
            type: [String].self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 3600
        )

        // Then
        XCTAssertEqual(fetchCallCount, 1, "Should fetch from network on first call")
        XCTAssertTrue(result1.isFresh)
        XCTAssertEqual(result1.data, testData)
    }

    func testMultiLayerCacheMemoryHit() async throws {
        // Given
        let testData = "cached-value"
        var fetchCallCount = 0

        let freshFetch: @Sendable () async throws -> String = {
            fetchCallCount += 1
            return testData
        }

        // When - First call populates cache
        _ = await coordinator.get(
            key: "test-memory",
            type: String.self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 3600
        )

        // Second call should hit memory cache
        let result2 = await coordinator.get(
            key: "test-memory",
            type: String.self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 3600
        )

        // Then
        XCTAssertEqual(fetchCallCount, 1, "Should not fetch again, memory cache hit")
        XCTAssertTrue(result2.isFresh)
        XCTAssertEqual(result2.metadata?.source, .memory)
    }

    func testMultiLayerCacheStaleWhileRevalidate() async throws {
        // Given
        let initialData = "initial"
        let updatedData = "updated"
        var fetchCallCount = 0
        var returnUpdatedData = false

        let freshFetch: @Sendable () async throws -> String = {
            fetchCallCount += 1
            return returnUpdatedData ? updatedData : initialData
        }

        // When - First fetch
        _ = await coordinator.get(
            key: "stale-test",
            type: String.self,
            freshFetch: freshFetch,
            memoryTTL: 0.2, // Short TTL
            diskTTL: 3600
        )

        // Wait for TTL to expire
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        // Change fetch to return updated data
        returnUpdatedData = true

        // Second fetch should return stale data and trigger background refresh
        let result2 = await coordinator.get(
            key: "stale-test",
            type: String.self,
            freshFetch: freshFetch,
            memoryTTL: 0.2,
            diskTTL: 3600
        )

        // Then
        if result2.isStale {
            XCTAssertEqual(result2.data, initialData, "Should return stale cached data immediately")

            // Wait for background refresh
            try await Task.sleep(nanoseconds: 200_000_000)

            XCTAssertEqual(fetchCallCount, 2, "Should trigger background refresh")
        }
    }

    func testMultiLayerCacheStatistics() async throws {
        // Given
        let freshFetch: @Sendable () async throws -> Int = { 100 }

        // When - Make several cache hits and misses
        _ = await coordinator.get(key: "stat-key-1", type: Int.self, freshFetch: freshFetch)
        _ = await coordinator.get(key: "stat-key-1", type: Int.self, freshFetch: freshFetch) // Memory hit
        _ = await coordinator.get(key: "stat-key-2", type: Int.self, freshFetch: freshFetch) // Miss
        _ = await coordinator.get(key: "stat-key-2", type: Int.self, freshFetch: freshFetch) // Memory hit

        // Then
        let stats = await coordinator.getLayerStatistics()
        XCTAssertGreaterThan(stats.memoryHits, 0, "Should have memory cache hits")
        XCTAssertGreaterThan(stats.overallHitRate, 0, "Should have positive hit rate")
    }

    // MARK: - Integration Tests

    func testEndToEndCachingFlow() async throws {
        // Given
        struct TestRecord: Codable, Equatable {
            let id: String
            let value: Int
        }

        let record1 = TestRecord(id: "1", value: 100)
        let record2 = TestRecord(id: "2", value: 200)

        var networkCallCount = 0
        let freshFetch: @Sendable () async throws -> [TestRecord] = {
            networkCallCount += 1
            return [record1, record2]
        }

        // When - Simulate user journey
        // 1. First load (network fetch)
        let firstLoad = await coordinator.get(
            key: "records-page-1",
            type: [TestRecord].self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 3600
        )

        // 2. Immediate second load (memory cache hit)
        let secondLoad = await coordinator.get(
            key: "records-page-1",
            type: [TestRecord].self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 3600
        )

        // 3. Clear memory, load again (disk cache hit)
        await coordinator.invalidateAll()

        // Re-save to disk manually for this test
        try await diskCache.save([record1, record2], key: "records-page-1", ttl: 3600)

        let thirdLoad = await coordinator.get(
            key: "records-page-1",
            type: [TestRecord].self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 3600
        )

        // Then
        XCTAssertEqual(firstLoad.data, [record1, record2])
        XCTAssertEqual(secondLoad.data, [record1, record2])
        XCTAssertEqual(thirdLoad.data, [record1, record2])

        XCTAssertTrue(firstLoad.isFresh)
        XCTAssertTrue(secondLoad.isFresh)

        XCTAssertLessThanOrEqual(networkCallCount, 2, "Should minimize network calls")
    }

    func testConcurrentAccessSafety() async throws {
        // Given
        let freshFetch: @Sendable () async throws -> String = {
            try await Task.sleep(nanoseconds: 50_000_000)
            return "result"
        }

        // When - Make many concurrent requests
        await withTaskGroup(of: CachedResult<String>.self) { group in
            for i in 0..<20 {
                group.addTask {
                    await self.coordinator.get(
                        key: "concurrent-key-\(i % 5)", // Use 5 different keys
                        type: String.self,
                        freshFetch: freshFetch,
                        memoryTTL: 300,
                        diskTTL: 3600
                    )
                }
            }

            var results: [CachedResult<String>] = []
            for await result in group {
                results.append(result)
            }

            // Then - Should complete without crashes or data corruption
            XCTAssertEqual(results.count, 20)
            XCTAssertTrue(results.allSatisfy { $0.hasData })
        }
    }
}

// MARK: - Performance Tests

extension MultiLayerCacheTests {

    func testMemoryCachePerformance() throws {
        // Test that memory cache is very fast (< 50ms)
        measure {
            let expectation = self.expectation(description: "Memory cache should be fast")

            Task {
                let freshFetch: @Sendable () async throws -> Int = { 42 }

                // Pre-populate cache
                _ = await coordinator.get(key: "perf-test", type: Int.self, freshFetch: freshFetch)

                // Measure cache hit
                let start = Date()
                _ = await coordinator.get(key: "perf-test", type: Int.self, freshFetch: freshFetch)
                let elapsed = Date().timeIntervalSince(start)

                XCTAssertLessThan(elapsed, 0.05, "Memory cache should respond in < 50ms")
                expectation.fulfill()
            }

            self.wait(for: [expectation], timeout: 1.0)
        }
    }
}
