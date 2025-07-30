//
//  AuditLog.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import Foundation
import SwiftData

// MARK: - Operation Types
enum OperationType: String, CaseIterable, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case statusChange = "status_change"
    case priorityChange = "priority_change"
    case returnProcess = "return_process"
    case batchUpdate = "batch_update"
    case batchDelete = "batch_delete"
    
    var displayName: String {
        switch self {
        case .create:
            return "创建"
        case .update:
            return "更新"
        case .delete:
            return "删除"
        case .statusChange:
            return "状态变更"
        case .priorityChange:
            return "优先级变更"
        case .returnProcess:
            return "退货处理"
        case .batchUpdate:
            return "批量更新"
        case .batchDelete:
            return "批量删除"
        }
    }
    
    var iconName: String {
        switch self {
        case .create:
            return "plus.circle.fill"
        case .update:
            return "pencil.circle.fill"
        case .delete:
            return "trash.circle.fill"
        case .statusChange:
            return "arrow.triangle.2.circlepath"
        case .priorityChange:
            return "flag.circle.fill"
        case .returnProcess:
            return "return.left"
        case .batchUpdate:
            return "rectangle.3.group.fill"
        case .batchDelete:
            return "trash.fill"
        }
    }
    
    var color: String {
        switch self {
        case .create:
            return "green"
        case .update:
            return "blue"
        case .delete:
            return "red"
        case .statusChange:
            return "orange"
        case .priorityChange:
            return "purple"
        case .returnProcess:
            return "indigo"
        case .batchUpdate:
            return "teal"
        case .batchDelete:
            return "red"
        }
    }
}

// MARK: - Entity Types
enum EntityType: String, CaseIterable, Codable {
    case customerOutOfStock = "customer_out_of_stock"
    case customer = "customer"
    case product = "product"
    case returnGoods = "return_goods"
    
    var displayName: String {
        switch self {
        case .customerOutOfStock:
            return "客户缺货"
        case .customer:
            return "客户"
        case .product:
            return "产品"
        case .returnGoods:
            return "退货"
        }
    }
}

// MARK: - Audit Log Model
@Model
final class AuditLog {
    var id: String
    var operationType: OperationType
    var entityType: EntityType
    var entityId: String
    var entityDescription: String // Human readable description of the entity
    var operatorUserId: String
    var operatorUserName: String
    var operationTimestamp: Date
    var operationDetails: String // JSON string containing before/after values and other details
    var ipAddress: String?
    var deviceInfo: String?
    var batchId: String? // For grouping batch operations
    var relatedEntityIds: [String] // For operations affecting multiple entities
    
    init(
        operationType: OperationType,
        entityType: EntityType,
        entityId: String,
        entityDescription: String,
        operatorUserId: String,
        operatorUserName: String,
        operationDetails: String,
        ipAddress: String? = nil,
        deviceInfo: String? = nil,
        batchId: String? = nil,
        relatedEntityIds: [String] = []
    ) {
        self.id = UUID().uuidString
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.entityDescription = entityDescription
        self.operatorUserId = operatorUserId
        self.operatorUserName = operatorUserName
        self.operationTimestamp = Date()
        self.operationDetails = operationDetails
        self.ipAddress = ipAddress
        self.deviceInfo = deviceInfo
        self.batchId = batchId
        self.relatedEntityIds = relatedEntityIds
    }
    
    // Helper methods
    var operationDetailsDict: [String: Any]? {
        guard let data = operationDetails.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: operationTimestamp)
    }
    
    var timeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(operationTimestamp)
        
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        }
    }
}

// MARK: - Operation Details Structures
struct CustomerOutOfStockOperation: Codable {
    let beforeValues: CustomerOutOfStockValues?
    let afterValues: CustomerOutOfStockValues?
    let changedFields: [String]
    let additionalInfo: String?
    
    struct CustomerOutOfStockValues: Codable {
        let customerName: String?
        let productName: String?
        let quantity: Int?
        let priority: String?
        let status: String?
        let notes: String?
        let returnQuantity: Int?
        let returnNotes: String?
    }
}

struct BatchOperation: Codable {
    let affectedItems: [String] // Entity IDs
    let operationType: String
    let changeDetails: [String: Any]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case affectedItems, operationType, totalCount
    }
    
    init(affectedItems: [String], operationType: String, changeDetails: [String: Any], totalCount: Int) {
        self.affectedItems = affectedItems
        self.operationType = operationType
        self.changeDetails = changeDetails
        self.totalCount = totalCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        affectedItems = try container.decode([String].self, forKey: .affectedItems)
        operationType = try container.decode(String.self, forKey: .operationType)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        changeDetails = [:] // Initialize with empty dict for now
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(affectedItems, forKey: .affectedItems)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(totalCount, forKey: .totalCount)
    }
}