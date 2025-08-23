//
//  CustomerOutOfStockListViewV2.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct CustomerOutOfStockListViewV2: View {
    @StateObject private var viewModel: CustomerOutOfStockViewModel
    @StateObject private var animationState = CommonAnimationState()
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var serviceFactory: ServiceFactory
    
    @State private var showingDatePicker = false
    @State private var listVisibleItems: Set<String> = []
    
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
                    dateNavigationSection
                    searchSection
                    statusTabSection
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
            .sheet(isPresented: $showingDatePicker) {
                OutOfStockDatePickerSheet(selectedDate: $viewModel.selectedDate)
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
                initializeView()
            }
            .memoryManaged()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                // Back button with text
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("销售员工作台")
                            .font(.system(size: 17))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Title
                Text("客户缺货管理")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // More menu button
                OutOfStockMoreMenu(
                    isPresented: .constant(false),
                    onExport: {
                        // TODO: Implement export functionality
                        print("Export data")
                    },
                    onRefresh: {
                        Task {
                            await viewModel.refreshData()
                        }
                    },
                    onSettings: {
                        // TODO: Implement settings
                        print("Open settings")
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .offset(y: animationState.headerOffset)
    }
    
    // MARK: - Date Navigation Section
    
    private var dateNavigationSection: some View {
        CommonDateNavigationBar(
            selectedDate: $viewModel.selectedDate,
            showingDatePicker: $showingDatePicker,
            loadedCount: viewModel.items.count,
            totalCount: viewModel.totalCount,
            onPreviousDay: previousDay,
            onNextDay: nextDay
        )
    }
    
    // MARK: - Status Tab Section
    
    private var statusTabSection: some View {
        OutOfStockStatusTabBar(
            selectedStatus: $viewModel.statusFilter,
            statusCounts: viewModel.statusCounts,
            totalCount: viewModel.totalCount
        )
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        OutOfStockSearchBar(
            searchText: $viewModel.searchText,
            placeholder: "搜索客户、产品、备注...",
            onSearch: { text in
                viewModel.performImmediateSearch(text)
            },
            onFilterTap: {
                viewModel.showingFilterSheet = true
            }
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .scaleEffect(animationState.searchBarScale)
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
                .scaleEffect(animationState.filterChipScale)
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
                    onAddNew: { 
                        // TODO: Implement proper add customer out of stock view
                        print("Add new out of stock record from empty state")
                    }
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
                    OutOfStockScreenshotCardView(
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
                    .staggeredListAnimation(index: index, total: viewModel.items.count)
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
    
    // MARK: - Initialization
    
    private func initializeView() {
        // Initialize the real service if it's still a placeholder
        let realService = serviceFactory.customerOutOfStockService
        viewModel.updateService(realService)
        animationState.animateInitialAppearance()
        viewModel.preloadAdjacentData()
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
    
}

#Preview {
    CustomerOutOfStockListViewV2()
}