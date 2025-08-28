//
//  BatchValidationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation
import SwiftUI

// MARK: - Batch Validation Service (批次验证服务)
@MainActor
public class BatchValidationService: ObservableObject {
    
    private let repositoryFactory: RepositoryFactory
    private let authService: AuthenticationService
    private let dateShiftPolicy: DateShiftPolicy
    private let timeProvider: TimeProvider
    
    @Published var validationResults: [BatchValidationResult] = []
    @Published var isValidating = false
    
    init(
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        dateShiftPolicy: DateShiftPolicy = StandardDateShiftPolicy(),
        timeProvider: TimeProvider = SystemTimeProvider()
    ) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.dateShiftPolicy = dateShiftPolicy
        self.timeProvider = timeProvider
    }
    
    // MARK: - Cross-Time-Point Validation (跨时间点验证)
    
    func validateCrossTimePointOperation(
        batch: ProductionBatch,
        operation: BatchValidationOperation
    ) async -> CrossTimeValidationResult {
        
        let currentTime = timeProvider.now
        
        // Check if operation is being performed across different time contexts
        let batchCreationTime = batch.submittedAt
        guard let targetDate = batch.targetDate,
              let shift = batch.shift else {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "批次缺少必要的时间信息",
                recommendedAction: .requireRefresh
            )
        }
        
        // Validate time consistency
        let creationPolicy = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: batchCreationTime)
        let currentPolicy = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: currentTime)
        
        // Check if time policies have changed
        if creationPolicy.hasRestriction != currentPolicy.hasRestriction {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "时间政策已变更，需要重新验证批次",
                recommendedAction: .requirePolicyUpdate,
                details: CrossTimeValidationDetails(
                    creationTimeRestriction: creationPolicy.hasRestriction,
                    currentTimeRestriction: currentPolicy.hasRestriction,
                    operationTime: currentTime,
                    batchCreationTime: batchCreationTime
                )
            )
        }
        
        // Check if shift is still available
        let allowedShifts = dateShiftPolicy.allowedShifts(for: targetDate, currentTime: currentTime)
        if !allowedShifts.contains(shift) {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "所选班次在当前时间不再可用",
                recommendedAction: .requireShiftChange,
                details: CrossTimeValidationDetails(
                    creationTimeRestriction: creationPolicy.hasRestriction,
                    currentTimeRestriction: currentPolicy.hasRestriction,
                    operationTime: currentTime,
                    batchCreationTime: batchCreationTime,
                    availableShifts: allowedShifts
                )
            )
        }
        
        // Operation-specific validation
        switch operation {
        case .edit:
            return await validateEditOperation(batch: batch, currentTime: currentTime)
        case .submit:
            return await validateSubmitOperation(batch: batch, currentTime: currentTime)
        case .approve:
            return await validateApprovalOperation(batch: batch, currentTime: currentTime)
        case .execute:
            return await validateExecutionOperation(batch: batch, currentTime: currentTime)
        }
    }
    
    private func validateEditOperation(batch: ProductionBatch, currentTime: Date) async -> CrossTimeValidationResult {
        // Check if batch can still be edited based on current time
        guard batch.status == .unsubmitted else {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "只能编辑未提交的批次",
                recommendedAction: .blockOperation
            )
        }
        
        // If it's a shift batch with color-only restriction, validate accordingly
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            guard let targetDate = batch.targetDate else {
                return CrossTimeValidationResult(
                    isValid: false,
                    reason: "班次批次缺少目标日期",
                    recommendedAction: .requireRefresh
                )
            }
            
            let cutoffInfo = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: currentTime)
            if cutoffInfo.hasRestriction {
                return CrossTimeValidationResult(
                    isValid: true,
                    reason: "仅限颜色编辑模式",
                    recommendedAction: .allowWithRestrictions,
                    restrictions: [.colorOnlyEditing]
                )
            }
        }
        
        return CrossTimeValidationResult(isValid: true, reason: "编辑操作有效")
    }
    
    private func validateSubmitOperation(batch: ProductionBatch, currentTime: Date) async -> CrossTimeValidationResult {
        // Check machine conflicts
        do {
            if let targetDate = batch.targetDate, let shift = batch.shift {
                let hasConflict = try await repositoryFactory.productionBatchRepository.hasConflictingBatches(
                    forDate: targetDate,
                    shift: shift,
                    machineId: batch.machineId,
                    excludingBatchId: batch.id
                )
                
                if hasConflict {
                    return CrossTimeValidationResult(
                        isValid: false,
                        reason: "存在机器时段冲突",
                        recommendedAction: .requireConflictResolution
                    )
                }
            }
        } catch {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "无法验证机器冲突: \(error.localizedDescription)",
                recommendedAction: .requireRefresh
            )
        }
        
        return CrossTimeValidationResult(isValid: true, reason: "提交操作有效")
    }
    
    private func validateApprovalOperation(batch: ProductionBatch, currentTime: Date) async -> CrossTimeValidationResult {
        // Check if user has approval permissions
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "无审批权限",
                recommendedAction: .blockOperation
            )
        }
        
        guard batch.status == .pending else {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "批次不在待审批状态",
                recommendedAction: .requireRefresh
            )
        }
        
        // Check machine status at approval time
        do {
            let machine = try await repositoryFactory.machineRepository.fetchMachineById(batch.machineId)
            if machine == nil || machine?.isOperational != true {
                return CrossTimeValidationResult(
                    isValid: false,
                    reason: "指定机器当前不可用或需要维护",
                    recommendedAction: .requireMachineCheck
                )
            }
        } catch {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "无法验证机器状态",
                recommendedAction: .requireRefresh
            )
        }
        
        return CrossTimeValidationResult(isValid: true, reason: "审批操作有效")
    }
    
    private func validateExecutionOperation(batch: ProductionBatch, currentTime: Date) async -> CrossTimeValidationResult {
        guard batch.status == .pendingExecution else {
            return CrossTimeValidationResult(
                isValid: false,
                reason: "批次不在待执行状态",
                recommendedAction: .requireRefresh
            )
        }
        
        // Check if target date/shift is still valid for execution
        if let targetDate = batch.targetDate, let shift = batch.shift {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: currentTime)
            let batchDate = calendar.startOfDay(for: targetDate)
            
            // Can't execute batches for past dates
            if batchDate < today {
                return CrossTimeValidationResult(
                    isValid: false,
                    reason: "无法执行过期批次",
                    recommendedAction: .blockOperation
                )
            }
            
            // For today's batches, check shift timing
            if calendar.isDate(targetDate, inSameDayAs: currentTime) {
                let currentHour = calendar.component(.hour, from: currentTime)
                
                switch shift {
                case .morning:
                    if currentHour > 12 {
                        return CrossTimeValidationResult(
                            isValid: false,
                            reason: "早班执行时间已过",
                            recommendedAction: .blockOperation
                        )
                    }
                case .evening:
                    if currentHour < 12 {
                        return CrossTimeValidationResult(
                            isValid: true,
                            reason: "可提前执行晚班",
                            recommendedAction: .allowWithWarning
                        )
                    }
                }
            }
        }
        
        return CrossTimeValidationResult(isValid: true, reason: "执行操作有效")
    }
    
    // MARK: - Comprehensive Batch Validation (全面批次验证)
    
    func validateBatchComprehensively(_ batch: ProductionBatch) async -> BatchValidationSummary {
        isValidating = true
        defer { isValidating = false }
        
        var issues: [BatchValidationIssue] = []
        var warnings: [BatchValidationWarning] = []
        
        // Basic batch validation
        if batch.products.isEmpty {
            issues.append(BatchValidationIssue(
                type: .missingProducts,
                message: "批次未配置任何产品",
                severity: .error
            ))
        }
        
        // Shift-specific validation
        if batch.isShiftBatch {
            let shiftValidation = await validateShiftBatch(batch)
            issues.append(contentsOf: shiftValidation.issues)
            warnings.append(contentsOf: shiftValidation.warnings)
        }
        
        // Machine validation
        let machineValidation = await validateMachineAssignment(batch)
        issues.append(contentsOf: machineValidation.issues)
        warnings.append(contentsOf: machineValidation.warnings)
        
        // Product configuration validation
        let productValidation = await validateProductConfigurations(batch)
        issues.append(contentsOf: productValidation.issues)
        warnings.append(contentsOf: productValidation.warnings)
        
        // Time consistency validation
        let timeValidation = await validateTimeConsistency(batch)
        issues.append(contentsOf: timeValidation.issues)
        warnings.append(contentsOf: timeValidation.warnings)
        
        return BatchValidationSummary(
            batch: batch,
            isValid: issues.filter { $0.severity == .error }.isEmpty,
            issues: issues,
            warnings: warnings,
            validatedAt: timeProvider.now
        )
    }
    
    private func validateShiftBatch(_ batch: ProductionBatch) async -> (issues: [BatchValidationIssue], warnings: [BatchValidationWarning]) {
        var issues: [BatchValidationIssue] = []
        var warnings: [BatchValidationWarning] = []
        
        guard batch.isShiftBatch else { return (issues, warnings) }
        
        guard let targetDate = batch.targetDate else {
            issues.append(BatchValidationIssue(
                type: .invalidShiftConfiguration,
                message: "班次批次缺少目标日期",
                severity: .error
            ))
            return (issues, warnings)
        }
        
        guard let shift = batch.shift else {
            issues.append(BatchValidationIssue(
                type: .invalidShiftConfiguration,
                message: "班次批次缺少班次信息",
                severity: .error
            ))
            return (issues, warnings)
        }
        
        // Check if shift is still valid
        let currentTime = timeProvider.now
        let allowedShifts = dateShiftPolicy.allowedShifts(for: targetDate, currentTime: currentTime)
        
        if !allowedShifts.contains(shift) {
            issues.append(BatchValidationIssue(
                type: .invalidShiftTiming,
                message: "所选班次在当前时间不可用",
                severity: .error
            ))
        }
        
        // Check for time policy changes
        let submittedAt = batch.submittedAt
        let creationPolicy = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: submittedAt)
        let currentPolicy = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: currentTime)
        
        if creationPolicy.hasRestriction != currentPolicy.hasRestriction {
            warnings.append(BatchValidationWarning(
                type: .timePolicyChanged,
                message: "时间政策自创建以来已发生变化",
                recommendation: "建议重新验证批次设置"
            ))
        }
        
        return (issues, warnings)
    }
    
    private func validateMachineAssignment(_ batch: ProductionBatch) async -> (issues: [BatchValidationIssue], warnings: [BatchValidationWarning]) {
        var issues: [BatchValidationIssue] = []
        var warnings: [BatchValidationWarning] = []
        
        do {
            guard let machine = try await repositoryFactory.machineRepository.fetchMachineById(batch.machineId) else {
                issues.append(BatchValidationIssue(
                    type: .machineNotFound,
                    message: "指定的机器不存在",
                    severity: .error
                ))
                return (issues, warnings)
            }
            
            if !machine.isOperational {
                issues.append(BatchValidationIssue(
                    type: .machineNotOperational,
                    message: "指定机器当前不可操作",
                    severity: .error
                ))
            }
            
            // Check for machine conflicts
            if let targetDate = batch.targetDate, let shift = batch.shift {
                let hasConflict = try await repositoryFactory.productionBatchRepository.hasConflictingBatches(
                    forDate: targetDate,
                    shift: shift,
                    machineId: batch.machineId,
                    excludingBatchId: batch.id
                )
                
                if hasConflict {
                    issues.append(BatchValidationIssue(
                        type: .machineTimeConflict,
                        message: "机器在指定时段已被其他批次占用",
                        severity: .error
                    ))
                }
            }
            
        } catch {
            issues.append(BatchValidationIssue(
                type: .validationError,
                message: "机器验证失败: \(error.localizedDescription)",
                severity: .error
            ))
        }
        
        return (issues, warnings)
    }
    
    private func validateProductConfigurations(_ batch: ProductionBatch) async -> (issues: [BatchValidationIssue], warnings: [BatchValidationWarning]) {
        var issues: [BatchValidationIssue] = []
        var warnings: [BatchValidationWarning] = []
        
        do {
            let productConfigs = try await repositoryFactory.productionBatchRepository.fetchProductConfigs(forBatch: batch.id)
            
            if productConfigs.isEmpty {
                issues.append(BatchValidationIssue(
                    type: .missingProducts,
                    message: "批次未配置任何产品",
                    severity: .error
                ))
            }
            
            // Validation for product configuration conflicts could be added here
            
            // Validate color assignments
            let availableColors = try await repositoryFactory.colorRepository.fetchAllColors()
            let availableColorIds = Set(availableColors.map { $0.id })
            
            for config in productConfigs {
                if !availableColorIds.contains(config.primaryColorId) {
                    warnings.append(BatchValidationWarning(
                        type: .invalidColorAssignment,
                        message: "产品 \(config.productName) 使用了不存在的颜色",
                        recommendation: "请重新选择有效的颜色"
                    ))
                }
            }
            
        } catch {
            issues.append(BatchValidationIssue(
                type: .validationError,
                message: "产品配置验证失败: \(error.localizedDescription)",
                severity: .error
            ))
        }
        
        return (issues, warnings)
    }
    
    private func validateTimeConsistency(_ batch: ProductionBatch) async -> (issues: [BatchValidationIssue], warnings: [BatchValidationWarning]) {
        var issues: [BatchValidationIssue] = []
        var warnings: [BatchValidationWarning] = []
        
        let currentTime = timeProvider.now
        
        // Check if batch is for a past date
        if let targetDate = batch.targetDate {
            let calendar = Calendar.current
            if calendar.startOfDay(for: targetDate) < calendar.startOfDay(for: currentTime) {
                issues.append(BatchValidationIssue(
                    type: .pastDateBatch,
                    message: "批次目标日期已过期",
                    severity: .error
                ))
            }
        }
        
        // Check submission timing consistency
        let submittedAt = batch.submittedAt
        if let targetDate = batch.targetDate, let shift = batch.shift {
            let submissionPolicy = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: submittedAt)
            let allowedShiftsAtSubmission = dateShiftPolicy.allowedShifts(for: targetDate, currentTime: submittedAt)
            
            if !allowedShiftsAtSubmission.contains(shift) {
                warnings.append(BatchValidationWarning(
                    type: .inconsistentSubmissionTiming,
                    message: "批次提交时间与班次选择不一致",
                    recommendation: "建议检查批次创建时间和班次选择的合理性"
                ))
            }
        }
        
        return (issues, warnings)
    }
}

