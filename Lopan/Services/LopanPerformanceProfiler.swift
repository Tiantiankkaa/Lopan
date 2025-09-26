//
//  LopanPerformanceProfiler.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Real-time metrics collection system
//

import SwiftUI
import Foundation
import Combine
import os
import QuartzCore

/// Comprehensive performance profiling system for Lopan production app
/// Provides real-time metrics collection, automatic degradation detection, and performance optimization guidance
@MainActor
public final class LopanPerformanceProfiler: ObservableObject {

    // MARK: - Singleton

    public static let shared = LopanPerformanceProfiler()

    // MARK: - Performance Metrics

    @Published public var currentMetrics = PerformanceMetrics()
    @Published public var isMonitoring = false
    @Published public var performanceAlerts: [PerformanceAlert] = []

    internal let logger = Logger(subsystem: "com.lopan.performance", category: "profiler")
    private var displayLink: CADisplayLink?
    private var frameTimes: [CFTimeInterval] = []
    private var memoryTimer: Timer?
    private var networkRequests: [NetworkMetric] = []
    private var viewTransitionTimes: [String: CFTimeInterval] = [:]
    private var scrollMetrics: [ScrollMetric] = []

    // MARK: - Configuration

    public struct Configuration {
        var maxFrameHistory = 120 // 2 seconds at 60fps
        var memoryCheckInterval: TimeInterval = 1.0
        var alertThresholds = AlertThresholds()
        var isDebugMode = false
    }

    public var configuration = Configuration()

    // MARK: - Initialization

    private init() {
        setupPerformanceMonitoring()
    }

    deinit {
        // Cleanup resources directly in deinit to avoid @MainActor isolation issues
        displayLink?.invalidate()
        displayLink = nil
        memoryTimer?.invalidate()
        memoryTimer = nil
    }

    // MARK: - Public Interface

    /// Start comprehensive performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        startFrameRateMonitoring()
        startMemoryMonitoring()
        startNetworkMonitoring()

        logger.info("🎯 Performance monitoring started")
    }

    /// Stop performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        memoryTimer?.invalidate()
        memoryTimer = nil

        logger.info("⏹️ Performance monitoring stopped")
    }

    /// Record view transition time
    public func recordViewTransition(from: String, to: String, duration: CFTimeInterval) {
        let key = "\(from)->\(to)"
        viewTransitionTimes[key] = duration

        // Check if transition is slow
        if duration > configuration.alertThresholds.viewTransitionThreshold {
            addAlert(.slowViewTransition(from: from, to: to, duration: duration))
        }

        // Update current metrics
        currentMetrics.averageViewTransitionTime = viewTransitionTimes.values.reduce(0, +) / Double(viewTransitionTimes.count)

        logger.debug("📱 View transition \(key): \(String(format: "%.1f", duration * 1000))ms")
    }

    /// Record scroll performance
    public func recordScrollPerformance(velocity: CGFloat, itemCount: Int, fps: Double) {
        let metric = ScrollMetric(
            timestamp: CFAbsoluteTimeGetCurrent(),
            velocity: velocity,
            itemCount: itemCount,
            fps: fps
        )

        scrollMetrics.append(metric)

        // Keep only recent metrics
        let cutoffTime = CFAbsoluteTimeGetCurrent() - 10.0 // Last 10 seconds
        scrollMetrics.removeAll { $0.timestamp < cutoffTime }

        // Check for performance issues
        if fps < configuration.alertThresholds.minimumFPS && itemCount > 100 {
            addAlert(.slowScrolling(itemCount: itemCount, fps: fps))
        }

        // Update current metrics
        if !scrollMetrics.isEmpty {
            currentMetrics.averageScrollFPS = scrollMetrics.map { $0.fps }.reduce(0, +) / Double(scrollMetrics.count)
        }
    }

    /// Record network request performance
    public func recordNetworkRequest(url: String, duration: CFTimeInterval, dataSize: Int64) {
        let metric = NetworkMetric(
            url: url,
            duration: duration,
            dataSize: dataSize,
            timestamp: CFAbsoluteTimeGetCurrent()
        )

        networkRequests.append(metric)

        // Keep only recent requests (last 100)
        if networkRequests.count > 100 {
            networkRequests.removeFirst(networkRequests.count - 100)
        }

        // Check for slow requests
        if duration > configuration.alertThresholds.networkRequestThreshold {
            addAlert(.slowNetworkRequest(url: url, duration: duration))
        }

        // Update current metrics
        updateNetworkMetrics()

        logger.debug("🌐 Network request \(url): \(String(format: "%.1f", duration * 1000))ms, \(dataSize) bytes")
    }

    /// Get performance summary for debugging
    public func getPerformanceSummary() -> PerformanceSummary {
        return PerformanceSummary(
            averageFPS: currentMetrics.currentFPS,
            memoryUsage: currentMetrics.memoryUsage,
            viewTransitionTime: currentMetrics.averageViewTransitionTime,
            networkLatency: currentMetrics.averageNetworkLatency,
            scrollPerformance: currentMetrics.averageScrollFPS,
            activeAlerts: performanceAlerts.count
        )
    }
}

