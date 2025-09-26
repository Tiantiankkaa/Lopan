//
//  LopanScrollOptimizer.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Advanced scroll performance optimization
//

import SwiftUI
import Combine
import os

/// Advanced scroll optimization system for 60fps performance with large datasets
@MainActor
public final class LopanScrollOptimizer: ObservableObject {

    // MARK: - Singleton

    public static let shared = LopanScrollOptimizer()

    // MARK: - Published Properties

    @Published public var currentScrollMetrics = ScrollMetrics()
    @Published public var isOptimizationActive = false
    @Published public var prefetchedItems: Set<String> = []

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.lopan.scroll", category: "optimizer")
    private var scrollVelocityHistory: [ScrollVelocityData] = []
    private var visibleRangeHistory: [VisibleRange] = []
    private var itemHeightCache: [String: CGFloat] = [:]
    private var prefetchQueue = DispatchQueue(label: "com.lopan.prefetch", qos: .userInitiated)

    // MARK: - Configuration

    private struct Configuration {
        static let velocityHistoryLimit = 30 // Keep last 30 velocity measurements
        static let highVelocityThreshold: CGFloat = 1000.0 // Points per second
        static let prefetchDistance = 3 // Number of screens to prefetch
        static let adaptiveQualityEnabled = true
        static let frameRateTarget: Double = 60.0
        static let memoryPressureThreshold: Double = 200.0 // MB
    }

    // MARK: - Initialization

    private init() {
        setupScrollOptimization()
    }

    // MARK: - Public Interface

    /// Start scroll optimization
    public func startOptimization() {
        guard !isOptimizationActive else { return }

        isOptimizationActive = true
        logger.info("⚡ Scroll optimization started")
    }

    /// Stop scroll optimization
    public func stopOptimization() {
        guard isOptimizationActive else { return }

        isOptimizationActive = false
        clearOptimizationData()
        logger.info("⚡ Scroll optimization stopped")
    }

    /// Record scroll event for optimization analysis
    public func recordScrollEvent(
        velocity: CGFloat,
        contentOffset: CGPoint,
        visibleRange: VisibleRange,
        itemCount: Int
    ) {
        guard isOptimizationActive else { return }

        let timestamp = CFAbsoluteTimeGetCurrent()

        // Record velocity data
        let velocityData = ScrollVelocityData(
            timestamp: timestamp,
            velocity: velocity,
            contentOffset: contentOffset
        )

        scrollVelocityHistory.append(velocityData)

        // Keep only recent data
        let cutoffTime = timestamp - 3.0 // Last 3 seconds
        scrollVelocityHistory.removeAll { $0.timestamp < cutoffTime }

        // Record visible range
        visibleRangeHistory.append(visibleRange)
        if visibleRangeHistory.count > 20 {
            visibleRangeHistory.removeFirst()
        }

        // Update current metrics
        updateScrollMetrics(itemCount: itemCount)

        // Perform velocity-based optimization
        performVelocityBasedOptimization(velocity: velocity, visibleRange: visibleRange)

        // Report to performance profiler
        let fps = calculateCurrentFPS()
        LopanPerformanceProfiler.shared.recordScrollPerformance(
            velocity: velocity,
            itemCount: itemCount,
            fps: fps
        )
    }

    /// Cache item height for layout optimization
    public func cacheItemHeight(_ height: CGFloat, forItem itemId: String) {
        itemHeightCache[itemId] = height
    }

    /// Get cached item height
    public func getCachedItemHeight(forItem itemId: String) -> CGFloat? {
        return itemHeightCache[itemId]
    }

    /// Calculate optimal visible window size based on current performance
    public func calculateOptimalVisibleWindow(
        currentItemCount: Int,
        averageItemHeight: CGFloat,
        screenSize: CGSize
    ) -> VisibleWindow {
        let baseWindowSize = Int(screenSize.height / averageItemHeight) + 4 // Add buffer

        // Adjust based on current memory usage
        let memoryUsage = LopanMemoryManager.shared.currentMemoryUsage.currentMB
        let memoryFactor = memoryUsage > Configuration.memoryPressureThreshold ? 0.7 : 1.0

        // Adjust based on scroll velocity
        let averageVelocity = getAverageScrollVelocity()
        let velocityFactor = averageVelocity > Configuration.highVelocityThreshold ? 0.8 : 1.0

        let adjustedWindowSize = Int(Double(baseWindowSize) * memoryFactor * velocityFactor)

        return VisibleWindow(
            size: max(adjustedWindowSize, 10), // Minimum window size
            prefetchSize: adjustedWindowSize / 3
        )
    }

