//
//  GiveBackManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct GiveBackManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomerOutOfStock.requestDate, order: .reverse) private var outOfStockItems: [CustomerOutOfStock]
    @Environment(\.appDependencies) private var appDependencies
    
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>?
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
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 400
            
            VStack(spacing: 0) {
                if isEditing {
                    BatchOperationHeader(
                        selectedCount: selectedItems.count,
                        totalCount: filteredItemsNeedingReturn.count,
                        onCancel: { cancelBatchEdit() },
                        onProcess: { },
                        onSelectAll: { toggleSelectAll() },
                        onSecondaryAction: { showingBatchReturnSheet = true },
                        processButtonText: "",
                        secondaryActionText: "还货",
                        processHint: "处理选中的还货申请"
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                ScrollView {
                    LazyVStack(spacing: isCompact ? 12 : 16) {
                        filterCard
                        statisticsCard
                        returnItemsSection
                    }
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 16)
                }
                .refreshable {
                    // Refresh logic here
                }
            }
        }
        .navigationTitle("return_goods_management".localized)
        .navigationBarTitleDisplayMode(.inline)
        .background(LopanColors.backgroundSecondary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("还货管理界面")
        .accessibilityHint("包含过滤器、统计信息和还货记录列表")
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isEditing)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingExportSheet = true }) {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .disabled(filteredItemsNeedingReturn.isEmpty)
                    
                    Button(action: { startBatchEdit() }) {
                        Label("批量操作", systemImage: "checkmark.circle")
                    }
                    .disabled(filteredItemsNeedingReturn.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("更多选项")
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            updateSearch()
        }
        .onAppear {
            // Debug: Check if we have data
            print("🔍 GiveBackManagementView - Total outOfStockItems: \(outOfStockItems.count)")
            
            // Initialize sample data if empty
            if outOfStockItems.isEmpty {
                print("📝 No out-of-stock items found, initializing sample data...")
                // Sample data initialization moved to app level
            }
            
            // Debug: Print items status
            for item in outOfStockItems {
                print("   - Customer: \(item.customerDisplayName), Product: \(item.product?.name ?? "Unknown"), Status: \(item.status.displayName), NeedsReturn: \(item.needsReturn)")
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
            Text("确定要处理选中的 \(itemsToReturn.count) 个还货记录吗？")
        }
    }
    
    // MARK: - Card-based Layout Components
    
    private var filterCard: some View {
        VStack(spacing: 0) {
            filterToggleHeader
            
            if showingAdvancedFilters {
                VStack(spacing: 12) {
                    filtersGrid
                    dateFilterSection
                }
                .padding(.top, 12)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
            
            ActiveFiltersIndicator(
                selectedReturnStatus: selectedReturnStatus,
                selectedCustomer: selectedCustomer,
                selectedAddress: selectedAddress,
                isFilteringByDate: isFilteringByDate,
                selectedDate: selectedDate,
                onRemoveReturnStatus: { selectedReturnStatus = nil },
                onRemoveCustomer: { selectedCustomer = nil },
                onRemoveAddress: { selectedAddress = nil },
                onRemoveDateFilter: { isFilteringByDate = false },
                onClearAllFilters: { clearAllFilters() }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
    
    private var statisticsCard: some View {
        StatisticsOverviewCard(
            needsReturnCount: outOfStockItems.filter { $0.needsReturn }.count,
            partialReturnCount: outOfStockItems.filter { $0.hasPartialReturn }.count,
            completedReturnCount: outOfStockItems.filter { $0.isFullyReturned }.count,
            lastUpdated: Date()
        )
        .onTapGesture {
            // Debug: Print detailed statistics
            print("📊 Statistics Debug:")
            print("   - Total items: \(outOfStockItems.count)")
            print("   - Needs return: \(outOfStockItems.filter { $0.needsReturn }.count)")
            print("   - Partial returns: \(outOfStockItems.filter { $0.hasPartialReturn }.count)")
            print("   - Fully returned: \(outOfStockItems.filter { $0.isFullyReturned }.count)")
            print("   - Filtered items: \(filteredItemsNeedingReturn.count)")
            print("   - Is editing mode: \(isEditing)")
        }
    }
    
    private var filterToggleHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAdvancedFilters.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showingAdvancedFilters ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.title3)
                        .foregroundColor(LopanColors.info)
                    
                    Text("筛选选项")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if activeFiltersCount > 0 {
                        Text("\(activeFiltersCount) 个筛选")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LopanColors.info.opacity(0.2))
                            .foregroundColor(LopanColors.info)
                            .cornerRadius(12)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showingAdvancedFilters ? "隐藏过滤器" : "显示过滤器")
            .accessibilityHint("点击可切换过滤器的显示状态")
            
            Spacer()
            
        }
    }
    
    
    private var filtersGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            enhancedReturnStatusFilterMenu
            enhancedCustomerFilterMenu
            enhancedAddressFilterMenu
        }
    }
    
    private var enhancedReturnStatusFilterMenu: some View {
        Menu {
            Button(action: { selectReturnStatus(nil) }) {
                Label("全部状态", systemImage: selectedReturnStatus == nil ? "checkmark" : "")
            }
            
            Divider()
            
            ForEach(ReturnStatus.allCases, id: \.self) { status in
                Button(action: { selectReturnStatus(status) }) {
                    Label(
                        status.displayName, 
                        systemImage: selectedReturnStatus == status ? "checkmark" : status.systemImage
                    )
                }
            }
        } label: {
            HStack {
                Text(selectedReturnStatus?.displayName ?? "全部状态")
                    .foregroundColor(.primary)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(LopanColors.backgroundSecondary)
            .cornerRadius(10)
        }
        .accessibilityLabel("选择还货状态")
        .accessibilityValue(selectedReturnStatus?.displayName ?? "全部状态")
    }
    
    private var enhancedCustomerFilterMenu: some View {
        Menu {
            Button("全部客户") {
                selectedCustomer = nil
            }
            
            if !uniqueCustomers.isEmpty {
                Divider()
                ForEach(uniqueCustomers, id: \.id) { customer in
                    Button(action: { selectedCustomer = customer }) {
                        Label(
                            customer.name,
                            systemImage: selectedCustomer?.id == customer.id ? "checkmark" : "person"
                        )
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedCustomer?.name ?? "全部客户")
                    .foregroundColor(.primary)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(LopanColors.backgroundSecondary)
            .cornerRadius(10)
        }
        .accessibilityLabel("选择客户")
        .accessibilityValue(selectedCustomer?.name ?? "全部客户")
    }
    
    private var enhancedAddressFilterMenu: some View {
        Menu {
            Button("全部地址") {
                selectedAddress = nil
            }
            
            if !uniqueAddresses.isEmpty {
                Divider()
                ForEach(uniqueAddresses, id: \.self) { address in
                    Button(action: { selectedAddress = address }) {
                        Label(
                            address,
                            systemImage: selectedAddress == address ? "checkmark" : "location"
                        )
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedAddress ?? "全部地址")
                    .foregroundColor(.primary)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(LopanColors.backgroundSecondary)
            .cornerRadius(10)
        }
        .accessibilityLabel("选择地址")
        .accessibilityValue(selectedAddress ?? "全部地址")
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
            .background(LopanColors.backgroundSecondary)
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
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(8)
            }
        }
    }
    
    
    
    
    private var returnItemsSection: some View {
        VStack(spacing: 0) {
            if filteredItemsNeedingReturn.isEmpty {
                EmptyReturnStateView(
                    isEditing: isEditing,
                    totalItemsCount: outOfStockItems.count,
                    onInitializeSampleData: outOfStockItems.isEmpty ? {
                        // Sample data initialization moved to app level
                    } : nil
                )
            } else {
                ReturnItemsList(
                    items: filteredItemsNeedingReturn,
                    isEditing: isEditing,
                    selectedItems: selectedItems,
                    onItemSelection: { item in
                        LopanHapticEngine.shared.light()
                        toggleItemSelection(item)
                    },
                    onItemTap: { item in
                        // Navigate to detail view
                        // This would need to be implemented with NavigationPath or similar
                    }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
    
    
    // MARK: - Computed Properties
    
    var filteredItemsNeedingReturn: [CustomerOutOfStock] {
        var filtered = outOfStockItems
        
        // 首先过滤掉已退货的记录（客户已退货，不需要还货）
        filtered = filtered.filter { $0.status != .returned }
        
        // 过滤掉已完成的记录（已经全部还货完成）
        filtered = filtered.filter { $0.status != .completed }
        
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
    
    private var activeFiltersCount: Int {
        var count = 0
        if selectedReturnStatus != nil { count += 1 }
        if selectedCustomer != nil { count += 1 }
        if selectedAddress != nil { count += 1 }
        if isFilteringByDate { count += 1 }
        return count
    }
    
    private func selectReturnStatus(_ status: ReturnStatus?) {
        LopanHapticEngine.shared.light()
        selectedReturnStatus = status
    }
    
    private func clearAllFilters() {
        LopanHapticEngine.shared.medium()
        selectedReturnStatus = nil
        selectedCustomer = nil
        selectedAddress = nil
        isFilteringByDate = false
    }
    
    private func updateSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            await MainActor.run {
                debouncedSearchText = searchText
            }
        }
    }
    
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
            Task {
                await appDependencies.serviceFactory.auditingService.logReturnProcessing(
                    item: item,
                    returnQuantity: quantity,
                    returnNotes: notes,
                    operatorUserId: "demo_user", // TODO: Get from authentication service
                    operatorUserName: "演示用户" // TODO: Get from authentication service
                )
            }
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
    
    var systemImage: String {
        switch self {
        case .needsReturn:
            return "exclamationmark.triangle.fill"
        case .partialReturn:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
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
                        .foregroundColor(isSelected ? LopanColors.primary : LopanColors.secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.customerDisplayName)
                        .font(.headline)
                        // Removed Dynamic Type constraint for full accessibility support
                    
                    Spacer()
                    
                    Text(returnStatusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(returnStatusColor.opacity(0.2))
                        .foregroundColor(returnStatusColor)
                        .cornerRadius(4)
                        .accessibilityLabel("还货状态：\(returnStatusText)")
                }
                
                Text(item.productDisplayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("原始数量: \(item.quantity)")
                            .font(.caption)
                       Text("已还数量: \(item.returnQuantity)")
                           .font(.caption)
                            .foregroundColor(LopanColors.info)
                        Text("剩余数量: \(item.remainingQuantity)")
                            .font(.caption)
                            .foregroundColor(item.remainingQuantity > 0 ? LopanColors.warning : LopanColors.success)
                    }
                    
                    Spacer()
                    
                    if let returnDate = item.returnDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("还货日期:")
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
        .background(isSelected ? LopanColors.info.opacity(0.1) : LopanColors.clear)
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
            return LopanColors.success
        } else if item.hasPartialReturn {
            return LopanColors.primary
        } else if item.needsReturn {
            return LopanColors.warning
        } else {
            return LopanColors.textSecondary
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
    GiveBackManagementView()
        .modelContainer(for: CustomerOutOfStock.self, inMemory: true)
}
