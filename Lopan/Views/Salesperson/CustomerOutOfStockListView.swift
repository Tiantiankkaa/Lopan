//
//  CustomerOutOfStockListView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct CustomerOutOfStockListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var outOfStockItems: [CustomerOutOfStock]
    @Query private var customers: [Customer]
    @Query private var products: [Product]
    
    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var selectedStatus: OutOfStockStatus? = nil
    @State private var selectedPriority: OutOfStockPriority? = nil
    @State private var selectedCustomer: Customer? = nil
    @State private var selectedProduct: Product? = nil
    @State private var selectedAddress: String? = nil
    @State private var showingAdvancedFilters = false
    
    // Batch operation states
    @State private var isEditing = false
    @State private var selectedItems: Set<String> = []
    @State private var showingBatchStatusSheet = false
    @State private var showingBatchPrioritySheet = false
    
    // Confirmation alerts
    @State private var showingDeleteConfirmation = false
    @State private var showingBatchDeleteConfirmation = false
    @State private var itemsToDelete: [CustomerOutOfStock] = []
    
    var body: some View {
        VStack {
            mainContentView
        }
        .navigationTitle("客户缺货管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddCustomerOutOfStockView(customers: customers, products: products)
        }
        .sheet(isPresented: $showingBatchStatusSheet) {
            BatchStatusSheet { newStatus in
                updateBatchStatus(newStatus)
            }
        }
        .sheet(isPresented: $showingBatchPrioritySheet) {
            BatchPrioritySheet { newPriority in
                updateBatchPriority(newPriority)
            }
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                confirmDeleteItems()
            }
        } message: {
            Text("确定要删除选中的 \(itemsToDelete.count) 个缺货记录吗？此操作无法撤销。")
        }
        .alert("确认批量删除", isPresented: $showingBatchDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                confirmDeleteSelectedItems()
            }
        } message: {
            Text("确定要删除选中的 \(itemsToDelete.count) 个缺货记录吗？此操作无法撤销。")
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if isEditing {
                batchOperationToolbar
            }
            filterSection
            itemsListSection
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            if !isEditing {
                filterToggleButton
                if showingAdvancedFilters {
                    simpleFiltersView
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
                    Text("高级筛选")
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(action: { startBatchEdit() }) {
                Text("批量操作")
                    .foregroundColor(.blue)
            }
        }
    }
    

    
    private var batchOperationToolbar: some View {
        HStack(spacing: 0) {
            Button(action: { showingBatchStatusSheet = true }) {
                Text("状态")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(selectedItems.isEmpty)
            
            Divider()
                .frame(height: 20)
            
            Button(action: { showingBatchPrioritySheet = true }) {
                Text("优先级")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(selectedItems.isEmpty)
            
            Divider()
                .frame(height: 20)
            
            Button(action: { 
                itemsToDelete = outOfStockItems.filter { selectedItems.contains($0.id) }
                showingBatchDeleteConfirmation = true
            }) {
                Text("删除")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(selectedItems.isEmpty)
            
            Divider()
                .frame(height: 20)
            
            Button(action: { cancelBatchEdit() }) {
                Text("取消")
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
                    Text("已选择 \(selectedItems.count) 个记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    private var simpleFiltersView: some View {
        VStack(spacing: 8) {
            statusFilterButton
            priorityFilterButton
            customerFilterButton
            productFilterButton
            addressFilterButton
        }
    }
    
    private var statusFilterButton: some View {
        Button(action: { selectedStatus = nil }) {
            HStack {
                Text(selectedStatus?.displayName ?? "全部状态")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    private var priorityFilterButton: some View {
        Button(action: { selectedPriority = nil }) {
            HStack {
                Text(selectedPriority?.displayName ?? "全部优先级")
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
        Button(action: { selectedCustomer = nil }) {
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
    
    private var productFilterButton: some View {
        Button(action: { selectedProduct = nil }) {
            HStack {
                Text(selectedProduct?.name ?? "全部产品")
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
        Button(action: { selectedAddress = nil }) {
            HStack {
                Text(selectedAddress ?? "全部地址")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    private var itemsListSection: some View {
        List {
            ForEach(filteredItems) { item in
                if isEditing {
                    CustomerOutOfStockRowView(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        isEditing: isEditing,
                        onSelect: { toggleItemSelection(item) }
                    )
                } else {
                    NavigationLink(destination: CustomerOutOfStockDetailView(item: item)) {
                        CustomerOutOfStockRowView(
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
    
    // MARK: - Computed Properties
    
    var filteredItems: [CustomerOutOfStock] {
        var filtered = outOfStockItems
        
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        if let priority = selectedPriority {
            filtered = filtered.filter { $0.priority == priority }
        }
        
        if let customer = selectedCustomer {
            filtered = filtered.filter { $0.customer?.id == customer.id }
        }
        
        if let product = selectedProduct {
            filtered = filtered.filter { $0.product?.id == product.id }
        }
        
        if let address = selectedAddress {
            filtered = filtered.filter { $0.customer?.address == address }
        }
        
        return filtered.sorted { $0.requestDate > $1.requestDate }
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
    
    private func deleteItem(_ item: CustomerOutOfStock) {
        itemsToDelete = [item]
        showingDeleteConfirmation = true
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
    
    private func deleteSelectedItems() {
        let itemsToDelete = outOfStockItems.filter { selectedItems.contains($0.id) }
        
        // Log batch deletion before deleting
        if !itemsToDelete.isEmpty {
            let affectedItemIds = itemsToDelete.map { $0.id }
            let entityDescriptions = itemsToDelete.map { "\($0.customer?.name ?? "未知客户") - \($0.productDisplayName)" }
            
            AuditingService.shared.logBatchOperation(
                operationType: .batchDelete,
                entityType: .customerOutOfStock,
                affectedItems: affectedItemIds,
                entityDescriptions: entityDescriptions,
                changeDetails: ["deletionReason": "批量删除"],
                operatorUserId: "demo_user", // TODO: Get from current user
                operatorUserName: "演示用户", // TODO: Get from current user
                modelContext: modelContext
            )
            
            // Log individual deletions
            for item in itemsToDelete {
                AuditingService.shared.logCustomerOutOfStockDeletion(
                    item: item,
                    operatorUserId: "demo_user", // TODO: Get from current user
                    operatorUserName: "演示用户", // TODO: Get from current user
                    modelContext: modelContext
                )
            }
        }
        
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        
        selectedItems.removeAll()
        isEditing = false
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting items: \(error)")
        }
    }
    
    private func updateBatchStatus(_ newStatus: OutOfStockStatus) {
        let itemsToUpdate = outOfStockItems.filter { selectedItems.contains($0.id) }
        
        // Log batch status update before updating
        if !itemsToUpdate.isEmpty {
            let affectedItemIds = itemsToUpdate.map { $0.id }
            let entityDescriptions = itemsToUpdate.map { "\($0.customer?.name ?? "未知客户") - \($0.productDisplayName)" }
            
            AuditingService.shared.logBatchOperation(
                operationType: .batchUpdate,
                entityType: .customerOutOfStock,
                affectedItems: affectedItemIds,
                entityDescriptions: entityDescriptions,
                changeDetails: [
                    "updateType": "status",
                    "newStatus": newStatus.displayName,
                    "batchSize": itemsToUpdate.count
                ],
                operatorUserId: "demo_user", // TODO: Get from current user
                operatorUserName: "演示用户", // TODO: Get from current user
                modelContext: modelContext
            )
            
            // Log individual status changes
            for item in itemsToUpdate {
                let oldStatus = item.status
                AuditingService.shared.logCustomerOutOfStockStatusChange(
                    item: item,
                    fromStatus: oldStatus,
                    toStatus: newStatus,
                    operatorUserId: "demo_user", // TODO: Get from current user
                    operatorUserName: "演示用户", // TODO: Get from current user
                    modelContext: modelContext
                )
            }
        }
        
        for item in itemsToUpdate {
            item.status = newStatus
            item.updatedAt = Date()
        }
        
        selectedItems.removeAll()
        isEditing = false
        
        do {
            try modelContext.save()
        } catch {
            print("Error updating status: \(error)")
        }
    }
    
    private func updateBatchPriority(_ newPriority: OutOfStockPriority) {
        let itemsToUpdate = outOfStockItems.filter { selectedItems.contains($0.id) }
        
        // Log batch priority update before updating
        if !itemsToUpdate.isEmpty {
            let affectedItemIds = itemsToUpdate.map { $0.id }
            let entityDescriptions = itemsToUpdate.map { "\($0.customer?.name ?? "未知客户") - \($0.productDisplayName)" }
            
            AuditingService.shared.logBatchOperation(
                operationType: .batchUpdate,
                entityType: .customerOutOfStock,
                affectedItems: affectedItemIds,
                entityDescriptions: entityDescriptions,
                changeDetails: [
                    "updateType": "priority",
                    "newPriority": newPriority.displayName,
                    "itemCount": itemsToUpdate.count
                ],
                operatorUserId: "demo_user", // TODO: Get from current user
                operatorUserName: "演示用户", // TODO: Get from current user
                modelContext: modelContext
            )
        }
        
        for item in itemsToUpdate {
            item.priority = newPriority
            item.updatedAt = Date()
        }
        
        selectedItems.removeAll()
        isEditing = false
        
        do {
            try modelContext.save()
        } catch {
            print("Error updating priority: \(error)")
        }
    }
    
    private func confirmDeleteItems() {
        // Log deletion for each item before deleting
        for item in itemsToDelete {
            AuditingService.shared.logCustomerOutOfStockDeletion(
                item: item,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                modelContext: modelContext
            )
            modelContext.delete(item)
        }
        
        itemsToDelete.removeAll()
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting items: \(error)")
        }
    }
    
    private func confirmDeleteSelectedItems() {
        deleteSelectedItems()
    }
}

// MARK: - Row View
struct CustomerOutOfStockRowView: View {
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
                Text(item.customer?.name ?? "未知客户")
                    .font(.headline)
                
                Text(item.productDisplayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("数量: \(item.quantity)")
                        if item.returnQuantity > 0 {
                            Text("已退: \(item.returnQuantity)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        if item.remainingQuantity > 0 && item.returnQuantity > 0 {
                            Text("剩余: \(item.remainingQuantity)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.status.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.2))
                            .cornerRadius(4)
                        
                        if item.needsReturn || item.hasPartialReturn {
                            Text(returnStatusText)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(returnStatusColor.opacity(0.2))
                                .foregroundColor(returnStatusColor)
                                .cornerRadius(3)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .inProduction: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private var returnStatusText: String {
        if item.isFullyReturned {
            return "fully_returned".localized
        } else if item.hasPartialReturn {
            return "partially_returned".localized
        } else if item.needsReturn {
            return "needs_return".localized
        } else {
            return ""
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

// MARK: - Add Customer Out of Stock View
struct AddCustomerOutOfStockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let customers: [Customer]
    let products: [Product]
    
    @State private var selectedCustomer: Customer?
    @State private var selectedProduct: Product?
    @State private var selectedProductSize: ProductSize?
    @State private var quantity = ""
    @State private var priority: OutOfStockPriority = .medium
    @State private var notes = ""
    @State private var showingAddCustomer = false
    @State private var showingAddProduct = false
    @State private var customerSearchText = ""
    @State private var productSearchText = ""
    @State private var showingCustomerPicker = false
    @State private var showingProductPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                customerSection
                productSection
                quantitySection
                prioritySection
                notesSection
            }
            .navigationTitle("新增缺货记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveItem() }
                        .disabled(selectedCustomer == nil || selectedProduct == nil || quantity.isEmpty)
                }
            }
            .sheet(isPresented: $showingCustomerPicker) {
                SearchableCustomerPicker(
                    customers: customers,
                    selectedCustomer: $selectedCustomer,
                    searchText: $customerSearchText
                )
            }
            .sheet(isPresented: $showingProductPicker) {
                SearchableProductPicker(
                    products: products,
                    selectedProduct: $selectedProduct,
                    selectedProductSize: $selectedProductSize,
                    searchText: $productSearchText
                )
            }
            .sheet(isPresented: $showingAddCustomer) {
                AddCustomerView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView()
                    .environment(\.modelContext, modelContext)
            }
        }
    }
    
    private var customerSection: some View {
        Section("客户信息") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCustomer?.name ?? "请选择客户")
                        .foregroundColor(selectedCustomer == nil ? .secondary : .primary)
                    if let customer = selectedCustomer {
                        Text(customer.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("选择") {
                    showingCustomerPicker = true
                }
                .foregroundColor(.blue)
            }
            Button("添加新客户") { showingAddCustomer = true }
        }
    }
    
    private var productSection: some View {
        Section("产品信息") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedProduct?.name ?? "请选择产品")
                        .foregroundColor(selectedProduct == nil ? .secondary : .primary)
                    if let product = selectedProduct {
                        if !product.colors.isEmpty {
                            Text(product.colors.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("无颜色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Button("选择") {
                    showingProductPicker = true
                }
                .foregroundColor(.blue)
            }
            Button("添加新产品") { showingAddProduct = true }
            
            if let product = selectedProduct, let sizes = product.sizes, !sizes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择尺寸")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sizes) { size in
                                Button(action: {
                                    selectedProductSize = size
                                }) {
                                    Text(size.size)
                                        .font(.caption)
                                        .foregroundColor(selectedProductSize?.id == size.id ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedProductSize?.id == size.id ? Color.blue : Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var quantitySection: some View {
        Section("缺货数量") {
            TextField("数量", text: $quantity)
                .keyboardType(.numberPad)
        }
    }
    
    private var prioritySection: some View {
        Section("优先级") {
            Picker("优先级", selection: $priority) {
                ForEach(OutOfStockPriority.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var notesSection: some View {
        Section("备注") {
            TextField("备注信息", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private func saveItem() {
        guard let quantityInt = Int(quantity), let customer = selectedCustomer, let product = selectedProduct else { return }
        
        let item = CustomerOutOfStock(
            customer: customer,
            product: product,
            productSize: selectedProductSize,
            quantity: quantityInt,
            priority: priority,
            notes: notes.isEmpty ? nil : notes,
            createdBy: "demo_user"
        )
        
        modelContext.insert(item)
        
        // Log the creation
        AuditingService.shared.logCustomerOutOfStockCreation(
            item: item,
            operatorUserId: "demo_user", // TODO: Get from authentication service
            operatorUserName: "演示用户", // TODO: Get from authentication service
            modelContext: modelContext
        )
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving item: \(error)")
        }
    }
}

// MARK: - Searchable Customer Picker
struct SearchableCustomerPicker: View {
    @Environment(\.dismiss) private var dismiss
    let customers: [Customer]
    @Binding var selectedCustomer: Customer?
    @Binding var searchText: String
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customers.sorted { $0.name < $1.name }
        } else {
            return customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.address.localizedCaseInsensitiveContains(searchText) ||
                customer.phone.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("搜索客户姓名、地址、电话...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                List {
                    ForEach(filteredCustomers) { customer in
                        Button(action: {
                            selectedCustomer = customer
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(customer.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(customer.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(customer.phone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("选择客户")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Searchable Product Picker
struct SearchableProductPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let products: [Product]
    @Binding var selectedProduct: Product?
    @Binding var selectedProductSize: ProductSize?
    @Binding var searchText: String
    @State private var loadedProducts: [Product] = []
    @State private var showingConfirmation = false
    
    private var productsToUse: [Product] {
        loadedProducts.isEmpty ? products : loadedProducts
    }
    
    private func filterProducts(_ products: [Product]) -> [Product] {
        if searchText.isEmpty {
            return products.sorted { $0.name < $1.name }
        } else {
            let searchTerms = searchText.lowercased().split(separator: " ")
            return products.filter { product in
                let sizeNames = product.sizeNames.joined(separator: " ")
                let colorNames = product.colors.joined(separator: " ")
                let productText = "\(product.name) \(sizeNames) \(colorNames)".lowercased()
                return searchTerms.allSatisfy { term in
                    productText.contains(term)
                }
            }.sorted { $0.name < $1.name }
        }
    }
    
    var filteredProducts: [Product] {
        filterProducts(productsToUse)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text("可用产品: \(filteredProducts.count) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                TextField("搜索产品名称、尺寸、颜色 (支持多关键词)", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                List {
                    ForEach(filteredProducts) { product in
                        ProductSelectionRowView(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedProduct = product
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("选择产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        showingConfirmation = true
                    }
                    .disabled(selectedProduct == nil)
                }
            }
            .onAppear {
                loadProductsFromDatabase()
            }
            .alert("确认选择", isPresented: $showingConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认") {
                    dismiss()
                }
            } message: {
                if let product = selectedProduct {
                    let colorDisplay = product.colors.isEmpty ? "无颜色" : product.colors.joined(separator: ", ")
                    Text("您已选择: \(product.name)-\(colorDisplay)")
                } else {
                    Text("请先选择一个产品")
                }
            }
        }
    }
    
    private func loadProductsFromDatabase() {
        do {
            let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            loadedProducts = try modelContext.fetch(descriptor)
            
            if loadedProducts.isEmpty {
                DataInitializationService.initializeSampleData(modelContext: modelContext)
                loadedProducts = try modelContext.fetch(descriptor)
            }
        } catch {
            print("❌ SearchableProductPicker - Failed to load products: \(error)")
            loadedProducts = []
        }
    }
}

// MARK: - Product Selection Row View
struct ProductSelectionRowView: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                productImage
                productInfo
                Spacer()
                selectionCheckmark
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var productImage: some View {
        Group {
            if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .cornerRadius(12)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
    }
    
    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.name)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            if !product.colors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(product.colors, id: \.self) { color in
                            Text(color)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
            } else {
                Text("暂无颜色")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let sizes = product.sizes, !sizes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sizes) { size in
                            Text(size.size)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            } else {
                Text("暂无尺寸")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var selectionCheckmark: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title)
                    .scaleEffect(isSelected ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
    }
}

// MARK: - Batch Operation Sheets
struct BatchStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (OutOfStockStatus) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(OutOfStockStatus.allCases, id: \.self) { status in
                    Button(action: {
                        onSelect(status)
                        dismiss()
                    }) {
                        HStack {
                            Text(status.displayName)
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择状态")
            .navigationBarTitleDisplayMode(.inline)
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

struct BatchPrioritySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (OutOfStockPriority) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(OutOfStockPriority.allCases, id: \.self) { priority in
                    Button(action: {
                        onSelect(priority)
                        dismiss()
                    }) {
                        HStack {
                            Text(priority.displayName)
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择优先级")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Customer Out of Stock Detail View
struct CustomerOutOfStockDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: CustomerOutOfStock
    
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusCardView
                customerInfoView
                outOfStockInfoView
                datesView
                notesView
            }
            .padding()
        }
        .navigationTitle("缺货详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCustomerOutOfStockView(item: item)
        }
    }
    
    private var statusCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("处理状态")
                .font(.headline)
            
            HStack {
                Text(item.status.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(item.priority.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(item.priority).opacity(0.2))
                    .foregroundColor(priorityColor(item.priority))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var customerInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("客户信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("客户姓名:")
                    Text(item.customer?.name ?? "未知")
                }
                HStack {
                    Text("客户地址:")
                    Text(item.customer?.address ?? "未知")
                }
                HStack {
                    Text("联系电话:")
                    Text(item.customer?.phone ?? "未知")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var outOfStockInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("缺货信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("缺货款式:")
                    Text(item.product?.name ?? "未知")
                }
                HStack {
                    Text("尺寸:")
                    Text(item.productSize?.size ?? "未指定")
                }
                HStack {
                    Text("颜色:")
                    Text(item.product?.color ?? "未知")
                }
                HStack {
                    Text("数量:")
                    Text("\(item.quantity)")
                }
                HStack {
                    Text("优先级:")
                    Text(item.priority.displayName)
                        .foregroundColor(priorityColor(item.priority))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var datesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("申请时间:")
                    Text(item.requestDate, style: .date)
                }
                
                if let actualDate = item.actualCompletionDate {
                    HStack {
                        Text("实际完成:")
                        Text(actualDate, style: .date)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var notesView: some View {
        Group {
            if let notes = item.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("备注")
                        .font(.headline)
                    
                    Text(notes)
                        .font(.body)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .inProduction: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private func priorityColor(_ priority: OutOfStockPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

// MARK: - Edit Customer Out of Stock View
struct EditCustomerOutOfStockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: CustomerOutOfStock
    
    @State private var selectedCustomer: Customer?
    @State private var selectedProduct: Product?
    @State private var selectedProductSize: ProductSize?
    @State private var quantity: String
    @State private var priority: OutOfStockPriority
    @State private var status: OutOfStockStatus
    @State private var notes: String
    @State private var showingProductPicker = false
    @State private var productSearchText = ""
    @State private var products: [Product] = []
    
    init(item: CustomerOutOfStock) {
        self.item = item
        _selectedCustomer = State(initialValue: item.customer)
        _selectedProduct = State(initialValue: item.product)
        _selectedProductSize = State(initialValue: item.productSize)
        _quantity = State(initialValue: String(item.quantity))
        _priority = State(initialValue: item.priority)
        _status = State(initialValue: item.status)
        _notes = State(initialValue: item.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("客户信息") {
                    HStack {
                        Text("客户姓名")
                        Spacer()
                        Text(selectedCustomer?.name ?? "未选择")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("产品信息") {
                    HStack {
                        Text("选择产品")
                        Spacer()
                        Button(action: {
                            showingProductPicker = true
                        }) {
                            Text(selectedProduct?.name ?? "选择产品")
                                .foregroundColor(selectedProduct == nil ? .blue : .primary)
                        }
                    }
                    
                    if let product = selectedProduct {
                        HStack {
                            Text("产品详情")
                            Spacer()
                            if !product.colors.isEmpty {
                                Text(product.colors.joined(separator: ", "))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("无颜色")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let sizes = product.sizes, !sizes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("选择尺寸")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(sizes) { size in
                                            Button(action: {
                                                selectedProductSize = size
                                            }) {
                                                Text(size.size)
                                                    .font(.caption)
                                                    .foregroundColor(selectedProductSize?.id == size.id ? .white : .primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(selectedProductSize?.id == size.id ? Color.blue : Color.gray.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                            HStack {
                                Text("产品图片")
                                Spacer()
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Section("缺货信息") {
                    TextField("数量", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        ForEach(OutOfStockPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("处理状态") {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(status.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("提示：状态由系统根据还货处理情况自动更新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("备注") {
                    TextField("备注信息", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("编辑缺货记录")
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
                }
            }
            .sheet(isPresented: $showingProductPicker) {
                SearchableProductPicker(
                    products: products,
                    selectedProduct: $selectedProduct,
                    selectedProductSize: $selectedProductSize,
                    searchText: $productSearchText
                )
            }
            .onAppear {
                loadProducts()
            }
            .onChange(of: showingProductPicker) { _, isPresented in
                if isPresented {
                    loadProducts()
                }
            }
        }
    }
    
    private func loadProducts() {
        do {
            let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            products = try modelContext.fetch(descriptor)
            
            if products.isEmpty {
                DataInitializationService.initializeSampleData(modelContext: modelContext)
                products = try modelContext.fetch(descriptor)
            }
        } catch {
            print("Failed to load products: \(error)")
            products = []
        }
    }
    
    private func saveChanges() {
        // Capture values before update for audit log
        let beforeValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            priority: item.priority.displayName,
            status: item.status.displayName,
            notes: item.notes,
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
        
        // Track which fields changed
        var changedFields: [String] = []
        
        if item.customer?.id != selectedCustomer?.id {
            changedFields.append("customer")
        }
        if item.product?.id != selectedProduct?.id {
            changedFields.append("product")
        }
        if item.productSize != selectedProductSize {
            changedFields.append("productSize")
        }
        if let newQuantity = Int(quantity), newQuantity != item.quantity {
            changedFields.append("quantity")
        }
        if item.priority != priority {
            changedFields.append("priority")
        }
        let newNotes = notes.isEmpty ? nil : notes
        if item.notes != newNotes {
            changedFields.append("notes")
        }
        
        // Apply changes
        item.customer = selectedCustomer
        item.product = selectedProduct
        item.productSize = selectedProductSize
        item.quantity = Int(quantity) ?? item.quantity
        item.priority = priority
        // Note: Status is no longer user-editable, managed by system
        item.notes = notes.isEmpty ? nil : notes
        item.updatedAt = Date()
        
        // Log the update if any fields changed
        if !changedFields.isEmpty {
            AuditingService.shared.logCustomerOutOfStockUpdate(
                item: item,
                beforeValues: beforeValues,
                changedFields: changedFields,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                modelContext: modelContext,
                additionalInfo: "字段更新: \(changedFields.joined(separator: ", "))"
            )
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving changes: \(error)")
        }
    }
}

#Preview {
    CustomerOutOfStockListView()
        .modelContainer(for: CustomerOutOfStock.self, inMemory: true)
}
