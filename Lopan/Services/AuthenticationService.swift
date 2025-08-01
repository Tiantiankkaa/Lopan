//
//  AuthenticationService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData
import AuthenticationServices

@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var smsCode = ""
    @Published var phoneNumber = ""
    @Published var showingSMSVerification = false
    
    private let userRepository: UserRepository
    private var pendingSMSUser: User?
    private weak var serviceFactory: ServiceFactory?
    
    init(repositoryFactory: RepositoryFactory, serviceFactory: ServiceFactory? = nil) {
        self.userRepository = repositoryFactory.userRepository
        self.serviceFactory = serviceFactory
    }
    
    // Simulate WeChat login
    func loginWithWeChat(wechatId: String, name: String, phone: String? = nil) async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        do {
            if let existingUser = try await userRepository.fetchUser(byWechatId: wechatId) {
                // User exists, update last login
                existingUser.lastLoginAt = Date()
                try await userRepository.updateUser(existingUser)
                currentUser = existingUser
            } else {
                // Create new user
                let newUser = User(wechatId: wechatId, name: name, phone: phone)
                try await userRepository.addUser(newUser)
                currentUser = newUser
            }
            
            isAuthenticated = true
            
        } catch {
            print("Authentication error: \(error)")
        }
        
        isLoading = false
    }
    
    func logout() {
        // Start comprehensive cleanup process
        Task {
            await performComprehensiveLogout()
        }
    }
    
    private func performComprehensiveLogout() async {
        print("⚙️ Starting comprehensive logout process...")
        
        // Step 1: Cleanup all services to cancel background tasks
        if let serviceFactory = serviceFactory {
            await serviceFactory.cleanupAllServices()
        }
        
        // Step 2: Clear user session after services are cleaned up
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
        }
        
        print("✅ Comprehensive logout completed successfully")
    }
    
    // MARK: - Workbench Session Management
    
    /// Exit current workbench (return to main menu/workbench selection)
    func exitWorkbench() {
        // This method provides a way to exit the current workbench context
        // without fully logging out the user
        // The actual workbench context is managed by WorkbenchNavigationService
        // This method can be used for audit logging or session tracking
        guard let user = currentUser else { return }
        print("User \(user.name) exited workbench context")
    }
    
    /// Switch to a workbench with proper context tracking
    func switchToWorkbenchWithContext(_ targetRole: UserRole, navigationService: WorkbenchNavigationService?) {
        guard let user = currentUser else { return }
        
        // Check permissions first
        guard user.isAdministrator || user.hasRole(targetRole) else { return }
        
        // Set workbench context
        navigationService?.setCurrentWorkbenchContext(targetRole)
        
        // Switch role if different from current
        if targetRole != user.primaryRole {
            switchToWorkbenchRole(targetRole)
        }
        
        print("User \(user.name) switched to \(targetRole.displayName) workbench")
    }
    
    /// Return to primary workbench
    func returnToPrimaryWorkbench(navigationService: WorkbenchNavigationService?) {
        guard let user = currentUser else { return }
        
        // Reset to original role if needed
        resetToOriginalRole()
        
        // Set primary workbench context
        navigationService?.setCurrentWorkbenchContext(user.primaryRole)
        
        print("User \(user.name) returned to primary workbench: \(user.primaryRole.displayName)")
    }
    
    func updateUserRoles(_ roles: [UserRole], primaryRole: UserRole) {
        guard let user = currentUser else { return }
        user.roles = roles
        user.primaryRole = primaryRole
        Task {
            try? await userRepository.updateUser(user)
        }
    }
    
    /// Switch to a different workbench role (for users with multiple roles or administrators)
    func switchToWorkbenchRole(_ targetRole: UserRole) {
        guard let user = currentUser else { return }
        
        // Administrators can switch to any role, others must have the target role
        guard user.isAdministrator || user.hasRole(targetRole) else { return }
        
        // Set original role if not already set
        if user.originalRole == nil {
            user.originalRole = user.primaryRole
        }
        
        // Switch to target role
        user.primaryRole = targetRole
        Task {
            try? await userRepository.updateUser(user)
        }
    }
    
    /// Reset user back to original primary role
    func resetToOriginalRole() {
        guard let user = currentUser else { return }
        
        user.resetToOriginalRole()
        Task {
            try? await userRepository.updateUser(user)
        }
    }
    
    // MARK: - Apple Sign In
    func loginWithApple(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        
        do {
            let authorization = try result.get()
            
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let email = appleIDCredential.email
                
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                let name = displayName.isEmpty ? "Apple 用户" : displayName
                
                // Check if user exists
                if let existingUser = try await userRepository.fetchUser(byAppleUserId: userID) {
                    existingUser.lastLoginAt = Date()
                    try await userRepository.updateUser(existingUser)
                    currentUser = existingUser
                } else {
                    let newUser = User(appleUserId: userID, name: name, email: email)
                    try await userRepository.addUser(newUser)
                    currentUser = newUser
                }
                
                isAuthenticated = true
            }
        } catch {
            print("Apple Sign In error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - SMS Authentication
    func sendSMSCode(to phoneNumber: String, name: String) async {
        isLoading = true
        self.phoneNumber = phoneNumber
        
        // Simulate SMS sending delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // In production, integrate with SMS service like Aliyun SMS
        print("模拟发送验证码到: \(phoneNumber)")
        
        // Create pending user
        pendingSMSUser = User(phone: phoneNumber, name: name)
        
        showingSMSVerification = true
        isLoading = false
    }
    
    func verifySMSCode(_ code: String) async {
        isLoading = true
        
        // Simulate verification delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In production, verify with SMS service
        // For demo, accept "1234" as valid code
        if code == "1234" || code.count == 6 {
            guard let pendingUser = pendingSMSUser else {
                isLoading = false
                return
            }
            
            do {
                // Check if user with this phone already exists
                if let existingUser = try await userRepository.fetchUser(byPhone: pendingUser.phone ?? "") {
                    existingUser.lastLoginAt = Date()
                    try await userRepository.updateUser(existingUser)
                    currentUser = existingUser
                } else {
                    try await userRepository.addUser(pendingUser)
                    currentUser = pendingUser
                }
                
                isAuthenticated = true
                showingSMSVerification = false
                smsCode = ""
                pendingSMSUser = nil
                
            } catch {
                print("SMS verification error: \(error)")
            }
        } else {
            print("无效验证码")
        }
        
        isLoading = false
    }
} 