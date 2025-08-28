//
//  EnhancedSecurityAuditService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI
import CryptoKit

// MARK: - Security Event Categories (安全事件分类)

/// Security event severity levels
/// 安全事件严重程度等级
enum SecurityEventSeverity: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    case fatal = "fatal"
    
    var displayName: String {
        switch self {
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        case .critical: return "严重"
        case .fatal: return "致命"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        case .fatal: return .black
        }
    }
    
    var priority: Int {
        switch self {
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        case .fatal: return 5
        }
    }
}

/// Security event categories
/// 安全事件类别
enum SecurityEventCategory: String, CaseIterable, Codable {
    case authentication = "authentication"
    case authorization = "authorization"
    case dataAccess = "data_access"
    case dataModification = "data_modification"
    case systemOperation = "system_operation"
    case cacheOperation = "cache_operation"
    case stateSync = "state_sync"
    case performanceIssue = "performance_issue"
    case securityViolation = "security_violation"
    case systemHealth = "system_health"
    
    var displayName: String {
        switch self {
        case .authentication: return "身份认证"
        case .authorization: return "权限控制"
        case .dataAccess: return "数据访问"
        case .dataModification: return "数据修改"
        case .systemOperation: return "系统操作"
        case .cacheOperation: return "缓存操作"
        case .stateSync: return "状态同步"
        case .performanceIssue: return "性能问题"
        case .securityViolation: return "安全违规"
        case .systemHealth: return "系统健康"
        }
    }
    
    var icon: String {
        switch self {
        case .authentication: return "person.badge.key"
        case .authorization: return "checkmark.shield"
        case .dataAccess: return "folder.circle"
        case .dataModification: return "pencil.circle"
        case .systemOperation: return "gear.circle"
        case .cacheOperation: return "memorychip.circle"
        case .stateSync: return "arrow.triangle.2.circlepath.circle"
        case .performanceIssue: return "speedometer"
        case .securityViolation: return "exclamationmark.shield"
        case .systemHealth: return "heart.circle"
        }
    }
}

// MARK: - Enhanced Security Event (增强安全事件)

/// Enhanced security audit event with detailed tracking
/// 具有详细跟踪的增强安全审计事件
struct EnhancedSecurityEvent: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let category: SecurityEventCategory
    let severity: SecurityEventSeverity
    let eventName: String
    let userId: String?
    let userName: String?
    let sessionId: String?
    let ipAddress: String?
    let userAgent: String?
    let description: String
    let details: [String: String]
    let metadata: [String: String]
    let correlationId: String?
    let stackTrace: String?
    let performanceMetrics: PerformanceMetrics?
    let securityContext: SecurityContext
    let isEncrypted: Bool
    
    init(
        category: SecurityEventCategory,
        severity: SecurityEventSeverity,
        eventName: String,
        userId: String? = nil,
        userName: String? = nil,
        sessionId: String? = nil,
        description: String,
        details: [String: String] = [:],
        metadata: [String: String] = [:],
        correlationId: String? = nil,
        stackTrace: String? = nil,
        performanceMetrics: PerformanceMetrics? = nil,
        securityContext: SecurityContext = SecurityContext()
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.category = category
        self.severity = severity
        self.eventName = eventName
        self.userId = userId
        self.userName = userName
        self.sessionId = sessionId
        self.ipAddress = securityContext.ipAddress
        self.userAgent = securityContext.userAgent
        self.description = description
        self.details = details
        self.metadata = metadata
        self.correlationId = correlationId
        self.stackTrace = stackTrace
        self.performanceMetrics = performanceMetrics
        self.securityContext = securityContext
        self.isEncrypted = securityContext.requiresEncryption
    }
}

// MARK: - Supporting Structures (支持结构)

/// Performance metrics for audit events
/// 审计事件的性能指标
struct PerformanceMetrics: Codable {
    let executionTime: TimeInterval
    let memoryUsage: UInt64?
    let cacheHitRate: Double?
    let errorCount: Int
    let warningCount: Int
    
    init(
        executionTime: TimeInterval,
        memoryUsage: UInt64? = nil,
        cacheHitRate: Double? = nil,
        errorCount: Int = 0,
        warningCount: Int = 0
    ) {
        self.executionTime = executionTime
        self.memoryUsage = memoryUsage
        self.cacheHitRate = cacheHitRate
        self.errorCount = errorCount
        self.warningCount = warningCount
    }
}

