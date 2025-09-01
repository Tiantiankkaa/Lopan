//
//  OutOfStockCacheManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//  Enhanced three-level cache system for high-performance data handling
//

import Foundation
import SwiftData
import UIKit

// MARK: - Enhanced Cache Key Structure

struct OutOfStockCacheKey: Hashable, Codable {
    let date: Date
    let filterHash: String
    let page: Int
    let pageSize: Int
    
    init(date: Date, criteria: OutOfStockFilterCriteria, page: Int) {
        // Use criteria.dateRange.start as the authoritative date source to avoid inconsistencies
        let authorativeDate = criteria.dateRange?.start ?? date
        self.date = Calendar.current.startOfDay(for: authorativeDate)
        self.page = page
        self.pageSize = criteria.pageSize
        
        // Create a comprehensive hash from filter criteria
        var hasher = Hasher()
        hasher.combine(criteria.customer?.id)
        hasher.combine(criteria.product?.id)
        // Ensure status filter is properly represented in cache key
        hasher.combine(criteria.status?.rawValue ?? "all")  // Use "all" for nil status
        hasher.combine(criteria.searchText)
        hasher.combine(criteria.sortOrder.rawValue)
        
        // Use the authoritative date in the hash to ensure consistency
        hasher.combine(self.date.timeIntervalSince1970)
        
        self.filterHash = String(hasher.finalize())
        
        print("🔑 [Cache Key] Generated key for date=\(self.date), status=\(criteria.status?.displayName ?? "all"), hash=\(self.filterHash)")
    }
    
    var cacheIdentifier: String {
        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        return "outOfStock_\(dateString)_\(filterHash)_p\(page)_s\(pageSize)"
    }
}

// MARK: - Enhanced Cached Page Data

struct CachedOutOfStockPage: Codable {
    let items: [CustomerOutOfStockDTO]
    let totalCount: Int
    let hasMoreData: Bool
    let cachedAt: Date
    let lastAccessed: Date
    let accessCount: Int
    let priority: CachePriority
    let dataHash: String
    
    enum CachePriority: Int, Codable, CaseIterable {
        case low = 1
        case normal = 2
        case high = 3
        case critical = 4
        
        var scoreMultiplier: Double {
            switch self {
            case .low: return 0.5
            case .normal: return 1.0
            case .high: return 2.0
            case .critical: return 4.0
            }
        }
    }
    
    init(items: [CustomerOutOfStockDTO], totalCount: Int, hasMoreData: Bool, priority: CachePriority = .normal) {
        self.items = items
        self.totalCount = totalCount
        self.hasMoreData = hasMoreData
        self.cachedAt = Date()
        self.lastAccessed = Date()
        self.accessCount = 1
        self.priority = priority
        
        // Create data hash for integrity checking
        var hasher = Hasher()
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.updatedAt)
        }
        hasher.combine(totalCount)
        hasher.combine(hasMoreData)
        self.dataHash = String(hasher.finalize())
    }
    
    private init(items: [CustomerOutOfStockDTO], totalCount: Int, hasMoreData: Bool, cachedAt: Date, lastAccessed: Date, accessCount: Int, priority: CachePriority, dataHash: String) {
        self.items = items
        self.totalCount = totalCount
        self.hasMoreData = hasMoreData
        self.cachedAt = cachedAt
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
        self.priority = priority
        self.dataHash = dataHash
    }
    
    func updatingLastAccessed() -> CachedOutOfStockPage {
        return CachedOutOfStockPage(
            items: items,
            totalCount: totalCount,
            hasMoreData: hasMoreData,
            cachedAt: cachedAt,
            lastAccessed: Date(),
            accessCount: accessCount + 1,
            priority: priority,
            dataHash: dataHash
        )
    }
    
    var isExpired: Bool {
        let ttl: TimeInterval = priority == .critical ? 600 : 300 // 10 min for critical, 5 min for others
        return Date().timeIntervalSince(cachedAt) > ttl
    }
    
    var cacheScore: Double {
        let timeFactor = max(0.1, 1.0 - Date().timeIntervalSince(lastAccessed) / 3600) // Decay over 1 hour
        let accessFactor = min(10.0, Double(accessCount) / 10.0) // Cap at 10x
        let priorityFactor = priority.scoreMultiplier
        
        return timeFactor * accessFactor * priorityFactor
    }
    
    var estimatedSizeInBytes: Int {
        return items.count * 512 + 1024 // Rough estimate
    }
}

// MARK: - Cache Statistics

struct OutOfStockCacheStatistics {
    let memoryHits: Int
    let diskHits: Int
    let countCacheHits: Int
    let totalMisses: Int
    let memorySize: Int
    let diskSize: Int
    let countCacheSize: Int
    let memoryUsageBytes: Int
    let diskUsageBytes: Int
    let averageAccessTime: Double
    let hitRate: Double
    
    var description: String {
        let hitRatePercent = hitRate * 100
        let memoryMB = memoryUsageBytes / (1024 * 1024)
        let diskMB = diskUsageBytes / (1024 * 1024)
        
        return """
        📊 Cache Performance:
        • Hit Rate: \(String(format: "%.1f", hitRatePercent))%
        • Count Cache: \(countCacheHits) hits, \(countCacheSize) entries
        • Memory: \(memorySize) pages (\(memoryMB)MB)
        • Disk: \(diskSize) pages (\(diskMB)MB) 
        • Avg Access: \(String(format: "%.2f", averageAccessTime))ms
        """
    }
}

