//
//  CustomerGroupedReturnView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import SwiftData

struct CustomerReturnGroup: Identifiable, Hashable {
    var id: String { customer.id }
    let customer: Customer
    let items: [CustomerOutOfStock]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(customer.id)
    }
    
    static func == (lhs: CustomerReturnGroup, rhs: CustomerReturnGroup) -> Bool {
        lhs.customer.id == rhs.customer.id
    }
    var totalQuantity: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    var returnableQuantity: Int {
        items.reduce(0) { $0 + $1.remainingQuantity }
    }
    var returnedQuantity: Int {
        items.reduce(0) { $0 + $1.deliveryQuantity }
    }
}

struct CustomerGroupedReturnView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    
    private var salespersonService: SalespersonServiceProvider {
        appDependencies.serviceFactory.salespersonServiceProvider
    }
    
    @State private var customerGroups: [CustomerReturnGroup] = []
    @State private var selectedCustomerGroups: Set<String> = []
    @State private var showingBatchProcessing = false
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedGroupForDetail: CustomerReturnGroup?
    @State private var isSelectionMode = false
    
    var filteredGroups: [CustomerReturnGroup] {
        guard !searchText.isEmpty else { return customerGroups }
        
        return customerGroups.filter { group in
            group.customer.name.localizedCaseInsensitiveContains(searchText) ||
            group.customer.address.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 400
            
            VStack(spacing: 0) {
                if isSelectionMode {
                    batchSelectionHeader
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                
                ScrollView {
                    LazyVStack(spacing: isCompact ? 12 : 16) {
                        enhancedSearchBar
                        customerGroupsOverview
                        customerGroupsGrid
                    }
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 16)
                }
                .refreshable {
                    loadCustomerGroups()
                }
            }
        }
        .navigationTitle("按客户分组还货")
        .navigationBarTitleDisplayMode(.inline)
        .background(LopanColors.backgroundSecondary)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isSelectionMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isSelectionMode {
                    Button("选择") {
                        isSelectionMode = true
                    }
                } else {
                    Button("完成") {
                        if !selectedCustomerGroups.isEmpty {
                            showingBatchProcessing = true
                        } else {
                            isSelectionMode = false
                        }
                    }
                    .disabled(selectedCustomerGroups.isEmpty)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            updateSearch()
        }
        .onAppear {
            loadCustomerGroups()
        }
        .sheet(isPresented: $showingBatchProcessing) {
            BatchCustomerReturnProcessingView(
                customerGroups: getSelectedGroups(),
                onCompletion: {
                    selectedCustomerGroups.removeAll()
                    loadCustomerGroups()
                }
            )
        }
        .overlay {
            if isLoading {
                ProgressView("正在加载...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LopanColors.shadow.opacity(0.5))
            }
        }
        .navigationDestination(item: $selectedGroupForDetail) { group in
            CustomerReturnDetailView(customerGroup: group)
        }
    }
    
    private var enhancedSearchBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("搜索客户姓名或地址", text: $searchText)
                        .font(.subheadline)
                        
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(10)
                
                if !searchText.isEmpty {
                    Button(action: {
                        LopanHapticEngine.shared.light()
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 20))
                    }
                    .accessibilityLabel("清除搜索")
                }
            }
            
            if !searchText.isEmpty {
                HStack {
                    Text("搜索结果：\(filteredGroups.count) 个客户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 1)
        )
    }
    
    private var batchSelectionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button("取消") {
                    LopanHapticEngine.shared.light()
                    isSelectionMode = false
                    selectedCustomerGroups.removeAll()
                }
                .foregroundColor(LopanColors.error)
                
                Spacer()
                
                Text("选择客户")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("处理") {
                    LopanHapticEngine.shared.medium()
                    showingBatchProcessing = true
                }
                .foregroundColor(selectedCustomerGroups.isEmpty ? LopanColors.textSecondary : LopanColors.primary)
                .disabled(selectedCustomerGroups.isEmpty)
            }
            
            SelectionSummaryBar(
                selectedCount: selectedCustomerGroups.count,
                totalCount: filteredGroups.count,
                onSelectAll: { selectAllGroups() },
                onSecondaryAction: { selectedCustomerGroups.removeAll() }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    LopanColors.primary.opacity(0.08),
                    LopanColors.primary.opacity(0.04)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.primary.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    private var customerGroupsOverview: some View {
        HStack(spacing: 16) {
            EnhancedStatCard(
                title: "客户数量",
                count: filteredGroups.count,
                color: LopanColors.primary,
                icon: "person.2.fill"
            )
            
            EnhancedStatCard(
                title: "可还货量",
                count: filteredGroups.reduce(0) { $0 + $1.returnableQuantity },
                color: LopanColors.warning,
                icon: "arrow.uturn.left.fill"
            )
            
            if isSelectionMode {
                EnhancedStatCard(
                    title: "已选中",
                    count: selectedCustomerGroups.count,
                    color: LopanColors.success,
                    icon: "checkmark.circle.fill"
                )
            }
        }
    }
    
    private var customerGroupsGrid: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredGroups, id: \.customer.id) { group in
                EnhancedCustomerGroupRowView(
                    group: group,
                    isSelected: selectedCustomerGroups.contains(group.customer.id),
                    isSelectionMode: isSelectionMode,
                    onSelectionChanged: { isSelected in
                        toggleSelection(for: group, isSelected: isSelected)
                    },
                    onTap: {
                        if isSelectionMode {
                            let isSelected = selectedCustomerGroups.contains(group.customer.id)
                            toggleSelection(for: group, isSelected: !isSelected)
                        } else {
                            selectedGroupForDetail = group
                        }
                    }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 1)
        )
        .padding(.horizontal, 2)
    }
    
    private func loadCustomerGroups() {
        isLoading = true
        
        Task {
            do {
                // Get returnable items from service
                let returnableItems = salespersonService.customerOutOfStockService.getReturnableItems()
                
                // Group by customer
                let grouped = Dictionary(grouping: returnableItems) { item in
                    item.customer?.id ?? "unknown"
                }
                
                let groups = grouped.compactMap { (customerId, items) -> CustomerReturnGroup? in
                    guard let customer = items.first?.customer else { return nil }
                    return CustomerReturnGroup(customer: customer, items: items)
                }
                
                await MainActor.run {
                    customerGroups = groups.sorted { $0.customer.name < $1.customer.name }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error loading customer groups: \(error)")
                    isLoading = false
                }
            }
        }
    }
    
    private func selectAllGroups() {
        selectedCustomerGroups = Set(filteredGroups.map { $0.customer.id })
    }
    
    private func updateSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            // Search is now performed directly on searchText in filteredGroups
        }
    }
    
    private func toggleSelection(for group: CustomerReturnGroup, isSelected: Bool) {
        LopanHapticEngine.shared.light()
        if isSelected {
            selectedCustomerGroups.insert(group.customer.id)
        } else {
            selectedCustomerGroups.remove(group.customer.id)
        }
    }
    
    private func getSelectedGroups() -> [CustomerReturnGroup] {
        return customerGroups.filter { selectedCustomerGroups.contains($0.customer.id) }
    }
}

