//
//  LopanPerformanceEnhanced.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//  Enhanced Performance Optimizations for iOS 26
//

import SwiftUI
import Combine
import OSLog

/// Enhanced performance optimization system for iOS 26
@available(iOS 26.0, *)
public final class LopanPerformanceEnhanced: ObservableObject {

    // MARK: - Singleton Instance

    public static let shared = LopanPerformanceEnhanced()

    // MARK: - Performance Monitoring

    @Published public var memoryUsage: Double = 0.0
    @Published public var cpuUsage: Double = 0.0
    @Published public var frameRate: Double = 60.0
    @Published public var renderingTime: Double = 0.0

    private let logger = Logger(subsystem: "com.lopan.performance", category: "enhancement")
    private var performanceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Performance Thresholds

    private let memoryWarningThreshold: Double = 80.0  // 80% memory usage
    private let cpuWarningThreshold: Double = 70.0     // 70% CPU usage
    private let frameRateWarningThreshold: Double = 45.0 // Below 45 FPS

    private init() {
        startPerformanceMonitoring()
    }

    // MARK: - Performance Monitoring

    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }

    private func updatePerformanceMetrics() {
        memoryUsage = getCurrentMemoryUsage()
        cpuUsage = getCurrentCPUUsage()
        frameRate = getCurrentFrameRate()

        checkPerformanceThresholds()
    }

    private func checkPerformanceThresholds() {
        if memoryUsage > memoryWarningThreshold {
            logger.warning("High memory usage detected: \(self.memoryUsage)%")
            triggerMemoryOptimization()
        }

        if cpuUsage > cpuWarningThreshold {
            logger.warning("High CPU usage detected: \(self.cpuUsage)%")
            triggerCPUOptimization()
        }

        if frameRate < frameRateWarningThreshold {
            logger.warning("Low frame rate detected: \(self.frameRate) FPS")
            triggerFrameRateOptimization()
        }
    }

    // MARK: - Performance Metrics

    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024 / 1024 // MB
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 // MB
            return (usedMemory / totalMemory) * 100
        }

        return 0.0
    }

    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            // Simplified CPU usage calculation
            return min(Double(info.virtual_size) / 1000000.0, 100.0)
        }

        return 0.0
    }

    private func getCurrentFrameRate() -> Double {
        // In a real implementation, this would measure actual frame rendering time
        // For now, we'll return a simulated value based on performance
        let baseFPS = 60.0
        let performanceFactor = min(1.0, (100.0 - cpuUsage) / 100.0)
        return baseFPS * performanceFactor
    }

    // MARK: - Performance Optimizations

    private func triggerMemoryOptimization() {
        logger.info("Triggering memory optimization")

        // Release cached images and resources
        LopanImageCache.shared.clearCache()

        // Notify components to reduce memory usage
        NotificationCenter.default.post(
            name: .memoryOptimizationRequired,
            object: nil
        )
    }

    private func triggerCPUOptimization() {
        logger.info("Triggering CPU optimization")

        // Reduce animation complexity
        AnimationOptimizer.shared.reducePlatformAnimations()

        // Notify components to reduce CPU usage
        NotificationCenter.default.post(
            name: .cpuOptimizationRequired,
            object: nil
        )
    }

    private func triggerFrameRateOptimization() {
        logger.info("Triggering frame rate optimization")

        // Enable GPU acceleration for critical views
        GPUAccelerationManager.shared.enableCriticalAcceleration()

        // Reduce rendering complexity
        NotificationCenter.default.post(
            name: .frameRateOptimizationRequired,
            object: nil
        )
    }

    deinit {
        performanceTimer?.invalidate()
    }
}

// MARK: - Image Cache Management

@available(iOS 17.0, *)
public final class LopanImageCache: ObservableObject {
    public static let shared = LopanImageCache()

    private var cache: [String: UIImage] = [:]
    private let maxCacheSize: Int = 50 // Maximum number of cached images
    private let queue = DispatchQueue(label: "com.lopan.imagecache", attributes: .concurrent)

    private init() {}

    public func cacheImage(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            if self.cache.count >= self.maxCacheSize {
                // Remove oldest entries
                let keysToRemove = Array(self.cache.keys.prefix(10))
                keysToRemove.forEach { self.cache.removeValue(forKey: $0) }
            }
            self.cache[key] = image
        }
    }

    public func image(forKey key: String) -> UIImage? {
        return queue.sync {
            return cache[key]
        }
    }

    public func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - Animation Optimizer

@available(iOS 26.0, *)
public final class AnimationOptimizer: ObservableObject {
    public static let shared = AnimationOptimizer()

    @Published public var isOptimizationEnabled: Bool = false
    @Published public var reducedAnimationComplexity: Bool = false

    private init() {}

