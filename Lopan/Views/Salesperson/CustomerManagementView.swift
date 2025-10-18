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
    case all = "All"
    case recent = "Recent"
    case favourite = "Collected"
}

// MARK: - Main View

struct CustomerManagementView: View {
    // Filter selection binding from parent
    @Binding var selectedTab: CustomerFilterTab

    // Scroll state binding to parent for dynamic tab switching
    @Binding var isScrolled: Bool

    // Manual collapse flag binding - prioritizes user tap over scroll events
    @Binding var manuallyCollapsed: Bool

    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }

    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var showingDeleteAlert = false
    @State private var customerToDelete: Customer?
    @State private var showingDeletionWarning = false
    @State private var deletionValidationResult: CustomerDeletionValidationService.DeletionValidationResult?
    @State private var validationService: CustomerDeletionValidationService?
    @State private var isLoadingCustomers = false
    @State private var customerToEdit: Customer?
    @State private var selectedCustomer: Customer?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isSearchActive: Bool = false
    @State private var searchDebounceTask: Task<Void, Never>?

    // Customer state
    @State private var customers: [Customer] = [] // All customers from repository
    @State private var displayedCustomers: [Customer] = [] // Filtered subset for display

    // Scroll tracking for tab transformation
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPhase: ScrollPhase = .idle  // Track scroll interaction state

    // Automatic refresh state
    @State private var refreshTimer: Timer?
    @State private var lastRefreshDate: Date?

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Seven days ago for "Recent" filter
    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    // Performance logging
    private let perfLogger = Logger(subsystem: "com.lopan.performance", category: "customer-list")

    // MARK: - Computed Properties

    /// Filtered and sorted customers based on tab and search
    var filteredCustomers: [Customer] {
        var result = customers

        // Apply tab filter
        switch selectedTab {
        case .all:
            break // Show all
        case .recent:
            result = result.filter { customer in
                if let lastViewed = customer.lastViewedAt {
                    return lastViewed >= sevenDaysAgo
                }
                return false
            }
        case .favourite:
            result = result.filter { $0.isFavorite }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.address.localizedCaseInsensitiveContains(searchText) ||
                customer.phone.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Always sort A-Z (already pre-sorted from repository, but re-sort after filtering)
        return result.sorted {
            $0.pinyinName.uppercased() < $1.pinyinName.uppercased()
        }
    }

    /// Customers grouped by first letter for sectioned list
    /// Works with paginated displayedCustomers (already filtered)
    var sectionedCustomers: [(letter: String, customers: [Customer])] {
        let grouped = Dictionary(grouping: displayedCustomers) { customer -> String in
            // Use pre-computed pinyin initial (cached in model)
            // "张三" → "Z", "李明" → "L", "Alice" → "A"
            return customer.pinyinInitial.isEmpty ? "#" : customer.pinyinInitial
        }

        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, customers: $0.value) }
    }

    /// Available letters for the section index
    var availableLetters: Set<String> {
        Set(sectionedCustomers.map { $0.letter })
    }

    /// Determines if the alphabetical section index should be displayed
    private var showsAlphabeticalIndex: Bool {
        !sectionedCustomers.isEmpty && selectedTab == .all && searchText.isEmpty
    }

    /// Determines if we need extra scrollable height for search bar collapse
    /// When there are few customers, content is too short to scroll, preventing search bar collapse
    private var needsExtraScrollHeight: Bool {
        displayedCustomers.count < 10
    }

    // MARK: - Body

    var body: some View {
        let _ = perfLogger.debug("🎨 body render - Tab: \(selectedTab.rawValue), Total: \(customers.count), Displayed: \(displayedCustomers.count)")

        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Customer list (with native searchable)
                customersListView
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
        }
        .navigationTitle("客户")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task {
                        await refreshCustomers()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoadingCustomers)
            }

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

            // Start automatic refresh timer
            startAutomaticRefresh()

            // Auto-migrate pinyin cache for existing customers (runs in background)
            Task.detached(priority: .utility) {
                // Wait for customers to load first
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                await migratePinyinIfNeeded()
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            perfLogger.info("🔄 Filter tab switched: \(oldTab.rawValue) → \(newTab.rawValue)")
            displayedCustomers = filteredCustomers
        }
        .onChange(of: searchText) { _, newValue in
            // Debounce search to avoid excessive filtering
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                displayedCustomers = filteredCustomers
            }
        }
        .onChange(of: customers.count) { _, _ in
            displayedCustomers = filteredCustomers
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App came to foreground - start automatic refresh
                startAutomaticRefresh()
                // Refresh immediately if last refresh was more than 60 seconds ago
                if let lastRefresh = lastRefreshDate,
                   Date().timeIntervalSince(lastRefresh) > 60 {
                    Task {
                        await refreshCustomers()
                    }
                }
            case .inactive, .background:
                // App going to background - stop timer to save battery
                stopAutomaticRefresh()
            @unknown default:
                break
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            stopAutomaticRefresh()
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

    /// Main customer list with sections (includes native searchable)
    private var customersListView: some View {
        Group {
            if displayedCustomers.isEmpty && !isLoadingCustomers {
                emptyStateView
            } else if isLoadingCustomers && displayedCustomers.isEmpty {
                loadingView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
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
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                    }
                                } header: {
                                    // Visible section header for alphabetical navigation
                                    Text(section.letter)
                                        .font(LopanTypography.titleSmall)
                                        .foregroundColor(LopanColors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(LopanColors.backgroundPrimary.opacity(0.95))
                                        .id(section.letter) // Anchor for scrollTo
                                }
                            }

                            // Customer count at bottom
                            if !displayedCustomers.isEmpty {
                                VStack(spacing: LopanSpacing.xs) {
                                    Divider()
                                        .opacity(0.3)

                                    Text("\(displayedCustomers.count) 位客户")
                                        .font(LopanTypography.caption)
                                        .foregroundColor(LopanColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                            }

                            // Extra scrollable space to enable search bar collapse when there are few items
                            if needsExtraScrollHeight {
                                Color.clear
                                    .frame(height: 500)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollPhaseChange { oldPhase, newPhase in
                        scrollPhase = newPhase
                        print("🌀 [CustomerManagementView] Scroll phase: \(oldPhase) → \(newPhase)")
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        // Extract content offset Y position
                        geometry.contentOffset.y
                    } action: { oldValue, newValue in
                        // Update isScrolled binding: scrolled down if offset > 5 (minimal threshold)
                        let isNowScrolled = newValue > 5
                        let shouldExpand = newValue < 3 && isScrolled  // Reverse scroll to near top

                        print("📊 [CustomerManagementView] offset: \(newValue), phase: \(scrollPhase), isScrolled: \(isScrolled), manual: \(manuallyCollapsed)")

                        if shouldExpand {
                            // iOS 26 native behavior: Scroll to top → expand tab bar and reset manual flag
                            isScrolled = false
                            manuallyCollapsed = false
                            print("⬆️ [CustomerManagementView] Scrolled to top, expanding")
                        } else if manuallyCollapsed {
                            // Manual collapse is active - only reset on NEW DOWNWARD gesture
                            if scrollPhase == .interacting && newValue > oldValue && isNowScrolled && !isScrolled {
                                // User started DOWNWARD scroll gesture → reset manual collapse
                                manuallyCollapsed = false
                                isScrolled = true
                                print("🔄 [CustomerManagementView] New downward gesture detected, resetting manual collapse")
                            } else {
                                // Upward scroll, momentum, or idle → ignore
                                print("🚫 [CustomerManagementView] Ignoring scroll (phase: \(scrollPhase), direction: \(newValue > oldValue ? "down" : "up"))")
                            }
                        } else if isScrolled != isNowScrolled {
                            isScrolled = isNowScrolled
                            print("✅ [CustomerManagementView] isScrolled → \(isNowScrolled)")
                        }
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
    /// Range: from top of view to top of bottom navigation bar
    private func letterFilterTopPadding(geometry: GeometryProxy) -> CGFloat {
        // Customer list starts from top (no header)
        let displayAreaStart: CGFloat = 0

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

    // MARK: - Data Operations

    private func loadCustomers() {
        Task {
            await refreshCustomers()
        }
    }

    private func refreshCustomers() async {
        isLoadingCustomers = true

        do {
            perfLogger.info("📥 Loading all customers")
            let fetchedCustomers = try await customerRepository.fetchCustomers()

            await MainActor.run {
                customers = fetchedCustomers
                displayedCustomers = filteredCustomers
                isLoadingCustomers = false
                lastRefreshDate = Date()

                perfLogger.info("✅ Loaded \(fetchedCustomers.count) customers")
            }
        } catch {
            perfLogger.error("❌ Error loading customers: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingCustomers = false
            }
        }
    }

    /// Start automatic refresh timer (60-second intervals)
    private func startAutomaticRefresh() {
        // Stop existing timer if any
        stopAutomaticRefresh()

        perfLogger.debug("🔄 Starting automatic refresh timer (60s intervals)")

        // Create timer that fires every 60 seconds on main thread
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshCustomers()
            }
        }

        // Ensure timer runs even during scroll interactions
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Stop automatic refresh timer
    private func stopAutomaticRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        perfLogger.debug("⏸️ Stopped automatic refresh timer")
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
                        displayedCustomers.removeAll { $0.id == customer.id }
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
                    // Remove from local arrays with animation
                    withAnimation {
                        customers.removeAll { $0.id == customer.id }
                        displayedCustomers.removeAll { $0.id == customer.id }
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

// Note: ScrollOffsetPreferenceKey is defined in VirtualScrollView.swift

#Preview {
    CustomerManagementView(
        selectedTab: .constant(.all),
        isScrolled: .constant(false),
        manuallyCollapsed: .constant(false)
    )
    .modelContainer(for: Customer.self, inMemory: true)
}
