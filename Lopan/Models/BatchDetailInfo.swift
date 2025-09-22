//
//  BatchDetailInfo.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/14.
//

import Foundation

/// Batch detail information structure for safe UI rendering
/// 批次详情信息结构，用于安全的UI渲染
struct BatchDetailInfo: Identifiable {
    let id: String
    let batchNumber: String
    let status: BatchStatus
    let machineId: String
    let mode: ProductionMode
    let batchType: BatchType
    let targetDate: Date?
    let shift: Shift?
    let submittedBy: String
    let submittedByName: String
    let submittedAt: Date
    let createdAt: Date
    
    // Execution information (执行信息)
    let executionTime: Date?
    let completedAt: Date?
    let appliedAt: Date?
    let isSystemAutoCompleted: Bool
    let allowsColorModificationOnly: Bool
    let isShiftBatch: Bool
    
    // Computed information (计算信息) - calculated once during initialization
    let executionTypeInfo: (type: String, details: String)?
    let formattedRuntimeDuration: String?
    let isAutoCompleted: Bool
    
    // Review information (审核信息)
    let reviewedAt: Date?
    let reviewedBy: String?
    let reviewedByName: String?
    let reviewNotes: String?
    let products: [ProductSnapshot]
    let totalStationsUsed: Int
    let isValidConfiguration: Bool
    
    /// Initialize from ProductionBatch model
    /// 从ProductionBatch模型初始化
    init(from batch: ProductionBatch) {
        // Basic information (基本信息)
        self.id = batch.id
        self.batchNumber = batch.batchNumber
        self.status = batch.status
        self.machineId = batch.machineId
        self.mode = batch.mode
        self.batchType = batch.batchType
        self.targetDate = batch.targetDate
        self.shift = batch.shift
        self.submittedBy = batch.submittedBy
        self.submittedByName = batch.submittedByName
        self.submittedAt = batch.submittedAt
        self.createdAt = batch.createdAt
        
        // Execution information (执行信息)
        self.executionTime = batch.executionTime
        self.completedAt = batch.completedAt
        self.appliedAt = batch.appliedAt
        self.isSystemAutoCompleted = batch.isSystemAutoCompleted
        self.allowsColorModificationOnly = batch.allowsColorModificationOnly
        self.isShiftBatch = batch.isShiftBatch
        
        // Review information (审核信息)
        self.reviewedAt = batch.reviewedAt
        self.reviewedBy = batch.reviewedBy
        self.reviewedByName = batch.reviewedByName
        self.reviewNotes = batch.reviewNotes
        
        // Snapshot related collections (集合快照)
        self.products = batch.products.map { ProductSnapshot(from: $0) }
        self.totalStationsUsed = batch.totalStationsUsed
        self.isValidConfiguration = batch.isValidConfiguration

        // Calculate computed properties once during initialization (初始化时一次性计算属性)
        self.isAutoCompleted = Self.calculateIsAutoCompleted(
            isSystemAutoCompleted: batch.isSystemAutoCompleted,
            executionTime: batch.executionTime,
            completedAt: batch.completedAt,
            shift: batch.shift,
            status: batch.status
        )
        
        self.executionTypeInfo = Self.calculateExecutionTypeInfo(
            status: batch.status,
            isAutoCompleted: self.isAutoCompleted,
            shift: batch.shift,
            executionTime: batch.executionTime,
            completedAt: batch.completedAt
        )
        
        self.formattedRuntimeDuration = Self.calculateFormattedRuntimeDuration(
            status: batch.status,
            isAutoCompleted: self.isAutoCompleted,
            executionTime: batch.executionTime,
            completedAt: batch.completedAt
        )
    }
    
    // MARK: - Static Calculation Methods (静态计算方法)
    
    /// Calculate if batch was auto-completed by the system
    /// 计算批次是否由系统自动完成
    private static func calculateIsAutoCompleted(
        isSystemAutoCompleted: Bool,
        executionTime: Date?,
        completedAt: Date?,
        shift: Shift?,
        status: BatchStatus
    ) -> Bool {
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
    
    /// Calculate execution type information for display
    /// 计算执行类型信息用于显示
    private static func calculateExecutionTypeInfo(
        status: BatchStatus,
        isAutoCompleted: Bool,
        shift: Shift?,
        executionTime: Date?,
        completedAt: Date?
    ) -> (type: String, details: String)? {
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
    
    /// Calculate formatted runtime duration string
    /// 计算格式化的运行时长字符串
    private static func calculateFormattedRuntimeDuration(
        status: BatchStatus,
        isAutoCompleted: Bool,
        executionTime: Date?,
        completedAt: Date?
    ) -> String? {
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
    
    /// Format duration for display
    /// 格式化时长显示
    private static func formatDuration(_ duration: TimeInterval) -> String {
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

// MARK: - Convenience Computed Properties (便利计算属性)

extension BatchDetailInfo {
    struct ProductSnapshot: Identifiable {
        let id: String
        let name: String
        let primaryColorId: String
        let secondaryColorId: String?
        let occupiedStations: [Int]
        let stationCount: Int?
        let gunAssignment: String?
        let isDualColor: Bool
        
        init(from product: ProductConfig) {
            self.id = product.id
            self.name = product.productName
            self.primaryColorId = product.primaryColorId
            self.secondaryColorId = product.secondaryColorId
            self.occupiedStations = product.occupiedStations
            self.stationCount = product.stationCount
            self.gunAssignment = product.gunAssignment
            self.isDualColor = product.isDualColor
        }
        
        var occupiedStationsDisplay: String {
            guard !occupiedStations.isEmpty else { return "-" }
            return occupiedStations.sorted().map(String.init).joined(separator: ", ")
        }
    }
    
    /// Display name for batch type
    /// 批次类型显示名称
    var batchTypeDisplayName: String {
        return batchType.displayName
    }
    
    /// Formatted submitted date
    /// 格式化的提交日期
    var formattedSubmittedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: submittedAt)
    }
    
    /// Formatted target date
    /// 格式化的目标日期
    var formattedTargetDate: String? {
        guard let targetDate = targetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: targetDate)
    }
    
    /// Check if batch allows editing
    /// 检查批次是否允许编辑
    var allowsEditing: Bool {
        return status == .pending || status == .approved
    }
    
    /// Get status display information
    /// 获取状态显示信息
    var statusDisplayInfo: (text: String, color: String) {
        switch status {
        case .unsubmitted:
            return ("未提交", "gray")
        case .pending:
            return ("待审核", "orange")
        case .approved:
            return ("已审批", "green")
        case .rejected:
            return ("已拒绝", "red")
        case .pendingExecution:
            return ("待执行", "blue")
        case .active:
            return ("执行中", "blue")
        case .completed:
            return ("已完成", "green")
        }
    }
}
