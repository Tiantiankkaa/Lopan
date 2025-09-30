//
//  CustomerOutOfStockCacheManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Phase 2: Repository Optimization - Cache manager for out-of-stock data
//

import Foundation

// MARK: - Customer Out-of-Stock Cache Manager

/// Manages caching for CustomerOutOfStock entities using three-tier strategy
@MainActor
public final class CustomerOutOfStockCacheManager {

    // MARK: - Properties

    // Note: CustomerOutOfStock contains SwiftData relationships that are not Codable
    // For now, we only cache counts and simple metadata
    // Future: Consider caching DTOs instead of domain models
    private let countCache: ThreeTierCacheStrategy<Int>

    // MARK: - Singleton

    public static let shared = CustomerOutOfStockCacheManager()

    // MARK: - Initialization

    private init() {
        self.countCache = ThreeTierCacheStrategy(cacheKeyPrefix: "out-of-stock-counts")
        print("🗄️ CustomerOutOfStockCacheManager: Initialized (count caching only)")
    }

    // MARK: - Count Caching

    /// Get cached count
    public func getCount(
        criteria: OutOfStockFilterCriteria,
        cloudFetch: (() async throws -> Int)? = nil
    ) async throws -> Int? {
        let cacheKey = countCacheKey(for: criteria)
        return try await countCache.get(key: cacheKey, cloudFetch: cloudFetch)
    }

    /// Cache count result
    public func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria) async {
        let cacheKey = countCacheKey(for: criteria)
        await countCache.set(key: cacheKey, value: count, ttl: 300) // 5-min TTL
    }

    // MARK: - Cache Management

    /// Clear all caches
    public func clearAllCaches() async {
        await countCache.clearAll()
        print("🧹 CustomerOutOfStockCacheManager: All caches cleared")
    }

    /// Evict old entries from all caches
    public func evictOldEntries() async {
        await countCache.evictOldEntriesIfNeeded()
    }

    /// Get cache statistics
    public func getStatistics() -> ThreeTierCacheStatistics {
        return countCache.getStatistics()
    }

    // MARK: - Private Cache Key Generation

    private func countCacheKey(for criteria: OutOfStockFilterCriteria) -> String {
        var components: [String] = ["count"]

        if let customer = criteria.customer {
            components.append("customer-\(customer.id)")
        }
        if let product = criteria.product {
            components.append("product-\(product.id)")
        }
        if let status = criteria.status {
            components.append("status-\(status.rawValue)")
        }
        if !criteria.searchText.isEmpty {
            components.append("search-\(criteria.searchText)")
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            components.append("from-\(formatter.string(from: dateRange.start))")
            components.append("to-\(formatter.string(from: dateRange.end))")
        }

        return components.joined(separator: ":")
    }
}