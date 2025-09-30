//
//  ThreeTierCacheStrategy.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Phase 2: Repository Optimization - Intelligent three-tier caching
//

import Foundation

// MARK: - Cache Configuration

private struct CacheConfig {
    // L1: Memory cache
    static let l1MaxItems = 50
    static let l1TTLSeconds: TimeInterval = 300 // 5 minutes

    // L2: Disk cache
    static let l2MaxItems = 500
    static let l2TTLSeconds: TimeInterval = 86400 // 24 hours

    // Cache eviction
    static let l1EvictionThreshold = 0.8 // Evict when 80% full
    static let l2EvictionThreshold = 0.9 // Evict when 90% full
}

// MARK: - Three-Tier Cache Strategy

/// Intelligent three-tier caching system for CustomerOutOfStock data
/// - L1: In-memory NSCache (fast, volatile, 50 items, 5-min TTL)
/// - L2: On-disk FileManager (persistent, 500 items, 24-hour TTL)
/// - L3: Cloud fallback (authoritative source)
@MainActor
public final class ThreeTierCacheStrategy<T: Codable> {

    // MARK: - Cache Layers

    private let l1Cache: NSCache<NSString, CachedItemWrapper<T>> // L1: Memory
    private let l2CacheDirectory: URL // L2: Disk
    private let cacheKeyPrefix: String

    // MARK: - Statistics

    private var l1Hits: Int = 0
    private var l1Misses: Int = 0
    private var l2Hits: Int = 0
    private var l2Misses: Int = 0
    private var cloudFetches: Int = 0

    // MARK: - Initialization

    public init(cacheKeyPrefix: String) {
        self.cacheKeyPrefix = cacheKeyPrefix

        // Initialize L1 cache
        self.l1Cache = NSCache<NSString, CachedItemWrapper<T>>()
        self.l1Cache.countLimit = CacheConfig.l1MaxItems
        self.l1Cache.totalCostLimit = 10 * 1024 * 1024 // 10MB memory limit

        // Initialize L2 cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.l2CacheDirectory = cacheDir.appendingPathComponent("Lopan/\(cacheKeyPrefix)")

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: l2CacheDirectory, withIntermediateDirectories: true)

