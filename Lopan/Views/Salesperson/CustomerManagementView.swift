//
//  CustomerManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//  Reconstructed by Claude Code on 2025/10/02.
//

import SwiftUI
import SwiftData

enum CustomerDeletionError: Error {
    case validationServiceNotInitialized
}

// MARK: - Filter & Sort Enums

enum CustomerFilterTab: String, CaseIterable {
    case all = "全部客户"
    case recent = "最近"
    case favourite = "收藏"
}

enum CustomerSortOrder: String, CaseIterable {
    case ascending = "A-Z"
    case descending = "Z-A"
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
    @State private var sortOrder: CustomerSortOrder = .ascending
    @State private var showingAddCustomer = false
    @State private var showingDeleteAlert = false
    @State private var customerToDelete: Customer?
    @State private var showingDeletionWarning = false
    @State private var deletionValidationResult: CustomerDeletionValidationService.DeletionValidationResult?
    @State private var validationService: CustomerDeletionValidationService?
    @State private var isLoadingCustomers = false
    @State private var customerToEdit: Customer?
    @State private var scrollProxy: ScrollViewProxy?

    // Heights for precise alphabetical index positioning
    @State private var headerHeight: CGFloat = 0
    @State private var searchHeight: CGFloat = 0
    @State private var sortHeight: CGFloat = 0

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Seven days ago for "Recent" filter
    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }
    
    // MARK: - Computed Properties

    /// Filtered and sorted customers based on tab and search
    var filteredCustomers: [Customer] {
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

        // Apply sorting using cached pinyin for performance
        filtered = filtered.sorted { customer1, customer2 in
            let name1 = customer1.pinyinName.uppercased()
            let name2 = customer2.pinyinName.uppercased()
            return sortOrder == .ascending ? name1 < name2 : name1 > name2
        }

        return filtered
    }

    /// Customers grouped by first letter for sectioned list
    /// Uses cached pinyin values for optimal performance
    var sectionedCustomers: [(letter: String, customers: [Customer])] {
        let grouped = Dictionary(grouping: filteredCustomers) { customer -> String in
            // Use pre-computed pinyin initial (cached in model)
            // "张三" → "Z", "李明" → "L", "Alice" → "A"
            // Returns cached value, no expensive CFStringTransform call
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

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                // Header with tabs
                headerView
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: HeaderHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )

                // Search section
                searchSection
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: SearchHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )

                // Sort section
                sortSection
                    .padding(.bottom, LopanSpacing.sm)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: SortHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )

                // Customer list
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
            .onPreferenceChange(SearchHeightKey.self) { searchHeight = $0 }
            .onPreferenceChange(SortHeightKey.self) { sortHeight = $0 }
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

            // Auto-migrate pinyin cache for existing customers (runs once)
            Task {
                // Wait for customers to load first
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                await migratePinyinIfNeeded()
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
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
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

    /// Search section with translucent design
    private var searchSection: some View {
        TranslucentSearchBar(
            text: $searchText,
            placeholder: "搜索客户姓名或地址"
        )
        .padding(.horizontal, LopanSpacing.md)
        .padding(.vertical, LopanSpacing.sm)
    }

    /// Sort section with two-pill design
    private var sortSection: some View {
        HStack(spacing: LopanSpacing.sm) {
            Text("排序方式")
                .font(LopanTypography.labelMedium)
                .foregroundColor(LopanColors.textSecondary)

            Spacer()

            HStack(spacing: LopanSpacing.xs) {
                ForEach(CustomerSortOrder.allCases, id: \.self) { order in
                    sortPillButton(order: order)
                }
            }
        }
        .padding(.horizontal, LopanSpacing.md)
        //.padding(.vertical, LopanSpacing.xs)
    }

    /// Individual sort pill button
    private func sortPillButton(order: CustomerSortOrder) -> some View {
        Button(action: {
            withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
                sortOrder = order
            }
        }) {
            Text(order.rawValue)
                .font(LopanTypography.labelMedium)
                .foregroundColor(sortOrder == order ? LopanColors.textOnPrimary : LopanColors.textSecondary)
                .padding(.horizontal, LopanSpacing.md)
                .padding(.vertical, LopanSpacing.xs)
                .background(
                    Capsule()
                        .fill(sortOrder == order ? LopanColors.primary : Color(UIColor.systemGray5))
                )
        }
        .accessibilityLabel("排序: \(order.rawValue)")
        .accessibilityAddTraits(sortOrder == order ? [.isSelected] : [])
    }
    
    /// Main customer list with sections
    private var customersListView: some View {
        Group {
            if filteredCustomers.isEmpty && !isLoadingCustomers {
                emptyStateView
            } else if isLoadingCustomers {
                loadingView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: LopanSpacing.sm) {
                            ForEach(sectionedCustomers, id: \.letter) { section in
                                // Invisible anchor for letter navigation
                                Color.clear
                                    .frame(height: 0)
                                    .id(section.letter)

                                // Customer cards without section headers
                                ForEach(section.customers, id: \.id) { customer in
                                    NavigationLink(
                                        destination: CustomerDetailView(customer: customer)
                                            .onAppear {
                                                updateLastViewed(customer)
                                            }
                                    ) {
                                        CustomerCardView(
                                            customer: customer,
                                            onCall: { callCustomer(customer) },
                                            onMessage: { messageCustomer(customer) },
                                            onEdit: { customerToEdit = customer },
                                            onToggleFavorite: { toggleFavorite(customer) },
                                            onDelete: { handleDeleteCustomer(customer) }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            // Customer count at bottom of list
                            if !filteredCustomers.isEmpty {
                                VStack(spacing: LopanSpacing.xs) {
                                    Divider()
                                        .opacity(0.3)

                                    Text("\(filteredCustomers.count) 位客户")
                                        .font(LopanTypography.caption)
                                        .foregroundColor(LopanColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.leading, LopanSpacing.md)
                        .padding(.trailing, 44)
                        .padding(.vertical, LopanSpacing.sm)
                    }
                    .refreshable {
                        await refreshCustomers()
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
            }
        }
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
    /// Range: from bottom of sort section to top of bottom navigation bar
    private func letterFilterTopPadding(geometry: GeometryProxy) -> CGFloat {
        // Where customer list display area starts (bottom of sort section)
        let displayAreaStart = headerHeight + searchHeight + sortHeight

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
            do {
                isLoadingCustomers = true
                customers = try await customerRepository.fetchCustomers()
                isLoadingCustomers = false
            } catch {
                print("Error loading customers: \(error)")
                isLoadingCustomers = false
            }
        }
    }

    private func refreshCustomers() async {
        do {
            customers = try await customerRepository.fetchCustomers()
        } catch {
            print("Error refreshing customers: \(error)")
        }
    }

    /// Migrates existing customers to populate pinyin cache
    /// This runs automatically on first load for customers with empty pinyin values
    private func migratePinyinIfNeeded() async {
        // Check if any customers need migration
        let needsMigration = customers.contains { $0.pinyinInitial.isEmpty || $0.pinyinName.isEmpty }

        guard needsMigration else {
            print("✓ All customers have pinyin cache populated")
            return
        }

        print("🔄 Starting pinyin cache migration for existing customers...")

        var migratedCount = 0

        for customer in customers where customer.pinyinInitial.isEmpty || customer.pinyinName.isEmpty {
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
    @State private var address = ""
    @State private var phone = ""
    @State private var isSaving = false
    @State private var isCheckingDuplicate = false
    @State private var duplicateError: String?

    let onSave: (Customer) -> Void

    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }

    var isValid: Bool {
        !name.isEmpty && !address.isEmpty && duplicateError == nil && !isCheckingDuplicate
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                Text("客户信息")
                    .font(LopanTypography.headlineSmall)
                    .foregroundColor(LopanColors.textPrimary)
                
                VStack(spacing: LopanSpacing.md) {
                    LopanTextField(
                        title: "客户姓名",
                        placeholder: "请输入客户姓名",
                        text: $name,
                        variant: .outline,
                        state: {
                            if duplicateError != nil {
                                return .error
                            } else if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                return .error
                            } else {
                                return .normal
                            }
                        }(),
                        isRequired: true,
                        icon: "person",
                        errorText: duplicateError ?? (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "客户姓名不能为空" : nil)
                    )
                    .onChange(of: name) { _, newValue in
                        Task {
                            await checkForDuplicates()
                        }
                    }

                    LopanTextField(
                        title: "客户地址",
                        placeholder: "请输入客户地址",
                        text: $address,
                        variant: .outline,
                        state: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .error : .normal,
                        isRequired: true,
                        icon: "location",
                        errorText: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "客户地址不能为空" : nil
                    )

                    LopanTextField(
                        title: "联系电话",
                        placeholder: "请输入联系电话（可选）",
                        text: $phone,
                        variant: .outline,
                        keyboardType: .phonePad,
                        icon: "phone",
                        helperText: "联系电话为可选信息"
                    )
                }
                
                Spacer()
            }
            .screenPadding()
            .navigationTitle("添加客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCustomer()
                    }
                    .disabled(!isValid || isSaving)
                }
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
        let customer = Customer(name: name, address: address, phone: phone)
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

struct SearchHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SortHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    CustomerManagementView()
        .modelContainer(for: Customer.self, inMemory: true)
}
