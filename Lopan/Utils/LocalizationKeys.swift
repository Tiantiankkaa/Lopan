//
//  LocalizationKeys.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation

// MARK: - Localization Keys (本地化键值)

struct LocalizationKeys {
    
    // MARK: - Batch Processing (批次处理)
    
    struct BatchProcessing {
        static let title = "batch_processing_title"
        static let subtitle = "batch_processing_subtitle"
        static let createNewBatch = "create_new_batch"
        static let editBatch = "edit_batch"
        static let approveBatch = "approve_batch"
        static let rejectBatch = "reject_batch"
        static let submitBatch = "submit_batch"
        static let executeBatch = "execute_batch"
        
        // Status
        static let unsubmitted = "status_unsubmitted"
        static let pending = "status_pending"
        static let approved = "status_approved"
        static let active = "status_active"
        static let completed = "status_completed"
        static let rejected = "status_rejected"
        static let pendingExecution = "status_pending_execution"
    }
    
    // MARK: - Shifts (班次)
    
    struct Shifts {
        static let morning = "shift_morning"
        static let evening = "shift_evening"
        static let selectShift = "select_shift"
        static let shiftNotAvailable = "shift_not_available"
        static let shiftRestricted = "shift_restricted"
        
        // Time Policy
        static let cutoffTime = "cutoff_time"
        static let beforeCutoff = "before_cutoff"
        static let afterCutoff = "after_cutoff"
        static let timeRestriction = "time_restriction"
        static let normalTimeMode = "normal_time_mode"
        static let restrictedTimeMode = "restricted_time_mode"
    }
    
    // MARK: - Machines (机器)
    
    struct Machines {
        static let selectMachine = "select_machine"
        static let machineStatus = "machine_status"
        static let operational = "machine_operational"
        static let needsMaintenance = "machine_needs_maintenance"
        static let machineConflict = "machine_conflict"
        static let noMachinesAvailable = "no_machines_available"
        static let refreshMachineStatus = "refresh_machine_status"
    }
    
    // MARK: - Products (产品)
    
    struct Products {
        static let addProduct = "add_product"
        static let removeProduct = "remove_product"
        static let productConfiguration = "product_configuration"
        static let productName = "product_name"
        static let primaryColor = "primary_color"
        static let expectedOutput = "expected_output"
        static let priority = "priority"
        static let noProductsConfigured = "no_products_configured"
    }
    
    // MARK: - Colors (颜色)
    
    struct Colors {
        static let colorSelection = "color_selection"
        static let colorOnlyMode = "color_only_mode"
        static let colorOnlyRestriction = "color_only_restriction"
        static let selectColor = "select_color"
        static let invalidColor = "invalid_color"
    }
    
    // MARK: - Validation (验证)
    
    struct Validation {
        static let validationPassed = "validation_passed"
        static let validationFailed = "validation_failed"
        static let validationWarning = "validation_warning"
        static let checkRequirements = "check_requirements"
        static let timeValidation = "time_validation"
        static let machineValidation = "machine_validation"
        static let productValidation = "product_validation"
        static let conflictCheck = "conflict_check"
    }
    
    // MARK: - Approval (审批)
    
    struct Approval {
        static let approvalRequired = "approval_required"
        static let approvalNotes = "approval_notes"
        static let approveConfirmation = "approve_confirmation"
        static let rejectConfirmation = "reject_confirmation"
        static let rejectionReason = "rejection_reason"
        static let approvedBy = "approved_by"
        static let rejectedBy = "rejected_by"
        static let reviewedAt = "reviewed_at"
    }
    
    // MARK: - Actions (操作)
    
    struct Actions {
        static let save = "save"
        static let cancel = "cancel"
        static let close = "close"
        static let confirm = "confirm"
        static let retry = "retry"
        static let refresh = "refresh"
        static let back = "back"
        static let next = "next"
        static let create = "create"
        static let edit = "edit"
        static let delete = "delete"
        static let submit = "submit"
        static let approve = "approve"
        static let reject = "reject"
        static let execute = "execute"
    }
    
    // MARK: - Messages (消息)
    
    struct Messages {
        static let loading = "loading"
        static let saving = "saving"
        static let success = "success"
        static let error = "error"
        static let warning = "warning"
        static let noData = "no_data"
        static let dataLoaded = "data_loaded"
        static let operationCompleted = "operation_completed"
        static let operationFailed = "operation_failed"
    }
    
    // MARK: - Accessibility (无障碍访问)
    
    struct Accessibility {
        static let tapToSelect = "accessibility_tap_to_select"
        static let tapToEdit = "accessibility_tap_to_edit"
        static let tapToApprove = "accessibility_tap_to_approve"
        static let swipeToAction = "accessibility_swipe_to_action"
        static let doubleTabToConfirm = "accessibility_double_tap_to_confirm"
        static let selected = "accessibility_selected"
        static let available = "accessibility_available"
        static let unavailable = "accessibility_unavailable"
        static let restricted = "accessibility_restricted"
    }
}

// MARK: - Localized String Helper (本地化字符串助手)

func NSLocalizedString(_ key: String, value: String, comment: String = "") -> String {
    return NSLocalizedString(key, tableName: nil, bundle: Bundle.main, value: value, comment: comment)
}

// MARK: - String Extensions for Localization (本地化字符串扩展)

extension String {
    func localizedWithFallback(_ fallback: String) -> String {
        let localized = NSLocalizedString(self, value: "", comment: "")
        return localized.isEmpty ? fallback : localized
    }
}

// MARK: - Batch Status Localization (批次状态本地化)

