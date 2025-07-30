//
//  SingleReturnProcessingSheet.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI

struct SingleReturnProcessingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: CustomerOutOfStock
    let onComplete: (Int, String?) -> Void
    
    @State private var returnQuantity = ""
    @State private var returnNotes = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                customerSection
                productSection
                quantitySection
                notesSection
            }
            .navigationTitle("return_processing".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("process_return".localized) {
                        showingConfirmation = true
                    }
                    .disabled(!isValidInput)
                }
            }
            .alert("return_confirmation".localized, isPresented: $showingConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("confirm".localized) {
                    processReturn()
                }
            } message: {
                if let quantity = Int(returnQuantity) {
                    Text("确定要处理 \(quantity) 件退货吗？".localized(with: quantity))
                }
            }
        }
        .onAppear {
            returnQuantity = String(item.remainingQuantity)
        }
    }
    
    private var customerSection: some View {
        Section("客户信息") {
            HStack {
                Text("客户姓名")
                Spacer()
                Text(item.customer?.name ?? "未知客户")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("客户地址")
                Spacer()
                Text(item.customer?.address ?? "未知地址")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var productSection: some View {
        Section("产品信息") {
            HStack {
                Text("产品名称")
                Spacer()
                Text(item.product?.name ?? "未知产品")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("产品规格")
                Spacer()
                Text(item.productDisplayName)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("原始数量")
                Spacer()
                Text("\(item.quantity)")
                    .foregroundColor(.secondary)
            }
            
            if item.hasPartialReturn {
                HStack {
                    Text("已退数量")
                    Spacer()
                    Text("\(item.returnQuantity)")
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                Text("remaining_quantity".localized)
                Spacer()
                Text("\(item.remainingQuantity)")
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var quantitySection: some View {
        Section(header: Text("return_quantity".localized)) {
            HStack {
                TextField("输入退货数量", text: $returnQuantity)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("最大值") {
                    returnQuantity = String(item.remainingQuantity)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if !isValidQuantity {
                Text("请输入有效的退货数量 (1-\(item.remainingQuantity))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Text("最大可退货数量: \(item.remainingQuantity)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var notesSection: some View {
        Section("return_notes".localized) {
            TextField("可选择填写退货原因或备注", text: $returnNotes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private var isValidQuantity: Bool {
        guard let quantity = Int(returnQuantity) else { return false }
        return quantity > 0 && quantity <= item.remainingQuantity
    }
    
    private var isValidInput: Bool {
        return isValidQuantity
    }
    
    private func processReturn() {
        guard let quantity = Int(returnQuantity) else { return }
        let notes = returnNotes.isEmpty ? nil : returnNotes
        onComplete(quantity, notes)
        dismiss()
    }
}

#Preview {
    let customer = Customer(name: "测试客户", address: "测试地址", phone: "13800000000")
    let product = Product(name: "测试产品", colors: ["红色"])
    let item = CustomerOutOfStock(customer: customer, product: product, quantity: 50, createdBy: "demo")
    item.status = .confirmed
    
    return SingleReturnProcessingSheet(item: item) { _, _ in }
}