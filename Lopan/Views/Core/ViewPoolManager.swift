//
//  ViewPoolManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import SwiftUI
import Combine
import os

/// Advanced view pool manager for efficient view reuse and memory management
@MainActor
public final class ViewPoolManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = ViewPoolManager()
    
    // MARK: - Pool Configuration
    
    private struct PoolConfig {
        static let maxPoolSize: Int = 30
        static let maxPoolSizePerType: Int = 8
        static let cleanupInterval: TimeInterval = 180 // 3 minutes
        static let maxIdleTime: TimeInterval = 600 // 10 minutes
        static let maxMemoryMB: Int = 20
    }
    
    // MARK: - View Pool
    
    private var viewPools: [String: ViewPool] = [:]
    private var poolStatistics = PoolStatistics()
    private var reuseHistory: [ViewReuseEvent] = []
    
    private struct ViewPool {
        var available: [PooledView] = []
        var inUse: [String: PooledView] = [:]
        let viewType: String
        var totalCreated: Int = 0
        var totalReused: Int = 0
        
        mutating func addView(_ view: PooledView) {
            available.append(view)
        }
        
        mutating func getView() -> PooledView? {
            guard !available.isEmpty else { return nil }
            let view = available.removeFirst()
            inUse[view.id] = view
            totalReused += 1
            return view
        }
        
        mutating func returnView(_ viewId: String) {
            if let view = inUse.removeValue(forKey: viewId) {
                var updatedView = view
                updatedView.lastUsed = Date()
                updatedView.reuseCount += 1
                available.append(updatedView)
            }
        }
        
        mutating func cleanup() {
            let cutoff = Date().addingTimeInterval(-PoolConfig.maxIdleTime)
            available.removeAll { $0.lastUsed < cutoff }
        }
        
        var memoryUsageMB: Double {
            let totalViews = available.count + inUse.count
            return Double(totalViews) * 1.2 // Estimated 1.2MB per view
        }
    }
    
    private struct PooledView {
        let id: String
        let view: AnyView
        let viewType: String
        let createdAt: Date
        var lastUsed: Date
        var reuseCount: Int
        let estimatedMemoryMB: Double
        
        init<T: View>(view: T, viewType: String) {
            self.id = UUID().uuidString
            self.view = AnyView(view)
            self.viewType = viewType
            self.createdAt = Date()
            self.lastUsed = Date()
            self.reuseCount = 0
            self.estimatedMemoryMB = 1.2 // Base estimation
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(lastUsed) > PoolConfig.maxIdleTime
        }
    }
    
    // MARK: - Statistics
    
    public struct PoolStatistics {
        var totalViews: Int = 0
        var totalReuses: Int = 0
        var totalCreations: Int = 0
        var memoryUsageMB: Double = 0
        var poolCount: Int = 0
        
        var reuseRate: Double {
            let total = totalReuses + totalCreations
            return total > 0 ? Double(totalReuses) / Double(total) : 0.0
        }
        
        var efficiency: Double {
            return reuseRate >= 0.6 ? 1.0 : reuseRate / 0.6
        }
    }
    
    private struct ViewReuseEvent {
        let viewType: String
        let eventType: EventType
        let timestamp: Date
        let poolSize: Int
        
        enum EventType {
            case created, reused, returned, expired
        }
    }
    
    // MARK: - Monitoring
    
    private let logger = Logger(subsystem: "com.lopan.views", category: "pool")
    private var cleanupTimer: Timer?
    private var memoryMonitor: PoolMemoryMonitor?
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryMonitoring()
        startPeriodicCleanup()
        logger.info("🏊‍♂️ ViewPoolManager initialized")
    }
    
    private func setupMemoryMonitoring() {
        memoryMonitor = PoolMemoryMonitor { [weak self] pressure in
            Task { @MainActor in
                await self?.handleMemoryPressure(pressure)
            }
        }
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: PoolConfig.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanup()
            }
        }
    }
    
    // MARK: - Public API
    
    /// Get or create a view from the pool
    public func getPooledView<T: View>(
        viewType: T.Type,
        factory: () -> T
    ) -> (view: AnyView, isReused: Bool) {
        let typeName = String(describing: viewType)
        
        // Try to get from pool first
        if var pool = viewPools[typeName], let pooledView = pool.getView() {
            viewPools[typeName] = pool
            poolStatistics.totalReuses += 1
            
            recordReuseEvent(viewType: typeName, event: .reused, poolSize: pool.available.count)
            logger.debug("♻️ Reused view: \(typeName)")
            
            return (pooledView.view, true)
        } else {
            // Create new view
            let newView = factory()
            let pooledView = PooledView(view: newView, viewType: typeName)
            
            // Initialize pool if needed
            if viewPools[typeName] == nil {
                viewPools[typeName] = ViewPool(viewType: typeName)
            }
            
            viewPools[typeName]?.totalCreated += 1
            poolStatistics.totalCreations += 1
            poolStatistics.totalViews += 1
            
            recordReuseEvent(viewType: typeName, event: .created, poolSize: 0)
            logger.debug("🆕 Created new view: \(typeName)")
            
            return (pooledView.view, false)
        }
    }
    
    /// Return a view to the pool for reuse
    public func returnViewToPool<T: View>(
        viewType: T.Type,
        viewId: String? = nil
    ) {
        let typeName = String(describing: viewType)
        
        if let viewId = viewId {
            viewPools[typeName]?.returnView(viewId)
            recordReuseEvent(viewType: typeName, event: .returned, poolSize: viewPools[typeName]?.available.count ?? 0)
            logger.debug("🔄 Returned view to pool: \(typeName)")
        }
    }
    
    /// Preload views into the pool
    public func preloadViews<T: View>(
        viewType: T.Type,
        count: Int,
        factory: @escaping () -> T
    ) {
        guard count > 0 && count <= PoolConfig.maxPoolSizePerType else { return }
        
        let typeName = String(describing: viewType)
        
        if viewPools[typeName] == nil {
            viewPools[typeName] = ViewPool(viewType: typeName)
        }
        
        for _ in 0..<count {
            let view = factory()
            let pooledView = PooledView(view: view, viewType: typeName)
            viewPools[typeName]?.addView(pooledView)
        }
        
        poolStatistics.totalViews += count
        logger.info("📦 Preloaded \(count) views of type: \(typeName)")
    }
    
    /// Clear all pools
    public func clearAllPools() {
        let totalViews = poolStatistics.totalViews
        viewPools.removeAll()
        poolStatistics = PoolStatistics()
        logger.info("🧹 Cleared all view pools (\(totalViews) views)")
    }
    
    /// Clear pool for specific view type
    public func clearPool<T: View>(for viewType: T.Type) {
        let typeName = String(describing: viewType)
        
        if let pool = viewPools.removeValue(forKey: typeName) {
            let clearedCount = pool.available.count + pool.inUse.count
            poolStatistics.totalViews -= clearedCount
            logger.info("🧹 Cleared pool for \(typeName) (\(clearedCount) views)")
        }
    }
    
    // MARK: - Performance Monitoring
    
    public func getPoolStatistics() -> PoolStatistics {
        updateStatistics()
        return poolStatistics
    }
    
    public func getDetailedPoolInfo() -> [PoolInfo] {
        return viewPools.map { key, pool in
            PoolInfo(
                viewType: key,
                availableViews: pool.available.count,
                inUseViews: pool.inUse.count,
                totalCreated: pool.totalCreated,
                totalReused: pool.totalReused,
                memoryUsageMB: pool.memoryUsageMB,
                reuseRate: pool.totalCreated > 0 ? Double(pool.totalReused) / Double(pool.totalCreated + pool.totalReused) : 0.0
            )
        }
    }
    
    public struct PoolInfo {
        public let viewType: String
        public let availableViews: Int
        public let inUseViews: Int
        public let totalCreated: Int
        public let totalReused: Int
        public let memoryUsageMB: Double
        public let reuseRate: Double
        
        public var efficiency: String {
            if reuseRate >= 0.8 { return "Excellent" }
            if reuseRate >= 0.6 { return "Good" }
            if reuseRate >= 0.4 { return "Fair" }
            return "Poor"
        }
    }
    
    public func getMemoryUsage() -> PoolMemoryUsage {
        let totalMemory = viewPools.values.reduce(0) { $0 + $1.memoryUsageMB }
        let totalViews = viewPools.values.reduce(0) { $0 + $1.available.count + $1.inUse.count }
        
        return PoolMemoryUsage(
            totalMemoryMB: totalMemory,
            totalViews: totalViews,
            poolCount: viewPools.count,
            isOverLimit: totalMemory > Double(PoolConfig.maxMemoryMB)
        )
    }
    
    public struct PoolMemoryUsage {
        public let totalMemoryMB: Double
        public let totalViews: Int
        public let poolCount: Int
        public let isOverLimit: Bool
        
        public var status: String {
            if isOverLimit { return "Over Limit" }
            if totalMemoryMB > Double(PoolConfig.maxMemoryMB) * 0.8 { return "High" }
            if totalMemoryMB > Double(PoolConfig.maxMemoryMB) * 0.6 { return "Medium" }
            return "Low"
        }
    }
    
    // MARK: - Private Implementation
    
    private func updateStatistics() {
        poolStatistics.totalViews = viewPools.values.reduce(0) { $0 + $1.available.count + $1.inUse.count }
        poolStatistics.memoryUsageMB = viewPools.values.reduce(0) { $0 + $1.memoryUsageMB }
        poolStatistics.poolCount = viewPools.count
    }
    
    private func recordReuseEvent(viewType: String, event: ViewReuseEvent.EventType, poolSize: Int) {
        let reuseEvent = ViewReuseEvent(
            viewType: viewType,
            eventType: event,
            timestamp: Date(),
            poolSize: poolSize
        )
        
        reuseHistory.append(reuseEvent)
        
        // Limit history size
        if reuseHistory.count > 1000 {
            reuseHistory.removeFirst(reuseHistory.count - 800)
        }
    }
    
    private func performCleanup() {
        let beforeCount = poolStatistics.totalViews
        let beforeMemory = poolStatistics.memoryUsageMB
        
        // Clean expired views from all pools
        for (key, var pool) in viewPools {
            let beforePoolSize = pool.available.count
            pool.cleanup()
            let afterPoolSize = pool.available.count
            
            if beforePoolSize != afterPoolSize {
                viewPools[key] = pool
                recordReuseEvent(viewType: key, event: .expired, poolSize: afterPoolSize)
            }
        }
        
        // Remove empty pools
        viewPools = viewPools.filter { !$0.value.available.isEmpty || !$0.value.inUse.isEmpty }
        
        updateStatistics()
        
        let afterCount = poolStatistics.totalViews
        let afterMemory = poolStatistics.memoryUsageMB
        
        if beforeCount != afterCount {
            logger.info("🧹 Pool cleanup: \(beforeCount) → \(afterCount) views, \(String(format: "%.1f", beforeMemory)) → \(String(format: "%.1f", afterMemory))MB")
        }
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) async {
        logger.warning("⚠️ Pool memory pressure: \(String(describing: level))")
        
        switch level {
        case .warning:
            // Remove 30% of least used views
            await reducePoolsByPercentage(0.3)
        case .critical:
            // Remove 60% of least used views
            await reducePoolsByPercentage(0.6)
        case .urgent:
            // Clear all pools
            clearAllPools()
        }
    }
    
    private func reducePoolsByPercentage(_ percentage: Double) async {
        for (key, var pool) in viewPools {
            let toRemove = Int(Double(pool.available.count) * percentage)
            
            // Sort by last used and remove oldest
            pool.available.sort { $0.lastUsed < $1.lastUsed }
            pool.available.removeFirst(min(toRemove, pool.available.count))
            
            viewPools[key] = pool
            recordReuseEvent(viewType: key, event: .expired, poolSize: pool.available.count)
        }
        
        updateStatistics()
        logger.info("🧹 Reduced pools by \(String(format: "%.0f", percentage * 100))% due to memory pressure")
    }
    
    deinit {
        cleanupTimer?.invalidate()
        memoryMonitor = nil
        logger.info("🏊‍♂️ ViewPoolManager deinitialized")
    }
}

