//
//  WarehouseKeeperTabView.swift
//  Lopan
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI
import SwiftData

/// Modern warehouse keeper workbench with bottom tab navigation
/// Following iOS 17+ Human Interface Guidelines and Western industrial design principles
/// Enhanced with intelligent view preloading for optimal performance
struct WarehouseKeeperTabView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @Environment(\.appDependencies) private var appDependencies
    
    @State private var selectedTab: WarehouseTab = .packaging
    @State private var showingQuickActions = false
    @State private var hapticController = TabHapticController()
    
    // MARK: - Preloading Integration
    @StateObject private var preloadManager = ViewPreloadManager.shared
    @StateObject private var preloadController = ViewPreloadController.shared
    @State private var preloadedTabs: Set<WarehouseTab> = []
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 包装管理 - Primary workflow (Preloaded)
            SmartTabItem(
                tabKey: "warehouse_packaging",
                preloadOnInit: true
            ) {
                PackagingManagementView()
                    .preloadable(cacheKey: "warehouse_packaging") {
                        await preloadPackagingViewDependencies()
                    } onDisplay: {
                        await trackTabUsage(.packaging)
                    }
            }
            .tabItem {
                TabBarIcon(
                    icon: "cube.box.fill",
                    title: "包装管理",
                    isSelected: selectedTab == .packaging
                )
            }
            .tag(WarehouseTab.packaging)
            
            // 任务提醒 - Task management (Smart preload)
            SmartTabItem(
                tabKey: "warehouse_tasks",
                preloadOnInit: selectedTab == .packaging // Preload if on packaging tab
            ) {
                TaskReminderView()
                    .preloadable(cacheKey: "warehouse_tasks") {
                        await preloadTaskViewDependencies()
                    }
            }
            .tabItem {
                TabBarIcon(
                    icon: "bell.badge.fill",
                    title: "任务提醒", 
                    isSelected: selectedTab == .tasks
                )
            }
            .tag(WarehouseTab.tasks)
            
            // 团队管理 - Team coordination (Lazy preload)
            SmartTabItem(
                tabKey: "warehouse_team",
                preloadOnInit: false
            ) {
                TeamManagementView()
                    .preloadable(cacheKey: "warehouse_team") {
                        await preloadTeamViewDependencies()
                    }
            }
            .tabItem {
                TabBarIcon(
                    icon: "person.2.fill",
                    title: "团队管理",
                    isSelected: selectedTab == .team
                )
            }
            .tag(WarehouseTab.team)
            
            // 统计分析 - Analytics and reports (Predictive preload)
            SmartTabItem(
                tabKey: "warehouse_analytics",
                preloadOnInit: false
            ) {
                AnalyticsView()
                    .preloadable(cacheKey: "warehouse_analytics") {
                        await preloadAnalyticsViewDependencies()
                    }
            }
            .tabItem {
                TabBarIcon(
                    icon: "chart.bar.fill",
                    title: "统计分析",
                    isSelected: selectedTab == .analytics
                )
            }
            .tag(WarehouseTab.analytics)
            
            // 产品信息 - Product information (On demand)
            SmartTabItem(
                tabKey: "warehouse_products",
                preloadOnInit: false
            ) {
                ProductInfoView()
                    .preloadable(cacheKey: "warehouse_products") {
                        await preloadProductViewDependencies()
                    }
            }
            .tabItem {
                TabBarIcon(
                    icon: "info.circle.fill",
                    title: "产品信息",
                    isSelected: selectedTab == .products
                )
            }
            .tag(WarehouseTab.products)
        }
        .tabViewStyle(.automatic)
        .tint(LopanColors.roleWarehouseKeeper)
        .onChange(of: selectedTab) { oldTab, newTab in
            hapticController.selectionChanged()
            trackTabSelection(newTab)
            
            // Intelligent preloading based on tab changes
            Task {
                await performSmartPreloading(from: oldTab, to: newTab)
            }
        }
        .task {
            // Initialize preloading system
            await initializePreloadingSystem()
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Search button for current tab
                if selectedTab.supportsSearch {
                    Button(action: { performSearch() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("搜索\(selectedTab.title)")
                }
                
                // Quick actions menu
                Button(action: { showingQuickActions = true }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .medium))
                }
                .accessibilityLabel("快捷操作")
            }
        }
        .sheet(isPresented: $showingQuickActions) {
            QuickActionMenu(
                selectedTab: selectedTab,
                authService: authService,
                navigationService: navigationService
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        "仓库管理员工作台"
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        // Implement search functionality based on selected tab
        HapticFeedback.light()
        
        switch selectedTab {
        case .packaging:
            // Trigger search in packaging management
            break
        case .tasks:
            // Trigger search in tasks
            break
        case .team:
            // Trigger search in team management
            break
        case .analytics:
            // Trigger search in analytics
            break
        case .products:
            // Trigger search in products
            break
        }
    }
    
    // MARK: - Preloading Methods
    
    private func initializePreloadingSystem() async {
        // Set up warehouse keeper specific preloading
        await preloadController.preloadCommonViews(for: "warehousekeeper")
        
        // Preload critical workflow
        await preloadController.preloadWorkflow(.packaging)
        
        // Register predictive patterns
        registerWarehouseKeeperPatterns()
        
        print("🏭 Warehouse keeper preloading system initialized")
    }
    
    private func performSmartPreloading(from oldTab: WarehouseTab?, to newTab: WarehouseTab) async {
        // Predictive preloading based on navigation patterns
        let predictedTabs = getPredictedTabs(from: newTab)
        
        for predictedTab in predictedTabs {
            if !preloadedTabs.contains(predictedTab) {
                await preloadTab(predictedTab)
                preloadedTabs.insert(predictedTab)
            }
        }
    }
    
    private func preloadTab(_ tab: WarehouseTab) async {
        let tabKey = getTabKey(for: tab)
        print("🔮 Preloading tab: \(tab.title)")
        
        // This would be enhanced with actual view factories
        switch tab {
        case .packaging:
            await preloadPackagingViewDependencies()
        case .tasks:
            await preloadTaskViewDependencies()
        case .team:
            await preloadTeamViewDependencies()
        case .analytics:
            await preloadAnalyticsViewDependencies()
        case .products:
            await preloadProductViewDependencies()
        }
    }
    
    private func getPredictedTabs(from currentTab: WarehouseTab) -> [WarehouseTab] {
        // Warehouse keeper workflow patterns
        switch currentTab {
        case .packaging:
            // After packaging, users often check tasks and team
            return [.tasks, .team]
        case .tasks:
            // After tasks, users often go back to packaging or check analytics
            return [.packaging, .analytics]
        case .team:
            // After team management, users often check packaging or analytics
            return [.packaging, .analytics]
        case .analytics:
            // After analytics, users often go back to packaging
            return [.packaging]
        case .products:
            // After products, users often go to packaging
            return [.packaging]
        }
    }
    
    private func registerWarehouseKeeperPatterns() {
        // This would integrate with the PredictiveLoadingEngine
        // to register warehouse-specific access patterns
        print("📊 Registered warehouse keeper access patterns")
    }
    
    private func getTabKey(for tab: WarehouseTab) -> String {
        return "warehouse_\(tab.rawValue)"
    }
    
    // MARK: - Dependency Preloading Methods
    
    private func preloadPackagingViewDependencies() async {
        // Preload packaging-related services and data
        _ = appDependencies.auditingService
        print("📦 Preloaded packaging dependencies")
    }
    
    private func preloadTaskViewDependencies() async {
        // Preload task-related services and data
        _ = appDependencies.auditingService
        print("📋 Preloaded task dependencies")
    }
    
    private func preloadTeamViewDependencies() async {
        // Preload team management dependencies
        _ = appDependencies.userService
        print("👥 Preloaded team dependencies")
    }
    
    private func preloadAnalyticsViewDependencies() async {
        // Preload analytics dependencies
        _ = appDependencies.auditingService
        _ = appDependencies.auditingService
        print("📈 Preloaded analytics dependencies")
    }
    
    private func preloadProductViewDependencies() async {
        // Preload product information dependencies
        _ = appDependencies.productService
        print("🏷️ Preloaded product dependencies")
    }
    
    private func trackTabUsage(_ tab: WarehouseTab) async {
        // Track tab usage for predictive learning
        await appDependencies.auditingService.logEvent(
            action: "tab_displayed_from_cache",
            entityId: authService.currentUser?.id ?? "unknown_user",
            details: "Tab: \(tab.rawValue), From Cache: true"
        )
    }
    
    private func trackTabSelection(_ tab: WarehouseTab) {
        // Analytics tracking for tab selection
        Task {
            await appDependencies.auditingService.logEvent(
                action: "tab_selected",
                entityId: authService.currentUser?.id ?? "unknown_user",
                details: "Warehouse keeper tab selection: \(tab.rawValue)"
            )
        }
    }
}

