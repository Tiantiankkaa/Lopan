//
//  RoleManagementService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Role Assignment Models (角色分配模型)

/// Role assignment with expiration and conditions
/// 带有过期时间和条件的角色分配
struct RoleAssignment: Identifiable, Codable {
    let id: String
    let userId: String
    let role: UserRole
    let assignedBy: String
    let assignedAt: Date
    let expiresAt: Date?
    let conditions: [String: String]
    let isActive: Bool
    let reason: String
    
    init(userId: String, role: UserRole, assignedBy: String, expiresAt: Date? = nil, conditions: [String: String] = [:], reason: String = "") {
        self.id = UUID().uuidString
        self.userId = userId
        self.role = role
        self.assignedBy = assignedBy
        self.assignedAt = Date()
        self.expiresAt = expiresAt
        self.conditions = conditions
        self.isActive = true
        self.reason = reason
    }
    
    /// Check if assignment is currently valid
    /// 检查分配是否当前有效
    var isValid: Bool {
        if !isActive { return false }
        if let expiry = expiresAt, Date() > expiry { return false }
        return true
    }
}

/// Role change audit log
/// 角色变更审计日志
struct RoleChangeLog: Identifiable, Codable {
    let id: String
    let userId: String
    let action: RoleAction
    let role: UserRole
    let performedBy: String
    let performedAt: Date
    let reason: String
    let previousRoles: [UserRole]
    let newRoles: [UserRole]
    
    enum RoleAction: String, Codable {
        case assigned = "assigned"
        case revoked = "revoked"
        case expired = "expired"
        case modified = "modified"
        
        var displayName: String {
            switch self {
            case .assigned: return "分配"
            case .revoked: return "撤销"
            case .expired: return "过期"
            case .modified: return "修改"
            }
        }
    }
}

/// Temporary role elevation request
/// 临时角色提升请求
struct RoleElevationRequest: Identifiable, Codable {
    let id: String
    let requesterId: String
    let requesterName: String
    let targetRole: UserRole
    let requestReason: String
    let requestedAt: Date
    let requestedDuration: TimeInterval
    let status: RequestStatus
    let reviewedBy: String?
    let reviewedAt: Date?
    let reviewNotes: String?
    
    enum RequestStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
        case expired = "expired"
        
        var displayName: String {
            switch self {
            case .pending: return "待审核"
            case .approved: return "已批准"
            case .rejected: return "已拒绝"
            case .expired: return "已过期"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return LopanColors.warning
            case .approved: return LopanColors.success
            case .rejected: return LopanColors.error
            case .expired: return LopanColors.textSecondary
            }
        }
    }
    
    var expiresAt: Date {
        return requestedAt.addingTimeInterval(requestedDuration)
    }
}

// MARK: - Role Management Service (角色管理服务)

/// Advanced role management with hierarchy, inheritance, and temporary assignments
/// 具有层次结构、继承和临时分配的高级角色管理
@MainActor
public class RoleManagementService: ObservableObject {
    
    // MARK: - Dependencies
    private let authService: AuthenticationService
    private let auditService: NewAuditingService
    private let permissionService: AdvancedPermissionService
    
