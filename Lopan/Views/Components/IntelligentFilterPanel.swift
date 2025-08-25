//
//  IntelligentFilterPanel.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//  AI-powered intelligent filter system
//

import SwiftUI

// MARK: - Filter Panel State

@MainActor
class IntelligentFilterState: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCustomer: Customer?
    @Published var selectedProduct: Product?
    @Published var selectedStatus: OutOfStockStatus?
    @Published var selectedDateRange: DateRangeOption?
    @Published var customStartDate = Date()
    @Published var customEndDate = Date()
    
    // Preview
    @Published var previewCount = 0
    @Published var previewLoading = false
    
    var hasActiveFilters: Bool {
        selectedCustomer != nil || 
        selectedProduct != nil || 
        selectedStatus != nil || 
        selectedDateRange != nil ||
        !searchText.isEmpty
    }
    
    var activeFilterCount: Int {
        var count = 0
        if selectedCustomer != nil { count += 1 }
        if selectedProduct != nil { count += 1 }
        if selectedStatus != nil { count += 1 }
        if selectedDateRange != nil { count += 1 }
        if !searchText.isEmpty { count += 1 }
        return count
    }
}

// MARK: - Supporting Models

enum DateRangeOption: CaseIterable {
    case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, custom
    
    var title: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .custom: return "自定义"
        }
    }
    
    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return (calendar.startOfDay(for: now), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return (calendar.startOfDay(for: yesterday), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            let startOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        case .custom:
            return (now, now) // Will be overridden by custom dates
        }
    }
}

// MARK: - Main Filter Panel

struct IntelligentFilterPanel: View {
    @StateObject private var filterState = IntelligentFilterState()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var serviceFactory: ServiceFactory
    
    @Binding var filters: OutOfStockFilters
    @Binding var searchText: String
    let customers: [Customer]
    let products: [Product]
    let onApply: () -> Void
    
