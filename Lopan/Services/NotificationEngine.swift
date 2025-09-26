//
//  NotificationEngine.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Notification Types and Categories (通知类型和分类)

/// Notification priority levels
/// 通知优先级等级
enum NotificationPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        case .critical: return "严重"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return LopanColors.textSecondary
        case .medium: return LopanColors.primary
        case .high: return LopanColors.warning
        case .urgent: return LopanColors.error
        case .critical: return LopanColors.primary
        }
    }
    
    var deliveryDelay: TimeInterval {
        switch self {
        case .low: return 300 // 5 minutes
        case .medium: return 60 // 1 minute
        case .high: return 30 // 30 seconds
        case .urgent: return 5 // 5 seconds
        case .critical: return 0 // Immediate
        }
    }
}

/// Notification categories for business logic
/// 业务逻辑的通知分类
enum NotificationCategory: String, CaseIterable, Codable {
    case production = "production"
    case machine = "machine"
    case quality = "quality"
    case maintenance = "maintenance"
    case security = "security"
    case system = "system"
    case user = "user"
    case batch = "batch"
    case inventory = "inventory"
    
    var displayName: String {
        switch self {
        case .production: return "生产"
        case .machine: return "机台"
        case .quality: return "质量"
        case .maintenance: return "维护"
        case .security: return "安全"
        case .system: return "系统"
        case .user: return "用户"
        case .batch: return "批次"
        case .inventory: return "库存"
        }
    }
    
    var icon: String {
        switch self {
        case .production: return "factory"
        case .machine: return "gear"
        case .quality: return "checkmark.seal"
        case .maintenance: return "wrench"
        case .security: return "shield"
        case .system: return "server.rack"
        case .user: return "person.circle"
        case .batch: return "folder.badge.gearshape"
        case .inventory: return "cube.box"
        }
    }
}

/// Notification delivery channels
/// 通知传递渠道
enum NotificationChannel: String, CaseIterable, Codable {
    case inApp = "in_app"
    case push = "push"
    case email = "email"
    case sms = "sms"
    case dashboard = "dashboard"
    
    var displayName: String {
        switch self {
        case .inApp: return "应用内"
        case .push: return "推送通知"
        case .email: return "邮件"
        case .sms: return "短信"
        case .dashboard: return "仪表板"
        }
    }
}

// MARK: - Notification Message Structure (通知消息结构)

/// Core notification message
/// 核心通知消息
struct NotificationMessage: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let category: NotificationCategory
    let priority: NotificationPriority
    let title: String
    let body: String
    let data: [String: String]
    let targetUserIds: [String]
    let targetRoles: [UserRole]
    let channels: [NotificationChannel]
    let expiresAt: Date?
    let isRead: Bool
    let actionButtons: [NotificationAction]
    let relatedEntityId: String?
    let relatedEntityType: String?
    
    init(
        category: NotificationCategory,
        priority: NotificationPriority,
        title: String,
        body: String,
        data: [String: String] = [:],
        targetUserIds: [String] = [],
        targetRoles: [UserRole] = [],
        channels: [NotificationChannel] = [.inApp],
        expiresAt: Date? = nil,
        actionButtons: [NotificationAction] = [],
        relatedEntityId: String? = nil,
        relatedEntityType: String? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.category = category
        self.priority = priority
        self.title = title
        self.body = body
        self.data = data
        self.targetUserIds = targetUserIds
        self.targetRoles = targetRoles
        self.channels = channels
        self.expiresAt = expiresAt
        self.isRead = false
        self.actionButtons = actionButtons
        self.relatedEntityId = relatedEntityId
        self.relatedEntityType = relatedEntityType
    }
}

/// Notification action buttons
/// 通知操作按钮
struct NotificationAction: Identifiable, Codable {
    let id: String
    let title: String
    let style: ActionStyle
    let action: ActionType
    let data: [String: String]
    
    enum ActionStyle: String, Codable {
        case `default` = "default"
        case destructive = "destructive"
        case cancel = "cancel"
    }
    
    enum ActionType: String, Codable {
        case navigate = "navigate"
        case approve = "approve"
        case reject = "reject"
        case acknowledge = "acknowledge"
        case custom = "custom"
    }
    
    init(title: String, style: ActionStyle = .default, action: ActionType, data: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.title = title
        self.style = style
        self.action = action
        self.data = data
    }
}

// MARK: - Notification Templates (通知模板)

