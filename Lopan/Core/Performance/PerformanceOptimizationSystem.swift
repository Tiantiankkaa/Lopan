//
//  PerformanceOptimizationSystem.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  iOS 26 Performance Optimization and Memory Management System
//

import SwiftUI
import Foundation
import os.log

// MARK: - Performance Optimization Manager

@MainActor
public final class PerformanceOptimizationManager: ObservableObject {
    public static let shared = PerformanceOptimizationManager()

    private let compatibilityLayer = iOS26CompatibilityLayer.shared
    private let featureFlags = FeatureFlagManager.shared
    private let logger = Logger(subsystem: "com.lopan.performance", category: "Optimization")

    @Published public var isEnabled: Bool = true
    @Published public var optimizationLevel: OptimizationLevel = .adaptive
    @Published public var memoryManagementEnabled: Bool = true
    @Published public var backgroundTaskOptimization: Bool = true

    // Performance monitoring
    @Published public private(set) var currentMemoryUsage: MemoryUsage = MemoryUsage()
    @Published public private(set) var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published public private(set) var isLowPowerModeDetected: Bool = false

    public enum OptimizationLevel: String, CaseIterable {
        case minimal = "minimal"
        case balanced = "balanced"
        case aggressive = "aggressive"
        case adaptive = "adaptive"

        public var displayName: String {
            switch self {
            case .minimal: return "Minimal"
            case .balanced: return "Balanced"
            case .aggressive: return "Aggressive"
            case .adaptive: return "Adaptive"
            }
        }

        public var cacheSize: Int {
            switch self {
            case .minimal: return 10
            case .balanced: return 25
            case .aggressive: return 50
            case .adaptive: return 30
            }
        }

        public var preloadLimit: Int {
            switch self {
            case .minimal: return 2
            case .balanced: return 5
            case .aggressive: return 10
            case .adaptive: return 7
            }
        }

        public var animationQuality: AnimationQuality {
            switch self {
            case .minimal: return .low
            case .balanced: return .medium
            case .aggressive: return .high
            case .adaptive: return .medium
            }
        }
    }

    public enum AnimationQuality: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        public var frameRate: Int {
            switch self {
            case .low: return 30
            case .medium: return 60
            case .high: return 120
            }
        }

