//
//  CustomerManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData
import UIKit

struct CustomerManagementView: View {
    @EnvironmentObject private var serviceFactory: ServiceFactory
    
    private var customerRepository: CustomerRepository {
        serviceFactory.repositoryFactory.customerRepository
    }
    
    @State private var customers: [Customer] = []
    
    @State private var showingAddCustomer = false
    @State private var showingExcelImport = false
    @State private var showingExcelExport = false
    @State private var searchText = ""
    @State private var selectedCustomers: Set<String> = []
    @State private var isBatchMode = false
    @State private var showingDeleteAlert = false
    @State private var customersToDelete: [Customer] = []
    @State private var searchSuggestions: [String] = []
    @State private var recentSearches: [String] = []
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    @State private var hasMoreData = true
    private let pageSize = 50
    
    // 过滤器状态
    @State private var showingFilters = false
    @State private var selectedCity = ""
    @State private var phoneFilter = ""
    @State private var sortOption: CustomerSortOption = .name
    
    enum CustomerSortOption: String, CaseIterable {
        case name = "姓名"
        case address = "地址"
        case createdDate = "创建时间"
    }
    
    var filteredCustomers: [Customer] {
        var filtered = customers
        
        // 文本搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 城市过滤
        if !selectedCity.isEmpty {
            filtered = filtered.filter { customer in
                customer.address.localizedCaseInsensitiveContains(selectedCity)
            }
        }
        
        // 电话过滤
        if !phoneFilter.isEmpty {
            filtered = filtered.filter { customer in
                customer.phone.contains(phoneFilter)
            }
        }
        
        // 排序
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .address:
            return filtered.sorted { $0.address < $1.address }
        case .createdDate:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var hasActiveFilters: Bool {
        !selectedCity.isEmpty || sortOption != .name || !phoneFilter.isEmpty
    }
    
    var body: some View {
        mainContentView
            .navigationTitle("客户管理")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                loadCustomers()
            }
            .onChange(of: filteredCustomers.count) { oldCount, newCount in
                handleFilterCountChange(oldCount: oldCount, newCount: newCount)
            }
            .sheet(isPresented: $showingAddCustomer) {
                AddCustomerView()
            }
            .sheet(isPresented: $showingExcelImport) {
                ExcelImportView(dataType: .customers)
            }
            .sheet(isPresented: $showingExcelExport) {
                ExcelExportView(dataType: .customers)
            }
            .confirmationDialog(
                "批量操作",
                isPresented: $showingDeleteAlert,
                titleVisibility: .visible
            ) {
                confirmationDialogButtons
            } message: {
                Text("选择要执行的批量操作。删除操作不可撤销。")
            }
    }
    
