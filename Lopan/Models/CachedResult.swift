//
//  CachedResult.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Cache state management model for stale-while-revalidate pattern
//

import Foundation

// MARK: - Cached Result

/// Represents the result of a cache lookup with freshness information
/// Supports stale-while-revalidate pattern for instant UI updates
public enum CachedResult<T> {
    /// Fresh data from network, cache has been updated
    case fresh(T, metadata: CacheMetadata)

    /// Stale data from cache, background refresh triggered
    case stale(T, metadata: CacheMetadata)

    /// First load with no cache available
    case loading

    /// Cache miss, fetching from network
    case fetching

    /// Error occurred during fetch
    case error(Error, cachedFallback: T?)
}

// MARK: - Cache Metadata

/// Metadata about cached data
public struct CacheMetadata: Codable {
    /// When the data was originally cached
    public let cachedAt: Date

    /// Time-to-live in seconds
    public let ttl: TimeInterval

    /// Cache layer that provided this data (memory, disk, network)
    public let source: CacheSource

    /// Size of cached data in bytes (approximate)
    public let sizeBytes: Int

    /// Unique cache key
    public let cacheKey: String

    /// Whether this data is expired based on TTL
    public var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }

    /// How old is this cached data
    public var age: TimeInterval {
        Date().timeIntervalSince(cachedAt)
    }

    /// Percentage of TTL elapsed (0.0 to 1.0+)
    public var freshnessRatio: Double {
        age / ttl
    }

    public init(
        cachedAt: Date,
        ttl: TimeInterval,
        source: CacheSource,
        sizeBytes: Int,
        cacheKey: String
    ) {
        self.cachedAt = cachedAt
        self.ttl = ttl
        self.source = source
        self.sizeBytes = sizeBytes
        self.cacheKey = cacheKey
    }
}

// MARK: - Cache Source

/// Identifies which cache layer provided the data
public enum CacheSource: String, Codable {
    case memory    // L1: In-memory cache (fastest)
    case disk      // L2: SQLite persistent cache
    case network   // L3: Fresh from API
    case prefetch  // Prefetched data

    public var displayName: String {
        switch self {
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .network: return "Network"
        case .prefetch: return "Prefetched"
        }
    }

    public var priority: Int {
        switch self {
        case .memory: return 1
        case .disk: return 2
        case .prefetch: return 3
        case .network: return 4
        }
    }
}

// MARK: - CachedResult Extensions

extension CachedResult {
    /// Extract the data if available, regardless of freshness
    public var data: T? {
        switch self {
        case .fresh(let data, _):
            return data
        case .stale(let data, _):
            return data
        case .loading, .fetching:
            return nil
        case .error(_, let fallback):
            return fallback
        }
    }

    /// Check if this result contains data (fresh or stale)
    public var hasData: Bool {
        data != nil
    }

    /// Check if data is fresh
    public var isFresh: Bool {
        if case .fresh = self {
            return true
        }
        return false
    }

    /// Check if data is stale
    public var isStale: Bool {
        if case .stale = self {
            return true
        }
        return false
    }

    /// Check if currently loading
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Check if currently fetching
    public var isFetching: Bool {
        if case .fetching = self {
            return true
        }
        return false
    }

    /// Get cache metadata if available
    public var metadata: CacheMetadata? {
        switch self {
        case .fresh(_, let metadata), .stale(_, let metadata):
            return metadata
        default:
            return nil
        }
    }

    /// Get cache source if available
    public var source: CacheSource? {
        metadata?.source
    }

    /// Map the wrapped data to a new type
    public func map<U>(_ transform: (T) -> U) -> CachedResult<U> {
        switch self {
        case .fresh(let data, let metadata):
            return .fresh(transform(data), metadata: metadata)
        case .stale(let data, let metadata):
            return .stale(transform(data), metadata: metadata)
        case .loading:
            return .loading
        case .fetching:
            return .fetching
        case .error(let error, let fallback):
            return .error(error, cachedFallback: fallback.map(transform))
        }
    }
}

// MARK: - Equatable (when T is Equatable)

extension CachedResult: Equatable where T: Equatable {
    public static func == (lhs: CachedResult<T>, rhs: CachedResult<T>) -> Bool {
        switch (lhs, rhs) {
        case (.fresh(let lData, let lMeta), .fresh(let rData, let rMeta)):
            return lData == rData && lMeta.cacheKey == rMeta.cacheKey
        case (.stale(let lData, let lMeta), .stale(let rData, let rMeta)):
            return lData == rData && lMeta.cacheKey == rMeta.cacheKey
        case (.loading, .loading):
            return true
        case (.fetching, .fetching):
            return true
        case (.error(_, let lFallback), .error(_, let rFallback)):
            return lFallback == rFallback
        default:
            return false
        }
    }
}

// MARK: - Cache Entry

/// Internal wrapper for storing data in cache with metadata
struct CacheEntry<T: Codable>: Codable {
    let data: T
    let metadata: CacheMetadata

    var isExpired: Bool {
        metadata.isExpired
    }

    var isStale: Bool {
        // Consider stale if > 50% of TTL has elapsed
        metadata.freshnessRatio > 0.5
    }
}
