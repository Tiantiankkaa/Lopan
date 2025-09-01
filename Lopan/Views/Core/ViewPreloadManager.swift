//
//  ViewPreloadManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import SwiftUI
import os

/// Core manager for preloading and caching SwiftUI views
/// Provides intelligent view preloading based on user patterns and system resources
@MainActor
public final class ViewPreloadManager: ObservableObject {
    
    // MARK: - Singleton Instance
    public static let shared = ViewPreloadManager()
    
    // MARK: - Cache Configuration
    
    private struct CacheConfig {
        static let maxCacheSize: Int = 20
        static let maxMemoryMB: Int = 15
        static let cleanupInterval: TimeInterval = 300 // 5 minutes
        static let memoryPressureThreshold: Double = 0.8
    }
    
    // MARK: - View Cache
    
    private var viewCache: [String: CachedView] = [:]
    private var accessHistory: [ViewAccess] = []
    private var cacheStatistics = CacheStatistics()
    
    private struct CachedView {
        let view: AnyView
        let createdAt: Date
        let lastAccessed: Date
        var accessCount: Int
        let viewType: String
        let estimatedMemoryMB: Double
        
        mutating func recordAccess() {
            accessCount += 1
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(lastAccessed) > 600 // 10 minutes
        }
    }
    
    public struct ViewAccess {
        let viewKey: String
        let accessTime: Date
        let context: AccessContext
        let userRole: String?
        
        public enum AccessContext: String {
            case navigation, tabSwitch, deepLink, search, manual
        }
    }
    
    // MARK: - Statistics
    
    public struct CacheStatistics {
        var hits: Int = 0
        var misses: Int = 0
        var evictions: Int = 0
        var totalMemoryMB: Double = 0
        var preloads: Int = 0
        
        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
        
        var efficiency: Double {
            return hitRate >= 0.8 ? 1.0 : hitRate / 0.8
        }
    }
    
    // MARK: - Performance Monitoring
    
    private let performanceLogger = Logger(subsystem: "com.lopan.views", category: "preload")
    private var cleanupTimer: Timer?
    private var memoryMonitor: MemoryMonitor?
    
    // MARK: - Integration with Predictive Engine
    
