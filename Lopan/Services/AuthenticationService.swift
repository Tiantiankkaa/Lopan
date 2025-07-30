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
    
    private let modelContext: ModelContext
    private var pendingSMSUser: User?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Simulate WeChat login
    func loginWithWeChat(wechatId: String, name: String, phone: String? = nil) async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        do {
            // Fetch all users and filter in memory to avoid predicate issues
            let allUsers = try modelContext.fetch(FetchDescriptor<User>())
            let existingUsers = allUsers.filter { $0.wechatId == wechatId }
            
            if let existingUser = existingUsers.first {
                // User exists, update last login
                existingUser.lastLoginAt = Date()
                currentUser = existingUser
            } else {
                // Create new user
                let newUser = User(wechatId: wechatId, name: name, phone: phone)
                modelContext.insert(newUser)
                currentUser = newUser
            }
            
            try modelContext.save()
            isAuthenticated = true
            
        } catch {
            print("Authentication error: \(error)")
        }
        
        isLoading = false
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
    }
    
    func updateUserRoles(_ roles: [UserRole], primaryRole: UserRole) {
        guard let user = currentUser else { return }
        user.roles = roles
        user.primaryRole = primaryRole
        try? modelContext.save()
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
        try? modelContext.save()
    }
    
    /// Reset user back to original primary role
    func resetToOriginalRole() {
        guard let user = currentUser else { return }
        
        user.resetToOriginalRole()
        try? modelContext.save()
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
                let allUsers = try modelContext.fetch(FetchDescriptor<User>())
                let existingUsers = allUsers.filter { $0.appleUserId == userID }
                
                if let existingUser = existingUsers.first {
                    existingUser.lastLoginAt = Date()
                    currentUser = existingUser
                } else {
                    let newUser = User(appleUserId: userID, name: name, email: email)
                    modelContext.insert(newUser)
                    currentUser = newUser
                }
                
                try modelContext.save()
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
                let allUsers = try modelContext.fetch(FetchDescriptor<User>())
                let existingUsers = allUsers.filter { $0.phone == pendingUser.phone }
                
                if let existingUser = existingUsers.first {
                    existingUser.lastLoginAt = Date()
                    currentUser = existingUser
                } else {
                    modelContext.insert(pendingUser)
                    currentUser = pendingUser
                }
                
                try modelContext.save()
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