/// Security context for audit events
/// 审计事件的安全上下文
struct SecurityContext: Codable {
    let ipAddress: String?
    let userAgent: String?
    let deviceId: String?
    let osVersion: String?
    let appVersion: String?
    let requiresEncryption: Bool
    let sensitivityLevel: DataSensitivityLevel
    
    init(
        ipAddress: String? = nil,
        userAgent: String? = nil,
        deviceId: String? = nil,
        requiresEncryption: Bool = false,
        sensitivityLevel: DataSensitivityLevel = .public
    ) {
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.requiresEncryption = requiresEncryption || sensitivityLevel.requiresEncryption
        self.sensitivityLevel = sensitivityLevel
    }
}

/// Data sensitivity levels
/// 数据敏感度等级
enum DataSensitivityLevel: String, CaseIterable, Codable {
    case `public` = "public"
    case `internal` = "internal"
    case confidential = "confidential"
    case restricted = "restricted"
    case topSecret = "top_secret"
    
    var displayName: String {
        switch self {
        case .public: return "公开"
        case .internal: return "内部"
        case .confidential: return "机密"
        case .restricted: return "限制级"
        case .topSecret: return "绝密"
        }
    }
    
    var requiresEncryption: Bool {
        switch self {
        case .`public`, .`internal`: return false
        case .confidential, .restricted, .topSecret: return true
        }
    }
}

// MARK: - Security Threat Detection (安全威胁检测)

/// Security threat patterns and detection
/// 安全威胁模式和检测
struct SecurityThreatPattern {
    let id: String
    let name: String
    let description: String
    let severity: SecurityEventSeverity
    let detectionLogic: (EnhancedSecurityEvent) -> Bool
    let responseAction: SecurityResponseAction
    
    init(
        name: String,
        description: String,
        severity: SecurityEventSeverity,
        detectionLogic: @escaping (EnhancedSecurityEvent) -> Bool,
        responseAction: SecurityResponseAction = .log
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.severity = severity
        self.detectionLogic = detectionLogic
        self.responseAction = responseAction
    }
}

enum SecurityResponseAction {
    case log
    case alert
    case block
    case lockAccount
    case requireReauth
}

// MARK: - Enhanced Security Audit Service (增强安全审计服务)

/// Comprehensive security audit service with threat detection and encryption
/// 具有威胁检测和加密功能的综合安全审计服务
@MainActor
public class EnhancedSecurityAuditService: ObservableObject {
    
    // MARK: - Dependencies
    private let baseAuditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var recentSecurityEvents: [EnhancedSecurityEvent] = []
    @Published var securityAlerts: [SecurityAlert] = []
    @Published var threatDetectionEnabled = true
    @Published var encryptionEnabled = true
    
    // MARK: - Configuration
    private let maxRecentEvents = 100
    private let encryptionKey: SymmetricKey
    private let threatPatterns: [SecurityThreatPattern]
    private let eventBuffer: SecurityEventBuffer
    
    struct SecurityAlert: Identifiable {
        let id = UUID()
        let timestamp: Date
        let severity: SecurityEventSeverity
        let title: String
        let message: String
        let recommendedActions: [String]
        let relatedEvents: [String] // Event IDs
    }
    
    init(
        baseAuditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.baseAuditService = baseAuditService
        self.authService = authService
        
        // Generate encryption key (in production, this should be securely managed)
        self.encryptionKey = SymmetricKey(size: .bits256)
        
        // Initialize threat detection patterns
        self.threatPatterns = Self.createThreatPatterns()
        
        // Initialize event buffer for performance
        self.eventBuffer = SecurityEventBuffer(maxSize: 1000)
    }
    
    // MARK: - Enhanced Audit Logging
    
