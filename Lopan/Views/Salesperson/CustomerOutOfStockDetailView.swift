//
//  CustomerOutOfStockDetailView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import SwiftUI
import SwiftData

struct CustomerOutOfStockDetailView: View {
    let item: CustomerOutOfStock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isUpdatingStatus = false
    
    private var customerOutOfStockService: CustomerOutOfStockService {
        appDependencies.serviceFactory.customerOutOfStockService
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Info Card
                customerInfoCard
                
                // Product Info Card  
                productInfoCard
                
                // Order Details Card (like the screenshot table)
                orderDetailsCard
                
                // Status and Actions Card
                statusActionsCard
                
                // Notes Card (if available)
                if let notes = item.userVisibleNotes, !notes.isEmpty {
                    notesCard(notes)
                }
                
                // Return Info Card (if applicable)
                if item.status == .refunded && item.deliveryQuantity > 0 {
                    returnInfoCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("缺货详情")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("编辑记录", systemImage: "pencil")
                    }
                    .disabled(item.status == .completed)
                    
                    if item.status == .pending {
                        Button(action: { updateStatus(to: .completed) }) {
                            Label("标记为已完成", systemImage: "checkmark.circle")
                        }
                        .disabled(isUpdatingStatus)
                        
                        Button(action: { updateStatus(to: .refunded) }) {
                            Label("标记为已退货", systemImage: "return.left")
                        }
                        .disabled(isUpdatingStatus)
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("删除记录", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            // Edit sheet would go here - placeholder for now
            NavigationStack {
                Text("编辑功能待实现")
                    .navigationTitle("编辑记录")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("取消") { showingEditSheet = false }
                        }
                    }
            }
        }
        .alert("删除确认", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("确定要删除这条缺货记录吗？此操作不可撤销。")
        }
    }
    
    // MARK: - UI Components
    
    private var customerInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(LopanColors.info)
                    .font(.title2)
                
                Text("客户信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                OutOfStockInfoRow(
                    icon: "person",
                    label: "客户姓名",
                    value: item.customerDisplayName
                )
                
                OutOfStockInfoRow(
                    icon: "location",
                    label: "联系地址",
                    value: item.customerAddress
                )
                
                OutOfStockInfoRow(
                    icon: "phone",
                    label: "联系电话", 
                    value: item.customerPhone
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var productInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(LopanColors.warning)
                    .font(.title2)
                
                Text("产品信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                OutOfStockInfoRow(
                    icon: "tag",
                    label: "产品名称",
                    value: item.productDisplayName
                )
                
                OutOfStockInfoRow(
                    icon: "number",
                    label: "缺货数量",
                    value: "\(item.quantity)"
                )
                
                if let product = item.product, !product.colors.isEmpty {
                    OutOfStockInfoRow(
                        icon: "paintpalette",
                        label: "产品颜色",
                        value: product.colors.joined(separator: ", ")
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var orderDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(LopanColors.success)
                    .font(.title2)
                
                Text("订单详情")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Table-like layout similar to the screenshot
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("项目")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("数量")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 60, alignment: .center)
                    
                    Text("状态")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 80, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(LopanColors.backgroundTertiary)
                
                Divider()
                
                // Data row
                HStack {
                    Text(item.productDisplayName)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                    
                    Text("\(item.quantity)")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 60, alignment: .center)
                    
                    statusBadge
                        .frame(width: 80, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(LopanColors.background)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LopanColors.secondary, lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var statusActionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(LopanColors.premium)
                    .font(.title2)
                
                Text("状态和时间")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                OutOfStockInfoRow(
                    icon: "calendar",
                    label: "请求时间",
                    value: DateFormatter.detailViewFormatter.string(from: item.requestDate)
                )
                
                OutOfStockInfoRow(
                    icon: "flag",
                    label: "当前状态",
                    value: item.status.displayName
                )
                
                if let completionDate = item.actualCompletionDate {
                    OutOfStockInfoRow(
                        icon: "checkmark.circle",
                        label: "完成时间",
                        value: DateFormatter.detailViewFormatter.string(from: completionDate)
                    )
                }
                
                OutOfStockInfoRow(
                    icon: "person.badge.key",
                    label: "创建人",
                    value: item.createdBy
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(LopanColors.primary)
                    .font(.title2)
                
                Text("备注")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(notes)
                .font(.body)
                .foregroundColor(.primary)
                .padding(12)
                .background(LopanColors.backgroundTertiary)
                .cornerRadius(8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var returnInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "return.left")
                    .foregroundColor(LopanColors.error)
                    .font(.title2)
                
                Text("退货信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                OutOfStockInfoRow(
                    icon: "minus.circle",
                    label: "退货数量",
                    value: "\(item.deliveryQuantity)"
                )
                
                if let returnDate = item.deliveryDate {
                    OutOfStockInfoRow(
                        icon: "calendar.badge.minus",
                        label: "退货时间",
                        value: DateFormatter.detailViewFormatter.string(from: returnDate)
                    )
                }
                
                if let returnNotes = item.deliveryNotes, !returnNotes.isEmpty {
                    OutOfStockInfoRow(
                        icon: "note.text",
                        label: "退货备注",
                        value: returnNotes
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(item.status.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending:
            return LopanColors.warning
        case .completed:
            return LopanColors.success
        case .refunded:
            return LopanColors.error
        }
    }
    
    // MARK: - Actions
    
    private func updateStatus(to newStatus: OutOfStockStatus) {
        isUpdatingStatus = true
        
        Task {
            do {
                // Update the status directly on the item
                await MainActor.run {
                    item.status = newStatus
                    if newStatus == .completed {
                        item.actualCompletionDate = Date()
                    }
                    item.updatedAt = Date()
                }
                
                // Update the item through the service
                try await customerOutOfStockService.updateOutOfStockItem(
                    item,
                    customer: item.customer,
                    product: item.product,
                    productSize: item.productSize,
                    quantity: item.quantity,
                    notes: item.notes
                )
                
                await MainActor.run {
                    isUpdatingStatus = false
                    // The item will be updated automatically through the service
                }
            } catch {
                await MainActor.run {
                    isUpdatingStatus = false
                    // Handle error - could show an alert
                    print("❌ Error updating status: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteItem() {
        Task {
            do {
                try await customerOutOfStockService.deleteOutOfStockItem(item)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error deleting item: \(error.localizedDescription)")
                // Handle error - could show an alert
            }
        }
    }
}

// MARK: - Supporting Views

private struct OutOfStockInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 14))
                .frame(width: 20, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let detailViewFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CustomerOutOfStock.self, configurations: config)
    let context = ModelContext(container)
    
    // Create sample data
    let customer = Customer(name: "张三", address: "北京市朝阳区", phone: "13800138000")
    let product = Product(name: "测试产品", colors: ["红色", "蓝色"], imageData: nil)
    let outOfStockItem = CustomerOutOfStock(
        customer: customer,
        product: product,
        quantity: 10,
        notes: "急需补货",
        createdBy: "sales001"
    )
    
    NavigationStack {
        CustomerOutOfStockDetailView(item: outOfStockItem)
            .environmentObject(ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: context)))
    }
}
