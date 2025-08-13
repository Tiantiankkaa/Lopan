//
//  BatchEditPermissionService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation
import SwiftUI

// MARK: - Batch Edit Permission Protocol (批次编辑权限协议)
protocol BatchEditPermission {
    @MainActor func canEditProduct(_ product: ProductConfig, in batch: ProductionBatch) -> Bool
    @MainActor func canEditColor(_ product: ProductConfig, in batch: ProductionBatch) -> Bool
    @MainActor func canEditStructure(_ product: ProductConfig, in batch: ProductionBatch) -> Bool
    func getEditRestrictionReason(for batch: ProductionBatch) -> String?
    func validateEdit(originalProduct: ProductConfig, modifiedProduct: ProductConfig, in batch: ProductionBatch) -> BatchEditValidationResult
}

// MARK: - Batch Edit Validation Result (批次编辑验证结果)
enum BatchEditValidationResult {
    case allowed
    case colorOnlyAllowed(reason: String)
    case blocked(reason: String)
    
    var isAllowed: Bool {
        switch self {
        case .allowed, .colorOnlyAllowed:
            return true
        case .blocked:
            return false
        }
    }
    
    var isColorOnlyRestricted: Bool {
        switch self {
        case .colorOnlyAllowed:
            return true
        case .allowed, .blocked:
            return false
        }
    }
    
    var reason: String? {
        switch self {
        case .allowed:
            return nil
        case .colorOnlyAllowed(let reason), .blocked(let reason):
            return reason
        }
    }
}

// MARK: - Standard Batch Edit Permission Service (标准批次编辑权限服务)
@MainActor
class StandardBatchEditPermissionService: ObservableObject, BatchEditPermission {
    
    private let authService: AuthenticationService
    
    init(authService: AuthenticationService) {
        self.authService = authService
    }
    
    // MARK: - Permission Checks (权限检查)
    
    func canEditProduct(_ product: ProductConfig, in batch: ProductionBatch) -> Bool {
        // Check user permissions first
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            return false
        }
        
        // Check batch status
        guard batch.status == .unsubmitted else {
            return false
        }
        
        // For shift-aware batches, check color-only restriction
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            return canEditColor(product, in: batch)
        }
        
        return true
    }
    
    func canEditColor(_ product: ProductConfig, in batch: ProductionBatch) -> Bool {
        // Check user permissions first
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            return false
        }
        
        // Check batch status
        guard batch.status == .unsubmitted else {
            return false
        }
        
        // Color editing is always allowed for unsubmitted batches
        return true
    }
    
    func canEditStructure(_ product: ProductConfig, in batch: ProductionBatch) -> Bool {
        // Check user permissions first
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            return false
        }
        
        // Check batch status
        guard batch.status == .unsubmitted else {
            return false
        }
        
        // For shift-aware batches with color-only restriction, structure editing is not allowed
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            return false
        }
        
        return true
    }
    
    func getEditRestrictionReason(for batch: ProductionBatch) -> String? {
        // Check user permissions
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            return "无操作权限"
        }
        
        // Check batch status
        guard batch.status == .unsubmitted else {
            return "只能编辑未提交的批次"
        }
        
        // Check shift-aware restrictions
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            return "班次批次仅支持颜色修改，产品结构变更请前往\"生产配置\""
        }
        
        return nil
    }
    
    func validateEdit(
        originalProduct: ProductConfig, 
        modifiedProduct: ProductConfig, 
        in batch: ProductionBatch
    ) -> BatchEditValidationResult {
        
        // Check basic edit permissions
        guard canEditProduct(originalProduct, in: batch) else {
            if let reason = getEditRestrictionReason(for: batch) {
                return .blocked(reason: reason)
            }
            return .blocked(reason: "无编辑权限")
        }
        
        // For shift-aware batches with color-only restriction
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            if isOnlyColorModification(original: originalProduct, modified: modifiedProduct) {
                return .allowed
            } else {
                return .colorOnlyAllowed(reason: "仅允许颜色修改，其他变更请前往\"生产配置\"")
            }
        }
        
        return .allowed
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func isOnlyColorModification(original: ProductConfig, modified: ProductConfig) -> Bool {
        // Check that only color fields have changed
        return original.productName == modified.productName &&
               original.occupiedStations == modified.occupiedStations &&
               original.stationCount == modified.stationCount &&
               original.gunAssignment == modified.gunAssignment &&
               original.expectedOutput == modified.expectedOutput &&
               original.priority == modified.priority &&
               original.productId == modified.productId
    }
    
    // MARK: - Batch-level Validation (批次级验证)
    
    func validateBatchForColorOnlyEditing(_ batch: ProductionBatch) -> Bool {
        return batch.isShiftBatch && batch.allowsColorModificationOnly
    }
    
    func shouldRedirectToProductionConfiguration(for batch: ProductionBatch, attemptedAction: BatchEditAction) -> Bool {
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            switch attemptedAction {
            case .modifyProductStructure, .addProduct, .removeProduct:
                return true
            case .modifyColors:
                return false
            }
        }
        return false
    }
    
    func getRedirectionMessage(for action: BatchEditAction) -> String {
        switch action {
        case .modifyProductStructure:
            return "产品结构修改需前往\"生产配置\"进行"
        case .addProduct:
            return "添加产品需前往\"生产配置\"进行"
        case .removeProduct:
            return "删除产品需前往\"生产配置\"进行"
        case .modifyColors:
            return "" // No redirection needed for color modifications
        }
    }
    
    // MARK: - User Guidance (用户指引)
    
    func getEditGuidance(for batch: ProductionBatch) -> BatchEditGuidance {
        if let restriction = getEditRestrictionReason(for: batch) {
            return BatchEditGuidance(
                canEdit: false,
                colorOnlyMode: false,
                message: restriction,
                redirectToProductionConfig: false
            )
        }
        
        if batch.isShiftBatch && batch.allowsColorModificationOnly {
            return BatchEditGuidance(
                canEdit: true,
                colorOnlyMode: true,
                message: "当前批次仅支持颜色修改",
                redirectToProductionConfig: true
            )
        }
        
        return BatchEditGuidance(
            canEdit: true,
            colorOnlyMode: false,
            message: "可以进行完整编辑",
            redirectToProductionConfig: false
        )
    }
}

