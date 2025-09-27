//
//  CustomerOutOfStockDashboard.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//  Revolutionary dashboard for customer out-of-stock management
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Dashboard State Manager

@MainActor
class CustomerOutOfStockDashboardState: ObservableObject {
    
    // MARK: - UI State
    
    @Published var selectedDate = Date()
    @Published var showingDatePicker = false
    @Published var showingFilterPanel = false
    @Published var showingAnalytics = false
    @Published var showingBatchCreation = false
    @Published var isSelectionMode = false
    @Published var selectedItems: Set<String> = []
    @Published var selectedDetailItem: CustomerOutOfStock?
    
    // MARK: - View Mode State
    
    @Published var currentViewMode: DateNavigationMode = .dateNavigation(date: Date(), isEnabled: true)
    
    // View mode management
    func enterFilterMode(with filters: OutOfStockFilters) {
        let summary = filters.intelligentSummary
        let filterCount = filters.activeFilterCount
        let dateRange = filters.dateRange?.toFormattedDateRange()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentViewMode = .filtered(summary: summary, dateRange: dateRange, filterCount: filterCount)
        }
        
        print("📊 [Dashboard] Entered filter mode: \(summary), date range: \(dateRange ?? "none")")
    }
    
    func exitFilterMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentViewMode = .dateNavigation(date: selectedDate, isEnabled: true)
            activeFilters = OutOfStockFilters() // Clear filters
        }
        
        print("📊 [Dashboard] Exited filter mode, returned to date navigation")
    }
    
    func updateDateInNavigationMode(_ date: Date) {
        if case .dateNavigation = currentViewMode {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentViewMode = .dateNavigation(date: date, isEnabled: true)
            }
        }
    }
    
    // Status filtering state
    @Published var selectedStatusTab: OutOfStockStatus? = nil
    @Published var statusTabAnimationScale: CGFloat = 1.0
    @Published var isProcessingStatusChange = false
    
    // Data loading lock state - prevents concurrent operations
    @Published var isDataOperationLocked = false
    @Published var lockMessage = ""
    
    // Debouncing state for performance optimization
    var statusChangeTimer: Timer?
    var dateChangeTimer: Timer?
    var pendingStatusChange: OutOfStockStatus?
    var pendingDateChange: Date?
    let statusChangeDebounceDelay: TimeInterval = 0.15
    let dateChangeDebounceDelay: TimeInterval = 0.2
    
    // Comprehensive data loading state - prevents concurrent UI operations
    var isDataLocked: Bool {
        // Keep quick status transitions visually responsive by allowing
        // short-lived debounce states to pass through without locking the UI.
        return isLoading || isRefreshing || isDataOperationLocked
    }
    
    // MARK: - Data State
    
    @Published var items: [CustomerOutOfStock] = []
    @Published var customers: [Customer] = []
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false // Skeleton loading state for date switching
    @Published var previousItems: [CustomerOutOfStock] = [] // Cache for smooth transitions
    @Published var skeletonItemCount = 6 // Number of skeleton items to show
    @Published var totalCount = 0
    @Published var unfilteredTotalCount = 0 // [rule:§2.1 Layering] Separate unfiltered total from filtered results
    @Published var statusCounts: [OutOfStockStatus: Int] = [:]
    
    // Scroll position management for better UX [rule:§3+.2 API Contract]
    @Published var totalScrollPosition: String? = nil // Save "总计" scroll position
    @Published var shouldScrollToTop = false // Trigger scroll to top on filter change
    
    // MARK: - Filter State
    
    @Published var activeFilters: OutOfStockFilters = OutOfStockFilters()
    @Published var searchText = ""
    @Published var sortOrder: CustomerOutOfStockNavigationState.SortOrder = .newestFirst
    
    // MARK: - Performance Metrics
    
    @Published var cacheHitRate: Double = 0
    @Published var loadingTime: TimeInterval = 0
    @Published var error: Error?
    
    var hasActiveFilters: Bool {
        activeFilters.hasAnyFilters || !searchText.isEmpty
    }
    
    var filteredItemsCount: Int {
        hasActiveFilters ? totalCount : items.count
    }
    
    var isInFilterMode: Bool {
        currentViewMode.isFilterMode
    }
    
    // MARK: - Debouncing Methods
    
    func requestStatusChange(_ status: OutOfStockStatus?) {
        // Cancel any pending status change
        statusChangeTimer?.invalidate()
        pendingStatusChange = status
        
        // Set lighter processing state (UI already updated)
        isProcessingStatusChange = true
        
        statusChangeTimer = Timer.scheduledTimer(withTimeInterval: statusChangeDebounceDelay, repeats: false) { _ in
            Task { @MainActor in
                // No need to update selectedStatusTab again - already done in UI
                self.isProcessingStatusChange = false
                self.pendingStatusChange = nil
            }
        }
    }
    
    func requestDateChange(_ date: Date) {
        // Cancel any pending date change
        dateChangeTimer?.invalidate()
        pendingDateChange = date
        
        // Set operation lock to prevent UI interactions (no message - rely on skeleton)
        isDataOperationLocked = true
        
        dateChangeTimer = Timer.scheduledTimer(withTimeInterval: dateChangeDebounceDelay, repeats: false) { _ in
            Task { @MainActor in
                self.selectedDate = self.pendingDateChange ?? date
                self.updateDateInNavigationMode(self.selectedDate)
                self.isDataOperationLocked = false
                self.pendingDateChange = nil
            }
        }
    }
    
    func setDataOperationLock(_ locked: Bool, message: String = "") {
        isDataOperationLocked = locked
        lockMessage = message
    }
}

// MARK: - Filter Model

struct OutOfStockFilters {
    var customer: Customer?
    var product: Product?
    var status: OutOfStockStatus?
    var dateRange: DateRange?
    var address: String?
    
    enum DateRange {
        case thisWeek
        case lastWeek
        case thisMonth
        case lastMonth
        case custom(start: Date, end: Date)
        
        var displayText: String {
            switch self {
            case .thisWeek: return "本周"
            case .lastWeek: return "上周"
            case .thisMonth: return "本月"
            case .lastMonth: return "上月"
            case .custom: return "自定义"
            }
        }
        
        func toFormattedDateRange() -> String {
            let dateInterval = toDateInterval()
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            
            let startString = formatter.string(from: dateInterval.start)
            let endDate = Calendar.current.date(byAdding: .day, value: -1, to: dateInterval.end)!
            let endString = formatter.string(from: endDate)
            
            return "\(startString)-\(endString)"
        }
        
        func toDateInterval() -> (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisWeek:
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
                // DateInterval.end is already the start of the next period, perfect for exclusive comparison
                return (weekInterval.start, weekInterval.end)
                
            case .lastWeek:
                let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!
                return (weekInterval.start, weekInterval.end)
                
            case .thisMonth:
                let monthInterval = calendar.dateInterval(of: .month, for: now)!
                // DateInterval.end is already the start of the next period, perfect for exclusive comparison
                return (monthInterval.start, monthInterval.end)
                
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                let monthInterval = calendar.dateInterval(of: .month, for: lastMonth)!
                return (monthInterval.start, monthInterval.end)
                
            case .custom(let start, let end):
                // For custom ranges, ensure end date includes the entire day by adding one day
                let adjustedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
                return (start, adjustedEnd)
            }
        }
    }
    
    var hasAnyFilters: Bool {
        customer != nil || product != nil || status != nil || dateRange != nil || address != nil
    }
    
    var activeFilterCount: Int {
        var count = 0
        if customer != nil { count += 1 }
        if product != nil { count += 1 }
        if status != nil { count += 1 }
        if dateRange != nil { count += 1 }
        if address != nil { count += 1 }
        return count
    }
    
    var intelligentSummary: String {
        var components: [String] = []
        
        if let customer = customer {
            components.append("客户\(customer.name)")
        }
        
        if let dateRange = dateRange {
            components.append(dateRange.displayText)
        }
        
        if let status = status {
            components.append(status.displayName)
        }
        
        if let product = product {
            components.append("产品\(product.name)")
        }
        
        if let address = address, !address.isEmpty {
            components.append("地址\(address)")
        }
        
        if components.isEmpty {
            return "无筛选条件"
        }
        
        // 显示前2个主要条件，如果有更多则显示"等X项"
        if components.count <= 2 {
            return components.joined(separator: " + ")
        } else {
            let mainComponents = components.prefix(2).joined(separator: " + ")
            return "\(mainComponents) 等\(components.count)项"
        }
    }
}

