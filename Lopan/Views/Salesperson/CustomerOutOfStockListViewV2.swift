//
//  CustomerOutOfStockListViewV2.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct CustomerOutOfStockListViewV2: View {
    @StateObject private var viewModel: CustomerOutOfStockViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDatePicker = false
    @State private var scrollOffset: CGFloat = 0
    @State private var listVisibleItems: Set<String> = []
    
    // Animation states
    @State private var headerAnimationOffset: CGFloat = -50
    @State private var searchBarAnimationScale: CGFloat = 0.9
    
    @EnvironmentObject private var serviceFactory: ServiceFactory
    
    init() {
        // Initialize with a placeholder, will be set from environment
        _viewModel = StateObject(wrappedValue: CustomerOutOfStockViewModel(service: .placeholder()))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all, edges: .top)
                
                VStack(spacing: 0) {
                    headerSection
                    searchSection
                    filterChipsSection
                    contentSection
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $viewModel.showingFilterSheet) {
                OutOfStockFilterSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddSheet) {
                AddCustomerOutOfStockViewV2()
            }
            .alert("删除确认", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await viewModel.deleteSelectedItems()
                    }
                }
            } message: {
                Text("确定要删除选中的 \(viewModel.selectedItems.count) 个缺货记录吗？此操作无法撤销。")
            }
            .alert("错误", isPresented: .constant(viewModel.error != nil)) {
                Button("确定") {
                    viewModel.clearError()
                }
                Button("重试") {
                    Task {
                        await viewModel.refreshData()
                    }
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .onAppear {
                // Initialize the real service if it's still a placeholder
                let realService = serviceFactory.customerOutOfStockService
                viewModel.updateService(realService)
                animateInitialAppearance()
                setupMemoryWarningObserver()
                viewModel.preloadAdjacentData()
            }
            .onDisappear {
                removeMemoryWarningObserver()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Navigation header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if viewModel.hasActiveFilters {
                        Text("\(viewModel.activeFiltersCount) 个筛选条件已激活")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    if viewModel.isInSelectionMode {
                        selectionModeButtons
                    } else {
                        normalModeButtons
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Date navigation bar
            dateNavigationBar
        }
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .offset(y: headerAnimationOffset)
    }
    
    private var selectionModeButtons: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.selectAll) {
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            Button(action: { viewModel.showingDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .disabled(viewModel.selectedItems.isEmpty)
            
            Button(action: viewModel.exitSelectionMode) {
                Text("取消")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var normalModeButtons: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.showingFilterSheet = true }) {
                ZStack {
                    Circle()
                        .fill(viewModel.hasActiveFilters ? Color.blue : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(viewModel.hasActiveFilters ? .white : .primary)
                    
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -12)
                    }
                }
            }
            
            Button(action: { viewModel.showingAddSheet = true }) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // MARK: - Date Navigation Bar
    
    private var dateNavigationBar: some View {
        HStack {
            Button(action: previousDay) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(action: { showingDatePicker = true }) {
                VStack(spacing: 2) {
                    Text(viewModel.selectedDate, style: .date)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(dayOfWeek(viewModel.selectedDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.selectedDate)
            }
            
            Spacer()
            
            Button(action: nextDay) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        LopanSearchBar(
            searchText: $viewModel.searchText,
            placeholder: "搜索客户、产品、尺寸、颜色、备注...",
            suggestions: [],
            style: .standard,
            showVoiceSearch: false,
            onClear: { viewModel.searchText = "" },
            onSearch: { text in
                viewModel.performImmediateSearch(text)
            }
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .scaleEffect(searchBarAnimationScale)
    }
    
    // MARK: - Filter Chips Section
    
    private var filterChipsSection: some View {
        Group {
            if viewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let customer = viewModel.selectedCustomer {
                            FilterChip(
                                title: "客户: \(customer.name)",
                                onRemove: { viewModel.selectedCustomer = nil }
                            )
                        }
                        
                        if let product = viewModel.selectedProduct {
                            FilterChip(
                                title: "产品: \(product.name)",
                                onRemove: { viewModel.selectedProduct = nil }
                            )
                        }
                        
                        if viewModel.statusFilter != .all {
                            FilterChip(
                                title: "状态: \(viewModel.statusFilter.displayName)",
                                onRemove: { viewModel.statusFilter = .all }
                            )
                        }
                        
                        if let address = viewModel.selectedAddress {
                            FilterChip(
                                title: "地址: \(address)",
                                onRemove: { viewModel.selectedAddress = nil }
                            )
                        }
                        
                        if !viewModel.searchText.isEmpty {
                            FilterChip(
                                title: "搜索: \(viewModel.searchText)",
                                onRemove: { viewModel.searchText = "" }
                            )
                        }
                        
                        // Clear all button
                        Button(action: viewModel.clearAllFilters) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                Text("清除全部")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
                .scaleEffect(viewModel.filterChipAnimationScale)
            }
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingView
            } else if viewModel.items.isEmpty {
                OutOfStockEmptyStateView(
                    hasActiveFilters: viewModel.hasActiveFilters,
                    onClearFilters: viewModel.clearAllFilters,
                    onAddNew: { viewModel.showingAddSheet = true }
                )
            } else {
                listView
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载数据...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - List View
    
    private var listView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    OutOfStockCardView(
                        item: item,
                        isSelected: viewModel.selectedItems.contains(item.id),
                        isInSelectionMode: viewModel.isInSelectionMode,
                        onTap: {
                            if viewModel.isInSelectionMode {
                                viewModel.toggleSelection(for: item)
                            } else {
                                // Navigate to detail view
                            }
                        },
                        onLongPress: {
                            if !viewModel.isInSelectionMode {
                                viewModel.enterSelectionMode()
                                viewModel.toggleSelection(for: item)
                            }
                        }
                    )
                    .id(item.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .onAppear {
                        listVisibleItems.insert(item.id)
                        
                        // Load more data when approaching end
                        if index >= viewModel.items.count - 5 {
                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                    }
                    .onDisappear {
                        listVisibleItems.remove(item.id)
                    }
                    .offset(y: viewModel.listItemAnimationOffset)
                }
                
                // Load more indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载更多...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.clear)
        }
    }
    
    // MARK: - Animation Methods
    
    private func animateInitialAppearance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.6)) {
                headerAnimationOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                searchBarAnimationScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.animateFilterChips()
        }
    }
    
    // MARK: - Date Navigation Methods
    
    private func previousDay() {
        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.selectedDate = previousDate
        }
        
        Task {
            await viewModel.loadDataForDate(previousDate)
        }
    }
    
    private func nextDay() {
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.selectedDate = nextDate
        }
        
        Task {
            await viewModel.loadDataForDate(nextDate)
        }
    }
    
    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleMemoryWarning()
        }
    }
    
    private func removeMemoryWarningObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    private func handleMemoryWarning() {
        print("🚨 Memory warning received - optimizing memory usage")
        
        // Optimize ViewModel memory usage
        viewModel.handleMemoryWarning()
        
        // Clear animation states
        withAnimation(.none) {
            headerAnimationOffset = 0
            searchBarAnimationScale = 1.0
        }
        
        // Clear visible items tracking
        listVisibleItems.removeAll()
        
        // Force garbage collection hint
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // This is just a hint, not a guarantee
            if #available(iOS 15.0, *) {
                // Modern memory pressure handling
                viewModel.optimizeMemoryUsage()
            }
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Add Customer Out of Stock View V2

struct AddCustomerOutOfStockViewV2: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("新增缺货记录")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Text("这是一个占位符界面，将在后续开发中完善")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CustomerOutOfStockListViewV2()
}