/// Predefined notification templates for common scenarios
/// 常见场景的预定义通知模板
struct NotificationTemplate {
    let id: String
    let name: String
    let category: NotificationCategory
    let priority: NotificationPriority
    let titleTemplate: String
    let bodyTemplate: String
    let defaultChannels: [NotificationChannel]
    let defaultActions: [NotificationAction]
    let targetRoles: [UserRole]
    
    // Common notification templates
    static let templates: [String: NotificationTemplate] = [
        "batch_completed": NotificationTemplate(
            id: "batch_completed",
            name: "批次完成通知",
            category: .production,
            priority: .medium,
            titleTemplate: "批次 {batchNumber} 已完成",
            bodyTemplate: "机台 {machineNumber} 上的批次 {batchNumber} 已成功完成，用时 {duration}",
            defaultChannels: [.inApp, .dashboard],
            defaultActions: [
                NotificationAction(title: "查看详情", action: .navigate, data: ["route": "batch_detail"]),
                NotificationAction(title: "确认", action: .acknowledge)
            ],
            targetRoles: [.workshopManager, .administrator]
        ),
        
        "machine_error": NotificationTemplate(
            id: "machine_error",
            name: "机台错误警报",
            category: .machine,
            priority: .urgent,
            titleTemplate: "机台 {machineNumber} 发生错误",
            bodyTemplate: "机台 {machineNumber} 出现异常: {errorMessage}。请立即检查处理。",
            defaultChannels: [.inApp, .push, .dashboard],
            defaultActions: [
                NotificationAction(title: "立即处理", action: .navigate, data: ["route": "machine_detail"]),
                NotificationAction(title: "报告维护", action: .custom, data: ["action": "report_maintenance"])
            ],
            targetRoles: [.workshopTechnician, .workshopManager, .administrator]
        ),
        
        "quality_issue": NotificationTemplate(
            id: "quality_issue",
            name: "质量问题警报",
            category: .quality,
            priority: .high,
            titleTemplate: "发现质量问题",
            bodyTemplate: "批次 {batchNumber} 在机台 {machineNumber} 上检测到质量问题: {issueDescription}",
            defaultChannels: [.inApp, .dashboard],
            defaultActions: [
                NotificationAction(title: "查看详情", action: .navigate, data: ["route": "quality_detail"]),
                NotificationAction(title: "标记已处理", action: .acknowledge)
            ],
            targetRoles: [.workshopManager, .administrator]
        ),
        
        "maintenance_due": NotificationTemplate(
            id: "maintenance_due",
            name: "维护提醒",
            category: .maintenance,
            priority: .medium,
            titleTemplate: "机台维护提醒",
            bodyTemplate: "机台 {machineNumber} 需要进行定期维护，下次维护时间: {maintenanceDate}",
            defaultChannels: [.inApp, .dashboard],
            defaultActions: [
                NotificationAction(title: "安排维护", action: .navigate, data: ["route": "maintenance_schedule"]),
                NotificationAction(title: "稍后提醒", action: .custom, data: ["action": "snooze"])
            ],
            targetRoles: [.workshopTechnician, .workshopManager]
        ),
        
        "security_alert": NotificationTemplate(
            id: "security_alert",
            name: "安全警报",
            category: .security,
            priority: .critical,
            titleTemplate: "安全威胁检测",
            bodyTemplate: "检测到安全威胁: {threatType}。详情: {description}",
            defaultChannels: [.inApp, .push, .dashboard],
            defaultActions: [
                NotificationAction(title: "立即查看", action: .navigate, data: ["route": "security_detail"]),
                NotificationAction(title: "确认处理", action: .acknowledge)
            ],
            targetRoles: [.administrator]
        ),
        
        "system_health": NotificationTemplate(
            id: "system_health",
            name: "系统健康警报",
            category: .system,
            priority: .high,
            titleTemplate: "系统健康警报",
            bodyTemplate: "系统健康检查发现问题: {issueType}。影响等级: {severity}",
            defaultChannels: [.inApp, .dashboard],
            defaultActions: [
                NotificationAction(title: "查看详情", action: .navigate, data: ["route": "system_health"]),
                NotificationAction(title: "开始修复", action: .custom, data: ["action": "auto_repair"])
            ],
            targetRoles: [.administrator]
        )
    ]
}

// MARK: - Message Routing and Delivery (消息路由和传递)

/// Message router for determining delivery channels and targets
/// 确定传递渠道和目标的消息路由器
class NotificationRouter {
    
