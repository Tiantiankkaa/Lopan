//
//  ViewSalesView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import SwiftUI

struct ViewSalesView: View {
    @Environment(\.appDependencies) private var appDependencies
    @StateObject private var viewModel = ViewSalesViewModel()
    @StateObject private var toastManager = EnhancedToastManager()
    @State private var entryToDelete: String?
    @State private var showDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading {
                loadingState
            } else if viewModel.errorMessage != nil {
                errorState
            } else {
                contentView
            }
        }
        .navigationTitle("View Sales")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.configure(dependencies: appDependencies)
        }
        .refreshable {
            await viewModel.refreshData()
            toastManager.showSuccess(NSLocalizedString("view_sales_refresh_success", comment: ""))
        }
        .withToastFeedback(toastManager: toastManager)
        .onChange(of: viewModel.showSuccessToast) { showToast in
            if showToast, let message = viewModel.successMessage {
                toastManager.showSuccess(message)
            }
        }
        .onChange(of: viewModel.errorMessage) { errorMessage in
            if let error = errorMessage {
                toastManager.showError(error)
            }
        }
        .onChange(of: viewModel.selectedDate) { _ in
            viewModel.loadSalesData()
        }
        .alert("Delete Sales Entry", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entryId in
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSalesEntry(id: entryId)
                    entryToDelete = nil
                }
            }
        } message: { _ in
            Text("Are you sure you want to delete this sales entry? This action cannot be undone.")
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LopanSpacing.sectionSpacing) {
                // Offline Banner
                if viewModel.isOffline {
                    offlineBanner
                }

                // Date Selector
                dateSection

                // Sales Summary
                summarySection

                // Today's Sales List
                salesListSection
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.md)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            // Date Input Field
            HStack(spacing: LopanSpacing.md) {
                DatePicker(
                    "",
                    selection: $viewModel.selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: viewModel.selectedDate) { _, _ in
                    LopanHapticEngine.shared.light()
                }

                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            )
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: LopanSpacing.md) {
            // Total Sales Card
            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                Text("Total Sales")
                    .lopanHeadlineMedium()
                    .foregroundColor(Color(UIColor.secondaryLabel))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("₦")
                        .lopanTitleLarge()
                    Text(viewModel.formatCurrency(viewModel.totalSales))
                        .lopanTitleLarge()
                        .fontWeight(.bold)
                }
                .foregroundColor(Color(UIColor.label))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LopanSpacing.md)
            .background(Color.white)
            .cornerRadius(LopanCornerRadius.card)
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)

            // Total Items Card
            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                Text("Total Items")
                    .lopanHeadlineMedium()
                    .foregroundColor(Color(UIColor.secondaryLabel))

                Text("\(viewModel.totalItems)")
                    .lopanTitleLarge()
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIColor.label))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LopanSpacing.md)
            .background(Color.white)
            .cornerRadius(LopanCornerRadius.card)
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        }
    }

    // MARK: - Sales List Section

    private var salesListSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            Text("Today's Sales")
                .lopanTitleMedium()
                .padding(.horizontal, LopanSpacing.xs)
                .padding(.bottom, LopanSpacing.xxs)

            if viewModel.isEmpty {
                // Inline Empty State
                VStack(spacing: LopanSpacing.sm) {
                    Image(systemName: "cart.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color(UIColor.secondaryLabel))

                    Text(NSLocalizedString("view_sales_empty_title", comment: ""))
                        .lopanBodyMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .background(Color.white)
                .cornerRadius(LopanCornerRadius.card)
                .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            } else {
                // Sales List
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.aggregatedProducts.enumerated()), id: \.element.id) { index, product in
                        VStack(spacing: 0) {
                            productRow(for: product)

                            // Show entry details if expanded
                            if product.isExpanded {
                                entryDetailsView(for: product)
                            }

                            if index < viewModel.aggregatedProducts.count - 1 {
                                Divider()
                                    .padding(.leading, LopanSpacing.md)
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(LopanCornerRadius.card)
                .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            }
        }
    }

    private func productRow(for product: ViewSalesViewModel.AggregatedProduct) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.toggleExpanded(productId: product.id)
            }
        } label: {
            HStack(spacing: LopanSpacing.md) {
                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.productName)
                        .lopanHeadlineMedium()
                        .foregroundColor(Color(UIColor.label))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("₦\(viewModel.formatCurrency(product.totalAmount))")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }

                Spacer()

                // Quantity
                HStack(spacing: 4) {
                    Text("\(product.totalQuantity)")
                        .lopanHeadlineMedium()
                        .fontWeight(.semibold)
                    Text("units")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }

                // Expand/Collapse Icon
                Image(systemName: product.isExpanded ? "chevron.up" : "chevron.down")
                    .lopanLabelLarge()
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(LopanSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func entryDetailsView(for product: ViewSalesViewModel.AggregatedProduct) -> some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, LopanSpacing.md)

            VStack(spacing: LopanSpacing.xs) {
                Text("Source Entries")
                    .lopanLabelLarge()
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, LopanSpacing.md)
                    .padding(.top, LopanSpacing.sm)

                ForEach(viewModel.getEntriesForProduct(productId: product.id)) { entry in
                    entryDetailRow(for: entry)
                }
            }
            .padding(.bottom, LopanSpacing.sm)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func entryDetailRow(for entry: ViewSalesViewModel.EntryDetail) -> some View {
        HStack(spacing: LopanSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formatTime(entry.createdAt))
                    .lopanBodyMedium()
                    .foregroundColor(Color(UIColor.label))

                ForEach(entry.items, id: \.id) { item in
                    Text("\(item.quantity) × ₦\(viewModel.formatCurrency(item.unitPrice))")
                        .lopanLabelMedium()
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }

            Spacer()

            Text("₦\(viewModel.formatCurrency(entry.totalAmount))")
                .lopanBodyMedium()
                .fontWeight(.medium)
                .foregroundColor(Color(UIColor.label))

            // Delete Button
            Button(action: {
                entryToDelete = entry.id
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash.circle.fill")
                    .lopanHeadlineMedium()
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, LopanSpacing.md)
        .padding(.vertical, LopanSpacing.xs)
        .background(Color.white)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                entryToDelete = entry.id
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: "wifi.slash")
                .lopanBodyLarge()
            Text("You're offline. Sales data might be outdated.")
                .lopanLabelMedium()
        }
        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.0))
        .padding(LopanSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color(red: 1.0, green: 0.95, blue: 0.8))
        .cornerRadius(LopanCornerRadius.card)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: LopanSpacing.sectionSpacing) {
            // Skeleton for date picker
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(Color(UIColor.systemGray5))
                .frame(height: 120)
                .padding(.horizontal, LopanSpacing.screenPadding)

            // Skeleton for summary cards
            HStack(spacing: LopanSpacing.md) {
                RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                    .fill(Color(UIColor.systemGray5))
                    .frame(height: 100)

                RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                    .fill(Color(UIColor.systemGray5))
                    .frame(height: 100)
            }
            .padding(.horizontal, LopanSpacing.screenPadding)

            // Skeleton for list
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(Color(UIColor.systemGray5))
                .frame(height: 200)
                .padding(.horizontal, LopanSpacing.screenPadding)

            Spacer()
        }
        .padding(.top, LopanSpacing.sectionSpacing)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LopanSpacing.lg) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(Color(UIColor.systemGray3))

            Text("No Sales on This Date")
                .lopanTitleLarge()
                .foregroundColor(Color(UIColor.label))

            Text("There were no sales recorded for the selected date. Try another day.")
                .lopanBodyMedium()
                .foregroundColor(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, LopanSpacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: LopanSpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Couldn't Load Sales")
                .lopanTitleLarge()
                .foregroundColor(Color(UIColor.label))

            if let error = viewModel.errorMessage {
                Text(error)
                    .lopanBodyMedium()
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LopanSpacing.xxl)
            }

            Button(action: { viewModel.loadSalesData() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .lopanHeadlineMedium()
                .padding(.horizontal, LopanSpacing.xl)
                .padding(.vertical, LopanSpacing.sm)
                .background(LopanColors.primary)
                .foregroundColor(.white)
                .cornerRadius(LopanCornerRadius.card)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ViewSalesView()
    }
}
