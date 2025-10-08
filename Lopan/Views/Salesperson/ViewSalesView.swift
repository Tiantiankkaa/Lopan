//
//  ViewSalesView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import SwiftUI

// MARK: - Lemon Green Theme Colors

extension Color {
    static let lemonGreen = Color(hex: "39B54A") ?? Color.green
    static let lemonGreenLight = Color(hex: "F0FEEA") ?? Color.green.opacity(0.1)
    static let lemonGreenBright = Color(hex: "AEF359") ?? Color.green
    static let lemonGreenDark = Color(hex: "8CC63F") ?? Color.green
}

struct ViewSalesView: View {
    @Environment(\.appDependencies) private var appDependencies
    @StateObject private var viewModel = ViewSalesViewModel()
    @StateObject private var toastManager = EnhancedToastManager()
    @State private var productToDelete: String?
    @State private var showDeleteConfirmation = false
    @State private var dateTransitionDirection: TransitionDirection = .forward

    // MARK: - Transition Direction

    enum TransitionDirection {
        case forward, backward

        var slideTransition: AnyTransition {
            switch self {
            case .forward:
                return .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
            case .backward:
                return .asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                )
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea()

            if viewModel.isInitialLoad && viewModel.isLoading {
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
        .alert("Delete Product Sales", isPresented: $showDeleteConfirmation, presenting: productToDelete) { productId in
            Button("Cancel", role: .cancel) {
                productToDelete = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteProductSales(productId: productId)
                    productToDelete = nil
                }
            }
        } message: { _ in
            Text("Are you sure you want to delete all sales entries for this product? This action cannot be undone.")
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
        HStack(spacing: LopanSpacing.md) {
            // Previous Day Button
            Button(action: {
                LopanHapticEngine.shared.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dateTransitionDirection = .backward
                    viewModel.navigateToPreviousDay()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(LopanColors.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.isLoading)

            // Date Display with loading indicator
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(formatDateLong(viewModel.selectedDate))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIColor.label))
                        .id(viewModel.selectedDate)
                        .transition(dateTransitionDirection.slideTransition)

                    if viewModel.isToday {
                        Text("Today")
                            .font(.footnote)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedDate)

            // Next Day Button
            Button(action: {
                LopanHapticEngine.shared.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dateTransitionDirection = .forward
                    viewModel.navigateToNextDay()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(viewModel.canNavigateForward ? LopanColors.primary : Color(UIColor.quaternaryLabel))
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canNavigateForward || viewModel.isLoading)
        }
        .padding(.horizontal, LopanSpacing.md)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        )
    }

    // Helper function to format date like "Thursday, July 25"
    private func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    // MARK: - Sorting Helpers

    private func sortIcon(for field: ViewSalesViewModel.SalesSortField) -> String {
        guard viewModel.sortField == field else {
            return "arrow.up.arrow.down"
        }
        return viewModel.sortDirection == .ascending ? "chevron.up" : "chevron.down"
    }

    private func sortColor(for field: ViewSalesViewModel.SalesSortField) -> Color {
        viewModel.sortField == field ? LopanColors.primary : Color(UIColor.secondaryLabel)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: LopanSpacing.md) {
            // Total Sales Card
            VStack(alignment: .leading, spacing: 12) {
                // Icon badge + Label
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lemonGreen)

                    Text("TOTAL SALES")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.lemonGreen)
                }

                // Animated value
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("₦")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(UIColor.label))

                    EnhancedAnimatedNumber(
                        value: safeDouble(viewModel.totalSales),
                        format: .number.precision(.fractionLength(2)),
                        font: .system(size: 20, weight: .bold, design: .rounded),
                        foregroundColor: Color(UIColor.label)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.lemonGreenLight)
            .cornerRadius(12)

            // Products Sold Card
            VStack(alignment: .leading, spacing: 12) {
                // Icon badge + Label
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lemonGreen)