    /// Route notification to appropriate channels and users
    /// 将通知路由到适当的渠道和用户
    static func routeNotification(_ message: NotificationMessage, currentUser: User?) -> RoutingResult {
        var deliveryPlan: [DeliveryInstruction] = []
        
        // Determine target users based on roles and explicit user IDs
        var targetUsers = Set<String>()
        
        // Add explicitly specified users
        targetUsers.formUnion(message.targetUserIds)
        
        // Add users based on roles (this would typically query a user service)
        // For now, we'll simulate this based on current user
        if let currentUser = currentUser,
           message.targetRoles.contains(currentUser.primaryRole) {
            targetUsers.insert(currentUser.id)
        }
        
        // Create delivery instructions for each channel and user combination
        for channel in message.channels {
            for userId in targetUsers {
                let canDeliver = checkDeliveryPermissions(
                    channel: channel,
                    priority: message.priority,
                    category: message.category,
                    userId: userId
                )
                
                if canDeliver {
                    let instruction = DeliveryInstruction(
                        messageId: message.id,
                        userId: userId,
                        channel: channel,
                        priority: message.priority,
                        scheduledAt: Date().addingTimeInterval(message.priority.deliveryDelay),
                        retryCount: 0,
                        maxRetries: getMaxRetries(for: channel, priority: message.priority)
                    )
                    deliveryPlan.append(instruction)
                }
            }
        }
        
        return RoutingResult(
            messageId: message.id,
            deliveryInstructions: deliveryPlan,
            estimatedDeliveryTime: Date().addingTimeInterval(message.priority.deliveryDelay),
            routingDecisions: createRoutingDecisions(for: message)
        )
    }
    
    /// Check if delivery is allowed for specific parameters
    /// 检查特定参数是否允许传递
    private static func checkDeliveryPermissions(
        channel: NotificationChannel,
        priority: NotificationPriority,
        category: NotificationCategory,
        userId: String
    ) -> Bool {
        // Business logic for delivery permissions
        switch channel {
        case .push:
            // Only allow push for high priority or above
            return priority.rawValue == "high" || priority.rawValue == "urgent" || priority.rawValue == "critical"
        case .email:
            // Email for medium priority and above
            return priority.rawValue != "low"
        case .sms:
            // SMS only for urgent and critical
            return priority.rawValue == "urgent" || priority.rawValue == "critical"
        case .inApp, .dashboard:
            // Always allow in-app and dashboard notifications
            return true
        }
    }
    
    /// Get maximum retry attempts for channel and priority
    /// 获取渠道和优先级的最大重试次数
    private static func getMaxRetries(for channel: NotificationChannel, priority: NotificationPriority) -> Int {
        switch (channel, priority) {
        case (.push, .critical), (.sms, .critical):
            return 5
        case (.push, .urgent), (.email, .urgent):
            return 3
        case (.push, .high), (.email, .high):
            return 2
        default:
            return 1
        }
    }
    
    /// Create routing decision log
    /// 创建路由决策日志
    private static func createRoutingDecisions(for message: NotificationMessage) -> [RoutingDecision] {
        var decisions: [RoutingDecision] = []
        
        for channel in message.channels {
            decisions.append(RoutingDecision(
                channel: channel,
                decision: .approved,
                reason: "Channel approved for \(message.category.displayName) category with \(message.priority.displayName) priority",
                timestamp: Date()
            ))
        }
        
        return decisions
    }
}

// MARK: - Routing Support Structures (路由支持结构)

/// Delivery instruction for notification routing
/// 通知路由的传递指令
struct DeliveryInstruction {
    let messageId: String
    let userId: String
    let channel: NotificationChannel
    let priority: NotificationPriority
    let scheduledAt: Date
    let retryCount: Int
    let maxRetries: Int
}

/// Result of routing operation
/// 路由操作的结果
struct RoutingResult {
    let messageId: String
    let deliveryInstructions: [DeliveryInstruction]
    let estimatedDeliveryTime: Date
    let routingDecisions: [RoutingDecision]
}

/// Individual routing decision
/// 单个路由决策
struct RoutingDecision {
    let channel: NotificationChannel
    let decision: Decision
    let reason: String
    let timestamp: Date
    
    enum Decision {
        case approved
        case rejected
        case deferred
    }
}

// MARK: - Notification Engine (通知引擎)

