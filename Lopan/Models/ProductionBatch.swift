//
//  ProductionBatch.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData
import SwiftUI

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
    case unsubmitted = "unsubmitted"
    case pending = "pending"
    case approved = "approved"
    case pendingExecution = "pending_execution"
    case rejected = "rejected"
    case active = "active"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .unsubmitted: return "未提交"
        case .pending: return "待审核"
        case .approved: return "已批准"
        case .pendingExecution: return "待执行"
        case .rejected: return "已拒绝"
        case .active: return "执行中"
        case .completed: return "已完成"
        }
    }
    
    var iconName: String {
        switch self {
        case .unsubmitted:
            return "clock.badge.exclamationmark"
        case .pending:
            return "clock"
        case .approved:
            return "checkmark.seal"
        case .pendingExecution:
            return "hourglass"
        case .active:
            return "gearshape.arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .unsubmitted:
            return "批次未提交"
        case .pending:
            return "批次待审核"
        case .approved:
            return "批次已批准"
        case .pendingExecution:
            return "批次待执行"
        case .rejected:
            return "批次已拒绝"
        case .active:
            return "批次执行中"
        case .completed:
            return "批次已完成"
        }
    }
    
}

enum BatchType: String, CaseIterable, Codable {
    case productionConfig = "PC"  // 生产配置 (单机)
    case batchProcessing = "BP"   // 批次处理 (多机)
    
    var displayName: String {
        switch self {
        case .productionConfig: return "生产配置"
        case .batchProcessing: return "批次处理"
        }
    }
    
    var prefix: String {
        return self.rawValue
    }
}

// MARK: - SwiftData Models
@Model
final class ProductionBatch: Identifiable {
    var id: String
    var batchNumber: String
    var machineId: String
    var mode: ProductionMode
    var status: BatchStatus
    var submittedAt: Date
    var submittedBy: String
    var submittedByName: String
    var approvalTargetDate: Date
    var reviewedAt: Date?
    var reviewedBy: String?
    var reviewedByName: String?
    var reviewNotes: String?
    var rejectedAt: Date?
    var completedAt: Date?
    var appliedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Shift scheduling fields (新增班次调度字段)
    var targetDate: Date? // Production target date (生产目标日期)
    var shift: Shift? // Target shift (目标班次)
    var allowsColorModificationOnly: Bool = true // Color-only editing constraint (仅允许颜色修改限制)
    var shiftSelectionLockTime: Date? // When shift selection was locked (班次选择锁定时间)
    var executionTime: Date? // Actual execution time (实际执行时间)
    var isSystemAutoCompleted: Bool = false // System auto-completion flag (系统自动完成标记)
    
    // Configuration snapshot
    var beforeConfigSnapshot: String? // JSON of previous configuration
    var afterConfigSnapshot: String?  // JSON of new configuration
    
    // Relationships
    @Relationship(deleteRule: .cascade) var products: [ProductConfig] = []
    
    init(machineId: String, mode: ProductionMode, submittedBy: String, submittedByName: String, approvalTargetDate: Date = Date(), batchNumber: String, targetDate: Date? = nil, shift: Shift? = nil) {
        self.id = UUID().uuidString
        self.batchNumber = batchNumber
        self.machineId = machineId
        self.mode = mode
        self.status = .unsubmitted
        self.submittedAt = Date()
        self.submittedBy = submittedBy
        self.submittedByName = submittedByName
        self.approvalTargetDate = approvalTargetDate
        self.targetDate = targetDate
        self.shift = shift
        self.allowsColorModificationOnly = true
        self.shiftSelectionLockTime = shift != nil ? Date() : nil
        self.executionTime = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Static Methods
    static func generateBatchNumber(using repository: ProductionBatchRepository, batchType: BatchType = .productionConfig) async -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        do {
            // Query for the latest batch number with the same date and type prefix
            if let latestBatchNumber = try await repository.fetchLatestBatchNumber(forDate: dateString, batchType: batchType) {
                // Extract the sequence number and increment it
                let batchPrefix = "\(batchType.prefix)-\(dateString)-"
                if let suffixRange = latestBatchNumber.range(of: batchPrefix) {
                    let suffix = String(latestBatchNumber[suffixRange.upperBound...])
                    if let currentSequence = Int(suffix) {
                        let nextSequence = currentSequence + 1
                        return "\(batchType.prefix)-\(dateString)-\(String(format: "%04d", nextSequence))"
                    }
                }
            }
            
            // No existing batches for this date and type, start with 0001
            return "\(batchType.prefix)-\(dateString)-0001"
            
        } catch {
            // Fallback to random generation if database query fails
            let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
            return "\(batchType.prefix)-\(dateString)-\(randomSuffix)"
        }
    }
    
