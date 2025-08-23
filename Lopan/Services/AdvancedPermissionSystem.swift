//
//  AdvancedPermissionSystem.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Core Permission Types (核心权限类型)

/// Granular permission definitions for fine-grained access control
/// 细粒度权限定义，用于精细访问控制
enum Permission: String, CaseIterable, Codable {
    // Data Management Permissions (数据管理权限)
    case createBatch = "create_batch"
    case editBatch = "edit_batch"
    case deleteBatch = "delete_batch"
    case viewBatch = "view_batch"
    case approveBatch = "approve_batch"
    case completeBatch = "complete_batch"
    
    // Machine Management Permissions (机台管理权限)
    case createMachine = "create_machine"
    case editMachine = "edit_machine"
    case deleteMachine = "delete_machine"
    case viewMachine = "view_machine"
    case operateMachine = "operate_machine"
    case maintainMachine = "maintain_machine"
    case resetMachine = "reset_machine"
    
    // User Management Permissions (用户管理权限)
    case createUser = "create_user"
    case editUser = "edit_user"
    case deleteUser = "delete_user"
    case viewUser = "view_user"
    case assignRole = "assign_role"
    case managePermissions = "manage_permissions"
    
    // System Administration Permissions (系统管理权限)
    case viewSystemHealth = "view_system_health"
    case configureSystem = "configure_system"
    case generateReports = "generate_reports"
    case accessAnalytics = "access_analytics"
    case manageNotifications = "manage_notifications"
    case viewAuditLogs = "view_audit_logs"
    case exportData = "export_data"
    case importData = "import_data"
    case backupData = "backup_data"
    case restoreData = "restore_data"
    case manageSystemSettings = "manage_system_settings"
    case viewSystemConfiguration = "view_system_configuration"
    case approveConfigurationChanges = "approve_configuration_changes"
    case manageSystemSecurity = "manage_system_security"
    case performSecurityScan = "perform_security_scan"
    case manageDeployments = "manage_deployments"
    case executeDeployments = "execute_deployments"
    case executeRollbacks = "execute_rollbacks"
    case monitorSystemHealth = "monitor_system_health"
    case executeRecoveryActions = "execute_recovery_actions"
    
    // Production Management Permissions (生产管理权限)
    case createProductionConfig = "create_production_config"
    case editProductionConfig = "edit_production_config"
    case viewProductionConfig = "view_production_config"
    case scheduleProduction = "schedule_production"
    case monitorProduction = "monitor_production"
    case qualityControl = "quality_control"
    
    // Inventory Management Permissions (库存管理权限)
    case manageInventory = "manage_inventory"
    case viewInventory = "view_inventory"
    case updateStock = "update_stock"
    case manageSuppliers = "manage_suppliers"
    
    // Customer Management Permissions (客户管理权限)
    case createCustomer = "create_customer"
    case editCustomer = "edit_customer"
    case deleteCustomer = "delete_customer"
    case viewCustomer = "view_customer"
    case manageCustomerOrders = "manage_customer_orders"
    
    var displayName: String {
        switch self {
        case .createBatch: return "创建批次"
        case .editBatch: return "编辑批次"
        case .deleteBatch: return "删除批次"
        case .viewBatch: return "查看批次"
        case .approveBatch: return "审批批次"
        case .completeBatch: return "完成批次"
        case .createMachine: return "创建机台"
        case .editMachine: return "编辑机台"
        case .deleteMachine: return "删除机台"
        case .viewMachine: return "查看机台"
        case .operateMachine: return "操作机台"
        case .maintainMachine: return "维护机台"
        case .resetMachine: return "重置机台"
        case .createUser: return "创建用户"
        case .editUser: return "编辑用户"
        case .deleteUser: return "删除用户"
        case .viewUser: return "查看用户"
        case .assignRole: return "分配角色"
        case .managePermissions: return "管理权限"
        case .viewSystemHealth: return "查看系统健康"
        case .configureSystem: return "配置系统"
        case .generateReports: return "生成报告"
        case .accessAnalytics: return "访问分析"
        case .manageNotifications: return "管理通知"
        case .viewAuditLogs: return "查看审计日志"
        case .exportData: return "导出数据"
        case .importData: return "导入数据"
        case .backupData: return "备份数据"
        case .restoreData: return "恢复数据"
        case .manageSystemSettings: return "管理系统设置"
        case .viewSystemConfiguration: return "查看系统配置"
        case .approveConfigurationChanges: return "审批配置变更"
        case .manageSystemSecurity: return "管理系统安全"
        case .performSecurityScan: return "执行安全扫描"
        case .manageDeployments: return "管理部署"
        case .executeDeployments: return "执行部署"
        case .executeRollbacks: return "执行回滚"
        case .monitorSystemHealth: return "监控系统健康"
        case .executeRecoveryActions: return "执行恢复操作"
        case .createProductionConfig: return "创建生产配置"
        case .editProductionConfig: return "编辑生产配置"
        case .viewProductionConfig: return "查看生产配置"
        case .scheduleProduction: return "安排生产"
        case .monitorProduction: return "监控生产"
        case .qualityControl: return "质量控制"
        case .manageInventory: return "管理库存"
        case .viewInventory: return "查看库存"
        case .updateStock: return "更新库存"
        case .manageSuppliers: return "管理供应商"
        case .createCustomer: return "创建客户"
        case .editCustomer: return "编辑客户"
        case .deleteCustomer: return "删除客户"
        case .viewCustomer: return "查看客户"
        case .manageCustomerOrders: return "管理客户订单"
        }
    }
    
