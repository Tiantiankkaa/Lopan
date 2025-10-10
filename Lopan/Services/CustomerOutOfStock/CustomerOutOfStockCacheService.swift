//
//  CustomerOutOfStockCacheService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//  Updated: 2025/10/8 - Integrated multi-layer caching with disk persistence
//

import Foundation
import os

/// Cache service for Customer Out-of-Stock operations
/// Now supports multi-layer caching (Memory → Disk → Network) with stale-while-revalidate
@MainActor
protocol CustomerOutOfStockCacheService {
    // Enhanced record caching with CachedResult
    func getCachedRecords(
        _ criteria: OutOfStockFilterCriteria,
        freshFetch: @escaping @Sendable () async throws -> [CustomerOutOfStock]
    ) async -> CachedResult<[CustomerOutOfStock]>

    func cacheRecords(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria) async

    // Legacy synchronous methods (deprecated, kept for compatibility)
    func getCachedRecordsSync(_ criteria: OutOfStockFilterCriteria) -> [CustomerOutOfStock]?
    func cacheRecordsSync(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria)

    // Count caching with CachedResult
    func getCachedCount(
        _ criteria: OutOfStockFilterCriteria,
        freshFetch: @escaping @Sendable () async throws -> Int
    ) async -> CachedResult<Int>

    func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria) async

    // Legacy synchronous count methods
    func getCachedCountSync(_ criteria: OutOfStockFilterCriteria) -> Int?
    func cacheCountSync(_ count: Int, for criteria: OutOfStockFilterCriteria)

    // Analytics caching methods
    func getCachedAnalytics<T>(for key: AnalyticsCacheKey, type: T.Type) -> T?
    func cacheAnalytics<T>(data: T, for key: AnalyticsCacheKey, ttl: TimeInterval)
    func invalidateAnalyticsCache()
    func invalidateAnalyticsCache(for key: AnalyticsCacheKey)

    func invalidateCache()
    func invalidateCache(for criteria: OutOfStockFilterCriteria)
    func getMemoryUsage() -> CacheMemoryUsage
    func handleMemoryPressure()
    func getLayerStatistics() async -> MultiLayerStatistics?
}

struct CacheMemoryUsage {
    let recordsCount: Int
    let approximateMemoryUsage: Int // in bytes
    let cacheHitRate: Double
    let lastEvictionTime: Date?
}

struct AnalyticsCacheEntry {
    let data: Any
    let createdAt: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > ttl
    }
}

@MainActor
class DefaultCustomerOutOfStockCacheService: CustomerOutOfStockCacheService {
    private let cacheManager: OutOfStockCacheManager
    private let multiLayerCache: MultiLayerCacheCoordinator
    private let logger = Logger(subsystem: "com.lopan.app", category: "CustomerOutOfStockCacheService")

    // Legacy memory cache for backward compatibility (will be gradually phased out)
    private var recordsCache: [String: [CustomerOutOfStock]] = [:]
    private var countsCache: [String: Int] = [:]
    private var accessOrder: [String] = [] // LRU tracking for records
    private var countAccessOrder: [String] = [] // LRU tracking for counts

    // Analytics cache with TTL support
    private var analyticsCache: [String: AnalyticsCacheEntry] = [:]
    private var analyticsCacheAccess: [String] = [] // LRU tracking for analytics

    // Adaptive memory management configuration
    private var maxCacheSize: Int
    private var maxMemoryBytes: Int
    private let baseMaxCacheSize = 100
    private let baseMaxMemoryBytes = 10 * 1024 * 1024 // 10MB baseline

    // Memory cache statistics
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var lastEvictionTime: Date?
    private var totalEvictions: Int = 0