    // MARK: - Computed Properties
    var batchType: BatchType {
        if batchNumber.hasPrefix("PC-") {
            return .productionConfig
        } else if batchNumber.hasPrefix("BP-") {
            return .batchProcessing
        } else {
            return .productionConfig // Default fallback for unknown formats
        }
    }
    
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
    
    // MARK: - Shift-aware Properties (班次相关属性)
    
    var isShiftBatch: Bool {
        return targetDate != nil && shift != nil
    }
    
    var shiftDate: ShiftDate? {
        guard let targetDate = targetDate, let shift = shift else { return nil }
        return ShiftDate(date: targetDate, shift: shift)
    }
    
    var displaySchedule: String {
        if let shiftDate = shiftDate {
            return shiftDate.displayText
        } else {
            // Legacy batch display
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(formatter.string(from: approvalTargetDate)) (传统批次)"
        }
    }
    
    var canModifyColors: Bool {
        // For shift-aware batches, only allow color modifications
        return isShiftBatch ? allowsColorModificationOnly : true
    }
    
    var canModifyStructure: Bool {
        // For shift-aware batches, structure modifications not allowed
        return !isShiftBatch || !allowsColorModificationOnly
    }
    
    var isLegacyBatch: Bool {
        return !isShiftBatch
    }
    
    func lockShiftSelection() {
        shiftSelectionLockTime = Date()
    }
    
    var isShiftSelectionLocked: Bool {
        return shiftSelectionLockTime != nil
    }
    
