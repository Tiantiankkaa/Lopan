//
//  SmartCacheManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//  Smart cache management with predictive preloading and intelligent eviction
//

import Foundation
import os

/// Smart cache management for Customer Out-of-Stock data with predictive capabilities
@MainActor
class SmartCacheManager {
    private let logger = Logger(subsystem: "com.lopan.app", category: "SmartCacheManager")
    
    // MARK: - Cache Strategy Configuration
    
    private struct CacheStrategy {
        static let hotDataTTL: TimeInterval = 300 // 5 minutes
        static let warmDataTTL: TimeInterval = 900 // 15 minutes  
        static let coldDataTTL: TimeInterval = 3600 // 1 hour
        static let predictiveRadius = 2 // Pages to preload around current
        static let maxPredictiveEntries = 10
    }
    
    // MARK: - Cache Tiers
    
    // Hot cache - frequently accessed data
    private var hotCache: [String: CachedData] = [:]
    private var hotAccessOrder: [String] = []
    
    // Warm cache - recently accessed data
    private var warmCache: [String: CachedData] = [:]
    private var warmAccessOrder: [String] = []
    
    // Predictive cache - anticipated data
    private var predictiveCache: [String: CachedData] = [:]
    
    // Access pattern tracking
    private var accessPatterns: [String: AccessPattern] = [:]
    private var sequentialAccessTracking: [String: [Date]] = [:]
    
    // MARK: - Cache Data Structure
    
    private struct CachedData {
        let records: [CustomerOutOfStock]
        let timestamp: Date
        let accessCount: Int
        let cacheScore: Double
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
        
        var isExpired: Bool {
            age > CacheStrategy.hotDataTTL
        }
        
        func updated(accessCount: Int) -> CachedData {
            let cacheScore = calculateCacheScore(accessCount: accessCount, age: age)
            return CachedData(
                records: records,
                timestamp: timestamp,
                accessCount: accessCount,
                cacheScore: cacheScore
            )
        }
        
        private func calculateCacheScore(accessCount: Int, age: TimeInterval) -> Double {
            let frequencyScore = Double(accessCount) * 0.7
            let recencyScore = max(0, 1.0 - age / 3600) * 0.3 // Decay over 1 hour
            return frequencyScore + recencyScore
        }
    }
    
    private struct AccessPattern {
        var frequency: Double = 1.0
        var lastAccess: Date = Date()
        var timePattern: [TimeInterval] = []
        var isSequential: Bool = false
        
        mutating func recordAccess() {
            let now = Date()
            let timeSinceLastAccess = now.timeIntervalSince(lastAccess)
            
            timePattern.append(timeSinceLastAccess)
            if timePattern.count > 10 {
                timePattern.removeFirst()
            }
            
            frequency = calculateFrequency()
            lastAccess = now
        }
        
        private func calculateFrequency() -> Double {
            guard timePattern.count > 1 else { return 1.0 }
            let averageInterval = timePattern.reduce(0, +) / Double(timePattern.count)
            return max(0.1, 1.0 / (averageInterval + 1.0))
        }
    }
    
    // MARK: - Smart Cache Operations
    
    func getCachedData(for key: String) -> [CustomerOutOfStock]? {
        // Record access pattern
        recordAccess(for: key)
        
        // Check hot cache first
        if let hotData = hotCache[key], !hotData.isExpired {
            updateAccessOrder(key: key, in: &hotAccessOrder)
            hotCache[key] = hotData.updated(accessCount: hotData.accessCount + 1)
            
            // Trigger predictive preloading
            triggerPredictivePreloading(for: key)
            
            logger.safeInfo("Hot cache hit", ["key": key, "accessCount": String(hotData.accessCount + 1)])
            return hotData.records
        }
        
        // Check warm cache
        if let warmData = warmCache[key], warmData.age < CacheStrategy.warmDataTTL {
            // Promote to hot cache
            promoteToHotCache(key: key, data: warmData)
            logger.safeInfo("Warm cache hit - promoted to hot", ["key": key])
            return warmData.records
        }
        
        // Check predictive cache
        if let predictiveData = predictiveCache[key], predictiveData.age < CacheStrategy.coldDataTTL {
            // Promote to hot cache
            promoteToHotCache(key: key, data: predictiveData)
            predictiveCache.removeValue(forKey: key)
            logger.safeInfo("Predictive cache hit - promoted to hot", ["key": key])
            return predictiveData.records
        }
        
        logger.safeInfo("Cache miss", ["key": key])
        return nil
    }
    
