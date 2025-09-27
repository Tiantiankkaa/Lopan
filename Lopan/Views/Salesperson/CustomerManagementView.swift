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
    @State private var isLoadingCustomers = false
    
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("客户管理列表")
        .accessibilityHint("浏览和管理客户信息")
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
            LopanTextField(
                title: "",
                placeholder: "搜索客户姓名或地址",
                text: $searchText,
                variant: .outline,
                icon: "magnifyingglass",
                helperText: "输入客户姓名或地址进行搜索"
            )

            if !searchText.isEmpty {
                LopanButton(
                    "清除",
                    style: .ghost,
                    size: .small,
                    icon: "xmark.circle.fill"
                ) {
                    searchText = ""
                }
            }
        }
        .lopanPaddingHorizontal()
        .lopanPaddingVertical(LopanSpacing.sm)
    }
    
    private var customersList: some View {
        Group {
            if displayedCustomers.isEmpty && !isLoadingCustomers {
                emptyStateView
            } else {
                LopanLazyList(
                    data: displayedCustomers,
                    configuration: LopanLazyList.Configuration(
                        isLoading: isLoadingCustomers,
                        skeletonCount: 8,
                        spacing: LopanSpacing.sm,
                        onRefresh: {
                            Task {
                                await refreshCustomers()
                            }
                        },
                        accessibilityLabel: "客户列表"
                    ),
                    content: { customer in
                        NavigationLink(destination: CustomerDetailView(customer: customer)) {
                            SimpleCustomerRow(customer: customer)
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            LopanButton(
                                "删除",
                                style: .destructive,
                                size: .small,
                                icon: "trash"
                            ) {
                                handleDeleteCustomer(customer)
                            }
                        }
                    },
                    skeletonContent: {
                        CustomerSkeletonRow()
                    }
                )
                .onAppear {
                    LopanScrollOptimizer.shared.startOptimization()
                }
                .onDisappear {
                    LopanScrollOptimizer.shared.stopOptimization()
                }
                .animation(
                    {
                        if #available(iOS 26.0, *) {
                            return LopanAdvancedAnimations.liquidSpring
                        } else {
                            return .spring(response: 0.55, dampingFraction: 0.825)
                        }
                    }(),
                    value: displayedCustomers.count
                )
            }
        }
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
                isLoadingCustomers = true
                customers = try await customerRepository.fetchCustomers()
                isLoadingCustomers = false
            } catch {
                print("Error loading customers: \(error)")
                isLoadingCustomers = false
            }
        }
    }

    private func refreshCustomers() async {
        do {
            customers = try await customerRepository.fetchCustomers()
        } catch {
            print("Error refreshing customers: \(error)")
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
                    LopanTextField(
                        title: "客户姓名",
                        placeholder: "请输入客户姓名",
                        text: $name,
                        variant: .outline,
                        state: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .error : .normal,
                        isRequired: true,
                        icon: "person",
                        errorText: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "客户姓名不能为空" : nil
                    )

                    LopanTextField(
                        title: "客户地址",
                        placeholder: "请输入客户地址",
                        text: $address,
                        variant: .outline,
                        state: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .error : .normal,
                        isRequired: true,
                        icon: "location",
                        errorText: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "客户地址不能为空" : nil
                    )

                    LopanTextField(
                        title: "联系电话",
                        placeholder: "请输入联系电话（可选）",
                        text: $phone,
                        variant: .outline,
                        keyboardType: .phonePad,
                        icon: "phone",
                        helperText: "联系电话为可选信息"
                    )
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

// MARK: - Customer Skeleton Row
struct CustomerSkeletonRow: View {
    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            Circle()
                .fill(LopanColors.secondaryLight)
                .frame(width: 40, height: 40)
                .shimmering()

            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmering()

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmering()

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 12)
                    .frame(width: 120, alignment: .leading)
                    .shimmering()
            }

            Spacer()
        }
        .lopanPaddingVertical(LopanSpacing.sm)
        .accessibilityHidden(true)
    }
}

#Preview {
    CustomerManagementView()
        .modelContainer(for: Customer.self, inMemory: true)
}