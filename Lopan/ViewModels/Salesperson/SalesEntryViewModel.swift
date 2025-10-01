//
//  SalesEntryViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import Foundation
import SwiftUI

@MainActor
final class SalesEntryViewModel: ObservableObject {
    // MARK: - Nested Types

    struct LineItemData: Identifiable, Equatable {
        let id: UUID
        var productId: String
        var productName: String
        var quantity: Int
        var unitPrice: Decimal

        var subtotal: Decimal {
            Decimal(quantity) * unitPrice
        }

        init(id: UUID = UUID(), productId: String = "", productName: String = "", quantity: Int = 1, unitPrice: Decimal = 0) {
            self.id = id
            self.productId = productId
            self.productName = productName
            self.quantity = quantity
            self.unitPrice = unitPrice
        }
    }

    // MARK: - Published State

    @Published var selectedDate: Date
    @Published var lineItems: [LineItemData] = []
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showSuccessToast = false

    // MARK: - Dependencies

    private var salesService: SalesService?
    private var productRepository: ProductRepository?
    private var authService: AuthenticationService?
    private let calendar = Calendar.current

    // MARK: - Computed Properties

    var totalAmount: Decimal {
        lineItems.reduce(Decimal(0)) { $0 + $1.subtotal }
    }

    var canSave: Bool {
        !lineItems.isEmpty &&
        lineItems.allSatisfy { !$0.productId.isEmpty && $0.quantity > 0 } &&
        !isSaving
    }

    // MARK: - Initialization

    init(date: Date = Date()) {
        self.selectedDate = date
        // Add initial empty line item
        self.lineItems = [LineItemData()]
    }

    // MARK: - Configuration

    func configure(dependencies: HasAppDependencies) {
        self.salesService = dependencies.salesService
        self.productRepository = dependencies.productRepository
        self.authService = dependencies.authenticationService
        loadProducts()
    }

    // MARK: - Data Loading

    func loadProducts() {
        guard let productRepository = productRepository else { return }

        Task {
            isLoading = true
            errorMessage = nil

            do {
                let products = try await productRepository.fetchProducts()
                await MainActor.run {
                    self.availableProducts = products
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Line Item Management

    func addLineItem() {
        lineItems.append(LineItemData())
    }

    func removeLineItem(at index: Int) {
        guard index < lineItems.count else { return }
        lineItems.remove(at: index)

        // Ensure at least one line item exists
        if lineItems.isEmpty {
            lineItems.append(LineItemData())
        }
    }

    func updateProduct(at index: Int, productId: String) {
        guard index < lineItems.count,
              let product = availableProducts.first(where: { $0.id == productId }) else {
            return
        }

        lineItems[index].productId = productId
        lineItems[index].productName = product.name
        // Note: In a real implementation, you'd fetch the current price from a price list
        // For now, we'll keep the existing price or set a default
    }

    func updateQuantity(at index: Int, quantity: Int) {
        guard index < lineItems.count else { return }
        lineItems[index].quantity = max(1, quantity)
    }

    func updateUnitPrice(at index: Int, price: Decimal) {
        guard index < lineItems.count else { return }
        lineItems[index].unitPrice = max(0, price)
    }

    // MARK: - Save Operations

    func saveSalesEntry() async -> Bool {
        guard let salesService = salesService,
              let authService = authService,
              let currentUser = authService.currentUser else {
            errorMessage = NSLocalizedString("sales_entry_error_no_user", comment: "")
            return false
        }

        guard canSave else {
            errorMessage = NSLocalizedString("sales_entry_error_invalid_data", comment: "")
            return false
        }

        isSaving = true
        errorMessage = nil

        do {
            // DEBUG: Log current state before save
            print("🔍 SalesEntryViewModel: Pre-save state check")
            print("   Line items count: \(lineItems.count)")
            lineItems.enumerated().forEach { index, item in
                print("   [\(index)] ID: \(item.id)")
                print("       Product: \(item.productName) (ID: \(item.productId))")
                print("       Quantity: \(item.quantity), Price: ₦\(item.unitPrice)")
            }

            // CRITICAL FIX: Deduplicate line items by ID
            // This prevents duplicate UUID errors in SwiftData
            var uniqueItems: [UUID: LineItemData] = [:]
            for item in lineItems {
                if uniqueItems[item.id] != nil {
                    print("⚠️ WARNING: Duplicate line item detected and removed: \(item.id)")
                }
                uniqueItems[item.id] = item
            }

            let deduplicatedItems = Array(uniqueItems.values)
            print("✅ Deduplicated: \(lineItems.count) → \(deduplicatedItems.count) items")

            // Create sales line items from deduplicated data
            let salesLineItems = deduplicatedItems.map { item in
                SalesLineItem(
                    productId: item.productId,
                    productName: item.productName,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice
                )
            }

            // Create sales entry
            let salesEntry = DailySalesEntry(
                date: selectedDate,
                salespersonId: currentUser.id,
                items: salesLineItems
            )

            // DEBUG: Verify item count after creation
            print("🔍 Created DailySalesEntry:")
            print("   Entry ID: \(salesEntry.id)")
            print("   Items in entry: \(salesEntry.items?.count ?? 0)")
            print("   Expected items: \(salesLineItems.count)")

            // CRITICAL FIX: DO NOT manually set bidirectional relationship!
            // The @Relationship(inverse:) macro handles this automatically.
            // Manual assignment causes SwiftData to DUPLICATE items in the array.
            //
            // REMOVED: salesLineItems.forEach { $0.salesEntry = salesEntry }
            //
            // Let @Relationship handle bidirectional sync automatically.

            // Save via service
            try await salesService.saveSalesEntry(salesEntry, createdBy: currentUser.id)

            await MainActor.run {
                self.isSaving = false
                self.showSuccessToast = true
                // Reset form
                self.lineItems = [LineItemData()]
                self.selectedDate = Date()
            }

            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isSaving = false
            }
            return false
        }
    }

    func saveAsDraft() async -> Bool {
        // TODO: Implement draft functionality in future
        // For now, just show a message
        errorMessage = NSLocalizedString("sales_entry_draft_not_implemented", comment: "Draft functionality coming soon")
        return false
    }

    // MARK: - Validation

    func validateEntry() -> String? {
        guard !lineItems.isEmpty else {
            return NSLocalizedString("sales_entry_error_no_items", comment: "")
        }

        for (index, item) in lineItems.enumerated() {
            if item.productId.isEmpty {
                return String(format: NSLocalizedString("sales_entry_error_no_product", comment: ""), index + 1)
            }

            if item.quantity <= 0 {
                return String(format: NSLocalizedString("sales_entry_error_invalid_quantity", comment: ""), item.productName)
            }

            if item.unitPrice <= 0 {
                return String(format: NSLocalizedString("sales_entry_error_invalid_price", comment: ""), item.productName)
            }
        }

        let futureDate = calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: Date())
        if futureDate {
            return NSLocalizedString("sales_entry_error_future_date", comment: "")
        }

        return nil
    }
}
