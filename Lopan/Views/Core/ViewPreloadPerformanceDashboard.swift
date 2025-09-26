//
//  ViewPreloadPerformanceDashboard.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import SwiftUI
import Charts
import os

/// Comprehensive performance dashboard for view preloading system
public struct ViewPreloadPerformanceDashboard: View {
    
    @StateObject private var preloadManager = ViewPreloadManager.shared
    @StateObject private var poolManager = ViewPoolManager.shared
    @StateObject private var preloadController = ViewPreloadController.shared
    @StateObject private var navigationController = SmartNavigationController()
    
    @State private var selectedTab: DashboardTab = .overview
    @State private var refreshTimer: Timer?
    @State private var performanceData = PerformanceData()
    @State private var isMonitoring = false
    @State private var testResults: [PerformanceTest] = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Overview Tab
                OverviewTab(performanceData: performanceData)
                    .tabItem {
                        Label("概览", systemImage: "chart.pie.fill")
                    }
                    .tag(DashboardTab.overview)
                
                // Cache Performance Tab
                CachePerformanceTab(
                    preloadManager: preloadManager,
                    poolManager: poolManager
                )
                .tabItem {
                    Label("缓存", systemImage: "externaldrive.fill")
                }
                .tag(DashboardTab.cache)
                
                // Navigation Performance Tab
                NavigationPerformanceTab(navigationController: navigationController)
                    .tabItem {
                        Label("导航", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .tag(DashboardTab.navigation)
                
                // System Health Tab
                SystemHealthTab(performanceData: performanceData)
                    .tabItem {
                        Label("系统", systemImage: "cpu.fill")
                    }
                    .tag(DashboardTab.system)
                
                // Testing Tab
                TestingTab(
                    testResults: $testResults,
                    onRunTests: performPerformanceTests
                )
                .tabItem {
                    Label("测试", systemImage: "testtube.2")
                }
                .tag(DashboardTab.testing)
            }
            .navigationTitle("视图预载性能仪表板")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: toggleMonitoring) {
                        Image(systemName: isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(isMonitoring ? LopanColors.error : LopanColors.success)
                    }
                    .accessibilityLabel(isMonitoring ? "停止监控" : "开始监控")
                    
                    Button("刷新") {
                        refreshData()
                    }
                }
            }
        }
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
    }
    
    // MARK: - Data Management
    
    private func refreshData() {
        let cacheStats = preloadManager.getCacheStatistics()
        let cacheMetrics = preloadManager.getDetailedMetrics()
        let poolStats = poolManager.getPoolStatistics()
        let poolMemory = poolManager.getMemoryUsage()
        let navMetrics = navigationController.getNavigationMetrics()
        let controllerReport = preloadController.getPerformanceReport()
        
        performanceData = PerformanceData(
            cacheHitRate: cacheStats.hitRate,
            poolReuseRate: poolStats.reuseRate,
            navigationPreloadRate: navMetrics.preloadHitRate,
            totalMemoryMB: cacheMetrics.totalMemoryMB + poolMemory.totalMemoryMB,
            averageNavigationTime: navMetrics.averageNavigationTime,
            systemEfficiency: (cacheStats.efficiency + poolStats.efficiency + controllerReport.efficiency) / 3.0,
            recommendations: generateRecommendations(cacheStats, poolStats, navMetrics)
        )
    }
    
    private func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
        isMonitoring.toggle()
    }
    
    private func startMonitoring() {
        refreshData()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refreshData()
        }
        isMonitoring = true
    }
    
    private func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        isMonitoring = false
    }
    
    private func generateRecommendations(
        _ cacheStats: ViewPreloadManager.CacheStatistics,
        _ poolStats: ViewPoolManager.PoolStatistics,
        _ navMetrics: SmartNavigationController.NavigationMetrics
    ) -> [String] {
        var recommendations: [String] = []
        
        if cacheStats.hitRate < 0.7 {
            recommendations.append("缓存命中率偏低，建议增加预加载频率")
        }
        
        if poolStats.reuseRate < 0.5 {
            recommendations.append("视图复用率偏低，考虑调整池大小")
        }
        
        if navMetrics.averageNavigationTime > 0.1 {
            recommendations.append("导航响应时间较慢，建议优化预加载策略")
        }
        
        if performanceData.totalMemoryMB > 50 {
            recommendations.append("内存使用过高，考虑减少缓存大小")
        }
        
        if recommendations.isEmpty {
            recommendations.append("系统性能良好，继续保持当前配置")
        }
        
        return recommendations
    }
    
    // MARK: - Performance Testing
    
    private func performPerformanceTests() async {
        var results: [PerformanceTest] = []
        
        // Test 1: Cache Performance
        results.append(await testCachePerformance())
        
        // Test 2: Pool Performance
        results.append(await testPoolPerformance())
        
        // Test 3: Navigation Performance
        results.append(await testNavigationPerformance())
        
        // Test 4: Memory Usage
        results.append(await testMemoryUsage())
        
        // Test 5: Concurrent Performance
        results.append(await testConcurrentPerformance())
        
        testResults = results
    }
    
    private func testCachePerformance() async -> PerformanceTest {
        let startTime = Date()
        
        // Simulate cache operations
        var hitCount = 0
        let totalOperations = 100
        
        for i in 0..<totalOperations {
            let key = "test_view_\(i % 10)" // Simulate 10 different views
            if await preloadManager.getCachedView(forKey: key) != nil {
                hitCount += 1
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let hitRate = Double(hitCount) / Double(totalOperations)
        
        return PerformanceTest(
            name: "缓存性能测试",
            duration: duration,
            passed: hitRate >= 0.5 && duration < 0.1,
            metrics: [
                "操作数量": "\(totalOperations)",
                "命中率": "\(String(format: "%.1f", hitRate * 100))%",
                "执行时间": "\(String(format: "%.0f", duration * 1000))ms"
            ]
        )
    }
    
    private func testPoolPerformance() async -> PerformanceTest {
        let startTime = Date()
        
        // Test view pool reuse
        var reuseCount = 0
        let totalOperations = 50
        
        for _ in 0..<totalOperations {
            let (_, isReused) = await poolManager.getPooledView(viewType: TestView.self) {
                TestView()
            }
            if isReused {
                reuseCount += 1
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let reuseRate = Double(reuseCount) / Double(totalOperations)
        
        return PerformanceTest(
            name: "视图池性能测试",
            duration: duration,
            passed: reuseRate >= 0.3 && duration < 0.05,
            metrics: [
                "操作数量": "\(totalOperations)",
                "复用率": "\(String(format: "%.1f", reuseRate * 100))%",
                "执行时间": "\(String(format: "%.0f", duration * 1000))ms"
            ]
        )
    }
    
    private func testNavigationPerformance() async -> PerformanceTest {
        let startTime = Date()
        
        // Simulate navigation operations
        let totalNavigations = 20
        var preloadedCount = 0
        
        for i in 0..<totalNavigations {
            let viewKey = "nav_test_\(i)"
            if await preloadManager.getCachedView(forKey: viewKey) != nil {
                preloadedCount += 1
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let preloadRate = Double(preloadedCount) / Double(totalNavigations)
        
        return PerformanceTest(
            name: "导航性能测试",
            duration: duration,
            passed: preloadRate >= 0.4 && duration < 0.02,
            metrics: [
                "导航数量": "\(totalNavigations)",
                "预载率": "\(String(format: "%.1f", preloadRate * 100))%",
                "执行时间": "\(String(format: "%.0f", duration * 1000))ms"
            ]
        )
    }
    
    private func testMemoryUsage() async -> PerformanceTest {
        let startTime = Date()
        
        let cacheMemory = preloadManager.getDetailedMetrics().totalMemoryMB
        let poolMemory = poolManager.getMemoryUsage().totalMemoryMB
        let totalMemory = cacheMemory + poolMemory
        
        let duration = Date().timeIntervalSince(startTime)
        let memoryEfficient = totalMemory < 50.0 // Under 50MB threshold
        
        return PerformanceTest(
            name: "内存使用测试",
            duration: duration,
            passed: memoryEfficient,
            metrics: [
                "缓存内存": "\(String(format: "%.1f", cacheMemory))MB",
                "池内存": "\(String(format: "%.1f", poolMemory))MB",
                "总内存": "\(String(format: "%.1f", totalMemory))MB",
                "状态": memoryEfficient ? "正常" : "过高"
            ]
        )
    }
    
    private func testConcurrentPerformance() async -> PerformanceTest {
        let startTime = Date()
        
        // Test concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let key = "concurrent_test_\(i)"
                    _ = await preloadManager.getCachedView(forKey: key)
                    
                    let (_, _) = await poolManager.getPooledView(viewType: TestView.self) {
                        TestView()
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return PerformanceTest(
            name: "并发性能测试",
            duration: duration,
            passed: duration < 0.1, // Under 100ms for 10 concurrent operations
            metrics: [
                "并发任务": "10",
                "执行时间": "\(String(format: "%.0f", duration * 1000))ms",
                "状态": duration < 0.1 ? "优秀" : "需优化"
            ]
        )
    }
}

// MARK: - Supporting Types

enum DashboardTab: String, CaseIterable {
    case overview = "overview"
    case cache = "cache"
    case navigation = "navigation"
    case system = "system"
    case testing = "testing"
}

struct PerformanceData {
    var cacheHitRate: Double = 0.0
    var poolReuseRate: Double = 0.0
    var navigationPreloadRate: Double = 0.0
    var totalMemoryMB: Double = 0.0
    var averageNavigationTime: TimeInterval = 0.0
    var systemEfficiency: Double = 0.0
    var recommendations: [String] = []
}

struct PerformanceTest {
    let name: String
    let duration: TimeInterval
    let passed: Bool
    let metrics: [String: String]
}

struct TestView: View {
    var body: some View {
        Text("Test View")
    }
}

// MARK: - Tab Views

struct OverviewTab: View {
    let performanceData: PerformanceData
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ViewMetricCard(
                    title: "缓存命中率",
                    value: "\(String(format: "%.1f", performanceData.cacheHitRate * 100))%",
                    color: performanceData.cacheHitRate >= 0.8 ? LopanColors.success : LopanColors.warning,
                    icon: "externaldrive.fill"
                )
                
                ViewMetricCard(
                    title: "视图复用率",
                    value: "\(String(format: "%.1f", performanceData.poolReuseRate * 100))%",
                    color: performanceData.poolReuseRate >= 0.6 ? LopanColors.success : LopanColors.warning,
                    icon: "arrow.triangle.2.circlepath"
                )
                
                ViewMetricCard(
                    title: "导航预载率",
                    value: "\(String(format: "%.1f", performanceData.navigationPreloadRate * 100))%",
                    color: performanceData.navigationPreloadRate >= 0.7 ? LopanColors.success : LopanColors.warning,
                    icon: "arrow.right.circle.fill"
                )
                
                ViewMetricCard(
                    title: "内存使用",
                    value: "\(String(format: "%.1f", performanceData.totalMemoryMB))MB",
                    color: performanceData.totalMemoryMB < 50 ? LopanColors.success : LopanColors.error,
                    icon: "memorychip.fill"
                )
                
                ViewMetricCard(
                    title: "系统效率",
                    value: "\(String(format: "%.1f", performanceData.systemEfficiency * 100))%",
                    color: performanceData.systemEfficiency >= 0.8 ? LopanColors.success : LopanColors.warning,
                    icon: "speedometer"
                )
                
                ViewMetricCard(
                    title: "导航响应",
                    value: "\(String(format: "%.0f", performanceData.averageNavigationTime * 1000))ms",
                    color: performanceData.averageNavigationTime < 0.05 ? LopanColors.success : LopanColors.warning,
                    icon: "timer"
                )
            }
            .padding()
            
            // Recommendations
            if !performanceData.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("优化建议")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(performanceData.recommendations, id: \.self) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(LopanColors.warning)
                            Text(recommendation)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
        }
        .navigationTitle("性能概览")
    }
}

struct CachePerformanceTab: View {
    @ObservedObject var preloadManager: ViewPreloadManager
    @ObservedObject var poolManager: ViewPoolManager
    
    var body: some View {
        PreloadPerformanceView()
            .navigationTitle("缓存性能")
    }
}

struct NavigationPerformanceTab: View {
    @ObservedObject var navigationController: SmartNavigationController
    
    var body: some View {
        NavigationPerformanceView()
            .navigationTitle("导航性能")
    }
}

struct SystemHealthTab: View {
    let performanceData: PerformanceData
    
    var body: some View {
        List {
            Section("系统状态") {
                HealthRow(
                    title: "缓存系统",
                    status: performanceData.cacheHitRate >= 0.8 ? .healthy : .warning,
                    details: "命中率: \(String(format: "%.1f", performanceData.cacheHitRate * 100))%"
                )
                
                HealthRow(
                    title: "视图池",
                    status: performanceData.poolReuseRate >= 0.6 ? .healthy : .warning,
                    details: "复用率: \(String(format: "%.1f", performanceData.poolReuseRate * 100))%"
                )
                
                HealthRow(
                    title: "导航系统",
                    status: performanceData.navigationPreloadRate >= 0.7 ? .healthy : .warning,
                    details: "预载率: \(String(format: "%.1f", performanceData.navigationPreloadRate * 100))%"
                )
                
                HealthRow(
                    title: "内存使用",
                    status: performanceData.totalMemoryMB < 50 ? .healthy : .critical,
                    details: "使用量: \(String(format: "%.1f", performanceData.totalMemoryMB))MB"
                )
            }
        }
        .navigationTitle("系统健康")
    }
}

struct TestingTab: View {
    @Binding var testResults: [PerformanceTest]
    let onRunTests: () async -> Void
    
    @State private var isRunningTests = false
    
    var body: some View {
        VStack {
            Button(action: runTests) {
                HStack {
                    if isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isRunningTests ? "测试中..." : "运行性能测试")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRunningTests ? LopanColors.secondary : LopanColors.primary)
                .foregroundColor(LopanColors.textPrimary)
                .cornerRadius(10)
            }
            .disabled(isRunningTests)
            .padding()
            
            List(testResults, id: \.name) { test in
                TestResultRow(test: test)
            }
        }
        .navigationTitle("性能测试")
    }
    
    private func runTests() {
        guard !isRunningTests else { return }
        isRunningTests = true
        
        Task {
            await onRunTests()
            isRunningTests = false
        }
    }
}

// MARK: - Helper Views

struct ViewMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(LopanColors.backgroundTertiary)
        .cornerRadius(12)
    }
}

struct HealthRow: View {
    let title: String
    let status: HealthStatus
    let details: String
    
    enum HealthStatus {
        case healthy, warning, critical
        
        var color: Color {
            switch self {
            case .healthy: return LopanColors.success
            case .warning: return LopanColors.warning
            case .critical: return LopanColors.error
            }
        }
        
        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TestResultRow: View {
    let test: PerformanceTest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(test.passed ? LopanColors.success : LopanColors.error)
                
                Text(test.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(String(format: "%.0f", test.duration * 1000))ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(test.metrics.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(test.metrics[key] ?? "")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 4)
    }
}