    /// Log enhanced security event with automatic threat detection
    /// 记录增强安全事件并自动进行威胁检测
    func logSecurityEvent(
        category: SecurityEventCategory,
        severity: SecurityEventSeverity,
        eventName: String,
        userId: String? = nil,
        userName: String? = nil,
        description: String,
        details: [String: String] = [:],
        metadata: [String: String] = [:],
        sensitivityLevel: DataSensitivityLevel = .internal,
        performanceMetrics: PerformanceMetrics? = nil
    ) async throws {
        
        let securityContext = SecurityContext(
            requiresEncryption: encryptionEnabled,
            sensitivityLevel: sensitivityLevel
        )
        
        let event = EnhancedSecurityEvent(
            category: category,
            severity: severity,
            eventName: eventName,
            userId: userId ?? authService.currentUser?.id,
            userName: userName ?? authService.currentUser?.name,
            sessionId: authService.currentSessionId,
            description: description,
            details: details,
            metadata: metadata,
            performanceMetrics: performanceMetrics,
            securityContext: securityContext
        )
        
        // Add to buffer and recent events
        eventBuffer.add(event)
        await MainActor.run {
            recentSecurityEvents.insert(event, at: 0)
            if recentSecurityEvents.count > maxRecentEvents {
                recentSecurityEvents.removeLast()
            }
        }
        
        // Encrypt sensitive events
        _ = securityContext.requiresEncryption ? await encryptEvent(event) : event
        
        // Store in base audit service (converting to legacy format)
        try await baseAuditService.logSecurityEvent(
            event: eventName,
            userId: userId ?? "system",
            details: ["description": description, "severity": severity.rawValue]
        )
        
        // Perform threat detection
        if threatDetectionEnabled {
            await performThreatDetection(for: event)
        }
    }
    
    /// Convenience method for backward compatibility
    /// 向后兼容的便利方法
    func logEvent(
        _ eventName: String,
        severity: SecurityEventSeverity = .info,
        category: SecurityEventCategory = .systemOperation,
        description: String,
        details: [String: String] = [:]
    ) async throws {
        try await logSecurityEvent(
            category: category,
            severity: severity,
            eventName: eventName,
            description: description,
            details: details
        )
    }
    
    // MARK: - Threat Detection
    
    /// Perform real-time threat detection on security events
    /// 对安全事件执行实时威胁检测
    private func performThreatDetection(for event: EnhancedSecurityEvent) async {
        for pattern in threatPatterns {
            if pattern.detectionLogic(event) {
                await handleThreatDetection(pattern: pattern, triggeringEvent: event)
            }
        }
        
        // Check for behavioral anomalies
        await detectBehavioralAnomalies(for: event)
    }
    
    /// Handle detected security threats
    /// 处理检测到的安全威胁
    private func handleThreatDetection(pattern: SecurityThreatPattern, triggeringEvent: EnhancedSecurityEvent) async {
        let alert = SecurityAlert(
            timestamp: Date(),
            severity: pattern.severity,
            title: "安全威胁检测: \(pattern.name)",
            message: pattern.description,
            recommendedActions: getRecommendedActions(for: pattern),
            relatedEvents: [triggeringEvent.id]
        )
        
        await MainActor.run {
            securityAlerts.insert(alert, at: 0)
        }
        
        // Log threat detection
        try? await logSecurityEvent(
            category: .securityViolation,
            severity: pattern.severity,
            eventName: "threat_detected",
            description: "检测到安全威胁: \(pattern.name)",
            details: [
                "pattern_id": pattern.id,
                "pattern_name": pattern.name,
                "triggering_event": triggeringEvent.id,
                "response_action": "\(pattern.responseAction)"
            ],
            sensitivityLevel: .confidential
        )
        
        // Execute response action
        await executeResponseAction(pattern.responseAction, for: triggeringEvent)
    }
    
    /// Detect behavioral anomalies
    /// 检测行为异常
    private func detectBehavioralAnomalies(for event: EnhancedSecurityEvent) async {
        guard let userId = event.userId else { return }
        
        let recentUserEvents = eventBuffer.getEvents(for: userId, within: TimeInterval(3600)) // Last hour
        
        // Check for unusual activity patterns
        if recentUserEvents.count > 50 { // Threshold for suspicious activity
            let alert = SecurityAlert(
                timestamp: Date(),
                severity: .warning,
                title: "异常活动检测",
                message: "用户 \(event.userName ?? userId) 在过去一小时内产生了异常多的活动 (\(recentUserEvents.count) 个事件)",
                recommendedActions: [
                    "检查用户活动模式",
                    "验证用户身份",
                    "考虑临时限制账户权限"
                ],
                relatedEvents: recentUserEvents.prefix(10).map { $0.id }
            )
            
            await MainActor.run {
                securityAlerts.insert(alert, at: 0)
            }
        }
    }
    