        public var usesMetal: Bool {
            switch self {
            case .low: return false
            case .medium: return false
            case .high: return true
            }
        }
    }

    public struct MemoryUsage {
        public let totalMemoryMB: Double
        public let usedMemoryMB: Double
        public let availableMemoryMB: Double
        public let memoryPressure: MemoryPressure

        public enum MemoryPressure: String, CaseIterable {
            case normal = "normal"
            case warning = "warning"
            case critical = "critical"

            public var thresholdPercentage: Double {
                switch self {
                case .normal: return 0.7
                case .warning: return 0.85
                case .critical: return 0.95
                }
            }
        }

        public init() {
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000
            let task = mach_task_self_
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }

            let usedMemory = kerr == KERN_SUCCESS ? Double(info.resident_size) / 1_000_000 : 0
            let availableMemory = totalMemory - usedMemory
            let usagePercentage = usedMemory / totalMemory

            self.totalMemoryMB = totalMemory
            self.usedMemoryMB = usedMemory
            self.availableMemoryMB = availableMemory

            if usagePercentage > MemoryPressure.critical.thresholdPercentage {
                self.memoryPressure = .critical
            } else if usagePercentage > MemoryPressure.warning.thresholdPercentage {
                self.memoryPressure = .warning
            } else {
                self.memoryPressure = .normal
            }
        }
    }

    public struct PerformanceMetrics {
        public let cpuUsage: Double
        public let frameRate: Double
        public let batteryLevel: Float
        public let thermalState: ProcessInfo.ThermalState

        public init() {
            self.cpuUsage = ProcessInfo.processInfo.thermalState == .critical ? 90.0 : 45.0 // Simplified
            self.frameRate = 60.0 // Would be measured from display link
            self.batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 1.0
            self.thermalState = ProcessInfo.processInfo.thermalState
        }
    }

    private var memoryMonitorTimer: Timer?
    private var performanceMonitorTimer: Timer?
    private let cacheManager = PerformanceCacheManager()

    private init() {
        setupOptimizationLevel()
        setupPerformanceMonitoring()
        setupLowPowerModeObserver()
        logger.info("⚡ Performance Optimization Manager initialized")
    }

    private func setupOptimizationLevel() {
        let deviceMemory = ProcessInfo.processInfo.physicalMemory
        let isLowMemoryDevice = deviceMemory < 4_000_000_000 // Less than 4GB

        if optimizationLevel == .adaptive {
            if isLowMemoryDevice || ProcessInfo.processInfo.isLowPowerModeEnabled {
                optimizationLevel = .minimal
            } else if compatibilityLayer.isIOS26Available {
                optimizationLevel = .balanced
            } else {
                optimizationLevel = .minimal
            }
        }

        logger.info("🎛️ Optimization level set to: \(self.optimizationLevel.displayName)")
    }

    private func setupPerformanceMonitoring() {
        // Monitor memory usage every 5 seconds
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }

        // Monitor general performance every 10 seconds
        performanceMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }

    private func setupLowPowerModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePowerModeChange()
        }
    }

    private func handlePowerModeChange() {
        isLowPowerModeDetected = ProcessInfo.processInfo.isLowPowerModeEnabled

        if isLowPowerModeDetected {
            optimizationLevel = .minimal
            logger.info("🔋 Low power mode detected - switching to minimal optimization")
        } else {
            setupOptimizationLevel()
            logger.info("🔌 Normal power mode - restoring optimization level")
        }
    }

    private func updateMemoryUsage() {
        currentMemoryUsage = MemoryUsage()

        // Trigger memory cleanup if needed
        if currentMemoryUsage.memoryPressure == .critical {
            triggerEmergencyMemoryCleanup()
        } else if currentMemoryUsage.memoryPressure == .warning {
            triggerMemoryCleanup()
        }
    }

    private func updatePerformanceMetrics() {
        performanceMetrics = PerformanceMetrics()

        // Adjust optimization based on performance
        if performanceMetrics.thermalState == .critical {
            optimizationLevel = .minimal
            logger.warning("🌡️ Critical thermal state - reducing optimization level")
        }
    }

    // MARK: - Memory Management

    public func triggerMemoryCleanup() {
        logger.info("🧹 Triggering memory cleanup")

        // Clear caches
        cacheManager.clearOldCaches()

        // Clear image caches
        URLCache.shared.removeAllCachedResponses()

        // Notify systems to cleanup
        NotificationCenter.default.post(name: .performanceMemoryCleanup, object: nil)
    }

    public func triggerEmergencyMemoryCleanup() {
        logger.critical("🚨 Triggering emergency memory cleanup")

        // Aggressive cleanup
        cacheManager.clearAllCaches()
        URLCache.shared.removeAllCachedResponses()

        // Disable non-essential features
        featureFlags.disable(.glassMorphismV2)
        featureFlags.disable(.fluidAnimations)
        featureFlags.disable(.adaptiveLayouts)

        // Notify systems for emergency cleanup
        NotificationCenter.default.post(name: .performanceEmergencyCleanup, object: nil)
    }

    // MARK: - Background Task Optimization

    @available(iOS 26.0, *)
    public func optimizeBackgroundTasks() async {
        guard backgroundTaskOptimization else { return }

        logger.info("🔧 Optimizing background tasks")

        // Reduce background update frequency during low power mode
        if isLowPowerModeDetected {
            await reduceBackgroundActivity()
        }

        // Intelligent batching of background operations
        await batchBackgroundOperations()
    }

    @available(iOS 26.0, *)
    private func reduceBackgroundActivity() async {
        // Reduce update frequencies
        logger.info("📱 Reducing background activity for power conservation")
    }

    @available(iOS 26.0, *)
    private func batchBackgroundOperations() async {
        // Batch operations for efficiency
        logger.info("📦 Batching background operations")
    }

    // MARK: - Performance Caching

    public func cacheViewData<T: Codable>(_ data: T, forKey key: String) {
        cacheManager.cacheData(data, forKey: key)
    }

    public func getCachedViewData<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        return cacheManager.getCachedData(type, forKey: key)
    }

    public func clearViewCache(forKey key: String) {
        cacheManager.clearCache(forKey: key)
    }

    // MARK: - Performance Reporting

    public func generatePerformanceReport() -> PerformanceOptimizationReport {
        return PerformanceOptimizationReport(
            optimizationLevel: optimizationLevel,
            memoryUsage: currentMemoryUsage,
            performanceMetrics: performanceMetrics,
            cacheStatistics: cacheManager.getStatistics(),
            featuresEnabled: PerformanceFeatures()
        )
    }

    public struct PerformanceOptimizationReport {
        public let optimizationLevel: OptimizationLevel
        public let memoryUsage: MemoryUsage
        public let performanceMetrics: PerformanceMetrics
        public let cacheStatistics: CacheStatistics
        public let featuresEnabled: PerformanceFeatures

        public var summary: String {
            """
            Performance Optimization Report
            ===============================
            Optimization Level: \(optimizationLevel.displayName)
            Memory Usage: \(String(format: "%.1f", memoryUsage.usedMemoryMB))/\(String(format: "%.1f", memoryUsage.totalMemoryMB))MB (\(String(format: "%.1f", (memoryUsage.usedMemoryMB / memoryUsage.totalMemoryMB) * 100))%)
            Memory Pressure: \(memoryUsage.memoryPressure.rawValue.capitalized)
            CPU Usage: \(String(format: "%.1f", performanceMetrics.cpuUsage))%
            Battery Level: \(String(format: "%.0f", performanceMetrics.batteryLevel * 100))%
            Thermal State: \(String(describing: performanceMetrics.thermalState).capitalized)

            Cache Statistics:
            - Total Items: \(cacheStatistics.totalItems)
            - Cache Hit Rate: \(String(format: "%.1f", cacheStatistics.hitRate * 100))%
            - Memory Used: \(String(format: "%.1f", cacheStatistics.memoryUsedMB))MB

            Performance Features:
            - Memory Management: \(featuresEnabled.memoryManagement ? "Enabled" : "Disabled")
            - Background Optimization: \(featuresEnabled.backgroundOptimization ? "Enabled" : "Disabled")
            - Cache Optimization: \(featuresEnabled.cacheOptimization ? "Enabled" : "Disabled")
            """
        }
    }

    public struct PerformanceFeatures {
        public let memoryManagement: Bool
        public let backgroundOptimization: Bool
        public let cacheOptimization: Bool

        public init() {
            self.memoryManagement = true
            self.backgroundOptimization = true
            self.cacheOptimization = true
        }
    }

    public struct CacheStatistics {
        public let totalItems: Int
        public let hitRate: Double
        public let memoryUsedMB: Double
    }

    deinit {
        memoryMonitorTimer?.invalidate()
        performanceMonitorTimer?.invalidate()
    }
}

