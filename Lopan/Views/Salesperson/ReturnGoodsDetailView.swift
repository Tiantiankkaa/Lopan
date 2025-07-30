//
//  ReturnGoodsDetailView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct ReturnGoodsDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: CustomerOutOfStock
    
    @State private var showingReturnSheet = false
    @State private var showingProcessingAlert = false
    @State private var returnQuantity = ""
    @State private var returnNotes = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                returnStatusCard
                customerInfoCard
                productInfoCard
                returnHistoryCard
                actionButtons
            }
            .padding()
        }
        .navigationTitle("return_status".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReturnSheet) {
            SingleReturnProcessingSheet(
                item: item,
                onComplete: { quantity, notes in
                    processReturn(quantity: quantity, notes: notes)
                }
            )
        }
        .alert("return_confirmation".localized, isPresented: $showingProcessingAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("confirm".localized) {
                confirmReturn()
            }
        } message: {
            if let quantity = Int(returnQuantity) {
                Text("确定要处理 \(quantity) 件退货吗？".localized(with: quantity))
            }
        }
    }
    
    private var returnStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("return_status".localized)
                .font(.headline)
            
            HStack {
                Text(returnStatusText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(returnStatusColor)
                
                Spacer()
                
                if item.needsReturn {
                    Button(action: { showingReturnSheet = true }) {
                        Text("process_return".localized)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("原始数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(item.quantity)")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("returned_quantity".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(item.returnQuantity)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("remaining_quantity".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(item.remainingQuantity)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(item.remainingQuantity > 0 ? .orange : .green)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var customerInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("客户信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "客户姓名", value: item.customer?.name ?? "未知")
                InfoRow(label: "客户地址", value: item.customer?.address ?? "未知")
                InfoRow(label: "联系电话", value: item.customer?.phone ?? "未知")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var productInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "产品名称", value: item.product?.name ?? "未知")
                InfoRow(label: "产品规格", value: item.productDisplayName)
                InfoRow(label: "优先级", value: item.priority.displayName)
                InfoRow(label: "申请时间", value: item.requestDate.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var returnHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("退货历史")
                .font(.headline)
            
            if item.returnQuantity > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "已退数量", value: "\(item.returnQuantity)")
                    
                    if let returnDate = item.returnDate {
                        InfoRow(label: "return_date".localized, value: returnDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    if let returnNotes = item.returnNotes, !returnNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("return_notes".localized + ":")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(returnNotes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("暂无退货记录")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if item.needsReturn {
                Button(action: { showingReturnSheet = true }) {
                    HStack {
                        Image(systemName: "arrow.uturn.left")
                        Text("process_return".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
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
    
    private func processReturn(quantity: Int, notes: String?) {
        if item.processReturn(quantity: quantity, notes: notes) {
            // Log the return processing
            AuditingService.shared.logReturnProcessing(
                item: item,
                returnQuantity: quantity,
                returnNotes: notes,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                modelContext: modelContext
            )
            
            do {
                try modelContext.save()
            } catch {
                print("Error processing return: \(error)")
            }
        }
    }
    
    private func confirmReturn() {
        guard let quantity = Int(returnQuantity) else { return }
        processReturn(quantity: quantity, notes: returnNotes.isEmpty ? nil : returnNotes)
    }
    
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: CustomerOutOfStock.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Create sample data
    let customer = Customer(name: "测试客户", address: "测试地址", phone: "13800000000")
    let product = Product(name: "测试产品", colors: ["红色"])
    let item = CustomerOutOfStock(customer: customer, product: product, quantity: 50, createdBy: "demo")
    item.status = .confirmed
    
    return ReturnGoodsDetailView(item: item)
        .modelContainer(container)
}