/// Core notification engine for managing all notification operations
/// 管理所有通知操作的核心通知引擎
@MainActor
class NotificationEngine: ObservableObject {
    
    // MARK: - Dependencies
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var activeNotifications: [NotificationMessage] = []
    @Published var deliveryQueue: [DeliveryInstruction] = []
    @Published var isProcessing = false
    @Published var stats: NotificationStats = NotificationStats()
    
    // MARK: - Configuration
    private let maxActiveNotifications = 100
    private let processingInterval: TimeInterval = 5.0 // 5 seconds
    private var processingTimer: Timer?
    
    init(
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.auditService = auditService
        self.authService = authService
        startProcessing()
    }
    
    // MARK: - Core Notification Operations
    
    /// Send notification using template
    /// 使用模板发送通知
    func sendNotification(
        templateId: String,
        parameters: [String: String],
        targetUserIds: [String] = [],
        customChannels: [NotificationChannel]? = nil,
        relatedEntityId: String? = nil,
        relatedEntityType: String? = nil
    ) async throws {
        guard let template = NotificationTemplate.templates[templateId] else {
            throw NotificationError.templateNotFound(templateId)
        }
        
        let message = createMessageFromTemplate(
            template: template,
            parameters: parameters,
            targetUserIds: targetUserIds,
            customChannels: customChannels,
            relatedEntityId: relatedEntityId,
            relatedEntityType: relatedEntityType
        )
        
        try await sendNotification(message)
    }
    
    /// Send custom notification
    /// 发送自定义通知
    func sendNotification(_ message: NotificationMessage) async throws {
        // Validate message
        try validateMessage(message)
        
        // Route message to determine delivery plan
        let routingResult = NotificationRouter.routeNotification(message, currentUser: authService.currentUser)
        
        // Add to active notifications
        activeNotifications.insert(message, at: 0)
        if activeNotifications.count > maxActiveNotifications {
            activeNotifications.removeLast()
        }
        
        // Add to delivery queue
        deliveryQueue.append(contentsOf: routingResult.deliveryInstructions)
        
        // Update statistics
        stats.recordNotificationSent(category: message.category, priority: message.priority)
        
        // Log notification creation
        try? await auditService.logSecurityEvent(
            event: "notification_created",
            userId: authService.currentUser?.id ?? "system",
            details: [
                "message_id": message.id,
                "category": message.category.rawValue,
                "priority": message.priority.rawValue,
                "channels": message.channels.map { $0.rawValue }.joined(separator: ","),
                "target_count": "\(routingResult.deliveryInstructions.count)"
            ]
        )
    }
    
    /// Send immediate notification (bypasses normal routing)
    /// 发送即时通知（绕过正常路由）
    func sendImmediateNotification(
        title: String,
        body: String,
        category: NotificationCategory = .system,
        priority: NotificationPriority = .urgent,
        targetUserId: String? = nil
    ) async throws {
        let targetUsers = targetUserId != nil ? [targetUserId!] : []
        
        let message = NotificationMessage(
            category: category,
            priority: priority,
            title: title,
            body: body,
            targetUserIds: targetUsers,
            channels: [.inApp, .push]
        )
        
        try await sendNotification(message)
        
        // Process immediately for urgent notifications
        if priority == .urgent || priority == .critical {
            await processDeliveryQueue()
        }
    }
    
    // MARK: - Template Processing
    
    /// Create notification message from template
    /// 从模板创建通知消息
    private func createMessageFromTemplate(
        template: NotificationTemplate,
        parameters: [String: String],
        targetUserIds: [String],
        customChannels: [NotificationChannel]?,
        relatedEntityId: String?,
        relatedEntityType: String?
    ) -> NotificationMessage {
        let title = processTemplate(template.titleTemplate, parameters: parameters)
        let body = processTemplate(template.bodyTemplate, parameters: parameters)
        let channels = customChannels ?? template.defaultChannels
        
        return NotificationMessage(
            category: template.category,
            priority: template.priority,
            title: title,
            body: body,
            data: parameters,
            targetUserIds: targetUserIds,
            targetRoles: template.targetRoles,
            channels: channels,
            actionButtons: template.defaultActions,
            relatedEntityId: relatedEntityId,
            relatedEntityType: relatedEntityType
        )
    }
    
