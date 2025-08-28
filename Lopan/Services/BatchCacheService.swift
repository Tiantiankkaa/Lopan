//
//  BatchCacheService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation
import SwiftUI

// MARK: - Batch Cache Service (批次缓存服务)
@MainActor
public class BatchCacheService: ObservableObject {
    
    // MARK: - Cache Storage (缓存存储)
    
    private var batchCache: [String: CachedBatch] = [:]
    private var machineStatusCache: [String: CachedMachineStatus] = [:]
    private var conflictCheckCache: [String: CachedConflictCheck] = [:]
    private var validationCache: [String: CachedValidation] = [:]
    
    // MARK: - Cache Configuration (缓存配置)
    
    private let batchCacheTTL: TimeInterval = 300 // 5 minutes
    private let machineStatusCacheTTL: TimeInterval = 30 // 30 seconds
    private let conflictCheckCacheTTL: TimeInterval = 60 // 1 minute
    private let validationCacheTTL: TimeInterval = 120 // 2 minutes
    
    private let maxCacheSize = 1000
    private let cleanupInterval: TimeInterval = 600 // 10 minutes
    
    private var cleanupTimer: Timer?
    
    init() {
        startCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Batch Caching (批次缓存)
    
    func getCachedBatches(for key: BatchCacheKey) -> [ProductionBatch]? {
        let cacheKey = key.stringValue
        
        guard let cached = batchCache[cacheKey],
              !cached.isExpired(ttl: batchCacheTTL) else {
            batchCache.removeValue(forKey: cacheKey)
            return nil
        }
        
        cached.lastAccessed = Date()
        return cached.batches
    }
    
    func cacheBatches(_ batches: [ProductionBatch], for key: BatchCacheKey) {
        let cacheKey = key.stringValue
        let cached = CachedBatch(batches: batches)
        
        batchCache[cacheKey] = cached
        maintainCacheSize()
    }
    
    func invalidateBatchCache(for key: BatchCacheKey? = nil) {
        if let key = key {
            batchCache.removeValue(forKey: key.stringValue)
        } else {
            batchCache.removeAll()
        }
    }
    
    // MARK: - Machine Status Caching (机器状态缓存)
    
    func getCachedMachineStatus(for machineId: String) -> Bool? {
        guard let cached = machineStatusCache[machineId],
              !cached.isExpired(ttl: machineStatusCacheTTL) else {
            machineStatusCache.removeValue(forKey: machineId)
            return nil
        }
        
        cached.lastAccessed = Date()
        return cached.isOperational
    }
    
    func cacheMachineStatus(_ isOperational: Bool, for machineId: String) {
        let cached = CachedMachineStatus(machineId: machineId, isOperational: isOperational)
        machineStatusCache[machineId] = cached
    }
    
    func invalidateMachineStatusCache(for machineId: String? = nil) {
        if let machineId = machineId {
            machineStatusCache.removeValue(forKey: machineId)
        } else {
            machineStatusCache.removeAll()
        }
    }
    
    // MARK: - Conflict Check Caching (冲突检查缓存)
    
    func getCachedConflictCheck(for key: ConflictCheckKey) -> Bool? {
        let cacheKey = key.stringValue
        
        guard let cached = conflictCheckCache[cacheKey],
              !cached.isExpired(ttl: conflictCheckCacheTTL) else {
            conflictCheckCache.removeValue(forKey: cacheKey)
            return nil
        }
        
        cached.lastAccessed = Date()
        return cached.hasConflict
    }
    
    func cacheConflictCheck(hasConflict: Bool, for key: ConflictCheckKey) {
        let cacheKey = key.stringValue
        let cached = CachedConflictCheck(key: key, hasConflict: hasConflict)
        
        conflictCheckCache[cacheKey] = cached
        maintainCacheSize()
    }
    
    func invalidateConflictCache(for machineId: String? = nil) {
        if let machineId = machineId {
            // Remove all conflict checks involving this machine
            conflictCheckCache = conflictCheckCache.filter { _, cached in
                cached.key.machineId != machineId
            }
        } else {
            conflictCheckCache.removeAll()
        }
    }
    
    // MARK: - Validation Caching (验证缓存)
    
    func getCachedValidation(for batchId: String) -> BatchValidationSummary? {
        guard let cached = validationCache[batchId],
              !cached.isExpired(ttl: validationCacheTTL) else {
            validationCache.removeValue(forKey: batchId)
            return nil
        }
        
        cached.lastAccessed = Date()
        return cached.validation
    }
    
    func cacheValidation(_ validation: BatchValidationSummary, for batchId: String) {
        let cached = CachedValidation(batchId: batchId, validation: validation)
        validationCache[batchId] = cached
    }
    
    func invalidateValidationCache(for batchId: String? = nil) {
        if let batchId = batchId {
            validationCache.removeValue(forKey: batchId)
        } else {
            validationCache.removeAll()
        }
    }
    
    // MARK: - Cache Management (缓存管理)
    
    private func maintainCacheSize() {
        let totalCacheSize = batchCache.count + machineStatusCache.count + 
                           conflictCheckCache.count + validationCache.count
        
        if totalCacheSize > maxCacheSize {
            // Remove least recently used entries
            cleanupLRUEntries()
        }
    }
    
    private func cleanupLRUEntries() {
        // Cleanup batch cache
        let sortedBatchEntries = batchCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let batchesToRemove = max(0, sortedBatchEntries.count - maxCacheSize / 4)
        
        for i in 0..<batchesToRemove {
            batchCache.removeValue(forKey: sortedBatchEntries[i].key)
        }
        
        // Cleanup conflict cache
        let sortedConflictEntries = conflictCheckCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let conflictsToRemove = max(0, sortedConflictEntries.count - maxCacheSize / 4)
        
        for i in 0..<conflictsToRemove {
            conflictCheckCache.removeValue(forKey: sortedConflictEntries[i].key)
        }
        
        // Cleanup validation cache
        let sortedValidationEntries = validationCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let validationsToRemove = max(0, sortedValidationEntries.count - maxCacheSize / 4)
        
        for i in 0..<validationsToRemove {
            validationCache.removeValue(forKey: sortedValidationEntries[i].key)
        }
    }
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performScheduledCleanup()
            }
        }
    }
    
    private func performScheduledCleanup() {
        let now = Date()
        
        // Clean expired batch cache entries
        batchCache = batchCache.filter { _, cached in
            !cached.isExpired(ttl: batchCacheTTL, currentTime: now)
        }
        
        // Clean expired machine status cache entries
        machineStatusCache = machineStatusCache.filter { _, cached in
            !cached.isExpired(ttl: machineStatusCacheTTL, currentTime: now)
        }
        
        // Clean expired conflict check cache entries
        conflictCheckCache = conflictCheckCache.filter { _, cached in
            !cached.isExpired(ttl: conflictCheckCacheTTL, currentTime: now)
        }
        
        // Clean expired validation cache entries
        validationCache = validationCache.filter { _, cached in
            !cached.isExpired(ttl: validationCacheTTL, currentTime: now)
        }
    }
    
    // MARK: - Cache Statistics (缓存统计)
    
    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            batchCacheSize: batchCache.count,
            machineStatusCacheSize: machineStatusCache.count,
            conflictCheckCacheSize: conflictCheckCache.count,
            validationCacheSize: validationCache.count,
            totalMemoryUsage: estimateMemoryUsage()
        )
    }
    
    private func estimateMemoryUsage() -> Int {
        // Rough estimation in bytes
        let batchCacheMemory = batchCache.values.reduce(0) { total, cached in
            total + cached.batches.count * 1024 // Rough estimate per batch
        }
        
        let machineStatusMemory = machineStatusCache.count * 64
        let conflictCheckMemory = conflictCheckCache.count * 128
        let validationMemory = validationCache.count * 512
        
        return batchCacheMemory + machineStatusMemory + conflictCheckMemory + validationMemory
    }
    
    func clearAllCaches() {
        batchCache.removeAll()
        machineStatusCache.removeAll()
        conflictCheckCache.removeAll()
        validationCache.removeAll()
    }
}

