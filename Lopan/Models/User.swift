//
//  User.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

enum UserRole: String, CaseIterable, Codable {
    case salesperson = "salesperson"
    case warehouseKeeper = "warehouse_keeper"
    case workshopManager = "workshop_manager"
    case evaGranulationTechnician = "eva_granulation_technician"
    case workshopTechnician = "workshop_technician"
    case administrator = "administrator"
    case unauthorized = "unauthorized"
    
    var displayName: String {
        switch self {
        case .salesperson:
            return "salesperson".localized
        case .warehouseKeeper:
            return "warehouse_keeper".localized
        case .workshopManager:
            return "workshop_manager".localized
        case .evaGranulationTechnician:
            return "eva_granulation_technician".localized
        case .workshopTechnician:
            return "workshop_technician".localized
        case .administrator:
            return "administrator".localized
        case .unauthorized:
            return "unauthorized".localized
        }
    }
}

enum AuthenticationMethod: String, CaseIterable, Codable {
    case wechat = "wechat"
    case appleId = "apple_id"
    case phoneNumber = "phone_number"
}

@Model
public final class User: @unchecked Sendable {
    public var id: String
    var wechatId: String?
    var appleUserId: String?
    var name: String
    var phone: String?
    var email: String?
    var authMethod: AuthenticationMethod
    var roles: [UserRole]
    var primaryRole: UserRole
    var originalRole: UserRole? // Track original role for administrators
    var isActive: Bool
    var createdAt: Date
    var lastLoginAt: Date?
    
    init(wechatId: String, name: String, phone: String? = nil) {
        self.id = UUID().uuidString
        self.wechatId = wechatId
        self.name = name
        self.phone = phone
        self.authMethod = .wechat
        self.roles = [.unauthorized]
        self.primaryRole = .unauthorized
        self.isActive = true
        self.createdAt = Date()
    }
    
    init(appleUserId: String, name: String, email: String? = nil) {
        self.id = UUID().uuidString
        self.appleUserId = appleUserId
        self.name = name
        self.email = email
        self.authMethod = .appleId
        self.roles = [.unauthorized]
        self.primaryRole = .unauthorized
        self.isActive = true
        self.createdAt = Date()
    }
    
    init(phone: String, name: String) {
        self.id = UUID().uuidString
        self.phone = phone
        self.name = name
        self.authMethod = .phoneNumber
        self.roles = [.unauthorized]
        self.primaryRole = .unauthorized
        self.isActive = true
        self.createdAt = Date()
    }
    
    /// True administrator status - checks if user has administrator role
    var isAdministrator: Bool {
        return roles.contains(.administrator) || originalRole == .administrator
    }
    
    /// Current effective role for workbench access
    var effectiveRole: UserRole {
        return primaryRole
    }
    
    /// Check if user has a specific role
    func hasRole(_ role: UserRole) -> Bool {
        return roles.contains(role)
    }
    
    /// Add a new role to the user
    func addRole(_ role: UserRole) {
        if !roles.contains(role) {
            roles.append(role)
        }
    }
    
    /// Remove a role from the user
    func removeRole(_ role: UserRole) {
        roles.removeAll { $0 == role }
        if primaryRole == role, let firstRole = roles.first {
            primaryRole = firstRole
        }
    }
    
    /// Set the primary role (must be one of the assigned roles)
    func setPrimaryRole(_ role: UserRole) {
        if roles.contains(role) {
            primaryRole = role
        }
    }
    
    /// Reset to original administrator role
    func resetToOriginalRole() {
        if let original = originalRole {
            primaryRole = original
        }
    }
} 