    func cacheData(_ records: [CustomerOutOfStock], for key: String) {
        let cacheData = CachedData(
            records: records,
            timestamp: Date(),
            accessCount: 1,
            cacheScore: 0.7 // Initial cache score for new items
        )
        
        // Ensure cache limits before adding
        enforceHotCacheLimit()
        
        hotCache[key] = cacheData
        updateAccessOrder(key: key, in: &hotAccessOrder)
        
        // Update access patterns
        recordAccess(for: key)
        
        logger.safeInfo("Data cached to hot cache", [
            "key": key,
            "recordCount": String(records.count),
            "hotCacheSize": String(hotCache.count)
        ])
    }
    
    // MARK: - Predictive Preloading
    
    private func triggerPredictivePreloading(for key: String) {
        guard let pattern = accessPatterns[key], pattern.frequency > 0.5 else { return }
        
        // Generate predictive cache keys based on patterns
        let predictiveKeys = generatePredictiveKeys(from: key)
        
        Task.detached(priority: .background) { [weak self] in
            await self?.performPredictivePreloading(keys: predictiveKeys)
        }
    }
    
    private func generatePredictiveKeys(from currentKey: String) -> [String] {
        // Simple strategy: predict adjacent pages
        var predictiveKeys: [String] = []
        
        // Extract page number if possible
        if let pageMatch = currentKey.range(of: "_p(\\d+)_", options: .regularExpression) {
            let pageString = String(currentKey[pageMatch])
            if let pageNum = Int(pageString.replacingOccurrences(of: "_p", with: "").replacingOccurrences(of: "_", with: "")) {
                for offset in -CacheStrategy.predictiveRadius...CacheStrategy.predictiveRadius {
                    guard offset != 0 else { continue }
                    let newPage = max(0, pageNum + offset)
                    let newKey = currentKey.replacingOccurrences(of: "_p\\(pageNum)_", with: "_p\\(newPage)_", options: .regularExpression)
                    predictiveKeys.append(newKey)
                }
            }
        }
        
        return Array(predictiveKeys.prefix(CacheStrategy.maxPredictiveEntries))
    }
    
    private func performPredictivePreloading(keys: [String]) async {
        // This would integrate with the data service to preload data
        // For now, just log the intention
        await MainActor.run {
            logger.safeInfo("Predictive preloading triggered", [
                "keyCount": String(keys.count),
                "keys": keys.prefix(3).joined(separator: ", ")
            ])
        }
    }
    
    // MARK: - Cache Management
    
    private func promoteToHotCache(key: String, data: CachedData) {
        // Remove from warm cache if present
        warmCache.removeValue(forKey: key)
        warmAccessOrder.removeAll { $0 == key }
        
        // Ensure hot cache limit
        enforceHotCacheLimit()
        
        // Add to hot cache with updated access count
        hotCache[key] = data.updated(accessCount: data.accessCount + 1)
        updateAccessOrder(key: key, in: &hotAccessOrder)
    }
    
    private func demoteToWarmCache() {
        guard let lruKey = hotAccessOrder.first,
              let lruData = hotCache[lruKey] else { return }
        
        // Move to warm cache
        warmCache[lruKey] = lruData
        updateAccessOrder(key: lruKey, in: &warmAccessOrder)
        
        // Remove from hot cache
        hotCache.removeValue(forKey: lruKey)
        hotAccessOrder.removeFirst()
        
        // Enforce warm cache limit
        enforceWarmCacheLimit()
    }
    
    private func enforceHotCacheLimit() {
        let maxHotCacheSize = 20
        while hotCache.count >= maxHotCacheSize {
            demoteToWarmCache()
        }
    }
    