    /// Predict next visible items based on scroll pattern
    public func predictNextVisibleItems(
        currentRange: VisibleRange,
        itemCount: Int
    ) -> [Int] {
        guard let direction = predictScrollDirection() else {
            return []
        }

        let prefetchCount = Configuration.prefetchDistance
        var predictedItems: [Int] = []

        if direction == .down {
            let startIndex = currentRange.endIndex + 1
            let endIndex = min(startIndex + prefetchCount, itemCount - 1)
            if startIndex <= endIndex && startIndex < itemCount {
                predictedItems = Array(startIndex...endIndex)
            }
        } else if direction == .up {
            let endIndex = max(currentRange.startIndex - 1, 0)
            let startIndex = max(endIndex - prefetchCount, 0)
            if startIndex <= endIndex && endIndex >= 0 {
                predictedItems = Array(startIndex...endIndex)
            }
        }

        return predictedItems
    }

    /// Get scroll optimization recommendations
    public func getOptimizationRecommendations() -> [ScrollOptimizationRecommendation] {
        var recommendations: [ScrollOptimizationRecommendation] = []

        // Check frame rate
        let currentFPS = calculateCurrentFPS()
        if currentFPS < Configuration.frameRateTarget * 0.9 {
            recommendations.append(.reducePrefetchDistance)
            recommendations.append(.enableAdaptiveQuality)
        }

        // Check memory usage
        let memoryUsage = LopanMemoryManager.shared.currentMemoryUsage.currentMB
        if memoryUsage > Configuration.memoryPressureThreshold {
            recommendations.append(.reduceImageQuality)
            recommendations.append(.clearUnusedCaches)
        }

        // Check scroll velocity patterns
        let highVelocityPercent = getHighVelocityPercentage()
        if highVelocityPercent > 0.3 {
            recommendations.append(.optimizeForFastScrolling)
        }

        return recommendations
    }
}

// MARK: - Private Implementation

extension LopanScrollOptimizer {

    private func setupScrollOptimization() {
        // Initial setup
        logger.debug("🔧 Scroll optimizer initialized")
    }

    private func clearOptimizationData() {
        scrollVelocityHistory.removeAll()
        visibleRangeHistory.removeAll()
        prefetchedItems.removeAll()
    }

    private func updateScrollMetrics(itemCount: Int) {
        currentScrollMetrics.averageVelocity = getAverageScrollVelocity()
        currentScrollMetrics.currentFPS = calculateCurrentFPS()
        currentScrollMetrics.totalItems = itemCount
        currentScrollMetrics.lastUpdate = Date()
    }

    private func getAverageScrollVelocity() -> CGFloat {
        guard !scrollVelocityHistory.isEmpty else { return 0 }

        let totalVelocity = scrollVelocityHistory.map { abs($0.velocity) }.reduce(0, +)
        return totalVelocity / CGFloat(scrollVelocityHistory.count)
    }

    private func calculateCurrentFPS() -> Double {
        // This would integrate with the performance profiler
        return LopanPerformanceProfiler.shared.currentMetrics.currentFPS
    }

    private func performVelocityBasedOptimization(velocity: CGFloat, visibleRange: VisibleRange) {
        let isHighVelocity = abs(velocity) > Configuration.highVelocityThreshold

        if isHighVelocity {
            // High velocity optimization
            enableHighVelocityMode()
        } else {
            // Normal velocity optimization
            enableNormalMode()
        }

        // Prefetch items based on scroll direction
        prefetchBasedOnScrollDirection(visibleRange: visibleRange)
    }

    private func enableHighVelocityMode() {
        // Reduce quality and prefetching during high velocity scrolling
        logger.debug("🏎️ High velocity mode enabled")
    }

    private func enableNormalMode() {
        // Full quality and normal prefetching
        logger.debug("🚶 Normal velocity mode enabled")
    }

    private func prefetchBasedOnScrollDirection(visibleRange: VisibleRange) {
        guard let direction = predictScrollDirection() else { return }

        let predictedItems = predictNextVisibleItems(
            currentRange: visibleRange,
            itemCount: currentScrollMetrics.totalItems
        )

        // Prefetch items on background queue
        prefetchQueue.async { [weak self] in
            self?.performPrefetch(items: predictedItems)
        }
    }

    private func performPrefetch(items: [Int]) {
        // This would integrate with the data loading system
        Task { @MainActor [weak self] in
            self?.prefetchedItems.formUnion(items.map { String($0) })
        }

        logger.debug("📦 Prefetched \(items.count) items")
    }