    // MARK: - State
    @Published var roleAssignments: [RoleAssignment] = []
    @Published var roleChangeLogs: [RoleChangeLog] = []
    @Published var elevationRequests: [RoleElevationRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    private let maxElevationDuration: TimeInterval = 24 * 3600 // 24 hours
    private let defaultRoleExpiration: TimeInterval = 365 * 24 * 3600 // 1 year
    
    init(authService: AuthenticationService, auditService: NewAuditingService, permissionService: AdvancedPermissionService) {
        self.authService = authService
        self.auditService = auditService
        self.permissionService = permissionService
        loadInitialData()
    }
    
    // MARK: - Role Assignment Management (角色分配管理)
    
    /// Assign role to user with optional expiration
    /// 为用户分配角色，可选过期时间
    func assignRole(_ role: UserRole, to userId: String, expiresAt: Date? = nil, reason: String = "") async throws {
        guard let currentUser = authService.currentUser,
              await permissionService.hasPermission(.assignRole).isGranted else {
            throw RoleManagementError.insufficientPermissions
        }
        
        // Check if user exists (in a real implementation, this would query user service)
        guard userId != currentUser.id || role != .administrator else {
            throw RoleManagementError.cannotModifyOwnAdminRole
        }
        
        // Check if assignment already exists
        if roleAssignments.contains(where: { $0.userId == userId && $0.role == role && $0.isValid }) {
            throw RoleManagementError.roleAlreadyAssigned
        }
        
        // Create role assignment
        let assignment = RoleAssignment(
            userId: userId,
            role: role,
            assignedBy: currentUser.id,
            expiresAt: expiresAt,
            reason: reason
        )
        
        roleAssignments.append(assignment)
        
        // Update user roles (in real implementation, this would update the user repository)
        await updateUserRoles(userId: userId)
        
        // Log the change
        let changeLog = RoleChangeLog(
            id: UUID().uuidString,
            userId: userId,
            action: .assigned,
            role: role,
            performedBy: currentUser.id,
            performedAt: Date(),
            reason: reason,
            previousRoles: getUserRoles(userId: userId).filter { $0 != role },
            newRoles: getUserRoles(userId: userId)
        )
        roleChangeLogs.append(changeLog)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "role_assigned",
            userId: currentUser.id,
            details: [
                "target_user": userId,
                "role": role.rawValue,
                "expires_at": expiresAt?.ISO8601Format() ?? "never",
                "reason": reason
            ]
        )
    }
    
