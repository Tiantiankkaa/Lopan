//
//  PreloadableView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import SwiftUI
import Combine
import os

// MARK: - PreloadableView Protocol

/// Protocol for views that can be preloaded and cached
public protocol PreloadableView: View {
    /// Unique identifier for caching this view
    static var cacheKey: String { get }
    
    /// Priority level for preloading this view
    static var preloadPriority: PreloadPriority { get }
    
    /// Dependencies that should be loaded before this view
    var preloadDependencies: [String] { get }
    
    /// Called when the view is being preloaded (not displayed)
    func onPreload() async
    
    /// Called when the view is first displayed from cache
    func onDisplayFromCache() async
    
    /// Estimated memory usage in MB for cache management
    var estimatedMemoryMB: Double { get }
    
    /// Whether this view should be cached after first creation
    var shouldCache: Bool { get }
}

// MARK: - Default Implementations

public extension PreloadableView {
    static var preloadPriority: PreloadPriority { .normal }
    
    var preloadDependencies: [String] { [] }
    
    func onPreload() async {
        // Default empty implementation
    }
    
    func onDisplayFromCache() async {
        // Default empty implementation
    }
    
    var estimatedMemoryMB: Double { 1.0 }
    
    var shouldCache: Bool { true }
}

// MARK: - PreloadableViewModifier

/// View modifier that integrates views with the preload system
public struct PreloadableViewModifier: ViewModifier {
    let cacheKey: String
    let onPreload: () async -> Void
    let onDisplay: () async -> Void
    
    @StateObject private var preloadManager = ViewPreloadManager.shared
    @State private var hasDisplayed = false
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    if !hasDisplayed {
                        await onDisplay()
                        hasDisplayed = true
                    }
                }
            }
            .task {
                await onPreload()
            }
    }
}

public extension View {
    /// Make any view preloadable with custom configuration
    func preloadable(
        cacheKey: String,
        onPreload: @escaping () async -> Void = {},
        onDisplay: @escaping () async -> Void = {}
    ) -> some View {
        self.modifier(PreloadableViewModifier(
            cacheKey: cacheKey,
            onPreload: onPreload,
            onDisplay: onDisplay
        ))
    }
}

// MARK: - Smart Preloaded Navigation Link

/// NavigationLink that automatically preloads its destination
public struct PreloadedNavigationLink<Label: View, Destination: View>: View {
    private let destination: () -> Destination
    private let label: () -> Label
    private let cacheKey: String
    private let preloadTrigger: PreloadTrigger
    
    @StateObject private var preloadManager = ViewPreloadManager.shared
    @State private var hasPreloaded = false
    
    public enum PreloadTrigger {
        case onAppear
        case onHover
        case immediate
        case manual
    }
    
    public init(
        cacheKey: String,
        preloadTrigger: PreloadTrigger = .onAppear,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.cacheKey = cacheKey
        self.preloadTrigger = preloadTrigger
        self.destination = destination
        self.label = label
    }
    
    public var body: some View {
        NavigationLink {
            // Check cache first
            if let cachedView = preloadManager.getCachedView(forKey: cacheKey, context: .navigation) {
                cachedView
            } else {
                destination()
                    .onAppear {
                        // Register the view for next time
                        preloadManager.registerView(destination(), forKey: cacheKey, context: .navigation)
                    }
            }
        } label: {
            label()
        }
        .onAppear {
            if preloadTrigger == .onAppear {
                preloadDestination()
            }
        }
        .onHover { hovering in
            if preloadTrigger == .onHover && hovering {
                preloadDestination()
            }
        }
        .task {
            if preloadTrigger == .immediate {
                preloadDestination()
            }
        }
    }
    
    private func preloadDestination() {
        guard !hasPreloaded else { return }
        hasPreloaded = true
        
        preloadManager.preloadView(
            destination(),
            forKey: cacheKey,
            priority: .normal
        )
    }
}

// MARK: - Smart Tab Item

/// Tab item that preloads its content intelligently
public struct SmartTabItem<Content: View>: View {
    private let content: () -> Content
    private let tabKey: String
    private let preloadOnInit: Bool
    
