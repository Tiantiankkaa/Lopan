//
//  ProductionBatch.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

// MARK: - Production Enums
enum ProductionMode: String, CaseIterable, Codable {
    case singleColor = "single"
    case dualColor = "dual"
    
    var displayName: String {
        switch self {
        case .singleColor: return "单色生产"
        case .dualColor: return "双色生产"
        }
    }
    
    var minStationsPerProduct: Int {
        switch self {
        case .singleColor: return 3
        case .dualColor: return 6
        }
    }
    
    var maxProducts: Int {
        switch self {
        case .singleColor: return 4 // 4 × 3 = 12 stations
        case .dualColor: return 2   // 2 × 6 = 12 stations
        }
    }
}

enum BatchStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case active = "active"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .pending: return "待审核"
        case .approved: return "已批准"
        case .rejected: return "已拒绝"
        case .active: return "执行中"
        case .completed: return "已完成"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .approved: return "green"
        case .rejected: return "red"
        case .active: return "blue"
        case .completed: return "gray"
        }
    }
}

// MARK: - SwiftData Models
@Model
final class ProductionBatch {
    var id: String
    var batchNumber: String
    var machineId: String
    var mode: ProductionMode
    var status: BatchStatus
    var submittedAt: Date
    var submittedBy: String
    var submittedByName: String
    var reviewedAt: Date?
    var reviewedBy: String?
    var reviewedByName: String?
    var reviewNotes: String?
    var appliedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Configuration snapshot
    var beforeConfigSnapshot: String? // JSON of previous configuration
    var afterConfigSnapshot: String?  // JSON of new configuration
    
    // Relationships
    @Relationship(deleteRule: .cascade) var products: [ProductConfig] = []
    
    init(machineId: String, mode: ProductionMode, submittedBy: String, submittedByName: String) {
        self.id = UUID().uuidString
        self.batchNumber = Self.generateBatchNumber()
        self.machineId = machineId
        self.mode = mode
        self.status = .pending
        self.submittedAt = Date()
        self.submittedBy = submittedBy
        self.submittedByName = submittedByName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Static Methods
    private static func generateBatchNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        return "BATCH-\(dateString)-\(randomSuffix)"
    }
    
    // MARK: - Computed Properties
    var canBeReviewed: Bool {
        return status == .pending
    }
    
    var canBeApplied: Bool {
        return status == .approved
    }
    
    var totalStationsUsed: Int {
        return products.reduce(0) { $0 + $1.occupiedStations.count }
    }
    
    var isValidConfiguration: Bool {
        // Check if total stations don't exceed 12
        guard totalStationsUsed <= 12 else { return false }
        
        // Check if each product meets minimum station requirements
        for product in products {
            if product.occupiedStations.count < mode.minStationsPerProduct {
                return false
            }
        }
        
        // Check if not exceeding max products
        guard products.count <= mode.maxProducts else { return false }
        
        // Check for station conflicts
        let allStations = products.flatMap { $0.occupiedStations }
        let uniqueStations = Set(allStations)
        guard allStations.count == uniqueStations.count else { return false }
        
        return true
    }
}

@Model
final class ProductConfig {
    var id: String
    var batchId: String
    var productName: String
    var productId: String? // Reference to existing Product in sales platform
    var primaryColorId: String
    var secondaryColorId: String? // Only for dual-color products
    var occupiedStations: [Int]
    var stationCount: Int? // Number of stations selected (3/6/9/12/Other)
    var gunAssignment: String? // "Gun A" or "Gun B"
    var expectedOutput: Int
    var priority: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(batchId: String, productName: String, primaryColorId: String, occupiedStations: [Int], expectedOutput: Int = 1000, priority: Int = 1, secondaryColorId: String? = nil, productId: String? = nil, stationCount: Int? = nil, gunAssignment: String? = nil) {
        self.id = UUID().uuidString
        self.batchId = batchId
        self.productName = productName
        self.productId = productId
        self.primaryColorId = primaryColorId
        self.secondaryColorId = secondaryColorId
        self.occupiedStations = occupiedStations.sorted()
        self.stationCount = stationCount
        self.gunAssignment = gunAssignment
        self.expectedOutput = expectedOutput
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    var isDualColor: Bool {
        return secondaryColorId != nil
    }
    
    var gunAssignments: (gunA: [Int], gunB: [Int]) {
        let gunA = occupiedStations.filter { $0 <= 6 }
        let gunB = occupiedStations.filter { $0 > 6 }
        return (gunA, gunB)
    }
    
    var stationRange: String {
        guard !occupiedStations.isEmpty else { return "未分配" }
        let sorted = occupiedStations.sorted()
        if sorted.count == 1 {
            return "工位 \(sorted[0])"
        } else {
            return "工位 \(sorted.map(String.init).joined(separator: ", "))"
        }
    }
}