struct EnhancedCustomerGroupRowView: View {
    let group: CustomerReturnGroup
    let isSelected: Bool
    let isSelectionMode: Bool
    let onSelectionChanged: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator (only in selection mode)
            if isSelectionMode {
                Button(action: {
                    onSelectionChanged(!isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                        .font(.title2)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Main content area - clickable for navigation
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Customer Avatar
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [LopanColors.primary.opacity(0.6), LopanColors.primary.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(group.customer.name.prefix(1)))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.textPrimary)
                        )
                    
                    // Customer Information
                    VStack(alignment: .leading, spacing: 8) {
                    // Header Row
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.customer.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                
                                .lineLimit(1)
                            
                            Text(group.customer.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Status Badge
                        if group.returnableQuantity > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("可还货")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LopanColors.warning.opacity(0.15))
                            .foregroundColor(LopanColors.warning)
                            .cornerRadius(12)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text("已完成")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LopanColors.success.opacity(0.15))
                            .foregroundColor(LopanColors.success)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Statistics Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ], spacing: 8) {
                        StatisticItem(
                            title: "商品数",
                            value: "\(group.items.count)",
                            color: .secondary
                        )
                        
                        StatisticItem(
                            title: "总数量",
                            value: "\(group.totalQuantity)",
                            color: .primary
                        )
                        
                        StatisticItem(
                            title: "可还货",
                            value: "\(group.returnableQuantity)",
                            color: group.returnableQuantity > 0 ? LopanColors.warning : LopanColors.textSecondary
                        )
                        
                        if group.returnedQuantity > 0 {
                            StatisticItem(
                                title: "已还货",
                                value: "\(group.returnedQuantity)",
                                color: LopanColors.primary
                            )
                        }
                    }
                }
                
                // Action Indicator
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .opacity(0.6)
                }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? LopanColors.primary.opacity(0.05) : LopanColors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? LopanColors.primary.opacity(0.3) : LopanColors.border,
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.customer.name)的还货信息")
        .accessibilityValue("共\(group.items.count)个商品，可还货\(group.returnableQuantity)件")
        .accessibilityHint(isSelectionMode ? "可选择进行批量操作" : "双击查看详情")
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }
}

