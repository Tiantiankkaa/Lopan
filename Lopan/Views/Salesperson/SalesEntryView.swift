//
//  SalesEntryView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import SwiftUI

struct SalesEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies
    @StateObject private var viewModel: SalesEntryViewModel
    @StateObject private var toastManager = EnhancedToastManager()

    // MARK: - Initialization

    init(date: Date = Date()) {
        _viewModel = StateObject(wrappedValue: SalesEntryViewModel(date: date))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: LopanSpacing.sectionSpacing) {
                        // Date Section
                        dateSection

                        // Items Section
                        itemsSection

                        // Total Section
                        totalSection
                    }
                    .padding(.horizontal, LopanSpacing.screenPadding)
                    .padding(.vertical, LopanSpacing.md)
                }

                // Bottom action buttons
                bottomActionButtons
            }
        }
        .navigationTitle("Add Sales Entry")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.configure(dependencies: appDependencies)
        }
        .withToastFeedback(toastManager: toastManager)
        .onChange(of: viewModel.showSuccessToast) { _, showToast in
            if showToast {
                toastManager.showSuccess(NSLocalizedString("sales_entry_saved_success", comment: "Sales entry saved successfully"))
                // Dismiss after showing toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .onChange(of: viewModel.errorMessage) { _, errorMessage in
            if let error = errorMessage {
                toastManager.showError(error)
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            Text("Date")
                .lopanLabelLarge()
                .foregroundColor(Color(UIColor.secondaryLabel))

            DatePicker(
                "",
                selection: $viewModel.selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("Items")
                    .lopanTitleMedium()

                Spacer()

                Button(action: { viewModel.addLineItem() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .lopanHeadlineMedium()
                        Text("Add Row")
                            .lopanBodyLarge()
                    }
                    .foregroundColor(LopanColors.primary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(viewModel.lineItems.enumerated()), id: \.element.id) { index, item in
                    lineItemRow(for: item, at: index)

                    if index < viewModel.lineItems.count - 1 {
                        Divider()
                            .padding(.leading, LopanSpacing.md)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(LopanCornerRadius.card)
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        }
    }

    private func lineItemRow(for item: SalesEntryViewModel.LineItemData, at index: Int) -> some View {
        VStack(spacing: LopanSpacing.sm) {
            HStack(spacing: LopanSpacing.md) {
                // Product Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Product")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    Picker("Product", selection: Binding(
                        get: { item.productId },
                        set: { viewModel.updateProduct(at: index, productId: $0) }
                    )) {
                        Text("Select Product").tag("")
                        ForEach(viewModel.availableProducts, id: \.id) { product in
                            Text(product.name).tag(product.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)

                // Quantity Input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qty")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    TextField("0", value: Binding(
                        get: { item.quantity },
                        set: { viewModel.updateQuantity(at: index, quantity: $0) }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            }

            HStack {
                // Unit Price Input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit Price")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    HStack(spacing: 4) {
                        Text("₦")
                            .lopanBodyLarge()
                        TextField("0.00", value: Binding(
                            get: { item.unitPrice },
                            set: { viewModel.updateUnitPrice(at: index, price: $0) }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity)

                // Subtotal Display
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Subtotal")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    Text("₦\(formatCurrency(item.subtotal))")
                        .lopanBodyLarge()
                        .foregroundColor(Color(UIColor.label))
                        .frame(height: 36)
                }
            }

            // Delete Button
            if viewModel.lineItems.count > 1 {
                Button(action: { viewModel.removeLineItem(at: index) }) {
                    HStack {
                        Image(systemName: "trash")
                            .lopanLabelLarge()
                        Text("Remove")
                            .lopanLabelLarge()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(LopanSpacing.md)
    }

    // MARK: - Total Section

    private var totalSection: some View {
        HStack {
            Text("Total")
                .lopanHeadlineMedium()

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("₦")
                    .lopanHeadlineMedium()
                Text(formatCurrency(viewModel.totalAmount))
                    .lopanHeadlineLarge()
            }
            .foregroundColor(LopanColors.primary)
        }
        .padding(.vertical, LopanSpacing.md)
        .padding(.horizontal, LopanSpacing.lg)
        .background(Color.white)
        .cornerRadius(LopanCornerRadius.card)
        .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
    }

    // MARK: - Bottom Action Buttons

    private var bottomActionButtons: some View {
        VStack(spacing: LopanSpacing.sm) {
            Divider()

            HStack(spacing: LopanSpacing.md) {
                // Save Entry Button
                Button(action: {
                    Task {
                        await viewModel.saveSalesEntry()
                    }
                }) {
                    HStack {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Save Entry")
                                .lopanTitleMedium()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: LopanSpacing.buttonHeight)
                    .background(viewModel.canSave ? LopanColors.primary : LopanColors.primary.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(LopanCornerRadius.card)
                }
                .disabled(!viewModel.canSave)

                // Save as Draft Button
                Button(action: {
                    Task {
                        await viewModel.saveAsDraft()
                    }
                }) {
                    Text("Save as Draft")
                        .lopanTitleMedium()
                        .frame(maxWidth: .infinity)
                        .frame(height: LopanSpacing.buttonHeight)
                        .background(LopanColors.primary.opacity(0.2))
                        .foregroundColor(LopanColors.primary)
                        .cornerRadius(LopanCornerRadius.card)
                }
                .disabled(viewModel.isSaving)
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.bottom, LopanSpacing.md)
        }
        .background(Color.white)
    }

    // MARK: - Helper Methods

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Preview

#Preview {
    SalesEntryView()
}
