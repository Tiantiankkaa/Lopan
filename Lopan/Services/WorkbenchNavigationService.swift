//
//  WorkbenchNavigationService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/29.
//

import Foundation
import SwiftUI

@MainActor
class WorkbenchNavigationService: ObservableObject {
    @Published var showingWorkbenchSelector = false
    
    // 检查用户是否可以访问指定角色的工作台
    func canAccessWorkbench(user: User, targetRole: UserRole) -> Bool {
        // Administrators can access all workbenches by default
        if user.isAdministrator {
            return targetRole != .unauthorized
        }
        
        // Other users can access workbenches for roles they have been assigned
        return user.hasRole(targetRole) && targetRole != .unauthorized
    }
    
    // 获取用户可以访问的所有工作台角色
    func getAccessibleWorkbenches(for user: User) -> [UserRole] {
        // Administrators can access all workbenches by default
        if user.isAdministrator {
            return UserRole.allCases.filter { $0 != .unauthorized }
        }
        
        // Other users can only access their assigned roles (excluding unauthorized)
        return user.roles.filter { $0 != .unauthorized }
    }
    
    // 显示工作台选择器
    func showWorkbenchSelector() {
        showingWorkbenchSelector = true
    }
    
    // 隐藏工作台选择器
    func hideWorkbenchSelector() {
        showingWorkbenchSelector = false
    }
}