struct CustomerReturnDetailView: View {
    let customerGroup: CustomerReturnGroup
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    
    private var salespersonService: SalespersonServiceProvider {
        appDependencies.serviceFactory.salespersonServiceProvider
    }
    
    @State private var returnQuantities: [String: String] = [:]
    @State private var returnNotes: [String: String] = [:]
    @State private var selectedItems: Set<String> = []
    @State private var showingProcessingAlert = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            customerInfoHeader
            
            List {
                ForEach(customerGroup.items) { item in
                    ReturnItemDetailRow(
                        item: item,
                        returnQuantity: Binding(
                            get: { returnQuantities[item.id] ?? "" },
                            set: { returnQuantities[item.id] = $0 }
                        ),
                        returnNotes: Binding(
                            get: { returnNotes[item.id] ?? "" },
                            set: { returnNotes[item.id] = $0 }
                        ),
                        isSelected: selectedItems.contains(item.id),
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                selectedItems.insert(item.id)
                                if returnQuantities[item.id]?.isEmpty ?? true {
                                    returnQuantities[item.id] = String(item.remainingQuantity)
                                }
                            } else {
                                selectedItems.remove(item.id)
                            }
                        }
                    )
                }
            }
            
            processButton
        }
        .navigationTitle(customerGroup.customer.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认处理还货", isPresented: $showingProcessingAlert) {
            Button("取消", role: .cancel) { }
            Button("确认") {
                processSelectedReturns()
            }
        } message: {
            Text("确定要处理选中的 \(selectedItems.count) 项还货吗？")
        }
        .overlay {
            if isProcessing {
                ProgressView("正在处理还货...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LopanColors.shadow.opacity(0.5))
            }
        }
    }
    
    private var customerInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(customerGroup.customer.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text(customerGroup.customer.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !customerGroup.customer.phone.isEmpty {
                Text(customerGroup.customer.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(LopanColors.secondary.opacity(0.1))
    }
    
    private var processButton: some View {
        Button(action: {
            showingProcessingAlert = true
        }) {
            Text("处理还货 (\(selectedItems.count))")
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedItems.isEmpty ? LopanColors.secondary : LopanColors.primary)
                .cornerRadius(8)
        }
        .disabled(selectedItems.isEmpty || isProcessing)
        .padding()
    }
    
    private func processSelectedReturns() {
        isProcessing = true
        
        Task {
            do {
                let requests = selectedItems.compactMap { itemId -> ReturnProcessingRequest? in
                    guard let item = customerGroup.items.first(where: { $0.id == itemId }),
                          let quantityStr = returnQuantities[itemId],
                          let quantity = Int(quantityStr),
                          quantity > 0 && quantity <= item.remainingQuantity else {
                        return nil
                    }
                    
                    let notes = returnNotes[itemId]?.isEmpty == false ? returnNotes[itemId] : nil
                    return ReturnProcessingRequest(
                        item: item,
                        deliveryQuantity: quantity,
                        deliveryNotes: notes
                    )
                }
                
                try await salespersonService.customerOutOfStockService.processBatchReturns(requests)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Error processing returns: \(error)")
                    isProcessing = false
                }
            }
        }
    }
}

struct ReturnItemDetailRow: View {
    let item: CustomerOutOfStock
    @Binding var returnQuantity: String
    @Binding var returnNotes: String
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selection and product info
            HStack {
                Button(action: {
                    onSelectionChanged(!isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.productDisplayName)
                        .font(.headline)
                    
                    HStack {
                        Text("总数量: \(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                       if item.deliveryQuantity > 0 {
                           Text("已发: \(item.deliveryQuantity)")
                               .font(.caption)
                                .foregroundColor(LopanColors.info)
                       }
                        
                        Text("可还: \(item.remainingQuantity)")
                            .font(.caption)
                            .foregroundColor(LopanColors.warning)
                    }
                }
                
                Spacer()
            }
            
            // Return quantity and notes input (shown when selected)
            if isSelected {
                VStack(spacing: 8) {
                    HStack {
                        Text("还货数量:")
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("数量", text: $returnQuantity)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        
                       Button("最大值") {
                           returnQuantity = String(item.remainingQuantity)
                       }
                       .font(.caption)
                        .foregroundColor(LopanColors.info)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("备注:")
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("备注（可选）", text: $returnNotes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BatchCustomerReturnProcessingView: View {
    let customerGroups: [CustomerReturnGroup]
    let onCompletion: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("批量还货处理功能开发中...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("批量处理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CustomerGroupedReturnView()
}
