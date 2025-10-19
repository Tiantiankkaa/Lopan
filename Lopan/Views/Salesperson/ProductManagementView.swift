//
//  ProductManagementView.swift
//  Lopan
//
//  Completely reconstructed to match HTML mockup
//  Overlay-based drawers with slide animations
//

import SwiftUI
import SwiftData
import os.log

struct ProductManagementView: View {
    @Environment(\.appDependencies) private var appDependencies

    private var productRepository: ProductRepository {
        appDependencies.serviceFactory.repositoryFactory.productRepository
    }

    // MARK: - State

    @State private var products: [Product] = []
    @State private var filteredProducts: [Product] = []

    // Drawer State
    @State private var showFilterDrawer = false
    @State private var selectedProduct: Product?

    // Filter State
    @State private var selectedProductFilterCategory: ProductFilterCategory = .all
    @State private var statusFilter: Set<Product.InventoryStatus> = [.active, .lowStock, .inactive]
    @State private var inventoryRange: Double = 100

    // UI State
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showAddProduct = false
    @State private var viewMode: ViewMode = .list

    // Scroll State
    @State private var previousScrollOffset: CGFloat = 0
    @State private var showHeaderContent = true

    // Pagination State
    @State private var currentPage = 0
    @State private var pageSize = 50 // Load 50 products per page
    @State private var hasMoreData = true
    @State private var isLoadingMore = false
    @State private var totalProductCount = 0

    // Filter chip counts (from database)
    @State private var allProductsCount = 0
    @State private var activeProductsCount = 0
    @State private var lowStockProductsCount = 0
    @State private var inactiveProductsCount = 0

    // Performance optimization: Cache filtered products
    // NOTE: With pagination, cache operates on currently loaded pages only (50-150 items)
    // This keeps memory usage low while providing instant filter/search feedback
    @State private var cachedFilteredProducts: [Product] = []
    @State private var filterCacheKey: String = ""
    @State private var cachedSectionedProducts: [(category: ProductFilterCategory, products: [Product])] = []
    @State private var sectionCacheKey: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var paginationTask: Task<Void, Never>?

    // Pre-sorted cache of all loaded products (updated when new pages load)
    // With pagination enabled, this cache only contains loaded pages, not all products
    @State private var allProductsSorted: [Product] = []
    @State private var allProductsCacheKey: String = ""

    // Loading states
    @State private var isLoadingProducts = false
    @State private var isUpdatingFilter = false

    // Performance logging
    private let perfLogger = Logger(subsystem: "com.lopan.performance", category: "product-list")

    // MARK: - Body

    var body: some View {
        let _ = perfLogger.debug("🎨 body render - Category: \(selectedProductFilterCategory.label), Updating: \(isUpdatingFilter), Cached products: \(cachedFilteredProducts.count)")

        ZStack {
            // Main ScrollView at top level (required for navigation bar collapse)
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar (Expandable)
                    if showSearch {
                        searchBarView
                    }

                    // Filter Chips Row
                    filterChipsRow

                    // Hidden GeometryReader to track scroll offset
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin.y
                        )
                    }
                    .frame(height: 0)

                    // Product List - Conditional based on view mode
                    if viewMode == .list {
                        listView
                    } else {
                        gridView
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                updateScrollPosition(value)
            }
            .refreshable {
                await refreshData()
            }
            .background(LopanColors.listBackground)

            // Backdrop Overlay
            if showFilterDrawer {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(30)
                    .onTapGesture {
                        closeAllDrawers()
                    }
            }

