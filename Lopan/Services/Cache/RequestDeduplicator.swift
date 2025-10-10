//
//  RequestDeduplicator.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Prevents duplicate concurrent network requests with shared results
//

import Foundation
import os

// MARK: - Request Deduplicator Protocol

/// Deduplicates concurrent requests to prevent redundant network calls
@MainActor
protocol RequestDeduplicatorProtocol {
    func deduplicate<T>(
        key: String,
        fetch: @escaping @Sendable () async throws -> T
    ) async throws -> T

    func invalidate(key: String)
    func invalidateAll()
    func getStatistics() -> DeduplicationStatistics
}

// MARK: - Deduplication Statistics

public struct DeduplicationStatistics {
    let totalRequests: Int
    let deduplicatedRequests: Int
    let activeTasks: Int
    let averageWaitTime: TimeInterval

    var deduplicationRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(deduplicatedRequests) / Double(totalRequests)
    }
}

// MARK: - Request Deduplicator Implementation

@MainActor
final class RequestDeduplicator: RequestDeduplicatorProtocol {

    // MARK: - Properties

    private var inflightTasks: [String: Task<Any, Error>] = [:]
    private var requestCounts: [String: Int] = [:]
    private var waitTimes: [String: TimeInterval] = [:]
    private let logger = Logger(subsystem: "com.lopan.app", category: "RequestDeduplicator")

    // Performance metrics
    private var totalRequests: Int = 0
    private var deduplicatedCount: Int = 0

    // MARK: - Initialization

    init() {
        logger.info("🔄 RequestDeduplicator initialized")
    }

    // MARK: - Deduplication

    func deduplicate<T>(
        key: String,
        fetch: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        totalRequests += 1

        // Check if there's already an in-flight request for this key
        if let existingTask = inflightTasks[key] {
            deduplicatedCount += 1
            requestCounts[key, default: 0] += 1

            logger.info("🔄 Deduplicating request: \(key) (shared with \(self.requestCounts[key, default: 0]) others)")

            let startWait = Date()

            // Wait for the existing task to complete
            do {
                let result = try await existingTask.value as! T

                let waitTime = Date().timeIntervalSince(startWait)
                waitTimes[key] = waitTime

                logger.info("🔄 Deduplicated request completed: \(key) (waited \(String(format: "%.2f", waitTime))s)")

                return result
            } catch {
                // If the shared task fails, all waiters get the same error
                logger.error("🔄 Deduplicated request failed: \(key) - \(error.localizedDescription)")
                throw error
            }
        }

        // No existing task - create a new one
        logger.info("🔄 Starting new request: \(key)")

        let task = Task<Any, Error> {
            defer {
                // Remove from in-flight when done
                Task { @MainActor in
                    inflightTasks.removeValue(forKey: key)
                    requestCounts.removeValue(forKey: key)
                }
            }

            do {
                let result = try await fetch()
                logger.info("✅ Request completed: \(key)")
                return result as Any
            } catch {
                logger.error("❌ Request failed: \(key) - \(error.localizedDescription)")
                throw error
            }
        }

        inflightTasks[key] = task

        // Wait for our newly created task
        let result = try await task.value as! T
        return result
    }

    // MARK: - Cache Invalidation

    func invalidate(key: String) {
        // Cancel the in-flight task if it exists
        if let task = inflightTasks[key] {
            task.cancel()
            inflightTasks.removeValue(forKey: key)
            requestCounts.removeValue(forKey: key)
            waitTimes.removeValue(forKey: key)
            logger.info("🗑️ Invalidated request: \(key)")
        }
    }

    func invalidateAll() {
        // Cancel all in-flight tasks
        for (_, task) in inflightTasks {
            task.cancel()
        }

        inflightTasks.removeAll()
        requestCounts.removeAll()
        waitTimes.removeAll()

        logger.info("🗑️ Invalidated all requests")
    }

    // MARK: - Statistics

    func getStatistics() -> DeduplicationStatistics {
        let avgWaitTime = waitTimes.values.isEmpty ? 0 : waitTimes.values.reduce(0, +) / Double(waitTimes.count)

        return DeduplicationStatistics(
            totalRequests: totalRequests,
            deduplicatedRequests: deduplicatedCount,
            activeTasks: inflightTasks.count,
            averageWaitTime: avgWaitTime
        )
    }

    // MARK: - Debugging

    func getSummary() -> String {
        let stats = getStatistics()
        return """
        Request Deduplication Summary:
        - Total Requests: \(stats.totalRequests)
        - Deduplicated: \(stats.deduplicatedRequests) (\(String(format: "%.1f%%", stats.deduplicationRate * 100)))
        - Active Tasks: \(stats.activeTasks)
        - Avg Wait Time: \(String(format: "%.2f", stats.averageWaitTime))s
        """
    }
}

// MARK: - Request Key Generator

/// Helper to generate consistent cache keys for deduplication
struct RequestKeyGenerator {

    /// Generate a cache key for out-of-stock records fetch
    static func outOfStockRecordsKey(criteria: OutOfStockFilterCriteria) -> String {
        var components: [String] = ["oos-records"]

        if let customer = criteria.customer {
            components.append("c:\(customer.id)")
        }

        if let product = criteria.product {
            components.append("p:\(product.id)")
        }

        if let status = criteria.status {
            components.append("s:\(status.rawValue)")
        }

        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            components.append("dr:\(formatter.string(from: dateRange.start))-\(formatter.string(from: dateRange.end))")
        }

        if !criteria.searchText.isEmpty {
            components.append("st:\(criteria.searchText)")
        }

        components.append("pg:\(criteria.page)")
        components.append("ps:\(criteria.pageSize)")
        components.append("so:\(criteria.sortOrder.rawValue)")

        return components.joined(separator: "|")
    }

    /// Generate a cache key for count queries
    static func outOfStockCountKey(criteria: OutOfStockFilterCriteria) -> String {
        var components: [String] = ["oos-count"]

        if let customer = criteria.customer {
            components.append("c:\(customer.id)")
        }

        if let product = criteria.product {
            components.append("p:\(product.id)")
        }

        if let status = criteria.status {
            components.append("s:\(status.rawValue)")
        }

        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            components.append("dr:\(formatter.string(from: dateRange.start))-\(formatter.string(from: dateRange.end))")
        }

        if !criteria.searchText.isEmpty {
            components.append("st:\(criteria.searchText)")
        }

        return components.joined(separator: "|")
    }

    /// Generate a cache key for customer data
    static func customerKey(_ customerId: String) -> String {
        "customer:\(customerId)"
    }

    /// Generate a cache key for product data
    static func productKey(_ productId: String) -> String {
        "product:\(productId)"
    }

    /// Generate a cache key for analytics queries
    static func analyticsKey(mode: String, timeRange: String) -> String {
        "analytics:\(mode):\(timeRange)"
    }
}