// MARK: - Cache Data Structures (缓存数据结构)

private class CachedBatch {
    let batches: [ProductionBatch]
    let createdAt: Date
    var lastAccessed: Date
    
    init(batches: [ProductionBatch]) {
        self.batches = batches
        self.createdAt = Date()
        self.lastAccessed = Date()
    }
    
    func isExpired(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        return currentTime.timeIntervalSince(createdAt) > ttl
    }
}

private class CachedMachineStatus {
    let machineId: String
    let isOperational: Bool
    let createdAt: Date
    var lastAccessed: Date
    
    init(machineId: String, isOperational: Bool) {
        self.machineId = machineId
        self.isOperational = isOperational
        self.createdAt = Date()
        self.lastAccessed = Date()
    }
    
    func isExpired(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        return currentTime.timeIntervalSince(createdAt) > ttl
    }
}

private class CachedConflictCheck {
    let key: ConflictCheckKey
    let hasConflict: Bool
    let createdAt: Date
    var lastAccessed: Date
    
    init(key: ConflictCheckKey, hasConflict: Bool) {
        self.key = key
        self.hasConflict = hasConflict
        self.createdAt = Date()
        self.lastAccessed = Date()
    }
    
    func isExpired(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        return currentTime.timeIntervalSince(createdAt) > ttl
    }
}

