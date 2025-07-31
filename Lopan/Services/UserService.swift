//
//  UserService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
@Observable
class UserService {
    private let userRepository: UserRepository
    private let auditingService: NewAuditingService
    
    var users: [User] = []
    var isLoading = false
    var error: Error?
    
    init(repositoryFactory: RepositoryFactory) {
        self.userRepository = repositoryFactory.userRepository
        self.auditingService = NewAuditingService(repositoryFactory: repositoryFactory)
    }
    
    func loadUsers() async {
        isLoading = true
        error = nil
        
        do {
            users = try await userRepository.fetchUsers()
        } catch {
            self.error = error
            print("❌ Error loading users: \(error)")
        }
        
        isLoading = false
    }
    
    func updateUserRoles(_ user: User, roles: [UserRole], primaryRole: UserRole, updatedBy: String) async -> Bool {
        let beforeData: [String: Any] = [
            "roles": user.roles.map { $0.rawValue },
            "primary_role": user.primaryRole.rawValue
        ]
        
        user.roles = roles
        user.primaryRole = primaryRole
        
        do {
            try await userRepository.updateUser(user)
            await loadUsers() // Refresh the list
            
            // Log the update
            await auditingService.logUpdate(
                entityType: .user,
                entityId: user.id,
                entityDescription: user.name,
                operatorUserId: updatedBy,
                operatorUserName: updatedBy,
                beforeData: beforeData,
                afterData: [
                    "roles": user.roles.map { $0.rawValue },
                    "primary_role": user.primaryRole.rawValue
                ] as [String: Any],
                changedFields: ["roles", "primary_role"]
            )
            
            return true
        } catch {
            self.error = error
            print("❌ Error updating user roles: \(error)")
            return false
        }
    }
    
    func deleteUser(_ user: User, deletedBy: String) async -> Bool {
        do {
            // Log before deletion
            await auditingService.logDelete(
                entityType: .user,
                entityId: user.id,
                entityDescription: user.name,
                operatorUserId: deletedBy,
                operatorUserName: deletedBy,
                deletedData: [
                    "name": user.name,
                    "wechat_id": user.wechatId ?? "",
                    "phone": user.phone ?? "",
                    "roles": user.roles.map { $0.rawValue }
                ]
            )
            
            try await userRepository.deleteUser(user)
            await loadUsers() // Refresh the list
            
            return true
        } catch {
            self.error = error
            print("❌ Error deleting user: \(error)")
            return false
        }
    }
}