// MARK: - Private Implementation

extension LopanPerformanceProfiler {

    private func setupPerformanceMonitoring() {
        #if DEBUG
        configuration.isDebugMode = true
        #endif
    }

    private func startFrameRateMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(frameRateCallback))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func frameRateCallback() {
        guard let displayLink = displayLink else { return }

        let currentTime = CFAbsoluteTimeGetCurrent()
        frameTimes.append(currentTime)

        // Keep only recent frame times
        if frameTimes.count > configuration.maxFrameHistory {
            frameTimes.removeFirst()
        }

        // Calculate FPS
        if frameTimes.count > 1,
           let lastTime = frameTimes.last,
           let firstTime = frameTimes.first {
            let timeSpan = lastTime - firstTime
            guard timeSpan > 0 else { return } // Avoid division by zero

            let fps = Double(frameTimes.count - 1) / timeSpan
            currentMetrics.currentFPS = fps

            // Check for low FPS
            if fps < configuration.alertThresholds.minimumFPS {
                addAlert(.lowFrameRate(fps: fps))
            }
        }
    }

    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: configuration.memoryCheckInterval, repeats: true) { [weak self] _ in
            self?.updateMemoryMetrics()
        }
    }

    private func updateMemoryMetrics() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / (1024 * 1024)
            currentMetrics.memoryUsage = memoryMB

            // Check for high memory usage
            if memoryMB > configuration.alertThresholds.memoryThreshold {
                addAlert(.highMemoryUsage(usage: memoryMB))
            }
        }
    }

    private func startNetworkMonitoring() {
        // Network monitoring will be integrated with existing network layer
        logger.debug("📡 Network monitoring initialized")
    }

    private func updateNetworkMetrics() {
        if !networkRequests.isEmpty {
            let totalLatency = networkRequests.map { $0.duration }.reduce(0, +)
            currentMetrics.averageNetworkLatency = totalLatency / Double(networkRequests.count)

            let totalBytes = networkRequests.map { $0.dataSize }.reduce(0, +)
            currentMetrics.totalDataTransferred = totalBytes
        }
    }

    private func addAlert(_ alert: PerformanceAlert) {
        // Avoid duplicate alerts
        if !performanceAlerts.contains(where: { $0.id == alert.id }) {
            performanceAlerts.append(alert)

            // Keep only recent alerts (last 10)
            if performanceAlerts.count > 10 {
                performanceAlerts.removeFirst()
            }

            logger.warning("⚠️ Performance alert: \(alert.description)")
        }
    }
}

// MARK: - Data Structures

public struct PerformanceMetrics {
    var currentFPS: Double = 60.0
    var memoryUsage: Double = 0.0 // MB
    var averageViewTransitionTime: Double = 0.0 // seconds
    var averageNetworkLatency: Double = 0.0 // seconds
    var averageScrollFPS: Double = 60.0
    var totalDataTransferred: Int64 = 0 // bytes
    var appLaunchTime: Double = 0.0 // seconds
}

public struct PerformanceSummary {
    let averageFPS: Double
    let memoryUsage: Double
    let viewTransitionTime: Double
    let networkLatency: Double
    let scrollPerformance: Double
    let activeAlerts: Int
}

