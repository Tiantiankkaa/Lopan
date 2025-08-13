//
//  ErrorHandling.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation
import SwiftUI

// MARK: - Batch Processing Error Types (批次处理错误类型)

enum BatchProcessingError: LocalizedError, Equatable {
    case invalidTimeSlot(message: String)
    case machineConflict(machineId: String, conflictingBatch: String)
    case shiftNotAvailable(shift: Shift, date: Date)
    case colorOnlyRestriction(batchId: String)
    case insufficientPermissions(requiredRole: String)
    case validationFailed(details: [String])
    case networkError(underlying: String)
    case dataCorruption(entity: String)
    case unexpectedState(state: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTimeSlot(let message):
            return NSLocalizedString("invalid_time_slot", 
                                    value: "时间段无效: \(message)", 
                                    comment: "Invalid time slot error")
        case .machineConflict(let machineId, let conflictingBatch):
            return NSLocalizedString("machine_conflict",
                                    value: "机器 \(machineId) 与批次 \(conflictingBatch) 存在冲突",
                                    comment: "Machine conflict error")
        case .shiftNotAvailable(let shift, let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return NSLocalizedString("shift_not_available",
                                    value: "\(shift.displayName) 在 \(formatter.string(from: date)) 不可用",
                                    comment: "Shift not available error")
        case .colorOnlyRestriction(let batchId):
            return NSLocalizedString("color_only_restriction",
                                    value: "批次 \(batchId) 仅允许颜色修改",
                                    comment: "Color-only restriction error")
        case .insufficientPermissions(let requiredRole):
            return NSLocalizedString("insufficient_permissions",
                                    value: "权限不足，需要 \(requiredRole) 角色",
                                    comment: "Insufficient permissions error")
        case .validationFailed(let details):
            return NSLocalizedString("validation_failed",
                                    value: "验证失败: \(details.joined(separator: ", "))",
                                    comment: "Validation failed error")
        case .networkError(let underlying):
            return NSLocalizedString("network_error",
                                    value: "网络错误: \(underlying)",
                                    comment: "Network error")
        case .dataCorruption(let entity):
            return NSLocalizedString("data_corruption",
                                    value: "数据损坏: \(entity)",
                                    comment: "Data corruption error")
        case .unexpectedState(let state):
            return NSLocalizedString("unexpected_state",
                                    value: "意外状态: \(state)",
                                    comment: "Unexpected state error")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidTimeSlot:
            return NSLocalizedString("invalid_time_slot_recovery",
                                    value: "请选择有效的时间段或联系管理员",
                                    comment: "Invalid time slot recovery")
        case .machineConflict:
            return NSLocalizedString("machine_conflict_recovery",
                                    value: "请选择其他机器或时间段",
                                    comment: "Machine conflict recovery")
        case .shiftNotAvailable:
            return NSLocalizedString("shift_not_available_recovery",
                                    value: "请选择其他班次或日期",
                                    comment: "Shift not available recovery")
        case .colorOnlyRestriction:
            return NSLocalizedString("color_only_restriction_recovery",
                                    value: "如需其他修改，请前往生产配置",
                                    comment: "Color-only restriction recovery")
        case .insufficientPermissions:
            return NSLocalizedString("insufficient_permissions_recovery",
                                    value: "请联系管理员获取相应权限",
                                    comment: "Insufficient permissions recovery")
        case .validationFailed:
            return NSLocalizedString("validation_failed_recovery",
                                    value: "请检查并修正错误后重试",
                                    comment: "Validation failed recovery")
        case .networkError:
            return NSLocalizedString("network_error_recovery",
                                    value: "请检查网络连接后重试",
                                    comment: "Network error recovery")
        case .dataCorruption:
            return NSLocalizedString("data_corruption_recovery",
                                    value: "请刷新数据或联系技术支持",
                                    comment: "Data corruption recovery")
        case .unexpectedState:
            return NSLocalizedString("unexpected_state_recovery",
                                    value: "请刷新页面或重启应用",
                                    comment: "Unexpected state recovery")
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .invalidTimeSlot, .shiftNotAvailable, .colorOnlyRestriction:
            return .warning
        case .machineConflict, .insufficientPermissions, .validationFailed:
            return .error
        case .networkError, .dataCorruption, .unexpectedState:
            return .critical
        }
    }
}

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error Handler Service (错误处理服务)

@MainActor
class ErrorHandlingService: ObservableObject {
    
    @Published var currentError: BatchProcessingError?
    @Published var errorHistory: [ErrorRecord] = []
    @Published var showingError = false
    
    private let maxHistoryCount = 50
    
    func handleError(_ error: Error, context: String = "") {
        let batchError: BatchProcessingError
        
        if let bpError = error as? BatchProcessingError {
            batchError = bpError
        } else {
            // Convert generic errors to batch processing errors
            batchError = mapGenericError(error)
        }
        
        // Record error
        let record = ErrorRecord(
            error: batchError,
            context: context,
            timestamp: Date(),
            userAction: nil
        )
        
        errorHistory.insert(record, at: 0)
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeLast()
        }
        
        // Show error to user for critical and error severity
        if batchError.severity == .error || batchError.severity == .critical {
            currentError = batchError
            showingError = true
        }
        
