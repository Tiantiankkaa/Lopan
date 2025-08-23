//
//  OutOfStockFilterSheet.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI
import SwiftData

struct OutOfStockFilterSheet: View {
    @ObservedObject var viewModel: CustomerOutOfStockViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var customers: [Customer]
    @Query private var products: [Product]
    
    @State private var tempCustomer: Customer?
    @State private var tempProduct: Product?
    @State private var tempProductSize: ProductSize?
    @State private var tempAddress: String?
    @State private var tempStatusFilter: CustomerOutOfStockNavigationState.StatusFilter = .all
    @State private var tempSortOrder: CustomerOutOfStockNavigationState.SortOrder = .newestFirst
    @State private var tempDateFilterMode: DateFilterOption?
    @State private var tempCustomDateRange: (start: Date, end: Date)?
    
    @State private var showingCustomerPicker = false
    @State private var showingProductPicker = false
    @State private var showingAddressPicker = false
    @State private var showingDateRangePicker = false
    
    @State private var sheetOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        handleBar
                        headerSection
                        filterSections
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .offset(y: sheetOffset)
            .gesture(
                DragGesture()
                    .onChanged(handleDragChanged)
                    .onEnded(handleDragEnded)
            )
            .navigationBarHidden(true)
            .onAppear {
                loadCurrentFilters()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingCustomerPicker) {
            CustomerFilterPickerSheet(
                customers: customers,
                selectedCustomer: $tempCustomer
            )
        }
        .sheet(isPresented: $showingProductPicker) {
            ProductFilterPickerSheet(
                products: products,
                selectedProduct: $tempProduct,
                selectedProductSize: $tempProductSize
            )
        }
        .sheet(isPresented: $showingAddressPicker) {
            AddressFilterPickerSheet(
                customers: customers,
                selectedAddress: $tempAddress
            )
        }
        .sheet(isPresented: $showingDateRangePicker) {
            DateRangePickerSheet(
                dateFilterMode: $tempDateFilterMode,
                customDateRange: $tempCustomDateRange
            )
        }
    }
    
    // MARK: - Handle Bar
    
    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.systemGray3))
            .frame(width: 40, height: 6)
            .padding(.top, 8)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("高级筛选")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: clearAllFilters) {
                    Text("清空")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            if hasActiveFilters {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("已应用 \(activeFiltersCount) 个筛选条件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Filter Sections
    
    private var filterSections: some View {
        VStack(spacing: 20) {
            customerSection
            productSection
            statusSection
            sortSection
            dateSection
        }
    }
    
    // MARK: - Customer Section
    
    private var customerSection: some View {
        FilterSectionCard(title: "客户筛选", icon: "person.circle") {
            VStack(spacing: 12) {
                FilterOptionRow(
                    title: "选择客户",
                    value: tempCustomer?.name ?? "全部客户",
                    isSelected: tempCustomer != nil,
                    action: { showingCustomerPicker = true }
                )
                
                FilterOptionRow(
                    title: "选择地址",
                    value: tempAddress ?? "全部地址",
                    isSelected: tempAddress != nil,
                    action: { showingAddressPicker = true }
                )
            }
        }
    }
    
    // MARK: - Product Section
    
    private var productSection: some View {
        FilterSectionCard(title: "产品筛选", icon: "cube.box") {
            VStack(spacing: 12) {
                FilterOptionRow(
                    title: "选择产品",
                    value: tempProduct?.name ?? "全部产品",
                    isSelected: tempProduct != nil,
                    action: { showingProductPicker = true }
                )
                
                if let product = tempProduct, let sizes = product.sizes, !sizes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("产品尺寸")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sizes) { size in
                                    SizeChip(
                                        size: size,
                                        isSelected: tempProductSize?.id == size.id,
                                        onTap: {
                                            if tempProductSize?.id == size.id {
                                                tempProductSize = nil
                                            } else {
                                                tempProductSize = size
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        FilterSectionCard(title: "状态筛选", icon: "circle.fill") {
            VStack(spacing: 8) {
                ForEach(CustomerOutOfStockNavigationState.StatusFilter.allCases, id: \.self) { status in
                    StatusFilterRow(
                        status: status,
                        isSelected: tempStatusFilter == status,
                        onTap: { tempStatusFilter = status }
                    )
                }
            }
        }
    }
    
    // MARK: - Sort Section
    
    private var sortSection: some View {
        FilterSectionCard(title: "排序方式", icon: "arrow.up.arrow.down.circle") {
            VStack(spacing: 8) {
                ForEach(CustomerOutOfStockNavigationState.SortOrder.allCases, id: \.self) { order in
                    SortOrderRow(
                        order: order,
                        isSelected: tempSortOrder == order,
                        onTap: { tempSortOrder = order }
                    )
                }
            }
        }
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        FilterSectionCard(title: "日期筛选", icon: "calendar.circle") {
            VStack(spacing: 12) {
                FilterOptionRow(
                    title: "日期范围",
                    value: dateFilterDisplayText,
                    isSelected: tempDateFilterMode != nil,
                    action: { showingDateRangePicker = true }
                )
                
                if let dateRange = tempCustomDateRange {
                    HStack {
                        Text("从: \(dateRange.start, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("到: \(dateRange.end, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: applyFilters) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("应用筛选")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            Button(action: { dismiss() }) {
                Text("取消")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentFilters() {
        tempCustomer = viewModel.selectedCustomer
        tempProduct = viewModel.selectedProduct
        tempProductSize = viewModel.selectedProductSize
        tempAddress = viewModel.selectedAddress
        tempStatusFilter = viewModel.statusFilter
        tempSortOrder = viewModel.sortOrder
        tempDateFilterMode = viewModel.dateFilterMode
        tempCustomDateRange = viewModel.customDateRange
    }
    
    private func applyFilters() {
        hapticFeedback.impactOccurred()
        
        viewModel.selectedCustomer = tempCustomer
        viewModel.selectedProduct = tempProduct
        viewModel.selectedProductSize = tempProductSize
        viewModel.selectedAddress = tempAddress
        viewModel.statusFilter = tempStatusFilter
        viewModel.sortOrder = tempSortOrder
        viewModel.dateFilterMode = tempDateFilterMode
        viewModel.customDateRange = tempCustomDateRange
        
        if let dateFilterMode = tempDateFilterMode {
            viewModel.applyDateFilter(dateFilterMode)
        }
        
        Task {
            await viewModel.refreshData()
        }
        
        dismiss()
    }
    
    private func clearAllFilters() {
        hapticFeedback.impactOccurred()
        
        tempCustomer = nil
        tempProduct = nil
        tempProductSize = nil
        tempAddress = nil
        tempStatusFilter = .all
        tempSortOrder = .newestFirst
        tempDateFilterMode = nil
        tempCustomDateRange = nil
    }
    
    private var hasActiveFilters: Bool {
        tempCustomer != nil ||
        tempProduct != nil ||
        tempProductSize != nil ||
        tempAddress != nil ||
        tempStatusFilter != .all ||
        tempDateFilterMode != nil
    }
    
    private var activeFiltersCount: Int {
        var count = 0
        if tempCustomer != nil { count += 1 }
        if tempProduct != nil { count += 1 }
        if tempProductSize != nil { count += 1 }
        if tempAddress != nil { count += 1 }
        if tempStatusFilter != .all { count += 1 }
        if tempDateFilterMode != nil { count += 1 }
        return count
    }
    
    private var dateFilterDisplayText: String {
        if let mode = tempDateFilterMode {
            switch mode {
            case .thisWeek:
                return "本周"
            case .thisMonth:
                return "本月"
            case .custom:
                return "自定义范围"
            }
        } else {
            return "不限日期"
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if value.translation.height > 0 {
            sheetOffset = value.translation.height * 0.3
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if value.translation.height > 150 {
                dismiss()
            } else {
                sheetOffset = 0
            }
        }
    }
}

// MARK: - Filter Section Card

struct FilterSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Filter Option Row

struct FilterOptionRow: View {
    let title: String
    let value: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Size Chip

struct SizeChip: View {
    let size: ProductSize
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(size.size)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Status Filter Row

struct StatusFilterRow: View {
    let status: CustomerOutOfStockNavigationState.StatusFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: status.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 20)
                
                Text(status.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sort Order Row

struct SortOrderRow: View {
    let order: CustomerOutOfStockNavigationState.SortOrder
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: order.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 20)
                
                Text(order.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Picker Sheets

struct CustomerFilterPickerSheet: View {
    let customers: [Customer]
    @Binding var selectedCustomer: Customer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("全部客户") {
                    selectedCustomer = nil
                    dismiss()
                }
                .foregroundColor(.primary)
                
                ForEach(customers.prefix(10)) { customer in
                    Button(customer.name) {
                        selectedCustomer = customer
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct ProductFilterPickerSheet: View {
    let products: [Product]
    @Binding var selectedProduct: Product?
    @Binding var selectedProductSize: ProductSize?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("全部产品") {
                    selectedProduct = nil
                    selectedProductSize = nil
                    dismiss()
                }
                .foregroundColor(.primary)
                
                ForEach(products.prefix(10)) { product in
                    Button(product.name) {
                        selectedProduct = product
                        selectedProductSize = nil
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct AddressFilterPickerSheet: View {
    let customers: [Customer]
    @Binding var selectedAddress: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("全部地址") {
                    selectedAddress = nil
                    dismiss()
                }
                .foregroundColor(.primary)
                
                ForEach(Array(Set(customers.map { $0.address })).prefix(10), id: \.self) { address in
                    Button(address) {
                        selectedAddress = address
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择地址")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct DateRangePickerSheet: View {
    @Binding var dateFilterMode: DateFilterOption?
    @Binding var customDateRange: (start: Date, end: Date)?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("快速选择") {
                    Button("本周") {
                        dateFilterMode = .thisWeek
                        dismiss()
                    }
                    
                    Button("本月") {
                        dateFilterMode = .thisMonth
                        dismiss()
                    }
                    
                    Button("清除日期筛选") {
                        dateFilterMode = nil
                        customDateRange = nil
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("选择日期范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    OutOfStockFilterSheet(viewModel: CustomerOutOfStockViewModel(service: .placeholder()))
}