    init(cacheManager: OutOfStockCacheManager, multiLayerCache: MultiLayerCacheCoordinator? = nil) {
        self.cacheManager = cacheManager

        // Initialize multi-layer cache
        if let cache = multiLayerCache {
            self.multiLayerCache = cache
        } else {
            // Create default multi-layer cache with disk persistence
            let diskCache = try! DiskCacheService(maxCacheSizeBytes: 100 * 1024 * 1024) // 100MB
            self.multiLayerCache = MultiLayerCacheCoordinator(diskCache: diskCache)
        }

        // Initialize with adaptive sizing based on device capabilities
        let deviceInfo = AdaptiveCacheSizing.getDeviceCapabilities()
        self.maxCacheSize = deviceInfo.maxCacheSize
        self.maxMemoryBytes = deviceInfo.maxMemoryBytes

        logger.safeInfo("Enhanced cache service initialized with multi-layer support", [
            "maxCacheSize": String(maxCacheSize),
            "maxMemoryMB": String(maxMemoryBytes / (1024 * 1024))
        ])
    }

    // MARK: - Enhanced Multi-Layer Cache Operations

    /// Get cached records with stale-while-revalidate pattern
    func getCachedRecords(
        _ criteria: OutOfStockFilterCriteria,
        freshFetch: @escaping @Sendable () async throws -> [CustomerOutOfStock]
    ) async -> CachedResult<[CustomerOutOfStock]> {
        let cacheKey = RequestKeyGenerator.outOfStockRecordsKey(criteria: criteria)

        let result = await multiLayerCache.get(
            key: cacheKey,
            type: [CustomerOutOfStock].self,
            freshFetch: freshFetch,
            memoryTTL: 300,  // 5 minutes
            diskTTL: 86400   // 24 hours
        )

        logger.safeInfo("getCachedRecords result", [
            "key": cacheKey,
            "isFresh": String(result.isFresh),
            "isStale": String(result.isStale),
            "hasData": String(result.hasData)
        ])

        return result
    }

    /// Cache records to all layers
    func cacheRecords(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria) async {
        let cacheKey = RequestKeyGenerator.outOfStockRecordsKey(criteria: criteria)

        await multiLayerCache.set(
            records,
            key: cacheKey,
            memoryTTL: 300,
            diskTTL: 86400
        )

        logger.safeInfo("Cached records to all layers", [
            "key": cacheKey,
            "count": String(records.count)
        ])
    }

    /// Get cached count with stale-while-revalidate pattern
    func getCachedCount(
        _ criteria: OutOfStockFilterCriteria,
        freshFetch: @escaping @Sendable () async throws -> Int
    ) async -> CachedResult<Int> {
        let cacheKey = RequestKeyGenerator.outOfStockCountKey(criteria: criteria)

        let result = await multiLayerCache.get(
            key: cacheKey,
            type: Int.self,
            freshFetch: freshFetch,
            memoryTTL: 300,
            diskTTL: 86400
        )

        logger.safeInfo("getCachedCount result", [
            "key": cacheKey,
            "isFresh": String(result.isFresh),
            "isStale": String(result.isStale),
            "hasData": String(result.hasData)
        ])

        return result
    }

