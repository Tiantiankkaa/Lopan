import Foundation
import CryptoKit
import SwiftUI

/// Secure session management service with timeout controls and audit logging
@MainActor
public final class SessionSecurityService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSessionValid: Bool = false
    @Published var sessionExpiresAt: Date?
    @Published var warningShown: Bool = false
    
    // MARK: - Private Properties
    
    private var sessionToken: String?
    private var sessionCreatedAt: Date?
    private var lastActivityAt: Date?
    private var sessionTimer: Timer?
    private var warningTimer: Timer?
    
    private let auditingService: NewAuditingService
    private let rateLimiter = RateLimiter(maxAttempts: 5, timeWindow: 300)
    
    // MARK: - Configuration
    
    private let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
    private let warningTime: TimeInterval = 5 * 60 // 5 minutes before expiry
    private let maxSessionDuration: TimeInterval = 8 * 60 * 60 // 8 hours absolute maximum
    
    // MARK: - Initialization
    
    init(auditingService: NewAuditingService) {
        self.auditingService = auditingService
        setupSessionMonitoring()
    }
    
    deinit {
        // Synchronous cleanup - only invalidate timers
        sessionTimer?.invalidate()
        warningTimer?.invalidate()
    }
    
    // MARK: - Session Management
    
    /// Creates a secure session token for authenticated users
    func createSession(for userId: String, userRole: UserRole) -> String {
        // Invalidate any existing session
        invalidateSession()
        
        // Generate cryptographically secure session token
        let tokenData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let token = tokenData.base64EncodedString()
        
        // Set session properties
        let now = Date()
        self.sessionToken = token
        self.sessionCreatedAt = now
        self.lastActivityAt = now
        self.sessionExpiresAt = now.addingTimeInterval(sessionTimeout)
        self.isSessionValid = true
        
        // Start session monitoring
        startSessionTimer()
        
        // Audit log session creation
        Task {
            try await auditingService.logSecurityEvent(
                event: "SESSION_CREATED",
                userId: userId,
                details: [
                    "userRole": userRole.rawValue,
                    "sessionId": generateSessionId(from: token),
                    "expiresAt": ISO8601DateFormatter().string(from: sessionExpiresAt!)
                ]
            )
        }
        
        return token
    }
    
    /// Validates the current session and updates activity timestamp
    func validateSession(token: String, userId: String) -> Bool {
        guard let currentToken = sessionToken,
              currentToken == token,
              isSessionValid else {
            
            // Audit failed validation attempt
            Task {
                try await auditingService.logSecurityEvent(
                    event: "SESSION_VALIDATION_FAILED",
                    userId: userId,
                    details: [
                        "reason": "invalid_token",
                        "attemptedToken": generateSessionId(from: token)
                    ]
                )
            }
            return false
        }
        
        let now = Date()
        
        // Check absolute session expiry
        if let createdAt = sessionCreatedAt,
           now.timeIntervalSince(createdAt) > maxSessionDuration {
            
            invalidateSession()
            
            Task {
                try await auditingService.logSecurityEvent(
                    event: "SESSION_EXPIRED_MAX_DURATION",
                    userId: userId,
                    details: ["sessionDuration": String(now.timeIntervalSince(createdAt))]
                )
            }
            return false
        }
        
        // Check inactivity timeout
        if let lastActivity = lastActivityAt,
           now.timeIntervalSince(lastActivity) > sessionTimeout {
            
            invalidateSession()
            
            Task {
                try await auditingService.logSecurityEvent(
                    event: "SESSION_EXPIRED_INACTIVITY",
                    userId: userId,
                    details: ["inactivityDuration": String(now.timeIntervalSince(lastActivity))]
                )
            }
            return false
        }
        
        // Update activity and extend session
        updateActivity()
        return true
    }
    
    /// Updates last activity timestamp and extends session
    func updateActivity() {
        guard isSessionValid else { return }
        
        let now = Date()
        lastActivityAt = now
        sessionExpiresAt = now.addingTimeInterval(sessionTimeout)
        
        // Reset warning state if we're no longer in warning period
        if let expiresAt = sessionExpiresAt,
           now.addingTimeInterval(warningTime) < expiresAt {
            warningShown = false
        }
        
        // Restart session timer
        startSessionTimer()
    }
    
    /// Invalidates the current session
    func invalidateSession() {
        sessionToken = nil
        sessionCreatedAt = nil
        lastActivityAt = nil
        sessionExpiresAt = nil
        isSessionValid = false
        warningShown = false
        
        sessionTimer?.invalidate()
        sessionTimer = nil
        warningTimer?.invalidate()
        warningTimer = nil
    }
    
    /// Forces logout with audit logging
    func forceLogout(userId: String, reason: String) {
        Task {
            try await auditingService.logSecurityEvent(
                event: "FORCED_LOGOUT",
                userId: userId,
                details: ["reason": reason]
            )
        }
        
        invalidateSession()
    }
    
    // MARK: - Rate Limiting
    
    /// Checks if authentication attempts are within rate limits
    func isAuthenticationAllowed(for identifier: String) -> Bool {
        return rateLimiter.isAllowed(for: identifier)
    }
    
    /// Resets rate limiting for successful authentication
    func resetRateLimit(for identifier: String) {
        rateLimiter.reset(for: identifier)
    }
    
    // MARK: - Private Methods
    
    private func setupSessionMonitoring() {
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackgrounded()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppForegrounded()
        }
    }
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        warningTimer?.invalidate()
        
        guard let expiresAt = sessionExpiresAt else { return }
        
        let now = Date()
        let timeToExpiry = expiresAt.timeIntervalSince(now)
        let timeToWarning = timeToExpiry - warningTime
        
        // Set warning timer
        if timeToWarning > 0 && !warningShown {
            warningTimer = Timer.scheduledTimer(withTimeInterval: timeToWarning, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, 
                          self.sessionToken != nil,
                          self.isSessionValid else { return }
                    self.showSessionWarning()
                }
            }
        }
        
        // Set expiry timer
        if timeToExpiry > 0 {
            sessionTimer = Timer.scheduledTimer(withTimeInterval: timeToExpiry, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self,
                          self.sessionToken != nil,
                          self.isSessionValid else { return }
                    self.handleSessionExpiry()
                }
            }
        }
    }
    
    private func showSessionWarning() {
        guard isSessionValid else { return }
        warningShown = true
    }
    
    private func handleSessionExpiry() {
        guard isSessionValid else { return }
        invalidateSession()
    }
    
    private func handleAppBackgrounded() {
        // Optional: Implement additional security measures when app goes to background
        // For example, blur content or require re-authentication
    }
    
    private func handleAppForegrounded() {
        // Validate session is still active when returning to foreground
        guard isSessionValid,
              let lastActivity = lastActivityAt else {
            return
        }
        
        let backgroundTime = Date().timeIntervalSince(lastActivity)
        if backgroundTime > sessionTimeout {
            invalidateSession()
        }
    }
    
    private func generateSessionId(from token: String) -> String {
        // Generate a safe session identifier for logging (not the full token)
        let data = Data(token.utf8)
        let hash = SHA256.hash(data: data)
        return String(hash.prefix(8).map { String(format: "%02x", $0) }.joined())
    }
}

