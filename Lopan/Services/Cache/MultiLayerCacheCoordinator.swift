//
//  MultiLayerCacheCoordinator.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Orchestrates multi-layer caching with stale-while-revalidate pattern
//  L0: Request Deduplication → L1: Memory → L2: Disk → Network
//

import Foundation
import os

// MARK: - Multi-Layer Cache Coordinator Protocol

/// Coordinates caching across multiple layers with intelligent fallback
@MainActor
protocol MultiLayerCacheCoordinatorProtocol {
    func get<T: Codable>(
        key: String,
        type: T.Type,
        freshFetch: @escaping @Sendable () async throws -> T,
        memoryTTL: TimeInterval,
        diskTTL: TimeInterval
    ) async -> CachedResult<T>

    func set<T: Codable>(_ data: T, key: String, memoryTTL: TimeInterval, diskTTL: TimeInterval) async

    func invalidate(key: String) async
    func invalidateAll() async
    func getLayerStatistics() async -> MultiLayerStatistics
}

// MARK: - Multi-Layer Statistics

public struct MultiLayerStatistics {
    let memoryHits: Int
    let memoryMisses: Int
    let diskHits: Int
    let diskMisses: Int
    let networkFetches: Int
    let deduplicationRate: Double
    let averageResponseTime: TimeInterval

    var totalHits: Int { memoryHits + diskHits }
    var totalMisses: Int { memoryMisses + diskMisses }
    var overallHitRate: Double {
        let total = totalHits + totalMisses
        guard total > 0 else { return 0 }
        return Double(totalHits) / Double(total)
    }
}

// MARK: - Multi-Layer Cache Coordinator Implementation

@MainActor
final class MultiLayerCacheCoordinator: MultiLayerCacheCoordinatorProtocol {

    // MARK: - Properties

    private let memoryCache: NSCache<NSString, AnyCacheWrapper>
    private let diskCache: DiskCacheService
    private let deduplicator: RequestDeduplicator
    private let logger = Logger(subsystem: "com.lopan.app", category: "MultiLayerCache")

    // Performance tracking
    private var memoryHits: Int = 0
    private var memoryMisses: Int = 0
    private var diskHits: Int = 0
    private var diskMisses: Int = 0
    private var networkFetches: Int = 0
    private var responseTimes: [TimeInterval] = []

    // MARK: - Initialization

    init(
        diskCache: DiskCacheService,
        memoryCacheCountLimit: Int = 200
    ) {
        self.diskCache = diskCache
        self.deduplicator = RequestDeduplicator()

        self.memoryCache = NSCache()
        self.memoryCache.countLimit = memoryCacheCountLimit
        self.memoryCache.totalCostLimit = 25 * 1024 * 1024 // 25MB

        logger.info("🎯 MultiLayerCacheCoordinator initialized")
        logger.info("   Memory limit: \(memoryCacheCountLimit) items, 25MB")
    }

    // MARK: - Cache Operations with Stale-While-Revalidate

    func get<T: Codable>(
        key: String,
        type: T.Type,
        freshFetch: @escaping @Sendable () async throws -> T,
        memoryTTL: TimeInterval = 300,  // 5 minutes
        diskTTL: TimeInterval = 86400   // 24 hours
    ) async -> CachedResult<T> {
        let startTime = Date()

        // L1: Check memory cache
        if let entry = getFromMemory(key: key, type: type) {
            memoryHits += 1
            trackResponseTime(Date().timeIntervalSince(startTime))

            if entry.isExpired {
                logger.info("📦 Memory HIT (STALE): \(key) - triggering background refresh")

                // Return stale data immediately, refresh in background
                Task.detached(priority: .background) {
                    await self.backgroundRefresh(key: key, freshFetch: freshFetch, memoryTTL: memoryTTL, diskTTL: diskTTL)
                }

                return .stale(entry.data, metadata: entry.metadata)
            } else {
                logger.info("📦 Memory HIT (FRESH): \(key)")
                return .fresh(entry.data, metadata: entry.metadata)
            }
        }
        memoryMisses += 1

        // L2: Check disk cache
        if let entry = try? await diskCache.get(key, type: type) {
            diskHits += 1
            trackResponseTime(Date().timeIntervalSince(startTime))

            // Populate memory cache
            saveToMemory(entry, key: key)

            if entry.isExpired {
                logger.info("💾 Disk HIT (STALE): \(key) - triggering background refresh")

                // Return stale data immediately, refresh in background
                Task.detached(priority: .background) {
                    await self.backgroundRefresh(key: key, freshFetch: freshFetch, memoryTTL: memoryTTL, diskTTL: diskTTL)
                }

                return .stale(entry.data, metadata: entry.metadata)
            } else {
                logger.info("💾 Disk HIT (FRESH): \(key)")
                return .fresh(entry.data, metadata: entry.metadata)
            }
        }
        diskMisses += 1

        // L3: Fetch from network (with deduplication)
        logger.info("🌐 Cache MISS: \(key) - fetching from network")

        do {
            let data = try await deduplicator.deduplicate(key: key, fetch: freshFetch)
            networkFetches += 1
            trackResponseTime(Date().timeIntervalSince(startTime))

            // Save to all cache layers
            await set(data, key: key, memoryTTL: memoryTTL, diskTTL: diskTTL)

            let metadata = CacheMetadata(
                cachedAt: Date(),
                ttl: memoryTTL,
                source: .network,
                sizeBytes: 0,
                cacheKey: key
            )

            logger.info("✅ Network FETCH completed: \(key)")
            return .fresh(data, metadata: metadata)

        } catch {
            logger.error("❌ Network FETCH failed: \(key) - \(error.localizedDescription)")
            return .error(error, cachedFallback: nil)
        }
    }