    /// Revoke role from user
    /// 从用户撤销角色
    func revokeRole(_ role: UserRole, from userId: String, reason: String = "") async throws {
        guard let currentUser = authService.currentUser,
              await permissionService.hasPermission(.assignRole).isGranted else {
            throw RoleManagementError.insufficientPermissions
        }
        
        // Prevent removing own administrator role
        if userId == currentUser.id && role == .administrator {
            throw RoleManagementError.cannotModifyOwnAdminRole
        }
        
        // Find and deactivate the assignment
        guard let assignmentIndex = roleAssignments.firstIndex(where: { $0.userId == userId && $0.role == role && $0.isValid }) else {
            throw RoleManagementError.roleNotFound
        }
        
        let previousRoles = getUserRoles(userId: userId)
        
        // Deactivate assignment
        var assignment = roleAssignments[assignmentIndex]
        roleAssignments[assignmentIndex] = RoleAssignment(
            userId: assignment.userId,
            role: assignment.role,
            assignedBy: assignment.assignedBy,
            expiresAt: assignment.expiresAt,
            conditions: assignment.conditions,
            reason: assignment.reason
        )
        roleAssignments[assignmentIndex] = RoleAssignment(
            userId: assignment.userId,
            role: assignment.role,
            assignedBy: currentUser.id,
            expiresAt: Date(), // Immediate expiration
            conditions: assignment.conditions,
            reason: "Revoked: \(reason)"
        )
        
        // Update user roles
        await updateUserRoles(userId: userId)
        
        // Log the change
        let changeLog = RoleChangeLog(
            id: UUID().uuidString,
            userId: userId,
            action: .revoked,
            role: role,
            performedBy: currentUser.id,
            performedAt: Date(),
            reason: reason,
            previousRoles: previousRoles,
            newRoles: getUserRoles(userId: userId)
        )
        roleChangeLogs.append(changeLog)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "role_revoked",
            userId: currentUser.id,
            details: [
                "target_user": userId,
                "role": role.rawValue,
                "reason": reason
            ]
        )
    }
    
    /// Request temporary role elevation
    /// 请求临时角色提升
    func requestRoleElevation(to role: UserRole, duration: TimeInterval, reason: String) async throws {
        guard let currentUser = authService.currentUser else {
            throw RoleManagementError.userNotAuthenticated
        }
        
        // Check if duration is within limits
        guard duration <= maxElevationDuration else {
            throw RoleManagementError.elevationDurationTooLong
        }
        
        // Check if user already has the role
        if currentUser.hasRole(role) {
            throw RoleManagementError.roleAlreadyAssigned
        }
        
        // Check for existing pending request
        if elevationRequests.contains(where: { $0.requesterId == currentUser.id && $0.targetRole == role && $0.status == .pending }) {
            throw RoleManagementError.duplicateElevationRequest
        }
        
        // Create elevation request
        let request = RoleElevationRequest(
            id: UUID().uuidString,
            requesterId: currentUser.id,
            requesterName: currentUser.name,
            targetRole: role,
            requestReason: reason,
            requestedAt: Date(),
            requestedDuration: duration,
            status: .pending,
            reviewedBy: nil,
            reviewedAt: nil,
            reviewNotes: nil
        )
        
        elevationRequests.append(request)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "role_elevation_requested",
            userId: currentUser.id,
            details: [
                "target_role": role.rawValue,
                "duration": "\(duration)",
                "reason": reason
            ]
        )
        
        // Notify administrators (using notification system)
        // This would integrate with the notification engine
    }
    
    /// Review role elevation request
    /// 审核角色提升请求
    func reviewElevationRequest(_ requestId: String, approved: Bool, notes: String = "") async throws {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.administrator) else {
            throw RoleManagementError.insufficientPermissions
        }
        
        guard let requestIndex = elevationRequests.firstIndex(where: { $0.id == requestId }) else {
            throw RoleManagementError.elevationRequestNotFound
        }
        
        var request = elevationRequests[requestIndex]
        
        // Update request status
        elevationRequests[requestIndex] = RoleElevationRequest(
            id: request.id,
            requesterId: request.requesterId,
            requesterName: request.requesterName,
            targetRole: request.targetRole,
            requestReason: request.requestReason,
            requestedAt: request.requestedAt,
            requestedDuration: request.requestedDuration,
            status: approved ? .approved : .rejected,
            reviewedBy: currentUser.id,
            reviewedAt: Date(),
            reviewNotes: notes
        )
        
        // If approved, assign the role temporarily
        if approved {
            let expirationDate = Date().addingTimeInterval(request.requestedDuration)
            try await assignRole(
                request.targetRole,
                to: request.requesterId,
                expiresAt: expirationDate,
                reason: "Temporary elevation: \(request.requestReason)"
            )
        }
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "role_elevation_reviewed",
            userId: currentUser.id,
            details: [
                "request_id": requestId,
                "approved": "\(approved)",
                "target_role": request.targetRole.rawValue,
                "requester": request.requesterId,
                "notes": notes
            ]
        )
    }
    
    // MARK: - Role Hierarchy Management (角色层次管理)
    
    /// Get effective roles for user including inherited roles
    /// 获取用户的有效角色，包括继承的角色
    @MainActor
    func getEffectiveRoles(for userId: String) -> [UserRole] {
        let directRoles = getUserRoles(userId: userId)
        var effectiveRoles = Set(directRoles)
        
        // Add inherited roles based on hierarchy
        for role in directRoles {
            let hierarchyPath = permissionService.getCurrentUserRoleHierarchy()
            effectiveRoles.formUnion(hierarchyPath.filter { hierarchyPath.firstIndex(of: $0) ?? 0 <= hierarchyPath.firstIndex(of: role) ?? 0 })
        }
        
        return Array(effectiveRoles).sorted { 
            getRoleLevel($0) > getRoleLevel($1) 
        }
    }
    
    /// Get role level for hierarchy sorting
    /// 获取角色层级用于排序
    private func getRoleLevel(_ role: UserRole) -> Int {
        switch role {
        case .administrator: return 4
        case .workshopManager: return 3
        case .workshopTechnician, .evaGranulationTechnician: return 2
        case .salesperson, .warehouseKeeper: return 1
        case .unauthorized: return 0
        }
    }
    
    /// Check if role can inherit from another role
    /// 检查角色是否可以从另一个角色继承
    func canInheritRole(_ childRole: UserRole, from parentRole: UserRole) -> Bool {
        let childLevel = getRoleLevel(childRole)
        let parentLevel = getRoleLevel(parentRole)
        return childLevel > parentLevel
    }
    
    // MARK: - Role Analytics (角色分析)
    
    /// Get role distribution statistics
    /// 获取角色分布统计
    func getRoleDistribution() -> [UserRole: Int] {
        var distribution: [UserRole: Int] = [:]
        
        // Count active role assignments
        for assignment in roleAssignments.filter({ $0.isValid }) {
            distribution[assignment.role, default: 0] += 1
        }
        
        return distribution
    }
    
    /// Get role change history for user
    /// 获取用户的角色变更历史
    func getRoleHistory(for userId: String) -> [RoleChangeLog] {
        return roleChangeLogs
            .filter { $0.userId == userId }
            .sorted { $0.performedAt > $1.performedAt }
    }
    
    /// Get pending elevation requests
    /// 获取待处理的提升请求
    func getPendingElevationRequests() -> [RoleElevationRequest] {
        return elevationRequests
            .filter { $0.status == .pending }
            .sorted { $0.requestedAt < $1.requestedAt }
    }
    
    // MARK: - Utility Methods (实用方法)
    
    /// Get current roles for user
    /// 获取用户当前角色
    private func getUserRoles(userId: String) -> [UserRole] {
        return roleAssignments
            .filter { $0.userId == userId && $0.isValid }
            .map { $0.role }
    }
    
    /// Update user roles in the system
    /// 更新系统中的用户角色
    private func updateUserRoles(userId: String) async {
        let roles = getUserRoles(userId: userId)
        // In a real implementation, this would update the user repository
        // For now, we'll just ensure the current user's roles are updated if it's them
        if let currentUser = authService.currentUser, currentUser.id == userId {
            for role in roles {
                currentUser.addRole(role)
            }
        }
    }
    
    /// Load initial data
    /// 加载初始数据
    private func loadInitialData() {
        // In a real implementation, this would load from persistent storage
        // For now, we'll create some sample data
        createSampleData()
    }
    
    /// Create sample data for demonstration
    /// 创建示例数据用于演示
    private func createSampleData() {
        // Sample role assignments
        if let currentUser = authService.currentUser {
            let sampleAssignment = RoleAssignment(
                userId: currentUser.id,
                role: .administrator,
                assignedBy: "system",
                reason: "System administrator"
            )
            roleAssignments.append(sampleAssignment)
        }
    }
    
    /// Clean up expired assignments
    /// 清理过期的分配
    func cleanupExpiredAssignments() async {
        let expiredAssignments = roleAssignments.filter { assignment in
            if let expiresAt = assignment.expiresAt {
                return Date() > expiresAt && assignment.isActive
            }
            return false
        }
        
        for assignment in expiredAssignments {
            // Log expiration
            let changeLog = RoleChangeLog(
                id: UUID().uuidString,
                userId: assignment.userId,
                action: .expired,
                role: assignment.role,
                performedBy: "system",
                performedAt: Date(),
                reason: "Role assignment expired",
                previousRoles: getUserRoles(userId: assignment.userId),
                newRoles: getUserRoles(userId: assignment.userId).filter { $0 != assignment.role }
            )
            roleChangeLogs.append(changeLog)
            
            // Update user roles
            await updateUserRoles(userId: assignment.userId)
        }
        
        // Remove expired assignments
        roleAssignments.removeAll { assignment in
            if let expiresAt = assignment.expiresAt {
                return Date() > expiresAt
            }
            return false
        }
    }
}