    /// Cache count to all layers
    func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria) async {
        let cacheKey = RequestKeyGenerator.outOfStockCountKey(criteria: criteria)

        await multiLayerCache.set(
            count,
            key: cacheKey,
            memoryTTL: 300,
            diskTTL: 86400
        )

        logger.safeInfo("Cached count to all layers", [
            "key": cacheKey,
            "count": String(count)
        ])
    }

    /// Get multi-layer cache statistics
    func getLayerStatistics() async -> MultiLayerStatistics? {
        await multiLayerCache.getLayerStatistics()
    }

    // MARK: - Legacy Cache Operations (Deprecated - kept for backward compatibility)

    func getCachedRecordsSync(_ criteria: OutOfStockFilterCriteria) -> [CustomerOutOfStock]? {
        let cacheKey = generateCacheKey(from: criteria)
        
        if let cached = recordsCache[cacheKey] {
            cacheHits += 1
            
            // Update LRU order - move to end (most recent)
            updateAccessOrder(for: cacheKey, in: &accessOrder)
            
            logger.safeInfo("Cache hit for records", [
                "cacheKey": cacheKey,
                "recordsCount": String(cached.count)
            ])
            return cached
        } else {
            cacheMisses += 1
            logger.safeInfo("Cache miss for records", ["cacheKey": cacheKey])
            return nil
        }
    }
    
    func cacheRecordsSync(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria) {
        let cacheKey = generateCacheKey(from: criteria)

        // Check if we need to evict before adding
        enforceMemoryLimitsBeforeAdding()

        recordsCache[cacheKey] = records
        updateAccessOrder(for: cacheKey, in: &accessOrder)

        logger.safeInfo("Records cached (legacy sync)", [
            "cacheKey": cacheKey,
            "recordsCount": String(records.count),
            "totalCacheSize": String(recordsCache.count)
        ])
    }

    func getCachedCountSync(_ criteria: OutOfStockFilterCriteria) -> Int? {
        let countKey = generateCountCacheKey(from: criteria)
        
        if let count = countsCache[countKey] {
            cacheHits += 1
            
            // Update LRU order for count cache
            updateAccessOrder(for: countKey, in: &countAccessOrder)
            
            logger.safeInfo("Cache hit for count", [
                "countKey": countKey,
                "count": String(count)
            ])
            return count
        } else {
            cacheMisses += 1
            logger.safeInfo("Cache miss for count", ["countKey": countKey])
            return nil
        }
    }
    
    func cacheCountSync(_ count: Int, for criteria: OutOfStockFilterCriteria) {
        let countKey = generateCountCacheKey(from: criteria)

        // Enforce limits before adding count
        enforceCountCacheLimits()

        countsCache[countKey] = count
        updateAccessOrder(for: countKey, in: &countAccessOrder)

        logger.safeInfo("Count cached (legacy sync)", [
            "countKey": countKey,
            "count": String(count),
            "totalCountCacheSize": String(countsCache.count)
        ])
    }
    
    func invalidateCache() {
        recordsCache.removeAll()
        countsCache.removeAll()
        accessOrder.removeAll()
        countAccessOrder.removeAll()
        logger.safeInfo("All caches invalidated")
    }
    
    func invalidateCache(for criteria: OutOfStockFilterCriteria) {
        let cacheKey = generateCacheKey(from: criteria)
        let countKey = generateCountCacheKey(from: criteria)
        
        recordsCache.removeValue(forKey: cacheKey)
        countsCache.removeValue(forKey: countKey)
        
        // Remove from access orders
        accessOrder.removeAll { $0 == cacheKey }
        countAccessOrder.removeAll { $0 == countKey }
        
        logger.safeInfo("Cache invalidated for specific criteria", [
            "cacheKey": cacheKey,
            "countKey": countKey
        ])
    }
    
    // MARK: - Memory Management
    
    func getMemoryUsage() -> CacheMemoryUsage {
        let recordsCount = recordsCache.values.reduce(0) { $0 + $1.count }
        let cacheEntriesCount = recordsCache.count + countsCache.count
        let approximateMemoryUsage = (recordsCount * 1024) + (cacheEntriesCount * 256) // 1KB per record + 256B per cache entry
        let totalRequests = cacheHits + cacheMisses
        let cacheHitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0
        
        return CacheMemoryUsage(
            recordsCount: recordsCount,
            approximateMemoryUsage: approximateMemoryUsage,
            cacheHitRate: cacheHitRate,
            lastEvictionTime: lastEvictionTime
        )
    }
    
    func handleMemoryPressure() {
        logger.safeWarning("Handling memory pressure - performing aggressive cleanup")
        
        let initialUsage = getMemoryUsage()
        
        // Strategy 1: Remove least recently used items (keep only top 25%)
        let keepCount = max(1, recordsCache.count / 4)
        let keysToKeep = Array(accessOrder.suffix(keepCount))
        
        var newRecordsCache: [String: [CustomerOutOfStock]] = [:]
        for key in keysToKeep {
            if let records = recordsCache[key] {
                newRecordsCache[key] = records
            }
        }
        
        // Strategy 2: Clear count cache completely (it's cheap to rebuild)
        countsCache.removeAll()
        countAccessOrder.removeAll()
        
        recordsCache = newRecordsCache
        accessOrder = keysToKeep
        
        lastEvictionTime = Date()
        totalEvictions += 1
        
        let finalUsage = getMemoryUsage()
        logger.safeInfo("Aggressive memory cleanup completed", [
            "initialRecords": String(initialUsage.recordsCount),
            "finalRecords": String(finalUsage.recordsCount),
            "memorySaved": String(initialUsage.approximateMemoryUsage - finalUsage.approximateMemoryUsage),
            "cacheHitRate": String(format: "%.2f", finalUsage.cacheHitRate),
            "totalEvictions": String(totalEvictions)
        ])
    }
    
    // MARK: - Cache Key Generation
    
    private func generateCacheKey(from criteria: OutOfStockFilterCriteria) -> String {
        var components: [String] = []
        
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
    
    private func generateCountCacheKey(from criteria: OutOfStockFilterCriteria) -> String {
        // Count cache key excludes pagination
        var components: [String] = []
        
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
        
        return "count:" + components.joined(separator: "|")
    }
    
    // MARK: - LRU and Memory Management Helper Methods
    
    private func updateAccessOrder(for key: String, in accessOrder: inout [String]) {
        // Remove existing occurrence
        accessOrder.removeAll { $0 == key }
        // Add to end (most recent)
        accessOrder.append(key)
    }
    
    private func enforceMemoryLimitsBeforeAdding() {
        // Check memory usage
        let currentUsage = getMemoryUsage()
        
        // If we exceed memory limit, perform eviction
        if currentUsage.approximateMemoryUsage > maxMemoryBytes || recordsCache.count >= maxCacheSize {
            evictLRUEntries()
        }
    }
    
    private func enforceCountCacheLimits() {
        // Keep count cache smaller since it's cheaper to rebuild
        let maxCountCacheSize = maxCacheSize / 2
        
        while countsCache.count >= maxCountCacheSize {
            if let lruKey = countAccessOrder.first {
                countsCache.removeValue(forKey: lruKey)
                countAccessOrder.removeFirst()
            } else {
                break
            }
        }
    }
    
    private func evictLRUEntries() {
        let targetSize = max(1, maxCacheSize * 3 / 4) // Keep 75% after eviction
        
        while recordsCache.count > targetSize {
            if let lruKey = accessOrder.first {
                recordsCache.removeValue(forKey: lruKey)
                accessOrder.removeFirst()
                totalEvictions += 1
            } else {
                break
            }
        }
        
        lastEvictionTime = Date()
        
        logger.safeInfo("LRU eviction completed", [
            "remainingEntries": String(recordsCache.count),
            "totalEvictions": String(totalEvictions)
        ])
    }

    // MARK: - Analytics Caching Methods

    func getCachedAnalytics<T>(for key: AnalyticsCacheKey, type: T.Type) -> T? {
        let cacheKey = createAnalyticsCacheKey(key)

        // Remove expired entries first
        cleanupExpiredAnalyticsCache()

        guard let entry = analyticsCache[cacheKey],
              !entry.isExpired,
              let data = entry.data as? T else {
            logger.safeInfo("Analytics cache miss", ["key": cacheKey])
            return nil
        }

        // Update access order for LRU
        updateAnalyticsCacheAccess(cacheKey)

        logger.safeInfo("Analytics cache hit", ["key": cacheKey])
        return data
    }

    func cacheAnalytics<T>(data: T, for key: AnalyticsCacheKey, ttl: TimeInterval) {
        let cacheKey = createAnalyticsCacheKey(key)

        let entry = AnalyticsCacheEntry(
            data: data,
            createdAt: Date(),
            ttl: ttl
        )

        analyticsCache[cacheKey] = entry
        updateAnalyticsCacheAccess(cacheKey)

        // Ensure we don't exceed cache limits
        enforceAnalyticsCacheLimits()

        logger.safeInfo("Analytics data cached", [
            "key": cacheKey,
            "ttl": String(ttl)
        ])
    }

    func invalidateAnalyticsCache() {
        analyticsCache.removeAll()
        analyticsCacheAccess.removeAll()
        logger.safeInfo("All analytics cache invalidated")
    }

    func invalidateAnalyticsCache(for key: AnalyticsCacheKey) {
        let cacheKey = createAnalyticsCacheKey(key)
        analyticsCache.removeValue(forKey: cacheKey)
        analyticsCacheAccess.removeAll { $0 == cacheKey }
        logger.safeInfo("Analytics cache invalidated for key", ["key": cacheKey])
    }

    // MARK: - Analytics Cache Helpers

    private func createAnalyticsCacheKey(_ key: AnalyticsCacheKey) -> String {
        var components = [
            "analytics",
            key.mode.rawValue,
            key.timeRange.rawValue
        ]

        if let start = key.customStartDate {
            components.append("start:\(start.timeIntervalSince1970)")
        }
        if let end = key.customEndDate {
            components.append("end:\(end.timeIntervalSince1970)")
        }

        return components.joined(separator: "_")
    }

    private func updateAnalyticsCacheAccess(_ key: String) {
        analyticsCacheAccess.removeAll { $0 == key }
        analyticsCacheAccess.append(key)
    }

    private func cleanupExpiredAnalyticsCache() {
        let expiredKeys = analyticsCache.compactMap { key, entry in
            entry.isExpired ? key : nil
        }

        for key in expiredKeys {
            analyticsCache.removeValue(forKey: key)
            analyticsCacheAccess.removeAll { $0 == key }
        }

        if !expiredKeys.isEmpty {
            logger.safeInfo("Cleaned up expired analytics cache entries", [
                "expiredCount": String(expiredKeys.count)
            ])
        }
    }

    private func enforceAnalyticsCacheLimits() {
        let maxAnalyticsEntries = maxCacheSize / 4 // Reserve 1/4 of cache for analytics

        while analyticsCache.count > maxAnalyticsEntries && !analyticsCacheAccess.isEmpty {
            // Remove least recently used entry
            let oldestKey = analyticsCacheAccess.removeFirst()
            analyticsCache.removeValue(forKey: oldestKey)
        }
    }
}

