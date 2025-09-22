//
//  SmartNavigationView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import SwiftUI
import Combine
import os

// MARK: - Smart Navigation View with Preloading

/// Enhanced NavigationView with intelligent view preloading and caching
public struct SmartNavigationView<Content: View>: View {
    private let content: () -> Content
    private let navigationTitle: String?
    private let preloadStrategy: NavigationPreloadStrategy
    
    @StateObject private var navigationController = SmartNavigationController()
    @StateObject private var preloadManager = ViewPreloadManager.shared
    
    public enum NavigationPreloadStrategy {
        case none           // No preloading
        case onAppear       // Preload when view appears
        case predictive     // Use AI prediction
        case aggressive     // Preload all linked views
    }
    
    public init(
        title: String? = nil,
        preloadStrategy: NavigationPreloadStrategy = .predictive,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.navigationTitle = title
        self.preloadStrategy = preloadStrategy
        self.content = content
    }
    
    public var body: some View {
        NavigationStack {
            content()
                .navigationTitle(navigationTitle ?? "")
                .environmentObject(navigationController)
                .task {
                    await setupPreloading()
                }
        }
        .environmentObject(navigationController)
    }
    
    private func setupPreloading() async {
        switch preloadStrategy {
        case .none:
            break
        case .onAppear:
            await navigationController.preloadCommonViews()
        case .predictive:
            await navigationController.startPredictivePreloading()
        case .aggressive:
            await navigationController.preloadAllLinkedViews()
        }
    }
}

// MARK: - Smart Navigation Controller

@MainActor
public final class SmartNavigationController: ObservableObject {
    
    // MARK: - Navigation State
    @Published var navigationPath = NavigationPath()
    @Published var isPreloading = false
    @Published var preloadedViews: Set<String> = []
    
    // MARK: - Services
    private let preloadManager = ViewPreloadManager.shared
    private let poolManager = ViewPoolManager.shared
    private let logger = Logger(subsystem: "com.lopan.navigation", category: "smart")
    
    // MARK: - Navigation History
    private var navigationHistory: [NavigationEvent] = []
    private var preloadingTimer: Timer?
    
    private struct NavigationEvent {
        let sourceView: String
        let targetView: String
        let timestamp: Date
        let navigationTime: TimeInterval
        let wasPreloaded: Bool
    }
    
    // MARK: - Public API
    
    /// Navigate to a view with smart preloading
    public func navigate<T: View>(
        to viewBuilder: @escaping () -> T,
        cacheKey: String,
        preloadNext: [String] = []
    ) {
        let startTime = Date()
        
        // Check if view is already preloaded
        if let cachedView = preloadManager.getCachedView(forKey: cacheKey, context: .navigation) {
            navigationPath.append(cacheKey)
            recordNavigation(to: cacheKey, wasPreloaded: true, navigationTime: Date().timeIntervalSince(startTime))
            
            // Preload predicted next views
            Task {
                await preloadPredictedViews(from: cacheKey, suggested: preloadNext)
            }
        } else {
            // Create and cache the view
            let view = viewBuilder()
            preloadManager.registerView(view, forKey: cacheKey, context: .navigation)
            navigationPath.append(cacheKey)
            
            recordNavigation(to: cacheKey, wasPreloaded: false, navigationTime: Date().timeIntervalSince(startTime))
            
            // Preload next views after successful navigation
            Task {
                await preloadPredictedViews(from: cacheKey, suggested: preloadNext)
            }
        }
        
        logger.info("📱 Navigated to: \(cacheKey)")
    }
    
    /// Preload common views based on current context
    public func preloadCommonViews() async {
        isPreloading = true
        defer { isPreloading = false }
        
        let commonViews = getCommonViewsToPreload()
        
        for viewInfo in commonViews {
            if !preloadedViews.contains(viewInfo.key) {
                // This would be implemented by specific view factories
                preloadedViews.insert(viewInfo.key)
                logger.info("🔮 Preloaded common view: \(viewInfo.key)")
            }
        }
    }
    