// MARK: - Pooled View Wrapper

/// Wrapper for views that can be pooled and reused
public struct PooledViewWrapper<Content: View>: View {
    private let content: Content
    private let viewType: String
    private let shouldPool: Bool
    
    @StateObject private var poolManager = ViewPoolManager.shared
    
    public init(
        shouldPool: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.viewType = String(describing: Content.self)
        self.shouldPool = shouldPool
    }
    
    public var body: some View {
        if shouldPool {
            // Use pooled version
            let (pooledView, _) = poolManager.getPooledView(viewType: Content.self) {
                content
            }
            
            pooledView
                .onDisappear {
                    // Return to pool when view disappears
                    poolManager.returnViewToPool(viewType: Content.self)
                }
        } else {
            // Use regular view
            content
        }
    }
}

// MARK: - Memory Monitor

private class PoolMemoryMonitor {
    private let onPressure: (MemoryPressureLevel) -> Void
    private var isMonitoring = false
    
    init(onPressure: @escaping (MemoryPressureLevel) -> Void) {
        self.onPressure = onPressure
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Placeholder for actual memory monitoring
        isMonitoring = true
    }
    
    deinit {
        isMonitoring = false
    }
}

// MARK: - View Extensions

public extension View {
    /// Enable view pooling for this view
    func pooled(shouldPool: Bool = true) -> some View {
        PooledViewWrapper(shouldPool: shouldPool) {
            self
        }
    }
    