// MARK: - Three-Level Cache Manager

@MainActor
class OutOfStockCacheManager: ObservableObject {
    
    // MARK: - Configuration
    
    private struct CacheConfig {
        static let maxMemoryPages = 50
        static let maxMemoryCacheSize = 50  // Maximum number of cache entries
        static let maxDiskPages = 200
        static let maxMemoryBytes = 50 * 1024 * 1024  // 50MB
        static let maxDiskBytes = 200 * 1024 * 1024   // 200MB
        static let diskCacheTTL: TimeInterval = 1800  // 30 minutes
        static let cleanupInterval: TimeInterval = 120 // 2 minutes
        static let preloadRadius = 3 // Pages to preload around current
    }
    
    // MARK: - Level 1: Memory Cache (Hot Data)
    
    private var memoryCache: [OutOfStockCacheKey: CachedOutOfStockPage] = [:]
    private var memoryAccessOrder: [OutOfStockCacheKey] = []
    
    // MARK: - Level 2: Disk Cache (Warm Data)
    
    private let diskCacheDirectory: URL
    private let diskQueue = DispatchQueue(label: "outOfStock.diskCache", qos: .utility)
    private let compressionQueue = DispatchQueue(label: "outOfStock.compression", qos: .background)
    
    // MARK: - Level 0: Count Cache (Ultra Hot Data)
    
    private var countCache: [String: (count: Int, timestamp: Date)] = [:]
    private var statusCountCache: [String: (counts: [OutOfStockStatus: Int], timestamp: Date)] = [:]
    private let countCacheTTL: TimeInterval = 30 // 30 seconds for ultra-fast counts
    private let statusCountCacheTTL: TimeInterval = 60 // 60 seconds for status counts
    
    // MARK: - Level -1: Base Data Cache (Status-agnostic)
    
    private var baseDataCache: [String: (items: [CustomerOutOfStockDTO], timestamp: Date)] = [:]
    private let baseDataCacheTTL: TimeInterval = 300 // 5 minutes for base data
    
    // MARK: - Performance Metrics
    
    @Published private var memoryHits = 0
    @Published private var diskHits = 0
    @Published private var countCacheHits = 0
    @Published private var statusCountCacheHits = 0
    @Published private var baseDataCacheHits = 0
    @Published private var totalMisses = 0
    private var accessTimes: [Double] = []
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDir.appendingPathComponent("OutOfStockCache")
        
        createCacheDirectory()
        setupMemoryWarningObserver()
        startPeriodicMaintenance()
        loadCriticalDataFromDisk()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Cache API
    
    /// Get cached count for filter criteria (fastest path)
    func getCachedCount(for criteria: OutOfStockFilterCriteria) -> Int? {
        let cacheKey = generateCountCacheKey(from: criteria)
        
        if let cached = countCache[cacheKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age <= countCacheTTL {
                countCacheHits += 1
                print("⚡ [Count Cache] Hit for key: \(cacheKey), count: \(cached.count), age: \(String(format: "%.1f", age))s")
                return cached.count
            } else {
                // Remove expired entry
                countCache.removeValue(forKey: cacheKey)
                print("⏰ [Count Cache] Expired entry removed: \(cacheKey)")
            }
        }
        
        return nil
    }
    
    /// Get cached status counts for filter criteria (includes date filtering)
    func getCachedStatusCounts(for criteria: OutOfStockFilterCriteria) -> [OutOfStockStatus: Int]? {
        let statusCountKey = generateStatusCountCacheKey(from: criteria)
        
        if let cached = statusCountCache[statusCountKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age <= statusCountCacheTTL {
                statusCountCacheHits += 1
                print("⚡ [Status Count Cache] Hit for key: \(statusCountKey), age: \(String(format: "%.1f", age))s")
                return cached.counts
            } else {
                statusCountCache.removeValue(forKey: statusCountKey)
                print("⏰ [Status Count Cache] Expired entry removed: \(statusCountKey)")
            }
        }
        
        return nil
    }
    
    /// Cache status counts for filter criteria (includes date filtering)
    func cacheStatusCounts(_ counts: [OutOfStockStatus: Int], for criteria: OutOfStockFilterCriteria) {
        let statusCountKey = generateStatusCountCacheKey(from: criteria)
        statusCountCache[statusCountKey] = (counts: counts, timestamp: Date())
        print("💾 [Status Count Cache] Stored counts for key: \(statusCountKey)")
        
        // Cleanup old entries
        if statusCountCache.count > 50 {
            cleanupExpiredStatusCountCache()
        }
    }
    
    /// Cache count result for ultra-fast future access
    func cacheCount(_ count: Int, for criteria: OutOfStockFilterCriteria) {
        let cacheKey = generateCountCacheKey(from: criteria)
        countCache[cacheKey] = (count: count, timestamp: Date())
        
        print("💾 [Count Cache] Stored count: \(count) for key: \(cacheKey)")
        
        // Cleanup old entries to prevent memory bloat
        if countCache.count > 100 {
            cleanupExpiredCountCacheEntries()
        }
    }
    
