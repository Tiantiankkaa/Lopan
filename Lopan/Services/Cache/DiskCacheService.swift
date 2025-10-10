//
//  DiskCacheService.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  SQLite-based persistent disk cache with automatic cleanup
//

import Foundation
import SQLite3
import os

// MARK: - Disk Cache Service Protocol

/// Persistent disk cache using SQLite for cross-launch data retention
@MainActor
protocol DiskCacheServiceProtocol {
    func save<T: Codable>(_ data: T, key: String, ttl: TimeInterval) async throws
    func get<T: Codable>(_ key: String, type: T.Type) async throws -> CacheEntry<T>?
    func remove(_ key: String) async throws
    func clear() async throws
    func cleanup() async throws // Remove expired entries
    func getStatistics() async -> DiskCacheStatistics
}

// MARK: - Disk Cache Statistics

public struct DiskCacheStatistics {
    let totalEntries: Int
    let totalSizeBytes: Int
    let oldestEntryDate: Date?
    let newestEntryDate: Date?
    let expiredEntries: Int
}

// MARK: - Disk Cache Error

enum DiskCacheError: Error, LocalizedError {
    case databaseNotOpen
    case serializationFailed
    case deserializationFailed
    case sqliteError(String)
    case entryNotFound
    case diskFull

    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Database is not open"
        case .serializationFailed:
            return "Failed to serialize data"
        case .deserializationFailed:
            return "Failed to deserialize data"
        case .sqliteError(let message):
            return "SQLite error: \(message)"
        case .entryNotFound:
            return "Cache entry not found"
        case .diskFull:
            return "Disk cache is full"
        }
    }
}

// MARK: - Disk Cache Service Implementation

@MainActor
final class DiskCacheService: DiskCacheServiceProtocol {

    // MARK: - Properties

    nonisolated(unsafe) private var db: OpaquePointer?
    private let dbPath: String
    private let maxCacheSizeBytes: Int
    private let logger = Logger(subsystem: "com.lopan.app", category: "DiskCacheService")

    // Performance tracking
    private var hits: Int = 0
    private var misses: Int = 0
    private var writes: Int = 0

    // MARK: - Constants

    private static let defaultMaxCacheSize = 100 * 1024 * 1024 // 100MB
    private static let tableName = "cache_entries"

    // MARK: - Initialization

    init(maxCacheSizeBytes: Int = DiskCacheService.defaultMaxCacheSize) throws {
        self.maxCacheSizeBytes = maxCacheSizeBytes

        // Get cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dbDir = cacheDir.appendingPathComponent("LopanDiskCache", isDirectory: true)

        // Create directory if needed
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        self.dbPath = dbDir.appendingPathComponent("cache.sqlite").path

        // Open database
        try openDatabase()
        try createTableIfNeeded()

        logger.info("💾 DiskCacheService initialized at \(self.dbPath)")
        logger.info("💾 Max cache size: \(maxCacheSizeBytes / 1024 / 1024)MB")
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Management

    private func openDatabase() throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(dbPath, &db, flags, nil)

        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to open database: \(errorMessage)")
        }

        // Enable WAL mode for better concurrency
        try execute("PRAGMA journal_mode=WAL")