    @StateObject private var preloadManager = ViewPreloadManager.shared
    @State private var isPreloaded = false
    
    public init(
        tabKey: String,
        preloadOnInit: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tabKey = tabKey
        self.preloadOnInit = preloadOnInit
        self.content = content
    }
    
    public var body: some View {
        Group {
            if let cachedView = preloadManager.getCachedView(forKey: tabKey, context: .tabSwitch) {
                cachedView
            } else {
                content()
                    .onAppear {
                        // Register for caching
                        preloadManager.registerView(content(), forKey: tabKey, context: .tabSwitch)
                    }
            }
        }
        .task {
            if preloadOnInit && !isPreloaded {
                preloadContent()
            }
        }
    }
    
    private func preloadContent() {
        guard !isPreloaded else { return }
        isPreloaded = true
        
        preloadManager.preloadView(
            content(),
            forKey: tabKey,
            priority: .high
        )
    }
}

// MARK: - View Preload Controller

/// Controller for managing view preloading at the app level
@MainActor
public final class ViewPreloadController: ObservableObject {
    
    public static let shared = ViewPreloadController()
    
    private let preloadManager = ViewPreloadManager.shared
    private let logger = Logger(subsystem: "com.lopan.views", category: "controller")
    
    // MARK: - Preload Strategies
    
    public enum PreloadStrategy {
        case aggressive  // Preload many views immediately
        case balanced    // Preload based on patterns
        case conservative // Only preload on demand
        case adaptive    // Adjust based on device performance
    }
    
    @Published public var currentStrategy: PreloadStrategy = .balanced
    @Published public var isEnabled: Bool = true
    
    private var preloadedViews: Set<String> = []
    
    private init() {
        setupIntegrations()
    }
    
    private func setupIntegrations() {
        // Future integration points
        logger.info("🎮 ViewPreloadController initialized")
    }
    
    // MARK: - Public Interface
    
    /// Preload common views based on user role
    public func preloadCommonViews(for userRole: String) async {
        guard isEnabled else { return }
        
        let commonViews = getCommonViewsForRole(userRole)
        
        for viewInfo in commonViews {
            if !preloadedViews.contains(viewInfo.key) {
                // This would need specific view factory implementations
                logger.info("📲 Scheduling preload for \(viewInfo.key)")
                preloadedViews.insert(viewInfo.key)
            }
        }
    }
    
    /// Preload views for a specific workflow
    public func preloadWorkflow(_ workflow: WorkflowType) async {
        guard isEnabled else { return }
        
        let workflowViews = getViewsForWorkflow(workflow)
        
        for viewKey in workflowViews {
            if !preloadedViews.contains(viewKey) {
                logger.info("🔄 Preloading workflow view: \(viewKey)")
                preloadedViews.insert(viewKey)
            }
        }
    }
    
    /// Get preload performance metrics
    public func getPerformanceReport() -> PreloadPerformanceReport {
        let stats = preloadManager.getCacheStatistics()
        let metrics = preloadManager.getDetailedMetrics()
        
        return PreloadPerformanceReport(
            cacheHitRate: stats.hitRate,
            totalPreloadedViews: preloadedViews.count,
            memoryUsageMB: metrics.totalMemoryMB,
            efficiency: stats.efficiency,
            strategy: currentStrategy
        )
    }
    
    /// Clear all preloaded views
    public func clearAllPreloads() {
        preloadManager.clearCache()
        preloadedViews.removeAll()
        logger.info("🧹 All preloads cleared")
    }
    
    // MARK: - Private Helpers
    
    private func getCommonViewsForRole(_ role: String) -> [ViewInfo] {
        switch role.lowercased() {
        case "salesperson":
            return [
                ViewInfo(key: "customer_dashboard", priority: .high),
                ViewInfo(key: "out_of_stock_dashboard", priority: .high),
                ViewInfo(key: "product_management", priority: .normal)
            ]
        case "warehousekeeper":
            return [
                ViewInfo(key: "packaging_management", priority: .high),
                ViewInfo(key: "task_reminders", priority: .high),
                ViewInfo(key: "team_management", priority: .normal)
            ]
        case "workshopmanager":
            return [
                ViewInfo(key: "production_dashboard", priority: .high),
                ViewInfo(key: "machine_management", priority: .high),
                ViewInfo(key: "batch_processing", priority: .normal)
            ]
        default:
            return []
        }
    }
    
