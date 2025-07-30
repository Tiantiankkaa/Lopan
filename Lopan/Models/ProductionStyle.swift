//
//  ProductionStyle.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

enum StyleStatus: String, CaseIterable, Codable {
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
final class ProductionStyle {
    var id: String
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
    var createdBy: String // User ID
    var createdAt: Date
    var updatedAt: Date
    
    init(styleCode: String, styleName: String, color: String, size: String, quantity: Int, productionDate: Date, notes: String? = nil, createdBy: String) {
        self.id = UUID().uuidString
        self.styleCode = styleCode
        self.styleName = styleName
        self.color = color
        self.size = size
        self.quantity = quantity
        self.status = .planning
        self.productionDate = productionDate
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 