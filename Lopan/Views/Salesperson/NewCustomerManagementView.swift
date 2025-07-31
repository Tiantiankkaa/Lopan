//
//  NewCustomerManagementView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI

struct NewCustomerManagementView: View {
    @EnvironmentObject private var serviceFactory: ServiceFactory
    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var showingExcelImport = false
    @State private var showingExcelExport = false
    @State private var selectedCustomers: Set<String> = []
    @State private var isBatchMode = false
    @State private var showingDeleteAlert = false
    @State private var customersToDelete: [Customer] = []
    
    private var customerService: CustomerService {
        serviceFactory.customerService
    }
    
    private var authService: AuthenticationService {
        serviceFactory.authenticationService
    }
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customerService.customers
        } else {
            return customerService.customers.filter { customer in
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
            NewAddCustomerView()
        }
        .sheet(isPresented: $showingExcelImport) {
            ExcelImportView(dataType: .customers)
        }
        .sheet(isPresented: $showingExcelExport) {
            ExcelExportView(dataType: .customers)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                Task {
                    guard let currentUser = authService.currentUser else { return }
                    
                    if customersToDelete.count == 1 {
                        await customerService.deleteCustomer(customersToDelete[0], deletedBy: currentUser.id)
                    } else {
                        await customerService.deleteCustomers(customersToDelete, deletedBy: currentUser.id)
                    }
                    
                    selectedCustomers.removeAll()
                    customersToDelete.removeAll()
                    isBatchMode = false
                }
            }
            Button("取消", role: .cancel) {
                customersToDelete.removeAll()
            }
        } message: {
            Text(customersToDelete.count == 1 
                 ? "确定要删除客户 \"\(customersToDelete.first?.name ?? "")\" 吗？"
                 : "确定要删除选中的 \(customersToDelete.count) 个客户吗？")
        }
        .task {
            await customerService.loadCustomers()
        }
    }
    
    private var searchAndToolbarView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                TextField("搜索客户姓名、地址或电话...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Toolbar
            HStack {
                Button(action: { showingAddCustomer = true }) {
                    Label("添加客户", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button(isBatchMode ? "取消" : "批量操作") {
                    isBatchMode.toggle()
                    if !isBatchMode {
                        selectedCustomers.removeAll()
                    }
                }
                .foregroundColor(isBatchMode ? .red : .blue)
                
                Menu {
                    Button("导入Excel") {
                        showingExcelImport = true
                    }
                    Button("导出Excel") {
                        showingExcelExport = true
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
            
            // Batch operations toolbar
            if isBatchMode {
                HStack {
                    Text("已选择 \(selectedCustomers.count) 个客户")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !selectedCustomers.isEmpty {
                        Button("删除选中") {
                            customersToDelete = customerService.customers.filter { selectedCustomers.contains($0.id) }
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var customerListView: some View {
        List {
            ForEach(filteredCustomers, id: \.id) { customer in
                CustomerRow(
                    customer: customer,
                    isSelected: selectedCustomers.contains(customer.id),
                    isBatchMode: isBatchMode,
                    onToggleSelection: { isSelected in
                        if isSelected {
                            selectedCustomers.insert(customer.id)
                        } else {
                            selectedCustomers.remove(customer.id)
                        }
                    },
                    onDelete: {
                        customersToDelete = [customer]
                        showingDeleteAlert = true
                    }
                )
            }
        }
        .refreshable {
            await customerService.loadCustomers()
        }
        .overlay {
            if customerService.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if filteredCustomers.isEmpty {
                ContentUnavailableView(
                    "暂无客户",
                    systemImage: "person.3",
                    description: Text("添加第一个客户开始管理")
                )
            }
        }
    }
}

struct CustomerRow: View {
    let customer: Customer
    let isSelected: Bool
    let isBatchMode: Bool
    let onToggleSelection: (Bool) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            if isBatchMode {
                Button(action: { onToggleSelection(!isSelected) }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(customer.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(customer.phone)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            if !isBatchMode {
                Button("删除") {
                    onDelete()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewAddCustomerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var serviceFactory: ServiceFactory
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var isLoading = false
    
    private var customerService: CustomerService {
        serviceFactory.customerService
    }
    
    private var authService: AuthenticationService {
        serviceFactory.authenticationService
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("客户信息")) {
                    LopanTextField(title: "客户姓名", placeholder: "请输入客户姓名", text: $name)
                    LopanTextField(title: "联系地址", placeholder: "请输入联系地址", text: $address)
                    LopanTextField(title: "联系电话", placeholder: "请输入联系电话", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("添加客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            await saveCustomer()
                        }
                    }
                    .disabled(name.isEmpty || address.isEmpty || phone.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func saveCustomer() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let currentUser = authService.currentUser else { return }
        
        let customer = Customer(name: name, address: address, phone: phone)
        
        let success = await customerService.addCustomer(customer, createdBy: currentUser.id)
        
        if success {
            dismiss()
        }
    }
}

#Preview {
    NavigationView {
        NewCustomerManagementView()
    }
}