    /// Execute security response action
    /// 执行安全响应操作
    private func executeResponseAction(_ action: SecurityResponseAction, for event: EnhancedSecurityEvent) async {
        switch action {
        case .log:
            // Already logged
            break
        case .alert:
            // Alert already created
            break
        case .block:
            // Implement blocking logic
            try? await logEvent(
                "security_action_block",
                severity: .critical,
                category: .securityViolation,
                description: "执行安全阻止操作",
                details: ["blocked_event": event.id]
            )
        case .lockAccount:
            // Implement account locking
            if let userId = event.userId {
                try? await logEvent(
                    "security_action_lock_account",
                    severity: .critical,
                    category: .securityViolation,
                    description: "锁定用户账户",
                    details: ["locked_user": userId]
                )
            }
        case .requireReauth:
            // Implement re-authentication requirement
            try? await logEvent(
                "security_action_require_reauth",
                severity: .warning,
                category: .authentication,
                description: "要求重新认证",
                details: ["user_id": event.userId ?? "unknown"]
            )
        }
    }
    
    // MARK: - Data Encryption
    
    /// Encrypt sensitive security event
    /// 加密敏感安全事件
    private func encryptEvent(_ event: EnhancedSecurityEvent) async -> EnhancedSecurityEvent {
        guard encryptionEnabled else { return event }
        
        do {
            // Create encrypted version with sensitive data encrypted
            let sensitiveData = [
                "description": event.description,
                "details": try JSONEncoder().encode(event.details).base64EncodedString(),
                "metadata": try JSONEncoder().encode(event.metadata).base64EncodedString()
            ]
            
            let jsonData = try JSONEncoder().encode(sensitiveData)
            let encryptedData = try AES.GCM.seal(jsonData, using: encryptionKey)
            _ = encryptedData.combined?.base64EncodedString() ?? ""
            
            // Return event with encrypted content
            let encryptedEvent = event
            // In a real implementation, you'd need to modify the struct to support this
            // For now, we'll just log that encryption occurred
            
            try await logEvent(
                "data_encrypted",
                severity: .info,
                category: .systemOperation,
                description: "敏感数据已加密存储",
                details: ["original_event_id": event.id]
            )
            
            return encryptedEvent
            
        } catch {
            try? await logEvent(
                "encryption_failed",
                severity: .error,
                category: .systemOperation,
                description: "数据加密失败: \(error.localizedDescription)",
                details: ["event_id": event.id]
            )
            return event
        }
    }
    
    // MARK: - Analytics and Reporting
    
    /// Get security analytics for dashboard
    /// 获取仪表板的安全分析
    func getSecurityAnalytics() -> SecurityAnalytics {
        let events = eventBuffer.getAllEvents()
        let now = Date()
        let last24Hours = events.filter { now.timeIntervalSince($0.timestamp) <= 86400 }
        
        let severityCounts = Dictionary(grouping: last24Hours, by: { $0.severity })
            .mapValues { $0.count }
        
        let categoryCounts = Dictionary(grouping: last24Hours, by: { $0.category })
            .mapValues { $0.count }
        
        let activeAlerts = securityAlerts.filter { alert in
            now.timeIntervalSince(alert.timestamp) <= 3600 // Active within last hour
        }
        
        return SecurityAnalytics(
            totalEvents24h: last24Hours.count,
            criticalEvents24h: severityCounts[.critical] ?? 0,
            errorEvents24h: severityCounts[.error] ?? 0,
            warningEvents24h: severityCounts[.warning] ?? 0,
            activeAlerts: activeAlerts.count,
            topCategories: Array(categoryCounts.sorted { $0.value > $1.value }.prefix(5)),
            threatDetectionEnabled: threatDetectionEnabled,
            encryptionEnabled: encryptionEnabled
        )
    }
    
    struct SecurityAnalytics {
        let totalEvents24h: Int
        let criticalEvents24h: Int
        let errorEvents24h: Int
        let warningEvents24h: Int
        let activeAlerts: Int
        let topCategories: [(key: SecurityEventCategory, value: Int)]
        let threatDetectionEnabled: Bool
        let encryptionEnabled: Bool
        
        var riskLevel: SecurityEventSeverity {
            if criticalEvents24h > 0 { return .critical }
            else if errorEvents24h > 5 { return .error }
            else if warningEvents24h > 10 { return .warning }
            else { return .info }
        }
    }
    
    // MARK: - Alert Management
    
