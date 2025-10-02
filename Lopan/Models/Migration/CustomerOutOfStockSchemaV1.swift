//
//  CustomerOutOfStockSchemaV1.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//  Schema V1 - Before semantic refactoring (returnQuantity → deliveryQuantity)
//

import Foundation
import SwiftData
import SwiftUI

enum CustomerOutOfStockSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [CustomerOutOfStockV1.self]
    }

    @Model
    final class CustomerOutOfStockV1 {
        var id: String
        var customer: Customer?
        var product: Product?
        var productSize: ProductSize?
        var quantity: Int
        var status: OutOfStockStatus
        var requestDate: Date
        var actualCompletionDate: Date?
        var notes: String?
        var createdBy: String
        var updatedBy: String?
        var createdAt: Date
        var updatedAt: Date

        // OLD field names (before semantic refactoring)
        var returnQuantity: Int
        var returnDate: Date?
        var returnNotes: String?

        // Refund fields
        var isRefunded: Bool
        var refundDate: Date?
        var refundReason: String?

        init(
            id: String,
            customer: Customer?,
            product: Product?,
            productSize: ProductSize?,
            quantity: Int,
            status: OutOfStockStatus,
            requestDate: Date,
            actualCompletionDate: Date?,
            notes: String?,
            createdBy: String,
            updatedBy: String?,
            createdAt: Date,
            updatedAt: Date,
            returnQuantity: Int,
            returnDate: Date?,
            returnNotes: String?,
            isRefunded: Bool,
            refundDate: Date?,
            refundReason: String?
        ) {
            self.id = id
            self.customer = customer
            self.product = product
            self.productSize = productSize
            self.quantity = quantity
            self.status = status
            self.requestDate = requestDate
            self.actualCompletionDate = actualCompletionDate
            self.notes = notes
            self.createdBy = createdBy
            self.updatedBy = updatedBy
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.returnQuantity = returnQuantity
            self.returnDate = returnDate
            self.returnNotes = returnNotes
            self.isRefunded = isRefunded
            self.refundDate = refundDate
            self.refundReason = refundReason
        }
    }
}
