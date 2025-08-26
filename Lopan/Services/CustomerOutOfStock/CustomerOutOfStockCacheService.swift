//
//  CustomerOutOfStockCacheService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation
import os

/// Cache service for Customer Out-of-Stock operations
/// Handles memory caching, disk caching, and cache invalidation
@MainActor
protocol CustomerOutOfStockCacheService {
    func getCachedRecords(_ criteria: OutOfStockFilterCriteria) -> [CustomerOutOfStock]?
    func cacheRecords(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria)
    func getCachedCount(_ criteria: OutOfStockFilterCriteria) -> Int?
    func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria)
    func invalidateCache()
    func invalidateCache(for criteria: OutOfStockFilterCriteria)
    func getMemoryUsage() -> CacheMemoryUsage
    func handleMemoryPressure()
}

struct CacheMemoryUsage {
    let recordsCount: Int
    let approximateMemoryUsage: Int // in bytes
    let cacheHitRate: Double
    let lastEvictionTime: Date?
}

@MainActor
class DefaultCustomerOutOfStockCacheService: CustomerOutOfStockCacheService {
    private let cacheManager: OutOfStockCacheManager
    private let logger = Logger(subsystem: "com.lopan.app", category: "CustomerOutOfStockCacheService")
    
    // Enhanced memory cache with LRU tracking
    private var recordsCache: [String: [CustomerOutOfStock]] = [:]
    private var countsCache: [String: Int] = [:]
    private var accessOrder: [String] = [] // LRU tracking for records
    private var countAccessOrder: [String] = [] // LRU tracking for counts
    
    // Memory management configuration
    private let maxCacheSize = 100 // Maximum number of cached entries
    private let maxMemoryBytes = 10 * 1024 * 1024 // 10MB limit
    
    // Memory cache statistics
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var lastEvictionTime: Date?
    private var totalEvictions: Int = 0
    
    init(cacheManager: OutOfStockCacheManager) {
        self.cacheManager = cacheManager
    }
    
    // MARK: - Cache Operations
    
    func getCachedRecords(_ criteria: OutOfStockFilterCriteria) -> [CustomerOutOfStock]? {
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
    
    func cacheRecords(_ records: [CustomerOutOfStock], for criteria: OutOfStockFilterCriteria) {
        let cacheKey = generateCacheKey(from: criteria)
        
        // Check if we need to evict before adding
        enforceMemoryLimitsBeforeAdding()
        
        recordsCache[cacheKey] = records
        updateAccessOrder(for: cacheKey, in: &accessOrder)
        
        logger.safeInfo("Records cached", [
            "cacheKey": cacheKey,
            "recordsCount": String(records.count),
            "totalCacheSize": String(recordsCache.count)
        ])
    }
    
    func getCachedCount(_ criteria: OutOfStockFilterCriteria) -> Int? {
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
    
    func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria) {
        let countKey = generateCountCacheKey(from: criteria)
        
        // Enforce limits before adding count
        enforceCountCacheLimits()
        
        countsCache[countKey] = count
        updateAccessOrder(for: countKey, in: &countAccessOrder)
        
        logger.safeInfo("Count cached", [
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
}