    /// Process template string with parameters
    /// 使用参数处理模板字符串
    private func processTemplate(_ template: String, parameters: [String: String]) -> String {
        var result = template
        for (key, value) in parameters {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
    
    // MARK: - Message Processing and Delivery
    
    /// Start automatic processing of delivery queue
    /// 开始自动处理传递队列
    private func startProcessing() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: processingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processDeliveryQueue()
            }
        }
    }
    
    /// Process pending notifications in delivery queue
    /// 处理传递队列中的待处理通知
    func processDeliveryQueue() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        let now = Date()
        let readyForDelivery = deliveryQueue.filter { $0.scheduledAt <= now }
        
        for instruction in readyForDelivery {
            await deliverNotification(instruction)
            
            // Remove from queue after processing
            deliveryQueue.removeAll { $0.messageId == instruction.messageId && $0.userId == instruction.userId && $0.channel == instruction.channel }
        }
        
        isProcessing = false
    }
    
    /// Deliver individual notification
    /// 传递单个通知
    private func deliverNotification(_ instruction: DeliveryInstruction) async {
        do {
            switch instruction.channel {
            case .inApp:
                try await deliverInAppNotification(instruction)
            case .push:
                try await deliverPushNotification(instruction)
            case .dashboard:
                try await deliverDashboardNotification(instruction)
            case .email:
                try await deliverEmailNotification(instruction)
            case .sms:
                try await deliverSMSNotification(instruction)
            }
            
            // Record successful delivery
            stats.recordDeliverySuccess(channel: instruction.channel)
            
        } catch {
            // Handle delivery failure
            await handleDeliveryFailure(instruction, error: error)
        }
    }
    
    // MARK: - Channel-Specific Delivery Methods
    
    private func deliverInAppNotification(_ instruction: DeliveryInstruction) async throws {
        // In-app notifications are already handled by adding to activeNotifications
        // This could trigger additional UI updates if needed
    }
    
    private func deliverPushNotification(_ instruction: DeliveryInstruction) async throws {
        // Implementation would integrate with UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        
        if let message = activeNotifications.first(where: { $0.id == instruction.messageId }) {
            content.title = message.title
            content.body = message.body
            content.categoryIdentifier = message.category.rawValue
            content.userInfo = message.data
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "\(message.id)-\(instruction.userId)",
                content: content,
                trigger: nil // Immediate delivery
            )
            
            // Schedule notification
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                throw NotificationError.deliveryFailed(instruction.channel, error.localizedDescription)
            }
        }
    }
    
    private func deliverDashboardNotification(_ instruction: DeliveryInstruction) async throws {
        // Dashboard notifications would typically update a shared notification store
        // For now, this is handled by the activeNotifications array
    }
    
    private func deliverEmailNotification(_ instruction: DeliveryInstruction) async throws {
        // Email delivery would integrate with email service (SendGrid, SES, etc.)
        // This is a placeholder implementation
        try await Task.sleep(nanoseconds: 100_000_000) // Simulate delivery time
    }
    
    private func deliverSMSNotification(_ instruction: DeliveryInstruction) async throws {
        // SMS delivery would integrate with SMS service (Twilio, etc.)
        // This is a placeholder implementation
        try await Task.sleep(nanoseconds: 100_000_000) // Simulate delivery time
    }
    
    // MARK: - Error Handling and Retry Logic
    
    /// Handle delivery failure with retry logic
    /// 使用重试逻辑处理传递失败
    private func handleDeliveryFailure(_ instruction: DeliveryInstruction, error: Error) async {
        stats.recordDeliveryFailure(channel: instruction.channel)
        
        if instruction.retryCount < instruction.maxRetries {
            // Schedule retry with exponential backoff
            let retryDelay = pow(2.0, Double(instruction.retryCount)) * 60 // Start with 1 minute, double each time
            let retryInstruction = DeliveryInstruction(
                messageId: instruction.messageId,
                userId: instruction.userId,
                channel: instruction.channel,
                priority: instruction.priority,
                scheduledAt: Date().addingTimeInterval(retryDelay),
                retryCount: instruction.retryCount + 1,
                maxRetries: instruction.maxRetries
            )
            
            deliveryQueue.append(retryInstruction)
            
            // Log retry
            try? await auditService.logSecurityEvent(
                event: "notification_retry_scheduled",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "message_id": instruction.messageId,
                    "channel": instruction.channel.rawValue,
                    "retry_count": "\(retryInstruction.retryCount)",
                    "retry_delay": "\(retryDelay)",
                    "error": error.localizedDescription
                ]
            )
        } else {
            // Max retries reached, log failure
            try? await auditService.logSecurityEvent(
                event: "notification_delivery_failed",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "message_id": instruction.messageId,
                    "channel": instruction.channel.rawValue,
                    "final_error": error.localizedDescription,
                    "total_retries": "\(instruction.retryCount)"
                ]
            )
        }
    }
    
    // MARK: - Validation and Utility Methods
    
    /// Validate notification message
    /// 验证通知消息
    private func validateMessage(_ message: NotificationMessage) throws {
        if message.title.isEmpty {
            throw NotificationError.invalidMessage("Title cannot be empty")
        }
        
        if message.body.isEmpty {
            throw NotificationError.invalidMessage("Body cannot be empty")
        }
        
        if message.channels.isEmpty {
            throw NotificationError.invalidMessage("At least one delivery channel must be specified")
        }
        
        if message.targetUserIds.isEmpty && message.targetRoles.isEmpty {
            throw NotificationError.invalidMessage("At least one target user or role must be specified")
        }
    }
    
    /// Mark notification as read
    /// 标记通知为已读
    func markAsRead(_ notificationId: String, userId: String) async {
        if let index = activeNotifications.firstIndex(where: { $0.id == notificationId }) {
            // In a real implementation, this would update the read status per user
            // For now, we'll simulate by logging the action
            try? await auditService.logSecurityEvent(
                event: "notification_marked_read",
                userId: userId,
                details: ["notification_id": notificationId]
            )
        }
    }
    
    /// Get notifications for specific user
    /// 获取特定用户的通知
    func getNotificationsForUser(_ userId: String, limit: Int = 50) -> [NotificationMessage] {
        return activeNotifications
            .filter { notification in
                notification.targetUserIds.contains(userId) ||
                (authService.currentUser?.primaryRole != nil && notification.targetRoles.contains(authService.currentUser!.primaryRole))
            }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Clean up expired notifications
    /// 清理过期通知
    func cleanupExpiredNotifications() {
        let now = Date()
        activeNotifications.removeAll { notification in
            if let expiresAt = notification.expiresAt {
                return now > expiresAt
            }
            // Remove notifications older than 30 days if no expiry is set
            return now.timeIntervalSince(notification.timestamp) > 30 * 24 * 3600
        }
    }
    
    deinit {
        processingTimer?.invalidate()
    }
}