        // Log error for debugging
        logError(record)
    }
    
    func dismissError() {
        currentError = nil
        showingError = false
    }
    
    func retryLastAction() {
        // Implementation would depend on the context
        // For now, just dismiss the error
        dismissError()
    }
    
    private func mapGenericError(_ error: Error) -> BatchProcessingError {
        let errorString = error.localizedDescription
        
        if errorString.contains("network") || errorString.contains("internet") {
            return .networkError(underlying: errorString)
        } else if errorString.contains("permission") || errorString.contains("authorization") {
            return .insufficientPermissions(requiredRole: "适当权限")
        } else if errorString.contains("validation") {
            return .validationFailed(details: [errorString])
        } else {
            return .unexpectedState(state: errorString)
        }
    }
    
    private func logError(_ record: ErrorRecord) {
        print("🔴 BatchProcessingError: \(record.error)")
        print("   Context: \(record.context)")
        print("   Time: \(record.timestamp)")
    }
}

struct ErrorRecord {
    let error: BatchProcessingError
    let context: String
    let timestamp: Date
    let userAction: String?
}

// MARK: - Error Display Components (错误显示组件)

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandlingService
    
    func body(content: Content) -> some View {
        content
            .alert("错误", isPresented: $errorHandler.showingError, presenting: errorHandler.currentError) { error in
                Button("确定") {
                    errorHandler.dismissError()
                }
                
                if error.severity != .critical {
                    Button("重试") {
                        errorHandler.retryLastAction()
                    }
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.localizedDescription)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
    }
}

struct ErrorBannerView: View {
    let error: BatchProcessingError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.severity.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(error.severity.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("错误")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let onRetry = onRetry, error.severity != .critical {
                    Button("重试") {
                        onRetry()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("关闭") {
                    onDismiss()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(error.severity.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - View Extensions (视图扩展)

extension View {
    func errorHandling(_ errorHandler: ErrorHandlingService) -> some View {
        self.modifier(ErrorAlertModifier(errorHandler: errorHandler))
    }
}

// MARK: - Accessibility Support (无障碍访问支持)

struct AccessibilityIdentifiers {
    // Batch Processing
    static let batchCreationView = "batch_creation_view"
    static let batchEditView = "batch_edit_view"
    static let batchApprovalView = "batch_approval_view"
    
    // Date and Shift Selection
    static let dateSelector = "date_selector"
    static let shiftSelector = "shift_selector"
    static let morningShiftButton = "morning_shift_button"
    static let eveningShiftButton = "evening_shift_button"
    
    // Machine Selection
    static let machineSelector = "machine_selector"
    static let machineCard = "machine_card"
    
    // Product Configuration
    static let productList = "product_list"
    static let productCard = "product_card"
    static let addProductButton = "add_product_button"
    
    // Actions
    static let createBatchButton = "create_batch_button"
    static let saveBatchButton = "save_batch_button"
    static let approveBatchButton = "approve_batch_button"
    static let rejectBatchButton = "reject_batch_button"
    
    // Status Indicators
    static let timeRestrictionBanner = "time_restriction_banner"
    static let machineStatusIndicator = "machine_status_indicator"
    static let batchStatusBadge = "batch_status_badge"
    
    // Navigation
    static let backButton = "back_button"
    static let closeButton = "close_button"
    static let refreshButton = "refresh_button"
}

struct AccessibilityLabels {
    // Date and Shift
    static func dateOption(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "选择日期 \(formatter.string(from: date))"
    }
    
    static func shiftOption(_ shift: Shift, isAvailable: Bool) -> String {
        if isAvailable {
            return "\(shift.displayName)班次可用"
        } else {
            return "\(shift.displayName)班次不可用"
        }
    }
    
    // Machine
    static func machineOption(_ machine: WorkshopMachine) -> String {
        let status = machine.isOperational ? "运行正常" : "需要维护"
        return "机器 \(machine.name)，\(status)"
    }
    
    // Batch
    static func batchCard(_ batch: ProductionBatch) -> String {
        var description = "批次 \(batch.batchNumber)，状态 \(batch.status.displayName)"
        
        if let targetDate = batch.targetDate, let shift = batch.shift {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            description += "，\(formatter.string(from: targetDate)) \(shift.displayName)"
        }
        
        if batch.allowsColorModificationOnly {
            description += "，仅限颜色编辑"
        }
        
        return description
    }
}

struct AccessibilityHints {
    static let tapToSelect = "点击选择"
    static let tapToEdit = "点击编辑"
    static let tapToApprove = "点击审批"
    static let swipeToAction = "滑动执行操作"
    static let doubleTapToConfirm = "双击确认"
}

// MARK: - Dynamic Type Support (动态字体支持)

extension Font {
    static var batchTitle: Font {
        .system(.title2, design: .rounded, weight: .bold)
    }
    
    static var batchSubtitle: Font {
        .system(.body, design: .rounded, weight: .medium)
    }
    
    static var batchCaption: Font {
        .system(.caption, design: .rounded)
    }
    
    static var batchMonospace: Font {
        .system(.body, design: .monospaced, weight: .medium)
    }
}