        print("🗄️ ThreeTierCache[\(cacheKeyPrefix)]: Initialized (L1: \(CacheConfig.l1MaxItems) items, L2: \(l2CacheDirectory.path))")
    }

    // MARK: - Public API

    /// Retrieve item from cache (L1 → L2 → L3)
    public func get(key: String, cloudFetch: (() async throws -> T)? = nil) async throws -> T? {
        // Try L1 (memory)
        if let item = getFromL1(key: key) {
            l1Hits += 1
            print("✅ L1 HIT: \(key)")
            return item
        }
        l1Misses += 1

        // Try L2 (disk)
        if let item = try? await getFromL2(key: key) {
            l2Hits += 1
            print("✅ L2 HIT: \(key)")
            // Promote to L1
            await set(key: key, value: item, ttl: CacheConfig.l1TTLSeconds)
            return item
        }
        l2Misses += 1

        // Try L3 (cloud)
        if let cloudFetch = cloudFetch {
            cloudFetches += 1
            print("☁️ L3 FETCH: \(key)")
            let item = try await cloudFetch()
            // Cache in both layers
            await set(key: key, value: item, ttl: CacheConfig.l2TTLSeconds)
            return item
        }

        return nil
    }

    /// Store item in both L1 and L2 caches
    public func set(key: String, value: T, ttl: TimeInterval) async {
        let item = CachedItemWrapper(data: value, expiresAt: Date().addingTimeInterval(ttl))

        // Store in L1
        l1Cache.setObject(item, forKey: key as NSString)

        // Store in L2 asynchronously
        Task.detached {
            try? await self.saveToL2(key: key, item: item)
        }

        print("💾 CACHED: \(key) (TTL: \(Int(ttl))s)")
    }

    /// Invalidate specific cache entry
    public func invalidate(key: String) async {
        // Remove from L1
        l1Cache.removeObject(forKey: key as NSString)

        // Remove from L2
        let fileURL = l2FileURL(for: key)
        try? FileManager.default.removeItem(at: fileURL)

        print("🗑️ INVALIDATED: \(key)")
    }

    /// Clear all cache layers
    public func clearAll() async {
        // Clear L1
        l1Cache.removeAllObjects()

        // Clear L2
        try? FileManager.default.removeItem(at: l2CacheDirectory)
        try? FileManager.default.createDirectory(at: l2CacheDirectory, withIntermediateDirectories: true)

        // Reset stats
        l1Hits = 0
        l1Misses = 0
        l2Hits = 0
        l2Misses = 0
        cloudFetches = 0

        print("🧹 CLEARED: All cache layers")
    }

    /// Get cache statistics
    public func getStatistics() -> ThreeTierCacheStatistics {
        let l1HitRate = l1Hits + l1Misses > 0 ? Double(l1Hits) / Double(l1Hits + l1Misses) : 0
        let l2HitRate = l2Hits + l2Misses > 0 ? Double(l2Hits) / Double(l2Hits + l2Misses) : 0
        let overallHitRate = (l1Hits + l2Hits) > 0 ? Double(l1Hits + l2Hits) / Double(l1Hits + l1Misses + l2Misses) : 0

        return ThreeTierCacheStatistics(
            l1Hits: l1Hits,
            l1Misses: l1Misses,
            l1HitRate: l1HitRate,
            l2Hits: l2Hits,
            l2Misses: l2Misses,
            l2HitRate: l2HitRate,
            cloudFetches: cloudFetches,
            overallHitRate: overallHitRate
        )
    }

    // MARK: - Private L1 Operations

    private func getFromL1(key: String) -> T? {
        guard let item = l1Cache.object(forKey: key as NSString) else {
            return nil
        }

        // Check expiration
        if item.isExpired {
            l1Cache.removeObject(forKey: key as NSString)
            return nil
        }

        return item.data
    }

    // MARK: - Private L2 Operations

    private func getFromL2(key: String) async throws -> T? {
        let fileURL = l2FileURL(for: key)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let item = try JSONDecoder().decode(CachedItemWrapper<T>.self, from: data)

        // Check expiration
        if item.isExpired {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        return item.data
    }

    private func saveToL2(key: String, item: CachedItemWrapper<T>) async throws {
        let fileURL = l2FileURL(for: key)
        let data = try JSONEncoder().encode(item)
        try data.write(to: fileURL, options: .atomic)
    }

    private func l2FileURL(for key: String) -> URL {
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
        return l2CacheDirectory.appendingPathComponent("\(sanitizedKey).json")
    }

    // MARK: - Eviction Strategy (LRU)

    public func evictOldEntriesIfNeeded() async {
        // L2 eviction: Remove files older than 24 hours
        guard let files = try? FileManager.default.contentsOfDirectory(at: l2CacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let now = Date()
        var removedCount = 0

        for fileURL in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let modDate = attributes[.modificationDate] as? Date,
               now.timeIntervalSince(modDate) > CacheConfig.l2TTLSeconds {
                try? FileManager.default.removeItem(at: fileURL)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            print("🧹 EVICTED: \(removedCount) expired L2 entries")
        }
    }
}

// MARK: - Supporting Types

// NSCache requires class types, so we use a wrapper class
private final class CachedItemWrapper<T: Codable>: Codable {
    let data: T
    let expiresAt: Date

    init(data: T, expiresAt: Date) {
        self.data = data
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        Date() > expiresAt
    }
}

public struct ThreeTierCacheStatistics {
    public let l1Hits: Int
    public let l1Misses: Int
    public let l1HitRate: Double
    public let l2Hits: Int
    public let l2Misses: Int
    public let l2HitRate: Double
    public let cloudFetches: Int
    public let overallHitRate: Double

    public var description: String {
        """
        📊 Cache Statistics:
        L1 (Memory): \(l1Hits) hits, \(l1Misses) misses (\(String(format: "%.1f%%", l1HitRate * 100)))
        L2 (Disk):   \(l2Hits) hits, \(l2Misses) misses (\(String(format: "%.1f%%", l2HitRate * 100)))
        L3 (Cloud):  \(cloudFetches) fetches
        Overall:     \(String(format: "%.1f%%", overallHitRate * 100)) hit rate
        """
    }
}