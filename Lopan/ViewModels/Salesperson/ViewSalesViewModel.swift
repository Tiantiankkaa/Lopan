//
//  ViewSalesViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import Foundation
import SwiftUI

@MainActor
final class ViewSalesViewModel: ObservableObject {
    // MARK: - Nested Types

    struct AggregatedProduct: Identifiable, Equatable {
        let id: String // productId
        let productName: String
        var totalQuantity: Int
        var totalAmount: Decimal
        var sourceEntryIds: [String]
        var isExpanded: Bool = false

        static func == (lhs: AggregatedProduct, rhs: AggregatedProduct) -> Bool {
            lhs.id == rhs.id &&
            lhs.productName == rhs.productName &&
            lhs.totalQuantity == rhs.totalQuantity &&
            lhs.totalAmount == rhs.totalAmount &&
            lhs.sourceEntryIds == rhs.sourceEntryIds &&
            lhs.isExpanded == rhs.isExpanded
        }
    }

    struct EntryDetail: Identifiable, Equatable {
        let id: String
        let createdAt: Date
        let items: [SalesLineItem]
        let totalAmount: Decimal
    }

    // MARK: - Published State

    @Published var selectedDate: Date
    @Published private(set) var aggregatedProducts: [AggregatedProduct] = []
    @Published private(set) var salesEntries: [DailySalesEntry] = []
    @Published private(set) var totalSales: Decimal = 0
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isOffline = false
    @Published var errorMessage: String?
    @Published var showSuccessToast = false
    @Published var successMessage: String?
    @Published var expandedProductId: String?

    // MARK: - Dependencies

    private var salesRepository: SalesRepository?
    private var salesService: SalesService?
    private var authService: AuthenticationService?
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(date: Date = Date()) {
        self.selectedDate = date
        checkNetworkStatus()
    }

    // MARK: - Configuration

    func configure(dependencies: HasAppDependencies) {
        self.salesRepository = dependencies.salesRepository
        self.salesService = dependencies.salesService
        self.authService = dependencies.authenticationService
        loadSalesData()
    }

    // MARK: - Data Loading