// MARK: - Supporting Types (支持类型)

enum BatchEditAction {
    case modifyProductStructure
    case modifyColors
    case addProduct
    case removeProduct
}

struct BatchEditGuidance {
    let canEdit: Bool
    let colorOnlyMode: Bool
    let message: String
    let redirectToProductionConfig: Bool
    
    var allowsStructuralChanges: Bool {
        return canEdit && !colorOnlyMode
    }
    
    var allowsColorChanges: Bool {
        return canEdit
    }
}

// MARK: - Error Types (错误类型)
enum BatchEditPermissionError: LocalizedError {
    case insufficientPermissions
    case batchNotEditable
    case colorOnlyRestriction
    case structuralChangeNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "无足够权限进行此操作"
        case .batchNotEditable:
            return "当前批次状态不允许编辑"
        case .colorOnlyRestriction:
            return "当前批次仅允许颜色修改"
        case .structuralChangeNotAllowed:
            return "产品结构变更请前往\"生产配置\"进行"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientPermissions:
            return "请联系管理员获取相应权限"
        case .batchNotEditable:
            return "请检查批次状态"
        case .colorOnlyRestriction, .structuralChangeNotAllowed:
            return "如需修改产品结构，请前往\"生产配置\"功能"
        }
    }
}

// MARK: - Mock Edit Permission Service (for testing) (测试用模拟服务)
class MockBatchEditPermissionService: BatchEditPermission {
    
    var allowProductEdit = true
    var allowColorEdit = true
    var allowStructureEdit = true
    var restrictionReason: String?
    var validationResult: BatchEditValidationResult = .allowed
    
    func canEditProduct(_ product: ProductConfig, in batch: ProductionBatch) -> Bool {
        return allowProductEdit
    }
    
    func canEditColor(_ product: ProductConfig, in batch: ProductionBatch) -> Bool {
        return allowColorEdit
    }
    
    func canEditStructure(_ product: ProductConfig, in batch: ProductionBatch) -> Bool {
        return allowStructureEdit
    }
    
    func getEditRestrictionReason(for batch: ProductionBatch) -> String? {
        return restrictionReason
    }
    
    func validateEdit(originalProduct: ProductConfig, modifiedProduct: ProductConfig, in batch: ProductionBatch) -> BatchEditValidationResult {
        return validationResult
    }
}

// MARK: - Convenience Extensions (便利扩展)
extension ProductionBatch {
    
    @MainActor func editGuidance(using permissionService: BatchEditPermission) -> BatchEditGuidance {
        if let service = permissionService as? StandardBatchEditPermissionService {
            return service.getEditGuidance(for: self)
        }
        
        // Fallback implementation
        let canEdit = permissionService.canEditProduct(products.first ?? ProductConfig(batchId: id, productName: "", primaryColorId: "", occupiedStations: []), in: self)
        let colorOnly = isShiftBatch && allowsColorModificationOnly
        
        return BatchEditGuidance(
            canEdit: canEdit,
            colorOnlyMode: colorOnly,
            message: colorOnly ? "仅支持颜色修改" : "可以进行编辑",
            redirectToProductionConfig: colorOnly
        )
    }
}