    var category: PermissionCategory {
        switch self {
        case .createBatch, .editBatch, .deleteBatch, .viewBatch, .approveBatch, .completeBatch:
            return .batchManagement
        case .createMachine, .editMachine, .deleteMachine, .viewMachine, .operateMachine, .maintainMachine, .resetMachine:
            return .machineManagement
        case .createUser, .editUser, .deleteUser, .viewUser, .assignRole, .managePermissions:
            return .userManagement
        case .viewSystemHealth, .configureSystem, .generateReports, .accessAnalytics, .manageNotifications, .viewAuditLogs, .exportData, .importData, .backupData, .restoreData, .manageSystemSettings, .viewSystemConfiguration, .approveConfigurationChanges, .manageSystemSecurity, .performSecurityScan, .manageDeployments, .executeDeployments, .executeRollbacks, .monitorSystemHealth, .executeRecoveryActions:
            return .systemAdministration
        case .createProductionConfig, .editProductionConfig, .viewProductionConfig, .scheduleProduction, .monitorProduction, .qualityControl:
            return .productionManagement
        case .manageInventory, .viewInventory, .updateStock, .manageSuppliers:
            return .inventoryManagement
        case .createCustomer, .editCustomer, .deleteCustomer, .viewCustomer, .manageCustomerOrders:
            return .customerManagement
        }
    }
}

/// Permission categories for organizational purposes
/// 权限分类，用于组织目的
enum PermissionCategory: String, CaseIterable, Codable {
    case batchManagement = "batch_management"
    case machineManagement = "machine_management"
    case userManagement = "user_management"
    case systemAdministration = "system_administration"
    case productionManagement = "production_management"
    case inventoryManagement = "inventory_management"
    case customerManagement = "customer_management"
    
    var displayName: String {
        switch self {
        case .batchManagement: return "批次管理"
        case .machineManagement: return "机台管理"
        case .userManagement: return "用户管理"
        case .systemAdministration: return "系统管理"
        case .productionManagement: return "生产管理"
        case .inventoryManagement: return "库存管理"
        case .customerManagement: return "客户管理"
        }
    }
    
    var icon: String {
        switch self {
        case .batchManagement: return "folder.badge.gearshape"
        case .machineManagement: return "gear.circle"
        case .userManagement: return "person.3.circle"
        case .systemAdministration: return "gearshape.2"
        case .productionManagement: return "factory"
        case .inventoryManagement: return "cube.box"
        case .customerManagement: return "person.2.circle"
        }
    }
}

// MARK: - Permission Context (权限上下文)

/// Context information for permission evaluation
/// 权限评估的上下文信息
struct PermissionContext {
    let userId: String
    let targetEntityId: String?
    let targetEntityType: String?
    let additionalData: [String: Any]
    let timestamp: Date
    
    init(userId: String, targetEntityId: String? = nil, targetEntityType: String? = nil, additionalData: [String: Any] = [:]) {
        self.userId = userId
        self.targetEntityId = targetEntityId
        self.targetEntityType = targetEntityType
        self.additionalData = additionalData
        self.timestamp = Date()
    }
}

/// Result of permission evaluation
/// 权限评估结果
struct PermissionResult {
    let permission: Permission
    let isGranted: Bool
    let reason: String
    let context: PermissionContext
    let evaluatedAt: Date
    let grantedBy: [String] // Role or permission source
    