    /// Preload views of this type into the pool
    static func preloadIntoPool(count: Int = 3) where Self: View {
        Task { @MainActor in
            ViewPoolManager.shared.preloadViews(
                viewType: Self.self,
                count: count
            ) {
                // This would need specific implementation per view type
                // For now, create a placeholder that matches the type
                EmptyView() as! Self
            }
        }
    }
}

// MARK: - Pool Performance Debug View

/// Debug view for monitoring pool performance
public struct PoolPerformanceView: View {
    @StateObject private var poolManager = ViewPoolManager.shared
    @State private var poolStats: ViewPoolManager.PoolStatistics?
    @State private var poolInfos: [ViewPoolManager.PoolInfo] = []
    @State private var memoryUsage: ViewPoolManager.PoolMemoryUsage?
    @State private var refreshTimer: Timer?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Pool Overview") {
                    if let stats = poolStats {
                        MetricRow(title: "Total Views", value: "\(stats.totalViews)")
                        MetricRow(title: "Reuse Rate", value: "\(String(format: "%.1f", stats.reuseRate * 100))%")
                            .foregroundColor(stats.reuseRate >= 0.6 ? .green : .orange)
                        MetricRow(title: "Efficiency", value: "\(String(format: "%.1f", stats.efficiency * 100))%")
                        MetricRow(title: "Active Pools", value: "\(stats.poolCount)")
                    }
                }
                
                Section("Memory Usage") {
                    if let memory = memoryUsage {
                        MetricRow(title: "Total Memory", value: "\(String(format: "%.1f", memory.totalMemoryMB))MB")
                            .foregroundColor(memory.isOverLimit ? .red : .primary)
                        MetricRow(title: "Status", value: memory.status)
                            .foregroundColor(memory.status == "Over Limit" ? .red : 
                                           memory.status == "High" ? .orange : .green)
                    }
                }
                
                Section("Pool Details") {
                    ForEach(poolInfos, id: \.viewType) { info in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.viewType)
                                .font(.headline)
                            
                            HStack {
                                Text("Available: \(info.availableViews)")
                                Spacer()
                                Text("In Use: \(info.inUseViews)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Reuse Rate: \(String(format: "%.1f", info.reuseRate * 100))%")
                                Spacer()
                                Text("Efficiency: \(info.efficiency)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                Section("Actions") {
                    Button("Clear All Pools") {
                        poolManager.clearAllPools()
                        refreshData()
                    }
                    .foregroundColor(.red)
                    
                    Button("Refresh Data") {
                        refreshData()
                    }
                }
            }
            .navigationTitle("View Pool Monitor")
            .onAppear {
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }
    
    private func refreshData() {
        poolStats = poolManager.getPoolStatistics()
        poolInfos = poolManager.getDetailedPoolInfo()
        memoryUsage = poolManager.getMemoryUsage()
    }
    
    private func startAutoRefresh() {
        refreshData()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            refreshData()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private struct MetricRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
            }
        }
    }
}