// MARK: - Session Warning View

struct SessionWarningAlert: View {
    @ObservedObject var sessionService: SessionSecurityService
    let onExtendSession: () -> Void
    let onLogout: () -> Void
    
    var body: some View {
        if sessionService.warningShown && sessionService.isSessionValid {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(LopanColors.warning)
                
                Text("会话即将过期")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("您的会话将在5分钟后过期，请选择继续工作或安全退出。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button("安全退出") {
                        onLogout()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("继续工作") {
                        onExtendSession()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .background(LopanColors.backgroundPrimary)
            .cornerRadius(16)
            .shadow(radius: 8)
            .padding()
        }
    }
}

// MARK: - Audit Service Extension

extension NewAuditingService {
    
    /// Logs security-related events with enhanced details
    func logSecurityEvent(
        event: String,
        userId: String,
        details: [String: String] = [:]
    ) async throws {
        
        var securityDetails = details
        securityDetails["eventType"] = "SECURITY"
        securityDetails["timestamp"] = ISO8601DateFormatter().string(from: Date())
        securityDetails["deviceId"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        try await logOperation(
            operationType: .create, // Map security events to operation types as needed
            entityType: .user,
            entityId: "SYSTEM",
            entityDescription: event,
            operatorUserId: userId,
            operatorUserName: "Security System",
            operationDetails: securityDetails
        )
    }
}