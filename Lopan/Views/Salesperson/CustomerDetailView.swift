//
//  CustomerDetailView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    let customer: Customer
    
    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }
    
    private var customerOutOfStockRepository: CustomerOutOfStockRepository {
        appDependencies.serviceFactory.repositoryFactory.customerOutOfStockRepository
    }
    
    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }
    
    @State private var recentOutOfStockItems: [CustomerOutOfStock] = []
    @State private var isLoadingOutOfStock = true
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.xl) {
                customerInfoCard
                outOfStockOverviewCard
            }
            .screenPadding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(LopanColors.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("编辑客户", systemImage: "pencil") {
                        showingEditSheet = true
                    }
                    
                    Button("拨打电话", systemImage: "phone") {
                        callCustomer()
                    }
                    
                    Button("发送短信", systemImage: "message") {
                        messageCustomer()
                    }
                    
                    Divider()
                    
                    Button("删除客户", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCustomerView(customer: customer)
        }
        .alert("删除客户", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                deleteCustomer()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除客户 \"\(customer.name)\" 吗？此操作不可撤销。")
        }
        .onAppear {
            loadRecentOutOfStockRecords()
        }
    }
    
    private var customerInfoCard: some View {
        InfoCard(title: "客户信息") {
            VStack(spacing: LopanSpacing.md) {
                HStack(spacing: LopanSpacing.md) {
                    Circle()
                        .fill(LopanColors.primary)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text(String(customer.name.prefix(1)).uppercased())
                                .font(LopanTypography.headlineSmall)
                                .foregroundColor(LopanColors.textOnPrimary)
                        }
                    
                    VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                        Text(customer.name)
                            .font(LopanTypography.titleLarge)
                            .foregroundColor(LopanColors.textPrimary)
                        
                        Text("客户编号: \(customer.customerNumber)")
                            .font(LopanTypography.bodySmall)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                VStack(spacing: LopanSpacing.sm) {
                    InfoRow(icon: "location", label: "地址", value: customer.address)
                    InfoRow(icon: "phone", label: "电话", value: customer.phone)
                    InfoRow(icon: "calendar", label: "创建时间", 
                           value: customer.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }
    
    private var outOfStockOverviewCard: some View {
        InfoCard(title: "缺货记录 (最近7天)") {
            if isLoadingOutOfStock {
                VStack(spacing: LopanSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在加载...")
                        .font(LopanTypography.bodySmall)
                        .foregroundColor(LopanColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .lopanPaddingVertical(LopanSpacing.xl)
            } else if recentOutOfStockItems.isEmpty {
                VStack(spacing: LopanSpacing.md) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(LopanColors.success)
                    
                    Text("最近7天暂无缺货记录")
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(LopanColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .lopanPaddingVertical(LopanSpacing.xl)
            } else {
                VStack(spacing: LopanSpacing.md) {
                    HStack {
                        Text("共 \(recentOutOfStockItems.count) 条记录")
                            .font(LopanTypography.bodyMedium)
                            .foregroundColor(LopanColors.textPrimary)
                        
                        Spacer()
                        
                        Text("待处理: \(recentOutOfStockItems.filter { $0.status == .pending }.count)")
                            .font(LopanTypography.bodySmall)
                            .foregroundColor(LopanColors.warning)
                    }
                    
                    ForEach(recentOutOfStockItems.prefix(5), id: \.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                                Text(item.product?.name ?? "未知产品")
                                    .font(LopanTypography.bodyMedium)
                                    .foregroundColor(LopanColors.textPrimary)
                                
                                Text("数量: \(item.quantity)")
                                    .font(LopanTypography.bodySmall)
                                    .foregroundColor(LopanColors.textSecondary)
                                
                                Text(item.requestDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(LopanTypography.caption)
                                    .foregroundColor(LopanColors.textTertiary)
                            }
                            
                            Spacer()
                            
                            Text(item.status.displayName)
                                .font(LopanTypography.caption)
                                .lopanPaddingHorizontal(LopanSpacing.xs)
                                .lopanPaddingVertical(LopanSpacing.xxs)
                                .background(statusColor(for: item.status).opacity(0.2))
                                .foregroundColor(statusColor(for: item.status))
                                .cornerRadius(LopanSpacing.xs)
                        }
                        .lopanPaddingVertical(LopanSpacing.xs)
                        
                        if item != recentOutOfStockItems.prefix(5).last {
                            Divider()
                        }
                    }
                    
                    if recentOutOfStockItems.count > 5 {
                        Text("还有 \(recentOutOfStockItems.count - 5) 条记录")
                            .font(LopanTypography.caption)
                            .foregroundColor(LopanColors.textTertiary)
                    }
                }
            }
        }
    }
    
    private func statusColor(for status: OutOfStockStatus) -> Color {
        switch status {
        case .pending: return LopanColors.warning
        case .completed: return LopanColors.success
        case .returned: return LopanColors.success
        }
    }
    
    private func callCustomer() {
        guard let url = URL(string: "tel://\(customer.phone)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func messageCustomer() {
        guard let url = URL(string: "sms://\(customer.phone)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func deleteCustomer() {
        Task {
            do {
                try await customerRepository.deleteCustomer(customer)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to delete customer: \(error)")
            }
        }
    }
    
    private func loadRecentOutOfStockRecords() {
        Task {
            isLoadingOutOfStock = true
            
            do {
                // Fetch all records for this customer
                let allRecords = try await customerOutOfStockRepository.fetchOutOfStockRecords(for: customer)
                
                // Filter to last 7 days only and sort by most recent first
                let filteredRecords = allRecords
                    .filter { $0.requestDate >= sevenDaysAgo }
                    .sorted { $0.requestDate > $1.requestDate }
                
                await MainActor.run {
                    recentOutOfStockItems = filteredRecords
                    isLoadingOutOfStock = false
                }
            } catch {
                await MainActor.run {
                    isLoadingOutOfStock = false
                    print("Failed to load out-of-stock records: \(error)")
                }
            }
        }
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            Text(title)
                .font(LopanTypography.titleMedium)
                .foregroundColor(LopanColors.textPrimary)
            
            content
        }
        .cardPadding()
        .background(LopanColors.surface)
        .cornerRadius(LopanSpacing.md)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: icon)
                .font(LopanTypography.bodySmall)
                .foregroundColor(LopanColors.primary)
                .frame(width: 20)
            
            Text(label)
                .font(LopanTypography.bodySmall)
                .foregroundColor(LopanColors.textSecondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(LopanTypography.bodyMedium)
                .foregroundColor(LopanColors.textPrimary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct EditCustomerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies
    let customer: Customer
    
    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }
    
    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var isSaving = false
    
    init(customer: Customer) {
        self.customer = customer
        self._name = State(initialValue: customer.name)
        self._address = State(initialValue: customer.address)
        self._phone = State(initialValue: customer.phone)
    }
    
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
            .navigationTitle("编辑客户")
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
        
        customer.name = name
        customer.address = address
        customer.phone = phone
        customer.updatedAt = Date()
        
        Task {
            do {
                try await customerRepository.updateCustomer(customer)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving customer: \(error)")
                }
            }
        }
    }
}

#Preview {
    let customer = Customer(name: "张三", address: "北京市朝阳区", phone: "13800138000")
    
    CustomerDetailView(customer: customer)
        .modelContainer(for: Customer.self, inMemory: true)
}