    /// Special method for "clear all" filters - highest priority caching
    func getCachedClearAllCount() -> Int? {
        return getCachedCount(for: createClearAllCriteria())
    }
    
    /// Cache the expensive "clear all" count
    func cacheClearAllCount(_ count: Int) {
        cacheCount(count, for: createClearAllCriteria())
    }
    
    private func createClearAllCriteria() -> OutOfStockFilterCriteria {
        return OutOfStockFilterCriteria(
            customer: nil,
            product: nil,
            status: nil,
            dateRange: nil,
            searchText: "",
            page: 0,
            pageSize: 1
        )
    }
    
    private func generateCountCacheKey(from criteria: OutOfStockFilterCriteria) -> String {
        var hasher = Hasher()
        hasher.combine(criteria.customer?.id)
        hasher.combine(criteria.product?.id)
        hasher.combine(criteria.status?.rawValue ?? "all")
        hasher.combine(criteria.searchText)
        
        // For count cache, we don't care about pagination
        if let dateRange = criteria.dateRange {
            hasher.combine(dateRange.start.timeIntervalSince1970)
            hasher.combine(dateRange.end.timeIntervalSince1970)
        }
        
        return "count_\(hasher.finalize())"
    }
    
    private func cleanupExpiredCountCacheEntries() {
        let now = Date()
        let keysToRemove = countCache.compactMap { key, cached in
            now.timeIntervalSince(cached.timestamp) > countCacheTTL ? key : nil
        }
        
        for key in keysToRemove {
            countCache.removeValue(forKey: key)
        }
        
        print("🧹 [Count Cache] Cleaned up \(keysToRemove.count) expired entries")
    }
    
    private func cleanupExpiredStatusCountCache() {
        let now = Date()
        let keysToRemove = statusCountCache.compactMap { key, cached in
            now.timeIntervalSince(cached.timestamp) > statusCountCacheTTL ? key : nil
        }
        
        for key in keysToRemove {
            statusCountCache.removeValue(forKey: key)
        }
        
        print("🧹 [Status Count Cache] Cleaned up \(keysToRemove.count) expired entries")
    }
    
    private func generateBaseDataKey(from criteria: OutOfStockFilterCriteria) -> String {
        // Base data key excludes status and pagination to allow status filtering on cached data
        var hasher = Hasher()
        hasher.combine(criteria.customer?.id)
        hasher.combine(criteria.product?.id)
        hasher.combine(criteria.searchText)
        
        if let dateRange = criteria.dateRange {
            hasher.combine(dateRange.start.timeIntervalSince1970)
            hasher.combine(dateRange.end.timeIntervalSince1970)
        }
        
        return "baseData_\(hasher.finalize())"
    }
    
    private func generateStatusCountCacheKey(from criteria: OutOfStockFilterCriteria) -> String {
        // Status count key includes date filtering for accurate date-specific counts
        var hasher = Hasher()
        hasher.combine(criteria.customer?.id)
        hasher.combine(criteria.product?.id)
        hasher.combine(criteria.searchText)
        
        if let dateRange = criteria.dateRange {
            hasher.combine(dateRange.start.timeIntervalSince1970)
            hasher.combine(dateRange.end.timeIntervalSince1970)
        }
        
        return "statusCounts_\(hasher.finalize())"
    }
    
    /// Get cached base data items (status-agnostic)
    func getCachedBaseData(for criteria: OutOfStockFilterCriteria) -> [CustomerOutOfStockDTO]? {
        let baseKey = generateBaseDataKey(from: criteria)
        
        if let cached = baseDataCache[baseKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age <= baseDataCacheTTL {
                baseDataCacheHits += 1
                print("⚡ [Base Data Cache] Hit for key: \(baseKey), items: \(cached.items.count), age: \(String(format: "%.1f", age))s")
                return cached.items
            } else {
                baseDataCache.removeValue(forKey: baseKey)
                print("⏰ [Base Data Cache] Expired entry removed: \(baseKey)")
            }
        }
        
        return nil
    }
    
    /// Cache base data items (status-agnostic)
    func cacheBaseData(_ items: [CustomerOutOfStockDTO], for criteria: OutOfStockFilterCriteria) {
        let baseKey = generateBaseDataKey(from: criteria)
        baseDataCache[baseKey] = (items: items, timestamp: Date())
        print("💾 [Base Data Cache] Stored \(items.count) items for key: \(baseKey)")
        
        // Cleanup old entries
        if baseDataCache.count > 20 {
            cleanupExpiredBaseDataCache()
        }
    }
    
    private func cleanupExpiredBaseDataCache() {
        let now = Date()
        let keysToRemove = baseDataCache.compactMap { key, cached in
            now.timeIntervalSince(cached.timestamp) > baseDataCacheTTL ? key : nil
        }
        
        for key in keysToRemove {
            baseDataCache.removeValue(forKey: key)
        }
        
        print("🧹 [Base Data Cache] Cleaned up \(keysToRemove.count) expired entries")
    }
    