    func loadSalesData() {
        guard let salesRepository = salesRepository,
              let authService = authService,
              let currentUser = authService.currentUser else {
            print("⚠️ ViewSalesViewModel: No repository or user available")
            return
        }

        Task {
            isLoading = true
            errorMessage = nil

            do {
                // Fetch sales entries for the selected date filtered by current salesperson
                let entries = try await salesRepository.fetchSalesEntries(
                    from: selectedDate,
                    to: selectedDate,
                    salespersonId: currentUser.id
                )

                print("📊 ViewSalesViewModel: Found \(entries.count) entries for date \(selectedDate)")
                entries.forEach { entry in
                    print("  ✅ Entry \(entry.id): \(entry.items?.count ?? 0) items, total: ₦\(entry.totalAmount)")
                }

                await MainActor.run {
                    self.salesEntries = entries
                    self.aggregateProducts()
                    self.calculateTotals()
                    isLoading = false
                }
            } catch {
                print("❌ ViewSalesViewModel: Error fetching sales: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func refreshData() async {
        guard let salesRepository = salesRepository,
              let authService = authService,
              let currentUser = authService.currentUser else { return }

        do {
            let entries = try await salesRepository.fetchSalesEntries(
                from: selectedDate,
                to: selectedDate,
                salespersonId: currentUser.id
            )

            await MainActor.run {
                self.salesEntries = entries
                self.aggregateProducts()
                self.calculateTotals()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Data Aggregation

    private func aggregateProducts() {
        var productMap: [String: AggregatedProduct] = [:]

        for entry in salesEntries {
            guard let items = entry.items else { continue }

            for item in items {
                if var existing = productMap[item.productId] {
                    // Update existing product
                    existing.totalQuantity += item.quantity
                    existing.totalAmount += item.subtotal
                    if !existing.sourceEntryIds.contains(entry.id) {
                        existing.sourceEntryIds.append(entry.id)
                    }
                    productMap[item.productId] = existing
                } else {
                    // Create new aggregated product
                    let aggregated = AggregatedProduct(
                        id: item.productId,
                        productName: item.productName,
                        totalQuantity: item.quantity,
                        totalAmount: item.subtotal,
                        sourceEntryIds: [entry.id],
                        isExpanded: false
                    )
                    productMap[item.productId] = aggregated
                }
            }
        }

        aggregatedProducts = Array(productMap.values).sorted { $0.productName < $1.productName }
    }

    private func calculateTotals() {
        totalSales = salesEntries.reduce(Decimal(0)) { $0 + $1.totalAmount }
        totalItems = salesEntries.reduce(0) { total, entry in
            total + (entry.items?.reduce(0) { $0 + $1.quantity } ?? 0)
        }
    }

    // MARK: - Entry Management

    func getEntriesForProduct(productId: String) -> [EntryDetail] {
        return salesEntries
            .filter { entry in
                entry.items?.contains { $0.productId == productId } ?? false
            }
            .map { entry in
                let items = entry.items?.filter { $0.productId == productId } ?? []
                let amount = items.reduce(Decimal(0)) { $0 + $1.subtotal }
                return EntryDetail(
                    id: entry.id,
                    createdAt: entry.createdAt,
                    items: items,
                    totalAmount: amount
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func toggleExpanded(productId: String) {
        if let index = aggregatedProducts.firstIndex(where: { $0.id == productId }) {
            aggregatedProducts[index].isExpanded.toggle()
            expandedProductId = aggregatedProducts[index].isExpanded ? productId : nil
        }
    }

    // MARK: - Delete Operations

    func deleteSalesEntry(id: String) async -> Bool {
        guard let salesService = salesService,
              let authService = authService,
              let currentUser = authService.currentUser else {
            errorMessage = NSLocalizedString("view_sales_error_no_user", comment: "")
            return false
        }

        do {
            try await salesService.deleteSalesEntry(id: id, deletedBy: currentUser.id)

            await MainActor.run {
                self.successMessage = NSLocalizedString("view_sales_delete_success", comment: "")
                self.showSuccessToast = true
            }

            // Refresh data after deletion
            await refreshData()

            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Date Management

    func changeDate(to newDate: Date) {
        selectedDate = newDate
        loadSalesData()
    }

    func navigateToToday() {
        selectedDate = Date()
        loadSalesData()
    }

    func navigateToYesterday() {
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
            selectedDate = yesterday
            loadSalesData()
        }
    }

    func navigateToPreviousDay() {
        if let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = previousDay
            loadSalesData()
        }
    }

    func navigateToNextDay() {
        let today = calendar.startOfDay(for: Date())
        let currentSelectedDay = calendar.startOfDay(for: selectedDate)

        // Only allow navigation if not already at today
        if currentSelectedDay < today {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                selectedDate = nextDay
                loadSalesData()
            }
        }
    }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var isYesterday: Bool {
        calendar.isDateInYesterday(selectedDate)
    }

    var canNavigateForward: Bool {
        let today = calendar.startOfDay(for: Date())
        let currentSelectedDay = calendar.startOfDay(for: selectedDate)
        return currentSelectedDay < today
    }

    // MARK: - Network Status

    private func checkNetworkStatus() {
        // Simple network check - in production, use NWPathMonitor
        isOffline = !isNetworkAvailable()
    }

    private func isNetworkAvailable() -> Bool {
        // Placeholder - in production, implement proper network monitoring
        return true
    }

    // MARK: - Formatting Helpers

    func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    // MARK: - Computed Properties

    var isEmpty: Bool {
        salesEntries.isEmpty
    }

    var hasData: Bool {
        !salesEntries.isEmpty
    }
}
