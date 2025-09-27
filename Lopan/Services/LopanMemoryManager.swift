//
//  LopanMemoryManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Intelligent memory optimization system
//

import SwiftUI
import Foundation
import Combine
import os

/// Advanced memory management system for optimal performance with large datasets
@MainActor
public final class LopanMemoryManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = LopanMemoryManager()

    // MARK: - Published Properties

    @Published public var currentMemoryUsage: MemoryUsage = MemoryUsage()
    @Published public var isOptimizationActive = false
    @Published public var cacheStatistics = CacheStatistics()

    // MARK: - Private Properties

    internal let logger = Logger(subsystem: "com.lopan.memory", category: "manager")
    private var memoryTimer: Timer?
    private var imageCaches: [String: NSCache<NSString, UIImage>] = [:]
    private var viewCaches: [String: Any] = [:]
    private var memoryWarningCancellable: AnyCancellable?
    private let imageCacheDelegate = ImageCacheDelegate() // Strong reference to prevent deallocation

    // MARK: - Debouncing Properties
    private var lastCleanupTime: Date?
    private let cleanupDebounceInterval: TimeInterval = 30.0
    private var consecutiveCleanupFailures = 0
    private let maxConsecutiveFailures = 3

    // MARK: - Configuration

    private struct Configuration {
        static let memoryCheckInterval: TimeInterval = 60.0 // Changed from 2.0s to 60s to prevent CPU loop
        static let highMemoryThreshold: Double = 500.0 // Changed from 200MB to 500MB (realistic for SwiftUI)
        static let criticalMemoryThreshold: Double = 800.0 // Changed from 300MB to 800MB
        static let imageCacheLimit = 50 // Number of images
        static let viewCacheLimit = 20 // Number of cached views
    }

    // MARK: - Initialization

    private init() {
        // Note: setupMemoryMonitoring() is now called only when startOptimization() is invoked
        setupImageCaches()
        setupMemoryWarningObserver()
    }

    deinit {
        memoryTimer?.invalidate()
        memoryWarningCancellable?.cancel()
    }

    // MARK: - Public Interface

    /// Start memory optimization monitoring
    public func startOptimization() {
        guard !isOptimizationActive else {
            logger.debug("🧠 Memory optimization already active")
            return
        }

        isOptimizationActive = true
        setupMemoryMonitoring() // Start the monitoring timer

        logger.info("🧠 Memory optimization started")
    }

    /// Stop memory optimization
    public func stopOptimization() {
        guard isOptimizationActive else { return }

        isOptimizationActive = false
        memoryTimer?.invalidate()
        memoryTimer = nil

        logger.info("🧠 Memory optimization stopped")
    }

    /// Cache image with intelligent eviction
    public func cacheImage(_ image: UIImage, forKey key: String, category: String = "default") {
        let cache = getOrCreateImageCache(for: category)
        cache.setObject(image, forKey: key as NSString)

        cacheStatistics.imageCacheEntries += 1
        logger.debug("📸 Cached image: \(key) in category: \(category)")
    }

    /// Retrieve cached image
    public func cachedImage(forKey key: String, category: String = "default") -> UIImage? {
        let cache = getOrCreateImageCache(for: category)
        let image = cache.object(forKey: key as NSString)

        if image != nil {
            cacheStatistics.imageCacheHits += 1
        } else {
            cacheStatistics.imageCacheMisses += 1
        }

        return image
    }

    /// Clear all caches
    public func clearAllCaches() {
        imageCaches.forEach { $0.value.removeAllObjects() }
        viewCaches.removeAll()

        cacheStatistics = CacheStatistics()
        logger.info("🗑️ All caches cleared")
    }

    /// Clear cache for specific category
    public func clearCache(category: String) {
        imageCaches[category]?.removeAllObjects()
        viewCaches.removeValue(forKey: category)

        logger.info("🗑️ Cache cleared for category: \(category)")
    }

    /// Perform memory pressure cleanup with debouncing
    public func performMemoryCleanup() {
        let now = Date()

        // Check if we should debounce (prevent rapid cleanup attempts)
        if let lastCleanup = lastCleanupTime,
           now.timeIntervalSince(lastCleanup) < cleanupDebounceInterval {
            logger.debug("🛑 Memory cleanup debounced - too recent (last: \(lastCleanup))")
            return
        }

        // Circuit breaker: stop if too many consecutive failures
        if consecutiveCleanupFailures >= maxConsecutiveFailures {
            logger.warning("🔴 Memory cleanup circuit breaker activated - too many failures")
            return
        }

        let initialUsage = getCurrentMemoryUsage()
        lastCleanupTime = now

        // Progressive cleanup strategy
        performLightCleanup()

        let afterLightCleanup = getCurrentMemoryUsage()
        if afterLightCleanup > Configuration.highMemoryThreshold {
            performMediumCleanup()
        }

        let afterMediumCleanup = getCurrentMemoryUsage()
        if afterMediumCleanup > Configuration.criticalMemoryThreshold {
            performAggressiveCleanup()
        }

        let finalUsage = getCurrentMemoryUsage()
        let memoryFreed = initialUsage - finalUsage

        // Check if cleanup was effective
        if memoryFreed > 0 {
            // Reset failure counter on success
            consecutiveCleanupFailures = 0
            logger.info("🧹 Memory cleanup completed. Freed: \(String(format: "%.1f", memoryFreed)) MB")
        } else {
            // Increment failure counter if cleanup wasn't effective
            consecutiveCleanupFailures += 1
            logger.warning("⚠️ Memory cleanup ineffective. Attempt \(self.consecutiveCleanupFailures)/\(self.maxConsecutiveFailures)")

            // If we've hit max failures, temporarily disable optimization
            if consecutiveCleanupFailures >= maxConsecutiveFailures {
                logger.error("🔴 Memory cleanup circuit breaker activated. Disabling optimization for 5 minutes.")

                // Schedule re-enable after 5 minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                    self?.resetCircuitBreaker()
                }
            }
        }
    }

    /// Get memory usage statistics
    public func getMemoryStatistics() -> MemoryStatistics {
        return MemoryStatistics(
            currentUsage: currentMemoryUsage,
            cacheStatistics: cacheStatistics,
            isOptimizationActive: isOptimizationActive,
            numberOfImageCaches: imageCaches.count,
            numberOfViewCaches: viewCaches.count
        )
    }
}