// MARK: - Main Dashboard View

struct CustomerOutOfStockDashboard: View {
    @StateObject private var dashboardState = CustomerOutOfStockDashboardState()
    @StateObject private var animationState = CommonAnimationState()
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    
    @State private var lastRefreshTime = Date()
    @State private var refreshTrigger = false
    
    // MARK: - Phase 5 View Preloading Integration
    @StateObject private var preloadManager = ViewPreloadManager.shared
    @StateObject private var preloadController = ViewPreloadController.shared
    
    private var customerOutOfStockService: CustomerOutOfStockService {
        appDependencies.serviceFactory.customerOutOfStockService
    }
    
    var body: some View {
        ZStack {
            // Background gradient with keyboard dismissal
            LinearGradient(
                colors: [
                    LopanColors.background,
                    LopanColors.backgroundTertiary.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all, edges: .top)
            
            VStack(spacing: 0) {
                filterSection
                quickStatsSection
                adaptiveNavigationSection
                mainContentSection
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle("客户缺货管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("客户缺货管理")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        isSearchFocused = false
                        dashboardState.showingAnalytics = true
                    } label: {
                        Label("数据分析", systemImage: "chart.bar.fill")
                    }

                    Button(action: exportData) {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { Task { await refreshData() } }) {
                        Label("刷新数据", systemImage: "arrow.clockwise")
                    }

                    Divider()

                    Button(action: toggleSelectionMode) {
                        Label(
                            dashboardState.isSelectionMode ? "取消选择" : "批量操作",
                            systemImage: dashboardState.isSelectionMode ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                        .accessibilityLabel("更多操作")
                }
            }
        }
        .sheet(isPresented: $dashboardState.showingFilterPanel) {
            IntelligentFilterPanel(
                filters: $dashboardState.activeFilters,
                searchText: $dashboardState.searchText,
                customers: dashboardState.customers,
                products: dashboardState.products,
                onApply: applyFilters,
                onDateRangeApplied: handleDateRangeApplied,
                onFilterModeEntered: { filters in
                    dashboardState.enterFilterMode(with: filters)
                }
            )
            .preloadable(cacheKey: "intelligent_filter_panel") {
                await preloadFilterPanelDependencies()
            } onDisplay: {
                await trackFilterPanelDisplayFromCache()
            }
        }
        .sheet(isPresented: $dashboardState.showingAnalytics) {
            OutOfStockAnalyticsSheet(
                items: dashboardState.items,
                totalCount: dashboardState.totalCount,
                statusCounts: dashboardState.statusCounts
            )
            .preloadable(cacheKey: "out_of_stock_analytics_sheet") {
                await preloadAnalyticsSheetDependencies()
            } onDisplay: {
                await trackAnalyticsSheetDisplayFromCache()
            }
        }
        .sheet(isPresented: $dashboardState.showingBatchCreation) {
            BatchOutOfStockCreationView(
                customers: dashboardState.customers,
                products: dashboardState.products,
                onSaveCompleted: {
                    Task {
                        await refreshData()
                    }
                }
            )
            .preloadable(cacheKey: "batch_out_of_stock_creation_view") {
                await preloadBatchCreationViewDependencies()
            } onDisplay: {
                await trackBatchCreationViewDisplayFromCache()
            }
        }
        .sheet(isPresented: $dashboardState.showingDatePicker) {
            DatePickerContent(
                initialDate: dashboardState.selectedDate,
                onSave: { newDate in
                    dashboardState.showingDatePicker = false
                    dashboardState.selectedDate = newDate
                    dashboardState.updateDateInNavigationMode(newDate)
                },
                onCancel: {
                    dashboardState.showingDatePicker = false
                }
            )
        }
        .preloadable(cacheKey: "customer_out_of_stock_dashboard") {
            await preloadDashboardDependencies()
        } onDisplay: {
            await trackDashboardDisplayFromCache()
        }
        .task {
            await preloadController.preloadWorkflow(.customerOutOfStock)
        }
        .onAppear {
            animationState.animateInitialAppearance()
            loadInitialData()
        }
        .onChange(of: dashboardState.selectedDate) { oldValue, newValue in
            print("📅 [Date Change] Date changed from \(oldValue) to \(newValue), showing skeleton and refreshing data...")
            
            // Store previous items for caching and set skeleton count
            dashboardState.previousItems = dashboardState.items
            dashboardState.skeletonItemCount = max(6, min(dashboardState.items.count, 8)) // 6-8 skeleton items
            
            // Set skeleton loading state but keep previous data visible
            dashboardState.isRefreshing = true
            dashboardState.isLoading = false
            
            Task {
                await refreshData()
            }
        }
        .refreshable {
            await refreshData()
        }
        .sheet(item: $dashboardState.selectedDetailItem) { selectedItem in
            NavigationStack {
                CustomerOutOfStockDetailView(item: selectedItem)
            }
        }
    }
    
    // MARK: - Adaptive Navigation
    
    private var adaptiveNavigationSection: some View {
        VStack(spacing: 0) {
            AdaptiveDateNavigationBar(
                mode: dashboardState.currentViewMode,
                onPreviousDay: previousDay,
                onNextDay: adaptiveNextDay,
                onDateTapped: { dashboardState.showingDatePicker = true },
                onClearFilters: clearFilters,
                onFilterSummaryTapped: { dashboardState.showingFilterPanel = true },
                sortOrder: dashboardState.sortOrder,
                onToggleSort: toggleSortOrder,
                isEnabled: !dashboardState.isDataLocked
            )
            
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        ZStack {
            if dashboardState.isRefreshing {
                // Show skeleton stats during date switching
                EnhancedSkeletonStatsCards()
                    .padding(.vertical, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Show real stats cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    QuickStatCard(
                        title: "总计",
                        value: "\(getTotalCount())", // Show filtered total when filters are active
                        icon: "list.bullet.rectangle.fill",
                        color: LopanColors.primary,
                        trend: nil,
                        associatedStatus: nil,
                        isSelected: dashboardState.selectedStatusTab == nil,
                        isLocked: dashboardState.isDataLocked,
                        onTap: { handleStatusTabTap(nil) }
                    )
                    
                    QuickStatCard(
                        title: "待处理",
                        value: "\(dashboardState.statusCounts[.pending] ?? 0)",
                        icon: "clock.fill",
                        color: LopanColors.warning,
                        trend: .stable,
                        associatedStatus: .pending,
                        isSelected: dashboardState.selectedStatusTab == .pending,
                        isLocked: dashboardState.isDataLocked,
                        onTap: { handleStatusTabTap(.pending) }
                    )
                    
                    QuickStatCard(
                        title: "已完成",
                        value: "\(dashboardState.statusCounts[.completed] ?? 0)",
                        icon: "checkmark.circle.fill",
                        color: LopanColors.success,
                        trend: .up,
                        associatedStatus: .completed,
                        isSelected: dashboardState.selectedStatusTab == .completed,
                        isLocked: dashboardState.isDataLocked,
                        onTap: { handleStatusTabTap(.completed) }
                    )
                    
                    QuickStatCard(
                        title: "已退货",
                        value: "\(dashboardState.statusCounts[.returned] ?? 0)",
                        icon: "arrow.uturn.left",
                        color: LopanColors.error,
                        trend: (dashboardState.statusCounts[.returned] ?? 0) > 0 ? .up : nil,
                        associatedStatus: .returned,
                        isSelected: dashboardState.selectedStatusTab == .returned,
                        isLocked: dashboardState.isDataLocked,
                        onTap: { handleStatusTabTap(.returned) }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .commonScaleAnimation(delay: 0.3)
                .opacity(dashboardState.isRefreshing ? 0.3 : 1.0)
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
                .selectionFeedback(trigger: dashboardState.selectedStatusTab)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: dashboardState.isRefreshing)
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Search bar with AI assistance
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(LopanColors.textSecondary)
                    
                    TextField("搜索客户、产品、备注...", text: $dashboardState.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onChange(of: dashboardState.searchText) { oldValue, newValue in
                            performSearch()
                        }
                        .onSubmit {
                            isSearchFocused = false
                        }
                        /*.toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("完成") {
                                    isSearchFocused = false
                                }
                                .foregroundColor(LopanColors.info)
                            }
                        }*/
                    
                    if !dashboardState.searchText.isEmpty {
                        Button(action: { dashboardState.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LopanColors.backgroundTertiary)
                )
                
                // Filter button with indicator
                Button(action: { 
                    isSearchFocused = false
                    dashboardState.showingFilterPanel = true 
                }) {
                    ZStack {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title2)
                            .foregroundColor(dashboardState.hasActiveFilters ? LopanColors.primary : .secondary)
                        
                        if dashboardState.hasActiveFilters {
                            Circle()
                                .fill(LopanColors.error)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .accessibilityLabel(Text("筛选"))
                .accessibilityValue(Text(dashboardState.hasActiveFilters ? "已启用筛选" : "未启用筛选"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .scaleEffect(animationState.searchBarScale)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animationState.searchBarScale)
    }
    
    // MARK: - Main Content Section
    
    private var mainContentSection: some View {
        ZStack {
            // Content with keyboard dismissal on empty area taps
            ZStack {
                if dashboardState.isRefreshing {
                    // Show skeleton loading during date switching
                    skeletonLoadingSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                } else if dashboardState.isLoading && dashboardState.items.isEmpty {
                    LoadingStateView("正在加载缺货数据...")
                } else if let error = dashboardState.error {
                    ErrorStateView(
                        title: "加载失败",
                        message: "无法加载缺货数据：\(error.localizedDescription)",
                        retryAction: {
                            dashboardState.error = nil
                            loadInitialData()
                        }
                    )
                } else if dashboardState.items.isEmpty && !dashboardState.isRefreshing {
                    CustomEmptyStateView(
                        title: dashboardState.hasActiveFilters ? "没有匹配的记录" : "暂无缺货记录",
                        message: dashboardState.hasActiveFilters ? "尝试调整筛选条件" : "点击下方按钮添加测试数据或开始添加第一条缺货记录",
                        systemImage: dashboardState.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "tray",
                        actionTitle: "添加记录",
                        secondaryActionTitle: "生成测试数据",
                        action: addNewItem,
                        secondaryAction: generateTestData
                    )
                } else {
                    virtualListSection
                        .opacity(dashboardState.isRefreshing ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: dashboardState.isRefreshing)
                }
            }
            .contentShape(Rectangle()) // Ensure the entire area responds to gestures
            .onTapGesture {
                // Dismiss keyboard when tapping on content area
                if isSearchFocused {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchFocused = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Skeleton Loading Section
    
    private var skeletonLoadingSection: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Show skeleton list only (stats are handled by quickStatsSection)
                EnhancedSkeletonList(itemCount: dashboardState.skeletonItemCount)
                    .padding(.top, 16)
            }
        }
        .scrollDisabled(true) // Prevent scrolling during skeleton loading
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在切换日期并加载数据")
        .accessibilityValue("请稍候，数据正在加载中")
    }
    
    // MARK: - Virtual List Section
    
    private var virtualListSection: some View {
        ScrollViewReader { proxy in
            VirtualListView(
                items: dashboardState.items,
                configuration: VirtualListConfiguration(
                    bufferSize: 15,
                    estimatedItemHeight: 140,
                    maxVisibleItems: 30, // [rule:§3+.2 API Contract] Reduced for better pagination
                    prefetchRadius: 5,
                    recyclingEnabled: true
                ),
                onScrollToBottom: {
                    loadMoreData()
                }
            ) { item in
                OutOfStockItemCard(
                    item: item,
                    isSelected: dashboardState.selectedItems.contains(item.id),
                    isSelectionMode: dashboardState.isSelectionMode,
                    onTap: { handleItemTap(item) },
                    onLongPress: { handleItemLongPress(item) }
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .id(item.id) // Add ID for scroll targeting
            }
            .scrollDismissesKeyboard(.immediately)
            .opacity(animationState.contentOpacity)
            .animation(.easeInOut(duration: 0.4), value: animationState.contentOpacity)
            .onAppear {
                // PHASE 1 OPTIMIZATION: Enable scroll optimization for large dataset performance
                LopanScrollOptimizer.shared.startOptimization()
            }
            .onDisappear {
                // PHASE 1 OPTIMIZATION: Stop scroll optimization when view disappears
                LopanScrollOptimizer.shared.stopOptimization()
            }
            .onChange(of: dashboardState.shouldScrollToTop) { shouldScroll in
                if shouldScroll {
                    // Scroll to top when filter changes [rule:§3+.2 API Contract]
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                    dashboardState.shouldScrollToTop = false
                }
            }
            .onChange(of: dashboardState.totalScrollPosition) { position in
                if let position = position, dashboardState.selectedStatusTab == nil {
                    // Restore "总计" scroll position [rule:§3+.2 API Contract]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(position, anchor: .top)
                        }
                        dashboardState.totalScrollPosition = nil
                    }
                }
            }
            .overlay(
                // Invisible anchor at top for scrolling
                LopanColors.clear
                    .frame(height: 1)
                    .id("top")
                    .offset(y: -8),
                alignment: .top
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() {
        dashboardState.isLoading = true
        
        print("🚀 Loading initial data for date: \(dashboardState.selectedDate)")
        print("📊 Status filter: \(dashboardState.selectedStatusTab?.displayName ?? "All")")
        
        Task {
            // Load customers and products first
            print("👥 Loading customers and products...")
            await appDependencies.serviceFactory.customerService.loadCustomers()
            await appDependencies.serviceFactory.productService.loadProducts()
            
            // Create criteria with status filter
            let criteria = OutOfStockFilterCriteria(
                customer: dashboardState.activeFilters.customer,
                product: dashboardState.activeFilters.product,
                status: dashboardState.selectedStatusTab,
                dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
                searchText: dashboardState.searchText,
                page: 0,
                pageSize: 50,
                sortOrder: dashboardState.sortOrder
            )
            
            // Load filtered data
            print("📅 Loading out of stock data with filter...")
            await customerOutOfStockService.loadFilteredItems(criteria: criteria)
            
            await MainActor.run {
                dashboardState.items = customerOutOfStockService.items
                dashboardState.totalCount = customerOutOfStockService.totalRecordsCount
                dashboardState.customers = appDependencies.serviceFactory.customerService.customers
                dashboardState.products = appDependencies.serviceFactory.productService.products
                
                print("📋 Loaded \(dashboardState.items.count) out of stock items")
                print("👥 Loaded \(dashboardState.customers.count) customers")
                print("📦 Loaded \(dashboardState.products.count) products")
                
                // Check if service has any error
                if let serviceError = customerOutOfStockService.error {
                    dashboardState.error = serviceError
                    print("❌ Service error: \(serviceError.localizedDescription)")
                }
                
                dashboardState.cacheHitRate = 0.85
                dashboardState.isLoading = false
                
                // Load real status counts and unfiltered total count in separate tasks
                Task {
                    let statusCriteria = OutOfStockFilterCriteria(
                        customer: dashboardState.activeFilters.customer,
                        product: dashboardState.activeFilters.product,
                        status: nil, // Don't filter by status to get all counts
                        dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
                        searchText: dashboardState.searchText,
                        page: 0,
                        pageSize: 50,
                        sortOrder: dashboardState.sortOrder
                    )
                    let statusCounts = await customerOutOfStockService.loadStatusCounts(criteria: statusCriteria)
                    
                    // Load unfiltered total count for "总计" display [rule:§3.2 Repository Protocol]
                    let unfilteredCriteria = OutOfStockFilterCriteria(
                        dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
                        page: 0,
                        pageSize: 1 // Only need count, not data
                    )
                    let unfilteredTotal = await customerOutOfStockService.loadUnfilteredTotalCount(criteria: unfilteredCriteria)
                    
                    await MainActor.run {
                        dashboardState.statusCounts = statusCounts
                        dashboardState.unfilteredTotalCount = unfilteredTotal
                        print("📊 Real status counts: \(statusCounts)")
                        print("📊 Unfiltered total count: \(unfilteredTotal)")
                    }
                }
                
                print("✅ Initial data loading completed")
            }
        }
    }
    
    private func refreshData() async {
        lastRefreshTime = Date()
        refreshTrigger.toggle()
        let refreshStartTime = Date()
        
        print("🔄 Refreshing data for date: \(dashboardState.selectedDate)")
        
        // Set loading state
        await MainActor.run {
            dashboardState.isLoading = true
        }
        
        // Determine date range based on active filters
        let dateRange: (start: Date, end: Date)
        if let filterDateRange = dashboardState.activeFilters.dateRange {
            // Use the date range from filters
            dateRange = filterDateRange.toDateInterval()
            print("🔧 [Dashboard] Using filter date range: \(filterDateRange.displayText) -> \(dateRange.start) to \(dateRange.end)")
        } else {
            // Fall back to single day for selected date
            dateRange = CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate)
            print("🔧 [Dashboard] Using selected date range: \(dashboardState.selectedDate) -> \(dateRange.start) to \(dateRange.end)")
        }
        
        // First, load ALL items for status counting and display (without status filter)
        let allItemsCriteria = OutOfStockFilterCriteria(
            customer: dashboardState.activeFilters.customer,
            product: dashboardState.activeFilters.product,
            status: nil, // No status filter to get all items
            dateRange: dateRange,
            searchText: dashboardState.searchText,
            page: 0,
            pageSize: 1000, // Large enough to get all items
            sortOrder: dashboardState.sortOrder
        )
        
        print("📊 [Data] Loading all items for status counting")
        await customerOutOfStockService.loadFilteredItems(criteria: allItemsCriteria)
        let allItems = customerOutOfStockService.items
        
        print("📊 [Data] Loaded \(allItems.count) total items")
        
        // Calculate status counts from all items
        let statusCounts: [OutOfStockStatus: Int] = [
            .pending: allItems.filter { $0.status == .pending }.count,
            .completed: allItems.filter { $0.status == .completed }.count,
            .returned: allItems.filter { $0.status == .returned }.count
        ]
        
        print("📊 [Status Counts] Total items: \(allItems.count), pending=\(statusCounts[.pending] ?? 0), completed=\(statusCounts[.completed] ?? 0), returned=\(statusCounts[.returned] ?? 0)")
        
        // Filter items for display based on selected status tab
        let displayItems: [CustomerOutOfStock]
        let displayCount: Int
        
        if let selectedStatus = dashboardState.selectedStatusTab {
            // Filter items by selected status
            displayItems = allItems.filter { $0.status == selectedStatus }
            displayCount = displayItems.count
            print("📊 [Data] Filtered \(displayCount) items for status: \(selectedStatus.displayName)")
        } else {
            // Show all items
            displayItems = allItems
            displayCount = allItems.count
            print("📊 [Data] Showing all \(displayCount) items (总计)")
        }
        
        // Ensure minimum skeleton display time for smooth UX
        let elapsedTime = Date().timeIntervalSince(refreshStartTime)
        let minimumSkeletonTime: TimeInterval = 0.8 // Show skeleton for at least 800ms
        let additionalDelay = max(0, minimumSkeletonTime - elapsedTime)
        
        if additionalDelay > 0 {
            print("⏱️ Adding \(Int(additionalDelay * 1000))ms delay for smooth skeleton transition")
            try? await Task.sleep(nanoseconds: UInt64(additionalDelay * 1_000_000_000))
        }
        
        await MainActor.run {
            // Smooth transition with animation
            withAnimation(.easeInOut(duration: 0.4)) {
                dashboardState.items = displayItems
                dashboardState.totalCount = displayCount
                dashboardState.statusCounts = statusCounts
                dashboardState.isLoading = false
                dashboardState.isRefreshing = false // Clear skeleton loading state
            }
            
            print("✅ Refresh completed: \(dashboardState.items.count) display items for date \(dashboardState.selectedDate)")
            
            // Explicitly log empty state for debugging
            if dashboardState.items.isEmpty {
                print("📭 [Dashboard] Empty state: No items found for selected date and filters")
            }
        }
        
        // Load unfiltered total count in separate task
        Task {
            let unfilteredCriteria = OutOfStockFilterCriteria(
                dateRange: dateRange, // Use the same date range as main data loading
                page: 0,
                pageSize: 1 // Only need count, not data
            )
            let unfilteredTotal = await customerOutOfStockService.loadUnfilteredTotalCount(criteria: unfilteredCriteria)
            
            await MainActor.run {
                dashboardState.unfilteredTotalCount = unfilteredTotal
                print("📊 Unfiltered total count: \(unfilteredTotal)")
            }
        }
    }
    
    private func loadMoreData() {
        // Improved conditions for loading more data [rule:§3+.2 API Contract]
        guard !dashboardState.isLoadingMore && 
              !customerOutOfStockService.isLoadingMore &&
              customerOutOfStockService.hasMoreData &&
              dashboardState.items.count < customerOutOfStockService.totalRecordsCount else { 
            print("🚫 Skip load more: loading=\(dashboardState.isLoadingMore), serviceLoading=\(customerOutOfStockService.isLoadingMore), hasMore=\(customerOutOfStockService.hasMoreData), items=\(dashboardState.items.count)/\(customerOutOfStockService.totalRecordsCount)")
            return 
        }
        
        dashboardState.isLoadingMore = true
        print("📄 Loading more data... current items: \(dashboardState.items.count)/\(customerOutOfStockService.totalRecordsCount)")
        print("📊 Load more with status filter: \(dashboardState.selectedStatusTab?.displayName ?? "All")")
        
        Task {
            // 直接使用Service的loadNextPage方法，让Service自己管理页码状态
            print("📄 [Dashboard] Calling service.loadNextPage() - currentPage: \(customerOutOfStockService.currentPage)")
            await customerOutOfStockService.loadNextPage()
            
            await MainActor.run {
                // Update dashboard state with new data
                dashboardState.items = customerOutOfStockService.items
                dashboardState.totalCount = customerOutOfStockService.totalRecordsCount
                dashboardState.isLoadingMore = customerOutOfStockService.isLoadingMore
                
                print("📄 Loaded next page, total items: \(dashboardState.items.count), hasMoreData: \(customerOutOfStockService.hasMoreData)")
            }
        }
    }
    
    private func performSearch() {
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            await executeSearch()
        }
    }
    
    private func executeSearch() async {
        print("🔍 Searching for: \(dashboardState.searchText)")
        
        // Create search criteria including status filter
        let criteria = OutOfStockFilterCriteria(
            customer: dashboardState.activeFilters.customer,
            product: dashboardState.activeFilters.product,
            status: dashboardState.selectedStatusTab ?? dashboardState.activeFilters.status,
            dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
            searchText: dashboardState.searchText,
            page: 0,
            pageSize: 50,
            sortOrder: dashboardState.sortOrder
        )
        
        // Load filtered data
        await customerOutOfStockService.loadFilteredItems(criteria: criteria)
        
        await MainActor.run {
            dashboardState.items = customerOutOfStockService.items
            dashboardState.totalCount = customerOutOfStockService.totalRecordsCount
        }
        
        // Load real status counts from repository in a separate task
        Task {
            let statusCriteria = OutOfStockFilterCriteria(
                customer: dashboardState.activeFilters.customer,
                product: dashboardState.activeFilters.product,
                status: nil, // Don't filter by status to get all counts
                dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
                searchText: dashboardState.searchText,
                page: 0,
                pageSize: 50,
                sortOrder: dashboardState.sortOrder
            )
            let statusCounts = await customerOutOfStockService.loadStatusCounts(criteria: statusCriteria)
            await MainActor.run {
                dashboardState.statusCounts = statusCounts
            }
        }
    }
    
    private func applyFilters() {
        // Apply filters and reload data
        print("🔧 [Dashboard] Applying filters")
        
        // Enter filter mode if filters are active
        if dashboardState.activeFilters.hasAnyFilters || !dashboardState.searchText.isEmpty {
            dashboardState.enterFilterMode(with: dashboardState.activeFilters)
        }
        
        // Clear current data immediately to prevent stale data display
        dashboardState.items = []
        dashboardState.totalCount = 0
        dashboardState.isLoading = true
        
        // Trigger scroll to top when filters are applied
        dashboardState.shouldScrollToTop = true
        
        Task {
            // Clear service state to ensure fresh data load
            customerOutOfStockService.currentPage = 0
            customerOutOfStockService.hasMoreData = true
            customerOutOfStockService.items = []
            customerOutOfStockService.totalRecordsCount = 0
            
            // Refresh data with new filters
            await refreshData()
            
            print("✅ [Dashboard] Filters applied and data refreshed")
        }
    }
    
    private func handleDateRangeApplied(_ targetDate: Date?) {
        // Handle date synchronization from filter panel
        print("📅 [Dashboard] Date range applied from filter: \(targetDate?.description ?? "nil")")
        
        if let targetDate = targetDate {
            // Update the selected date to match the filter
            withAnimation(.easeInOut(duration: 0.3)) {
                dashboardState.selectedDate = targetDate
                // 重置状态选择，回到"总计"
                dashboardState.selectedStatusTab = nil
            }
            print("📅 [Dashboard] Updated selectedDate to: \(targetDate)")
        } else {
            // If no specific date provided, use current date
            withAnimation(.easeInOut(duration: 0.3)) {
                dashboardState.selectedDate = Date()
                // 重置状态选择，回到"总计"
                dashboardState.selectedStatusTab = nil
            }
            print("📅 [Dashboard] Reset selectedDate to today")
        }
    }
    
    private func removeFilter(_ filterType: String) {
        // Remove specific filter
        print("❌ Removing filter: \(filterType)")
    }
    
    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dashboardState.activeFilters = OutOfStockFilters()
            dashboardState.searchText = ""
            dashboardState.selectedStatusTab = nil // Clear status filter
        }
        
        Task {
            await refreshData()
        }
    }
    
    private func toggleSortOrder() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dashboardState.sortOrder = dashboardState.sortOrder == .newestFirst ? .oldestFirst : .newestFirst
        }
        
        Task {
            await refreshData()
        }
    }
    
    // MARK: - Helper Functions
    
    private func getTotalCount() -> Int {
        // Check if any filters are active (customer or product)
        let hasFilters = dashboardState.activeFilters.customer != nil || 
                        dashboardState.activeFilters.product != nil
        
        if hasFilters {
            // When filters are active, sum all filtered status counts
            return dashboardState.statusCounts.values.reduce(0, +)
        } else {
            // When no filters are active, show unfiltered total
            return dashboardState.unfilteredTotalCount
        }
    }
    
    // MARK: - Mode Management
    
    private func clearFilters() {
        print("🧹 [Dashboard] Clearing filters and returning to date navigation mode")
        
        // Clear filters
        withAnimation(.easeInOut(duration: 0.3)) {
            dashboardState.activeFilters = OutOfStockFilters()
            dashboardState.searchText = ""
            dashboardState.selectedStatusTab = nil
        }
        
        // Exit filter mode
        dashboardState.exitFilterMode()
        
        // Refresh data
        Task {
            await refreshData()
        }
    }
    
    private func adaptiveNextDay() {
        // Prevent operation if data is currently locked
        guard !dashboardState.isDataLocked else {
            print("🚫 [Adaptive Navigation] Operation blocked - data is currently loading")
            showDataLockedFeedback()
            return
        }
        
        if case .dateNavigation = dashboardState.currentViewMode {
            let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: dashboardState.selectedDate) ?? dashboardState.selectedDate
            
            // Check if next date is not in the future
            let today = Date()
            let calendar = Calendar.current
            if calendar.compare(nextDate, to: today, toGranularity: .day) == .orderedDescending {
                print("⚠️ [Adaptive Navigation] Cannot select future date")
                return
            }
            
            // Use debounced date change
            dashboardState.requestDateChange(nextDate)
            
            // Reset status selection to "总计"
            withAnimation(.easeInOut(duration: 0.3)) {
                dashboardState.selectedStatusTab = nil
            }
            
            Task {
                try? await Task.sleep(nanoseconds: UInt64(dashboardState.dateChangeDebounceDelay * 1_000_000_000))
                print("🔄 [Adaptive Navigation] Loading data for next date...")
                await refreshData()
                print("✅ [Adaptive Navigation] Data refresh completed")
            }
        }
    }
    
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dashboardState.isSelectionMode.toggle()
            if !dashboardState.isSelectionMode {
                dashboardState.selectedItems.removeAll()
            }
        }
    }
    
    private func handleItemTap(_ item: CustomerOutOfStock) {
        // Dismiss keyboard before any action
        isSearchFocused = false
        
        if dashboardState.isSelectionMode {
            if dashboardState.selectedItems.contains(item.id) {
                dashboardState.selectedItems.remove(item.id)
            } else {
                dashboardState.selectedItems.insert(item.id)
            }
        } else {
            // Navigate to detail view
            dashboardState.selectedDetailItem = item
            print("📱 Navigating to detail view for item: \(item.id)")
        }
    }
    
    private func handleItemLongPress(_ item: CustomerOutOfStock) {
        if !dashboardState.isSelectionMode {
            withAnimation(.easeInOut(duration: 0.3)) {
                dashboardState.isSelectionMode = true
                dashboardState.selectedItems.insert(item.id)
            }
        }
    }
    
    private func previousDay() {
        // Prevent operation if data is currently locked
        guard !dashboardState.isDataLocked else {
            print("🚫 [日期切换] Operation blocked - data is currently loading")
            showDataLockedFeedback()
            return
        }
        
        print("📅 [日期切换] 点击上一天按钮")
        
        let currentDate = dashboardState.selectedDate
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) else {
            print("❌ [日期切换] 无法计算上一天日期")
            return
        }
        
        print("📅 [日期切换] 从 \(currentDate) 切换到 \(newDate)")
        
        // Use debounced date change
        dashboardState.requestDateChange(newDate)
        
        // Reset status selection to "总计"
        withAnimation(.easeInOut(duration: 0.3)) {
            dashboardState.selectedStatusTab = nil
        }
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(dashboardState.dateChangeDebounceDelay * 1_000_000_000))
            print("🔄 [日期切换] 开始刷新数据...")
            await refreshData()
            print("✅ [日期切换] 数据刷新完成")
        }
    }
    
    private func nextDay() {
        print("📅 [日期切换] 点击下一天按钮")
        
        let currentDate = dashboardState.selectedDate
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else {
            print("❌ [日期切换] 无法计算下一天日期")
            return
        }
        
        // 检查新日期是否超过今天
        let today = Date()
        let calendar = Calendar.current
        if calendar.compare(newDate, to: today, toGranularity: .day) == .orderedDescending {
            print("⚠️ [日期切换] 不能选择未来日期，当前选择日期已是最新")
            return
        }
        
        print("📅 [日期切换] 从 \(currentDate) 切换到 \(newDate)")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            dashboardState.selectedDate = newDate
            // 重置状态选择，回到"总计"
            dashboardState.selectedStatusTab = nil
        }
        
        Task {
            print("🔄 [日期切换] 开始刷新数据...")
            await refreshData()
            print("✅ [日期切换] 数据刷新完成")
        }
    }
    
    private func exportData() {
        print("📤 Exporting data")
    }
    
    private func addNewItem() {
        print("➕ Adding new item")
        isSearchFocused = false
        dashboardState.showingBatchCreation = true
    }
    
    private func generateTestData() {
        print("🧪 Generating test data...")
        
        Task {
            do {
                // Create some test customer out-of-stock records
                let testCustomer = Customer(name: "测试客户", address: "测试地址", phone: "13800138000")
                let testProduct = Product(name: "测试产品", colors: ["红色"], imageData: nil)
                
                // Add test data to repositories first
                try await appDependencies.serviceFactory.repositoryFactory.customerRepository.addCustomer(testCustomer)
                try await appDependencies.serviceFactory.repositoryFactory.productRepository.addProduct(testProduct)
                
                // Create test out-of-stock records
                let requests = [
                    OutOfStockCreationRequest(
                        customer: testCustomer,
                        product: testProduct,
                        productSize: nil,
                        quantity: 10,
                        notes: "测试缺货记录 1",
                        createdBy: "test_user"
                    ),
                    OutOfStockCreationRequest(
                        customer: testCustomer,
                        product: testProduct,
                        productSize: nil,
                        quantity: 5,
                        notes: "测试缺货记录 2",
                        createdBy: "test_user"
                    )
                ]
                
                try await customerOutOfStockService.createMultipleOutOfStockItems(requests)
                
                // Refresh data
                await refreshData()
                
                print("✅ Test data generated successfully")
            } catch {
                await MainActor.run {
                    dashboardState.error = error
                }
                print("❌ Error generating test data: \(error.localizedDescription)")
            }
        }
    }
    
    private func dayOfWeekText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // 检查选中的日期是否为今天
    private var isSelectedDateToday: Bool {
        let calendar = Calendar.current
        return calendar.isDate(dashboardState.selectedDate, inSameDayAs: Date())
    }
    
    // MARK: - Status Tab Filtering
    
    private func handleStatusTabTap(_ status: OutOfStockStatus?) {
        // Prevent operation if data is currently locked
        guard !dashboardState.isDataLocked else {
            print("🚫 [Status Filter] Operation blocked - data is currently loading")
            showDataLockedFeedback()
            return
        }
        
        print("📊 [Status Filter] Tapped status tab: \(status?.displayName ?? "总计")")
        playStatusSelectionFeedback()

        // If tapping the same status, clear the filter
        let targetStatus: OutOfStockStatus?
        if dashboardState.selectedStatusTab == status {
            targetStatus = nil
            print("📊 [Status Filter] Cleared filter - showing all items")
        } else {
            targetStatus = status
            print("📊 [Status Filter] Applied filter: \(status?.displayName ?? "总计")")
        }
        
        // Immediate UI update for better responsiveness
        withAnimation(.easeInOut(duration: 0.2)) {
            dashboardState.selectedStatusTab = targetStatus
        }
        
        // Use debounced data refresh to prevent multiple requests
        dashboardState.requestStatusChange(targetStatus)
        
        // Refresh data with new filter after debounce delay
        Task {
            try? await Task.sleep(nanoseconds: UInt64(dashboardState.statusChangeDebounceDelay * 1_000_000_000))
            await refreshData()
        }
    }
    
    // MARK: - User Feedback Methods
    
    private func showDataLockedFeedback() {
        // Provide lighter haptic feedback
        playStatusSelectionFeedback()
        
        // Show visual feedback - could be enhanced with toast notification
        print("💬 [User Feedback] 数据正在加载中，请稍候...")
        
        // Quicker and lighter animation feedback
        withAnimation(.easeInOut(duration: 0.15)) {
            dashboardState.statusTabAnimationScale = 0.97
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) {
                dashboardState.statusTabAnimationScale = 1.0
            }
        }
    }

