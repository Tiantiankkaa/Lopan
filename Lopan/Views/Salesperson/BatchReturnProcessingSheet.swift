//
//  BatchReturnProcessingSheet.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct BatchReturnProcessingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [CustomerOutOfStock]
    let onComplete: ([(CustomerOutOfStock, Int, String?)]) -> Void
    
    @State private var returnQuantities: [String: String] = [:]
    @State private var returnNotes: [String: String] = [:]
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                headerSection
                itemsList
                actionButtons
            }
            .navigationTitle("batch_return".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("return_confirmation".localized, isPresented: $showingConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("confirm".localized) {
                    processBatchReturn()
                }
            } message: {
                Text("确定要处理这 \(items.count) 个还货记录吗？".localized(with: items.count))
            }
        }
        .onAppear {
            initializeQuantities()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("return_processing".localized)
                .font(.headline)
            
            Text("已选择 \(items.count) 个需要还货的记录".localized(with: items.count))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
        }
        .padding()
    }
    
    private var itemsList: some View {
        List {
            ForEach(items, id: \.id) { item in
                ReturnItemInputRow(
                    item: item,
                    returnQuantity: Binding(
                        get: { returnQuantities[item.id] ?? "" },
                        set: { returnQuantities[item.id] = $0 }
                    ),
                    returnNotes: Binding(
                        get: { returnNotes[item.id] ?? "" },
                        set: { returnNotes[item.id] = $0 }
                    )
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { fillMaxQuantities() }) {
                Text("填充最大还货数量")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            Button(action: { showingConfirmation = true }) {
                Text("process_return".localized)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidInput ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!isValidInput)
        }
        .padding()
    }
    
    private var isValidInput: Bool {
        for item in items {
            guard let quantityStr = returnQuantities[item.id],
                  let quantity = Int(quantityStr),
                  quantity > 0,
                  quantity <= item.remainingQuantity else {
                return false
            }
        }
        return true
    }
    
    private func initializeQuantities() {
        for item in items {
            returnQuantities[item.id] = String(item.remainingQuantity)
            returnNotes[item.id] = ""
        }
    }
    
    private func fillMaxQuantities() {
        for item in items {
            returnQuantities[item.id] = String(item.remainingQuantity)
        }
    }
    
    private func processBatchReturn() {
        var processedItems: [(CustomerOutOfStock, Int, String?)] = []
        
        for item in items {
            guard let quantityStr = returnQuantities[item.id],
                  let quantity = Int(quantityStr),
                  quantity > 0 else { continue }
            
            let notes = returnNotes[item.id]?.isEmpty == false ? returnNotes[item.id] : nil
            processedItems.append((item, quantity, notes))
        }
        
        onComplete(processedItems)
        dismiss()
    }
}

struct ReturnItemInputRow: View {
    let item: CustomerOutOfStock
    @Binding var returnQuantity: String
    @Binding var returnNotes: String
    
    @State private var showingError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            customerAndProductInfo
            quantityInputSection
            notesInputSection
            
            if showingError {
                Text("invalid_return_quantity".localized)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .onChange(of: returnQuantity) { _, newValue in
            validateQuantity(newValue)
        }
    }
    
    private var customerAndProductInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.customerDisplayName)
                    .font(.headline)
                Spacer()
                Text(item.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(item.productDisplayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("剩余数量: \(item.remainingQuantity)")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                if item.hasPartialReturn {
                    Text("已还: \(item.returnQuantity)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var quantityInputSection: some View {
        HStack {
            Text("return_quantity".localized + ":")
                .font(.subheadline)
            
            Spacer()
            
            TextField("max_return_quantity".localized + ": \(item.remainingQuantity)", text: $returnQuantity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .frame(width: 120)
                .multilineTextAlignment(.center)
        }
    }
    
    private var notesInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("return_notes".localized + ":")
                .font(.subheadline)
            
            TextField("可选择填写还货原因或备注", text: $returnNotes)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private func validateQuantity(_ quantityStr: String) {
        guard let quantity = Int(quantityStr) else {
            showingError = !quantityStr.isEmpty
            return
        }
        
        showingError = quantity <= 0 || quantity > item.remainingQuantity
    }
}

