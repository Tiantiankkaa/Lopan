//
//  ProductionStyle.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

public enum StyleStatus: String, CaseIterable, Codable {
    case planning = "planning"
    case inProduction = "in_production"
    case completed = "completed"
    case warehoused = "warehoused"
    case shipped = "shipped"
    
    var displayName: String {
        switch self {
        case .planning:
            return "计划中"
        case .inProduction:
            return "生产中"
        case .completed:
            return "已完成"
        case .warehoused:
            return "已入库"
        case .shipped:
            return "已发货"
        }
    }
}

@Model
public final class ProductionStyle {
    public var id: String
    var styleCode: String
    var styleName: String
    var color: String
    var size: String
    var quantity: Int
    var status: StyleStatus
    var productionDate: Date
    var completionDate: Date?
    var warehouseDate: Date?
    var notes: String?
    var productId: String? // Reference to source Product
    var productSizeId: String? // Reference to specific ProductSize
    var createdBy: String // User ID
    var createdAt: Date
    var updatedAt: Date
    
    init(styleCode: String, styleName: String, color: String, size: String, quantity: Int, productionDate: Date, notes: String? = nil, productId: String? = nil, productSizeId: String? = nil, createdBy: String) {
        self.id = UUID().uuidString
        self.styleCode = styleCode
        self.styleName = styleName
        self.color = color
        self.size = size
        self.quantity = quantity
        self.status = .planning
        self.productionDate = productionDate
        self.notes = notes
        self.productId = productId
        self.productSizeId = productSizeId
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Helper method to create from Product and ProductSize
    static func fromProduct(_ product: Product, size: ProductSize, color: String, quantity: Int, productionDate: Date, createdBy: String) -> ProductionStyle {
        let styleCode = "\(product.name.prefix(2).uppercased())\(String(format: "%03d", Int.random(in: 1...999)))"
        
        return ProductionStyle(
            styleCode: styleCode,
            styleName: product.name,
            color: color,
            size: size.size,
            quantity: quantity,
            productionDate: productionDate,
            productId: product.id,
            productSizeId: size.id,
            createdBy: createdBy
        )
    }
} 