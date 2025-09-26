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
    case pending = "pending"
    case completed = "completed"
    case returned = "returned"
    
    var displayName: String {
        switch self {
        case .pending:
            return "待处理"
        case .completed:
            return "已完成"
        case .returned:
            return "已退货"
        }
    }
    
    var color: Color {
        switch self {
        case .pending:
            return LopanColors.warning
        case .completed:
            return LopanColors.success
        case .returned:
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
    
    // Return goods fields
    var returnQuantity: Int
    var returnDate: Date?
    var returnNotes: String?
    
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
        
        // Initialize return fields
        self.returnQuantity = 0
        self.returnDate = nil
        self.returnNotes = nil
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
            let colorDisplay = product.colors.isEmpty ? "无颜色" : product.colors.joined(separator: ",")
            if let size = productSize {
                return "\(product.name)-\(size.size)-\(colorDisplay)"
            } else {
                return "\(product.name)-\(colorDisplay)"
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
    
    // Return goods computed properties
    var remainingQuantity: Int {
        return quantity - returnQuantity
    }
    
    var needsReturn: Bool {
        return remainingQuantity > 0 && status == .pending
    }
    
    var isFullyReturned: Bool {
        return returnQuantity >= quantity
    }
    
    var hasPartialReturn: Bool {
        return returnQuantity > 0 && returnQuantity < quantity
    }
    
    // Method to process return
    func processReturn(quantity: Int, notes: String? = nil) -> Bool {
        guard quantity > 0 && quantity <= remainingQuantity else { return false }
        
        self.returnQuantity += quantity
        self.returnDate = Date()
        self.returnNotes = notes
        self.updatedAt = Date()
        
        // Update status to returned when processing returns
        self.status = .returned
        self.actualCompletionDate = Date()
        
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
        case returnQuantity, returnDate, returnNotes
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
        
        self.returnQuantity = try container.decode(Int.self, forKey: .returnQuantity)
        self.returnDate = try container.decodeIfPresent(Date.self, forKey: .returnDate)
        self.returnNotes = try container.decodeIfPresent(String.self, forKey: .returnNotes)
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
        
        try container.encode(returnQuantity, forKey: .returnQuantity)
        try container.encodeIfPresent(returnDate, forKey: .returnDate)
        try container.encodeIfPresent(returnNotes, forKey: .returnNotes)
        
        try container.encode(customerDisplayName, forKey: .customerName)
        try container.encode(customerAddress, forKey: .customerAddress)
        try container.encode(customerPhone, forKey: .customerPhone)
        try container.encode(productDisplayName, forKey: .productName)
        try container.encodeIfPresent(productSize?.size, forKey: .productSize)
    }
}