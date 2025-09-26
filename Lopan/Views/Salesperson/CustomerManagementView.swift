//
//  CustomerManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

enum CustomerDeletionError: Error {
    case validationServiceNotInitialized
}

struct CustomerManagementView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.modelContext) private var modelContext
    
    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }
    
    @State private var customers: [Customer] = []
    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var showingDeleteAlert = false
    @State private var customerToDelete: Customer?
    @State private var showingDeletionWarning = false
    @State private var deletionValidationResult: CustomerDeletionValidationService.DeletionValidationResult?
    @State private var validationService: CustomerDeletionValidationService?
    
    var displayedCustomers: [Customer] {
        let filtered = searchText.isEmpty ? customers : customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(searchText) ||
            customer.address.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            customersList
        }
        .navigationTitle("客户管理")
        .navigationBarTitleDisplayMode(.large)
        .background(LopanColors.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCustomer = true
                } label: {
                    Image(systemName: "plus")
                        .font(LopanTypography.buttonMedium)
                }
            }
        }
        .onAppear {
            if validationService == nil {
                validationService = CustomerDeletionValidationService(modelContext: modelContext)
            }
            loadCustomers()
        }
        .sheet(isPresented: $showingAddCustomer) {
            AddCustomerView(onSave: { customer in
                Task {
                    try await customerRepository.addCustomer(customer)
                    loadCustomers()
                }
            })
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(LopanColors.textSecondary)
                    .font(LopanTypography.bodyMedium)
                
                TextField("搜索客户姓名或地址", text: $searchText)
                    .font(LopanTypography.bodyMedium)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(LopanColors.textSecondary)
                    }
                }
            }
            .lopanPaddingHorizontal(LopanSpacing.md)
            .lopanPaddingVertical(LopanSpacing.sm)
            .background(LopanColors.backgroundSecondary)
            .cornerRadius(LopanSpacing.sm)
        }
        .lopanPaddingHorizontal()
        .lopanPaddingVertical(LopanSpacing.sm)
    }
    
    private var customersList: some View {
        List {
            if displayedCustomers.isEmpty {
                emptyStateView
                    .listRowSeparator(.hidden)
            } else {
                ForEach(displayedCustomers) { customer in
                    NavigationLink(destination: CustomerDetailView(customer: customer)) {
                        SimpleCustomerRow(customer: customer)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button {
                            handleDeleteCustomer(customer)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        .tint(LopanColors.error)
                    }
                }
            }
        }
        .listStyle(.plain)
        .alert("删除客户", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let customer = customerToDelete {
                    performSimpleDeletion(customer)
                }
            }
            Button("取消", role: .cancel) {
                customerToDelete = nil
            }
        } message: {
            if let customer = customerToDelete {
                Text("确定要删除客户 \"\(customer.name)\" 吗？")
            }
        }
        .alert("删除客户确认", isPresented: $showingDeletionWarning) {
            if let result = deletionValidationResult {
                if result.pendingOutOfStockCount > 0 {
                    Button("取消", role: .cancel) { 
                        customerToDelete = nil
                        deletionValidationResult = nil
                    }
                    Button("仍要删除", role: .destructive) {
                        performDeletion()
                    }
                } else {
                    Button("取消", role: .cancel) {
                        customerToDelete = nil
                        deletionValidationResult = nil
                    }
                    Button("删除", role: .destructive) {
                        performDeletion()
                    }
                }
            }
        } message: {
            if let result = deletionValidationResult {
                Text(result.impactSummary)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: LopanSpacing.xl) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(LopanColors.textSecondary)
            
            VStack(spacing: LopanSpacing.sm) {
                Text(searchText.isEmpty ? "暂无客户" : "未找到客户")
                    .font(LopanTypography.titleMedium)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(searchText.isEmpty ? "点击右上角 + 号添加第一个客户" : "尝试修改搜索条件")
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button {
                    showingAddCustomer = true
                } label: {
                    Text("添加客户")
                        .font(LopanTypography.buttonMedium)
                        .foregroundColor(LopanColors.textOnPrimary)
                        .lopanPaddingHorizontal(LopanSpacing.xl)
                        .lopanPaddingVertical(LopanSpacing.sm)
                        .background(LopanColors.primary)
                        .cornerRadius(LopanSpacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .lopanPaddingVertical(LopanSpacing.xxxxl)
    }
    
    private func loadCustomers() {
        Task {
            do {
                customers = try await customerRepository.fetchCustomers()
            } catch {
                print("Error loading customers: \(error)")
            }
        }
    }
    
    private func handleDeleteCustomer(_ customer: Customer) {
        Task {
            do {
                guard let validationService = validationService else {
                    throw CustomerDeletionError.validationServiceNotInitialized
                }
                let result = try await validationService.validateCustomerDeletion(customer)
                await MainActor.run {
                    self.deletionValidationResult = result
                    self.customerToDelete = customer
                    self.showingDeletionWarning = true
                }
            } catch {
                print("Error validating customer deletion: \(error)")
                await MainActor.run {
                    // Fallback to simple deletion warning
                    customerToDelete = customer
                    showingDeleteAlert = true
                }
            }
        }
    }
    
    private func performSimpleDeletion(_ customer: Customer) {
        Task {
            do {
                try await customerRepository.deleteCustomer(customer)
                await MainActor.run {
                    withAnimation {
                        customers.removeAll { $0.id == customer.id }
                    }
                    customerToDelete = nil
                }
            } catch {
                await MainActor.run {
                    print("Error deleting customer: \(error)")
                    customerToDelete = nil
                }
            }
        }
    }
    
    private func performDeletion() {
        guard let customer = customerToDelete else { return }
        
        Task {
            do {
                // Prepare customer for safe deletion
                guard let validationService = validationService else {
                    throw CustomerDeletionError.validationServiceNotInitialized
                }
                try await validationService.prepareCustomerForDeletion(customer)
                // Now safe to delete
                try await customerRepository.deleteCustomer(customer)
                
                await MainActor.run {
                    // Remove from local array with animation
                    withAnimation {
                        customers.removeAll { $0.id == customer.id }
                    }
                    customerToDelete = nil
                    deletionValidationResult = nil
                }
            } catch {
                await MainActor.run {
                    print("Error deleting customer: \(error)")
                    customerToDelete = nil
                    deletionValidationResult = nil
                }
            }
        }
    }
}

struct SimpleCustomerRow: View {
    let customer: Customer
    
    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            Circle()
                .fill(LopanColors.primary)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(customer.name.prefix(1)).uppercased())
                        .font(LopanTypography.labelLarge)
                        .foregroundColor(LopanColors.textOnPrimary)
                }
            
            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                Text(customer.name)
                    .font(LopanTypography.bodyLarge)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(customer.address)
                    .font(LopanTypography.bodySmall)
                    .foregroundColor(LopanColors.textSecondary)
                    .lineLimit(1)
                
                if !customer.phone.isEmpty {
                    Text(customer.phone)
                        .font(LopanTypography.bodySmall)
                        .foregroundColor(LopanColors.textSecondary)
                }
            }
            
            Spacer()
        }
        .lopanPaddingVertical(LopanSpacing.sm)
    }
}

struct AddCustomerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var isSaving = false
    
    let onSave: (Customer) -> Void
    
    var isValid: Bool {
        !name.isEmpty && !address.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                Text("客户信息")
                    .font(LopanTypography.headlineSmall)
                    .foregroundColor(LopanColors.textPrimary)
                
                VStack(spacing: LopanSpacing.md) {
                    TextField("客户姓名", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isSaving)
                    
                    TextField("客户地址", text: $address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isSaving)
                    
                    TextField("联系电话", text: $phone)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                        .disabled(isSaving)
                }
                
                Spacer()
            }
            .screenPadding()
            .navigationTitle("添加客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCustomer()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }
    
    private func saveCustomer() {
        isSaving = true
        let customer = Customer(name: name, address: address, phone: phone)
        onSave(customer)
        dismiss()
    }
}

#Preview {
    CustomerManagementView()
        .modelContainer(for: Customer.self, inMemory: true)
}