    private var predictiveEngine: PredictiveLoadingEngine?
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryMonitoring()
        startPeriodicCleanup()
        performanceLogger.info("🎬 ViewPreloadManager initialized")
    }
    
    private func setupMemoryMonitoring() {
        memoryMonitor = MemoryMonitor { [weak self] pressure in
            Task { @MainActor in
                await self?.handleMemoryPressure(pressure)
            }
        }
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: CacheConfig.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanup()
            }
        }
    }
    
    // MARK: - Public API
    
    /// Register a view for preloading
    public func registerView<T: View>(_ view: T, forKey key: String, context: ViewAccess.AccessContext = .manual) {
        let anyView = AnyView(view)
        let memoryEstimate = estimateMemoryUsage(for: view)
        
        let cachedView = CachedView(
            view: anyView,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 1,
            viewType: String(describing: T.self),
            estimatedMemoryMB: memoryEstimate
        )
        
        viewCache[key] = cachedView
        cacheStatistics.totalMemoryMB += memoryEstimate
        cacheStatistics.preloads += 1
        
        recordAccess(key: key, context: context)
        
        performanceLogger.info("🎬 Registered view: \(key) (\(String(format: "%.1f", memoryEstimate))MB)")
        
        // Trigger cleanup if needed
        if shouldPerformCleanup() {
            performCleanup()
        }
    }
    
    /// Retrieve a cached view
    public func getCachedView(forKey key: String, context: ViewAccess.AccessContext = .navigation) -> AnyView? {
        if var cached = viewCache[key] {
            // Cache hit
            cached.recordAccess()
            viewCache[key] = cached
            cacheStatistics.hits += 1
            
            recordAccess(key: key, context: context)
            performanceLogger.debug("✅ Cache hit for view: \(key)")
            
            return cached.view
        } else {
            // Cache miss
            cacheStatistics.misses += 1
            performanceLogger.debug("❌ Cache miss for view: \(key)")
            return nil
        }
    }
    
    /// Preload a view based on predictions
    public func preloadView<T: View>(
        _ viewBuilder: @autoclosure @escaping () -> T,
        forKey key: String,
        priority: PreloadPriority = .normal
    ) {
        guard !viewCache.keys.contains(key) else {
            performanceLogger.debug("🔄 View already cached: \(key)")
            return
        }
        
        let view = viewBuilder()
        registerView(view, forKey: key, context: .manual)
        
        performanceLogger.info("🚀 Preloaded view: \(key) (priority: \(String(describing: priority)))")
    }
    
    /// Clear all cached views
    public func clearCache() {
        viewCache.removeAll()
        cacheStatistics.totalMemoryMB = 0
        cacheStatistics.evictions += viewCache.count
        performanceLogger.info("🧹 Cache cleared")
    }
    
    /// Set the predictive loading engine for intelligent preloading
    public func setPredictiveEngine(_ engine: PredictiveLoadingEngine) {
        self.predictiveEngine = engine
        performanceLogger.info("🧠 Predictive engine connected to ViewPreloadManager")
    }
    
    // MARK: - Performance Monitoring
    
    public func getCacheStatistics() -> CacheStatistics {
        return cacheStatistics
    }
    
    public func getDetailedMetrics() -> DetailedMetrics {
        return DetailedMetrics(
            cacheSize: viewCache.count,
            totalMemoryMB: cacheStatistics.totalMemoryMB,
            hitRate: cacheStatistics.hitRate,
            efficiency: cacheStatistics.efficiency,
            averageAccessCount: calculateAverageAccessCount(),
            mostAccessedViews: getMostAccessedViews(),
            recentAccesses: Array(accessHistory.suffix(10))
        )
    }
    
    public struct DetailedMetrics {
        let cacheSize: Int
        let totalMemoryMB: Double
        let hitRate: Double
        let efficiency: Double
        let averageAccessCount: Double
        let mostAccessedViews: [(String, Int)]
        let recentAccesses: [ViewAccess]
    }
    
    // MARK: - Private Implementation
    
    private func recordAccess(key: String, context: ViewAccess.AccessContext) {
        let access = ViewAccess(
            viewKey: key,
            accessTime: Date(),
            context: context,
            userRole: getCurrentUserRole()
        )
        
        accessHistory.append(access)
        
        // Limit history size
        if accessHistory.count > 1000 {
            accessHistory.removeFirst(accessHistory.count - 800)
        }
        
        // Trigger predictive preloading
        triggerPredictivePreloading(basedOn: access)
    }
    
    private func getCurrentUserRole() -> String? {
        // This would integrate with the authentication system
        return "unknown" // Placeholder
    }
    
    private func triggerPredictivePreloading(basedOn access: ViewAccess) {
        // Use patterns to predict next likely views
        let predictions = getPredictedViews(following: access)
        
        for prediction in predictions.prefix(3) {
            if !viewCache.keys.contains(prediction.viewKey) && prediction.confidence > 0.7 {
                // This would be implemented by specific view factories
                performanceLogger.info("🔮 Predicted view for preload: \(prediction.viewKey)")
            }
        }
    }
    
    private func getPredictedViews(following access: ViewAccess) -> [ViewPrediction] {
        // Analyze access patterns to predict next views
        let recentAccesses = accessHistory.suffix(50)
        var patterns: [String: Int] = [:]
        
        for i in 0..<recentAccesses.count - 1 {
            if recentAccesses[Array(recentAccesses).indices][i].viewKey == access.viewKey {
                let nextView = recentAccesses[Array(recentAccesses).indices][i + 1].viewKey
                patterns[nextView, default: 0] += 1
            }
        }
        
        return patterns.map { key, count in
            let confidence = Double(count) / Double(recentAccesses.count)
            return ViewPrediction(viewKey: key, confidence: confidence, reason: "Access pattern")
        }.sorted { $0.confidence > $1.confidence }
    }
    
    private struct ViewPrediction {
        let viewKey: String
        let confidence: Double
        let reason: String
    }
    
    private func estimateMemoryUsage<T: View>(for view: T) -> Double {
        // Rough estimation based on view type
        let baseSize = 0.5 // MB base size
        let typeString = String(describing: T.self)
        
        var multiplier: Double = 1.0
        
        if typeString.contains("List") || typeString.contains("Table") {
            multiplier = 2.0
        } else if typeString.contains("Detail") || typeString.contains("Dashboard") {
            multiplier = 1.5
        } else if typeString.contains("Sheet") || typeString.contains("Picker") {
            multiplier = 0.8
        }
        
        return baseSize * multiplier
    }
    
    private func shouldPerformCleanup() -> Bool {
        return viewCache.count >= CacheConfig.maxCacheSize ||
               cacheStatistics.totalMemoryMB >= Double(CacheConfig.maxMemoryMB)
    }
    
    private func performCleanup() {
        let beforeCount = viewCache.count
        let beforeMemory = cacheStatistics.totalMemoryMB
        
        // Remove expired views
        let expiredKeys = viewCache.compactMap { key, cached in
            cached.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            if let cached = viewCache.removeValue(forKey: key) {
                cacheStatistics.totalMemoryMB -= cached.estimatedMemoryMB
                cacheStatistics.evictions += 1
            }
        }
        
        // If still over limit, remove least recently used
        if shouldPerformCleanup() {
            let sortedByAccess = viewCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            let toRemove = sortedByAccess.prefix(max(1, viewCache.count / 4))
            
            for (key, cached) in toRemove {
                viewCache.removeValue(forKey: key)
                cacheStatistics.totalMemoryMB -= cached.estimatedMemoryMB
                cacheStatistics.evictions += 1
            }
        }
        
        let afterCount = viewCache.count
        let afterMemory = cacheStatistics.totalMemoryMB
        
        if beforeCount != afterCount {
            performanceLogger.info("🧹 Cleanup completed: \(beforeCount) → \(afterCount) views, \(String(format: "%.1f", beforeMemory)) → \(String(format: "%.1f", afterMemory))MB")
        }
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) async {
        performanceLogger.warning("⚠️ Memory pressure detected: \(String(describing: level))")
        
        switch level {
        case .warning:
            // Remove 25% of cache
            await evictCachePercentage(0.25)
        case .critical:
            // Remove 50% of cache
            await evictCachePercentage(0.5)
        case .urgent:
            // Clear all cache
            clearCache()
        }
    }
    
    private func evictCachePercentage(_ percentage: Double) async {
        let toEvict = Int(Double(viewCache.count) * percentage)
        let sortedByAccess = viewCache.sorted { $0.value.accessCount < $1.value.accessCount }
        
        for (key, cached) in sortedByAccess.prefix(toEvict) {
            viewCache.removeValue(forKey: key)
            cacheStatistics.totalMemoryMB -= cached.estimatedMemoryMB
            cacheStatistics.evictions += 1
        }
        
        performanceLogger.info("🧹 Evicted \(toEvict) views due to memory pressure")
    }
    
    private func calculateAverageAccessCount() -> Double {
        guard !viewCache.isEmpty else { return 0.0 }
        let totalAccesses = viewCache.values.reduce(0) { $0 + $1.accessCount }
        return Double(totalAccesses) / Double(viewCache.count)
    }
    
    private func getMostAccessedViews() -> [(String, Int)] {
        return viewCache.map { ($0.key, $0.value.accessCount) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { ($0.0, $0.1) }
    }
    
    deinit {
        cleanupTimer?.invalidate()
        memoryMonitor = nil
        performanceLogger.info("🎬 ViewPreloadManager deinitialized")
    }
}

// MARK: - Supporting Types

public enum PreloadPriority {
    case low, normal, high, critical
}

public enum MemoryPressureLevel {
    case warning, critical, urgent
}

// MARK: - Memory Monitor Helper

private class MemoryMonitor {
    private let onPressure: (MemoryPressureLevel) -> Void
    private var isMonitoring = false
    
    init(onPressure: @escaping (MemoryPressureLevel) -> Void) {
        self.onPressure = onPressure
        startMonitoring()
    }
    
    private func startMonitoring() {
        // This would integrate with iOS memory pressure notifications
        // For now, this is a placeholder implementation
        isMonitoring = true
    }
    
    deinit {
        isMonitoring = false
    }
}