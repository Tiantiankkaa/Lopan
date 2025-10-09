//
//  CustomerManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//  Reconstructed by Claude Code on 2025/10/02.
//

import SwiftUI
import SwiftData
import os.log

enum CustomerDeletionError: Error {
    case validationServiceNotInitialized
}

// MARK: - Filter & Sort Enums

enum CustomerFilterTab: String, CaseIterable {
    case all = "全部客户"
    case recent = "最近"
    case favourite = "收藏"
}

// MARK: - Main View

struct CustomerManagementView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.modelContext) private var modelContext

    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }

    @State private var customers: [Customer] = []
    @State private var searchText = ""
    @State private var selectedTab: CustomerFilterTab = .all
    @State private var showingAddCustomer = false
    @State private var showingDeleteAlert = false
    @State private var customerToDelete: Customer?
    @State private var showingDeletionWarning = false
    @State private var deletionValidationResult: CustomerDeletionValidationService.DeletionValidationResult?
    @State private var validationService: CustomerDeletionValidationService?
    @State private var isLoadingCustomers = false
    @State private var isUpdatingFilter = false
    @State private var customerToEdit: Customer?
    @State private var selectedCustomer: Customer?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isSearchActive: Bool = false

    // Heights for precise alphabetical index positioning
    @State private var headerHeight: CGFloat = 0

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Performance optimization: Cache filtered customers
    @State private var cachedFilteredCustomers: [Customer] = []
    @State private var filterCacheKey: String = ""
    @State private var cachedSectionedCustomers: [(letter: String, customers: [Customer])] = []
    @State private var sectionCacheKey: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    // Pre-sorted cache of all customers (updated only when customer list changes)
    @State private var allCustomersSorted: [Customer] = []
    @State private var allCustomersSections: [(letter: String, customers: [Customer])] = []
    @State private var allCustomersCacheKey: String = ""

    // Seven days ago for "Recent" filter
    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    // Performance logging
    private let perfLogger = Logger(subsystem: "com.lopan.performance", category: "customer-list")

    // MARK: - Computed Properties

    /// Filtered and sorted customers based on tab and search
    /// Optimized with caching to avoid recomputation on every render
    var filteredCustomers: [Customer] {
        // Generate cache key from current filter state
        let currentCacheKey = "\(selectedTab.rawValue)-\(searchText)-\(customers.count)"

        // Return cached result if filter state hasn't changed
        if currentCacheKey == filterCacheKey && !cachedFilteredCustomers.isEmpty {
            return cachedFilteredCustomers
        }

        // Recompute filtered customers
        var filtered = customers

        // Apply tab filter
        switch selectedTab {
        case .all:
            break // Show all
        case .recent:
            filtered = filtered.filter { customer in
                if let lastViewed = customer.lastViewedAt {
                    return lastViewed >= sevenDaysAgo
                }
                return false
            }
        case .favourite:
            filtered = filtered.filter { $0.isFavorite }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.address.localizedCaseInsensitiveContains(searchText) ||
                customer.phone.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Always sort A-Z (use alphabetical index for navigation)
        filtered = filtered.sorted {
            $0.pinyinName.uppercased() < $1.pinyinName.uppercased()
        }

        return filtered
    }

    /// Customers grouped by first letter for sectioned list
    /// Uses cached pinyin values for optimal performance
    /// Cache is updated in updateFilterCache() to avoid state mutation during view update
    var sectionedCustomers: [(letter: String, customers: [Customer])] {
        let callStart = CFAbsoluteTimeGetCurrent()
        let currentKey = filterCacheKey

        // Return cached result if filter hasn't changed
        if currentKey == sectionCacheKey && !cachedSectionedCustomers.isEmpty {
            let duration = (CFAbsoluteTimeGetCurrent() - callStart) * 1000
            perfLogger.debug("📊 sectionedCustomers: cache HIT (\(String(format: "%.2f", duration))ms)")
            return cachedSectionedCustomers
        }

        // If async update is in progress, return existing cache to avoid blocking main thread
        // The async task will update the cache when ready
        if isUpdatingFilter && !cachedSectionedCustomers.isEmpty {
            let duration = (CFAbsoluteTimeGetCurrent() - callStart) * 1000
            perfLogger.debug("📊 sectionedCustomers: returning stale cache while updating (\(String(format: "%.2f", duration))ms)")
            return cachedSectionedCustomers
        }

        // Large dataset handling (> 100 customers)
        if filteredCustomers.count > 100 {
            if cachedSectionedCustomers.isEmpty {
                // Cache not ready yet - return empty to avoid blocking main thread
                // Async updateFilterCache() will populate cache and trigger re-render
                let duration = (CFAbsoluteTimeGetCurrent() - callStart) * 1000
                perfLogger.debug("📊 sectionedCustomers: large dataset (\(filteredCustomers.count)), cache empty, returning [] while async updates (\(String(format: "%.2f", duration))ms)")
                return []  // Brief flash of empty, then populated when cache ready (~40ms)
            } else {
                // Cache exists - return it
                let duration = (CFAbsoluteTimeGetCurrent() - callStart) * 1000
                perfLogger.debug("📊 sectionedCustomers: large dataset, returning old cache (\(String(format: "%.2f", duration))ms)")
                return cachedSectionedCustomers
            }
        }

        // Small dataset (< 100) - safe to compute synchronously
        perfLogger.debug("📊 sectionedCustomers: small dataset (\(filteredCustomers.count)), computing synchronously")
        let grouped = Dictionary(grouping: filteredCustomers) { customer -> String in
            // Use pre-computed pinyin initial (cached in model)
            // "张三" → "Z", "李明" → "L", "Alice" → "A"
            // Returns cached value, no expensive CFStringTransform call
            return customer.pinyinInitial.isEmpty ? "#" : customer.pinyinInitial
        }

        let result = grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, customers: $0.value) }

        let duration = (CFAbsoluteTimeGetCurrent() - callStart) * 1000
        perfLogger.debug("📊 sectionedCustomers: small dataset SYNC compute took \(String(format: "%.2f", duration))ms")
        return result
    }

    /// Available letters for the section index
    var availableLetters: Set<String> {
        Set(sectionedCustomers.map { $0.letter })
    }

    /// Determines if the alphabetical section index should be displayed
    private var showsAlphabeticalIndex: Bool {
        !sectionedCustomers.isEmpty && selectedTab == .all && searchText.isEmpty
    }

    // MARK: - Performance Timing Helpers

    /// Measure execution time of a synchronous operation
    @MainActor
    private func measureTime<T>(_ label: String, operation: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        perfLogger.info("⏱️ \(label): \(String(format: "%.2f", duration))ms")
        return result
    }

    /// Measure execution time of an async operation
    @MainActor
    private func measureTimeAsync<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        perfLogger.info("▶️ START: \(label)")
        let result = try await operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        perfLogger.info("⏱️ \(label): \(String(format: "%.2f", duration))ms")
        return result
    }

    // MARK: - Body

    var body: some View {
        let _ = perfLogger.debug("🎨 body render - Tab: \(selectedTab.rawValue), Updating: \(isUpdatingFilter), Sections: \(sectionedCustomers.count)")

        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                // Header with tabs - hide instantly when search is active (native iOS behavior)
                headerView
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: HeaderHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .opacity(isSearchActive ? 0 : 1)
                    .frame(height: isSearchActive ? 0 : nil)
                    .clipped()
                    .allowsHitTesting(!isSearchActive)

                // Customer list (with native searchable)
                // Let native .searchable() handle presentation animations
                customersListView

                // Customer count
                //customerCountView
            }
            .background(LopanColors.backgroundPrimary)

            // Alphabetical index (centered in customer card display area)
            if showsAlphabeticalIndex {
                AlphabeticalSectionIndexView(
                    availableLetters: availableLetters,
                    onLetterTap: { letter in
                        withAnimation(reduceMotion ? .none : .default) {
                            scrollProxy?.scrollTo(letter, anchor: .top)
                        }
                    }
                )
                .padding(.trailing, 8)
                .padding(.top, letterFilterTopPadding(geometry: geometry))
            }
            }
            .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
        }
        .navigationTitle("客户")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCustomer = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            if validationService == nil {
                validationService = CustomerDeletionValidationService(modelContext: modelContext)
            }
            loadCustomers()

            // Auto-migrate pinyin cache for existing customers (runs in background)
            Task.detached(priority: .utility) {
                // Wait for customers to load first
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                await migratePinyinIfNeeded()
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            perfLogger.info("🔄 Tab switched: \(oldTab.rawValue) → \(newTab.rawValue)")
            let switchStart = CFAbsoluteTimeGetCurrent()

            // Use synchronous path for instant cached data, async for filtering/sorting
            if canUseSynchronousCache(for: newTab) {
                // FAST PATH: Synchronous cache access (<10ms)
                updateFilterCacheSync()
                let totalDuration = (CFAbsoluteTimeGetCurrent() - switchStart) * 1000
                perfLogger.info("✅ Total tab switch time (sync): \(String(format: "%.2f", totalDuration))ms")
            } else {
                // SLOW PATH: Async filtering/sorting needed
                Task {
                    await measureTimeAsync("Tab switch complete (\(oldTab.rawValue)→\(newTab.rawValue))") {
                        await updateFilterCache()
                    }

                    let totalDuration = (CFAbsoluteTimeGetCurrent() - switchStart) * 1000
                    perfLogger.info("✅ Total tab switch time (async): \(String(format: "%.2f", totalDuration))ms")
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Debounce search to avoid excessive filtering
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                await updateFilterCache()
            }
        }
        .onChange(of: customers.count) { _, _ in
            Task {
                await updateFilterCache()
                await updateAllCustomersCache()
            }
        }
        .sheet(isPresented: $showingAddCustomer) {
            AddCustomerView(onSave: { customer in
                Task {
                    try await customerRepository.addCustomer(customer)
                    loadCustomers()
                }
            })
        }
        .sheet(item: $customerToEdit) { customer in
            EditCustomerView(customer: customer)
        }
    }

    // MARK: - View Components

    /// Header with filter tabs
    private var headerView: some View {
        HStack(spacing: LopanSpacing.xl) {
            Spacer()
            ForEach(CustomerFilterTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: LopanSpacing.xxs) {
                        Text(tab.rawValue)
                            .font(selectedTab == tab ? LopanTypography.labelLarge : LopanTypography.labelMedium)
                            .foregroundColor(selectedTab == tab ? LopanColors.primary : LopanColors.textSecondary)

                        if selectedTab == tab {
                            Rectangle()
                                .fill(LopanColors.primary)
                                .frame(height: 2)
                                .transition(.scale)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .accessibilityLabel("\(tab.rawValue) 标签")
                .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
            }

            Spacer()
        }
        .lopanPaddingHorizontal()
        .lopanPaddingVertical(LopanSpacing.xxs)
        .background(LopanColors.surface)
    }

    /// Main customer list with sections (includes native searchable)
    private var customersListView: some View {
        Group {
            if filteredCustomers.isEmpty && !isLoadingCustomers {
                emptyStateView
            } else if isLoadingCustomers {
                loadingView
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(sectionedCustomers, id: \.letter) { section in
                            Section {
                                ForEach(section.customers, id: \.id) { customer in
                                    Button {
                                        selectedCustomer = customer
                                        updateLastViewed(customer)
                                    } label: {
                                        CustomerCardView(
                                            customer: customer,
                                            onCall: { callCustomer(customer) },
                                            onMessage: { messageCustomer(customer) },
                                            onEdit: { customerToEdit = customer },
                                            onToggleFavorite: { toggleFavorite(customer) },
                                            onDelete: { handleDeleteCustomer(customer) }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 44))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            } header: {
                                // Invisible anchor for letter navigation
                                Color.clear
                                    .frame(height: 0)
                                    .id(section.letter)
                                    .listRowInsets(EdgeInsets())
                            }
                        }

                        // Customer count at bottom of list
                        if !filteredCustomers.isEmpty {
                            Section {
                                VStack(spacing: LopanSpacing.xs) {
                                    Divider()
                                        .opacity(0.3)

                                    Text("\(filteredCustomers.count) 位客户")
                                        .font(LopanTypography.caption)
                                        .foregroundColor(LopanColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .listSectionSpacing(0)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .environment(\.defaultMinListHeaderHeight, 0)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    .refreshable {
                        await refreshCustomers()
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .navigationDestination(item: $selectedCustomer) { customer in
                        CustomerDetailView(customer: customer)
                    }
                }
            }
        }
        .searchable(text: $searchText, isPresented: $isSearchActive, prompt: "搜索客户姓名或地址")
        .alert("删除客户", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let customer = customerToDelete {
                    performSimpleDeletion(customer)
                }
            }
            Button("取消", role: .cancel) {
                customerToDelete = nil
            }
        } message: {
            if let customer = customerToDelete {
                Text("确定要删除客户 \"\(customer.name)\" 吗？")
            }
        }
        .alert("删除客户确认", isPresented: $showingDeletionWarning) {
            if let result = deletionValidationResult {
                if result.pendingOutOfStockCount > 0 {
                    Button("取消", role: .cancel) {
                        customerToDelete = nil
                        deletionValidationResult = nil
                    }
                    Button("仍要删除", role: .destructive) {
                        performDeletion()
                    }
                } else {
                    Button("取消", role: .cancel) {
                        customerToDelete = nil
                        deletionValidationResult = nil
                    }
                    Button("删除", role: .destructive) {
                        performDeletion()
                    }
                }
            }
        } message: {
            if let result = deletionValidationResult {
                Text(result.impactSummary)
            }
        }
    }

    /// Customer count display
    private var customerCountView: some View {
        Group {
            if !filteredCustomers.isEmpty {
                Text("\(filteredCustomers.count) 位客户")
                    .font(LopanTypography.caption)
                    .foregroundColor(LopanColors.textSecondary)
                    .lopanPaddingVertical(LopanSpacing.sm)
            }
        }
    }

    /// Loading view
    private var loadingView: some View {
        VStack(spacing: LopanSpacing.md) {
            ForEach(0..<5, id: \.self) { _ in
                CustomerSkeletonRow()
                    .lopanPaddingHorizontal()
            }
        }
        .lopanPaddingVertical()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: LopanSpacing.xl) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(LopanColors.textSecondary)
            
            VStack(spacing: LopanSpacing.sm) {
                Text(searchText.isEmpty ? "暂无客户" : "未找到客户")
                    .font(LopanTypography.titleMedium)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(searchText.isEmpty ? "点击右上角 + 号添加第一个客户" : "尝试修改搜索条件")
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button {
                    showingAddCustomer = true
                } label: {
                    Text("添加客户")
                        .font(LopanTypography.buttonMedium)
                        .foregroundColor(LopanColors.textOnPrimary)
                        .lopanPaddingHorizontal(LopanSpacing.xl)
                        .lopanPaddingVertical(LopanSpacing.sm)
                        .background(LopanColors.primary)
                        .cornerRadius(LopanSpacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .lopanPaddingVertical(LopanSpacing.xxxxl)
    }
    
    // MARK: - Letter Filter Positioning

    /// Calculates top padding to center letter filter in customer card display area
    /// Range: from bottom of header to top of bottom navigation bar
    private func letterFilterTopPadding(geometry: GeometryProxy) -> CGFloat {
        // Where customer list display area starts (bottom of header)
        // Native searchable is embedded in the List, not a separate section
        let displayAreaStart = headerHeight

        // Bottom navigation bar height
        let bottomNavHeight = geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 83

        // Where customer list display area ends (top of bottom nav)
        let displayAreaEnd = geometry.size.height - bottomNavHeight

        // Height of the customer list display area
        let displayAreaHeight = displayAreaEnd - displayAreaStart

        // Letter filter actual height (26 letters with spacing)
        let letterFilterHeight: CGFloat = 468

        // Calculate padding to center the filter in display area
        let centeringOffset = max(0, (displayAreaHeight - letterFilterHeight) / 2)

        return displayAreaStart + centeringOffset
    }

    // MARK: - Cache Management Helpers

    /// Checks if synchronous cache update is possible (pre-sorted cache available)
    private func canUseSynchronousCache(for tab: CustomerFilterTab) -> Bool {
        return tab == .all && searchText.isEmpty && !allCustomersSorted.isEmpty && customers.count == allCustomersSorted.count
    }

    /// Synchronous cache update for instant operations (pre-sorted cache)
    /// Eliminates async/await overhead for ~5-10ms faster tab switches
    private func updateFilterCacheSync() {
        let syncStart = CFAbsoluteTimeGetCurrent()
        let currentCacheKey = "\(selectedTab.rawValue)-\(searchText)-\(customers.count)"

        // Early return if already cached
        guard currentCacheKey != filterCacheKey else {
            perfLogger.debug("✅ Cache hit, skipping sync update")
            return
        }

        perfLogger.debug("🚀 Sync cache update using pre-sorted data")

        // Batch all state updates into single render cycle
        withAnimation(.none) {
            cachedFilteredCustomers = allCustomersSorted
            cachedSectionedCustomers = allCustomersSections
            filterCacheKey = currentCacheKey
            sectionCacheKey = currentCacheKey
        }

        let syncDuration = (CFAbsoluteTimeGetCurrent() - syncStart) * 1000
        perfLogger.info("✅ Sync cache update COMPLETE: \(String(format: "%.2f", syncDuration))ms")
    }

    /// Determines the reason for cache invalidation by analyzing key changes
    private func determineCacheMissReason(oldKey: String, newKey: String) -> String {
        let oldParts = oldKey.split(separator: "-")
        let newParts = newKey.split(separator: "-")

        guard oldParts.count == 3, newParts.count == 3 else {
            return "initialization"
        }

        let oldTab = oldParts[0]
        let oldSearch = oldParts[1]
        let oldCount = oldParts[2]

        let newTab = newParts[0]
        let newSearch = newParts[1]
        let newCount = newParts[2]

        if oldTab != newTab {
            return "tab change (\(oldTab) → \(newTab))"
        } else if oldSearch != newSearch {
            let searchDesc = newSearch.isEmpty ? "cleared" : "updated"
            return "search \(searchDesc)"
        } else if oldCount != newCount {
            return "data updated (\(oldCount) → \(newCount) customers)"
        } else {
            return "unknown"
        }
    }

    // MARK: - Data Operations

    private func loadCustomers() {
        Task {
            do {
                isLoadingCustomers = true

                // Load customers in background thread for better performance
                let loadedCustomers = try await Task.detached(priority: .userInitiated) {
                    try await self.customerRepository.fetchCustomers()
                }.value

                await MainActor.run {
                    self.customers = loadedCustomers
                    self.isLoadingCustomers = false
                }
                await self.updateFilterCache()
                await self.updateAllCustomersCache()
            } catch {
                print("Error loading customers: \(error)")
                await MainActor.run {
                    isLoadingCustomers = false
                }
            }
        }
    }

    /// Updates the filtered customers cache asynchronously
    /// Performs expensive filtering and sorting off the main thread for better performance
    private func updateFilterCache() async {
        let overallStart = CFAbsoluteTimeGetCurrent()
        perfLogger.debug("🔄 updateFilterCache START - Tab: \(selectedTab.rawValue), Count: \(customers.count)")

        let currentCacheKey = "\(selectedTab.rawValue)-\(searchText)-\(customers.count)"

        // Only recompute if cache key changed
        guard currentCacheKey != filterCacheKey else {
            perfLogger.debug("✅ Cache hit, skipping update")
            return
        }

        // Determine why cache was invalidated
        let reason = determineCacheMissReason(oldKey: filterCacheKey, newKey: currentCacheKey)
        perfLogger.debug("🔄 Cache invalidated: \(reason)")

        // Capture current state for async work
        let captureStart = CFAbsoluteTimeGetCurrent()
        let tab = selectedTab
        let search = searchText
        let allCustomers = customers
        let cutoffDate = sevenDaysAgo
        let captureDuration = (CFAbsoluteTimeGetCurrent() - captureStart) * 1000
        perfLogger.debug("⏱️ State capture: \(String(format: "%.2f", captureDuration))ms")

        // OPTIMIZATION: Use pre-sorted cache for "All Customers" tab
        if tab == .all && search.isEmpty && !allCustomersSorted.isEmpty && allCustomers.count == allCustomersSorted.count {
            perfLogger.info("🚀 Using pre-sorted 'All Customers' cache (\(allCustomersSorted.count) items, \(allCustomersSections.count) sections) - skipping sort!")

            await MainActor.run {
                let finalCacheKey = "\(selectedTab.rawValue)-\(searchText)-\(customers.count)"
                if finalCacheKey == currentCacheKey {
                    cachedFilteredCustomers = allCustomersSorted
                    filterCacheKey = currentCacheKey
                    cachedSectionedCustomers = allCustomersSections
                    sectionCacheKey = currentCacheKey
                    perfLogger.info("✅ Cache updated from pre-sorted (instant!)")
                }
                isUpdatingFilter = false
            }

            let overallDuration = (CFAbsoluteTimeGetCurrent() - overallStart) * 1000
            perfLogger.info("✅ updateFilterCache COMPLETE (pre-sorted): \(String(format: "%.2f", overallDuration))ms")
            return
        }

        // Show updating indicator
        await MainActor.run { isUpdatingFilter = true }

        // Perform expensive filtering, sorting, AND sectioning off main thread
        let bgStart = CFAbsoluteTimeGetCurrent()
        perfLogger.debug("🔧 Starting background computation...")

        let (filtered, sectioned) = await Task.detached(priority: .userInitiated) {
            let taskStart = CFAbsoluteTimeGetCurrent()
            var result = allCustomers

            // Phase 1: Tab filtering
            let filterStart = CFAbsoluteTimeGetCurrent()
            switch tab {
            case .all:
                break // Show all
            case .recent:
                result = result.filter { customer in
                    if let lastViewed = customer.lastViewedAt {
                        return lastViewed >= cutoffDate
                    }
                    return false
                }
            case .favourite:
                result = result.filter { $0.isFavorite }
            }
            let filterDuration = (CFAbsoluteTimeGetCurrent() - filterStart) * 1000
            print("  ⏱️ [BG] Tab filter (\(tab.rawValue)): \(String(format: "%.2f", filterDuration))ms, Result: \(result.count) items")

            // Phase 2: Search filtering
            if !search.isEmpty {
                let searchStart = CFAbsoluteTimeGetCurrent()
                result = result.filter { customer in
                    customer.name.localizedCaseInsensitiveContains(search) ||
                    customer.address.localizedCaseInsensitiveContains(search) ||
                    customer.phone.localizedCaseInsensitiveContains(search)
                }
                let searchDuration = (CFAbsoluteTimeGetCurrent() - searchStart) * 1000
                print("  ⏱️ [BG] Search filter: \(String(format: "%.2f", searchDuration))ms, Result: \(result.count) items")
            }

            // Phase 3: Sorting
            let sortStart = CFAbsoluteTimeGetCurrent()
            let sortedCustomers = result.sorted {
                $0.pinyinName.uppercased() < $1.pinyinName.uppercased()
            }
            let sortDuration = (CFAbsoluteTimeGetCurrent() - sortStart) * 1000
            print("  ⏱️ [BG] Sorting: \(String(format: "%.2f", sortDuration))ms")

            // Phase 4: Sectioning
            let sectionStart = CFAbsoluteTimeGetCurrent()
            let grouped = Dictionary(grouping: sortedCustomers) { customer in
                customer.pinyinInitial.isEmpty ? "#" : customer.pinyinInitial
            }
            let sections = grouped.sorted { $0.key < $1.key }
                .map { (letter: $0.key, customers: $0.value) }
            let sectionDuration = (CFAbsoluteTimeGetCurrent() - sectionStart) * 1000
            print("  ⏱️ [BG] Sectioning: \(String(format: "%.2f", sectionDuration))ms, Sections: \(sections.count)")

            let totalTaskDuration = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
            print("  ⏱️ [BG] Total background work: \(String(format: "%.2f", totalTaskDuration))ms")

            return (sortedCustomers, sections)
        }.value

        let bgDuration = (CFAbsoluteTimeGetCurrent() - bgStart) * 1000
        perfLogger.debug("⏱️ Background computation: \(String(format: "%.2f", bgDuration))ms")

        // Update both caches on main thread (legal - in async function)
        await MainActor.run {
            // Verify cache key is still valid (user might have switched tabs again)
            let finalCacheKey = "\(selectedTab.rawValue)-\(searchText)-\(customers.count)"
            if finalCacheKey == currentCacheKey {
                cachedFilteredCustomers = filtered
                filterCacheKey = currentCacheKey

                // Update section cache with pre-computed sections
                cachedSectionedCustomers = sectioned
                sectionCacheKey = currentCacheKey
                perfLogger.debug("✅ Cache updated - \(filtered.count) customers, \(sectioned.count) sections")
            } else {
                perfLogger.warning("⚠️ Cache key mismatch, discarding results")
            }
            isUpdatingFilter = false
        }

        let overallDuration = (CFAbsoluteTimeGetCurrent() - overallStart) * 1000
        perfLogger.info("✅ updateFilterCache COMPLETE: \(String(format: "%.2f", overallDuration))ms")
    }

    /// Pre-compute and cache the sorted "All Customers" view
    /// Called once when data loads and when customer list changes
    /// Eliminates 38ms sorting overhead on subsequent tab switches to "All Customers"
    private func updateAllCustomersCache() async {
        let currentKey = "all-\(customers.count)"
        guard currentKey != allCustomersCacheKey else {
            perfLogger.debug("✅ 'All Customers' cache up to date")
            return
        }

        perfLogger.info("🔄 Pre-computing 'All Customers' cache for \(customers.count) items")
        let allCustomers = customers

        let (sorted, sections) = await Task.detached(priority: .userInitiated) {
            let sortStart = CFAbsoluteTimeGetCurrent()
            let sorted = allCustomers.sorted {
                $0.pinyinName.uppercased() < $1.pinyinName.uppercased()
            }
            let sortDuration = (CFAbsoluteTimeGetCurrent() - sortStart) * 1000
            print("  ⏱️ [BG] Pre-sort all customers: \(String(format: "%.2f", sortDuration))ms")

            let sectionStart = CFAbsoluteTimeGetCurrent()
            let grouped = Dictionary(grouping: sorted) { customer in
                customer.pinyinInitial.isEmpty ? "#" : customer.pinyinInitial
            }
            let sections = grouped.sorted { $0.key < $1.key }
                .map { (letter: $0.key, customers: $0.value) }
            let sectionDuration = (CFAbsoluteTimeGetCurrent() - sectionStart) * 1000
            print("  ⏱️ [BG] Pre-section all customers: \(String(format: "%.2f", sectionDuration))ms")

            return (sorted, sections)
        }.value

        await MainActor.run {
            allCustomersSorted = sorted
            allCustomersSections = sections
            allCustomersCacheKey = currentKey
            perfLogger.info("✅ 'All Customers' cache ready: \(sorted.count) customers, \(sections.count) sections")
        }
    }

    private func refreshCustomers() async {
        do {
            customers = try await customerRepository.fetchCustomers()
            await updateFilterCache()
            await updateAllCustomersCache()
        } catch {
            print("Error refreshing customers: \(error)")
        }
    }

    /// Migrates existing customers to populate pinyin cache
    /// Optimized with background processing and batching to avoid UI freeze
    private func migratePinyinIfNeeded() async {
        // Check if any customers need migration
        let customersNeedingMigration = await MainActor.run {
            customers.filter { $0.pinyinInitial.isEmpty || $0.pinyinName.isEmpty }
        }

        guard !customersNeedingMigration.isEmpty else {
            print("✓ All customers have pinyin cache populated")
            return
        }

        // If too many customers need migration, defer to avoid blocking
        if customersNeedingMigration.count > 200 {
            print("⚠️ \(customersNeedingMigration.count) customers need pinyin migration, deferring to background")
            return
        }

        print("🔄 Starting background pinyin cache migration for \(customersNeedingMigration.count) customers...")

        var migratedCount = 0
        let batchSize = 50

        // Process in batches to avoid blocking
        for batchStart in stride(from: 0, to: customersNeedingMigration.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, customersNeedingMigration.count)
            let batch = Array(customersNeedingMigration[batchStart..<batchEnd])

            for customer in batch {
                // Compute pinyin values
                customer.pinyinName = customer.name.toPinyin()
                customer.pinyinInitial = customer.name.pinyinInitial()

                // Update in database
                do {
                    try await customerRepository.updateCustomer(customer)
                    migratedCount += 1
                    print("  ✓ Migrated: \(customer.name) → \(customer.pinyinInitial)")
                } catch {
                    print("  ✗ Failed to migrate \(customer.name): \(error)")
                }
            }

            // Yield to let other tasks run (prevents UI freeze)
            await Task.yield()

            // Small delay between batches
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Refresh to show updated data with proper sectioning
        await refreshCustomers()

        print("✅ Pinyin migration complete: \(migratedCount) customers updated")
    }

    // MARK: - Customer Actions

    private func toggleFavorite(_ customer: Customer) {
        Task {
            do {
                try await customerRepository.toggleFavorite(customer)
                // Reload to reflect changes
                await refreshCustomers()
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }

    private func updateLastViewed(_ customer: Customer) {
        Task {
            do {
                try await customerRepository.updateLastViewed(customer)
            } catch {
                print("Error updating last viewed: \(error)")
            }
        }
    }

    private func callCustomer(_ customer: Customer) {
        guard !customer.phone.isEmpty,
              let url = URL(string: "tel://\(customer.phone)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    private func messageCustomer(_ customer: Customer) {
        guard !customer.phone.isEmpty,
              let url = URL(string: "sms://\(customer.phone)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Deletion

    private func handleDeleteCustomer(_ customer: Customer) {
        Task {
            do {
                guard let validationService = validationService else {
                    throw CustomerDeletionError.validationServiceNotInitialized
                }
                let result = try await validationService.validateCustomerDeletion(customer)
                await MainActor.run {
                    self.deletionValidationResult = result
                    self.customerToDelete = customer
                    self.showingDeletionWarning = true
                }
            } catch {
                print("Error validating customer deletion: \(error)")
                await MainActor.run {
                    // Fallback to simple deletion warning
                    customerToDelete = customer
                    showingDeleteAlert = true
                }
            }
        }
    }
    
    private func performSimpleDeletion(_ customer: Customer) {
        Task {
            do {
                try await customerRepository.deleteCustomer(customer)
                await MainActor.run {
                    withAnimation {
                        customers.removeAll { $0.id == customer.id }
                    }
                    customerToDelete = nil
                }
            } catch {
                await MainActor.run {
                    print("Error deleting customer: \(error)")
                    customerToDelete = nil
                }
            }
        }
    }
    
    private func performDeletion() {
        guard let customer = customerToDelete else { return }
        
        Task {
            do {
                // Prepare customer for safe deletion
                guard let validationService = validationService else {
                    throw CustomerDeletionError.validationServiceNotInitialized
                }
                try await validationService.prepareCustomerForDeletion(customer)
                // Now safe to delete
                try await customerRepository.deleteCustomer(customer)
                
                await MainActor.run {
                    // Remove from local array with animation
                    withAnimation {
                        customers.removeAll { $0.id == customer.id }
                    }
                    customerToDelete = nil
                    deletionValidationResult = nil
                }
            } catch {
                await MainActor.run {
                    print("Error deleting customer: \(error)")
                    customerToDelete = nil
                    deletionValidationResult = nil
                }
            }
        }
    }
}

// MARK: - Add Customer View

struct AddCustomerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies
    @State private var name = ""
    @State private var selectedCountry: Country?
    @State private var region = ""
    @State private var city = ""
    @State private var phone = ""
    @State private var whatsappNumber = ""
    @State private var isSaving = false
    @State private var isCheckingDuplicate = false
    @State private var duplicateError: String?
    @State private var showCountrySelection = false
    @State private var showRegionSelection = false

    let onSave: (Customer) -> Void

    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmedName.isEmpty &&
               selectedCountry != nil &&
               !trimmedRegion.isEmpty &&
               !trimmedCity.isEmpty &&
               !trimmedPhone.isEmpty &&
               duplicateError == nil &&
               !isCheckingDuplicate
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.965, green: 0.965, blue: 0.973)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(Color(red: 0.153, green: 0.345, blue: 0.925))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(isSaving)

                    Spacer()

                    // Title
                    Text("New Customer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.textPrimary)

                    Spacer()

                    // Empty space for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(
                    Color(red: 0.965, green: 0.965, blue: 0.973).opacity(0.8)
                        .background(.ultraThinMaterial)
                )

                // Content
                ScrollView {
                    VStack(spacing: 28) {
                        // Customer Name
                        TextField("Customer Name", text: $name)
                            .font(.system(size: 16))
                            .foregroundColor(LopanColors.textPrimary)
                            .padding(.horizontal, LopanSpacing.lg)
                            .frame(height: LopanSpacing.inputHeight)
                            .background(Color.white)
                            .cornerRadius(LopanCornerRadius.lg)
                            .lopanShadow(LopanShadows.sm)
                            .onChange(of: name) { _, newValue in
                                Task {
                                    await checkForDuplicates()
                                }
                            }

                        // Country Selector
                        Button(action: { showCountrySelection = true }) {
                            HStack {
                                if let country = selectedCountry {
                                    Text("\(country.flag) \(country.name)")
                                        .font(.system(size: 16))
                                        .foregroundColor(LopanColors.textPrimary)
                                } else {
                                    Text("Country")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(.placeholderText))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(.systemGray))
                            }
                            .padding(.horizontal, LopanSpacing.lg)
                            .frame(height: LopanSpacing.inputHeight)
                            .background(Color.white)
                            .cornerRadius(LopanCornerRadius.lg)
                            .lopanShadow(LopanShadows.sm)
                        }

                        // Region Selector (only show if country is selected)
                        if selectedCountry != nil {
                            Button(action: {
                                if selectedCountry != nil {
                                    showRegionSelection = true
                                }
                            }) {
                                HStack {
                                    Text(region.isEmpty ? "Region" : region)
                                        .font(.system(size: 16))
                                        .foregroundColor(region.isEmpty ? Color(.placeholderText) : LopanColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(.systemGray))
                                }
                                .padding(.horizontal, LopanSpacing.lg)
                                .frame(height: LopanSpacing.inputHeight)
                                .background(Color.white)
                                .cornerRadius(LopanCornerRadius.lg)
                                .lopanShadow(LopanShadows.sm)
                            }
                        }

                        // City Field (only show if region is selected)
                        if selectedCountry != nil && !region.isEmpty {
                            TextField("City", text: $city)
                                .font(.system(size: 16))
                                .foregroundColor(LopanColors.textPrimary)
                                .padding(.horizontal, LopanSpacing.lg)
                                .frame(height: LopanSpacing.inputHeight)
                                .background(Color.white)
                                .cornerRadius(LopanCornerRadius.lg)
                                .lopanShadow(LopanShadows.sm)
                        }

                        // Phone Number
                        HStack(spacing: 8) {
                            // Dial Code Prefix
                            if let country = selectedCountry {
                                Text(country.dialCode)
                                    .font(.system(size: 16))
                                    .foregroundColor(LopanColors.textPrimary)
                            }

                            TextField("Phone Number", text: $phone)
                                .font(.system(size: 16))
                                .foregroundColor(LopanColors.textPrimary)
                                .keyboardType(.phonePad)
                        }
                        .padding(.horizontal, LopanSpacing.lg)
                        .frame(height: LopanSpacing.inputHeight)
                        .background(Color.white)
                        .cornerRadius(LopanCornerRadius.lg)
                        .lopanShadow(LopanShadows.sm)

                        // WhatsApp Number
                        HStack(spacing: 8) {
                            // Dial Code Prefix
                            if let country = selectedCountry {
                                Text(country.dialCode)
                                    .font(.system(size: 16))
                                    .foregroundColor(LopanColors.textPrimary)
                            }

                            TextField("WhatsApp Number", text: $whatsappNumber)
                                .font(.system(size: 16))
                                .foregroundColor(LopanColors.textPrimary)
                                .keyboardType(.phonePad)
                        }
                        .padding(.horizontal, LopanSpacing.lg)
                        .frame(height: LopanSpacing.inputHeight)
                        .background(Color.white)
                        .cornerRadius(LopanCornerRadius.lg)
                        .lopanShadow(LopanShadows.sm)

                        // Error message for duplicate
                        if let error = duplicateError {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }

                // Footer with Add Customer button
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(.separator))

                    Button(action: saveCustomer) {
                        Text("Add Customer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(red: 0.153, green: 0.345, blue: 0.925))
                            .cornerRadius(8)
                    }
                    .disabled(!isValid || isSaving)
                    .opacity(!isValid || isSaving ? 0.5 : 1.0)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.965, green: 0.965, blue: 0.973))
                }
            }
        }
        .sheet(isPresented: $showCountrySelection) {
            CountrySelectionView(selectedCountry: $selectedCountry)
                .onDisappear {
                    // Reset region when country changes
                    if selectedCountry != nil {
                        region = ""
                    }
                }
        }
        .sheet(isPresented: $showRegionSelection) {
            if let country = selectedCountry {
                RegionSelectionView(country: country, selectedRegion: $region)
            }
        }
    }

    private func checkForDuplicates() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            duplicateError = nil
            return
        }

        isCheckingDuplicate = true
        do {
            let hasDuplicate = try await customerRepository.checkDuplicateName(trimmedName, excludingId: nil)
            await MainActor.run {
                duplicateError = hasDuplicate ? "客户姓名已存在，请使用其他姓名" : nil
                isCheckingDuplicate = false
            }
        } catch {
            await MainActor.run {
                duplicateError = nil
                isCheckingDuplicate = false
            }
        }
    }

    private func saveCustomer() {
        isSaving = true

        // Combine dial code with phone numbers
        let dialCode = selectedCountry?.dialCode ?? ""
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWhatsApp = whatsappNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        let fullPhone = trimmedPhone.isEmpty ? "" : "\(dialCode)\(trimmedPhone)"
        let fullWhatsApp = trimmedWhatsApp.isEmpty ? "" : "\(dialCode)\(trimmedWhatsApp)"

        let customer = Customer(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: "", // Free text address field removed, will be added later if needed
            phone: fullPhone,
            whatsappNumber: fullWhatsApp,
            country: selectedCountry?.id ?? "",
            countryName: selectedCountry?.name ?? "",
            region: region.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(customer)
        dismiss()
    }
}

// MARK: - Customer Skeleton Row
struct CustomerSkeletonRow: View {
    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            Circle()
                .fill(LopanColors.secondaryLight)
                .frame(width: 40, height: 40)
                .shimmering()

            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmering()

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmering()

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 12)
                    .frame(width: 120, alignment: .leading)
                    .shimmering()
            }

            Spacer()
        }
        .lopanPaddingVertical(LopanSpacing.sm)
        .accessibilityHidden(true)
    }
}

// MARK: - Preference Keys for Layout

struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    CustomerManagementView()
        .modelContainer(for: Customer.self, inMemory: true)
}
