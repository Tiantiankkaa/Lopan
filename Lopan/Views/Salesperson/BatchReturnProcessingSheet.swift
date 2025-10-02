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
    
    @State private var deliveryQuantities: [String: String] = [:]
    @State private var deliveryNotes: [String: String] = [:]
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationStack {
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
                .foregroundColor(LopanColors.textSecondary)
            
            Divider()
        }
        .padding()
    }
    
    private var itemsList: some View {
        LopanLazyList(
            data: items,
            configuration: LopanLazyList.Configuration(
                isLoading: false,
                spacing: LopanSpacing.sm,
                accessibilityLabel: "还货处理列表"
            ),
            content: { item in
                ReturnItemInputRow(
                    item: item,
                    deliveryQuantity: Binding(
                        get: { deliveryQuantities[item.id] ?? "" },
                        set: { deliveryQuantities[item.id] = $0 }
                    ),
                    deliveryNotes: Binding(
                        get: { deliveryNotes[item.id] ?? "" },
                        set: { deliveryNotes[item.id] = $0 }
                    )
                )
            },
            skeletonContent: {
                ReturnItemSkeletonRow()
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
            value: items.count
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { fillMaxQuantities() }) {
                Text("填充最大还货数量")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LopanColors.info.opacity(0.1))
                    .foregroundColor(LopanColors.info)
                    .cornerRadius(8)
            }
            
            Button(action: { showingConfirmation = true }) {
                Text("process_return".localized)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidInput ? LopanColors.success : LopanColors.secondary)
                    .foregroundColor(LopanColors.textOnPrimary)
                    .cornerRadius(8)
            }
            .disabled(!isValidInput)
        }
        .padding()
    }
    
    private var isValidInput: Bool {
        for item in items {
            guard let quantityStr = deliveryQuantities[item.id],
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
            deliveryQuantities[item.id] = String(item.remainingQuantity)
            deliveryNotes[item.id] = ""
        }
    }

    private func fillMaxQuantities() {
        for item in items {
            deliveryQuantities[item.id] = String(item.remainingQuantity)
        }
    }
    
    private func processBatchReturn() {
        var processedItems: [(CustomerOutOfStock, Int, String?)] = []

        for item in items {
            guard let quantityStr = deliveryQuantities[item.id],
                  let quantity = Int(quantityStr),
                  quantity > 0 else { continue }

            let notes = deliveryNotes[item.id]?.isEmpty == false ? deliveryNotes[item.id] : nil
            processedItems.append((item, quantity, notes))
        }

        onComplete(processedItems)
        dismiss()
    }
}

struct ReturnItemInputRow: View {
    let item: CustomerOutOfStock
    @Binding var deliveryQuantity: String
    @Binding var deliveryNotes: String
    
    @State private var showingError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            customerAndProductInfo
            quantityInputSection
            notesInputSection
            
            if showingError {
                Text("invalid_return_quantity".localized)
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
            }
        }
        .padding(.vertical, 8)
        .onChange(of: deliveryQuantity) { _, newValue in
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
                    .background(LopanColors.info.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(item.productDisplayName)
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
            
            HStack {
                Text("剩余数量: \(item.remainingQuantity)")
                    .font(.caption)
                    .foregroundColor(LopanColors.warning)
                
                if item.hasPartialDelivery {
                    Text("已还货: \(item.deliveryQuantity)")
                        .font(.caption)
                        .foregroundColor(LopanColors.info)
                }
            }
        }
    }
    
    private var quantityInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LopanTextField(
                title: "delivery_quantity".localized,
                placeholder: "最多: \(item.remainingQuantity)",
                text: $deliveryQuantity,
                variant: .outline,
                state: showingError ? .error : .normal,
                keyboardType: .numberPad,
                icon: "number",
                helperText: "请输入要还货的数量",
                errorText: showingError ? "请输入有效的还货数量（1-\(item.remainingQuantity)）" : nil
            )
        }
    }

    private var notesInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LopanTextField(
                title: "delivery_notes".localized,
                placeholder: "可选择填写还货原因或备注",
                text: $deliveryNotes,
                variant: .outline,
                icon: "note.text",
                helperText: "还货备注为可选信息"
            )
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

// MARK: - Return Item Skeleton Row
struct ReturnItemSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Customer and product info skeleton
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Rectangle()
                        .fill(LopanColors.secondaryLight)
                        .frame(height: 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .shimmering()

                    Rectangle()
                        .fill(LopanColors.secondaryLight)
                        .frame(width: 60, height: 16)
                        .shimmering()
                }

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmering()

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(width: 120, height: 12)
                    .shimmering()
            }

            // Input fields skeleton
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 40)
                    .shimmering()

                Rectangle()
                    .fill(LopanColors.secondaryLight)
                    .frame(height: 40)
                    .shimmering()
            }
        }
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}