    @State private var showingCustomDatePicker = false
    @State private var showingCustomerPicker = false
    @State private var showingProductPicker = false
    @State private var customerSearchText = ""
    @State private var productSearchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    detailedFiltersSection
                    previewSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                initializeFilterState()
            }
            .sheet(isPresented: $showingCustomerPicker) {
                SearchableCustomerPicker(
                    customers: customers,
                    selectedCustomer: $filterState.selectedCustomer,
                    searchText: $customerSearchText
                )
            }
            .onChange(of: filterState.selectedCustomer) { _, _ in
                updatePreview()
            }
            .sheet(isPresented: $showingProductPicker) {
                SearchableProductPicker(
                    products: products,
                    selectedProduct: $filterState.selectedProduct,
                    selectedProductSize: .constant(nil),
                    searchText: $productSearchText
                )
            }
            .onChange(of: filterState.selectedProduct) { _, _ in
                updatePreview()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("筛选")
                    .font(.title)
                    .fontWeight(.bold)
                
                if filterState.hasActiveFilters {
                    Text("\(filterState.activeFilterCount) 个活跃筛选")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .foregroundColor(.blue)
        }
        .padding(.bottom, 8)
    }
    
    
    
    // MARK: - Detailed Filters Section
    
    private var detailedFiltersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("精细筛选")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Date Range Filter
                FilterSection(title: "日期筛选", icon: "calendar.circle.fill") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(DateRangeOption.allCases, id: \.self) { option in
                            DateRangeButton(
                                option: option,
                                isSelected: filterState.selectedDateRange == option
                            ) {
                                filterState.selectedDateRange = filterState.selectedDateRange == option ? nil : option
                                updatePreview()
                            }
                        }
                    }
                }
                
                if filterState.selectedDateRange == .custom {
                    CustomDateRangePicker(
                        startDate: $filterState.customStartDate,
                        endDate: $filterState.customEndDate,
                        onChange: updatePreview
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                Divider()
                
                // Customer Filter (placeholder)
                FilterSection(title: "客户筛选", icon: "person.circle.fill") {
                    Button(action: selectCustomer) {
                        HStack {
                            Text(filterState.selectedCustomer?.name ?? "选择客户")
                                .foregroundColor(filterState.selectedCustomer != nil ? .primary : .secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Product Filter (placeholder)
                FilterSection(title: "产品筛选", icon: "cube.fill") {
                    Button(action: selectProduct) {
                        HStack {
                            Text(filterState.selectedProduct?.name ?? "选择产品")
                                .foregroundColor(filterState.selectedProduct != nil ? .primary : .secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("筛选预览")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if filterState.previewLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(filterState.previewCount) 条记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                }
            }
            
            HStack(spacing: 12) {
                Button("清除全部") {
                    clearAllFilters()
                }
                .buttonStyle(.bordered)
                .disabled(!filterState.hasActiveFilters)
                
                Button("应用筛选 (\(filterState.previewCount))") {
                    applyFilters()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filterState.previewCount == 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Methods
    
    private func initializeFilterState() {
        // Initialize filter state from current filters binding
        filterState.searchText = searchText
        filterState.selectedCustomer = filters.customer
        filterState.selectedProduct = filters.product
        filterState.selectedStatus = filters.status
        
        // Initialize date range from current filters
        if let dateRange = filters.dateRange {
            switch dateRange {
            case .today:
                filterState.selectedDateRange = .today
            case .thisWeek:
                filterState.selectedDateRange = .thisWeek
            case .thisMonth:
                filterState.selectedDateRange = .thisMonth
            case .custom(let start, let end):
                filterState.selectedDateRange = .custom
                filterState.customStartDate = start
                filterState.customEndDate = end
            }
        }
        
        // Update preview with current filters
        updatePreview()
    }
    
    private func updatePreview() {
        filterState.previewLoading = true
        
        Task {
            await updatePreviewAsync()
        }
    }
    
    private func updatePreviewAsync() async {
        await MainActor.run {
            filterState.previewLoading = true
        }
        
        // Check if this is a "clear all" scenario for optimized handling
        let isClearAll = filterState.selectedCustomer == nil && 
                        filterState.selectedProduct == nil && 
                        filterState.selectedStatus == nil && 
                        filterState.selectedDateRange == nil && 
                        filterState.searchText.isEmpty
        
        let count: Int
        if isClearAll {
            // Use optimized clear all method with special caching
            count = await serviceFactory.customerOutOfStockService.getClearAllFilteredCount()
        } else {
            // Create criteria based on current filter state
            let dateRange: (start: Date, end: Date)?
            if let selectedDateRange = filterState.selectedDateRange {
                switch selectedDateRange {
                case .custom:
                    dateRange = (start: filterState.customStartDate, end: filterState.customEndDate)
                default:
                    dateRange = selectedDateRange.dateRange
                }
            } else {
                dateRange = nil
            }
            
            let criteria = OutOfStockFilterCriteria(
                customer: filterState.selectedCustomer,
                product: filterState.selectedProduct,
                status: filterState.selectedStatus,
                dateRange: dateRange,
                searchText: filterState.searchText,
                page: 0,
                pageSize: 1
            )
            
            count = await serviceFactory.customerOutOfStockService.getFilteredCount(criteria: criteria)
        }
        
        await MainActor.run {
            filterState.previewCount = count
            filterState.previewLoading = false
        }
    }
    
    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            filterState.searchText = ""
            filterState.selectedCustomer = nil
            filterState.selectedProduct = nil
            filterState.selectedStatus = nil
            filterState.selectedDateRange = nil
            filterState.previewCount = 0
        }
        
        // Debounce the preview update to avoid blocking UI
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            await updatePreviewAsync()
        }
    }
    
    private func applyFilters() {
        // Apply filters to the parent view
        searchText = filterState.searchText
        
        // Convert filter state to parent filter model
        filters.customer = filterState.selectedCustomer
        filters.product = filterState.selectedProduct
        filters.status = filterState.selectedStatus
        
        // Convert date range if selected
        if let dateRange = filterState.selectedDateRange {
            switch dateRange {
            case .today:
                filters.dateRange = .today
            case .yesterday:
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                let startOfDay = Calendar.current.startOfDay(for: yesterday)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
                filters.dateRange = .custom(start: startOfDay, end: endOfDay)
            case .thisWeek:
                filters.dateRange = .thisWeek
            case .lastWeek:
                let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
                let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: lastWeek)
                let startOfWeek = weekInterval?.start ?? Date()
                let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek) ?? startOfWeek
                filters.dateRange = .custom(start: startOfWeek, end: endOfWeek)
            case .thisMonth:
                filters.dateRange = .thisMonth
            case .lastMonth:
                let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let monthInterval = Calendar.current.dateInterval(of: .month, for: lastMonth)
                let startOfMonth = monthInterval?.start ?? Date()
                let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? startOfMonth
                filters.dateRange = .custom(start: startOfMonth, end: endOfMonth)
            case .custom:
                filters.dateRange = .custom(start: filterState.customStartDate, end: filterState.customEndDate)
            }
        } else {
            filters.dateRange = nil
        }
        
        dismiss()
        onApply()
    }
    
    private func selectCustomer() {
        showingCustomerPicker = true
    }
    
    private func selectProduct() {
        showingProductPicker = true
    }
}

// MARK: - Supporting Views


private struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            content
        }
    }
}

private struct StatusFilterButton: View {
    let status: OutOfStockStatus
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(status.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? statusColor(status) : Color(.systemGray6))
                )
        }
    }
    
    private func statusColor(_ status: OutOfStockStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

private struct DateRangeButton: View {
    let option: DateRangeOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(option.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
    }
}

private struct CustomDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onChange: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开始日期")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: startDate) { onChange() }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("结束日期")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: endDate) { onChange() }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
}


#Preview {
    @Previewable @State var filters = OutOfStockFilters()
    @Previewable @State var searchText = ""
    
    return IntelligentFilterPanel(
        filters: $filters,
        searchText: $searchText,
        customers: [],
        products: [],
        onApply: {}
    )
}