// MARK: - Supporting Types (支持类型)

struct BatchValidationResult {
    let isValid: Bool
    let message: String
    let severity: ValidationSeverity
    let affectedProducts: [ProductConfig]
    
    enum ValidationSeverity {
        case info, warning, error
    }
}

enum BatchValidationOperation {
    case edit
    case submit
    case approve
    case execute
}

struct CrossTimeValidationResult {
    let isValid: Bool
    let reason: String
    let recommendedAction: ValidationAction
    let restrictions: [BatchRestriction]
    let details: CrossTimeValidationDetails?
    
    init(
        isValid: Bool,
        reason: String,
        recommendedAction: ValidationAction = .allowOperation,
        restrictions: [BatchRestriction] = [],
        details: CrossTimeValidationDetails? = nil
    ) {
        self.isValid = isValid
        self.reason = reason
        self.recommendedAction = recommendedAction
        self.restrictions = restrictions
        self.details = details
    }
}

struct CrossTimeValidationDetails {
    let creationTimeRestriction: Bool
    let currentTimeRestriction: Bool
    let operationTime: Date
    let batchCreationTime: Date
    let availableShifts: Set<Shift>?
    
    init(
        creationTimeRestriction: Bool,
        currentTimeRestriction: Bool,
        operationTime: Date,
        batchCreationTime: Date,
        availableShifts: Set<Shift>? = nil
    ) {
        self.creationTimeRestriction = creationTimeRestriction
        self.currentTimeRestriction = currentTimeRestriction
        self.operationTime = operationTime
        self.batchCreationTime = batchCreationTime
        self.availableShifts = availableShifts
    }
}