    // Migration helper for legacy batches
    func migrateToShiftBatch(targetDate: Date, shift: Shift) {
        self.targetDate = targetDate
        self.shift = shift
        self.allowsColorModificationOnly = true
        self.shiftSelectionLockTime = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Execution Properties
    var isExecuted: Bool {
        return executionTime != nil
    }
    
    var canExecute: Bool {
        // Batch must be in pendingExecution status to be executed
        return status == .pendingExecution && executionTime == nil
    }
    
    func setExecutionTime(_ time: Date) {
        self.executionTime = time
        self.status = .active
        self.updatedAt = Date()
    }
    
    /// Set batch as auto-completed when shift time has passed
    /// 班次时间过期后将批次设置为自动完成
    func setAutoCompleted(executionTime: Date, completionTime: Date? = nil) {
        self.executionTime = executionTime // Set to shift start time
        self.completedAt = completionTime ?? Date() // Set to provided completion time or current time
        self.status = .completed
        self.isSystemAutoCompleted = true // Mark as system auto-completed
        self.updatedAt = Date()
    }
    
    // MARK: - Execution Information Properties (执行信息属性)
    
    /// Check if batch was auto-completed by the system
    /// 检查批次是否由系统自动完成
    var isAutoCompleted: Bool {
        // 优先检查明确的标记
        if isSystemAutoCompleted {
            return true
        }
        
        // 后备逻辑：针对旧数据的智能检测
        // 场景1：有班次信息，执行时间是班次开始时间
        if let executionTime = executionTime, 
           let shift = shift,
           status == .completed {
            let calendar = Calendar.current
            let shiftStart = shift.standardStartTime
            let executionComponents = calendar.dateComponents([.hour, .minute], from: executionTime)
            if executionComponents.hour == shiftStart.hour && 
               executionComponents.minute == shiftStart.minute {
                return true
            }
        }
        
        // 场景2：已完成但缺少执行时间（可能是旧的自动完成数据）
        if status == .completed && 
           executionTime == nil && 
           completedAt != nil {
            return true
        }
        
        return false
    }
    
    /// Calculate runtime duration from execution to completion
    /// 计算从执行到完成的运行时长
    var runtimeDuration: TimeInterval? {
        guard let executionTime = executionTime,
              let completedAt = completedAt else { return nil }
        
        return completedAt.timeIntervalSince(executionTime)
    }
    
    /// Get formatted runtime duration string
    /// 获取格式化的运行时长字符串
    var formattedRuntimeDuration: String? {
        guard status == .completed else { return nil }
        
        if isAutoCompleted {
            // 系统自动完成：固定12小时
            return "12h"
        } else if let executionTime = executionTime, let completedAt = completedAt {
            // 用户手动执行：计算实际时长
            let duration = completedAt.timeIntervalSince(executionTime)
            return formatDuration(duration)
        } else {
            // 缺少执行时间信息
            return nil
        }
    }
    
    /// Get execution type information for display
    /// 获取执行类型信息用于显示
    var executionTypeInfo: (type: String, details: String)? {
        guard status == .completed else { return nil }
        
        if isAutoCompleted {
            // 系统自动完成
            if let shift = shift {
                return ("系统自动执行", "该批次为系统自动执行，按班次时间 \(shift.timeRangeDisplay) 运行")
            } else {
                return ("系统自动执行", "该批次为系统自动执行，运行时长: 12h")
            }
        } else if executionTime != nil && completedAt != nil {
            // 用户手动完成且有完整执行信息
            return ("用户手动操作", "用户手动执行和完成的批次")
        } else if completedAt != nil {
            // 只有完成时间，缺少执行时间
            return ("批次已完成", "批次已完成但缺少详细执行信息")
        } else {
            // 即使没有时间信息，已完成的批次也应该显示基本信息
            return ("批次已完成", "批次已完成，执行信息不可用")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Format duration for display
    /// 格式化时长显示
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
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
    private var occupiedStationsString: String
    var stationCount: Int? // Number of stations selected (3/6/9/12/Other)
    var gunAssignment: String? // "Gun A" or "Gun B"
    var approvalTargetDate: Date? // Product-level approval target date
    var startTime: Date? // Required start time for production
    var createdAt: Date
    var updatedAt: Date
    
    // Computed property for occupiedStations
    var occupiedStations: [Int] {
        get {
            guard !occupiedStationsString.isEmpty else { return [] }
            return occupiedStationsString.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .sorted()
        }
        set {
            occupiedStationsString = newValue.sorted().map { String($0) }.joined(separator: ",")
        }
    }
    
    init(batchId: String, productName: String, primaryColorId: String, occupiedStations: [Int], secondaryColorId: String? = nil, productId: String? = nil, stationCount: Int? = nil, gunAssignment: String? = nil, approvalTargetDate: Date? = nil, startTime: Date? = nil) {
        self.id = UUID().uuidString
        self.batchId = batchId
        self.productName = productName
        self.productId = productId
        self.primaryColorId = primaryColorId
        self.secondaryColorId = secondaryColorId
        self.occupiedStationsString = occupiedStations.sorted().map { String($0) }.joined(separator: ",")
        self.stationCount = stationCount
        self.gunAssignment = gunAssignment
        self.approvalTargetDate = approvalTargetDate
        self.startTime = startTime
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

// MARK: - Batch Color Modification Model (批次颜色修改模型)
struct BatchColorModification: Codable, Identifiable {
    let id: String
    let machineId: String
    let workstationId: String
    let currentColorId: String
    let proposedColorId: String
    let shift: Shift
    let modifiedAt: Date
    let modifiedBy: String
    let modifiedByName: String
    
    init(machineId: String, workstationId: String, currentColorId: String, proposedColorId: String, shift: Shift, modifiedBy: String, modifiedByName: String) {
        self.id = UUID().uuidString
        self.machineId = machineId
        self.workstationId = workstationId
        self.currentColorId = currentColorId
        self.proposedColorId = proposedColorId
        self.shift = shift
        self.modifiedAt = Date()
        self.modifiedBy = modifiedBy
        self.modifiedByName = modifiedByName
    }
    
    var hasChanges: Bool {
        return currentColorId != proposedColorId
    }
    
    var displayText: String {
        if hasChanges {
            return "工位 \(workstationId): 当前颜色 → 建议颜色"
        } else {
            return "工位 \(workstationId): 无变更"
        }
    }
}