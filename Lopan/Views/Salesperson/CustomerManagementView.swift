//
//  CustomerManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct CustomerManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var customers: [Customer]
    
    @State private var showingAddCustomer = false
    @State private var showingExcelImport = false
    @State private var showingExcelExport = false
    @State private var searchText = ""
    @State private var selectedCustomers: Set<String> = []
    @State private var isBatchMode = false
    @State private var showingDeleteAlert = false
    @State private var customersToDelete: [Customer] = []
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customers
        } else {
            return customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.address.localizedCaseInsensitiveContains(searchText) ||
                customer.phone.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search and toolbar
            searchAndToolbarView
            
            // Customer list
            customerListView
        }
        .navigationTitle("客户管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCustomer) {
            AddCustomerView()
        }
        .sheet(isPresented: $showingExcelImport) {
            ExcelImportView(dataType: .customers)
        }
        .sheet(isPresented: $showingExcelExport) {
            ExcelExportView(dataType: .customers)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteSelectedCustomers()
            }
        } message: {
            Text("确定要删除选中的 \(customersToDelete.count) 个客户吗？此操作不可撤销。")
        }
    }
    
    private var searchAndToolbarView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索客户姓名、地址、电话", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Toolbar
            HStack {
                if isBatchMode {
                    Button(action: { 
                        customersToDelete = customers.filter { selectedCustomers.contains($0.id) }
                        showingDeleteAlert = true
                    }) {
                        Label("删除", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                    .disabled(selectedCustomers.isEmpty)
                } else {
                    Button(action: { showingAddCustomer = true }) {
                        Label("添加", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                Button(action: { showingExcelImport = true }) {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                
                Button(action: { showingExcelExport = true }) {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                
                Button(action: { toggleBatchMode() }) {
                    Label(isBatchMode ? "完成" : "批量", systemImage: isBatchMode ? "checkmark" : "list.bullet")
                }
                .buttonStyle(.bordered)
                .foregroundColor(isBatchMode ? .green : .primary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var customerListView: some View {
        List {
            ForEach(filteredCustomers) { customer in
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
        }
        .listStyle(PlainListStyle())
    }
    
    private func toggleBatchMode() {
        withAnimation {
            isBatchMode.toggle()
            if !isBatchMode {
                selectedCustomers.removeAll()
            }
        }
    }
    
    private func toggleCustomerSelection(_ customer: Customer) {
        if isBatchMode {
            if selectedCustomers.contains(customer.id) {
                selectedCustomers.remove(customer.id)
            } else {
                selectedCustomers.insert(customer.id)
            }
        }
    }
    
    private func deleteCustomer(_ customer: Customer) {
        customersToDelete = [customer]
        showingDeleteAlert = true
    }
    
    private func deleteSelectedCustomers() {
        let customersToDelete = customers.filter { selectedCustomers.contains($0.id) }
        
        for customer in customersToDelete {
            modelContext.delete(customer)
        }
        
        selectedCustomers.removeAll()
        isBatchMode = false
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting customers: \(error)")
        }
    }
}

struct CustomerRowView: View {
    let customer: Customer
    let isSelected: Bool
    let isBatchMode: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection checkbox
            if isBatchMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Customer info
            VStack(alignment: .leading, spacing: 8) {
                Text(customer.name)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text(customer.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(customer.phone)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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
        case .confirmed: return .blue
        case .inProduction: return .purple
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
        NavigationView {
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

#Preview {
    CustomerManagementView()
        .modelContainer(for: Customer.self, inMemory: true)
} 