    /// Start predictive preloading based on user patterns
    public func startPredictivePreloading() async {
        await preloadCommonViews()
        
        // Start periodic predictive preloading
        preloadingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPredictivePreload()
            }
        }
        
        logger.info("🧠 Started predictive navigation preloading")
    }
    
    /// Preload all linked views (aggressive strategy)
    public func preloadAllLinkedViews() async {
        isPreloading = true
        defer { isPreloading = false }
        
        let allViews = getAllPossibleViews()
        
        for viewKey in allViews {
            if !preloadedViews.contains(viewKey) {
                // This would need specific implementations
                preloadedViews.insert(viewKey)
                logger.info("🚀 Aggressively preloaded: \(viewKey)")
            }
        }
    }
    
    /// Get navigation performance metrics
    public func getNavigationMetrics() -> NavigationMetrics {
        let recentEvents = navigationHistory.suffix(50)
        let preloadedNavigations = recentEvents.filter { $0.wasPreloaded }
        let averageNavigationTime = recentEvents.isEmpty ? 0 : 
                                  recentEvents.map { $0.navigationTime }.reduce(0, +) / Double(recentEvents.count)
        
        return NavigationMetrics(
            totalNavigations: recentEvents.count,
            preloadedNavigations: preloadedNavigations.count,
            preloadHitRate: recentEvents.isEmpty ? 0 : Double(preloadedNavigations.count) / Double(recentEvents.count),
            averageNavigationTime: averageNavigationTime,
            preloadedViews: preloadedViews.count,
            isPerformingWell: preloadedNavigations.count >= recentEvents.count / 2
        )
    }
    
    public struct NavigationMetrics {
        public let totalNavigations: Int
        public let preloadedNavigations: Int
        public let preloadHitRate: Double
        public let averageNavigationTime: TimeInterval
        public let preloadedViews: Int
        public let isPerformingWell: Bool
    }
    
    // MARK: - Private Implementation
    
    private func recordNavigation(to viewKey: String, wasPreloaded: Bool, navigationTime: TimeInterval) {
        let event = NavigationEvent(
            sourceView: getCurrentView(),
            targetView: viewKey,
            timestamp: Date(),
            navigationTime: navigationTime,
            wasPreloaded: wasPreloaded
        )
        
        navigationHistory.append(event)
        
        // Limit history size
        if navigationHistory.count > 200 {
            navigationHistory.removeFirst(navigationHistory.count - 150)
        }
    }
    
    private func getCurrentView() -> String {
        // This would be enhanced to track current view
        return "unknown"
    }
    
    private func preloadPredictedViews(from currentView: String, suggested: [String]) async {
        var viewsToPreload = suggested
        
        // Add AI predictions
        let predictions = getPredictedNextViews(from: currentView)
        viewsToPreload.append(contentsOf: predictions)
        
        for viewKey in Set(viewsToPreload).prefix(3) { // Limit to top 3
            if !preloadedViews.contains(viewKey) {
                await preloadSpecificView(viewKey)
                preloadedViews.insert(viewKey)
            }
        }
    }
    
    private func getPredictedNextViews(from currentView: String) -> [String] {
        // Analyze navigation history to predict next views
        let recentHistory = navigationHistory.suffix(20)
        var predictions: [String: Int] = [:]
        
        for i in 0..<recentHistory.count - 1 {
            let events = Array(recentHistory)
            if events[i].targetView == currentView {
                let nextView = events[i + 1].targetView
                predictions[nextView, default: 0] += 1
            }
        }
        
        return predictions.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }
    
    private func performPredictivePreload() async {
        // This would use machine learning to predict next views
        let currentContext = getCurrentNavigationContext()
        let predictions = getPredictionsForContext(currentContext)
        
        for prediction in predictions.prefix(2) {
            if !preloadedViews.contains(prediction.viewKey) && prediction.confidence > 0.7 {
                await preloadSpecificView(prediction.viewKey)
                preloadedViews.insert(prediction.viewKey)
                logger.info("🔮 Predictively preloaded: \(prediction.viewKey)")
            }
        }
    }
    
    private func getCurrentNavigationContext() -> NavigationContext {
        // Analyze current state to determine context
        return NavigationContext(
            currentView: getCurrentView(),
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            recentViews: Array(navigationHistory.suffix(5).map { $0.targetView })
        )
    }
    
    private func getPredictionsForContext(_ context: NavigationContext) -> [ViewPrediction] {
        // This would use sophisticated prediction algorithms
        return []
    }
    
    private struct NavigationContext {
        let currentView: String
        let timeOfDay: Int
        let recentViews: [String]
    }
    
    private struct ViewPrediction {
        let viewKey: String
        let confidence: Double
        let reason: String
    }
    
    private func preloadSpecificView(_ viewKey: String) async {
        // This would need specific view factory implementations
        logger.debug("🔄 Preloading specific view: \(viewKey)")
        
        // Placeholder - would need actual view factories
        switch viewKey {
        case "customer_detail":
            // Preload customer detail view
            break
        case "product_management":
            // Preload product management view
            break
        case "out_of_stock_dashboard":
            // Preload out of stock dashboard
            break
        default:
            break
        }
    }
    
    private func getCommonViewsToPreload() -> [ViewInfo] {
        return [
            ViewInfo(key: "customer_list", priority: .high),
            ViewInfo(key: "product_list", priority: .high),
            ViewInfo(key: "out_of_stock_list", priority: .normal),
            ViewInfo(key: "search_results", priority: .normal)
        ]
    }
    
    private func getAllPossibleViews() -> [String] {
        return [
            "customer_list", "customer_detail", "customer_edit",
            "product_list", "product_detail", "product_edit",
            "out_of_stock_list", "out_of_stock_detail", "out_of_stock_create",
            "packaging_list", "packaging_detail", "packaging_edit",
            "team_management", "analytics_dashboard", "settings"
        ]
    }
    
    private struct ViewInfo {
        let key: String
        let priority: PreloadPriority
    }
    
    deinit {
        preloadingTimer?.invalidate()
        logger.info("🧠 Smart navigation controller deinitialized")
    }
}