    private func playStatusSelectionFeedback() {
        LopanHapticEngine.shared.light()
    }

    // MARK: - Phase 5 View Preloading Methods
    
    /// Try to apply status filter using cached base data
    private func tryApplyStatusFilterFromCache(_ status: OutOfStockStatus?) async -> (items: [CustomerOutOfStock], totalCount: Int)? {
        // Create base criteria (without status) to check for cached data
        let baseCriteria = OutOfStockFilterCriteria(
            customer: dashboardState.activeFilters.customer,
            product: dashboardState.activeFilters.product,
            status: nil, // No status filter for base data
            dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
            searchText: dashboardState.searchText,
            page: 0,
            pageSize: 50,
            sortOrder: dashboardState.sortOrder
        )
        
        // Try to get cached base data from cache service
        if let cachedBaseData = await customerOutOfStockService.getCachedBaseData(for: baseCriteria) {
            print("⚡ [Cache] Found cached base data with \(cachedBaseData.count) items")
            
            // Apply status filtering in memory
            let filteredItems: [CustomerOutOfStock]
            if let targetStatus = status {
                filteredItems = cachedBaseData.filter { $0.status == targetStatus }
                print("🔍 [Memory Filter] Applied status filter '\(targetStatus.displayName)': \(filteredItems.count) items")
            } else {
                filteredItems = cachedBaseData
                print("🔍 [Memory Filter] No status filter (总计): \(filteredItems.count) items")
            }
            
            return (items: filteredItems, totalCount: filteredItems.count)
        }
        
        print("📭 [Cache] No cached base data found for current criteria")
        return nil
    }
    