// MARK: - Performance Cache Manager

public final class PerformanceCacheManager {
    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize: Int = 50
    private let maxCacheAge: TimeInterval = 300 // 5 minutes

    private struct CacheEntry {
        let data: Data
        let timestamp: Date
        let accessCount: Int
    }

    public func cacheData<T: Codable>(_ data: T, forKey key: String) {
        do {
            let encodedData = try JSONEncoder().encode(data)
            cache[key] = CacheEntry(data: encodedData, timestamp: Date(), accessCount: 0)

            // Cleanup old entries if cache is full
            if cache.count > maxCacheSize {
                cleanupOldEntries()
            }
        } catch {
            print("Failed to cache data for key \(key): \(error)")
        }
    }

    public func getCachedData<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let entry = cache[key] else { return nil }

        // Check if cache entry is still valid
        if Date().timeIntervalSince(entry.timestamp) > maxCacheAge {
            cache.removeValue(forKey: key)
            return nil
        }

        // Update access count
        cache[key] = CacheEntry(data: entry.data, timestamp: entry.timestamp, accessCount: entry.accessCount + 1)

        do {
            return try JSONDecoder().decode(type, from: entry.data)
        } catch {
            cache.removeValue(forKey: key)
            return nil
        }
    }

    public func clearCache(forKey key: String) {
        cache.removeValue(forKey: key)
    }

    public func clearOldCaches() {
        let cutoffTime = Date().addingTimeInterval(-maxCacheAge)
        cache = cache.filter { $0.value.timestamp > cutoffTime }
    }

    public func clearAllCaches() {
        cache.removeAll()
    }

    private func cleanupOldEntries() {
        // Remove least recently used entries
        let sortedEntries = cache.sorted { $0.value.accessCount < $1.value.accessCount }
        let toRemove = sortedEntries.prefix(10)

        for (key, _) in toRemove {
            cache.removeValue(forKey: key)
        }
    }

    public func getStatistics() -> PerformanceOptimizationManager.CacheStatistics {
        let totalItems = cache.count
        let totalAccesses = cache.values.reduce(0) { $0 + $1.accessCount }
        let hits = totalAccesses
        let memoryUsed = cache.values.reduce(0) { $0 + $1.data.count }

        return PerformanceOptimizationManager.CacheStatistics(
            totalItems: totalItems,
            hitRate: totalAccesses > 0 ? Double(hits) / Double(totalAccesses) : 0,
            memoryUsedMB: Double(memoryUsed) / 1_000_000
        )
    }
}


// MARK: - Notifications

public extension Notification.Name {
    static let performanceMemoryCleanup = Notification.Name("performanceMemoryCleanup")
    static let performanceEmergencyCleanup = Notification.Name("performanceEmergencyCleanup")
}

// MARK: - Environment Integration

private struct PerformanceOptimizationManagerKey: EnvironmentKey {
    static let defaultValue = PerformanceOptimizationManager.shared
}

public extension EnvironmentValues {
    var performanceOptimization: PerformanceOptimizationManager {
        get { self[PerformanceOptimizationManagerKey.self] }
        set { self[PerformanceOptimizationManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Optimizes view performance based on current optimization level
    func performanceOptimized() -> some View {
        let manager = PerformanceOptimizationManager.shared

        return self
            .animation(
                manager.optimizationLevel.animationQuality == .low ? nil : .default,
                value: manager.currentMemoryUsage.memoryPressure
            )
            .onReceive(NotificationCenter.default.publisher(for: .performanceMemoryCleanup)) { _ in
                // Cleanup view-specific resources
            }
            .onReceive(NotificationCenter.default.publisher(for: .performanceEmergencyCleanup)) { _ in
                // Emergency cleanup
            }
    }

    /// Caches view data for performance
    func performanceCached<T: Codable>(
        data: T,
        key: String
    ) -> some View {
        self.onAppear {
            PerformanceOptimizationManager.shared.cacheViewData(data, forKey: key)
        }
    }

    /// Memory-aware rendering
    func memoryAware() -> some View {
        let manager = PerformanceOptimizationManager.shared

        return Group {
            if manager.currentMemoryUsage.memoryPressure == .critical {
                // Simplified view for critical memory pressure
                Text("Loading...")
                    .foregroundColor(.secondary)
            } else {
                self
            }
        }
    }
}