// MARK: - Error Types (错误类型)

enum RoleManagementError: LocalizedError {
    case insufficientPermissions
    case userNotAuthenticated
    case roleAlreadyAssigned
    case roleNotFound
    case cannotModifyOwnAdminRole
    case elevationDurationTooLong
    case duplicateElevationRequest
    case elevationRequestNotFound
    case invalidRoleHierarchy
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足，无法执行此操作"
        case .userNotAuthenticated:
            return "用户未认证"
        case .roleAlreadyAssigned:
            return "角色已分配给用户"
        case .roleNotFound:
            return "未找到指定角色"
        case .cannotModifyOwnAdminRole:
            return "不能修改自己的管理员角色"
        case .elevationDurationTooLong:
            return "提升持续时间超过限制"
        case .duplicateElevationRequest:
            return "已存在相同的角色提升请求"
        case .elevationRequestNotFound:
            return "未找到角色提升请求"
        case .invalidRoleHierarchy:
            return "无效的角色层次结构"
        }
    }
}

// MARK: - Supporting Extensions (支持扩展)

extension User {
    /// Get effective roles including inherited ones
    /// 获取有效角色，包括继承的角色
    @MainActor
    func getEffectiveRoles(using roleManager: RoleManagementService) -> [UserRole] {
        return roleManager.getEffectiveRoles(for: self.id)
    }
    
    /// Check if user has role or inherits it
    /// 检查用户是否拥有角色或继承了该角色
    @MainActor
    func hasEffectiveRole(_ role: UserRole, using roleManager: RoleManagementService) -> Bool {
        return getEffectiveRoles(using: roleManager).contains(role)
    }
}