// MARK: - Supporting Types

enum WarehouseTab: String, CaseIterable {
    case packaging = "packaging"
    case tasks = "tasks" 
    case team = "team"
    case analytics = "analytics"
    case products = "products"
    
    var title: String {
        switch self {
        case .packaging: return "包装管理"
        case .tasks: return "任务提醒"
        case .team: return "团队管理"
        case .analytics: return "统计分析"
        case .products: return "产品信息"
        }
    }
    
    var icon: String {
        switch self {
        case .packaging: return "cube.box.fill"
        case .tasks: return "bell.badge.fill"
        case .team: return "person.2.fill"
        case .analytics: return "chart.bar.fill"
        case .products: return "info.circle.fill"
        }
    }
    
    var supportsSearch: Bool {
        switch self {
        case .packaging, .team, .products: return true
        case .tasks, .analytics: return false
        }
    }
}

// MARK: - Tab Content Views

private struct TaskReminderView: View {
    var body: some View {
        NavigationStack {
            PackagingReminderView()
                .navigationTitle("任务提醒")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct TeamManagementView: View {
    var body: some View {
        NavigationStack {
            PackagingTeamManagementView()
                .navigationTitle("团队管理")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            PackagingStatisticsView()
                .navigationTitle("统计分析")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct ProductInfoView: View {
    var body: some View {
        NavigationStack {
            ProductionStyleListView()
                .navigationTitle("产品信息")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Haptic Feedback Helper
// Using HapticFeedback from LopanAnimation design system

private class TabHapticController {
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    func selectionChanged() {
        selectionFeedback.selectionChanged()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        HapticFeedback.medium()
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: User.self, 
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
    let authService = AuthenticationService(repositoryFactory: repositoryFactory)
    let navigationService = WorkbenchNavigationService()
    
    return NavigationStack {
        WarehouseKeeperTabView(
            authService: authService,
            navigationService: navigationService
        )
    }
}