    init(permission: Permission, isGranted: Bool, reason: String, context: PermissionContext, grantedBy: [String] = []) {
        self.permission = permission
        self.isGranted = isGranted
        self.reason = reason
        self.context = context
        self.evaluatedAt = Date()
        self.grantedBy = grantedBy
    }
}

// MARK: - Permission Rules (权限规则)

/// Time-based permission constraints
/// 基于时间的权限约束
struct TimeConstraint: Codable {
    let startTime: Date?
    let endTime: Date?
    let daysOfWeek: [Int]? // 1 = Sunday, 7 = Saturday
    let timeOfDayStart: String? // "HH:mm" format
    let timeOfDayEnd: String? // "HH:mm" format
    
    func isValid(at date: Date = Date()) -> Bool {
        // Check date range
        if let start = startTime, date < start { return false }
        if let end = endTime, date > end { return false }
        
        // Check day of week
        if let allowedDays = daysOfWeek {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            if !allowedDays.contains(weekday) { return false }
        }
        
        // Check time of day
        if let startTime = timeOfDayStart, let endTime = timeOfDayEnd {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let currentTime = String(format: "%02d:%02d", hour, minute)
            
            if startTime <= endTime {
                // Same day range
                return currentTime >= startTime && currentTime <= endTime
            } else {
                // Overnight range
                return currentTime >= startTime || currentTime <= endTime
            }
        }
        
        return true
    }
}

/// Conditional permission rule
/// 条件权限规则
struct ConditionalPermission: Codable {
    let permission: Permission
    let conditions: [String: String] // Key-value conditions
    let timeConstraint: TimeConstraint?
    let priority: Int // Higher priority rules override lower priority
    let description: String
    
    init(permission: Permission, conditions: [String: String] = [:], timeConstraint: TimeConstraint? = nil, priority: Int = 0, description: String = "") {
        self.permission = permission
        self.conditions = conditions
        self.timeConstraint = timeConstraint
        self.priority = priority
        self.description = description
    }
    