                    Text("PRODUCTS SOLD")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.lemonGreen)
                }

                // Animated value
                EnhancedAnimatedInteger(
                    value: max(0, viewModel.totalItems),
                    font: .system(size: 20, weight: .bold, design: .rounded),
                    foregroundColor: Color(UIColor.label)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.lemonGreenLight)
            .cornerRadius(12)
        }
    }

    // MARK: - Helper Methods

    /// Safely converts Decimal to Double, returning 0.0 for invalid values
    private func safeDouble(_ decimal: Decimal) -> Double {
        let number = NSDecimalNumber(decimal: decimal)
        let double = number.doubleValue

        // Check for NaN, Infinity, or extremely large values
        guard double.isFinite, abs(double) < Double.greatestFiniteMagnitude else {
            print("⚠️ [ViewSales] Invalid decimal value: \(decimal), using 0.0")
            return 0.0
        }

        return double
    }

    // MARK: - Sales List Section

    private var salesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Title
            Text("Today's Sales")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(UIColor.label))

            Group {
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
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Table Layout
                    VStack(spacing: 0) {
                        // Table Header
                        HStack(spacing: 0) {
                            Button(action: {
                                LopanHapticEngine.shared.light()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.setSortField(.productName)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Product")
                                    Image(systemName: sortIcon(for: .productName))
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .font(.system(size: 12, weight: viewModel.sortField == .productName ? .bold : .semibold))
                                .foregroundColor(sortColor(for: .productName))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: {
                                LopanHapticEngine.shared.light()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.setSortField(.quantity)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Qty")
                                    Image(systemName: sortIcon(for: .quantity))
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .font(.system(size: 12, weight: viewModel.sortField == .quantity ? .bold : .semibold))
                                .foregroundColor(sortColor(for: .quantity))
                                .frame(width: 80, alignment: .center)
                            }

                            Button(action: {
                                LopanHapticEngine.shared.light()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.setSortField(.amount)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Amount")
                                    Image(systemName: sortIcon(for: .amount))
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .font(.system(size: 12, weight: viewModel.sortField == .amount ? .bold : .semibold))
                                .foregroundColor(sortColor(for: .amount))
                                .frame(width: 120, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12, corners: [.topLeft, .topRight])

                        // Table Rows
                        ForEach(Array(viewModel.paginatedProducts.enumerated()), id: \.element.id) { index, product in
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    Text(product.productName)
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(UIColor.label))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)

                                    Text("\(product.totalQuantity)")
                                        .font(.system(size: 15))
                                        .monospacedDigit()
                                        .foregroundColor(Color(UIColor.label))
                                        .frame(width: 80, alignment: .center)

                                    Text("₦\(viewModel.formatCurrency(product.totalAmount))")
                                        .font(.system(size: 15, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(.lemonGreen)
                                        .frame(width: 120, alignment: .trailing)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        productToDelete = product.id
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                                if index < viewModel.paginatedProducts.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }

                        // Bottom corner radius
                        Rectangle()
                            .fill(Color.white)
                            .frame(height: 12)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.sortField)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.sortDirection)

                    // Centered Pagination (outside the table card)
                    if viewModel.totalPages > 1 {
                        centeredPagination
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isEmpty)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.aggregatedProducts.count)
        }
    }

    // MARK: - Centered Pagination

    private var centeredPagination: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.navigateToPreviousPage()
                    LopanHapticEngine.shared.light()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canNavigateToPreviousPage ? .lemonGreen : Color(UIColor.quaternaryLabel))
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canNavigateToPreviousPage)

            Text("\(viewModel.pageStartIndex) - \(viewModel.pageEndIndex) of \(viewModel.totalProductCount)")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.horizontal, 12)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.navigateToNextPage()
                    LopanHapticEngine.shared.light()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canNavigateToNextPage ? .lemonGreen : Color(UIColor.quaternaryLabel))
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canNavigateToNextPage)
        }
        .background(Color.white)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
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

    // MARK: - Skeleton Loading State

    private var loadingState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date selector skeleton
                LopanSkeletonView(
                    style: .rectangular(width: nil, height: 60),
                    accessibilityLabel: "Loading date selector"
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LopanSpacing.screenPadding)

                // Summary cards skeleton
                HStack(spacing: LopanSpacing.md) {
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 120, height: 14)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: 90, height: 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.lemonGreenLight.opacity(0.3))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 120, height: 14)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: 50, height: 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.lemonGreenLight.opacity(0.3))
                    .cornerRadius(12)
                }
                .padding(.horizontal, LopanSpacing.screenPadding)

                // Section title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 150, height: 20)
                    .padding(.horizontal, LopanSpacing.screenPadding)

                // Table skeleton
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 80, height: 12)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 30, height: 12)
                            .frame(width: 80, alignment: .center)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 60, height: 12)
                            .frame(width: 120, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Rows
                    ForEach(0..<5) { _ in
                        VStack(spacing: 0) {
                            Divider()

                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(UIColor.systemGray4))
                                    .frame(height: 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(UIColor.systemGray4))
                                    .frame(width: 20, height: 14)
                                    .frame(width: 80, alignment: .center)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(UIColor.systemGray4))
                                    .frame(width: 80, height: 14)
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, LopanSpacing.screenPadding)

                Spacer()
            }
            .padding(.vertical, LopanSpacing.md)
        }
        .redacted(reason: .placeholder)
        .shimmering()
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

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ViewSalesView()
    }
}