    // MARK: - Main Content Views
    private var mainContentView: some View {
        VStack(spacing: 0) {
            searchAndToolbarView
            
            if showingFilters {
                filtersView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if isBatchMode && !selectedCustomers.isEmpty {
                selectionSummaryBar
            }
            
            customerListView
        }
    }
    
    @ViewBuilder
    private var confirmationDialogButtons: some View {
        Button("删除选中的客户 (\(customersToDelete.count))", role: .destructive) {
            deleteSelectedCustomers()
        }
        .disabled(customersToDelete.isEmpty)
        
        if !customersToDelete.isEmpty {
            Button("导出选中的客户") {
                exportSelectedCustomers()
            }
        }
        
        Button("取消", role: .cancel) {
            // Cancel action
        }
    }
    
    private func handleFilterCountChange(oldCount: Int, newCount: Int) {
        if oldCount != newCount && oldCount != 0 {
            announceFilterChange(newCount)
        }
    }
    
    private var searchAndToolbarView: some View {
        VStack(spacing: 12) {
            // Enhanced search with suggestions
            enhancedSearchView
            
            // Active filter indicator
            if hasActiveFilters && !showingFilters {
                filterIndicatorBar
            }
            
            // Enhanced toolbar with proper hierarchy
            enhancedToolbarView
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var enhancedSearchView: some View {
        VStack(spacing: 8) {
            searchFieldView
            searchSuggestionsView
            recentSearchesView
        }
    }
    
    private var searchFieldView: some View {
        DebouncedSearchField(
            placeholder: "搜索客户姓名、地址或电话...",
            searchText: $searchText,
            debounceTime: 0.5
        )
        .padding(.horizontal)
        .accessibilityLabel("客户搜索")
        .accessibilityHint("输入客户信息进行搜索")
        .onChange(of: searchText) { oldValue, newValue in
            updateSearchSuggestions(for: newValue)
            resetPagination()
        }
    }
    
    @ViewBuilder
    private var searchSuggestionsView: some View {
        if !searchText.isEmpty && searchSuggestions.count > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchSuggestions.prefix(5), id: \.self) { suggestion in
                        suggestionButton(for: suggestion)
                    }
                }
                .padding(.horizontal)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    @ViewBuilder
    private var recentSearchesView: some View {
        if searchText.isEmpty && !recentSearches.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("最近搜索:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(recentSearches.prefix(3), id: \.self) { recent in
                        recentSearchButton(for: recent)
                    }
                    
                    Button("清除历史") {
                        recentSearches.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
            .transition(.opacity)
        }
    }
    
    private func suggestionButton(for suggestion: String) -> some View {
        Button(suggestion) {
            searchText = suggestion
            addToRecentSearches(suggestion)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
        .accessibilityLabel("搜索建议: \(suggestion)")
    }
    
    private func recentSearchButton(for recent: String) -> some View {
        Button(recent) {
            searchText = recent
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .foregroundColor(.secondary)
    }
    
    private var filterIndicatorBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundColor(.blue)
                .font(.caption)
            
            Text("已应用筛选条件")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("清除") {
                withAnimation(.easeInOut) {
                    clearFilters()
                }
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var enhancedToolbarView: some View {
        GeometryReader { geometry in
            if geometry.size.width < 400 {
                compactToolbarView
            } else {
                fullToolbarView
            }
        }
        .frame(height: 44)
    }
    
    private var compactToolbarView: some View {
        HStack(spacing: 12) {
            // Primary action
            if isBatchMode {
                Button(action: { 
                    customersToDelete = customers.filter { selectedCustomers.contains($0.id) }
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(selectedCustomers.isEmpty)
            } else {
                Button(action: { showingAddCustomer = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("添加新客户")
            }
            
            Spacer()
            
            // Batch selection indicator
            if isBatchMode && !selectedCustomers.isEmpty {
                Text("\(selectedCustomers.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // More menu
            Menu {
                if !isBatchMode {
                    Button(action: { showingExcelImport = true }) {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingExcelExport = true }) {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                }
                
                Button(action: { toggleBatchMode() }) {
                    Label(isBatchMode ? "退出批量模式" : "进入批量模式", systemImage: isBatchMode ? "checkmark" : "list.bullet")
                }
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFilters.toggle() 
                    }
                }) {
                    Label(showingFilters ? "隐藏筛选" : "显示筛选", systemImage: "line.3.horizontal.decrease")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .overlay(alignment: .topTrailing) {
                        if hasActiveFilters {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
    
    private var fullToolbarView: some View {
        HStack(spacing: 12) {
            // Primary action - more prominent
            if isBatchMode {
                batchModeActions
            } else {
                Button(action: { showingAddCustomer = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("添加客户")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .accessibilityLabel("添加新客户")
                .accessibilityHint("双击创建新客户")
            }
            
            Spacer()
            
            // Secondary actions - grouped and less prominent
            HStack(spacing: 8) {
                // Data management menu
                Menu {
                    Button(action: { showingExcelImport = true }) {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingExcelExport = true }) {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("数据管理")
                .accessibilityHint("导入或导出客户数据")
                
                // Batch mode toggle
                Button(action: { toggleBatchMode() }) {
                    Image(systemName: isBatchMode ? "checkmark.circle.fill" : "list.bullet.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundColor(isBatchMode ? .green : .primary)
                .accessibilityLabel(isBatchMode ? "退出批量模式" : "进入批量模式")
                
                // Filter toggle with indicator
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFilters.toggle() 
                    }
                }) {
                    ZStack {
                        Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        
                        if hasActiveFilters && !showingFilters {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundColor(showingFilters ? .blue : .primary)
                .accessibilityLabel(showingFilters ? "隐藏筛选器" : "显示筛选器")
                .accessibilityValue(hasActiveFilters ? "有活跃筛选" : "无活跃筛选")
            }
        }
        .padding(.horizontal)
    }
    
    private var batchModeActions: some View {
        HStack(spacing: 12) {
            Button(action: { 
                customersToDelete = customers.filter { selectedCustomers.contains($0.id) }
                showingDeleteAlert = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("删除 (\(selectedCustomers.count))")
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            .disabled(selectedCustomers.isEmpty)
            .accessibilityLabel("删除选中的 \(selectedCustomers.count) 个客户")
            
            if !selectedCustomers.isEmpty {
                Button("全选") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedCustomers.count == filteredCustomers.count {
                            selectedCustomers.removeAll()
                        } else {
                            selectedCustomers = Set(filteredCustomers.map { $0.id })
                        }
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }
    
    private var customerListView: some View {
        List {
            if filteredCustomers.isEmpty {
                enhancedEmptyStateView
            } else {
                ForEach(Array(paginatedCustomers.enumerated()), id: \.element.id) { index, customer in
                    customerRowView(for: customer)
                        .onAppear {
                            if index >= paginatedCustomers.count - 10 && !isLoadingMore && hasMoreData {
                                loadMoreCustomersIfNeeded()
                            }
                        }
                }
                
                if isLoadingMore {
                    loadingMoreView
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listRowSeparator(.visible)
        .listSectionSeparator(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    private var paginatedCustomers: [Customer] {
        let endIndex = min((currentPage + 1) * pageSize, filteredCustomers.count)
        return Array(filteredCustomers.prefix(endIndex))
    }
    
    private var loadingMoreView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载更多...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .accessibilityLabel("正在加载更多客户")
    }
    
    private func toggleBatchMode() {
        withAnimation {
            isBatchMode.toggle()
            if !isBatchMode {
                selectedCustomers.removeAll()
            }
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Announce mode change
        announceBatchModeChange()
    }
    
    private func toggleCustomerSelection(_ customer: Customer) {
        if isBatchMode {
            let wasSelected = selectedCustomers.contains(customer.id)
            if wasSelected {
                selectedCustomers.remove(customer.id)
            } else {
                selectedCustomers.insert(customer.id)
            }
            
            // Add haptic feedback
            let feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator.selectionChanged()
            
            // Announce selection change if needed
            if selectedCustomers.count % 5 == 0 || selectedCustomers.count == 1 {
                announceSelectionChange()
            }
        }
    }
    
    private func deleteCustomer(_ customer: Customer) {
        customersToDelete = [customer]
        showingDeleteAlert = true
    }
    
    private func loadCustomers() {
        Task {
            do {
                customers = try await customerRepository.fetchCustomers()
            } catch {
                print("Error loading customers: \(error)")
            }
        }
    }
    
    private func deleteSelectedCustomers() {
        let customersToDelete = customers.filter { selectedCustomers.contains($0.id) }
        
        Task {
            do {
                for customer in customersToDelete {
                    try await customerRepository.deleteCustomer(customer)
                }
                
                selectedCustomers.removeAll()
                isBatchMode = false
                
                // Reload customers after deletion
                loadCustomers()
            } catch {
                print("Failed to delete customers: \(error)")
            }
        }
    }
    
    // MARK: - Simplified Filters View
    private var filtersView: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    cityFilterChips
                    
                    Divider()
                        .frame(height: 24)
                        .accessibilityHidden(true)
                    
                    sortFilterChips
                    
                    if hasActiveFilters {
                        clearAllFiltersButton
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }
    
    @ViewBuilder
    private var cityFilterChips: some View {
        ForEach(["全部"] + uniqueCities, id: \.self) { city in
            FilterChipView(
                title: city == "全部" ? "全部城市" : city,
                isActive: city == "全部" ? selectedCity.isEmpty : selectedCity == city,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCity = city == "全部" ? "" : city
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private var sortFilterChips: some View {
        ForEach(CustomerSortOption.allCases, id: \.self) { option in
            FilterChipView(
                title: option.rawValue,
                isActive: sortOption == option,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sortOption = option
                    }
                }
            )
        }
    }
    
    private var clearAllFiltersButton: some View {
        Button("清除全部") {
            withAnimation(.easeInOut(duration: 0.2)) {
                clearFilters()
            }
        }
        .font(.caption)
        .foregroundColor(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var uniqueCities: [String] {
        let cities = customers.map { customer in
            customer.address.components(separatedBy: " ").first ?? ""
        }
        return Array(Set(cities)).filter { !$0.isEmpty }.sorted()
    }
    
    private func clearFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedCity = ""
            phoneFilter = ""
            sortOption = .name
        }
        
        // Add haptic feedback for filter clear
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
        
        // Reset pagination when filters change
        resetPagination()
    }
    
    // MARK: - Search Enhancement Functions
    private func updateSearchSuggestions(for searchTerm: String) {
        guard !searchTerm.isEmpty else {
            searchSuggestions = []
            return
        }
        
        let term = searchTerm.lowercased()
        let customerNames = customers.map { $0.name.lowercased() }
        let customerCities = customers.compactMap { customer -> String? in
            let components = customer.address.components(separatedBy: " ")
            return components.first?.lowercased()
        }
        
        let suggestions = Set(customerNames + customerCities)
            .filter { $0.contains(term) && $0 != term }
            .sorted()
        
        searchSuggestions = Array(suggestions)
    }
    
    private func addToRecentSearches(_ search: String) {
        guard !search.isEmpty else { return }
        
        // Remove if already exists
        recentSearches.removeAll { $0 == search }
        
        // Add to beginning
        recentSearches.insert(search, at: 0)
        
        // Keep only 5 recent searches
        if recentSearches.count > 5 {
            recentSearches = Array(recentSearches.prefix(5))
        }
    }
    
    // MARK: - Enhanced Customer Row View
    private func customerRowView(for customer: Customer) -> some View {
        Group {
            if isBatchMode {
                CustomerRowView(
                    customer: customer,
                    isSelected: selectedCustomers.contains(customer.id),
                    isBatchMode: isBatchMode,
                    onSelect: { toggleCustomerSelection(customer) }
                )
            } else {
                NavigationLink(destination: CustomerDetailView(customer: customer)) {
                    CustomerRowView(
                        customer: customer,
                        isSelected: false,
                        isBatchMode: false,
                        onSelect: {}
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                // Add haptic feedback for destructive action
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.notificationOccurred(.warning)
                deleteCustomer(customer)
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                // Add haptic feedback for edit action
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                feedbackGenerator.impactOccurred()
                editCustomer(customer)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                // Add haptic feedback for phone call
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                feedbackGenerator.impactOccurred()
                callCustomer(customer)
            } label: {
                Label("拨打", systemImage: "phone")
            }
            .tint(.green)
        }
        .accessibilityActions {
            Button("编辑客户") { editCustomer(customer) }
            Button("删除客户") { deleteCustomer(customer) }
            Button("拨打电话") { callCustomer(customer) }
        }
    }
    
    // MARK: - Customer Actions
    private func editCustomer(_ customer: Customer) {
        // TODO: Navigate to edit view
        print("Editing customer: \(customer.name)")
    }
    
    private func callCustomer(_ customer: Customer) {
        guard let url = URL(string: "tel://\(customer.phone)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Enhanced Empty State
    private var enhancedEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "person.2" : "person.2.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "没有客户数据" : "未找到匹配的客户")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? "点击下方按钮添加第一个客户" : "尝试修改搜索条件或清除筛选器")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if searchText.isEmpty {
                Button(action: { showingAddCustomer = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加第一个客户")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("添加第一个客户")
                .accessibilityHint("双击创建新客户")
            } else if hasActiveFilters {
                Button(action: { 
                    withAnimation {
                        clearFilters()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clear.fill")
                        Text("清除筛选")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                .accessibilityLabel("清除所有筛选条件")
                .accessibilityHint("双击移除当前的搜索和筛选条件")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(searchText.isEmpty ? "没有客户数据" : "未找到匹配的客户")
        .accessibilityValue(searchText.isEmpty ? "点击下方按钮添加第一个客户" : "当前搜索条件: \(searchText)。尝试修改搜索条件或清除筛选器")
    }
    
    // MARK: - Selection Summary Bar
    private var selectionSummaryBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("已选择 \(selectedCustomers.count) 个客户")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if selectedCustomers.count == filteredCustomers.count {
                    Text("已全选")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("共 \(filteredCustomers.count) 个客户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("全选") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedCustomers.count == filteredCustomers.count {
                            selectedCustomers.removeAll()
                        } else {
                            selectedCustomers = Set(filteredCustomers.map { $0.id })
                        }
                    }
                    
                    let feedbackGenerator = UISelectionFeedbackGenerator()
                    feedbackGenerator.selectionChanged()
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
                
                Button("清除") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCustomers.removeAll()
                    }
                    
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                    feedbackGenerator.impactOccurred()
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("选择统计")
        .accessibilityValue("已选择 \(selectedCustomers.count) 个，共 \(filteredCustomers.count) 个客户")
    }
    
    // MARK: - Export Functions
    private func exportSelectedCustomers() {
        let selected = customers.filter { selectedCustomers.contains($0.id) }
        // TODO: Implement export functionality
        print("Exporting \(selected.count) customers")
    }
    
    // MARK: - Performance Optimizations
    private func loadMoreCustomersIfNeeded() {
        guard !isLoadingMore && hasMoreData else { return }
        
        let totalAvailable = filteredCustomers.count
        let currentlyLoaded = paginatedCustomers.count
        
        if currentlyLoaded < totalAvailable {
            isLoadingMore = true
            
            // Simulate network delay for demonstration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.currentPage += 1
                
                let newEndIndex = min((self.currentPage + 1) * self.pageSize, totalAvailable)
                self.hasMoreData = newEndIndex < totalAvailable
                self.isLoadingMore = false
            }
        } else {
            hasMoreData = false
        }
    }
    
    private func resetPagination() {
        currentPage = 0
        hasMoreData = true
        isLoadingMore = false
    }
    
    // Optimized search with debouncing and background processing
    private func performOptimizedSearch(_ searchTerm: String) {
        // Reset pagination when search changes
        resetPagination()
        
        Task {
            // Perform filtering on background queue for better performance
            let filtered = await withTaskGroup(of: [Customer].self) { group in
                group.addTask {
                    // Since searchCustomers method may not exist, use the existing filtered logic
                    let allCustomers = try? await self.customerRepository.fetchCustomers()
                    return self.filterCustomers(allCustomers ?? [], searchTerm: searchTerm)
                }
                
                var results: [Customer] = []
                for await result in group {
                    results = result
                }
                return results
            }
            
            await MainActor.run {
                // Update UI on main thread
                if searchTerm == self.searchText {
                    // Only update if search hasn't changed while processing
                    self.customers = filtered
                }
            }
        }
    }
    
    private func filterCustomers(_ customers: [Customer], searchTerm: String) -> [Customer] {
        var filtered = customers
        
        // Text search filtering
        if !searchTerm.isEmpty {
            filtered = filtered.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchTerm) ||
                customer.address.localizedCaseInsensitiveContains(searchTerm) ||
                customer.phone.contains(searchTerm)
            }
        }
        
        // Apply other filters
        if !selectedCity.isEmpty {
            filtered = filtered.filter { customer in
                customer.address.localizedCaseInsensitiveContains(selectedCity)
            }
        }
        
        if !phoneFilter.isEmpty {
            filtered = filtered.filter { customer in
                customer.phone.contains(phoneFilter)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .address:
            return filtered.sorted { $0.address < $1.address }
        case .createdDate:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - Accessibility Helpers
    private func announceFilterChange(_ count: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let announcement = "筛选结果已更新，显示 \(count) 个客户"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
    
    private func announceBatchModeChange() {
        let announcement = isBatchMode ? "已进入批量选择模式" : "已退出批量选择模式"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    private func announceSelectionChange() {
        if selectedCustomers.count == 1 {
            UIAccessibility.post(notification: .announcement, argument: "已选择 1 个客户")
        } else if selectedCustomers.count > 1 {
            UIAccessibility.post(notification: .announcement, argument: "已选择 \(selectedCustomers.count) 个客户")
        }
    }
}

struct CustomerRowView: View {
    let customer: Customer
    let isSelected: Bool
    let isBatchMode: Bool
    let onSelect: () -> Void
    
    var body: some View {
        customerRowContent
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background {
                customerRowBackground
            }
            .overlay(alignment: .trailing) {
                chevronIndicator
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isBatchMode ? [.isButton] : [.isButton, .startsMediaSession])
            .accessibilityHint(isBatchMode ? "双击选择或取消选择" : "双击查看详情，左滑拨打电话，右滑编辑或删除")
    }
    
    private var customerRowContent: some View {
        HStack(spacing: 16) {
            selectionCheckbox
            customerAvatar
            customerInformation
        }
    }
    
    @ViewBuilder
    private var selectionCheckbox: some View {
        if isBatchMode {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isSelected ? "取消选择客户" : "选择客户")
            .accessibilityValue(customer.name)
        }
    }
    
    private var customerAvatar: some View {
        Circle()
            .fill(Color.blue.gradient)
            .frame(width: 40, height: 40)
            .overlay {
                Text(String(customer.name.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)
    }
    
    private var customerInformation: some View {
        VStack(alignment: .leading, spacing: 6) {
            customerNameAndDate
            customerAddressRow
            customerPhoneRow
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("客户信息")
        .accessibilityValue("姓名：\(customer.name)，地址：\(customer.address)，电话：\(customer.phone)")
    }
    
    private var customerNameAndDate: some View {
        HStack {
            Text(customer.name)
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(customer.createdAt, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var customerAddressRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "location")
                .foregroundColor(.secondary)
                .font(.caption)
            
            Text(customer.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var customerPhoneRow: some View {
        if !customer.phone.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "phone")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text(customer.phone)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var customerRowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
    }
    
    @ViewBuilder
    private var chevronIndicator: some View {
        if !isBatchMode {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
        }
    }
}

// MARK: - Customer Detail View
struct CustomerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let customer: Customer
    
    @State private var showingEditSheet = false
    @Query private var outOfStockItems: [CustomerOutOfStock]
    
    var customerOutOfStockItems: [CustomerOutOfStock] {
        outOfStockItems.filter { $0.customer?.id == customer.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                customerInfoView
                outOfStockHistoryView
            }
            .padding()
        }
        .navigationTitle("客户详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCustomerView(customer: customer)
        }
    }
    
    private var customerInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("客户信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("客户姓名:")
                    Text(customer.name)
                }
                HStack {
                    Text("客户地址:")
                    Text(customer.address)
                }
                HStack {
                    Text("联系电话:")
                    Text(customer.phone)
                }
                HStack {
                    Text("创建时间:")
                    Text(customer.createdAt, style: .date)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var outOfStockHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("缺货记录")
                .font(.headline)
            
            if customerOutOfStockItems.isEmpty {
                Text("暂无缺货记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(customerOutOfStockItems.sorted { $0.requestDate > $1.requestDate }) { item in
                        NavigationLink(destination: CustomerOutOfStockDetailView(item: item)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.product?.name ?? "未知产品")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("数量: \(item.quantity)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(item.status.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(statusColor(item.status).opacity(0.2))
                                        .foregroundColor(statusColor(item.status))
                                        .cornerRadius(4)
                                    
                                    Text(item.requestDate, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func statusColor(_ status: OutOfStockStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Edit Customer View
struct EditCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let customer: Customer
    
    @State private var name: String
    @State private var address: String
    @State private var phone: String
    
    init(customer: Customer) {
        self.customer = customer
        _name = State(initialValue: customer.name)
        _address = State(initialValue: customer.address)
        _phone = State(initialValue: customer.phone)
    }
    
    var body: some View {
        ModernNavigationView {
            Form {
                Section("客户信息") {
                    TextField("客户姓名", text: $name)
                    TextField("客户地址", text: $address)
                    TextField("联系电话", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("编辑客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        customer.name = name
        customer.address = address
        customer.phone = phone
        customer.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving customer: \(error)")
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChipView: View {
    let title: String
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.blue : Color(.systemGray5))
                .foregroundColor(isActive ? .white : .primary)
                .clipShape(Capsule())
        }
        .accessibilityLabel("筛选选项: \(title)")
        .accessibilityValue(isActive ? "已选中" : "未选中")
        .accessibilityHint("双击以\(isActive ? "取消" : "")选择此筛选条件")
    }
}

#Preview {
    CustomerManagementView()
        .modelContainer(for: Customer.self, inMemory: true)
} 