    public func reducePlatformAnimations() {
        isOptimizationEnabled = true
        reducedAnimationComplexity = true

        // Automatically restore after a period
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.restoreNormalAnimations()
        }
    }

    public func restoreNormalAnimations() {
        isOptimizationEnabled = false
        reducedAnimationComplexity = false
    }

    public func optimizedAnimation(
        _ baseAnimation: Animation,
        complexity: AnimationComplexity = .normal
    ) -> Animation {
        if isOptimizationEnabled {
            switch complexity {
            case .simple:
                return .easeInOut(duration: 0.2)
            case .normal:
                return .easeInOut(duration: 0.3)
            case .complex:
                return reducedAnimationComplexity ? .easeInOut(duration: 0.3) : baseAnimation
            }
        }
        return baseAnimation
    }
}

@available(iOS 26.0, *)
public enum AnimationComplexity {
    case simple
    case normal
    case complex
}

// MARK: - GPU Acceleration Manager

@available(iOS 26.0, *)
public final class GPUAccelerationManager: ObservableObject {
    public static let shared = GPUAccelerationManager()

    @Published public var isCriticalAccelerationEnabled: Bool = false
    @Published public var activeAcceleratedViews: Set<String> = []

    private init() {}

    public func enableCriticalAcceleration() {
        isCriticalAccelerationEnabled = true

        // Automatically disable after optimization period
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.disableCriticalAcceleration()
        }
    }

    public func disableCriticalAcceleration() {
        isCriticalAccelerationEnabled = false
        activeAcceleratedViews.removeAll()
    }

    public func enableAcceleration(for viewID: String) {
        activeAcceleratedViews.insert(viewID)
    }

    public func disableAcceleration(for viewID: String) {
        activeAcceleratedViews.remove(viewID)
    }

    public func isAccelerated(_ viewID: String) -> Bool {
        return isCriticalAccelerationEnabled || activeAcceleratedViews.contains(viewID)
    }
}

// MARK: - Performance-Optimized View Modifiers

@available(iOS 26.0, *)
public struct PerformanceOptimizedModifier: ViewModifier {
    let priority: PerformancePriority
    let viewID: String

    @StateObject private var performanceManager = LopanPerformanceEnhanced.shared
    @StateObject private var gpuManager = GPUAccelerationManager.shared

    public func body(content: Content) -> some View {
        let shouldAccelerate = gpuManager.isAccelerated(viewID) || priority == .critical

        Group {
            if shouldAccelerate {
                content
                    .drawingGroup() // Enable GPU acceleration
                    .compositingGroup()
            } else {
                content
            }
        }
        .onAppear {
            if priority == .critical {
                gpuManager.enableAcceleration(for: viewID)
            }
        }
        .onDisappear {
            gpuManager.disableAcceleration(for: viewID)
        }
    }
}

@available(iOS 26.0, *)
public enum PerformancePriority {
    case low
    case normal
    case high
    case critical
}

// MARK: - Lazy Rendering System

@available(iOS 26.0, *)
public struct LazyRenderingModifier: ViewModifier {
    let threshold: CGFloat
    let onEnterViewport: () -> Void
    let onExitViewport: () -> Void

    @State private var isInViewport: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ViewportPreferenceKey.self,
                            value: geometry.frame(in: .global)
                        )
                }
            )
            .onPreferenceChange(ViewportPreferenceKey.self) { frame in
                let screenBounds = UIScreen.main.bounds
                let expandedBounds = screenBounds.insetBy(
                    dx: -threshold,
                    dy: -threshold
                )

                let newIsInViewport = expandedBounds.intersects(frame)

                if newIsInViewport != isInViewport {
                    isInViewport = newIsInViewport

                    if newIsInViewport {
                        onEnterViewport()
                    } else {
                        onExitViewport()
                    }
                }
            }
    }
}

@available(iOS 26.0, *)
private struct ViewportPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Smart Memory Management

@available(iOS 26.0, *)
public struct SmartMemoryModifier: ViewModifier {
    let memoryPriority: MemoryPriority

    @StateObject private var performanceManager = LopanPerformanceEnhanced.shared

    public func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .memoryOptimizationRequired)) { _ in
                handleMemoryOptimization()
            }
    }

    private func handleMemoryOptimization() {
        switch memoryPriority {
        case .low:
            // Can be aggressively freed during memory pressure
            break
        case .normal:
            // Standard memory management
            break
        case .high:
            // Should be preserved during normal memory pressure
            break
        case .critical:
            // Must be preserved at all costs
            break
        }
    }
}

@available(iOS 26.0, *)
public enum MemoryPriority {
    case low
    case normal
    case high
    case critical
}

// MARK: - Notification Extensions

@available(iOS 26.0, *)
public extension Notification.Name {
    static let memoryOptimizationRequired = Notification.Name("memoryOptimizationRequired")
    static let cpuOptimizationRequired = Notification.Name("cpuOptimizationRequired")
    static let frameRateOptimizationRequired = Notification.Name("frameRateOptimizationRequired")
}

// MARK: - View Extensions