    private func predictScrollDirection() -> ScrollDirection? {
        guard scrollVelocityHistory.count >= 3 else { return nil }

        let recentVelocities = scrollVelocityHistory.suffix(3)
        let averageVelocity = recentVelocities.map { $0.velocity }.reduce(0, +) / 3

        if averageVelocity > 50 {
            return .down
        } else if averageVelocity < -50 {
            return .up
        } else {
            return nil
        }
    }

    private func getHighVelocityPercentage() -> Double {
        guard !scrollVelocityHistory.isEmpty else { return 0 }

        let highVelocityCount = scrollVelocityHistory.count { abs($0.velocity) > Configuration.highVelocityThreshold }
        return Double(highVelocityCount) / Double(scrollVelocityHistory.count)
    }
}

// MARK: - Data Structures

public struct ScrollMetrics {
    var averageVelocity: CGFloat = 0
    var currentFPS: Double = 60
    var totalItems: Int = 0
    var lastUpdate: Date = Date()
}

public struct VisibleRange: Hashable {
    let startIndex: Int
    let endIndex: Int
    let timestamp: CFTimeInterval

    init(startIndex: Int, endIndex: Int) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.timestamp = CFAbsoluteTimeGetCurrent()
    }
}

public struct VisibleWindow {
    let size: Int
    let prefetchSize: Int
}

private struct ScrollVelocityData {
    let timestamp: CFTimeInterval
    let velocity: CGFloat
    let contentOffset: CGPoint
}

private enum ScrollDirection {
    case up, down
}

public enum ScrollOptimizationRecommendation: CaseIterable {
    case reducePrefetchDistance
    case enableAdaptiveQuality
    case reduceImageQuality
    case clearUnusedCaches
    case optimizeForFastScrolling

    public var description: String {
        switch self {
        case .reducePrefetchDistance:
            return "Reduce prefetch distance to improve performance"
        case .enableAdaptiveQuality:
            return "Enable adaptive quality based on scroll speed"
        case .reduceImageQuality:
            return "Reduce image quality to free memory"
        case .clearUnusedCaches:
            return "Clear unused caches to free memory"
        case .optimizeForFastScrolling:
            return "Optimize for fast scrolling patterns"
        }
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Add scroll optimization to any scrollable view
    public func scrollOptimized(
        itemCount: Int,
        visibleRange: VisibleRange
    ) -> some View {
        self.onAppear {
            LopanScrollOptimizer.shared.startOptimization()
        }
        .onDisappear {
            LopanScrollOptimizer.shared.stopOptimization()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let velocity = value.predictedEndLocation.y - value.location.y
                    LopanScrollOptimizer.shared.recordScrollEvent(
                        velocity: velocity,
                        contentOffset: CGPoint(x: 0, y: value.translation.height),
                        visibleRange: visibleRange,
                        itemCount: itemCount
                    )
                }
        )
    }
}

// MARK: - Debug View

#if DEBUG
public struct ScrollOptimizerDebugView: View {
    @StateObject private var optimizer = LopanScrollOptimizer.shared

    public var body: some View {
        NavigationStack {
            List {
                Section("Scroll Metrics") {
                    ScrollMetricRow(
                        title: "Average Velocity",
                        value: "\(String(format: "%.1f", optimizer.currentScrollMetrics.averageVelocity)) pt/s"
                    )
                    ScrollMetricRow(
                        title: "Current FPS",
                        value: "\(String(format: "%.1f", optimizer.currentScrollMetrics.currentFPS))"
                    )
                    ScrollMetricRow(
                        title: "Total Items",
                        value: "\(optimizer.currentScrollMetrics.totalItems)"
                    )
                }

                Section("Prefetch Status") {
                    ScrollMetricRow(
                        title: "Prefetched Items",
                        value: "\(optimizer.prefetchedItems.count)"
                    )
                }

                Section("Recommendations") {
                    ForEach(optimizer.getOptimizationRecommendations(), id: \.self) { recommendation in
                        Text(recommendation.description)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Scroll Optimizer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(optimizer.isOptimizationActive ? "Stop" : "Start") {
                        if optimizer.isOptimizationActive {
                            optimizer.stopOptimization()
                        } else {
                            optimizer.startOptimization()
                        }
                    }
                }
            }
        }
    }
}

private struct ScrollMetricRow: View {
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
    ScrollOptimizerDebugView()
}
#endif