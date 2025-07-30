//
//  CustomerOutOfStock.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

enum OutOfStockStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case confirmed = "confirmed"
    case inProduction = "in_production"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending:
            return "待处理"
        case .confirmed:
            return "已确认"
        case .inProduction:
            return "生产中"
        case .completed:
            return "已完成"
        case .cancelled:
            return "已取消"
        }
    }
}

enum OutOfStockPriority: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high:
            return "高"
        case .medium:
            return "中"
        case .low:
            return "低"
        }
    }
}

@Model
final class CustomerOutOfStock {
    var id: String
    var customer: Customer?
    var product: Product?
    var productSize: ProductSize? // Specific size for this out-of-stock item
    var quantity: Int
    var priority: OutOfStockPriority
    var status: OutOfStockStatus
    var requestDate: Date
    var actualCompletionDate: Date?
    var notes: String?
    var createdBy: String // User ID
    var createdAt: Date
    var updatedAt: Date
    
    // Return goods fields
    var returnQuantity: Int
    var returnDate: Date?
    var returnNotes: String?
    
    init(customer: Customer?, product: Product?, productSize: ProductSize? = nil, quantity: Int, priority: OutOfStockPriority = .medium, notes: String? = nil, createdBy: String) {
        self.id = UUID().uuidString
        self.customer = customer
        self.product = product
        self.productSize = productSize
        self.quantity = quantity
        self.priority = priority
        self.status = .pending
        self.requestDate = Date()
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Initialize return fields
        self.returnQuantity = 0
        self.returnDate = nil
        self.returnNotes = nil
    }
    
    // Helper method to get display name for the product with size
    var productDisplayName: String {
        guard let product = product else { return "未知产品" }
        let colorDisplay = product.colors.isEmpty ? "无颜色" : product.colors.joined(separator: ",")
        if let size = productSize {
            return "\(product.name)-\(size.size)-\(colorDisplay)"
        } else {
            return "\(product.name)-\(colorDisplay)"
        }
    }
    
    // Return goods computed properties
    var remainingQuantity: Int {
        return quantity - returnQuantity
    }
    
    var needsReturn: Bool {
        return remainingQuantity > 0 && (status == .pending || status == .confirmed || status == .inProduction)
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
        
        // Update status based on remaining quantity
        if self.returnQuantity >= self.quantity {
            self.status = .completed
            self.actualCompletionDate = Date()
        } else if self.returnQuantity > 0 {
            self.status = .inProduction
        }
        
        return true
    }
} 