//
//  CustomerOutOfStock.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData
import SwiftUI

public enum OutOfStockStatus: String, CaseIterable, Codable {
    case pending = "pending"        // Order placed, awaiting fulfillment
    case completed = "completed"    // Products delivered to customer
    case refunded = "returned"      // Order cancelled/refunded to supplier (raw value kept for backward compatibility)

    var displayName: String {
        switch self {
        case .pending:
            return "待处理"           // Pending
        case .completed:
            return "已还货"           // Delivered (to customer)
        case .refunded:
            return "已退货"           // Refunded (to supplier)
        }
    }

    var color: Color {
        switch self {
        case .pending:
            return LopanColors.warning
        case .completed:
            return LopanColors.success
        case .refunded:
            return LopanColors.error
        }
    }
}

@Model
public final class CustomerOutOfStock {
    public var id: String
    var customer: Customer?
    var product: Product?
    var productSize: ProductSize? // Specific size for this out-of-stock item
    var quantity: Int
    var status: OutOfStockStatus
    var requestDate: Date
    var actualCompletionDate: Date?
    var notes: String?
    var createdBy: String // User ID
    var updatedBy: String? // User ID of last updater
    var createdAt: Date
    var updatedAt: Date
    
    // Delivery goods fields (products delivered TO customer from out-of-stock orders)
    var deliveryQuantity: Int = 0
    var deliveryDate: Date?
    var deliveryNotes: String?

    // Refund fields (order returned TO supplier/cancelled)
    var isRefunded: Bool = false
    var refundDate: Date?
    var refundReason: String?
    
    init(customer: Customer?, product: Product?, productSize: ProductSize? = nil, quantity: Int, notes: String? = nil, createdBy: String) {
        self.id = UUID().uuidString
        self.customer = customer
        self.product = product
        self.productSize = productSize
        self.quantity = quantity
        self.status = .pending
        self.requestDate = Date()
        self.notes = notes
        self.createdBy = createdBy
        self.updatedBy = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Initialize delivery fields
        self.deliveryQuantity = 0
        self.deliveryDate = nil
        self.deliveryNotes = nil

        // Initialize refund fields
        self.isRefunded = false
        self.refundDate = nil
        self.refundReason = nil
    }
    
    // Helper method to get display name for the customer (safe for orphaned records)
    var customerDisplayName: String {
        if let customer = customer {
            return customer.name
        } else {
            // Customer deleted, try to extract from DISPLAY_INFO or legacy notes pattern
            return extractCustomerNameFromDisplayInfo() ?? extractCustomerNameFromNotes() ?? "客户已删除"
        }
    }
    
    // Helper method to get customer address (safe for orphaned records)
    var customerAddress: String {
        if let customer = customer {
            return customer.address
        } else {
            return extractCustomerAddressFromDisplayInfo() ?? "地址已删除"
        }
    }
    
    // Helper method to get customer phone (safe for orphaned records)
    var customerPhone: String {
        if let customer = customer {
            return customer.phone
        } else {
            return extractCustomerPhoneFromDisplayInfo() ?? "电话已删除"
        }
    }
    
    // Helper method to get display name for the product with size
    var productDisplayName: String {
        if let product = product {
            if let size = productSize {
                return "\(product.name)-\(size.size)"
            } else {
                return product.name
            }
        } else {
            return extractProductNameFromDisplayInfo() ?? "未知产品"
        }
    }
    
    // Extract cached customer name from notes (format: "（原客户：Name - Number）")
    func extractCustomerNameFromNotes() -> String? {
        guard let notes = notes else { return nil }
        
        // Look for pattern "（原客户：Name - Number）"
        let pattern = "（原客户：([^-]+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: notes, options: [], range: NSRange(location: 0, length: notes.count)),
           let range = Range(match.range(at: 1), in: notes) {
            let extractedName = String(notes[range]).trimmingCharacters(in: .whitespaces)
            return extractedName.isEmpty ? nil : extractedName
        }
        
        return nil
    }
    
    // MARK: - DISPLAY_INFO Extraction Methods
    
    /// Extract display info from notes field (format: "DISPLAY_INFO:{customerName|customerAddress|customerPhone|productName}")
    private func extractDisplayInfo() -> (customerName: String?, customerAddress: String?, customerPhone: String?, productName: String?)? {
        guard let notes = notes else { return nil }
        
        // Look for DISPLAY_INFO pattern
        let pattern = "DISPLAY_INFO:\\{([^}]+)\\}"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: notes, options: [], range: NSRange(location: 0, length: notes.count)),
           let range = Range(match.range(at: 1), in: notes) {
            let displayInfoString = String(notes[range])
            let components = displayInfoString.components(separatedBy: "|")
            
            if components.count >= 4 {
                return (
                    customerName: components[0].isEmpty ? nil : components[0],
                    customerAddress: components[1].isEmpty ? nil : components[1],
                    customerPhone: components[2].isEmpty ? nil : components[2],
                    productName: components[3].isEmpty ? nil : components[3]
                )
            }
        }
        
