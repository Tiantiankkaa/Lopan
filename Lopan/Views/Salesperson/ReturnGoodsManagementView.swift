//
//  ReturnGoodsManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct ReturnGoodsManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomerOutOfStock.requestDate, order: .reverse) private var outOfStockItems: [CustomerOutOfStock]
    
    @State private var searchText = ""
    @State private var selectedReturnStatus: ReturnStatus? = nil
    @State private var selectedCustomer: Customer? = nil
    @State private var selectedAddress: String? = nil
    @State private var selectedDate: Date = Date()
    @State private var isFilteringByDate = true
    @State private var showingAdvancedFilters = false
    
    // Batch operation states
    @State private var isEditing = false
    @State private var selectedItems: Set<String> = []
    @State private var showingBatchReturnSheet = false
    @State private var showingExportSheet = false
    
    // Return processing states
    @State private var showingReturnConfirmation = false
    @State private var itemsToReturn: [CustomerOutOfStock] = []
    @State private var returnQuantities: [String: Int] = [:]
    @State private var returnNotes: String = ""
    
    var body: some View {
        VStack {
            mainContentView
        }
        .navigationTitle("return_goods_management".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Debug: Check if we have data
            print("🔍 ReturnGoodsManagementView - Total outOfStockItems: \(outOfStockItems.count)")
            
            // Initialize sample data if empty
            if outOfStockItems.isEmpty {
                print("📝 No out-of-stock items found, initializing sample data...")
                DataInitializationService.initializeSampleData(modelContext: modelContext)
            }
            
            // Debug: Print items status
            for item in outOfStockItems {
                print("   - Customer: \(item.customer?.name ?? "Unknown"), Product: \(item.product?.name ?? "Unknown"), Status: \(item.status.displayName), NeedsReturn: \(item.needsReturn)")
            }
        }
        .sheet(isPresented: $showingBatchReturnSheet) {
            BatchReturnProcessingSheet(
                items: filteredItemsNeedingReturn.filter { selectedItems.contains($0.id) },
                onComplete: { processedItems in
                    processReturnBatch(processedItems)
                }
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            ReturnOrderExportView(items: filteredItemsNeedingReturn)
        }
        .alert("return_confirmation".localized, isPresented: $showingReturnConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("confirm".localized) {
                confirmReturnProcessing()
            }
        } message: {
            Text("确定要处理选中的 \(itemsToReturn.count) 个退货记录吗？".localized(with: itemsToReturn.count))
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if isEditing {
                batchOperationToolbar
            }
            filterSection
            statisticsSection
            itemsListSection
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            if !isEditing {
                filterToggleButton
                if showingAdvancedFilters {
                    filtersView
                }
            }
            batchSelectionStatus
        }
        .padding()
    }
    
    private var filterToggleButton: some View {
        HStack {
            Button(action: {
                withAnimation {
                    showingAdvancedFilters.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showingAdvancedFilters ? "chevron.up" : "chevron.down")
                    Text("filter_by_return_status".localized)
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { showingExportSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("export_return_orders".localized)
                    }
                    .foregroundColor(.green)
                }
                
                Button(action: { startBatchEdit() }) {
                    Text("batch_return".localized)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var filtersView: some View {
        VStack(spacing: 8) {
            returnStatusFilterButton
            customerFilterButton
            addressFilterButton
            dateFilterSection
        }
    }
    
    private var returnStatusFilterButton: some View {
        Menu {
            Button("all_return_status".localized) {
                selectedReturnStatus = nil
            }
            Button("pending_return".localized) {
                selectedReturnStatus = .needsReturn
            }
            Button("partial_return".localized) {
                selectedReturnStatus = .partialReturn
            }
            Button("completed_return".localized) {
                selectedReturnStatus = .completed
            }
        } label: {
            HStack {
                Text(selectedReturnStatus?.displayName ?? "all_return_status".localized)
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    private var customerFilterButton: some View {
        Menu {
            Button("全部客户") {
                selectedCustomer = nil
            }
            ForEach(uniqueCustomers, id: \.id) { customer in
                Button(customer.name) {
                    selectedCustomer = customer
                }
            }
        } label: {
            HStack {
                Text(selectedCustomer?.name ?? "全部客户")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    private var addressFilterButton: some View {
        Menu {
            Button("全部地址") {
                selectedAddress = nil
            }
            ForEach(uniqueAddresses, id: \.self) { address in
                Button(address) {
                    selectedAddress = address
                }
            }
        } label: {
            HStack {
                Text(selectedAddress ?? "全部地址")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("按日期筛选", isOn: $isFilteringByDate)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if isFilteringByDate {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var batchOperationToolbar: some View {
        HStack(spacing: 0) {
            Button(action: { showingBatchReturnSheet = true }) {
                Text("process_selected_returns".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(selectedItems.isEmpty)
            
            Divider()
                .frame(height: 20)
            
            Button(action: { toggleSelectAll() }) {
                Text(selectedItems.count == filteredItemsNeedingReturn.count ? "取消全选" : "全选")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            
            Divider()
                .frame(height: 20)
            
            Button(action: { cancelBatchEdit() }) {
                Text("cancel".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .background(Color.gray.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    private var batchSelectionStatus: some View {
        Group {
            if isEditing {
                HStack {
                    Text("已选择 \(selectedItems.count) 个记录".localized(with: selectedItems.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    private var statisticsSection: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "customers_needing_returns".localized,
                count: outOfStockItems.filter { $0.needsReturn }.count,
                color: .orange
            )
            
            StatCard(
                title: "partially_returned".localized,
                count: outOfStockItems.filter { $0.hasPartialReturn }.count,
                color: .blue
            )
            
            StatCard(
                title: "fully_returned".localized,
                count: outOfStockItems.filter { $0.isFullyReturned }.count,
                color: .green
            )
        }
        .padding(.horizontal)
        .onTapGesture {
            // Debug: Print detailed statistics
            print("📊 Statistics Debug:")
            print("   - Total items: \(outOfStockItems.count)")
            print("   - Needs return: \(outOfStockItems.filter { $0.needsReturn }.count)")
            print("   - Partial returns: \(outOfStockItems.filter { $0.hasPartialReturn }.count)")
            print("   - Fully returned: \(outOfStockItems.filter { $0.isFullyReturned }.count)")
            print("   - Filtered items: \(filteredItemsNeedingReturn.count)")
            print("   - Is editing mode: \(isEditing)")
            if isEditing {
                print("   - Items hidden in batch mode: \(outOfStockItems.filter { $0.isFullyReturned }.count)")
            }
        }
    }
    
    private var itemsListSection: some View {
        Group {
            if filteredItemsNeedingReturn.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredItemsNeedingReturn) { item in
                        if isEditing {
                            ReturnGoodsRowView(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                isEditing: isEditing,
                                onSelect: { toggleItemSelection(item) }
                            )
                        } else {
                            NavigationLink(destination: ReturnGoodsDetailView(item: item)) {
                                ReturnGoodsRowView(
                                    item: item,
                                    isSelected: false,
                                    isEditing: false,
                                    onSelect: {}
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.uturn.left.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(isEditing ? "暂无可批量处理的还货记录" : "暂无还货记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("总记录数: \(outOfStockItems.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if outOfStockItems.isEmpty {
                Button("初始化示例数据") {
                    DataInitializationService.initializeSampleData(modelContext: modelContext)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Computed Properties
    
    var filteredItemsNeedingReturn: [CustomerOutOfStock] {
        var filtered = outOfStockItems
        
        // Filter by return status
        switch selectedReturnStatus {
        case .needsReturn:
            filtered = filtered.filter { $0.needsReturn }
        case .partialReturn:
            filtered = filtered.filter { $0.hasPartialReturn }
        case .completed:
            filtered = filtered.filter { $0.isFullyReturned }
        case .none:
            // Show all items normally, but exclude fully returned items only in batch edit mode
            if isEditing {
                filtered = filtered.filter { $0.remainingQuantity > 0 || $0.hasPartialReturn }
            }
            // In normal mode, show all items including fully returned
        }
        
        // Apply other filters
        if let customer = selectedCustomer {
            filtered = filtered.filter { $0.customer?.id == customer.id }
        }
        
        if let address = selectedAddress {
            filtered = filtered.filter { $0.customer?.address == address }
        }
        
        if isFilteringByDate {
            let calendar = Calendar.current
            filtered = filtered.filter { item in
                calendar.isDate(item.requestDate, inSameDayAs: selectedDate)
            }
        }
        
        return filtered.sorted { $0.requestDate > $1.requestDate }
    }
    
    var uniqueCustomers: [Customer] {
        let customers = outOfStockItems.compactMap { $0.customer }
        return Array(Set(customers.map { $0.id })).compactMap { id in
            customers.first { $0.id == id }
        }.sorted { $0.name < $1.name }
    }
    
    var uniqueAddresses: [String] {
        let addresses = outOfStockItems.compactMap { $0.customer?.address }
        return Array(Set(addresses)).sorted()
    }
    
    // MARK: - Helper Functions
    
    private func toggleItemSelection(_ item: CustomerOutOfStock) {
        if isEditing {
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        }
    }
    
    private func toggleSelectAll() {
        if selectedItems.count == filteredItemsNeedingReturn.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(filteredItemsNeedingReturn.map { $0.id })
        }
    }
    
    private func startBatchEdit() {
        withAnimation {
            isEditing = true
        }
    }
    
    private func cancelBatchEdit() {
        withAnimation {
            isEditing = false
            selectedItems.removeAll()
        }
    }
    
    private func processReturnBatch(_ processedItems: [(CustomerOutOfStock, Int, String?)]) {
        for (item, quantity, notes) in processedItems {
            _ = item.processReturn(quantity: quantity, notes: notes)
            
            // Log each return processing
            AuditingService.shared.logReturnProcessing(
                item: item,
                returnQuantity: quantity,
                returnNotes: notes,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                modelContext: modelContext
            )
        }
        
        do {
            try modelContext.save()
            selectedItems.removeAll()
            isEditing = false
        } catch {
            print("Error processing return batch: \(error)")
        }
    }
    
    private func confirmReturnProcessing() {
        // Process the return items
        do {
            try modelContext.save()
        } catch {
            print("Error confirming return processing: \(error)")
        }
    }
}

// MARK: - Supporting Enums and Views

enum ReturnStatus: CaseIterable {
    case needsReturn
    case partialReturn
    case completed
    
    var displayName: String {
        switch self {
        case .needsReturn:
            return "pending_return".localized
        case .partialReturn:
            return "partial_return".localized
        case .completed:
            return "completed_return".localized
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ReturnGoodsRowView: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            if isEditing {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.customer?.name ?? "未知客户")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(returnStatusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(returnStatusColor.opacity(0.2))
                        .foregroundColor(returnStatusColor)
                        .cornerRadius(4)
                }
                
                Text(item.productDisplayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("原始数量: \(item.quantity)")
                            .font(.caption)
                        Text("已退数量: \(item.returnQuantity)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("剩余数量: \(item.remainingQuantity)")
                            .font(.caption)
                            .foregroundColor(item.remainingQuantity > 0 ? .orange : .green)
                    }
                    
                    Spacer()
                    
                    if let returnDate = item.returnDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("退货日期:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(returnDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var returnStatusText: String {
        if item.isFullyReturned {
            return "fully_returned".localized
        } else if item.hasPartialReturn {
            return "partially_returned".localized
        } else if item.needsReturn {
            return "needs_return".localized
        } else {
            return item.status.displayName
        }
    }
    
    private var returnStatusColor: Color {
        if item.isFullyReturned {
            return .green
        } else if item.hasPartialReturn {
            return .blue
        } else if item.needsReturn {
            return .orange
        } else {
            return .gray
        }
    }
}

enum DateRange: CaseIterable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    
    var displayName: String {
        switch self {
        case .today:
            return "今天"
        case .yesterday:
            return "昨天"
        case .thisWeek:
            return "本周"
        case .lastWeek:
            return "上周"
        case .thisMonth:
            return "本月"
        case .lastMonth:
            return "上月"
        }
    }
    
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return calendar.isDate(date, inSameDayAs: yesterday)
        case .thisWeek:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            return calendar.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            return calendar.isDate(date, equalTo: lastMonth, toGranularity: .month)
        }
    }
}

#Preview {
    ReturnGoodsManagementView()
        .modelContainer(for: CustomerOutOfStock.self, inMemory: true)
}