    // MARK: - Background Refresh

    private func backgroundRefresh<T: Codable>(
        key: String,
        freshFetch: @Sendable () async throws -> T,
        memoryTTL: TimeInterval,
        diskTTL: TimeInterval
    ) async {
        logger.info("🔄 Background refresh started: \(key)")

        do {
            let freshData = try await freshFetch()
            await set(freshData, key: key, memoryTTL: memoryTTL, diskTTL: diskTTL)
            logger.info("✅ Background refresh completed: \(key)")
        } catch {
            logger.error("❌ Background refresh failed: \(key) - \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Writing

    func set<T: Codable>(
        _ data: T,
        key: String,
        memoryTTL: TimeInterval = 300,
        diskTTL: TimeInterval = 86400
    ) async {
        let metadata = CacheMetadata(
            cachedAt: Date(),
            ttl: memoryTTL,
            source: .memory,
            sizeBytes: 0,
            cacheKey: key
        )

        let entry = CacheEntry(data: data, metadata: metadata)

        // L1: Save to memory
        saveToMemory(entry, key: key)

        // L2: Save to disk (background)
        Task.detached(priority: .utility) {
            do {
                try await self.diskCache.save(data, key: key, ttl: diskTTL)
            } catch {
                self.logger.error("Failed to save to disk cache: \(key) - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Memory Cache Operations

    private func getFromMemory<T: Codable>(key: String, type: T.Type) -> CacheEntry<T>? {
        guard let wrapper = memoryCache.object(forKey: key as NSString) else {
            return nil
        }

        guard let entry = wrapper.entry as? CacheEntry<T> else {
            return nil
        }

        return entry
    }

    private func saveToMemory<T: Codable>(_ entry: CacheEntry<T>, key: String) {
        let wrapper = AnyCacheWrapper(entry: entry)
        memoryCache.setObject(wrapper, forKey: key as NSString)
    }

    // MARK: - Cache Invalidation

    func invalidate(key: String) async {
        // Remove from memory
        memoryCache.removeObject(forKey: key as NSString)

        // Remove from disk
        try? await diskCache.remove(key)

        // Cancel any in-flight requests
        deduplicator.invalidate(key: key)

        logger.info("🗑️ Invalidated cache: \(key)")
    }

    func invalidateAll() async {
        // Clear memory
        memoryCache.removeAllObjects()

        // Clear disk
        try? await diskCache.clear()

        // Cancel all in-flight requests
        deduplicator.invalidateAll()

        logger.info("🗑️ Invalidated all caches")
    }

    // MARK: - Statistics

    func getLayerStatistics() async -> MultiLayerStatistics {
        let deduplicationStats = deduplicator.getStatistics()
        let avgResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)

        return MultiLayerStatistics(
            memoryHits: memoryHits,
            memoryMisses: memoryMisses,
            diskHits: diskHits,
            diskMisses: diskMisses,
            networkFetches: networkFetches,
            deduplicationRate: deduplicationStats.deduplicationRate,
            averageResponseTime: avgResponseTime
        )
    }

    private func trackResponseTime(_ time: TimeInterval) {
        responseTimes.append(time)

        // Keep only last 100 measurements
        if responseTimes.count > 100 {
            responseTimes.removeFirst()
        }
    }

    // MARK: - Debugging

    func getSummary() async -> String {
        let stats = await getLayerStatistics()
        let diskStats = await diskCache.getStatistics()

        return """
        Multi-Layer Cache Summary:

        L1 (Memory):
        - Hits: \(stats.memoryHits)
        - Misses: \(stats.memoryMisses)
        - Hit Rate: \(String(format: "%.1f%%", Double(stats.memoryHits) / Double(stats.memoryHits + stats.memoryMisses) * 100))

        L2 (Disk):
        - Hits: \(stats.diskHits)
        - Misses: \(stats.diskMisses)
        - Size: \(diskStats.totalSizeBytes / 1024 / 1024)MB
        - Hit Rate: \(String(format: "%.1f%%", Double(stats.diskHits) / Double(stats.diskHits + stats.diskMisses) * 100))

        L3 (Network):
        - Fetches: \(stats.networkFetches)
        - Deduplication Rate: \(String(format: "%.1f%%", stats.deduplicationRate * 100))

        Overall:
        - Hit Rate: \(String(format: "%.1f%%", stats.overallHitRate * 100))
        - Avg Response: \(String(format: "%.3f", stats.averageResponseTime))s
        """
    }
}

// MARK: - Type-Erased Cache Wrapper

/// Wrapper to store any Codable type in NSCache
private class AnyCacheWrapper: NSObject {
    let entry: Any

    init<T: Codable>(entry: CacheEntry<T>) {
        self.entry = entry
    }
}
