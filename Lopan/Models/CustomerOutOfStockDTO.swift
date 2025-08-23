//
//  CustomerOutOfStockDTO.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation

/// Thread-safe data transfer object for CustomerOutOfStock
/// Used for caching without SwiftData relationship issues
struct CustomerOutOfStockDTO: Codable, Hashable, Identifiable {
    let id: String
    
    // Customer information (extracted from relationship)
    let customerName: String?
    let customerAddress: String?
    let customerPhone: String?
    
    // Product information (extracted from relationship)
    let productName: String?
    let productColors: [String]?
    let productSize: String?
    
    // Core out-of-stock data
    let quantity: Int
    let status: String
    let requestDate: Date
    let actualCompletionDate: Date?
    let notes: String?
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    
    // Return goods fields
    let returnQuantity: Int
    let returnDate: Date?
    let returnNotes: String?
    
    init(from customerOutOfStock: CustomerOutOfStock) {
        self.id = customerOutOfStock.id
        
        // Extract customer information safely
        self.customerName = customerOutOfStock.customer?.name
        self.customerAddress = customerOutOfStock.customer?.address
        self.customerPhone = customerOutOfStock.customer?.phone
        
        // Extract product information safely
        self.productName = customerOutOfStock.product?.name
        self.productColors = customerOutOfStock.product?.colors
        self.productSize = customerOutOfStock.productSize?.size
        
        // Copy core data
        self.quantity = customerOutOfStock.quantity
        self.status = customerOutOfStock.status.rawValue
        self.requestDate = customerOutOfStock.requestDate
        self.actualCompletionDate = customerOutOfStock.actualCompletionDate
        self.notes = customerOutOfStock.notes
        self.createdBy = customerOutOfStock.createdBy
        self.createdAt = customerOutOfStock.createdAt
        self.updatedAt = customerOutOfStock.updatedAt
        
        // Copy return goods data
        self.returnQuantity = customerOutOfStock.returnQuantity
        self.returnDate = customerOutOfStock.returnDate
        self.returnNotes = customerOutOfStock.returnNotes
    }
    
    // Helper properties for display
    var statusEnum: OutOfStockStatus {
        return OutOfStockStatus(rawValue: status) ?? .pending
    }
    
    var customerDisplayName: String {
        return customerName ?? "客户已删除"
    }
    
    var customerDisplayAddress: String {
        return customerAddress ?? "地址已删除"
    }
    
    var customerDisplayPhone: String {
        return customerPhone ?? "电话已删除"
    }
    
    var productDisplayName: String {
        guard let productName = productName else { return "未知产品" }
        let colorDisplay = (productColors?.isEmpty == false) ? productColors!.joined(separator: ",") : "无颜色"
        if let size = productSize {
            return "\(productName)-\(size)-\(colorDisplay)"
        } else {
            return "\(productName)-\(colorDisplay)"
        }
    }
}

// MARK: - Collection Extensions

extension Array where Element == CustomerOutOfStockDTO {
    /// Convert array of DTOs back to display format
    /// Note: This doesn't recreate SwiftData models, just provides display data
    var displayItems: [CustomerOutOfStockDisplayItem] {
        return map { CustomerOutOfStockDisplayItem(from: $0) }
    }
}

/// Display-only representation of out-of-stock data
/// Used when we need to show data without SwiftData models
struct CustomerOutOfStockDisplayItem: Identifiable {
    let id: String
    let customerName: String
    let customerAddress: String
    let customerPhone: String
    let productName: String
    let quantity: Int
    let status: OutOfStockStatus
    let requestDate: Date
    let actualCompletionDate: Date?
    let notes: String?
    let returnQuantity: Int
    let returnDate: Date?
    let returnNotes: String?
    
    init(from dto: CustomerOutOfStockDTO) {
        self.id = dto.id
        self.customerName = dto.customerDisplayName
        self.customerAddress = dto.customerDisplayAddress
        self.customerPhone = dto.customerDisplayPhone
        self.productName = dto.productDisplayName
        self.quantity = dto.quantity
        self.status = dto.statusEnum
        self.requestDate = dto.requestDate
        self.actualCompletionDate = dto.actualCompletionDate
        self.notes = dto.notes
        self.returnQuantity = dto.returnQuantity
        self.returnDate = dto.returnDate
        self.returnNotes = dto.returnNotes
    }
}