private class CachedValidation {
    let batchId: String
    let validation: BatchValidationSummary
    let createdAt: Date
    var lastAccessed: Date
    
    init(batchId: String, validation: BatchValidationSummary) {
        self.batchId = batchId
        self.validation = validation
        self.createdAt = Date()
        self.lastAccessed = Date()
    }
    
    func isExpired(ttl: TimeInterval, currentTime: Date = Date()) -> Bool {
        return currentTime.timeIntervalSince(createdAt) > ttl
    }
}

// MARK: - Cache Key Types (缓存键类型)

struct BatchCacheKey {
    let type: BatchQueryType
    let parameters: [String: Any]
    
    var stringValue: String {
        let paramString = parameters.compactMap { key, value in
            "\(key):\(String(describing: value))"
        }.sorted().joined(separator: ",")
        
        return "\(type.rawValue)_\(paramString)"
    }
}

enum BatchQueryType: String {
    case allBatches = "all"
    case byStatus = "status"
    case byMachine = "machine"
    case byDateShift = "date_shift"
    case byDate = "date"
    case shiftAware = "shift_aware"
    case conflicting = "conflicting"
}

struct ConflictCheckKey {
    let date: Date
    let shift: Shift
    let machineId: String
    let excludingBatchId: String?
    
    var stringValue: String {
        let dateString = ISO8601DateFormatter().string(from: date)
        let excludeString = excludingBatchId ?? "none"
        return "conflict_\(dateString)_\(shift.rawValue)_\(machineId)_\(excludeString)"
    }
}

struct CacheStatistics {
    let batchCacheSize: Int
    let machineStatusCacheSize: Int
    let conflictCheckCacheSize: Int
    let validationCacheSize: Int
    let totalMemoryUsage: Int
    
    var totalCacheSize: Int {
        return batchCacheSize + machineStatusCacheSize + conflictCheckCacheSize + validationCacheSize
    }
    
    var memoryUsageString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(totalMemoryUsage))
    }
}

// MARK: - Enhanced Repository with Caching (带缓存的增强存储库)

extension LocalProductionBatchRepository {
    
    private var cacheService: BatchCacheService? {
        // This would be injected or accessed through a service locator
        return nil // Placeholder - would be properly implemented
    }
    
    func fetchBatchesWithCache(forDate date: Date, shift: Shift) async throws -> [ProductionBatch] {
        let cacheKey = BatchCacheKey(
            type: .byDateShift,
            parameters: [
                "date": ISO8601DateFormatter().string(from: date),
                "shift": shift.rawValue
            ]
        )
        
        // Try cache first
        if let cachedBatches = await cacheService?.getCachedBatches(for: cacheKey) {
            return cachedBatches
        }
        
        // Fetch from database
        let batches = try await fetchBatches(forDate: date, shift: shift)
        
        // Cache the result
        await cacheService?.cacheBatches(batches, for: cacheKey)
        
        return batches
    }
    
    func hasConflictingBatchesWithCache(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool {
        let cacheKey = ConflictCheckKey(
            date: date,
            shift: shift,
            machineId: machineId,
            excludingBatchId: excludingBatchId
        )
        
        // Try cache first
        if let cachedResult = await cacheService?.getCachedConflictCheck(for: cacheKey) {
            return cachedResult
        }
        
        // Check database
        let hasConflict = try await hasConflictingBatches(forDate: date, shift: shift, machineId: machineId, excludingBatchId: excludingBatchId)
        
        // Cache the result
        await cacheService?.cacheConflictCheck(hasConflict: hasConflict, for: cacheKey)
        
        return hasConflict
    }
}

// MARK: - Cache-aware Batch Service Extension (缓存感知批次服务扩展)

extension ProductionBatchService {
    
    func invalidateRelatedCaches(for batch: ProductionBatch) {
        // This would be called when a batch is created, updated, or deleted
        // to ensure cache consistency
        
        // Invalidate machine status cache
        // cacheService.invalidateMachineStatusCache(for: batch.machineId)
        
        // Invalidate conflict cache for the machine
        // cacheService.invalidateConflictCache(for: batch.machineId)
        
        // Invalidate batch caches
        if let targetDate = batch.targetDate, let shift = batch.shift {
            let dateShiftKey = BatchCacheKey(
                type: .byDateShift,
                parameters: [
                    "date": ISO8601DateFormatter().string(from: targetDate),
                    "shift": shift.rawValue
                ]
            )
            // cacheService.invalidateBatchCache(for: dateShiftKey)
        }
    }
}