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
        self.date = Calendar.current.startOfDay(for: date)
        self.page = page
        self.pageSize = criteria.pageSize
        
        // Create a comprehensive hash from filter criteria
        var hasher = Hasher()
        hasher.combine(criteria.customer?.id)
        hasher.combine(criteria.product?.id)
        hasher.combine(criteria.status?.rawValue)
        hasher.combine(criteria.searchText)
        hasher.combine(criteria.sortOrder.rawValue)
        
        if let dateRange = criteria.dateRange {
            hasher.combine(dateRange.start)
            hasher.combine(dateRange.end)
        }
        
        self.filterHash = String(hasher.finalize())
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
    let totalMisses: Int
    let memorySize: Int
    let diskSize: Int
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
    
    // MARK: - Performance Metrics
    
    @Published private var memoryHits = 0
    @Published private var diskHits = 0
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
    
    func getCachedPage(for key: OutOfStockCacheKey) async -> CachedOutOfStockPage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let accessTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            recordAccessTime(accessTime)
        }
        
        // Level 1: Memory Cache Check (Fastest)
        if let page = getFromMemoryCache(key) {
            memoryHits += 1
            return page
        }
        
        // Level 2: Disk Cache Check (Fast)
        if let page = await getFromDiskCache(key) {
            // Promote to memory cache
            addToMemoryCache(page, for: key)
            diskHits += 1
            return page
        }
        
        // Level 3: Cache Miss - will be handled by repository layer
        totalMisses += 1
        return nil
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
        if let date = date, let filterHash = filterHash {
            // Remove specific date/filter combination
            await removeFromCaches { key in
                key.date == Calendar.current.startOfDay(for: date) && key.filterHash == filterHash
            }
        } else if let date = date {
            // Remove all entries for specific date
            await removeFromCaches { key in
                key.date == Calendar.current.startOfDay(for: date)
            }
        } else if let filterHash = filterHash {
            // Remove all entries with specific filter
            await removeFromCaches { key in
                key.filterHash == filterHash
            }
        } else {
            // Clear all caches
            await clearAllCaches()
        }
    }
    
    func clearAllCaches() async {
        let memoryCount = memoryCache.count
        
        // Clear memory
        memoryCache.removeAll()
        memoryAccessOrder.removeAll()
        
        // Clear disk cache asynchronously
        await clearDiskCache()
        
        print("🧹 Cleared all caches: \(memoryCount) memory pages removed")
    }
    
    func getOutOfStockCacheStatistics() async -> OutOfStockCacheStatistics {
        let totalRequests = memoryHits + diskHits + totalMisses
        let hitRate = totalRequests > 0 ? Double(memoryHits + diskHits) / Double(totalRequests) : 0.0
        
        let memoryUsage = memoryCache.values.reduce(0) { $0 + $1.estimatedSizeInBytes }
        let diskUsage = await calculateDiskUsage()
        let avgAccessTime = accessTimes.isEmpty ? 0.0 : accessTimes.reduce(0, +) / Double(accessTimes.count)
        
        return OutOfStockCacheStatistics(
            memoryHits: memoryHits,
            diskHits: diskHits,
            totalMisses: totalMisses,
            memorySize: memoryCache.count,
            diskSize: await countDiskCacheFiles(),
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