    private func getViewsForWorkflow(_ workflow: WorkflowType) -> [String] {
        switch workflow {
        case .customerOutOfStock:
            return ["customer_list", "out_of_stock_detail", "product_selector"]
        case .packaging:
            return ["packaging_list", "add_record", "team_view"]
        case .production:
            return ["batch_list", "machine_detail", "production_config"]
        }
    }
    
    private struct ViewInfo {
        let key: String
        let priority: PreloadPriority
    }
}

// MARK: - Supporting Types

public enum WorkflowType {
    case customerOutOfStock
    case packaging
    case production
}

public struct PreloadPerformanceReport {
    public let cacheHitRate: Double
    public let totalPreloadedViews: Int
    public let memoryUsageMB: Double
    public let efficiency: Double
    public let strategy: ViewPreloadController.PreloadStrategy
    
    public var isPerformingWell: Bool {
        return cacheHitRate >= 0.8 && efficiency >= 0.7
    }
}

// MARK: - View Extensions for Easy Integration

public extension View {
    /// Register this view with the preload system
    func registerForPreload(
        key: String,
        priority: PreloadPriority = .normal,
        dependencies: [String] = []
    ) -> some View {
        self.onAppear {
            Task {
                let manager = ViewPreloadManager.shared
                manager.registerView(AnyView(self), forKey: key)
            }
        }
    }
    
    /// Enable smart caching for this view
    func cached(key: String) -> some View {
        self.onAppear {
            let manager = ViewPreloadManager.shared
            manager.registerView(AnyView(self), forKey: key)
        }
    }
}

// MARK: - Performance Monitoring View

/// Debug view for monitoring preload performance
public struct PreloadPerformanceView: View {
    @StateObject private var controller = ViewPreloadController.shared
    @StateObject private var manager = ViewPreloadManager.shared
    @State private var performanceReport: PreloadPerformanceReport?
    @State private var detailedMetrics: ViewPreloadManager.DetailedMetrics?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Performance Overview") {
                    if let report = performanceReport {
                        HStack {
                            Text("Cache Hit Rate")
                            Spacer()
                            Text("\(String(format: "%.1f", report.cacheHitRate * 100))%")
                                .foregroundColor(report.cacheHitRate >= 0.8 ? .green : .orange)
                        }
                        
                        HStack {
                            Text("Memory Usage")
                            Spacer()
                            Text("\(String(format: "%.1f", report.memoryUsageMB))MB")
                        }
                        
                        HStack {
                            Text("Preloaded Views")
                            Spacer()
                            Text("\(report.totalPreloadedViews)")
                        }
                        
                        HStack {
                            Text("Efficiency")
                            Spacer()
                            Text("\(String(format: "%.1f", report.efficiency * 100))%")
                                .foregroundColor(report.efficiency >= 0.7 ? .green : .orange)
                        }
                    }
                }
                
                Section("Cache Statistics") {
                    if let metrics = detailedMetrics {
                        HStack {
                            Text("Cache Size")
                            Spacer()
                            Text("\(metrics.cacheSize) views")
                        }
                        
                        HStack {
                            Text("Average Access Count")
                            Spacer()
                            Text(String(format: "%.1f", metrics.averageAccessCount))
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Clear Cache") {
                        controller.clearAllPreloads()
                        updateMetrics()
                    }
                    .foregroundColor(.red)
                    
                    Button("Refresh Metrics") {
                        updateMetrics()
                    }
                }
            }
            .navigationTitle("Preload Performance")
            .onAppear {
                updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        performanceReport = controller.getPerformanceReport()
        detailedMetrics = manager.getDetailedMetrics()
    }
}