// MARK: - Smart Navigation Link

/// Enhanced NavigationLink with intelligent preloading
public struct SmartNavigationLink<Label: View, Destination: View>: View {
    private let destination: () -> Destination
    private let label: () -> Label
    private let cacheKey: String
    private let preloadTrigger: PreloadTrigger
    private let nextViews: [String]
    
    @EnvironmentObject private var navigationController: SmartNavigationController
    @State private var hasPreloaded = false
    
    public enum PreloadTrigger {
        case onAppear
        case onHover
        case immediate
        case manual
        case onLongPress
    }
    
    public init(
        cacheKey: String,
        preloadTrigger: PreloadTrigger = .onAppear,
        predictedNext: [String] = [],
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.cacheKey = cacheKey
        self.preloadTrigger = preloadTrigger
        self.nextViews = predictedNext
        self.destination = destination
        self.label = label
    }
    
    public var body: some View {
        Button {
            navigationController.navigate(
                to: destination,
                cacheKey: cacheKey,
                preloadNext: nextViews
            )
        } label: {
            label()
        }
        .onAppear {
            if preloadTrigger == .onAppear {
                triggerPreload()
            }
        }
        .onHover { isHovering in
            if preloadTrigger == .onHover && isHovering {
                triggerPreload()
            }
        }
        .onLongPressGesture {
            if preloadTrigger == .onLongPress {
                triggerPreload()
            }
        }
        .task {
            if preloadTrigger == .immediate {
                triggerPreload()
            }
        }
    }
    
    private func triggerPreload() {
        guard !hasPreloaded else { return }
        hasPreloaded = true
        
        Task {
            await navigationController.preloadCommonViews()
        }
    }
}

// MARK: - Navigation Performance View

/// Debug view for monitoring navigation performance
public struct NavigationPerformanceView: View {
    @StateObject private var navigationController = SmartNavigationController()
    @State private var metrics: SmartNavigationController.NavigationMetrics?
    @State private var refreshTimer: Timer?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Navigation Performance") {
                    if let metrics = metrics {
                        MetricRow(
                            title: "Total Navigations",
                            value: "\(metrics.totalNavigations)"
                        )
                        
                        MetricRow(
                            title: "Preload Hit Rate",
                            value: "\(String(format: "%.1f", metrics.preloadHitRate * 100))%"
                        )
                        .foregroundColor(metrics.preloadHitRate >= 0.7 ? .green : .orange)
                        
                        MetricRow(
                            title: "Average Nav Time",
                            value: "\(String(format: "%.0f", metrics.averageNavigationTime * 1000))ms"
                        )
                        
                        MetricRow(
                            title: "Preloaded Views",
                            value: "\(metrics.preloadedViews)"
                        )
                        
                        MetricRow(
                            title: "Performance",
                            value: metrics.isPerformingWell ? "Good" : "Needs Improvement"
                        )
                        .foregroundColor(metrics.isPerformingWell ? .green : .orange)
                    }
                }
                
                Section("Actions") {
                    Button("Start Predictive Preloading") {
                        Task {
                            await navigationController.startPredictivePreloading()
                        }
                    }
                    
                    Button("Preload Common Views") {
                        Task {
                            await navigationController.preloadCommonViews()
                        }
                    }
                    
                    Button("Refresh Metrics") {
                        refreshMetrics()
                    }
                }
            }
            .navigationTitle("Navigation Monitor")
            .onAppear {
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }
    
    private func refreshMetrics() {
        metrics = navigationController.getNavigationMetrics()
    }
    
    private func startAutoRefresh() {
        refreshMetrics()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            refreshMetrics()
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

// MARK: - View Extensions

public extension View {
    /// Enable smart navigation for this view
    func smartNavigation(
        title: String? = nil,
        preloadStrategy: SmartNavigationView<AnyView>.NavigationPreloadStrategy = .predictive
    ) -> some View {
        SmartNavigationView(
            title: title,
            preloadStrategy: preloadStrategy
        ) {
            AnyView(self)
        }
    }
    
    /// Create a smart navigation link
    func smartNavigationLink<Destination: View>(
        cacheKey: String,
        preloadTrigger: SmartNavigationLink<AnyView, Destination>.PreloadTrigger = .onAppear,
        predictedNext: [String] = [],
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        SmartNavigationLink(
            cacheKey: cacheKey,
            preloadTrigger: preloadTrigger,
            predictedNext: predictedNext,
            destination: destination
        ) {
            AnyView(self)
        }
    }
}