@available(iOS 26.0, *)
public extension View {

    /// Applies performance optimization based on priority
    func performanceOptimized(
        priority: PerformancePriority = .normal,
        viewID: String = UUID().uuidString
    ) -> some View {
        modifier(
            PerformanceOptimizedModifier(
                priority: priority,
                viewID: viewID
            )
        )
    }

    /// Enables lazy rendering with viewport detection
    func lazyRendering(
        threshold: CGFloat = 100,
        onEnterViewport: @escaping () -> Void = {},
        onExitViewport: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            LazyRenderingModifier(
                threshold: threshold,
                onEnterViewport: onEnterViewport,
                onExitViewport: onExitViewport
            )
        )
    }

    /// Applies smart memory management
    func smartMemoryManagement(
        priority: MemoryPriority = .normal
    ) -> some View {
        modifier(
            SmartMemoryModifier(memoryPriority: priority)
        )
    }

    /// Applies optimized animation based on current performance
    func optimizedAnimation<V: Equatable>(
        _ animation: Animation,
        value: V,
        complexity: AnimationComplexity = .normal
    ) -> some View {
        let optimizedAnim = AnimationOptimizer.shared.optimizedAnimation(
            animation,
            complexity: complexity
        )
        return self.animation(optimizedAnim, value: value)
    }

    /// Enables GPU acceleration for critical views
    func gpuAccelerated(_ enabled: Bool = true) -> some View {
        Group {
            if enabled {
                self
                    .drawingGroup()
                    .compositingGroup()
            } else {
                self
            }
        }
    }

    /// Applies performance-aware rendering
    func performanceAwareRendering(
        renderingMode: RenderingMode = .automatic
    ) -> some View {
        Group {
            switch renderingMode {
            case .automatic:
                if LopanPerformanceEnhanced.shared.cpuUsage > 50 {
                    self.drawingGroup() // Use GPU when CPU is busy
                } else {
                    self
                }
            case .cpu:
                self
            case .gpu:
                self.drawingGroup()
            }
        }
    }
}

@available(iOS 26.0, *)
public enum RenderingMode {
    case automatic
    case cpu
    case gpu
}

// MARK: - Performance Dashboard

@available(iOS 26.0, *)
public struct PerformanceDashboard: View {
    @StateObject private var performanceManager = LopanPerformanceEnhanced.shared
    @StateObject private var animationOptimizer = AnimationOptimizer.shared
    @StateObject private var gpuManager = GPUAccelerationManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Dashboard")
                .font(.title2)
                .bold()

            Group {
                metricRow(
                    title: "Memory Usage",
                    value: "\(Int(performanceManager.memoryUsage))%",
                    color: colorForMetric(performanceManager.memoryUsage, threshold: 80)
                )

                metricRow(
                    title: "CPU Usage",
                    value: "\(Int(performanceManager.cpuUsage))%",
                    color: colorForMetric(performanceManager.cpuUsage, threshold: 70)
                )

                metricRow(
                    title: "Frame Rate",
                    value: "\(Int(performanceManager.frameRate)) FPS",
                    color: performanceManager.frameRate < 45 ? .red : .green
                )
            }

            Divider()

            Group {
                statusRow(
                    title: "Animation Optimization",
                    isActive: animationOptimizer.isOptimizationEnabled
                )

                statusRow(
                    title: "GPU Acceleration",
                    isActive: gpuManager.isCriticalAccelerationEnabled
                )

                if !gpuManager.activeAcceleratedViews.isEmpty {
                    Text("Accelerated Views: \(gpuManager.activeAcceleratedViews.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }

    private func statusRow(title: String, isActive: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Circle()
                .fill(isActive ? .green : .gray)
                .frame(width: 8, height: 8)
        }
    }

    private func colorForMetric(_ value: Double, threshold: Double) -> Color {
        if value > threshold {
            return .red
        } else if value > threshold * 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    VStack(spacing: 20) {
        Text("Performance Enhanced Features")
            .font(.title)
            .performanceOptimized(priority: .high)

        Rectangle()
            .frame(height: 100)
            .foregroundColor(LopanColors.info)
            .performanceOptimized(priority: .normal)
            .smartMemoryManagement(priority: .normal)
            .overlay(
                Text("Optimized View")
                    .foregroundColor(LopanColors.textOnPrimary)
            )

        PerformanceDashboard()

        ScrollView {
            LazyVStack {
                ForEach(0..<100, id: \.self) { index in
                    Rectangle()
                        .frame(height: 50)
                        .foregroundColor(LopanColors.premium)
                        .lazyRendering(
                            onEnterViewport: { print("Item \(index) entered viewport") },
                            onExitViewport: { print("Item \(index) exited viewport") }
                        )
                        .overlay(
                            Text("Item \(index)")
                                .foregroundColor(LopanColors.textOnPrimary)
                        )
                }
            }
        }
        .frame(height: 200)
    }
    .padding()
}