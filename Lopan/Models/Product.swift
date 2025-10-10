//
//  Product.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

@Model
public final class Product {
    public var id: String
    var sku: String // Unique SKU identifier (e.g., "PRD-000001")
    var name: String
    var imageData: Data? // Store image as Data (legacy, use imageDataArray instead)
    var imageDataArray: [Data] = [] // Multiple product images (max 3)
    var productDescription: String? // Product description
    var weight: Double? // Product weight in grams
    var price: Double // Product price
    var quantity: Int = 0 // Actual inventory quantity (independent from sizes)
    var sizes: [ProductSize]? // Relationship to sizes
    var manualInventoryStatus: Int? // Manual status override (using rawValue for SwiftData compatibility)
    var lowStockThreshold: Int? // Custom inventory quantity for low stock status
    var cachedInventoryStatus: Int = 0 // Cached inventory status for database queries
    var createdAt: Date
    var updatedAt: Date

    init(sku: String, name: String, imageData: Data? = nil, price: Double = 0.0, productDescription: String? = nil, weight: Double? = nil) {
        self.id = UUID().uuidString
        self.sku = sku
        self.name = name
        self.imageData = imageData
        self.imageDataArray = imageData != nil ? [imageData!] : []
        self.productDescription = productDescription
        self.weight = weight
        self.price = price
        self.quantity = 0 // Initialize inventory quantity
        self.sizes = []
        self.manualInventoryStatus = nil
        self.lowStockThreshold = nil
        self.cachedInventoryStatus = 0 // Will be updated after sizes are set
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Cache Management

    /// Updates the cached inventory status based on current inventory or manual override
    func updateCachedInventoryStatus() {
        // Use manual status if set
        if let manualStatusRaw = manualInventoryStatus,
           let manualStatus = InventoryStatus(rawValue: manualStatusRaw) {
            self.cachedInventoryStatus = manualStatus.rawValue
            return
        }

        // Otherwise compute from inventory quantity
        let quantity = inventoryQuantity
        if quantity == 0 {
            self.cachedInventoryStatus = InventoryStatus.inactive.rawValue
        } else if quantity < 10 {
            self.cachedInventoryStatus = InventoryStatus.lowStock.rawValue
        } else {
            self.cachedInventoryStatus = InventoryStatus.active.rawValue
        }
    }
    
    // Helper method to get all sizes as strings (sorted by sortIndex to preserve order)
    var sizeNames: [String] {
        return sizes?.sorted(by: { $0.sortIndex < $1.sortIndex }).map { $0.size } ?? []
    }
    
    // Helper method to get display name with sizes
    var displayName: String {
        let sizeList = sizeNames.joined(separator: ", ")
        return "\(name) (\(sizeList))"
    }

    // MARK: - Computed Properties for Product Management

    /// Total inventory quantity (stored independently from sizes)
    var inventoryQuantity: Int {
        return quantity
    }

    /// Formatted SKU (returns the stored unique SKU)
    var formattedSKU: String {
        return sku.uppercased()
    }

    /// Formatted price with currency symbol
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    /// Formatted weight with unit
    var formattedWeight: String {
        guard let weight = weight else { return "N/A" }
        if weight >= 1000 {
            return String(format: "%.1f kg", weight / 1000)
        }
        return String(format: "%.0f g", weight)
    }

    /// Primary image for display (first in array or legacy imageData)
    var primaryImageData: Data? {
        return imageDataArray.first ?? imageData
    }

    /// Inventory status based on cached value
    /// Note: Use updateCachedInventoryStatus() to refresh cache when inventory changes
    var inventoryStatus: InventoryStatus {
        return InventoryStatus(rawValue: cachedInventoryStatus) ?? .inactive
    }

    // MARK: - Inventory Status Enum

    /// Represents the inventory status of a product
    public enum InventoryStatus: Int, Codable, Equatable, CaseIterable {
        case active = 0       // Healthy stock levels
        case lowStock = 1     // Stock running low (< 10 items)
        // case outOfStock = 2 - REMOVED: Use .inactive instead
        case inactive = 3     // Product marked as inactive (no stock or discontinued)

        var displayName: String {
            switch self {
            case .active: return "Active"
            case .lowStock: return "Low Stock"
            case .inactive: return "Inactive"
            }
        }
    }
}

@Model
final class ProductSize {
    public var id: String
    var size: String
    var quantity: Int // Number of items in stock for this size
    var sortIndex: Int = 0 // Explicit ordering field to preserve size order
    var product: Product?
    var createdAt: Date

    init(size: String, quantity: Int = 0, sortIndex: Int = 0, product: Product? = nil) {
        self.id = UUID().uuidString
        self.size = size
        self.quantity = quantity
        self.sortIndex = sortIndex
        self.product = product
        self.createdAt = Date()
    }
} 