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
public class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var smsCode = ""
    @Published var phoneNumber = ""
    @Published var showingSMSVerification = false
    
    private let userRepository: UserRepository
    private var pendingSMSUser: User?
    private weak var serviceFactory: ServiceFactory?
    private var sessionSecurityService: SessionSecurityService? {
        serviceFactory?.sessionSecurityService
    }
    
    init(repositoryFactory: RepositoryFactory, serviceFactory: ServiceFactory? = nil) {
        self.userRepository = repositoryFactory.userRepository
        self.serviceFactory = serviceFactory
    }
    
    // Simulate WeChat login
    // TODO: Replace with proper WeChat SDK integration and server-side verification
    func loginWithWeChat(wechatId: String, name: String, phone: String? = nil) async {
        isLoading = true
        
        // Check rate limiting
        guard let sessionService = sessionSecurityService,
              sessionService.isAuthenticationAllowed(for: wechatId) else {
            print("❌ Security: Authentication rate limited for WeChat ID: \(wechatId)")
            isLoading = false
            return
        }
        
        // Input validation
        guard isValidWeChatId(wechatId) else {
            print("❌ Security: Invalid WeChat ID format rejected")
            isLoading = false
            return
        }
        
        guard isValidName(name) else {
            print("❌ Security: Invalid name format rejected")
            isLoading = false
            return
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        do {
            if let existingUser = try await userRepository.fetchUser(byWechatId: wechatId) {
                // User exists, update last login
                existingUser.lastLoginAt = Date()
                
                // Role assignment should be handled by administrators through proper authorization
                // TODO: Implement proper role-based access control with admin verification
                
                try await userRepository.updateUser(existingUser)
                currentUser = existingUser
                
                // Create secure session
                if let sessionService = sessionSecurityService {
                    let sessionToken = sessionService.createSession(for: existingUser.id, userRole: existingUser.primaryRole)
                    sessionService.resetRateLimit(for: wechatId)
                }
            } else {
                // Create new user
                let newUser = User(wechatId: wechatId, name: name, phone: phone)
                
                // New users get default role - role upgrades require administrator approval
                // TODO: Implement secure role assignment workflow
                
                try await userRepository.addUser(newUser)
                currentUser = newUser
                
                // Create secure session
                if let sessionService = sessionSecurityService {
                    let sessionToken = sessionService.createSession(for: newUser.id, userRole: newUser.primaryRole)
                    sessionService.resetRateLimit(for: wechatId)
                }
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
        
        // Step 1: Invalidate secure session
        await MainActor.run {
            if let user = currentUser, let sessionService = sessionSecurityService {
                sessionService.forceLogout(userId: user.id, reason: "User logout")
            }
        }
        
        // Step 2: Cleanup all services to cancel background tasks
        if let serviceFactory = serviceFactory {
            await serviceFactory.cleanupAllServices()
        }
        
        // Step 3: Clear user session after services are cleaned up
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
    
    @MainActor
    func updateUserRoles(_ roles: [UserRole], primaryRole: UserRole) {
        guard let user = currentUser else { return }
        user.roles = roles
        user.primaryRole = primaryRole
        Task {
            try? await userRepository.updateUser(user)
        }
    }
    
    /// Switch to a different workbench role (for users with multiple roles or administrators)
    @MainActor
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
    @MainActor
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
                
                // Check rate limiting
                guard let sessionService = sessionSecurityService,
                      sessionService.isAuthenticationAllowed(for: userID) else {
                    print("❌ Security: Authentication rate limited for Apple ID: \(userID)")
                    isLoading = false
                    return
                }
                
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                let name = displayName.isEmpty ? "Apple 用户" : displayName
                
                // Check if user exists
                if let existingUser = try await userRepository.fetchUser(byAppleUserId: userID) {
                    existingUser.lastLoginAt = Date()
                    try await userRepository.updateUser(existingUser)
                    currentUser = existingUser
                    
                    // Create secure session
                    if let sessionService = sessionSecurityService {
                        let sessionToken = sessionService.createSession(for: existingUser.id, userRole: existingUser.primaryRole)
                        sessionService.resetRateLimit(for: userID)
                    }
                } else {
                    let newUser = User(appleUserId: userID, name: name, email: email)
                    try await userRepository.addUser(newUser)
                    currentUser = newUser
                    
                    // Create secure session
                    if let sessionService = sessionSecurityService {
                        let sessionToken = sessionService.createSession(for: newUser.id, userRole: newUser.primaryRole)
                        sessionService.resetRateLimit(for: userID)
                    }
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
        
        // Check rate limiting for SMS sending
        guard let sessionService = sessionSecurityService,
              sessionService.isAuthenticationAllowed(for: phoneNumber) else {
            print("❌ Security: SMS rate limited for phone: \(phoneNumber)")
            isLoading = false
            return
        }
        
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
        
        // Input validation for SMS code
        guard isValidSMSCode(code) else {
            print("❌ Security: Invalid SMS code format rejected")
            isLoading = false
            return
        }
        
        // In production, verify with SMS service
        // TODO: Replace with proper SMS service verification
        if isValidVerificationCode(code) {
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
                    
                    // Create secure session
                    if let sessionService = sessionSecurityService {
                        let sessionToken = sessionService.createSession(for: existingUser.id, userRole: existingUser.primaryRole)
                        sessionService.resetRateLimit(for: pendingUser.phone ?? "")
                    }
                } else {
                    try await userRepository.addUser(pendingUser)
                    currentUser = pendingUser
                    
                    // Create secure session
                    if let sessionService = sessionSecurityService {
                        let sessionToken = sessionService.createSession(for: pendingUser.id, userRole: pendingUser.primaryRole)
                        sessionService.resetRateLimit(for: pendingUser.phone ?? "")
                    }
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
    
    // MARK: - Session Validation
    
    /// 验证当前用户会话是否有效（增强版本，使用SessionSecurityService）
    func isSessionValid() -> Bool {
        guard let user = currentUser else {
            return false
        }
        
        // 检查用户是否已认证
        guard isAuthenticated else {
            return false
        }
        
        // 使用SessionSecurityService进行会话验证
        if let sessionService = sessionSecurityService {
            return sessionService.isSessionValid
        }
        
        // 回退到基本验证逻辑
        // 检查最后登录时间，如果超过24小时则认为session过期
        if let lastLogin = user.lastLoginAt {
            let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
            if lastLogin < twentyFourHoursAgo {
                return false
            }
        }
        
        // 检查用户对象是否完整
        if user.name.isEmpty {
            return false
        }
        
        return true
    }
    
    /// 强制session过期，需要重新登录
    func invalidateSession() {
        // 使用SessionSecurityService清理会话
        if let sessionService = sessionSecurityService {
            sessionService.invalidateSession()
        }
        
        currentUser = nil
        isAuthenticated = false
        showingSMSVerification = false
        smsCode = ""
        phoneNumber = ""
        pendingSMSUser = nil
    }
    
    // MARK: - Input Validation
    
    /// Validates WeChat ID format (basic security check)
    /// TODO: Implement proper WeChat ID format validation based on official specs
    private func isValidWeChatId(_ wechatId: String) -> Bool {
        // Basic validation - reject empty, too short, or suspicious patterns
        guard !wechatId.isEmpty,
              wechatId.count >= 3,
              wechatId.count <= 50 else {
            return false
        }
        
        // Reject common injection patterns and scripts
        let suspiciousPatterns = ["<script", "javascript:", "onload", "eval(", "alert("]
        for pattern in suspiciousPatterns {
            if wechatId.lowercased().contains(pattern) {
                return false
            }
        }
        
        // WeChat ID should contain only alphanumeric characters, underscore, and hyphen
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return wechatId.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    /// Validates user name format
    private func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty,
              name.count >= 1,
              name.count <= 50 else {
            return false
        }
        
        // Reject HTML/script injection attempts
        let suspiciousPatterns = ["<", ">", "script", "javascript:", "onload"]
        for pattern in suspiciousPatterns {
            if name.lowercased().contains(pattern) {
                return false
            }
        }
        
        return true
    }
    
    /// Validates SMS code format
    private func isValidSMSCode(_ code: String) -> Bool {
        // SMS codes should be 4-8 digits only
        guard !code.isEmpty,
              code.count >= 4,
              code.count <= 8 else {
            return false
        }
        
        // Only numeric characters allowed
        return code.allSatisfy { $0.isNumber }
    }
    
    /// Validates verification code (placeholder for actual SMS service integration)
    /// TODO: Replace with proper SMS service verification
    private func isValidVerificationCode(_ code: String) -> Bool {
        #if DEBUG
        // In DEBUG builds, accept "1234" for testing purposes only
        if code == "1234" {
            print("⚠️ DEBUG: Accepting test verification code")
            return true
        }
        #endif
        
        // In production, this should verify with SMS service
        // For now, reject all codes to prevent unauthorized access
        print("❌ SMS verification disabled - implement proper SMS service")
        return false
    }
} 