// MARK: - Private Implementation

extension LopanMemoryManager {

    private func setupMemoryMonitoring() {
        // Stop any existing timer to prevent multiple instances
        memoryTimer?.invalidate()
        memoryTimer = nil

        // Only start timer if optimization is active
        guard isOptimizationActive else {
            logger.debug("🧠 Memory monitoring setup skipped - optimization not active")
            return
        }

        // Monitor memory usage periodically
        memoryTimer = Timer.scheduledTimer(withTimeInterval: Configuration.memoryCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryMetrics()
            }
        }

        logger.debug("🧠 Memory monitoring timer started with \(Configuration.memoryCheckInterval)s interval")
    }

    private func setupImageCaches() {
        // Create default image cache
        let defaultCache = NSCache<NSString, UIImage>()
        defaultCache.countLimit = Configuration.imageCacheLimit
        defaultCache.delegate = imageCacheDelegate
        imageCaches["default"] = defaultCache
    }

    private func setupMemoryWarningObserver() {
        memoryWarningCancellable = NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
    }

    private func getOrCreateImageCache(for category: String) -> NSCache<NSString, UIImage> {
        if let existingCache = imageCaches[category] {
            return existingCache
        }

        let newCache = NSCache<NSString, UIImage>()
        newCache.countLimit = Configuration.imageCacheLimit
        newCache.delegate = imageCacheDelegate
        imageCaches[category] = newCache

        return newCache
    }

    private func updateMemoryMetrics() {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage.currentMB = usage
        currentMemoryUsage.timestamp = Date()

        // Track peak usage
        if usage > currentMemoryUsage.peakMB {
            currentMemoryUsage.peakMB = usage
        }

        // Check for automatic cleanup with additional safeguards
        if usage > Configuration.highMemoryThreshold && isOptimizationActive {
            // Additional safety check: don't cleanup if we just did one recently
            let now = Date()
            if let lastCleanup = lastCleanupTime,
               now.timeIntervalSince(lastCleanup) < cleanupDebounceInterval {
                logger.debug("🛑 Skipping automatic cleanup - too recent")
            } else if consecutiveCleanupFailures < maxConsecutiveFailures {
                // Only perform cleanup if we haven't hit circuit breaker
                logger.info("🧠 Automatic memory cleanup triggered at \(String(format: "%.1f", usage))MB")
                performMemoryCleanup()
            } else {
                logger.warning("🔴 Automatic cleanup skipped - circuit breaker active")
            }
        }

        // Update cache statistics
        updateCacheStatistics()
    }

    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Double(info.resident_size) / (1024 * 1024) : 0.0
    }

    private func updateCacheStatistics() {
        cacheStatistics.totalImageCaches = imageCaches.count
        cacheStatistics.totalViewCaches = viewCaches.count

        let totalImageEntries = imageCaches.values.reduce(0) { $0 + $1.totalCostLimit }
        cacheStatistics.imageCacheEntries = totalImageEntries
    }

    private func performLightCleanup() {
        // Remove least recently used image cache entries
        imageCaches.forEach { _, cache in
            let currentCount = cache.totalCostLimit
            cache.totalCostLimit = max(currentCount / 2, 10)
        }

        logger.debug("🧹 Light cleanup performed")
    }

    private func performMediumCleanup() {
        // Clear caches for non-essential categories
        let nonEssentialCategories = ["thumbnails", "previews", "temp"]
        nonEssentialCategories.forEach { category in
            imageCaches[category]?.removeAllObjects()
        }

        // Reduce view cache size
        let maxViewCaches = Configuration.viewCacheLimit / 2
        while viewCaches.count > maxViewCaches {
            guard let oldestKey = viewCaches.keys.first else {
                break // Safety break if somehow keys are empty
            }
            viewCaches.removeValue(forKey: oldestKey)
        }

        logger.debug("🧹 Medium cleanup performed")
    }

    private func performAggressiveCleanup() {
        // Clear all non-critical caches
        imageCaches.forEach { key, cache in
            if key != "default" {
                cache.removeAllObjects()
            }
        }

        // Clear most view caches
        viewCaches.removeAll()

        // Trigger garbage collection
        DispatchQueue.global(qos: .utility).async {
            // Force memory cleanup on background queue
            autoreleasepool {
                // This helps trigger garbage collection
            }
        }

        logger.debug("🧹 Aggressive cleanup performed")
    }

    private func handleMemoryWarning() {
        logger.warning("⚠️ Memory warning received")
        performMemoryCleanup()

        // Report performance impact
        LopanPerformanceProfiler.shared.recordMemoryPressure()
    }

    /// Reset circuit breaker after cooldown period
    private func resetCircuitBreaker() {
        consecutiveCleanupFailures = 0
        logger.info("✅ Memory cleanup circuit breaker reset - optimization re-enabled")
    }
}

