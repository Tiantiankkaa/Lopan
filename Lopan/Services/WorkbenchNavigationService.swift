//
//  WorkbenchNavigationService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/29.
//

import Foundation
import SwiftUI

@MainActor
public class WorkbenchNavigationService: ObservableObject {
    @Published var showingWorkbenchSelector = false
    @Published var currentWorkbenchContext: UserRole?
    
    // 检查用户是否可以访问指定角色的工作台
    func canAccessWorkbench(user: User, targetRole: UserRole) -> Bool {
        // Administrators can access all workbenches by default
        if user.isAdministrator {
            return targetRole != .unauthorized
        }
        
        // Other users can access workbenches for roles they have been assigned
        return user.hasRole(targetRole) && targetRole != .unauthorized
    }
    
    // 获取用户的主工作台（用户的主要角色）
    func getPrimaryWorkbench(for user: User) -> UserRole {
        return user.primaryRole
    }
    
    // 获取用户被授权的额外工作台（除了主工作台外的其他角色）
    func getAuthorizedWorkbenches(for user: User) -> [UserRole] {
        if user.isAdministrator {
            // 管理员可以访问所有工作台，主工作台除外
            return UserRole.allCases.filter { $0 != .unauthorized && $0 != user.primaryRole }
        }
        
        // 其他用户只能访问被明确授权的角色（除了主角色和未授权角色）
        return user.roles.filter { $0 != .unauthorized && $0 != user.primaryRole }
    }
    
    // 获取用户可以访问的所有工作台角色（兼容性方法）
    func getAccessibleWorkbenches(for user: User) -> [UserRole] {
        var accessible = [getPrimaryWorkbench(for: user)]
        accessible.append(contentsOf: getAuthorizedWorkbenches(for: user))
        return accessible.filter { $0 != .unauthorized }
    }
    
    // 显示工作台选择器
    func showWorkbenchSelector() {
        showingWorkbenchSelector = true
    }
    
    // 隐藏工作台选择器
    func hideWorkbenchSelector() {
        showingWorkbenchSelector = false
    }
    
    // 设置当前工作台上下文
    func setCurrentWorkbenchContext(_ role: UserRole) {
        currentWorkbenchContext = role
    }
    
    // 清除工作台上下文
    func clearWorkbenchContext() {
        currentWorkbenchContext = nil
    }
    
    // 检查是否在特定工作台中
    func isInWorkbench(_ role: UserRole) -> Bool {
        return currentWorkbenchContext == role
    }
    
    // 获取工作台类型分类
    func getWorkbenchCategories(for user: User) -> WorkbenchCategories {
        let primary = getPrimaryWorkbench(for: user)
        let authorized = getAuthorizedWorkbenches(for: user)
        
        return WorkbenchCategories(
            primary: primary,
            authorized: authorized,
            current: currentWorkbenchContext
        )
    }
}

// MARK: - Supporting Types
struct WorkbenchCategories {
    let primary: UserRole           // 主工作台
    let authorized: [UserRole]      // 授权工作台
    let current: UserRole?          // 当前工作台上下文
    
    var hasMultipleAccess: Bool {
        return !authorized.isEmpty
    }
    
    var isInSecondaryWorkbench: Bool {
        guard let current = current else { return false }
        return authorized.contains(current)
    }
}