enum ValidationAction {
    case allowOperation
    case allowWithWarning
    case allowWithRestrictions
    case requireRefresh
    case requirePolicyUpdate
    case requireShiftChange
    case requireConflictResolution
    case requireMachineCheck
    case blockOperation
}

enum BatchRestriction {
    case colorOnlyEditing
    case noStructuralChanges
    case requireApproval
    case timeLimited
}

struct BatchValidationSummary {
    let batch: ProductionBatch
    let isValid: Bool
    let issues: [BatchValidationIssue]
    let warnings: [BatchValidationWarning]
    let validatedAt: Date
    
    var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }
    
    var hasWarnings: Bool {
        !warnings.isEmpty
    }
    
    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }
    
    var warningCount: Int {
        warnings.count
    }
}

struct BatchValidationIssue {
    let type: ValidationIssueType
    let message: String
    let severity: ValidationSeverity
}

struct BatchValidationWarning {
    let type: ValidationWarningType
    let message: String
    let recommendation: String
}

enum ValidationIssueType {
    case missingProducts
    case invalidShiftConfiguration
    case invalidShiftTiming
    case machineNotFound
    case machineNotOperational
    case machineTimeConflict
    case pastDateBatch
    case validationError
}

enum ValidationWarningType {
    case timePolicyChanged
    case duplicatePriorities
    case invalidColorAssignment
    case inconsistentSubmissionTiming
}

enum ValidationSeverity {
    case error
    case warning
    case info
}