public struct AlertThresholds {
    var minimumFPS: Double = 55.0
    var memoryThreshold: Double = 200.0 // MB
    var viewTransitionThreshold: Double = 0.3 // seconds
    var networkRequestThreshold: Double = 2.0 // seconds
}

public enum PerformanceAlert: Identifiable {
    case lowFrameRate(fps: Double)
    case highMemoryUsage(usage: Double)
    case slowViewTransition(from: String, to: String, duration: Double)
    case slowNetworkRequest(url: String, duration: Double)
    case slowScrolling(itemCount: Int, fps: Double)

    public var id: String {
        switch self {
        case .lowFrameRate: return "low_fps"
        case .highMemoryUsage: return "high_memory"
        case .slowViewTransition(let from, let to, _): return "slow_transition_\(from)_\(to)"
        case .slowNetworkRequest(let url, _): return "slow_network_\(url.hashValue)"
        case .slowScrolling: return "slow_scroll"
        }
    }

    public var description: String {
        switch self {
        case .lowFrameRate(let fps):
            return "Low frame rate: \(String(format: "%.1f", fps)) FPS"
        case .highMemoryUsage(let usage):
            return "High memory usage: \(String(format: "%.1f", usage)) MB"
        case .slowViewTransition(let from, let to, let duration):
            return "Slow transition \(from)→\(to): \(String(format: "%.1f", duration * 1000))ms"
        case .slowNetworkRequest(let url, let duration):
            return "Slow network request \(url): \(String(format: "%.1f", duration))s"
        case .slowScrolling(let count, let fps):
            return "Slow scrolling with \(count) items: \(String(format: "%.1f", fps)) FPS"
        }
    }
}

private struct NetworkMetric {
    let url: String
    let duration: CFTimeInterval
    let dataSize: Int64
    let timestamp: CFTimeInterval
}

private struct ScrollMetric {
    let timestamp: CFTimeInterval
    let velocity: CGFloat
    let itemCount: Int
    let fps: Double
}

// MARK: - SwiftUI Integration

extension View {
    /// Add performance monitoring to any view
    public func performanceMonitored(identifier: String) -> some View {
        self.onAppear {
            LopanPerformanceProfiler.shared.logger.debug("📱 View appeared: \(identifier)")
        }
        .onDisappear {
            LopanPerformanceProfiler.shared.logger.debug("📱 View disappeared: \(identifier)")
        }
    }

    /// Monitor view transition performance
    public func transitionMonitored(from: String, to: String) -> some View {
        let startTime = CFAbsoluteTimeGetCurrent()

        return self.onAppear {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            LopanPerformanceProfiler.shared.recordViewTransition(
                from: from,
                to: to,
                duration: duration
            )
        }
    }
}

// MARK: - Debug Views

#if DEBUG
public struct PerformanceDebugView: View {
    @StateObject private var profiler = LopanPerformanceProfiler.shared

    public var body: some View {
        NavigationStack {
            List {
                Section("Current Metrics") {
                    PerformanceMetricRow(title: "Frame Rate", value: "\(String(format: "%.1f", profiler.currentMetrics.currentFPS)) FPS")
                    PerformanceMetricRow(title: "Memory Usage", value: "\(String(format: "%.1f", profiler.currentMetrics.memoryUsage)) MB")
                    PerformanceMetricRow(title: "View Transitions", value: "\(String(format: "%.1f", profiler.currentMetrics.averageViewTransitionTime * 1000)) ms")
                    PerformanceMetricRow(title: "Network Latency", value: "\(String(format: "%.1f", profiler.currentMetrics.averageNetworkLatency * 1000)) ms")
                    PerformanceMetricRow(title: "Scroll Performance", value: "\(String(format: "%.1f", profiler.currentMetrics.averageScrollFPS)) FPS")
                }

                if !profiler.performanceAlerts.isEmpty {
                    Section("Performance Alerts") {
                        ForEach(profiler.performanceAlerts) { alert in
                            Text(alert.description)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Performance Monitor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(profiler.isMonitoring ? "Stop" : "Start") {
                        if profiler.isMonitoring {
                            profiler.stopMonitoring()
                        } else {
                            profiler.startMonitoring()
                        }
                    }
                }
            }
        }
    }
}

private struct PerformanceMetricRow: View {
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
    PerformanceDebugView()
}
#endif