// MARK: - Adaptive Cache Sizing

struct AdaptiveCacheSizing {
    struct DeviceCapabilities {
        let maxCacheSize: Int
        let maxMemoryBytes: Int
        let deviceTier: DeviceTier
    }

    enum DeviceTier {
        case highEnd    // Pro models, latest devices
        case midRange   // Standard devices
        case lowEnd     // Older or entry-level devices
    }

    static func getDeviceCapabilities() -> DeviceCapabilities {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)

        let tier = classifyDevice(memoryGB: memoryGB)

        switch tier {
        case .highEnd:
            return DeviceCapabilities(
                maxCacheSize: 200,
                maxMemoryBytes: 25 * 1024 * 1024, // 25MB
                deviceTier: tier
            )
        case .midRange:
            return DeviceCapabilities(
                maxCacheSize: 100,
                maxMemoryBytes: 15 * 1024 * 1024, // 15MB
                deviceTier: tier
            )
        case .lowEnd:
            return DeviceCapabilities(
                maxCacheSize: 50,
                maxMemoryBytes: 8 * 1024 * 1024, // 8MB
                deviceTier: tier
            )
        }
    }

    private static func classifyDevice(memoryGB: Double) -> DeviceTier {
        // Classify based on available memory
        // iOS devices typically have:
        // High-end: 8GB+ (Pro models, latest)
        // Mid-range: 4-6GB (Standard recent models)
        // Low-end: <4GB (Older devices)

        if memoryGB >= 8.0 {
            return .highEnd
        } else if memoryGB >= 4.0 {
            return .midRange
        } else {
            return .lowEnd
        }
    }
}