extension BatchStatus {
    var localizedDisplayName: String {
        switch self {
        case .unsubmitted:
            return LocalizationKeys.BatchProcessing.unsubmitted.localized
        case .pending:
            return LocalizationKeys.BatchProcessing.pending.localized
        case .approved:
            return LocalizationKeys.BatchProcessing.approved.localized
        case .active:
            return LocalizationKeys.BatchProcessing.active.localized
        case .completed:
            return LocalizationKeys.BatchProcessing.completed.localized
        case .rejected:
            return LocalizationKeys.BatchProcessing.rejected.localized
        case .pendingExecution:
            return LocalizationKeys.BatchProcessing.pendingExecution.localized
        }
    }
}

// MARK: - Shift Localization (班次本地化)

extension Shift {
    var localizedDisplayName: String {
        switch self {
        case .morning:
            return LocalizationKeys.Shifts.morning.localized
        case .evening:
            return LocalizationKeys.Shifts.evening.localized
        }
    }
}

// MARK: - Production Mode Localization (生产模式本地化)

extension ProductionMode {
    var localizedDisplayName: String {
        switch self {
        case .singleColor:
            return "单色生产".localized
        case .dualColor:
            return "双色生产".localized
        }
    }
}

// MARK: - Validation Severity Localization (验证严重程度本地化)

extension BatchValidationResult.ValidationSeverity {
    var localizedDisplayName: String {
        switch self {
        case .info:
            return "信息"
        case .warning:
            return "警告"
        case .error:
            return "错误"
        }
    }
}

// MARK: - Default Localized Strings (默认本地化字符串)

// These would typically be in Localizable.strings files
struct DefaultLocalizedStrings {
    static let chineseStrings: [String: String] = [
        // Batch Processing
        "batch_processing_title": "批次处理",
        "batch_processing_subtitle": "按班次安排生产批次，精准控制生产节奏",
        "create_new_batch": "创建新批次",
        "edit_batch": "编辑批次",
        "approve_batch": "批准批次",
        "reject_batch": "拒绝批次",
        "submit_batch": "提交批次",
        "execute_batch": "执行批次",
        
        // Status
        "status_unsubmitted": "未提交",
        "status_pending": "待审批",
        "status_approved": "已批准",
        "status_active": "进行中",
        "status_completed": "已完成",
        "status_rejected": "已拒绝",
        "status_pending_execution": "待执行",
        
        // Shifts
        "shift_morning": "早班",
        "shift_evening": "晚班",
        "select_shift": "选择班次",
        "shift_not_available": "班次不可用",
        "shift_restricted": "班次受限",
        "cutoff_time": "截止时间",
        "before_cutoff": "截止前",
        "after_cutoff": "截止后",
        "time_restriction": "时间限制",
        "normal_time_mode": "正常时间模式",
        "restricted_time_mode": "限制时间模式",
        
        // Machines
        "select_machine": "选择机器",
        "machine_status": "机器状态",
        "machine_operational": "运行正常",
        "machine_needs_maintenance": "需要维护",
        "machine_conflict": "机器冲突",
        "no_machines_available": "无可用机器",
        "refresh_machine_status": "刷新机器状态",
        
        // Products
        "add_product": "添加产品",
        "remove_product": "移除产品",
        "product_configuration": "产品配置",
        "product_name": "产品名称",
        "primary_color": "主颜色",
        "expected_output": "预期产量",
        "priority": "优先级",
        "no_products_configured": "未配置产品",
        
        // Colors
        "color_selection": "颜色选择",
        "color_only_mode": "仅颜色模式",
        "color_only_restriction": "仅限颜色修改",
        "select_color": "选择颜色",
        "invalid_color": "无效颜色",
        
        // Validation
        "validation_passed": "验证通过",
        "validation_failed": "验证失败",
        "validation_warning": "验证警告",
        "check_requirements": "检查要求",
        "time_validation": "时间验证",
        "machine_validation": "机器验证",
        "product_validation": "产品验证",
        "conflict_check": "冲突检查",
        
        // Approval
        "approval_required": "需要审批",
        "approval_notes": "审批备注",
        "approve_confirmation": "确认批准",
        "reject_confirmation": "确认拒绝",
        "rejection_reason": "拒绝原因",
        "approved_by": "批准人",
        "rejected_by": "拒绝人",
        "reviewed_at": "审核时间",
        
        // Actions
        "save": "保存",
        "cancel": "取消",
        "close": "关闭",
        "confirm": "确认",
        "retry": "重试",
        "refresh": "刷新",
        "back": "返回",
        "next": "下一步",
        "create": "创建",
        "edit": "编辑",
        "delete": "删除",
        "submit": "提交",
        "approve": "批准",
        "reject": "拒绝",
        "execute": "执行",
        
        // Messages
        "loading": "加载中",
        "saving": "保存中",
        "success": "成功",
        "error": "错误",
        "warning": "警告",
        "no_data": "无数据",
        "data_loaded": "数据已加载",
        "operation_completed": "操作完成",
        "operation_failed": "操作失败",
        
        // Accessibility
        "accessibility_tap_to_select": "点击选择",
        "accessibility_tap_to_edit": "点击编辑",
        "accessibility_tap_to_approve": "点击审批",
        "accessibility_swipe_to_action": "滑动执行操作",
        "accessibility_double_tap_to_confirm": "双击确认",
        "accessibility_selected": "已选择",
        "accessibility_available": "可用",
        "accessibility_unavailable": "不可用",
        "accessibility_restricted": "受限"
    ]
}