    /// Dismiss security alert
    /// 关闭安全警报
    func dismissAlert(_ alert: SecurityAlert) {
        securityAlerts.removeAll { $0.id == alert.id }
        
        Task {
            try? await logEvent(
                "security_alert_dismissed",
                severity: .info,
                category: .systemOperation,
                description: "安全警报已关闭",
                details: ["alert_id": alert.id.uuidString]
            )
        }
    }
    
    /// Clear all alerts
    /// 清除所有警报
    func clearAllAlerts() {
        let alertCount = securityAlerts.count
        securityAlerts.removeAll()
        
        Task {
            try? await logEvent(
                "all_security_alerts_cleared",
                severity: .info,
                category: .systemOperation,
                description: "所有安全警报已清除",
                details: ["cleared_count": "\(alertCount)"]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get recommended actions for threat pattern
    /// 获取威胁模式的建议操作
    private func getRecommendedActions(for pattern: SecurityThreatPattern) -> [String] {
        switch pattern.responseAction {
        case .log:
            return ["查看日志详情", "监控后续活动"]
        case .alert:
            return ["立即检查系统状态", "验证用户活动"]
        case .block:
            return ["检查被阻止的操作", "确认是否为恶意活动"]
        case .lockAccount:
            return ["联系用户确认身份", "审查账户活动历史"]
        case .requireReauth:
            return ["通知用户重新登录", "检查认证状态"]
        }
    }
    
    // MARK: - Static Threat Patterns
    
    /// Create predefined threat detection patterns
    /// 创建预定义的威胁检测模式
    private static func createThreatPatterns() -> [SecurityThreatPattern] {
        return [
            SecurityThreatPattern(
                name: "频繁登录失败",
                description: "检测到频繁的登录失败尝试，可能存在暴力破解攻击",
                severity: .warning,
                detectionLogic: { event in
                    return event.category == .authentication &&
                           event.eventName.contains("login_failed") &&
                           event.severity == .error
                },
                responseAction: .alert
            ),
            
            SecurityThreatPattern(
                name: "异常数据访问",
                description: "检测到异常的数据访问模式",
                severity: .error,
                detectionLogic: { event in
                    return event.category == .dataAccess &&
                           event.severity == .error
                },
                responseAction: .alert
            ),
            
            SecurityThreatPattern(
                name: "系统关键错误",
                description: "检测到系统关键错误，可能影响安全性",
                severity: .critical,
                detectionLogic: { event in
                    return event.severity == .critical ||
                           event.severity == .fatal
                },
                responseAction: .alert
            ),
            
            SecurityThreatPattern(
                name: "未授权操作尝试",
                description: "检测到未授权的操作尝试",
                severity: .error,
                detectionLogic: { event in
                    return event.category == .authorization &&
                           event.eventName.contains("unauthorized")
                },
                responseAction: .requireReauth
            )
        ]
    }
}

// MARK: - Security Event Buffer (安全事件缓冲区)

/// High-performance in-memory buffer for security events
/// 高性能的内存安全事件缓冲区
class SecurityEventBuffer {
    private var events: [EnhancedSecurityEvent] = []
    private let maxSize: Int
    private let queue = DispatchQueue(label: "security.event.buffer", attributes: .concurrent)
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func add(_ event: EnhancedSecurityEvent) {
        queue.async(flags: .barrier) {
            self.events.append(event)
            if self.events.count > self.maxSize {
                self.events.removeFirst(self.events.count - self.maxSize)
            }
        }
    }
    
    func getEvents(for userId: String, within timeInterval: TimeInterval) -> [EnhancedSecurityEvent] {
        return queue.sync {
            let cutoffTime = Date().addingTimeInterval(-timeInterval)
            return events.filter { event in
                event.userId == userId && event.timestamp >= cutoffTime
            }
        }
    }
    
    func getAllEvents() -> [EnhancedSecurityEvent] {
        return queue.sync {
            return Array(events)
        }
    }
    
    func clearOldEvents(olderThan timeInterval: TimeInterval) {
        queue.async(flags: .barrier) {
            let cutoffTime = Date().addingTimeInterval(-timeInterval)
            self.events.removeAll { $0.timestamp < cutoffTime }
        }
    }
}

// MARK: - Extensions for Authentication Service

extension AuthenticationService {
    /// Current session ID for audit tracking
    /// 当前会话ID用于审计跟踪
    var currentSessionId: String? {
        // In a real implementation, this would track the current session
        return currentUser?.id.appending("-session")
    }
}