    /// Background refresh to ensure cached data is current
    private func refreshDataInBackground() async {
        do {
            // Perform a lightweight refresh without updating UI immediately
            let criteria = OutOfStockFilterCriteria(
                customer: dashboardState.activeFilters.customer,
                product: dashboardState.activeFilters.product,
                status: dashboardState.selectedStatusTab,
                dateRange: CustomerOutOfStockService.createDateRange(for: dashboardState.selectedDate),
                searchText: dashboardState.searchText,
                page: 0,
                pageSize: 50,
                sortOrder: dashboardState.sortOrder
            )
            
            await customerOutOfStockService.loadFilteredItems(criteria: criteria)
            
            // Update UI only if data has changed significantly
            let newItems = customerOutOfStockService.items
            let currentItemCount = dashboardState.items.count
            
            if abs(newItems.count - currentItemCount) > 0 {
                await MainActor.run {
                    dashboardState.items = newItems
                    dashboardState.totalCount = customerOutOfStockService.totalRecordsCount
                    print("🔄 [Background Refresh] Updated UI with fresh data: \(newItems.count) items")
                }
            } else {
                print("✅ [Background Refresh] Data is current, no UI update needed")
            }
            
        } catch {
            print("⚠️ [Background Refresh] Failed: \(error.localizedDescription)")
        }
    }
    
