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
    case read = "read"
    case statusChange = "status_change"
    case priorityChange = "priority_change"
    case returnProcess = "return_process"
    case batchUpdate = "batch_update"
    case batchDelete = "batch_delete"
    case machineStateChange = "machine_state_change"
    case gunColorChange = "gun_color_change"
    case maintenanceScheduled = "maintenance_scheduled"
    case maintenanceCompleted = "maintenance_completed"
    case colorAssignment = "color_assignment"
    case batchSubmission = "batch_submission"
    case batchReview = "batch_review"
    case productionConfigChange = "production_config_change"
    case reset = "reset"
    
    var displayName: String {
        switch self {
        case .create:
            return "创建"
        case .update:
            return "更新"
        case .delete:
            return "删除"
        case .read:
            return "查询"
        case .statusChange:
            return "状态变更"
        case .priorityChange:
            return "优先级变更"
        case .returnProcess:
            return "还货处理"
        case .batchUpdate:
            return "批量更新"
        case .batchDelete:
            return "批量删除"
        case .machineStateChange:
            return "设备状态变更"
        case .gunColorChange:
            return "喷枪颜色变更"
        case .maintenanceScheduled:
            return "维护安排"
        case .maintenanceCompleted:
            return "维护完成"
        case .colorAssignment:
            return "颜色分配"
        case .batchSubmission:
            return "批次提交"
        case .batchReview:
            return "批次审核"
        case .productionConfigChange:
            return "生产配置变更"
        case .reset:
            return "重置"
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
        case .read:
            return "magnifyingglass.circle.fill"
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
        case .machineStateChange:
            return "gearshape.2"
        case .gunColorChange:
            return "paintbrush.fill"
        case .maintenanceScheduled:
            return "calendar.badge.plus"
        case .maintenanceCompleted:
            return "checkmark.circle.fill"
        case .colorAssignment:
            return "paintbrush.pointed.fill"
        case .batchSubmission:
            return "tray.and.arrow.up.fill"
        case .batchReview:
            return "checkmark.seal.fill"
        case .productionConfigChange:
            return "gearshape.2.fill"
        case .reset:
            return "arrow.counterclockwise.circle.fill"
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
        case .read:
            return "gray"
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
        case .machineStateChange:
            return "orange"
        case .gunColorChange:
            return "purple"
        case .maintenanceScheduled:
            return "blue"
        case .maintenanceCompleted:
            return "green"
        case .colorAssignment:
            return "purple"
        case .batchSubmission:
            return "blue"
        case .batchReview:
            return "orange"
        case .productionConfigChange:
            return "teal"
        case .reset:
            return "purple"
        }
    }
}

// MARK: - Entity Types
enum EntityType: String, CaseIterable, Codable {
    case customerOutOfStock = "customer_out_of_stock"
    case customer = "customer"
    case product = "product"
    case user = "user"
    case delivery = "delivery"
    case machine = "machine"
    case station = "station"
    case workstation = "workstation"
    case gun = "gun"
    case maintenanceRecord = "maintenance_record"
    case color = "color"
    case productionBatch = "production_batch"
    case productConfig = "product_config"
    
    var displayName: String {
        switch self {
        case .customerOutOfStock:
            return "客户缺货"
        case .customer:
            return "客户"
        case .product:
            return "产品"
        case .user:
            return "用户"
        case .delivery:
            return "还货"
        case .machine:
            return "生产设备"
        case .station:
            return "工位"
        case .workstation:
            return "工作站"
        case .gun:
            return "喷枪"
        case .maintenanceRecord:
            return "维护记录"
        case .color:
            return "颜色卡"
        case .productionBatch:
            return "生产批次"
        case .productConfig:
            return "产品配置"
        }
    }
}

// MARK: - Audit Log Model
@Model
public final class AuditLog {
    public var id: String
    var operationType: OperationType
    var entityType: EntityType
    var entityId: String
    var entityDescription: String // Human readable description of the entity
    var userId: String // Renamed from operatorUserId
    var operatorUserName: String
    var timestamp: Date // Renamed from operationTimestamp
    var action: String // Added for compatibility
    var operationDetails: String // JSON string containing before/after values and other details
    var ipAddress: String?
    var deviceInfo: String?
    var batchId: String? // For grouping batch operations
    private var relatedEntityIdsString: String // For operations affecting multiple entities - stored as comma-separated string
    
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
        self.userId = operatorUserId // Updated property name
        self.operatorUserName = operatorUserName
        self.timestamp = Date() // Updated property name
        self.action = operationType.rawValue // Set action to operation type
        self.operationDetails = operationDetails
        self.ipAddress = ipAddress
        self.deviceInfo = deviceInfo
        self.batchId = batchId
        self.relatedEntityIdsString = relatedEntityIds.joined(separator: ",")
    }
    
    // MARK: - Computed Properties for Array Compatibility
    var relatedEntityIds: [String] {
        get {
            guard !relatedEntityIdsString.isEmpty else { return [] }
            return relatedEntityIdsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            relatedEntityIdsString = newValue.joined(separator: ",")
        }
    }
    
    // Helper methods
    var operationDetailsDict: [String: Any]? {
        guard let data = operationDetails.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var timeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(timestamp)
        
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
        let status: String?
        let notes: String?
        let deliveryQuantity: Int?
        let deliveryNotes: String?
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(affectedItems, forKey: .affectedItems)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(totalCount, forKey: .totalCount)
    }
}