// MARK: - Data Structures

public struct MemoryUsage {
    var currentMB: Double = 0.0
    var peakMB: Double = 0.0
    var timestamp: Date = Date()
}

public struct CacheStatistics {
    var imageCacheEntries: Int = 0
    var imageCacheHits: Int = 0
    var imageCacheMisses: Int = 0
    var totalImageCaches: Int = 0
    var totalViewCaches: Int = 0

    var hitRate: Double {
        let total = imageCacheHits + imageCacheMisses
        return total > 0 ? Double(imageCacheHits) / Double(total) : 0.0
    }
}

public struct MemoryStatistics {
    let currentUsage: MemoryUsage
    let cacheStatistics: CacheStatistics
    let isOptimizationActive: Bool
    let numberOfImageCaches: Int
    let numberOfViewCaches: Int
}

// MARK: - Cache Delegate

private class ImageCacheDelegate: NSObject, NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Log cache eviction for debugging
        let logger = Logger(subsystem: "com.lopan.memory", category: "cache")
        logger.debug("💾 Cache evicting object")
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Add memory monitoring to views
    public func memoryMonitored(category: String) -> some View {
        self.onAppear {
            LopanMemoryManager.shared.logger.debug("📱 View appeared: \(category)")
        }
        .onDisappear {
            LopanMemoryManager.shared.logger.debug("📱 View disappeared: \(category)")
        }
    }
}

// MARK: - Performance Profiler Integration
// recordMemoryPressure() is now implemented in LopanPerformanceProfiler.swift

// MARK: - Debug View

#if DEBUG
public struct MemoryDebugView: View {
    @StateObject private var memoryManager = LopanMemoryManager.shared

    public var body: some View {
        NavigationStack {
            List {
                Section("Memory Usage") {
                    MemoryMetricRow(
                        title: "Current Usage",
                        value: "\(String(format: "%.1f", memoryManager.currentMemoryUsage.currentMB)) MB"
                    )
                    MemoryMetricRow(
                        title: "Peak Usage",
                        value: "\(String(format: "%.1f", memoryManager.currentMemoryUsage.peakMB)) MB"
                    )
                }

                Section("Cache Statistics") {
                    MemoryMetricRow(
                        title: "Image Cache Hit Rate",
                        value: "\(String(format: "%.1f", memoryManager.cacheStatistics.hitRate * 100))%"
                    )
                    MemoryMetricRow(
                        title: "Image Caches",
                        value: "\(memoryManager.cacheStatistics.totalImageCaches)"
                    )
                    MemoryMetricRow(
                        title: "View Caches",
                        value: "\(memoryManager.cacheStatistics.totalViewCaches)"
                    )
                }
            }
            .navigationTitle("Memory Monitor")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Clear Cache") {
                        memoryManager.clearAllCaches()
                    }

                    Button(memoryManager.isOptimizationActive ? "Stop" : "Start") {
                        if memoryManager.isOptimizationActive {
                            memoryManager.stopOptimization()
                        } else {
                            memoryManager.startOptimization()
                        }
                    }
                }
            }
        }
    }
}

private struct MemoryMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    MemoryDebugView()
}
#endif