    private func enforceWarmCacheLimit() {
        let maxWarmCacheSize = 50
        while warmCache.count >= maxWarmCacheSize {
            // Remove least valuable item from warm cache
            if let lruKey = warmAccessOrder.first {
                warmCache.removeValue(forKey: lruKey)
                warmAccessOrder.removeFirst()
            }
        }
    }
    
    // MARK: - Access Pattern Tracking
    
    private func recordAccess(for key: String) {
        if accessPatterns[key] == nil {
            accessPatterns[key] = AccessPattern()
        }
        accessPatterns[key]?.recordAccess()
        
        // Track sequential access patterns
        let now = Date()
        if sequentialAccessTracking[key] == nil {
            sequentialAccessTracking[key] = []
        }
        sequentialAccessTracking[key]?.append(now)
        
        // Keep only recent accesses (last 10)
        if let count = sequentialAccessTracking[key]?.count, count > 10 {
            sequentialAccessTracking[key]?.removeFirst()
        }
    }
    
    // MARK: - Utility Methods
    
    private func updateAccessOrder(key: String, in accessOrder: inout [String]) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() -> SmartCacheStatistics {
        let totalEntries = hotCache.count + warmCache.count + predictiveCache.count
        let hotCacheSize = hotCache.values.reduce(0) { $0 + $1.records.count }
        let warmCacheSize = warmCache.values.reduce(0) { $0 + $1.records.count }
        let predictiveCacheSize = predictiveCache.values.reduce(0) { $0 + $1.records.count }
        
        return SmartCacheStatistics(
            totalEntries: totalEntries,
            hotCacheEntries: hotCache.count,
            warmCacheEntries: warmCache.count,
            predictiveCacheEntries: predictiveCache.count,
            totalRecords: hotCacheSize + warmCacheSize + predictiveCacheSize,
            averageAccessCount: calculateAverageAccessCount(),
            topAccessPatterns: getTopAccessPatterns()
        )
    }
    
    private func calculateAverageAccessCount() -> Double {
        let allAccessCounts = hotCache.values.map { Double($0.accessCount) } + 
                            warmCache.values.map { Double($0.accessCount) }
        guard !allAccessCounts.isEmpty else { return 0.0 }
        return allAccessCounts.reduce(0, +) / Double(allAccessCounts.count)
    }
    
    private func getTopAccessPatterns() -> [String] {
        return accessPatterns
            .sorted { $0.value.frequency > $1.value.frequency }
            .prefix(5)
            .map { $0.key }
    }
    
    // MARK: - Memory Pressure Handling
    
    func handleMemoryPressure() {
        logger.safeWarning("Smart cache handling memory pressure")
        
        let initialCount = hotCache.count + warmCache.count + predictiveCache.count
        
        // Clear predictive cache completely
        predictiveCache.removeAll()
        
        // Aggressively trim warm cache
        let warmKeepCount = max(1, warmCache.count / 4)
        let warmKeysToKeep = Array(warmAccessOrder.suffix(warmKeepCount))
        
        var newWarmCache: [String: CachedData] = [:]
        for key in warmKeysToKeep {
            if let data = warmCache[key] {
                newWarmCache[key] = data
            }
        }
        warmCache = newWarmCache
        warmAccessOrder = warmKeysToKeep
        
        // Trim hot cache to essentials
        let hotKeepCount = max(1, hotCache.count / 2)
        let hotKeysToKeep = Array(hotAccessOrder.suffix(hotKeepCount))
        
        var newHotCache: [String: CachedData] = [:]
        for key in hotKeysToKeep {
            if let data = hotCache[key] {
                newHotCache[key] = data
            }
        }
        hotCache = newHotCache
        hotAccessOrder = hotKeysToKeep
        
        let finalCount = hotCache.count + warmCache.count + predictiveCache.count
        
        logger.safeInfo("Memory pressure handled", [
            "initialEntries": String(initialCount),
            "finalEntries": String(finalCount),
            "entriesFreed": String(initialCount - finalCount)
        ])
    }
}

// MARK: - Supporting Types

struct SmartCacheStatistics {
    let totalEntries: Int
    let hotCacheEntries: Int
    let warmCacheEntries: Int
    let predictiveCacheEntries: Int
    let totalRecords: Int
    let averageAccessCount: Double
    let topAccessPatterns: [String]
}