// MARK: - Statistics and Monitoring (统计和监控)

/// Notification statistics for monitoring and analytics
/// 用于监控和分析的通知统计
struct NotificationStats {
    private var sentByCategory: [NotificationCategory: Int] = [:]
    private var sentByPriority: [NotificationPriority: Int] = [:]
    private var deliverySuccesses: [NotificationChannel: Int] = [:]
    private var deliveryFailures: [NotificationChannel: Int] = [:]
    private var lastResetTime = Date()
    
    mutating func recordNotificationSent(category: NotificationCategory, priority: NotificationPriority) {
        sentByCategory[category, default: 0] += 1
        sentByPriority[priority, default: 0] += 1
    }
    
    mutating func recordDeliverySuccess(channel: NotificationChannel) {
        deliverySuccesses[channel, default: 0] += 1
    }
    
    mutating func recordDeliveryFailure(channel: NotificationChannel) {
        deliveryFailures[channel, default: 0] += 1
    }
    
    func getTotalSent() -> Int {
        return sentByCategory.values.reduce(0, +)
    }
    
    func getSuccessRate(for channel: NotificationChannel) -> Double {
        let successes = deliverySuccesses[channel, default: 0]
        let failures = deliveryFailures[channel, default: 0]
        let total = successes + failures
        return total > 0 ? Double(successes) / Double(total) : 0.0
    }
    
    func getCategoryBreakdown() -> [(category: NotificationCategory, count: Int)] {
        return sentByCategory.map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Error Types (错误类型)

enum NotificationError: LocalizedError {
    case templateNotFound(String)
    case invalidMessage(String)
    case deliveryFailed(NotificationChannel, String)
    case rateLimitExceeded
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .templateNotFound(let templateId):
            return "Notification template '\(templateId)' not found"
        case .invalidMessage(let reason):
            return "Invalid notification message: \(reason)"
        case .deliveryFailed(let channel, let reason):
            return "Failed to deliver notification via \(channel.displayName): \(reason)"
        case .rateLimitExceeded:
            return "Notification rate limit exceeded"
        case .insufficientPermissions:
            return "Insufficient permissions to send notification"
        }
    }
}