        return nil
    }
    
    /// Extract customer name from DISPLAY_INFO in notes
    func extractCustomerNameFromDisplayInfo() -> String? {
        return extractDisplayInfo()?.customerName
    }
    
    /// Extract customer address from DISPLAY_INFO in notes
    func extractCustomerAddressFromDisplayInfo() -> String? {
        return extractDisplayInfo()?.customerAddress
    }
    
    /// Extract customer phone from DISPLAY_INFO in notes
    func extractCustomerPhoneFromDisplayInfo() -> String? {
        return extractDisplayInfo()?.customerPhone
    }
    
    /// Extract product name from DISPLAY_INFO in notes
    func extractProductNameFromDisplayInfo() -> String? {
        return extractDisplayInfo()?.productName
    }
    
    /// Get user-visible notes (filtered to remove DISPLAY_INFO metadata)
    var userVisibleNotes: String? {
        guard let notes = notes else { return nil }
        
        // Remove DISPLAY_INFO pattern
        let pattern = "DISPLAY_INFO:\\{[^}]*\\}\\s*"
        let cleanedNotes = notes.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedNotes.isEmpty ? nil : cleanedNotes
    }
    
    // Delivery goods computed properties
    var remainingQuantity: Int {
        return quantity - deliveryQuantity
    }

    var needsDelivery: Bool {
        return remainingQuantity > 0 && status == .pending
    }

    var isFullyDelivered: Bool {
        return deliveryQuantity >= quantity
    }

    var hasPartialDelivery: Bool {
        return deliveryQuantity > 0 && deliveryQuantity < quantity
    }

    // Method to process delivery (products delivered to customer)
    func processDelivery(quantity: Int, notes: String? = nil) -> Bool {
        guard quantity > 0 && quantity <= remainingQuantity else { return false }

        self.deliveryQuantity += quantity
        self.deliveryDate = Date()
        self.deliveryNotes = notes
        self.updatedAt = Date()

        // Update status to completed when fully delivered
        if self.deliveryQuantity >= self.quantity {
            self.status = .completed
            self.actualCompletionDate = Date()
        }

        return true
    }

    // Method to process refund (order cancelled/returned to supplier)
    func processRefund(reason: String) -> Bool {
        guard !isRefunded else { return false }

        self.isRefunded = true
        self.refundDate = Date()
        self.refundReason = reason
        self.status = .refunded
        self.actualCompletionDate = Date()
        self.updatedAt = Date()

        return true
    }
    
    // MARK: - Mock Data Creation (Production Safe)
    
    /// Create a mock record from creation request - used for safe placeholder behavior
    static func createMockRecord(from request: OutOfStockCreationRequest) -> CustomerOutOfStock {
        let mockRecord = CustomerOutOfStock(
            customer: nil, // Placeholder mode - no real customer
            product: nil,  // Placeholder mode - no real product
            quantity: request.quantity,
            notes: "MOCK_RECORD: \(request.notes ?? "")",
            createdBy: request.createdBy
        )
        
        // Add display info for testing
        if let customerName = request.customerName,
           let productName = request.productName {
            mockRecord.notes = "DISPLAY_INFO:{Mock Customer|\(customerName)|Mock Phone|\(productName)} \(request.notes ?? "")"
        }
        
        return mockRecord
    }
}

extension CustomerOutOfStock: Equatable {
    public static func == (lhs: CustomerOutOfStock, rhs: CustomerOutOfStock) -> Bool {
        return lhs.id == rhs.id
    }
}

extension CustomerOutOfStock: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension CustomerOutOfStock: Identifiable {
    // id property already exists in the class
}

extension CustomerOutOfStock: Codable {
    enum CodingKeys: String, CodingKey {
        case id, quantity, status, requestDate, actualCompletionDate, notes, createdBy, updatedBy, createdAt, updatedAt
        case deliveryQuantity, deliveryDate, deliveryNotes
        case isRefunded, refundDate, refundReason
        case customerName, customerAddress, customerPhone
        case productName, productSize
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let quantity = try container.decode(Int.self, forKey: .quantity)
        let createdBy = try container.decode(String.self, forKey: .createdBy)
        
        self.init(customer: nil, product: nil, productSize: nil, quantity: quantity, notes: nil, createdBy: createdBy)
        
        self.id = id
        self.status = try container.decode(OutOfStockStatus.self, forKey: .status)
        self.requestDate = try container.decode(Date.self, forKey: .requestDate)
        self.actualCompletionDate = try container.decodeIfPresent(Date.self, forKey: .actualCompletionDate)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.updatedBy = try container.decodeIfPresent(String.self, forKey: .updatedBy)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        self.deliveryQuantity = try container.decode(Int.self, forKey: .deliveryQuantity)
        self.deliveryDate = try container.decodeIfPresent(Date.self, forKey: .deliveryDate)
        self.deliveryNotes = try container.decodeIfPresent(String.self, forKey: .deliveryNotes)

        self.isRefunded = try container.decodeIfPresent(Bool.self, forKey: .isRefunded) ?? false
        self.refundDate = try container.decodeIfPresent(Date.self, forKey: .refundDate)
        self.refundReason = try container.decodeIfPresent(String.self, forKey: .refundReason)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(status, forKey: .status)
        try container.encode(requestDate, forKey: .requestDate)
        try container.encodeIfPresent(actualCompletionDate, forKey: .actualCompletionDate)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(updatedBy, forKey: .updatedBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        try container.encode(deliveryQuantity, forKey: .deliveryQuantity)
        try container.encodeIfPresent(deliveryDate, forKey: .deliveryDate)
        try container.encodeIfPresent(deliveryNotes, forKey: .deliveryNotes)

        try container.encode(isRefunded, forKey: .isRefunded)
        try container.encodeIfPresent(refundDate, forKey: .refundDate)
        try container.encodeIfPresent(refundReason, forKey: .refundReason)
        
        try container.encode(customerDisplayName, forKey: .customerName)
        try container.encode(customerAddress, forKey: .customerAddress)
        try container.encode(customerPhone, forKey: .customerPhone)
        try container.encode(productDisplayName, forKey: .productName)
        try container.encodeIfPresent(productSize?.size, forKey: .productSize)
    }
}