    func evaluateConditions(context: PermissionContext) -> Bool {
        // Check time constraints first
        if let timeConstraint = timeConstraint, !timeConstraint.isValid() {
            return false
        }
        
        // Check custom conditions
        for (key, expectedValue) in conditions {
            guard let actualValue = context.additionalData[key] as? String,
                  actualValue == expectedValue else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Role Permission Mapping (角色权限映射)

/// Enhanced role with hierarchical permissions
/// 增强的角色，具有分层权限
struct EnhancedRole: Codable {
    let role: UserRole
    let permissions: [Permission]
    let conditionalPermissions: [ConditionalPermission]
    let inheritedRoles: [UserRole]
    let level: Int // Role hierarchy level
    
    init(role: UserRole, permissions: [Permission] = [], conditionalPermissions: [ConditionalPermission] = [], inheritedRoles: [UserRole] = [], level: Int = 0) {
        self.role = role
        self.permissions = permissions
        self.conditionalPermissions = conditionalPermissions
        self.inheritedRoles = inheritedRoles
        self.level = level
    }
    
    /// Get all permissions including inherited ones
    /// 获取所有权限，包括继承的权限
    func getAllPermissions(using roleManager: RoleHierarchyManager) -> [Permission] {
        var allPermissions = Set(permissions)
        
        // Add permissions from inherited roles
        for inheritedRole in inheritedRoles {
            if let inherited = roleManager.getEnhancedRole(inheritedRole) {
                allPermissions.formUnion(inherited.getAllPermissions(using: roleManager))
            }
        }
        
        return Array(allPermissions)
    }
}

// MARK: - Role Hierarchy Manager (角色层次管理器)

/// Manages role hierarchy and permission inheritance
/// 管理角色层次和权限继承
class RoleHierarchyManager {
    private var enhancedRoles: [UserRole: EnhancedRole] = [:]
    
    init() {
        setupDefaultRoleHierarchy()
    }
    
    /// Setup default role hierarchy with permissions
    /// 设置默认角色层次和权限
    private func setupDefaultRoleHierarchy() {
        // Base roles with specific permissions
        enhancedRoles[.salesperson] = EnhancedRole(
            role: .salesperson,
            permissions: [
                .viewCustomer, .createCustomer, .editCustomer,
                .manageCustomerOrders, .viewInventory
            ],
            level: 1
        )
        
        enhancedRoles[.warehouseKeeper] = EnhancedRole(
            role: .warehouseKeeper,
            permissions: [
                .manageInventory, .viewInventory, .updateStock,
                .manageSuppliers, .viewBatch
            ],
            level: 1
        )
        
        enhancedRoles[.workshopTechnician] = EnhancedRole(
            role: .workshopTechnician,
            permissions: [
                .viewMachine, .operateMachine, .maintainMachine,
                .viewBatch, .viewProductionConfig
            ],
            level: 2
        )
        
        enhancedRoles[.evaGranulationTechnician] = EnhancedRole(
            role: .evaGranulationTechnician,
            permissions: [
                .viewMachine, .operateMachine, .viewInventory,
                .updateStock, .qualityControl
            ],
            level: 2
        )
        
        enhancedRoles[.workshopManager] = EnhancedRole(
            role: .workshopManager,
            permissions: [
                .createBatch, .editBatch, .viewBatch, .approveBatch, .completeBatch,
                .createMachine, .editMachine, .viewMachine, .operateMachine, .resetMachine,
                .createProductionConfig, .editProductionConfig, .viewProductionConfig,
                .scheduleProduction, .monitorProduction, .qualityControl
            ],
            inheritedRoles: [.workshopTechnician, .evaGranulationTechnician],
            level: 3
        )
        
        enhancedRoles[.administrator] = EnhancedRole(
            role: .administrator,
            permissions: Permission.allCases, // All permissions
            inheritedRoles: [.workshopManager, .warehouseKeeper, .salesperson],
            level: 4
        )
        
        enhancedRoles[.unauthorized] = EnhancedRole(
            role: .unauthorized,
            permissions: [], // No permissions
            level: 0
        )
    }
    
    func getEnhancedRole(_ role: UserRole) -> EnhancedRole? {
        return enhancedRoles[role]
    }
    
    func updateRolePermissions(_ role: UserRole, permissions: [Permission]) {
        if var enhancedRole = enhancedRoles[role] {
            enhancedRole = EnhancedRole(
                role: enhancedRole.role,
                permissions: permissions,
                conditionalPermissions: enhancedRole.conditionalPermissions,
                inheritedRoles: enhancedRole.inheritedRoles,
                level: enhancedRole.level
            )
            enhancedRoles[role] = enhancedRole
        }
    }
    
    func addConditionalPermission(_ role: UserRole, conditionalPermission: ConditionalPermission) {
        if var enhancedRole = enhancedRoles[role] {
            var newConditionalPermissions = enhancedRole.conditionalPermissions
            newConditionalPermissions.append(conditionalPermission)
            
            enhancedRole = EnhancedRole(
                role: enhancedRole.role,
                permissions: enhancedRole.permissions,
                conditionalPermissions: newConditionalPermissions,
                inheritedRoles: enhancedRole.inheritedRoles,
                level: enhancedRole.level
            )
            enhancedRoles[role] = enhancedRole
        }
    }
    
    /// Get role hierarchy path from lowest to highest
    /// 获取从最低到最高的角色层次路径
    func getRoleHierarchyPath(for role: UserRole) -> [UserRole] {
        var path: [UserRole] = [role]
        var visited: Set<UserRole> = [role]
        
        if let enhancedRole = enhancedRoles[role] {
            for inheritedRole in enhancedRole.inheritedRoles {
                if !visited.contains(inheritedRole) {
                    visited.insert(inheritedRole)
                    let inheritedPath = getRoleHierarchyPath(for: inheritedRole)
                    path.append(contentsOf: inheritedPath)
                }
            }
        }
        
        return path.sorted { (enhancedRoles[$0]?.level ?? 0) < (enhancedRoles[$1]?.level ?? 0) }
    }
}

// MARK: - Advanced Permission Service (高级权限服务)

/// Comprehensive permission management service
/// 综合权限管理服务
@MainActor
class AdvancedPermissionService: ObservableObject {
    
    // MARK: - Dependencies
    private let authService: AuthenticationService
    private let auditService: NewAuditingService
    private let roleHierarchyManager = RoleHierarchyManager()
    
    // MARK: - State
    @Published var userPermissions: [String: [Permission]] = [:]
    @Published var permissionCache: [String: [String: PermissionResult]] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    init(authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        self.auditService = auditService
    }
    
    // MARK: - Core Permission Evaluation (核心权限评估)
    
    /// Check if user has permission with context
    /// 检查用户是否具有权限（带上下文）
    func hasPermission(_ permission: Permission, context: PermissionContext? = nil) async -> PermissionResult {
        let currentContext = context ?? PermissionContext(userId: authService.currentUser?.id ?? "")
        let cacheKey = "\(permission.rawValue):\(currentContext.userId)"
        
        // Check cache first
        if let cachedResult = getCachedPermissionResult(cacheKey),
           Date().timeIntervalSince(cachedResult.evaluatedAt) < cacheTimeout {
            return cachedResult
        }
        
        // Evaluate permission
        let result = await evaluatePermission(permission, context: currentContext)
        
        // Cache result
        cachePermissionResult(cacheKey, result: result)
        
        // Audit permission check
        try? await auditService.logSecurityEvent(
            event: "permission_check",
            userId: currentContext.userId,
            details: [
                "permission": permission.rawValue,
                "granted": "\(result.isGranted)",
                "reason": result.reason,
                "target_entity": currentContext.targetEntityId ?? "none"
            ]
        )
        
        return result
    }
    
    /// Evaluate permission based on user roles and conditions
    /// 基于用户角色和条件评估权限
    private func evaluatePermission(_ permission: Permission, context: PermissionContext) async -> PermissionResult {
        guard let user = authService.currentUser else {
            return PermissionResult(
                permission: permission,
                isGranted: false,
                reason: "用户未认证",
                context: context
            )
        }
        
        if !user.isActive {
            return PermissionResult(
                permission: permission,
                isGranted: false,
                reason: "用户账户已禁用",
                context: context
            )
        }
        
        var grantingSources: [String] = []
        
        // Check permissions from all user roles
        for role in user.roles {
            if let enhancedRole = roleHierarchyManager.getEnhancedRole(role) {
                // Check direct permissions
                let allPermissions = enhancedRole.getAllPermissions(using: roleHierarchyManager)
                if allPermissions.contains(permission) {
                    grantingSources.append("role:\(role.rawValue)")
                }
                
                // Check conditional permissions
                for conditionalPermission in enhancedRole.conditionalPermissions {
                    if conditionalPermission.permission == permission &&
                       conditionalPermission.evaluateConditions(context: context) {
                        grantingSources.append("conditional:\(role.rawValue)")
                    }
                }
            }
        }
        
        let isGranted = !grantingSources.isEmpty
        let reason = isGranted ? "权限通过角色授予: \(grantingSources.joined(separator: ", "))" : "用户无此权限"
        
        return PermissionResult(
            permission: permission,
            isGranted: isGranted,
            reason: reason,
            context: context,
            grantedBy: grantingSources
        )
    }
    
    // MARK: - Batch Permission Checks (批量权限检查)
    
    /// Check multiple permissions at once
    /// 一次检查多个权限
    func hasPermissions(_ permissions: [Permission], context: PermissionContext? = nil) async -> [Permission: PermissionResult] {
        var results: [Permission: PermissionResult] = [:]
        
        for permission in permissions {
            results[permission] = await hasPermission(permission, context: context)
        }
        
        return results
    }
    
    /// Get all permissions for current user
    /// 获取当前用户的所有权限
    func getCurrentUserPermissions() -> [Permission] {
        guard let user = authService.currentUser else { return [] }
        
        var allPermissions = Set<Permission>()
        
        for role in user.roles {
            if let enhancedRole = roleHierarchyManager.getEnhancedRole(role) {
                allPermissions.formUnion(enhancedRole.getAllPermissions(using: roleHierarchyManager))
            }
        }
        
        return Array(allPermissions).sorted { $0.displayName < $1.displayName }
    }
    
    /// Get permissions grouped by category
    /// 获取按类别分组的权限
    func getPermissionsByCategory() -> [PermissionCategory: [Permission]] {
        let userPermissions = getCurrentUserPermissions()
        var grouped: [PermissionCategory: [Permission]] = [:]
        
        for permission in userPermissions {
            let category = permission.category
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(permission)
        }
        
        return grouped
    }
    
    // MARK: - Permission Management (权限管理)
    
    /// Grant permission to role
    /// 向角色授予权限
    func grantPermissionToRole(_ permission: Permission, role: UserRole) async throws {
        guard let currentUser = authService.currentUser,
              await hasPermission(.managePermissions).isGranted else {
            throw PermissionError.insufficientPermissions
        }
        
        if let enhancedRole = roleHierarchyManager.getEnhancedRole(role) {
            var newPermissions = enhancedRole.permissions
            if !newPermissions.contains(permission) {
                newPermissions.append(permission)
                roleHierarchyManager.updateRolePermissions(role, permissions: newPermissions)
                
                // Clear relevant caches
                clearPermissionCache()
                
                // Audit the change
                try await auditService.logSecurityEvent(
                    event: "permission_granted",
                    userId: currentUser.id,
                    details: [
                        "permission": permission.rawValue,
                        "target_role": role.rawValue,
                        "granted_by": currentUser.name
                    ]
                )
            }
        }
    }
    
    /// Revoke permission from role
    /// 从角色撤销权限
    func revokePermissionFromRole(_ permission: Permission, role: UserRole) async throws {
        guard let currentUser = authService.currentUser,
              await hasPermission(.managePermissions).isGranted else {
            throw PermissionError.insufficientPermissions
        }
        
        if let enhancedRole = roleHierarchyManager.getEnhancedRole(role) {
            var newPermissions = enhancedRole.permissions
            newPermissions.removeAll { $0 == permission }
            roleHierarchyManager.updateRolePermissions(role, permissions: newPermissions)
            
            // Clear relevant caches
            clearPermissionCache()
            
            // Audit the change
            try await auditService.logSecurityEvent(
                event: "permission_revoked",
                userId: currentUser.id,
                details: [
                    "permission": permission.rawValue,
                    "target_role": role.rawValue,
                    "revoked_by": currentUser.name
                ]
            )
        }
    }
    
    // MARK: - Cache Management (缓存管理)
    
    private func getCachedPermissionResult(_ key: String) -> PermissionResult? {
        guard let userCache = permissionCache[authService.currentUser?.id ?? ""],
              let result = userCache[key] else {
            return nil
        }
        return result
    }
    
    private func cachePermissionResult(_ key: String, result: PermissionResult) {
        let userId = authService.currentUser?.id ?? ""
        if permissionCache[userId] == nil {
            permissionCache[userId] = [:]
        }
        permissionCache[userId]?[key] = result
    }
    
    private func clearPermissionCache() {
        permissionCache.removeAll()
    }
    
    // MARK: - Utility Methods (实用方法)
    
    /// Create permission context for entity operations
    /// 为实体操作创建权限上下文
    func createContext(targetEntityId: String? = nil, targetEntityType: String? = nil, additionalData: [String: Any] = [:]) -> PermissionContext {
        return PermissionContext(
            userId: authService.currentUser?.id ?? "",
            targetEntityId: targetEntityId,
            targetEntityType: targetEntityType,
            additionalData: additionalData
        )
    }
    
    /// Get role hierarchy for current user
    /// 获取当前用户的角色层次
    func getCurrentUserRoleHierarchy() -> [UserRole] {
        guard let user = authService.currentUser else { return [] }
        
        var allRoles = Set<UserRole>()
        for role in user.roles {
            let hierarchyPath = roleHierarchyManager.getRoleHierarchyPath(for: role)
            allRoles.formUnion(hierarchyPath)
        }
        
        return Array(allRoles).sorted { 
            (roleHierarchyManager.getEnhancedRole($0)?.level ?? 0) < 
            (roleHierarchyManager.getEnhancedRole($1)?.level ?? 0) 
        }
    }
}

// MARK: - Error Types (错误类型)

enum PermissionError: LocalizedError {
    case insufficientPermissions
    case userNotAuthenticated
    case invalidPermission
    case roleNotFound
    case operationNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足"
        case .userNotAuthenticated:
            return "用户未认证"
        case .invalidPermission:
            return "无效权限"
        case .roleNotFound:
            return "角色不存在"
        case .operationNotAllowed:
            return "操作不被允许"
        }
    }
}

// MARK: - SwiftUI Integration (SwiftUI集成)

/// Property wrapper for permission-based view access
/// 基于权限的视图访问属性包装器
@propertyWrapper
struct RequiresPermission {
    let permission: Permission
    let permissionService: AdvancedPermissionService
    
    var wrappedValue: Bool {
        // This would need to be implemented asynchronously in real usage
        // For SwiftUI integration, consider using a state-based approach
        return true // Placeholder
    }
}

/// View modifier for permission-based content display
/// 基于权限的内容显示视图修饰符
struct PermissionRequiredModifier: ViewModifier {
    let permission: Permission
    let permissionService: AdvancedPermissionService
    @State private var hasPermission = false
    
    func body(content: Content) -> some View {
        Group {
            if hasPermission {
                content
            } else {
                Text("权限不足")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .task {
            let result = await permissionService.hasPermission(permission)
            hasPermission = result.isGranted
        }
    }
}

extension View {
    func requiresPermission(_ permission: Permission, using service: AdvancedPermissionService) -> some View {
        modifier(PermissionRequiredModifier(permission: permission, permissionService: service))
    }
}