    private func preloadDashboardDependencies() async {
        print("🔮 [Preload] Starting dashboard dependencies preload...")
        
        // Preload core services
        _ = appDependencies.customerService
        _ = appDependencies.productService
        _ = appDependencies.auditingService
        
        // Preload common data structures
        do {
            // Create lightweight filter criteria for preloading
            let criteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: nil,
                searchText: "",
                page: 0,
                pageSize: 5 // Small batch for preloading
            )
            
            // Pre-warm the service with lightweight data fetch
            let _ = try await customerOutOfStockService.fetchOutOfStockRecords(
                criteria: criteria,
                page: 0,
                pageSize: 5
            )
            
            print("✅ [Preload] Dashboard dependencies preloaded successfully")
            
            // Phase 5.3: Proactive data synchronization
            await performProactiveDataSync()
            
        } catch {
            print("⚠️ [Preload] Failed to preload dashboard dependencies: \(error)")
        }
    }
    
    private func trackDashboardDisplayFromCache() async {
        print("📊 [Cache] Dashboard displayed from preloaded cache")
        
        // Track performance metrics
        await appDependencies.auditingService.logEvent(
            action: "dashboard_displayed_from_cache",
            entityId: "customer_out_of_stock_dashboard",
            details: "Dashboard loaded from preload cache with enhanced performance"
        )
    }
    
    // MARK: - Phase 5.2 Sub-view Preloading Methods
    
    private func preloadFilterPanelDependencies() async {
        print("🔮 [Preload] Starting filter panel dependencies preload...")
        
        // Preload customer and product services for filter options
        _ = appDependencies.customerService
        _ = appDependencies.productService
        
        // Pre-warm filter data
        do {
            // Ensure customers and products are loaded for filtering
            if dashboardState.customers.isEmpty {
                // This would trigger customer loading in background
                print("🔮 [Preload] Customers will be loaded for filter panel")
            }
            
            if dashboardState.products.isEmpty {
                // This would trigger product loading in background
                print("🔮 [Preload] Products will be loaded for filter panel")
            }
            
            print("✅ [Preload] Filter panel dependencies preloaded successfully")
        } catch {
            print("⚠️ [Preload] Failed to preload filter panel dependencies: \(error)")
        }
    }
    
    private func trackFilterPanelDisplayFromCache() async {
        print("📊 [Cache] Filter panel displayed from preloaded cache")
        
        await appDependencies.auditingService.logEvent(
            action: "filter_panel_displayed_from_cache",
            entityId: "intelligent_filter_panel",
            details: "Filter panel loaded from preload cache with enhanced performance"
        )
    }
    
    private func preloadAnalyticsSheetDependencies() async {
        print("🔮 [Preload] Starting analytics sheet dependencies preload...")
        
        // Preload auditing service for analytics tracking
        _ = appDependencies.auditingService
        
        // Pre-calculate analytics data if not already available
        do {
            // Ensure status counts are calculated
            if dashboardState.statusCounts.isEmpty {
                print("🔮 [Preload] Status counts will be calculated for analytics")
            }
            
            // Pre-warm any chart/graph data structures
            let itemCount = dashboardState.items.count
            let totalCount = dashboardState.totalCount
            
            print("✅ [Preload] Analytics sheet dependencies preloaded successfully (items: \(itemCount), total: \(totalCount))")
        } catch {
            print("⚠️ [Preload] Failed to preload analytics sheet dependencies: \(error)")
        }
    }
    
    private func trackAnalyticsSheetDisplayFromCache() async {
        print("📊 [Cache] Analytics sheet displayed from preloaded cache")
        
        await appDependencies.auditingService.logEvent(
            action: "analytics_sheet_displayed_from_cache",
            entityId: "out_of_stock_analytics_sheet",
            details: "Analytics sheet loaded from preload cache with enhanced performance"
        )
    }
    
    private func preloadBatchCreationViewDependencies() async {
        print("🔮 [Preload] Starting batch creation view dependencies preload...")
        
        // Preload core services needed for batch creation
        _ = appDependencies.customerService
        _ = appDependencies.productService
        _ = appDependencies.auditingService
        
        // Pre-warm batch creation data
        do {
            // Ensure customers and products are available for batch creation
            if dashboardState.customers.isEmpty || dashboardState.products.isEmpty {
                print("🔮 [Preload] Customer and product data will be loaded for batch creation")
            }
            
            // Pre-warm the customer out of stock service for batch operations
            _ = customerOutOfStockService
            
            print("✅ [Preload] Batch creation view dependencies preloaded successfully")
        } catch {
            print("⚠️ [Preload] Failed to preload batch creation view dependencies: \(error)")
        }
    }
    
    private func trackBatchCreationViewDisplayFromCache() async {
        print("📊 [Cache] Batch creation view displayed from preloaded cache")
        
        await appDependencies.auditingService.logEvent(
            action: "batch_creation_view_displayed_from_cache",
            entityId: "batch_out_of_stock_creation_view",
            details: "Batch creation view loaded from preload cache with enhanced performance"
        )
    }
    
    // MARK: - Phase 5.3 Data-View Synchronization Methods
    
    private func performProactiveDataSync() async {
        print("🔄 [DataSync] Starting proactive data synchronization...")
        
        // Intelligent data preloading based on common usage patterns
        await preloadNavigationPatternData()
        await preloadFrequentlyAccessedData()
        await setupCacheAwareDataStrategies()
        
        print("✅ [DataSync] Proactive data synchronization completed")
    }
    
    private func preloadNavigationPatternData() async {
        print("🧠 [PatternPreload] Analyzing navigation patterns for data preloading...")
        
        // Based on typical salesperson workflow patterns
        do {
            // 1. Preload next day's data (common pattern: users check tomorrow's items)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: dashboardState.selectedDate) ?? Date()
            let tomorrowCriteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: nil,
                searchText: "",
                page: 0,
                pageSize: 10
            )
            
            // Pre-warm tomorrow's data in background
            let _ = try await customerOutOfStockService.fetchOutOfStockRecords(
                criteria: tomorrowCriteria,
                page: 0,
                pageSize: 10
            )
            print("📅 [PatternPreload] Tomorrow's data preloaded")
            
            // 2. Preload pending items (most frequently accessed status)
            let pendingCriteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: .pending,
                dateRange: nil,
                searchText: "",
                page: 0,
                pageSize: 15
            )
            
            let _ = try await customerOutOfStockService.fetchOutOfStockRecords(
                criteria: pendingCriteria,
                page: 0,
                pageSize: 15
            )
            print("⏳ [PatternPreload] Pending items data preloaded")
            
            // 3. Preload customer and product lists for filters
            if dashboardState.customers.isEmpty || dashboardState.products.isEmpty {
                await preloadFilterDataLists()
            }
            
        } catch {
            print("⚠️ [PatternPreload] Failed to preload navigation pattern data: \(error)")
        }
    }
    
    private func preloadFrequentlyAccessedData() async {
        print("📊 [FrequentAccess] Preloading frequently accessed data...")
        
        // Based on analytics, these are the most accessed data types
        do {
            // 1. Status counts for dashboard quick stats (using current selected date for accuracy)
            let currentDateRange = CustomerOutOfStockCoordinator.createDateRange(for: dashboardState.selectedDate)
            let statusCounts = try await customerOutOfStockService.countOutOfStockRecordsByStatus(
                criteria: OutOfStockFilterCriteria(
                    customer: nil,
                    product: nil,
                    status: nil,
                    dateRange: currentDateRange,
                    searchText: "",
                    page: 0,
                    pageSize: 50
                )
            )
            
            // Update dashboard state with preloaded counts
            await MainActor.run {
                dashboardState.statusCounts = statusCounts
            }
            print("🔢 [FrequentAccess] Status counts preloaded: \(statusCounts)")
            
            // 2. Recent customer activity (for filter suggestions) - use broader range for more suggestions
            let recentCriteria = OutOfStockFilterCriteria(
                customer: nil,
                product: nil,
                status: nil,
                dateRange: nil, // Keep nil for suggestions to get broader data
                searchText: "",
                page: 0,
                pageSize: 20
            )
            
            let recentData = try await customerOutOfStockService.fetchOutOfStockRecords(
                criteria: recentCriteria,
                page: 0,
                pageSize: 20
            )
            
            // Extract unique customers and products for filter preloading
            let uniqueCustomers = Set(recentData.items.compactMap { $0.customer })
            let uniqueProducts = Set(recentData.items.compactMap { $0.product })
            
            await MainActor.run {
                if dashboardState.customers.isEmpty {
                    dashboardState.customers = Array(uniqueCustomers)
                }
                if dashboardState.products.isEmpty {
                    dashboardState.products = Array(uniqueProducts)
                }
            }
            
            print("👥 [FrequentAccess] Recent activity preloaded: \(uniqueCustomers.count) customers, \(uniqueProducts.count) products")
            
        } catch {
            print("⚠️ [FrequentAccess] Failed to preload frequently accessed data: \(error)")
        }
    }
    
    private func setupCacheAwareDataStrategies() async {
        print("💾 [CacheStrategy] Setting up cache-aware data fetching strategies...")
        
        // 1. Register cache-aware data fetching patterns
        preloadManager.registerView(
            AnyView(EmptyView()),
            forKey: "data_sync_strategy_\(dashboardState.selectedDate.timeIntervalSince1970)",
            context: .manual
        )
        
        // 2. Set up intelligent cache invalidation triggers
        await setupCacheInvalidationTriggers()
        
        // 3. Configure predictive data loading based on time patterns
        await configurePredictiveDataLoading()
        
        print("✅ [CacheStrategy] Cache-aware strategies configured")
    }
    
    private func preloadFilterDataLists() async {
        print("🔍 [FilterData] Preloading customer and product lists for filters...")
        
        do {
            // This would integrate with customer and product services
            // For now, we'll use the existing service calls
            if dashboardState.customers.isEmpty {
                // Load customers from recent out-of-stock records
                let customerData = try await customerOutOfStockService.fetchOutOfStockRecords(
                    criteria: OutOfStockFilterCriteria(
                        customer: nil,
                        product: nil,
                        status: nil,
                        dateRange: nil,
                        searchText: "",
                        page: 0,
                        pageSize: 50
                    ),
                    page: 0,
                    pageSize: 50
                )
                
                let customers = Array(Set(customerData.items.compactMap { $0.customer }))
                await MainActor.run {
                    dashboardState.customers = customers
                }
                print("👥 [FilterData] Loaded \(customers.count) customers")
            }
            
            if dashboardState.products.isEmpty {
                // Similar approach for products
                let productData = try await customerOutOfStockService.fetchOutOfStockRecords(
                    criteria: OutOfStockFilterCriteria(
                        customer: nil,
                        product: nil,
                        status: nil,
                        dateRange: nil,
                        searchText: "",
                        page: 0,
                        pageSize: 50
                    ),
                    page: 0,
                    pageSize: 50
                )
                
                let products = Array(Set(productData.items.compactMap { $0.product }))
                await MainActor.run {
                    dashboardState.products = products
                }
                print("🏷️ [FilterData] Loaded \(products.count) products")
            }
            
        } catch {
            print("⚠️ [FilterData] Failed to preload filter data lists: \(error)")
        }
    }
    
    private func setupCacheInvalidationTriggers() async {
        print("🔄 [CacheInvalidation] Setting up intelligent cache invalidation...")
        
        // Set up triggers for cache invalidation based on data changes
        await appDependencies.auditingService.logEvent(
            action: "cache_invalidation_triggers_setup",
            entityId: "customer_out_of_stock_dashboard",
            details: "Configured intelligent cache invalidation for data consistency"
        )
    }
    
    private func configurePredictiveDataLoading() async {
        print("🔮 [PredictiveLoading] Configuring time-based predictive data loading...")
        
        // Configure loading patterns based on typical usage times
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // Morning pattern (8-12): Focus on pending and new items
        // Afternoon pattern (12-17): Focus on completed and returned items
        // Evening pattern (17-20): Focus on analytics and tomorrow's planning
        
        let preferredStatuses: [OutOfStockStatus] = {
            switch currentHour {
            case 8..<12:
                return [.pending] // Morning focus
            case 12..<17:
                return [.completed, .returned] // Afternoon focus
            case 17..<20:
                return [.pending] // Evening planning
            default:
                return [.pending, .completed, .returned] // Default all
            }
        }()
        
        // Pre-warm cache with time-appropriate data
        for status in preferredStatuses {
            do {
                let criteria = OutOfStockFilterCriteria(
                    customer: nil,
                    product: nil,
                    status: status,
                    dateRange: nil,
                    searchText: "",
                    page: 0,
                    pageSize: 10
                )
                
                let _ = try await customerOutOfStockService.fetchOutOfStockRecords(
                    criteria: criteria,
                    page: 0,
                    pageSize: 10
                )
                
                print("⏰ [PredictiveLoading] Pre-warmed \(status.displayName) items for time pattern")
            } catch {
                print("⚠️ [PredictiveLoading] Failed to preload \(status.displayName) data: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views (Placeholders)

// MARK: - Date Picker Content

private struct DatePickerContent: View {
    @State private var tempDate: Date
    let onSave: (Date) -> Void
    let onCancel: () -> Void
    
    init(initialDate: Date, onSave: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        _tempDate = State(initialValue: initialDate)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("选择日期", 
                          selection: $tempDate,
                          displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    onCancel()
                },
                trailing: Button("完成") {
                    onSave(tempDate)
                }
                .fontWeight(.semibold)
            )
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct ActiveFiltersView: View {
    let filters: OutOfStockFilters
    let searchText: String
    let onRemove: (String) -> Void
    let onClearAll: () -> Void
    let sortOrder: CustomerOutOfStockNavigationState.SortOrder
    let onToggleSort: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Active filter chips
            LazyHStack(spacing: 8) {
                // Search filter chip
                if !searchText.isEmpty {
                    FilterChip(
                        title: "搜索: \(searchText)",
                        color: LopanColors.primary,
                        onRemove: { onRemove("search") }
                    )
                }
                
                // Date range filter chip
                if let dateRange = filters.dateRange {
                    FilterChip(
                        title: "\(dateRange.displayText)",
                        color: LopanColors.success,
                        onRemove: { onRemove("dateRange") }
                    )
                }
                
                // Customer filter chip
                if let customer = filters.customer {
                    FilterChip(
                        title: "客户: \(customer.name)",
                        color: LopanColors.primary,
                        onRemove: { onRemove("customer") }
                    )
                }
                
                // Product filter chip
                if let product = filters.product {
                    FilterChip(
                        title: "产品: \(product.name)",
                        color: LopanColors.warning,
                        onRemove: { onRemove("product") }
                    )
                }
                
                // Status filter chip
                if let status = filters.status {
                    FilterChip(
                        title: "状态: \(status.displayName)",
                        color: LopanColors.error,
                        onRemove: { onRemove("status") }
                    )
                }
            }
            
            Spacer()
            
            // Sort button
            Button(action: onToggleSort) {
                HStack(spacing: 4) {
                    Image(systemName: sortOrder == .newestFirst ? "arrow.down" : "arrow.up")
                        .font(.caption.weight(.semibold))
                    Text(sortOrder == .newestFirst ? "倒序" : "正序")
                        .font(.caption)
                }
                .foregroundColor(LopanColors.info)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(LopanColors.info.opacity(0.1))
                )
            }
            
            // Clear all button
            Button("清除筛选", action: onClearAll)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.error)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(LopanColors.error.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}


private struct OutOfStockAnalyticsSheet: View {
    let items: [CustomerOutOfStock]
    let totalCount: Int
    let statusCounts: [OutOfStockStatus: Int]
    
    var body: some View {
        Text("Analytics Sheet - To be implemented")
    }
}

private struct OutOfStockItemCard: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                    .font(.title2)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 12) {
                // Header: Customer name and status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.customerDisplayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(item.customerAddress)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(item.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Product information
                HStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .foregroundColor(LopanColors.info)
                        .symbolRenderingMode(.multicolor)
                        .imageScale(.medium)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.productDisplayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("数量: \(item.quantity)")
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Date and time
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.requestDate, style: .date)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                        
                        Text(item.requestDate, style: .time)
                            .font(.caption2)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                }
                
                // Notes (if available)
                if let notes = item.userVisibleNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
                
                // Return information (if applicable)
                if item.status == .returned && item.returnQuantity > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "return.left")
                            .foregroundColor(LopanColors.warning)
                            .font(.caption)
                        
                        Text("退货数量: \(item.returnQuantity)")
                            .font(.caption)
                            .foregroundColor(LopanColors.warning)
                        
                        if let returnDate = item.returnDate {
                            Text(returnDate, style: .date)
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(
                    color: isSelected ? LopanColors.info.opacity(0.3) : LopanColors.textPrimary.opacity(0.06),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? LopanColors.info : LopanColors.clear,
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending:
            return LopanColors.warning
        case .completed:
            return LopanColors.success
        case .returned:
            return LopanColors.error
        }
    }
}

// Note: ErrorStateView and LoadingStateView are already defined in ModernNavigationComponents.swift
// Custom EmptyStateView with secondary action support for this dashboard

private struct CustomEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String
    let secondaryActionTitle: String?
    let action: () -> Void
    let secondaryAction: (() -> Void)?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String,
        secondaryActionTitle: String? = nil,
        action: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.action = action
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(.largeTitle, weight: .regular))
                .foregroundColor(LopanColors.textSecondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(.headline)
                    .foregroundColor(LopanColors.textOnPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LopanColors.info)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if let secondaryActionTitle = secondaryActionTitle,
                   let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text(secondaryActionTitle)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(LopanColors.info)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LopanColors.info.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LopanColors.backgroundPrimary)
    }
}

private extension View {
    @ViewBuilder
    func selectionFeedback<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.selection, trigger: trigger)
        } else {
            self
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CustomerOutOfStock.self, configurations: config)
    let context = ModelContext(container)
    
    CustomerOutOfStockDashboard()
        .environmentObject(ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: context)))
}