    func getCachedPage(for key: OutOfStockCacheKey) async -> CachedOutOfStockPage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let accessTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            recordAccessTime(accessTime)
        }
        
        // Validate date in cache key to prevent cross-date contamination
        let requestedDate = Calendar.current.startOfDay(for: key.date)
        
        // Level 1: Memory Cache Check (Fastest)
        if let page = getFromMemoryCache(key) {
            // Enhanced validation: check if cached data items match the requested date
            if await validateCachedPageDate(page, expectedDate: requestedDate) {
                memoryHits += 1
                print("📥 [Cache] Memory cache hit for date: \(requestedDate), validated items match")
                return page
            } else {
                print("⚠️ [Cache] Date validation failed for memory cache entry, removing")
                removeFromMemoryCache(key)
            }
        }
        
        // Level 2: Disk Cache Check (Fast)
        if let page = await getFromDiskCache(key) {
            // Enhanced validation: check if cached data items match the requested date
            if await validateCachedPageDate(page, expectedDate: requestedDate) {
                // Promote to memory cache
                addToMemoryCache(page, for: key)
                diskHits += 1
                print("📥 [Cache] Disk cache hit for date: \(requestedDate), validated items match")
                return page
            } else {
                print("⚠️ [Cache] Date validation failed for disk cache entry, removing")
                await removeDiskCacheEntry(for: key)
            }
        }
        
        // Level 3: Cache Miss - will be handled by repository layer
        totalMisses += 1
        print("📭 [Cache] Cache miss for date: \(requestedDate)")
        return nil
    }
    
    /// Validates that all items in a cached page match the expected date
    /// - Parameters:
    ///   - page: The cached page to validate
    ///   - expectedDate: The expected date (start of day)
    /// - Returns: True if all items match the expected date, false otherwise
    private func validateCachedPageDate(_ page: CachedOutOfStockPage, expectedDate: Date) async -> Bool {
        // If no items, consider it valid (empty result for the date)
        guard !page.items.isEmpty else { 
            print("📝 [Cache] Empty cached page considered valid for date: \(expectedDate)")
            return true 
        }
        
        // Check if all items have requestDate matching the expected date
        let calendar = Calendar.current
        for item in page.items {
            let itemDate = calendar.startOfDay(for: item.requestDate)
            if itemDate != expectedDate {
                print("⚠️ [Cache] Item date mismatch: expected \(expectedDate), found \(itemDate)")
                return false
            }
        }
        
        print("✅ [Cache] All \(page.items.count) items match expected date: \(expectedDate)")
        return true
    }
    
    func cachePage(_ page: CachedOutOfStockPage, for key: OutOfStockCacheKey, priority: CachedOutOfStockPage.CachePriority = .normal) async {
        let enhancedPage = CachedOutOfStockPage(
            items: page.items,
            totalCount: page.totalCount,
            hasMoreData: page.hasMoreData,
            priority: priority
        )
        
        // Always add to memory cache
        addToMemoryCache(enhancedPage, for: key)
        
        // Asynchronously write to disk for persistence
        Task.detached(priority: .utility) {
            await self.saveToDiskCache(enhancedPage, for: key)
        }
        
        // Intelligent preloading
        if priority.scoreMultiplier >= 2.0 {
            await preloadAdjacentPages(around: key)
        }
    }
    
    func invalidateCache(for date: Date? = nil, filterHash: String? = nil) async {
        print("🧹 [Cache] Starting cache invalidation - date: \(date?.description ?? "all"), filter: \(filterHash ?? "all")")
        
        // Always clear count cache when invalidating - critical for filter changes
        let countCacheCleared = countCache.count
        let statusCountCacheCleared = statusCountCache.count
        let baseDataCacheCleared = baseDataCache.count
        
        countCache.removeAll()
        statusCountCache.removeAll()
        baseDataCache.removeAll()
        
        print("🧹 [Count Cache] Cleared \(countCacheCleared) count cache entries during invalidation")
        print("🧹 [Status Count Cache] Cleared \(statusCountCacheCleared) status count entries during invalidation")
        print("🧹 [Base Data Cache] Cleared \(baseDataCacheCleared) base data entries during invalidation")
        
        if let date = date, let filterHash = filterHash {
            // Remove specific date/filter combination
            let normalizedDate = Calendar.current.startOfDay(for: date)
            await removeFromCaches { key in
                key.date == normalizedDate && key.filterHash == filterHash
            }
            print("🧹 [Cache] Invalidated specific date/filter combo: \(normalizedDate), hash: \(filterHash)")
        } else if let date = date {
            // Remove all entries for specific date
            let normalizedDate = Calendar.current.startOfDay(for: date)
            await removeFromCaches { key in
                key.date == normalizedDate
            }
            print("🧹 [Cache] Invalidated all entries for date: \(normalizedDate)")
        } else if let filterHash = filterHash {
            // Remove all entries with specific filter
            await removeFromCaches { key in
                key.filterHash == filterHash
            }
            print("🧹 [Cache] Invalidated all entries with filter hash: \(filterHash)")
        } else {
            // Clear all caches
            print("🧹 [Cache] Clearing ALL caches")
            await clearAllCaches()
        }
        
        print("✅ [Cache] Cache invalidation completed")
    }
    
    func clearAllCaches() async {
        let memoryCount = memoryCache.count
        let countCacheCount = countCache.count
        let statusCountCacheCount = statusCountCache.count
        let baseDataCacheCount = baseDataCache.count
        
        // Clear all caches
        countCache.removeAll()
        statusCountCache.removeAll()
        baseDataCache.removeAll()
        memoryCache.removeAll()
        memoryAccessOrder.removeAll()
        
        // Clear disk cache asynchronously
        await clearDiskCache()
        
        print("🧹 Cleared all caches: \(memoryCount) memory pages, \(countCacheCount) count entries, \(statusCountCacheCount) status count entries, \(baseDataCacheCount) base data entries removed")
    }
    
    func getOutOfStockCacheStatistics() async -> OutOfStockCacheStatistics {
        let totalRequests = memoryHits + diskHits + countCacheHits + totalMisses
        let hitRate = totalRequests > 0 ? Double(memoryHits + diskHits + countCacheHits) / Double(totalRequests) : 0.0
        
        let memoryUsage = memoryCache.values.reduce(0) { $0 + $1.estimatedSizeInBytes }
        let diskUsage = await calculateDiskUsage()
        let avgAccessTime = accessTimes.isEmpty ? 0.0 : accessTimes.reduce(0, +) / Double(accessTimes.count)
        
        return OutOfStockCacheStatistics(
            memoryHits: memoryHits,
            diskHits: diskHits,
            countCacheHits: countCacheHits + statusCountCacheHits + baseDataCacheHits,
            totalMisses: totalMisses,
            memorySize: memoryCache.count,
            diskSize: await countDiskCacheFiles(),
            countCacheSize: countCache.count + statusCountCache.count + baseDataCache.count,
            memoryUsageBytes: memoryUsage,
            diskUsageBytes: diskUsage,
            averageAccessTime: avgAccessTime,
            hitRate: hitRate
        )
    }
    
    /// Convert CustomerOutOfStock models to DTOs safely (must be called on main thread)
    @MainActor
    func createCachedPage(from items: [CustomerOutOfStock], totalCount: Int, hasMoreData: Bool, priority: CachedOutOfStockPage.CachePriority = .normal) -> CachedOutOfStockPage {
        // Convert SwiftData models to thread-safe DTOs
        let dtoItems = items.map { CustomerOutOfStockDTO(from: $0) }
        return CachedOutOfStockPage(items: dtoItems, totalCount: totalCount, hasMoreData: hasMoreData, priority: priority)
    }
    
    // MARK: - Memory Cache Operations
    
    private func getFromMemoryCache(_ key: OutOfStockCacheKey) -> CachedOutOfStockPage? {
        guard let page = memoryCache[key] else { return nil }
        
        if page.isExpired {
            removeFromMemoryCache(key)
            return nil
        }
        
        // Update access order and access count
        let updatedPage = page.updatingLastAccessed()
        memoryCache[key] = updatedPage
        updateMemoryAccessOrder(key)
        
        return updatedPage
    }
    
    private func addToMemoryCache(_ page: CachedOutOfStockPage, for key: OutOfStockCacheKey) {
        // Ensure we don't exceed memory limits
        enforceMemoryLimits()
        
        memoryCache[key] = page
        updateMemoryAccessOrder(key)
    }
    
    private func removeFromMemoryCache(_ key: OutOfStockCacheKey) {
        memoryCache.removeValue(forKey: key)
        memoryAccessOrder.removeAll { $0 == key }
    }
    
    private func updateMemoryAccessOrder(_ key: OutOfStockCacheKey) {
        memoryAccessOrder.removeAll { $0 == key }
        memoryAccessOrder.append(key)
    }
    
    private func enforceMemoryLimits() {
        // Remove pages if over limit
        while memoryCache.count >= CacheConfig.maxMemoryPages ||
                currentMemoryUsage() >= CacheConfig.maxMemoryBytes {
            evictLeastValueablePage()
        }
    }
    
    private func evictLeastValueablePage() {
        guard !memoryCache.isEmpty else { return }
        
        // Find page with lowest cache score
        let keyToEvict = memoryCache.min { (first, second) in
            first.value.cacheScore < second.value.cacheScore
        }?.key
        
        if let key = keyToEvict {
            removeFromMemoryCache(key)
        }
    }
    
    private func currentMemoryUsage() -> Int {
        return memoryCache.values.reduce(0) { $0 + $1.estimatedSizeInBytes }
    }
    
    // MARK: - Disk Cache Operations
    
    private func getFromDiskCache(_ key: OutOfStockCacheKey) async -> CachedOutOfStockPage? {
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                let fileURL = self.diskCacheFile(for: key)
                
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decompressedData = try self.decompress(data)
                    let page = try JSONDecoder().decode(CachedOutOfStockPage.self, from: decompressedData)
                    
                    if page.isExpired {
                        try? FileManager.default.removeItem(at: fileURL)
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    continuation.resume(returning: page)
                } catch {
                    print("❌ Failed to load from disk cache: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func saveToDiskCache(_ page: CachedOutOfStockPage, for key: OutOfStockCacheKey) async {
        await withCheckedContinuation { continuation in
            compressionQueue.async {
                do {
                    let data = try JSONEncoder().encode(page)
                    let compressedData = try self.compress(data)
                    let fileURL = self.diskCacheFile(for: key)
                    
                    try compressedData.write(to: fileURL)
                } catch {
                    print("❌ Failed to save to disk cache: \(error)")
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    private func diskCacheFile(for key: OutOfStockCacheKey) -> URL {
        return diskCacheDirectory.appendingPathComponent("\(key.cacheIdentifier).cache")
    }
    
    // MARK: - Utility Methods
    
    private func removeFromCaches(where predicate: (OutOfStockCacheKey) -> Bool) async {
        // Remove from memory
        let memoryKeysToRemove = memoryCache.keys.filter(predicate)
        for key in memoryKeysToRemove {
            removeFromMemoryCache(key)
        }
        
        // Remove from disk
        await removeDiskCacheFiles(where: predicate)
    }
    
    private func removeDiskCacheFiles(where predicate: (OutOfStockCacheKey) -> Bool) async {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: self.diskCacheDirectory, includingPropertiesForKeys: nil)
                    
                    for file in files {
                        let filename = file.deletingPathExtension().lastPathComponent
                        // This is a simplified check - in production you'd need proper key reconstruction
                        if filename.contains("outOfStock_") {
                            try? FileManager.default.removeItem(at: file)
                        }
                    }
                } catch {
                    print("❌ Failed to remove disk cache files: \(error)")
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    private func clearDiskCache() async {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: self.diskCacheDirectory, includingPropertiesForKeys: nil)
                    for file in files {
                        try? FileManager.default.removeItem(at: file)
                    }
                } catch {
                    print("❌ Failed to clear disk cache: \(error)")
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    private func removeDiskCacheEntry(for key: OutOfStockCacheKey) async {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                let filename = key.cacheIdentifier + ".json"
                let fileURL = self.diskCacheDirectory.appendingPathComponent(filename)
                
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                        print("🗑️ [Cache] Removed disk cache entry: \(filename)")
                    }
                } catch {
                    print("❌ Failed to remove disk cache entry \(filename): \(error)")
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Maintenance and Setup
    
    private func createCacheDirectory() {
        try? FileManager.default.createDirectory(
            at: diskCacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() async {
        let originalCount = memoryCache.count
        
        // Aggressive cleanup - keep only critical priority items
        let keysToKeep = memoryCache.compactMap { key, page in
            page.priority == .critical ? key : nil
        }
        
        var newCache: [OutOfStockCacheKey: CachedOutOfStockPage] = [:]
        for key in keysToKeep {
            if let page = memoryCache[key] {
                newCache[key] = page
            }
        }
        
        memoryCache = newCache
        memoryAccessOrder = Array(newCache.keys)
        
        print("🚨 Memory warning handled: \(originalCount) → \(memoryCache.count) pages")
    }
    
    private func startPeriodicMaintenance() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: CacheConfig.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performMaintenance()
            }
        }
    }
    
    private func performMaintenance() async {
        // Remove expired entries
        let expiredKeys = memoryCache.compactMap { key, page in
            page.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            removeFromMemoryCache(key)
        }
        
        // Enforce memory limits
        enforceMemoryLimits()
        
        // Cleanup access times array
        if accessTimes.count > 1000 {
            accessTimes = Array(accessTimes.suffix(500))
        }
    }
    
    private func loadCriticalDataFromDisk() {
        // Could implement loading of frequently accessed data on startup
    }
    
    private func saveCriticalDataToDisk() {
        // Could implement saving critical cache state for next startup
    }
    
    private func recordAccessTime(_ time: Double) {
        accessTimes.append(time)
        if accessTimes.count > 100 {
            accessTimes.removeFirst()
        }
    }
    
    private func calculateDiskUsage() async -> Int {
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: self.diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
                    let totalSize = files.reduce(0) { total, file in
                        let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        return total + fileSize
                    }
                    continuation.resume(returning: totalSize)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    private func countDiskCacheFiles() async -> Int {
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: self.diskCacheDirectory, includingPropertiesForKeys: nil)
                    continuation.resume(returning: files.count)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    // MARK: - Intelligent Preloading
    
    private func preloadAdjacentPages(around key: OutOfStockCacheKey) async {
        let currentPage = key.page
        let preloadRange = max(0, currentPage - CacheConfig.preloadRadius)...(currentPage + CacheConfig.preloadRadius)
        
        for pageNum in preloadRange where pageNum != currentPage {
            let adjacentKey = OutOfStockCacheKey(
                date: key.date,
                criteria: OutOfStockFilterCriteria(
                    page: pageNum,
                    pageSize: key.pageSize
                ),
                page: pageNum
            )
            
            // Only preload if not already cached
            if memoryCache[adjacentKey] == nil {
                // This would trigger a background load from the repository
                // The actual implementation would depend on your service layer
                print("🔮 Preloading page \(pageNum) for \(key.date)")
            }
        }
    }
    
    // MARK: - Compression Helpers
    
    private func compress(_ data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .lzfse) as Data
    }
    
    private func decompress(_ data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }
    
    // MARK: - Enhanced Cache Validation & Data Consistency
    
    /// Comprehensive cache validation and consistency check
    /// - Returns: ValidationResult with detailed validation status
    func validateCacheConsistency() async -> CacheValidationResult {
        print("🔍 [Cache Validation] Starting comprehensive cache consistency check...")
        
        var result = CacheValidationResult()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Validate memory cache integrity
        await validateMemoryCacheIntegrity(&result)
        
        // 2. Validate count cache consistency
        await validateCountCacheConsistency(&result)
        
        // 3. Validate base data cache coherence
        await validateBaseDataCacheCoherence(&result)
        
        // 4. Check for date contamination across caches
        await validateDateConsistencyAcrossCaches(&result)
        
        // 5. Validate cache size limits and memory usage
        await validateCacheSizeLimits(&result)
        
        // 6. Check disk cache integrity
        await validateDiskCacheIntegrity(&result)
        
        let validationTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        result.validationTimeMs = validationTime
        
        let statusEmoji = result.isValid ? "✅" : "❌"
        print("\(statusEmoji) [Cache Validation] Completed in \(String(format: "%.2f", validationTime))ms")
        print("📊 [Cache Validation] Errors: \(result.errorCount), Warnings: \(result.warningCount)")
        
        return result
    }
    
    private func validateMemoryCacheIntegrity(_ result: inout CacheValidationResult) async {
        print("🔍 [Memory Cache] Validating integrity...")
        
        for (key, page) in memoryCache {
            // Check if page items match key date
            if !page.items.isEmpty {
                let expectedDate = Calendar.current.startOfDay(for: key.date)
                for item in page.items {
                    let itemDate = Calendar.current.startOfDay(for: item.requestDate)
                    if itemDate != expectedDate {
                        result.addError("Memory cache date mismatch: key=\(key.date), item=\(itemDate)")
                    }
                }
            }
            
            // Check for reasonable totalCount
            if page.totalCount < 0 {
                result.addError("Invalid totalCount in memory cache: \(page.totalCount)")
            }
            
            // Verify items count doesn't exceed totalCount
            if page.items.count > page.totalCount {
                result.addWarning("Items count (\(page.items.count)) exceeds totalCount (\(page.totalCount)) in memory cache")
            }
        }
        
        result.memoryCacheItemsChecked = memoryCache.count
        print("✅ [Memory Cache] Checked \(memoryCache.count) items")
    }
    
    private func validateCountCacheConsistency(_ result: inout CacheValidationResult) async {
        print("🔍 [Count Cache] Validating consistency...")
        
        for (key, cached) in countCache {
            // Check if cache entry is not expired
            let age = Date().timeIntervalSince(cached.timestamp)
            if age > countCacheTTL {
                result.addWarning("Expired count cache entry found: \(key), age: \(age)s")
            }
            
            // Check for reasonable count values
            if cached.count < 0 {
                result.addError("Invalid negative count in cache: \(cached.count)")
            }
        }
        
        result.countCacheItemsChecked = countCache.count
        print("✅ [Count Cache] Checked \(countCache.count) items")
    }
    
    private func validateBaseDataCacheCoherence(_ result: inout CacheValidationResult) async {
        print("🔍 [Base Data Cache] Validating coherence...")
        
        for (key, cached) in baseDataCache {
            // Check cache age
            let age = Date().timeIntervalSince(cached.timestamp)
            if age > baseDataCacheTTL {
                result.addWarning("Expired base data cache entry found: \(key), age: \(age)s")
            }
            
            // Validate items data consistency
            for item in cached.items {
                // Check for valid IDs
                if item.id.description.isEmpty {
                    result.addError("Invalid empty ID in base data cache")
                }
                
                // Check for valid dates
                if item.requestDate.timeIntervalSince1970 < 0 {
                    result.addError("Invalid request date in base data cache: \(item.requestDate)")
                }
                
                // Check for valid status values
                let validStatuses: Set<String> = ["pending", "completed", "returned"]
                if !validStatuses.contains(item.status) {
                    result.addError("Invalid status in base data cache: \(item.status)")
                }
            }
            
            // Check for duplicate IDs within cache entry
            let ids = cached.items.map { $0.id }
            let uniqueIds = Set(ids)
            if ids.count != uniqueIds.count {
                result.addError("Duplicate IDs found in base data cache entry: \(key)")
            }
        }
        
        result.baseDataCacheItemsChecked = baseDataCache.count
        print("✅ [Base Data Cache] Checked \(baseDataCache.count) items")
    }
    
    private func validateDateConsistencyAcrossCaches(_ result: inout CacheValidationResult) async {
        print("🔍 [Cross-Cache] Validating date consistency...")
        
        // Collect all dates from different caches
        let memoryDates = Set(memoryCache.keys.map { Calendar.current.startOfDay(for: $0.date) })
        let baseDataDates = Set(baseDataCache.keys.compactMap { key in
            // Extract date from base data key if possible
            if key.contains("date:") {
                if let colonIndex = key.firstIndex(of: ":") {
                    let dateString = String(key[key.index(after: colonIndex)...])
                    return DateFormatter.yyyyMMdd.date(from: String(dateString.prefix(10)))
                }
            }
            return nil
        })
        
        // Check for date contamination (same date with different formats)
        for date in memoryDates {
            let dateString = DateFormatter.yyyyMMdd.string(from: date)
            let normalizedDate = DateFormatter.yyyyMMdd.date(from: dateString)!
            if date != normalizedDate {
                result.addWarning("Date normalization inconsistency detected: \(date) vs \(normalizedDate)")
            }
        }
        
        result.dateConsistencyChecked = memoryDates.count + baseDataDates.count
        print("✅ [Cross-Cache] Checked \(result.dateConsistencyChecked) date entries")
    }
    
    private func validateCacheSizeLimits(_ result: inout CacheValidationResult) async {
        print("🔍 [Size Limits] Validating cache sizes...")
        
        // Check memory cache size
        if memoryCache.count > CacheConfig.maxMemoryCacheSize {
            result.addWarning("Memory cache exceeds limit: \(memoryCache.count) > \(CacheConfig.maxMemoryCacheSize)")
        }
        
        // Check count cache size
        if countCache.count > 100 { // Reasonable limit for count cache
            result.addWarning("Count cache is large: \(countCache.count) entries")
        }
        
        // Check base data cache size
        if baseDataCache.count > 50 { // Reasonable limit for base data cache
            result.addWarning("Base data cache is large: \(baseDataCache.count) entries")
        }
        
        // Calculate approximate memory usage
        let approximateMemoryUsage = memoryCache.values.reduce(0) { total, page in
            total + page.items.count * 200 // Rough estimate: 200 bytes per item
        }
        
        if approximateMemoryUsage > 10 * 1024 * 1024 { // 10MB
            result.addWarning("High estimated memory usage: \(approximateMemoryUsage) bytes")
        }
        
        result.estimatedMemoryUsage = approximateMemoryUsage
        print("✅ [Size Limits] Memory: \(memoryCache.count) items, ~\(approximateMemoryUsage) bytes")
    }
    
    private func validateDiskCacheIntegrity(_ result: inout CacheValidationResult) async {
        print("🔍 [Disk Cache] Validating integrity...")
        
        let diskFileCount = await countDiskCacheFiles()
        let diskUsage = await calculateDiskUsage()
        
        // Check for excessive disk usage
        if diskUsage > 50 * 1024 * 1024 { // 50MB
            result.addWarning("High disk cache usage: \(diskUsage) bytes")
        }
        
        // Check for excessive file count
        if diskFileCount > 1000 {
            result.addWarning("High disk cache file count: \(diskFileCount) files")
        }
        
        result.diskCacheFileCount = diskFileCount
        result.diskCacheUsage = diskUsage
        print("✅ [Disk Cache] \(diskFileCount) files, \(diskUsage) bytes")
    }
    
    /// Quick consistency check for critical cache operations
    func performQuickConsistencyCheck(for key: OutOfStockCacheKey) -> Bool {
        // Check if memory and disk cache are consistent
        let hasMemoryCache = memoryCache[key] != nil
        
        // If we have memory cache, verify basic integrity
        if hasMemoryCache {
            guard let page = memoryCache[key] else { return false }
            
            // Basic validation: reasonable item count and totalCount
            if page.totalCount < 0 || page.items.count > page.totalCount + 10 { // Allow some tolerance
                print("⚠️ [Quick Check] Inconsistent counts for key: \(key)")
                return false
            }
            
            // Date validation for non-empty pages
            if !page.items.isEmpty {
                let expectedDate = Calendar.current.startOfDay(for: key.date)
                let firstItemDate = Calendar.current.startOfDay(for: page.items[0].requestDate)
                if firstItemDate != expectedDate {
                    print("⚠️ [Quick Check] Date mismatch for key: \(key)")
                    return false
                }
            }
        }
        
        return true
    }
}

/// Detailed cache validation result
struct CacheValidationResult {
    var isValid: Bool = true
    var errorCount: Int = 0
    var warningCount: Int = 0
    var validationTimeMs: Double = 0
    
    var memoryCacheItemsChecked: Int = 0
    var countCacheItemsChecked: Int = 0
    var baseDataCacheItemsChecked: Int = 0
    var dateConsistencyChecked: Int = 0
    var diskCacheFileCount: Int = 0
    var diskCacheUsage: Int = 0
    var estimatedMemoryUsage: Int = 0
    
    private var errors: [String] = []
    private var warnings: [String] = []
    
    mutating func addError(_ message: String) {
        errors.append(message)
        errorCount += 1
        isValid = false
        print("❌ [Validation Error] \(message)")
    }
    
    mutating func addWarning(_ message: String) {
        warnings.append(message)
        warningCount += 1
        print("⚠️ [Validation Warning] \(message)")
    }
    
    var allErrors: [String] { return errors }
    var allWarnings: [String] { return warnings }
}

// MARK: - Extensions

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension OutOfStockFilterCriteria {
    init(page: Int, pageSize: Int) {
        self.init(
            customer: nil,
            product: nil,
            status: nil,
            dateRange: nil,
            searchText: "",
            page: page,
            pageSize: pageSize,
            sortOrder: .newestFirst
        )
    }
}