            // Filter Drawer (Left Slide)
            if showFilterDrawer {
                filterDrawerView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
                    .zIndex(40)
            }
        }
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        LopanHapticEngine.shared.medium()
                        showAddProduct = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(LopanColors.viewModeIconColor)
                    }
                    .accessibilityLabel("Add product")
                    .accessibilityHint("Opens form to add a new product")
                    .disabled(!showHeaderContent)

                    Menu {
                        // View Mode Section
                        Section("View Mode") {
                            Button(action: {
                                LopanHapticEngine.shared.light()
                                viewMode = .list
                            }) {
                                Label("List View", systemImage: viewMode == .list ? "checkmark.circle.fill" : "list.bullet")
                            }

                            Button(action: {
                                LopanHapticEngine.shared.light()
                                viewMode = .grid
                            }) {
                                Label("Grid View", systemImage: viewMode == .grid ? "checkmark.circle.fill" : "square.grid.2x2")
                            }
                        }

                        Divider()

                        // Filters Section
                        Button(action: {
                            LopanHapticEngine.shared.light()
                            // Sync drawer status with current chip selection before opening
                            syncDrawerStatusWithChip()
                            showFilterDrawer = true
                        }) {
                            Label("Filters & Sort", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(LopanColors.viewModeIconColor)
                    }
                    .accessibilityLabel("Filter and view options")
                    .disabled(!showHeaderContent)
                }
                .opacity(showHeaderContent ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: showHeaderContent)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFilterDrawer)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showAddProduct) {
            NavigationStack {
                CreateProductView()
            }
        }
        .sheet(item: $selectedProduct) { product in
            let _ = perfLogger.debug("📋 Sheet content rendering (item-based)")
            let _ = perfLogger.debug("  └─ Product: \(product.name)")
            let _ = perfLogger.debug("  └─ Product ID: \(product.id)")
            NavigationStack {
                ProductDetailView(product: product)
            }
        }
        .onChange(of: selectedProductFilterCategory) { oldCategory, newCategory in
            perfLogger.info("🔄 Category switched: \(oldCategory.label) → \(newCategory.label)")
            let switchStart = CFAbsoluteTimeGetCurrent()

            // Reset pagination and reload with new filter
            loadData(status: currentFilterStatus)

            let totalDuration = (CFAbsoluteTimeGetCurrent() - switchStart) * 1000
            perfLogger.info("✅ Total category switch time: \(String(format: "%.2f", totalDuration))ms")
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
        .onChange(of: products.count) { _, _ in
            Task {
                await updateFilterCache()
                await updateAllProductsCache()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .productAdded)) { _ in
            perfLogger.info("📢 Product added notification received - refreshing list")
            Task {
                await refreshData()
            }
        }
    }

    // MARK: - Search Bar View

    /// Expandable search bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(LopanColors.textSecondary)
            TextField("Search products...", text: $searchText)
                .font(.system(size: 16))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(LopanColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LopanColors.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.sm))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Filter Chips Row

    /// Matches HTML: <div class="flex space-x-2 overflow-x-auto">
    private var filterChipsRow: some View {
        // Scrollable chips - now takes full width
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProductFilterCategory.allCases, id: \.self) { chip in
                    filterChipButton(chip)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
        .frame(height: showHeaderContent ? nil : 0)
        .clipped()
        .opacity(showHeaderContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: showHeaderContent)
    }

    private func filterChipButton(_ chip: ProductFilterCategory) -> some View {
        LopanFilterChip(
            title: chip.label,
            count: chipCountForCategory(chip),
            isSelected: selectedProductFilterCategory == chip
        ) {
            selectedProductFilterCategory = chip
        }
    }

    /// Returns the database count for a given filter category
    private func chipCountForCategory(_ category: ProductFilterCategory) -> Int {
        switch category {
        case .all:
            return allProductsCount
        case .active:
            return activeProductsCount
        case .lowStock:
            return lowStockProductsCount
        case .inactive:
            return inactiveProductsCount
        }
    }

    // MARK: - List and Grid Views

    /// List view with full-width product cards
    private var listView: some View {
        LazyVStack(spacing: 12) {
            ForEach(cachedFilteredProducts, id: \.id) { product in
                HTMLProductCard(product: product) {
                    // Debug logging for product detail page entry
                    perfLogger.debug("🎯 PRODUCT CARD TAPPED")
                    perfLogger.debug("  └─ Product ID: \(product.id)")
                    perfLogger.debug("  └─ Product Name: \(product.name)")
                    perfLogger.debug("  └─ SKU: \(product.formattedSKU)")
                    perfLogger.debug("  └─ Price: \(product.formattedPrice)")
                    perfLogger.debug("  └─ Status: \(product.inventoryStatus.displayName)")
                    perfLogger.debug("  └─ Inventory: \(product.inventoryQuantity)")
                    perfLogger.debug("  └─ Sizes: \(product.sizes?.count ?? 0)")
                    perfLogger.debug("  └─ Images: \(product.imageDataArray.count)")
                    perfLogger.debug("  └─ Description: \(product.productDescription ?? "nil")")
                    perfLogger.debug("  └─ Weight: \(product.weight.map { "\($0)g" } ?? "nil")")
                    perfLogger.debug("  └─ Manual Status: \(product.manualInventoryStatus.map { "\($0)" } ?? "nil")")
                    perfLogger.debug("  └─ Low Stock Threshold: \(product.lowStockThreshold.map { "\($0)" } ?? "nil")")

                    selectedProduct = product

                    perfLogger.debug("  └─ ✅ Sheet presentation triggered (item-based)")
                    LopanHapticEngine.shared.light()
                }
            }

            // Infinite Scroll Trigger
            if hasMoreData && !isLoadingMore && !isLoadingProducts {
                InfiniteScrollTrigger(prefetchThreshold: 0.7) {
                    Task {
                        await loadNextPage()
                    }
                }
            }

            // Loading Indicator
            if isLoadingMore {
                LoadingMoreIndicator(isLoading: true, hasMore: hasMoreData)
                    .padding(.vertical, 16)
            } else if !hasMoreData && products.count > 0 {
                LoadingMoreIndicator(isLoading: false, hasMore: false)
                    .padding(.vertical, 16)
            }
        }
        .padding(16)
    }

    /// Grid view with 2-column layout
    private var gridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(cachedFilteredProducts, id: \.id) { product in
                GridProductCard(product: product) {
                    selectedProduct = product
                    LopanHapticEngine.shared.light()
                }
            }

            // Infinite Scroll Trigger
            if hasMoreData && !isLoadingMore && !isLoadingProducts {
                InfiniteScrollTrigger(prefetchThreshold: 0.7) {
                    Task {
                        await loadNextPage()
                    }
                }
                .gridCellColumns(2)  // Span both columns
            }

            // Loading Indicator
            if isLoadingMore {
                LoadingMoreIndicator(isLoading: true, hasMore: hasMoreData)
                    .padding(.vertical, 16)
                    .gridCellColumns(2)  // Span both columns
            } else if !hasMoreData && products.count > 0 {
                LoadingMoreIndicator(isLoading: false, hasMore: false)
                    .padding(.vertical, 16)
                    .gridCellColumns(2)  // Span both columns
            }
        }
        .padding(16)
    }

    // MARK: - Filter Drawer View

    /// Left-sliding filter drawer matching HTML mockup
    /// Width: 80% max 320pt, white background
    private var filterDrawerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                filterDrawerHeader
                filterDrawerContent
            }
            .frame(maxWidth: 320)
            .frame(maxHeight: .infinity)
            .background(LopanColors.chipBackground)
            .lopanShadow(LopanShadows.modal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var filterDrawerHeader: some View {
        HStack {
            Text("Filters")
                .lopanHeadlineMedium()
                .foregroundColor(LopanColors.textPrimary)

            Spacer()

            Button(action: {
                LopanHapticEngine.shared.light()
                showFilterDrawer = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .padding(24)
    }

    private var filterDrawerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statusFilterSection
                inventoryRangeSection
                filterActionButtons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var statusFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .lopanLabelMedium()
                .foregroundColor(LopanColors.textPrimary)

            Menu {
                Button("All") { statusFilter = [.active, .lowStock, .inactive] }
                Button("Active") { statusFilter = [.active] }
                Button("Low Stock") { statusFilter = [.lowStock] }
                Button("Inactive") { statusFilter = [.inactive] }
            } label: {
                HStack {
                    Text(statusFilterLabel)
                        .lopanBodySmall()
                        .foregroundColor(LopanColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .lopanCaption()
                        .foregroundColor(LopanColors.textSecondary)
                }
                .padding(12)
                .background(LopanColors.chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                        .stroke(LopanColors.productCardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
        }
    }

    private var inventoryRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inventory")
                    .lopanLabelMedium()
                    .foregroundColor(LopanColors.textPrimary)

                Spacer()

                Text("\(Int(inventoryRange))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LopanColors.primary)
            }

            VStack(spacing: 8) {
                Slider(value: $inventoryRange, in: 0...100, step: 5)
                    .tint(LopanColors.primary)

                HStack {
                    Text("0")
                        .lopanCaption()
                        .foregroundColor(LopanColors.textSecondary)
                    Spacer()
                    Text("100+")
                        .lopanCaption()
                        .foregroundColor(LopanColors.textSecondary)
                }
            }
        }
    }

    private var filterActionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                LopanHapticEngine.shared.medium()
                // Sync chip selection with drawer status changes
                syncChipWithDrawerStatus()
                // Trigger filter cache update to apply drawer changes
                Task {
                    await updateFilterCache()
                }
                showFilterDrawer = false
            }) {
                Text("Apply Filters")
                    .lopanButtonMedium()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LopanColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.sm))
            }

            Button(action: {
                LopanHapticEngine.shared.light()
                statusFilter = [.active, .lowStock, .inactive]
                inventoryRange = 100
                selectedProductFilterCategory = .all
                // No need to call updateFilteredProducts() - chip change triggers reload via onChange
            }) {
                Text("Reset")
                    .lopanButtonMedium()
                    .foregroundColor(LopanColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                            .stroke(LopanColors.productCardBorder, lineWidth: 1)
                    )
            }
        }
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

    // MARK: - Helper Methods

    /// Converts the current filter category to an optional inventory status for repository queries
    private var currentFilterStatus: Product.InventoryStatus? {
        switch selectedProductFilterCategory {
        case .all:
            return nil
        case .active:
            return .active
        case .lowStock:
            return .lowStock
        case .inactive:
            return .inactive
        }
    }

    private var statusFilterLabel: String {
        if statusFilter.count == 3 { return "All" }
        if statusFilter.count == 1 {
            switch statusFilter.first {
            case .active: return "Active"
            case .lowStock: return "Low Stock"
            case .inactive: return "Inactive"
            case .none: return "All"
            }
        }
        return "Custom"
    }

    private func closeAllDrawers() {
        LopanHapticEngine.shared.light()
        showFilterDrawer = false
        selectedProduct = nil
    }

    /// Synchronizes the drawer status filter with the currently selected chip
    /// Called when opening the filter drawer to ensure consistency
    private func syncDrawerStatusWithChip() {
        switch selectedProductFilterCategory {
        case .all:
            statusFilter = [.active, .lowStock, .inactive]
        case .active:
            statusFilter = [.active]
        case .lowStock:
            statusFilter = [.lowStock]
        case .inactive:
            statusFilter = [.inactive]
        }
    }

    /// Synchronizes the chip selection with the current drawer status filter
    /// Called when applying filters to update the chip based on drawer changes
    private func syncChipWithDrawerStatus() {
        // If all statuses selected, switch to "All" chip
        if statusFilter.count == 3 {
            selectedProductFilterCategory = .all
        }
        // If single status selected, switch to corresponding chip
        else if statusFilter.count == 1 {
            switch statusFilter.first {
            case .active:
                selectedProductFilterCategory = .active
            case .lowStock:
                selectedProductFilterCategory = .lowStock
            case .inactive:
                selectedProductFilterCategory = .inactive
            case .none:
                selectedProductFilterCategory = .all
            }
        }
        // If multiple (but not all) statuses selected, leave chip unchanged
        // This handles custom multi-select scenarios
    }

    private func updateScrollPosition(_ offset: CGFloat) {
        // Small threshold to ignore tiny movements (prevent jitter)
        let minMovement: CGFloat = 5

        // Calculate scroll delta
        let delta = offset - previousScrollOffset

        // Ignore very small movements
        guard abs(delta) > minMovement else { return }

        // Determine scroll direction
        if delta > 0 {
            // Scrolling UP (content moving down) - show header
            if !showHeaderContent {
                withAnimation(.easeOut(duration: 0.25)) {
                    showHeaderContent = true
                }
            }
        } else if delta < 0 {
            // Scrolling DOWN (content moving up) - hide header
            // But keep visible if already at/near top
            if offset > -20 {
                // Near top - keep header visible
                if !showHeaderContent {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showHeaderContent = true
                    }
                }
            } else if showHeaderContent {
                withAnimation(.easeOut(duration: 0.25)) {
                    showHeaderContent = false
                }
            }
        }

        previousScrollOffset = offset
    }

    @MainActor
    private func loadData(status: Product.InventoryStatus? = nil) {
        Task {
            do {
                perfLogger.info("🔄 loadData START - Pagination enabled, Status filter: \(status?.displayName ?? "None")")
                isLoadingProducts = true

                // Reset pagination state AND clear cache to prevent stale data display
                currentPage = 0
                products = []
                cachedFilteredProducts = []  // Clear stale cache
                filterCacheKey = ""  // Invalidate cache key
                hasMoreData = true

                // Fetch total count first (for progress tracking)
                let count = try await productRepository.fetchProductCount(status: status)
                totalProductCount = count
                perfLogger.info("📊 Total product count: \(count) for status: \(status?.displayName ?? "All")")

                // Load first page with sorting and status filter
                let sortBy = [SortDescriptor(\Product.name, order: .forward)]
                let loadedProducts = try await Task.detached(priority: .userInitiated) {
                    try await self.productRepository.fetchProducts(
                        limit: self.pageSize,
                        offset: 0,
                        sortBy: sortBy,
                        status: status
                    )
                }.value

                await MainActor.run {
                    self.products = loadedProducts
                    self.currentPage = 1
                    self.hasMoreData = loadedProducts.count == self.pageSize
                    self.isLoadingProducts = false
                    perfLogger.info("✅ First page loaded: \(loadedProducts.count) products")
                }

                await self.updateFilterCache()
                await self.updateAllProductsCache()
                await self.updateFilterChipCounts()
            } catch {
                perfLogger.error("❌ Error loading products: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingProducts = false
                }
            }
        }
    }

    /// Fetch counts for each filter category from the database
    @MainActor
    private func updateFilterChipCounts() async {
        do {
            perfLogger.debug("📊 Fetching filter chip counts from database...")

            // Fetch counts in parallel for better performance
            async let allCount = productRepository.fetchProductCount(status: nil)
            async let activeCount = productRepository.fetchProductCount(status: .active)
            async let lowStockCount = productRepository.fetchProductCount(status: .lowStock)
            async let inactiveCount = productRepository.fetchProductCount(status: .inactive)

            // Await all counts
            let counts = try await (allCount, activeCount, lowStockCount, inactiveCount)

            // Update state
            allProductsCount = counts.0
            activeProductsCount = counts.1
            lowStockProductsCount = counts.2
            inactiveProductsCount = counts.3

            perfLogger.debug("✅ Filter chip counts updated - All: \(counts.0), Active: \(counts.1), Low Stock: \(counts.2), Inactive: \(counts.3)")
        } catch {
            perfLogger.error("❌ Error fetching filter chip counts: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func loadNextPage() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingMore && hasMoreData else {
            perfLogger.debug("⏭️ Skipping loadNextPage - isLoadingMore: \(isLoadingMore), hasMoreData: \(hasMoreData)")
            return
        }

        // Cancel any existing pagination task
        paginationTask?.cancel()

        perfLogger.info("📄 Loading page \(currentPage + 1)...")
        isLoadingMore = true

        // Create new pagination task
        paginationTask = Task {
            do {
                let offset = currentPage * pageSize
                let sortBy = [SortDescriptor(\Product.name, order: .forward)]
                let currentStatus = currentFilterStatus

                perfLogger.debug("🔍 Fetching offset: \(offset), limit: \(pageSize), status: \(currentStatus?.displayName ?? "None")")
                let newProducts = try await Task.detached(priority: .userInitiated) {
                    try await self.productRepository.fetchProducts(
                        limit: self.pageSize,
                        offset: offset,
                        sortBy: sortBy,
                        status: currentStatus
                    )
                }.value

                // Check if task was cancelled
                try Task.checkCancellation()

                await MainActor.run {
                    // CRITICAL: Filter out duplicate products (race condition safety net)
                    let existingIDs = Set(self.products.map { $0.id })
                    let uniqueNewProducts = newProducts.filter { !existingIDs.contains($0.id) }

                    if uniqueNewProducts.count != newProducts.count {
                        let duplicateCount = newProducts.count - uniqueNewProducts.count
                        perfLogger.warning("⚠️ RACE CONDITION DETECTED: Filtered out \(duplicateCount) duplicate product(s)")
                        perfLogger.warning("  └─ Total fetched: \(newProducts.count), Unique: \(uniqueNewProducts.count)")

                        // Log the duplicate IDs for debugging
                        let duplicateIDs = newProducts.filter { existingIDs.contains($0.id) }.map { $0.id }
                        perfLogger.warning("  └─ Duplicate IDs: \(duplicateIDs.joined(separator: ", "))")
                    }

                    // Append only unique products
                    self.products.append(contentsOf: uniqueNewProducts)
                    self.currentPage += 1

                    // Check if we have more data
                    self.hasMoreData = newProducts.count == self.pageSize
                    self.isLoadingMore = false

                    perfLogger.info("✅ Page \(self.currentPage) loaded: \(uniqueNewProducts.count) unique products (Total: \(self.products.count)/\(self.totalProductCount))")
                }

                await self.updateFilterCache()
            } catch is CancellationError {
                perfLogger.info("🚫 Pagination task cancelled")
                await MainActor.run {
                    isLoadingMore = false
                }
            } catch {
                perfLogger.error("❌ Error loading next page: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }

        await paginationTask?.value
    }

    @MainActor
    private func refreshData() async {
        do {
            perfLogger.info("🔄 Refreshing products (pagination reset)")
            let currentStatus = currentFilterStatus

            // Reset pagination AND clear cache to prevent stale data display
            currentPage = 0
            products = []
            cachedFilteredProducts = []  // Clear stale cache
            filterCacheKey = ""  // Invalidate cache key
            hasMoreData = true

            // Fetch total count
            let count = try await productRepository.fetchProductCount(status: currentStatus)
            totalProductCount = count

            // Load first page with current filter
            let sortBy = [SortDescriptor(\Product.name, order: .forward)]
            let loadedProducts = try await productRepository.fetchProducts(
                limit: pageSize,
                offset: 0,
                sortBy: sortBy,
                status: currentStatus
            )

            products = loadedProducts
            currentPage = 1
            hasMoreData = loadedProducts.count == pageSize

            perfLogger.info("✅ Refresh complete: \(loadedProducts.count) products loaded")

            await updateFilterCache()
            await updateAllProductsCache()
            await updateFilterChipCounts()
        } catch {
            perfLogger.error("❌ Error refreshing products: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func updateFilteredProducts() {
        var filtered = products

        // Apply chip filter
        switch selectedProductFilterCategory {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.inventoryStatus == .active }
        case .lowStock:
            filtered = filtered.filter { $0.inventoryStatus == .lowStock }
        case .inactive:
            filtered = filtered.filter { $0.inventoryStatus == .inactive }
        }

        // Apply status filter
        filtered = filtered.filter { statusFilter.contains($0.inventoryStatus) }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.formattedSKU.localizedCaseInsensitiveContains(searchText)
            }
        }

        filteredProducts = filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Updates the filtered products cache asynchronously
    /// Performs expensive filtering and sorting off the main thread for better performance
    private func updateFilterCache() async {
        let overallStart = CFAbsoluteTimeGetCurrent()
        perfLogger.info("🔄 updateFilterCache START - Category: \(selectedProductFilterCategory.label), Count: \(products.count)")

        let currentCacheKey = "\(selectedProductFilterCategory.rawValue)-\(searchText)-\(statusFilter.count)-\(Int(inventoryRange))-\(products.count)"

        // Only recompute if cache key changed
        guard currentCacheKey != filterCacheKey else {
            perfLogger.info("✅ Cache hit, skipping update")
            return
        }

        perfLogger.info("⚠️ Cache miss - old: '\(filterCacheKey)', new: '\(currentCacheKey)'")

        // Capture current state for async work
        let captureStart = CFAbsoluteTimeGetCurrent()
        let category = selectedProductFilterCategory
        let search = searchText
        let statusSet = statusFilter
        let maxInventory = inventoryRange
        let allProducts = products
        let captureDuration = (CFAbsoluteTimeGetCurrent() - captureStart) * 1000
        perfLogger.info("⏱️ State capture: \(String(format: "%.2f", captureDuration))ms")

        // OPTIMIZATION: Use pre-sorted cache for "All" category with no search and no inventory filter
        // Note: statusSet.count == 3 because we have Active, Low Stock, Inactive (outOfStock was removed)
        if category == .all && search.isEmpty && statusSet.count == 3 && maxInventory == 100 && !allProductsSorted.isEmpty && allProducts.count == allProductsSorted.count {
            perfLogger.info("🚀 Using pre-sorted 'All Products' cache (\(allProductsSorted.count) items) - skipping sort!")

            await MainActor.run {
                let finalCacheKey = "\(selectedProductFilterCategory.rawValue)-\(searchText)-\(statusFilter.count)-\(Int(inventoryRange))-\(products.count)"
                if finalCacheKey == currentCacheKey {
                    cachedFilteredProducts = allProductsSorted
                    filterCacheKey = currentCacheKey
                    perfLogger.info("✅ Cache updated from pre-sorted (instant!)")
                }
                isUpdatingFilter = false
            }

            let overallDuration = (CFAbsoluteTimeGetCurrent() - overallStart) * 1000
            perfLogger.info("✅ updateFilterCache COMPLETE (pre-sorted): \(String(format: "%.2f", overallDuration))ms")
            return
        }

        // Show updating indicator
        let flagStart = CFAbsoluteTimeGetCurrent()
        await MainActor.run { isUpdatingFilter = true }
        let flagDuration = (CFAbsoluteTimeGetCurrent() - flagStart) * 1000
        perfLogger.info("⏱️ Set updating flag: \(String(format: "%.2f", flagDuration))ms")

        // Perform expensive filtering and sorting off main thread
        let bgStart = CFAbsoluteTimeGetCurrent()
        perfLogger.info("🔧 Starting background computation...")

        let filtered = await Task.detached(priority: .userInitiated) {
            let taskStart = CFAbsoluteTimeGetCurrent()
            var result = allProducts

            // Phase 1: Category filtering
            let filterStart = CFAbsoluteTimeGetCurrent()
            switch category {
            case .all:
                break
            case .active:
                result = result.filter { $0.inventoryStatus == .active }
            case .lowStock:
                result = result.filter { $0.inventoryStatus == .lowStock }
            case .inactive:
                result = result.filter { $0.inventoryStatus == .inactive }
            }
            let filterDuration = (CFAbsoluteTimeGetCurrent() - filterStart) * 1000
            print("  ⏱️ [BG] Category filter (\(category.label)): \(String(format: "%.2f", filterDuration))ms, Result: \(result.count) items")

            // Phase 2: Status filtering
            let statusStart = CFAbsoluteTimeGetCurrent()
            result = result.filter { statusSet.contains($0.inventoryStatus) }
            let statusDuration = (CFAbsoluteTimeGetCurrent() - statusStart) * 1000
            print("  ⏱️ [BG] Status filter: \(String(format: "%.2f", statusDuration))ms, Result: \(result.count) items")

            // Phase 2.5: Inventory range filtering (only if < 100, which means "no limit")
            if maxInventory < 100 {
                let inventoryStart = CFAbsoluteTimeGetCurrent()
                result = result.filter { $0.inventoryQuantity <= Int(maxInventory) }
                let inventoryDuration = (CFAbsoluteTimeGetCurrent() - inventoryStart) * 1000
                print("  ⏱️ [BG] Inventory filter (≤\(Int(maxInventory))): \(String(format: "%.2f", inventoryDuration))ms, Result: \(result.count) items")
            }

            // Phase 3: Search filtering
            if !search.isEmpty {
                let searchStart = CFAbsoluteTimeGetCurrent()
                result = result.filter { product in
                    product.name.localizedCaseInsensitiveContains(search) ||
                    product.formattedSKU.localizedCaseInsensitiveContains(search)
                }
                let searchDuration = (CFAbsoluteTimeGetCurrent() - searchStart) * 1000
                print("  ⏱️ [BG] Search filter: \(String(format: "%.2f", searchDuration))ms, Result: \(result.count) items")
            }

            // Phase 4: Sorting
            let sortStart = CFAbsoluteTimeGetCurrent()
            let sortedProducts = result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            let sortDuration = (CFAbsoluteTimeGetCurrent() - sortStart) * 1000
            print("  ⏱️ [BG] Sorting: \(String(format: "%.2f", sortDuration))ms")

            let totalTaskDuration = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
            print("  ⏱️ [BG] Total background work: \(String(format: "%.2f", totalTaskDuration))ms")

            return sortedProducts
        }.value

        let bgDuration = (CFAbsoluteTimeGetCurrent() - bgStart) * 1000
        perfLogger.info("⏱️ Background computation: \(String(format: "%.2f", bgDuration))ms")

        // Update cache on main thread
        let updateStart = CFAbsoluteTimeGetCurrent()
        await MainActor.run {
            // Verify cache key is still valid (user might have changed filters again)
            let finalCacheKey = "\(selectedProductFilterCategory.rawValue)-\(searchText)-\(statusFilter.count)-\(Int(inventoryRange))-\(products.count)"
            if finalCacheKey == currentCacheKey {
                cachedFilteredProducts = filtered
                filterCacheKey = currentCacheKey
                perfLogger.info("✅ Cache updated - \(filtered.count) products")
            } else {
                perfLogger.warning("⚠️ Cache key mismatch, discarding results")
            }
            isUpdatingFilter = false
        }
        let updateDuration = (CFAbsoluteTimeGetCurrent() - updateStart) * 1000
        perfLogger.info("⏱️ Cache update: \(String(format: "%.2f", updateDuration))ms")

        let overallDuration = (CFAbsoluteTimeGetCurrent() - overallStart) * 1000
        perfLogger.info("✅ updateFilterCache COMPLETE: \(String(format: "%.2f", overallDuration))ms")
    }

    /// Pre-compute and cache the sorted "All Products" view
    /// Called once when data loads and when product list changes
    /// Eliminates sorting overhead on subsequent tab switches to "All Products"
    private func updateAllProductsCache() async {
        let currentKey = "all-\(products.count)"
        guard currentKey != allProductsCacheKey else {
            perfLogger.debug("✅ 'All Products' cache up to date")
            return
        }

        perfLogger.info("🔄 Pre-computing 'All Products' cache for \(products.count) items")
        let allProducts = products

        let sorted = await Task.detached(priority: .userInitiated) {
            let sortStart = CFAbsoluteTimeGetCurrent()
            let sorted = allProducts.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            let sortDuration = (CFAbsoluteTimeGetCurrent() - sortStart) * 1000
            print("  ⏱️ [BG] Pre-sort all products: \(String(format: "%.2f", sortDuration))ms")
            return sorted
        }.value

        await MainActor.run {
            allProductsSorted = sorted
            allProductsCacheKey = currentKey
            perfLogger.info("✅ 'All Products' cache ready: \(sorted.count) products")
        }
    }
}

// MARK: - View Mode Enum

enum ViewMode {
    case list
    case grid
}

// MARK: - Filter Chip Enum

enum ProductFilterCategory: String, CaseIterable {
    case all = "all"
    case active = "active"
    case lowStock = "lowStock"
    case inactive = "inactive"

    var label: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .lowStock: return "Low Stock"
        case .inactive: return "Inactive"
        }
    }

    func count(from products: [Product]) -> Int? {
        switch self {
        case .all:
            return products.count
        case .active:
            return products.filter { $0.inventoryStatus == .active }.count
        case .lowStock:
            return products.filter { $0.inventoryStatus == .lowStock }.count
        case .inactive:
            return products.filter { $0.inventoryStatus == .inactive }.count
        }
    }
}

// Note: ScrollOffsetPreferenceKey is defined in VirtualScrollView.swift

// MARK: - Preview

#Preview {
    ProductManagementView()
}