        // Enable auto-vacuum to reclaim space
        try execute("PRAGMA auto_vacuum=INCREMENTAL")
    }

    nonisolated private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func createTableIfNeeded() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(Self.tableName) (
            key TEXT PRIMARY KEY NOT NULL,
            data BLOB NOT NULL,
            cached_at REAL NOT NULL,
            ttl REAL NOT NULL,
            size_bytes INTEGER NOT NULL,
            metadata TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_cached_at ON \(Self.tableName)(cached_at);
        CREATE INDEX IF NOT EXISTS idx_ttl ON \(Self.tableName)(ttl);
        """

        try execute(createTableSQL)
    }

    private func execute(_ sql: String) throws {
        guard let db = db else {
            throw DiskCacheError.databaseNotOpen
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)

        if result != SQLITE_OK {
            let message = errorMessage != nil ? String(cString: errorMessage!) : "Unknown error"
            sqlite3_free(errorMessage)
            throw DiskCacheError.sqliteError(message)
        }
    }

    // MARK: - Cache Operations

    func save<T: Codable>(_ data: T, key: String, ttl: TimeInterval) async throws {
        guard let db = db else {
            throw DiskCacheError.databaseNotOpen
        }

        // Check if adding this entry would exceed max size
        let stats = await getStatistics()
        if stats.totalSizeBytes > maxCacheSizeBytes {
            // Perform cleanup
            try await cleanup()

            // Check again
            let newStats = await getStatistics()
            if newStats.totalSizeBytes > maxCacheSizeBytes {
                throw DiskCacheError.diskFull
            }
        }

        // Serialize data
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(data) else {
            throw DiskCacheError.serializationFailed
        }

        let cachedAt = Date().timeIntervalSince1970
        let sizeBytes = jsonData.count

        // Prepare insert/replace statement
        let sql = """
        INSERT OR REPLACE INTO \(Self.tableName)
        (key, data, cached_at, ttl, size_bytes, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to prepare statement: \(errorMessage)")
        }

        // Bind parameters
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
        jsonData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(bytes.count), nil)
        }
        sqlite3_bind_double(statement, 3, cachedAt)
        sqlite3_bind_double(statement, 4, ttl)
        sqlite3_bind_int64(statement, 5, Int64(sizeBytes))
        sqlite3_bind_text(statement, 6, "disk", -1, nil)

        // Execute
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to execute: \(errorMessage)")
        }

        writes += 1
        logger.info("💾 Saved to disk cache: \(key) (\(sizeBytes) bytes, TTL: \(ttl)s)")
    }

    func get<T: Codable>(_ key: String, type: T.Type) async throws -> CacheEntry<T>? {
        guard let db = db else {
            throw DiskCacheError.databaseNotOpen
        }

        let sql = """
        SELECT data, cached_at, ttl, size_bytes
        FROM \(Self.tableName)
        WHERE key = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to prepare statement: \(errorMessage)")
        }

        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            // Extract data
            let blobPointer = sqlite3_column_blob(statement, 0)
            let blobSize = sqlite3_column_bytes(statement, 0)
            let cachedAt = sqlite3_column_double(statement, 1)
            let ttl = sqlite3_column_double(statement, 2)
            let sizeBytes = Int(sqlite3_column_int64(statement, 3))

            guard let blobPointer = blobPointer else {
                throw DiskCacheError.deserializationFailed
            }

            let jsonData = Data(bytes: blobPointer, count: Int(blobSize))

            // Deserialize
            let decoder = JSONDecoder()
            guard let data = try? decoder.decode(T.self, from: jsonData) else {
                throw DiskCacheError.deserializationFailed
            }

            // Create metadata
            let metadata = CacheMetadata(
                cachedAt: Date(timeIntervalSince1970: cachedAt),
                ttl: ttl,
                source: .disk,
                sizeBytes: sizeBytes,
                cacheKey: key
            )

            hits += 1
            logger.info("💾 Disk cache HIT: \(key) (age: \(String(format: "%.1f", metadata.age))s)")

            return CacheEntry(data: data, metadata: metadata)
        }

        misses += 1
        logger.info("💾 Disk cache MISS: \(key)")
        return nil
    }

    func remove(_ key: String) async throws {
        guard let db = db else {
            throw DiskCacheError.databaseNotOpen
        }

        let sql = "DELETE FROM \(Self.tableName) WHERE key = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to prepare statement: \(errorMessage)")
        }

        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to execute: \(errorMessage)")
        }

        logger.info("💾 Removed from disk cache: \(key)")
    }

    func clear() async throws {
        try execute("DELETE FROM \(Self.tableName)")
        try execute("VACUUM")
        logger.info("💾 Disk cache cleared")
    }

    func cleanup() async throws {
        guard let db = db else {
            throw DiskCacheError.databaseNotOpen
        }

        let now = Date().timeIntervalSince1970

        // Delete expired entries
        let sql = """
        DELETE FROM \(Self.tableName)
        WHERE (cached_at + ttl) < ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to prepare statement: \(errorMessage)")
        }

        sqlite3_bind_double(statement, 1, now)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DiskCacheError.sqliteError("Failed to execute: \(errorMessage)")
        }

        let deletedCount = sqlite3_changes(db)

        // Reclaim space
        try execute("PRAGMA incremental_vacuum")

        logger.info("💾 Cleaned up \(deletedCount) expired entries from disk cache")
    }

    func getStatistics() async -> DiskCacheStatistics {
        guard let db = db else {
            return DiskCacheStatistics(
                totalEntries: 0,
                totalSizeBytes: 0,
                oldestEntryDate: nil,
                newestEntryDate: nil,
                expiredEntries: 0
            )
        }

        let statsSQL = """
        SELECT
            COUNT(*) as total_entries,
            SUM(size_bytes) as total_size,
            MIN(cached_at) as oldest,
            MAX(cached_at) as newest,
            SUM(CASE WHEN (cached_at + ttl) < ? THEN 1 ELSE 0 END) as expired
        FROM \(Self.tableName)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, statsSQL, -1, &statement, nil) == SQLITE_OK else {
            return DiskCacheStatistics(
                totalEntries: 0,
                totalSizeBytes: 0,
                oldestEntryDate: nil,
                newestEntryDate: nil,
                expiredEntries: 0
            )
        }

        let now = Date().timeIntervalSince1970
        sqlite3_bind_double(statement, 1, now)

        if sqlite3_step(statement) == SQLITE_ROW {
            let totalEntries = Int(sqlite3_column_int64(statement, 0))
            let totalSize = Int(sqlite3_column_int64(statement, 1))
            let oldest = sqlite3_column_double(statement, 2)
            let newest = sqlite3_column_double(statement, 3)
            let expired = Int(sqlite3_column_int64(statement, 4))

            return DiskCacheStatistics(
                totalEntries: totalEntries,
                totalSizeBytes: totalSize,
                oldestEntryDate: oldest > 0 ? Date(timeIntervalSince1970: oldest) : nil,
                newestEntryDate: newest > 0 ? Date(timeIntervalSince1970: newest) : nil,
                expiredEntries: expired
            )
        }

        return DiskCacheStatistics(
            totalEntries: 0,
            totalSizeBytes: 0,
            oldestEntryDate: nil,
            newestEntryDate: nil,
            expiredEntries: 0
        )
    }
}

// MARK: - Extensions

extension DiskCacheService {
    /// Get cache hit rate
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }

    /// Get cache summary for debugging
    func getSummary() async -> String {
        let stats = await getStatistics()
        return """
        Disk Cache Summary:
        - Entries: \(stats.totalEntries)
        - Size: \(stats.totalSizeBytes / 1024 / 1024)MB
        - Expired: \(stats.expiredEntries)
        - Hit Rate: \(String(format: "%.1f%%", hitRate * 100))
        - Writes: \(writes)
        """
    }
}
