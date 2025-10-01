//
//  DailySalesEntry.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import Foundation
import SwiftData

@Model
public final class DailySalesEntry {
    public var id: String
    public var date: Date // Normalized to start of day
    public var salespersonId: String
    @Relationship(deleteRule: .cascade, inverse: \SalesLineItem.salesEntry)
    public var items: [SalesLineItem]?
    public var createdAt: Date
    public var updatedAt: Date

    // Computed property for total amount
    public var totalAmount: Decimal {
        items?.reduce(Decimal(0)) { $0 + $1.subtotal } ?? Decimal(0)
    }

    public init(
        id: String = UUID().uuidString,
        date: Date,
        salespersonId: String,
        items: [SalesLineItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        // Normalize date to start of day for consistent comparisons
        self.date = Calendar.current.startOfDay(for: date)
        self.salespersonId = salespersonId
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SalesLineItem {
    public var id: String
    public var productId: String
    public var productName: String // Denormalized for performance
    public var quantity: Int
    public var unitPrice: Decimal
    public var salesEntry: DailySalesEntry?

    // Computed property for subtotal
    public var subtotal: Decimal {
        Decimal(quantity) * unitPrice
    }

    public init(
        id: String = UUID().uuidString,
        productId: String,
        productName: String,
        quantity: Int,
        unitPrice: Decimal,
        salesEntry: DailySalesEntry? = nil
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.salesEntry = salesEntry
    }
}
