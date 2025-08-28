//
//  SystemConfigurationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Configuration Categories (配置分类)

/// System configuration categories for organized management
/// 用于组织管理的系统配置分类
enum ConfigurationCategory: String, CaseIterable, Codable {
    case system = "system"
    case security = "security"
    case notification = "notification"
    case production = "production"
    case ui = "ui"
    case backup = "backup"
    case integration = "integration"
    case performance = "performance"
    
    var displayName: String {
        switch self {
        case .system: return "系统设置"
        case .security: return "安全设置"
        case .notification: return "通知设置"
        case .production: return "生产设置"
        case .ui: return "界面设置"
        case .backup: return "备份设置"
        case .integration: return "集成设置"
        case .performance: return "性能设置"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .security: return "lock.shield"
        case .notification: return "bell"
        case .production: return "factory"
        case .ui: return "paintbrush"
        case .backup: return "externaldrive"
        case .integration: return "link"
        case .performance: return "speedometer"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "基本系统配置和全局设置"
        case .security: return "安全策略、认证和访问控制设置"
        case .notification: return "通知和警报配置"
        case .production: return "生产流程和设备管理设置"
        case .ui: return "用户界面和主题设置"
        case .backup: return "数据备份和恢复设置"
        case .integration: return "第三方集成和API设置"
        case .performance: return "系统性能和优化设置"
        }
    }
}

// MARK: - Configuration Value Types (配置值类型)

/// Supported configuration value types
/// 支持的配置值类型
enum ConfigurationValueType: String, CaseIterable, Codable {
    case string = "string"
    case integer = "integer"
    case double = "double"
    case boolean = "boolean"
    case array = "array"
    case object = "object"
    case password = "password"
    case url = "url"
    case email = "email"
    case duration = "duration"
    case percentage = "percentage"
    
    var displayName: String {
        switch self {
        case .string: return "文本"
        case .integer: return "整数"
        case .double: return "小数"
        case .boolean: return "布尔值"
        case .array: return "数组"
        case .object: return "对象"
        case .password: return "密码"
        case .url: return "URL"
        case .email: return "邮箱"
        case .duration: return "时长"
        case .percentage: return "百分比"
        }
    }
}

// MARK: - Configuration Definition (配置定义)

/// Definition of a configuration setting
/// 配置设置的定义
struct ConfigurationDefinition: Identifiable, Codable {
    let id: String
    let key: String
    let category: ConfigurationCategory
    let displayName: String
    let description: String
    let valueType: ConfigurationValueType
    let defaultValue: ConfigurationValue
    let validationRules: [ValidationRule]
    let isRequired: Bool
    let isReadOnly: Bool
    let isSensitive: Bool
    let requiresRestart: Bool
    let minimumPermissionLevel: UserRole
    let tags: [String]
    
    struct ValidationRule: Codable {
        let type: ValidationType
        let parameters: [String: AnyValue]
        let errorMessage: String
        
        enum ValidationType: String, Codable {
            case range = "range"
            case length = "length"
            case regex = "regex"
            case custom = "custom"
            case required = "required"
        }
    }
    
    init(
        key: String,
        category: ConfigurationCategory,
        displayName: String,
        description: String,
        valueType: ConfigurationValueType,
        defaultValue: ConfigurationValue,
        validationRules: [ValidationRule] = [],
        isRequired: Bool = false,
        isReadOnly: Bool = false,
        isSensitive: Bool = false,
        requiresRestart: Bool = false,
        minimumPermissionLevel: UserRole = .administrator,
        tags: [String] = []
    ) {
        self.id = UUID().uuidString
        self.key = key
        self.category = category
        self.displayName = displayName
        self.description = description
        self.valueType = valueType
        self.defaultValue = defaultValue
        self.validationRules = validationRules
        self.isRequired = isRequired
        self.isReadOnly = isReadOnly
        self.isSensitive = isSensitive
        self.requiresRestart = requiresRestart
        self.minimumPermissionLevel = minimumPermissionLevel
        self.tags = tags
    }
}

// MARK: - Configuration Value (配置值)

/// A configuration value that can hold different types
/// 可以容纳不同类型的配置值
enum ConfigurationValue: Codable, Equatable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([ConfigurationValue])
    case object([String: ConfigurationValue])
    case null
    
    var displayValue: String {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return "\(value)"
        case .double(let value):
            return String(format: "%.2f", value)
        case .boolean(let value):
            return value ? "是" : "否"
        case .array(let values):
            return "[\(values.count) 项]"
        case .object(let dict):
            return "{\(dict.count) 属性}"
        case .null:
            return "null"
        }
    }
    
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var intValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
    
    var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }
    
    var arrayValue: [ConfigurationValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
    
    var objectValue: [String: ConfigurationValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}

// MARK: - Configuration Setting (配置设置)

/// A configuration setting instance with its current value
/// 具有当前值的配置设置实例
struct ConfigurationSetting: Identifiable, Codable {
    let id: String
    let definitionId: String
    let key: String
    var value: ConfigurationValue
    let lastModified: Date
    let modifiedBy: String
    let version: Int
    let environment: String
    
    init(
        definitionId: String,
        key: String,
        value: ConfigurationValue,
        modifiedBy: String,
        environment: String = "production"
    ) {
        self.id = UUID().uuidString
        self.definitionId = definitionId
        self.key = key
        self.value = value
        self.lastModified = Date()
        self.modifiedBy = modifiedBy
        self.version = 1
        self.environment = environment
    }
}

// MARK: - Configuration Change Request (配置变更请求)

/// Request for configuration changes with approval workflow
/// 带有审批工作流的配置变更请求
struct ConfigurationChangeRequest: Identifiable, Codable {
    let id: String
    let configurationKey: String
    let currentValue: ConfigurationValue
    let proposedValue: ConfigurationValue
    let reason: String
    let requestedBy: String
    let requestedAt: Date
    var status: ChangeRequestStatus
    var reviewedBy: String?
    var reviewedAt: Date?
    var reviewNotes: String?
    let priority: ChangeRequestPriority
    let estimatedImpact: String
    
    enum ChangeRequestStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
        case implemented = "implemented"
        case cancelled = "cancelled"
        
        var displayName: String {
            switch self {
            case .pending: return "待审核"
            case .approved: return "已批准"
            case .rejected: return "已拒绝"
            case .implemented: return "已实施"
            case .cancelled: return "已取消"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .green
            case .rejected: return .red
            case .implemented: return .blue
            case .cancelled: return .gray
            }
        }
    }
    
    enum ChangeRequestPriority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            case .critical: return "紧急"
            }
        }
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
    
    init(
        configurationKey: String,
        currentValue: ConfigurationValue,
        proposedValue: ConfigurationValue,
        reason: String,
        requestedBy: String,
        priority: ChangeRequestPriority = .medium,
        estimatedImpact: String = ""
    ) {
        self.id = UUID().uuidString
        self.configurationKey = configurationKey
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.reason = reason
        self.requestedBy = requestedBy
        self.requestedAt = Date()
        self.status = .pending
        self.priority = priority
        self.estimatedImpact = estimatedImpact
    }
}

// MARK: - Configuration Environment (配置环境)

/// Different environments for configuration management
/// 配置管理的不同环境
enum ConfigurationEnvironment: String, CaseIterable, Codable {
    case development = "development"
    case testing = "testing"
    case staging = "staging"
    case production = "production"
    
    var displayName: String {
        switch self {
        case .development: return "开发环境"
        case .testing: return "测试环境"
        case .staging: return "预发布环境"
        case .production: return "生产环境"
        }
    }
    
    var color: Color {
        switch self {
        case .development: return .blue
        case .testing: return .orange
        case .staging: return .yellow
        case .production: return .red
        }
    }
}

// MARK: - System Configuration Service (系统配置服务)

/// Comprehensive system configuration management service
/// 综合系统配置管理服务
@MainActor
public class SystemConfigurationService: ObservableObject {
    
    // MARK: - Dependencies
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private let permissionService: AdvancedPermissionService
    private let notificationEngine: NotificationEngine?
    
    // MARK: - State
    @Published var configurationDefinitions: [ConfigurationDefinition] = []
    @Published var currentSettings: [String: ConfigurationSetting] = [:]
    @Published var pendingChangeRequests: [ConfigurationChangeRequest] = []
    @Published var configurationHistory: [ConfigurationChangeRecord] = []
    @Published var currentEnvironment: ConfigurationEnvironment = .production
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // MARK: - Configuration Storage
    private let configurationsDirectory: URL
    private let settingsFileName = "system_settings.json"
    private let definitionsFileName = "configuration_definitions.json"
    
    init(
        auditService: NewAuditingService,
        authService: AuthenticationService,
        permissionService: AdvancedPermissionService,
        notificationEngine: NotificationEngine? = nil
    ) {
        self.auditService = auditService
        self.authService = authService
        self.permissionService = permissionService
        self.notificationEngine = notificationEngine
        
        // Setup storage directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.configurationsDirectory = documentsURL.appendingPathComponent("SystemConfigurations")
        
        setupDirectories()
        loadConfigurationDefinitions()
        loadCurrentSettings()
    }
    
    // MARK: - Configuration Management (配置管理)
    
    /// Get configuration value by key
    /// 通过键获取配置值
    func getConfigurationValue<T>(_ key: String, type: T.Type, defaultValue: T) -> T {
        guard let setting = currentSettings[key] else {
            return defaultValue
        }
        
        switch type {
        case is String.Type:
            return setting.value.stringValue as? T ?? defaultValue
        case is Int.Type:
            return setting.value.intValue as? T ?? defaultValue
        case is Double.Type:
            return setting.value.doubleValue as? T ?? defaultValue
        case is Bool.Type:
            return setting.value.boolValue as? T ?? defaultValue
        default:
            return defaultValue
        }
    }
    
    /// Set configuration value with validation
    /// 通过验证设置配置值
    func setConfigurationValue(_ key: String, value: ConfigurationValue, reason: String = "") async throws {
        // Check permissions
        guard await permissionService.hasPermission(.manageSystemSettings).isGranted else {
            throw ConfigurationError.insufficientPermissions
        }
        
        // Find definition
        guard let definition = configurationDefinitions.first(where: { $0.key == key }) else {
            throw ConfigurationError.configurationNotFound(key)
        }
        
        // Check if read-only
        guard !definition.isReadOnly else {
            throw ConfigurationError.readOnlyConfiguration
        }
        
        // Validate value
        try validateConfigurationValue(value, against: definition)
        
        // Create change request if configuration is critical
        if definition.requiresRestart || definition.category == .security {
            try await createChangeRequest(
                configurationKey: key,
                proposedValue: value,
                reason: reason.isEmpty ? "配置更新" : reason
            )
        } else {
            // Apply change directly
            try await applyConfigurationChange(key: key, value: value, reason: reason)
        }
    }
    
    /// Create configuration change request
    /// 创建配置变更请求
    func createChangeRequest(
        configurationKey: String,
        proposedValue: ConfigurationValue,
        reason: String,
        priority: ConfigurationChangeRequest.ChangeRequestPriority = .medium,
        estimatedImpact: String = ""
    ) async throws {
        guard await permissionService.hasPermission(.manageSystemSettings).isGranted else {
            throw ConfigurationError.insufficientPermissions
        }
        
        let currentValue = currentSettings[configurationKey]?.value ?? .null
        
        let changeRequest = ConfigurationChangeRequest(
            configurationKey: configurationKey,
            currentValue: currentValue,
            proposedValue: proposedValue,
            reason: reason,
            requestedBy: authService.currentUser?.id ?? "unknown",
            priority: priority,
            estimatedImpact: estimatedImpact
        )
        
        pendingChangeRequests.append(changeRequest)
        
        // Save to persistent storage
        try saveChangeRequests()
        
        // Send notification to administrators
        await notifyAdministrators(about: changeRequest)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_change_requested",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "configuration_key": configurationKey,
                "reason": reason,
                "priority": priority.rawValue,
                "request_id": changeRequest.id
            ]
        )
    }
    
    /// Approve configuration change request
    /// 批准配置变更请求
    func approveChangeRequest(_ requestId: String, reviewNotes: String = "") async throws {
        guard await permissionService.hasPermission(.approveConfigurationChanges).isGranted else {
            throw ConfigurationError.insufficientPermissions
        }
        
        guard let index = pendingChangeRequests.firstIndex(where: { $0.id == requestId }) else {
            throw ConfigurationError.changeRequestNotFound
        }
        
        var request = pendingChangeRequests[index]
        guard request.status == .pending else {
            throw ConfigurationError.invalidRequestStatus
        }
        
        // Update request status
        request.status = .approved
        request.reviewedBy = authService.currentUser?.id
        request.reviewedAt = Date()
        request.reviewNotes = reviewNotes
        
        pendingChangeRequests[index] = request
        
        // Apply the configuration change
        try await applyConfigurationChange(
            key: request.configurationKey,
            value: request.proposedValue,
            reason: "批准的变更请求: \(request.reason)"
        )
        
        // Mark as implemented
        pendingChangeRequests[index].status = .implemented
        
        try saveChangeRequests()
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_change_approved",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "request_id": requestId,
                "configuration_key": request.configurationKey,
                "review_notes": reviewNotes
            ]
        )
    }
    
    /// Reject configuration change request
    /// 拒绝配置变更请求
    func rejectChangeRequest(_ requestId: String, reviewNotes: String) async throws {
        guard await permissionService.hasPermission(.approveConfigurationChanges).isGranted else {
            throw ConfigurationError.insufficientPermissions
        }
        
        guard let index = pendingChangeRequests.firstIndex(where: { $0.id == requestId }) else {
            throw ConfigurationError.changeRequestNotFound
        }
        
        var request = pendingChangeRequests[index]
        guard request.status == .pending else {
            throw ConfigurationError.invalidRequestStatus
        }
        
        // Update request status
        request.status = .rejected
        request.reviewedBy = authService.currentUser?.id
        request.reviewedAt = Date()
        request.reviewNotes = reviewNotes
        
        pendingChangeRequests[index] = request
        
        try saveChangeRequests()
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_change_rejected",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "request_id": requestId,
                "configuration_key": request.configurationKey,
                "review_notes": reviewNotes
            ]
        )
    }
    
    /// Get configurations by category
    /// 按类别获取配置
    func getConfigurationsByCategory(_ category: ConfigurationCategory) -> [ConfigurationDefinition] {
        return configurationDefinitions.filter { $0.category == category }
    }
    
    /// Search configurations
    /// 搜索配置
    func searchConfigurations(_ query: String) -> [ConfigurationDefinition] {
        guard !query.isEmpty else { return configurationDefinitions }
        
        let lowercaseQuery = query.lowercased()
        return configurationDefinitions.filter { definition in
            definition.displayName.lowercased().contains(lowercaseQuery) ||
            definition.description.lowercased().contains(lowercaseQuery) ||
            definition.key.lowercased().contains(lowercaseQuery) ||
            definition.tags.joined(separator: " ").lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Reset configuration to default value
    /// 将配置重置为默认值
    func resetConfigurationToDefault(_ key: String, reason: String = "重置为默认值") async throws {
        guard await permissionService.hasPermission(.manageSystemSettings).isGranted else {
            throw ConfigurationError.insufficientPermissions
        }
        
        guard let definition = configurationDefinitions.first(where: { $0.key == key }) else {
            throw ConfigurationError.configurationNotFound(key)
        }
        
        try await setConfigurationValue(key, value: definition.defaultValue, reason: reason)
    }
    
    /// Bulk update configurations
    /// 批量更新配置
    func bulkUpdateConfigurations(_ updates: [String: ConfigurationValue], reason: String) async throws {
        guard await permissionService.hasPermission(.manageSystemSettings).isGranted else {
            throw ConfigurationError.insufficientPermissions
        }
        
        // Validate all updates first
        for (key, value) in updates {
            guard let definition = configurationDefinitions.first(where: { $0.key == key }) else {
                throw ConfigurationError.configurationNotFound(key)
            }
            
            try validateConfigurationValue(value, against: definition)
        }
        
        // Apply all updates
        for (key, value) in updates {
            try await applyConfigurationChange(key: key, value: value, reason: reason)
        }
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "bulk_configuration_update",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "updated_keys": updates.keys.joined(separator: ","),
                "reason": reason,
                "count": "\(updates.count)"
            ]
        )
    }
    
    // MARK: - Private Methods (私有方法)
    
    private func setupDirectories() {
        try? FileManager.default.createDirectory(
            at: configurationsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private func loadConfigurationDefinitions() {
        // First load from file if exists
        let definitionsURL = configurationsDirectory.appendingPathComponent(definitionsFileName)
        
        if FileManager.default.fileExists(atPath: definitionsURL.path) {
            do {
                let data = try Data(contentsOf: definitionsURL)
                configurationDefinitions = try JSONDecoder().decode([ConfigurationDefinition].self, from: data)
            } catch {
                print("Failed to load configuration definitions: \(error)")
                createDefaultConfigurationDefinitions()
            }
        } else {
            createDefaultConfigurationDefinitions()
        }
    }
    
    private func createDefaultConfigurationDefinitions() {
        configurationDefinitions = [
            // System Settings
            ConfigurationDefinition(
                key: "system.app_name",
                category: .system,
                displayName: "应用名称",
                description: "系统显示的应用程序名称",
                valueType: .string,
                defaultValue: .string("Lopan生产管理系统"),
                tags: ["display", "branding"]
            ),
            
            ConfigurationDefinition(
                key: "system.session_timeout",
                category: .system,
                displayName: "会话超时时间",
                description: "用户会话的超时时间（分钟）",
                valueType: .integer,
                defaultValue: .integer(30),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(5), "max": AnyValue.integer(480)],
                        errorMessage: "会话超时时间必须在5-480分钟之间"
                    )
                ],
                tags: ["security", "session"]
            ),
            
            ConfigurationDefinition(
                key: "system.max_concurrent_users",
                category: .system,
                displayName: "最大并发用户数",
                description: "系统允许的最大并发用户数量",
                valueType: .integer,
                defaultValue: .integer(100),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(1), "max": AnyValue.integer(1000)],
                        errorMessage: "并发用户数必须在1-1000之间"
                    )
                ],
                requiresRestart: true,
                tags: ["performance", "limits"]
            ),
            
            // Security Settings
            ConfigurationDefinition(
                key: "security.password_policy.min_length",
                category: .security,
                displayName: "密码最小长度",
                description: "用户密码的最小长度要求",
                valueType: .integer,
                defaultValue: .integer(8),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(6), "max": AnyValue.integer(32)],
                        errorMessage: "密码长度必须在6-32个字符之间"
                    )
                ],
                tags: ["security", "password"]
            ),
            
            ConfigurationDefinition(
                key: "security.password_policy.require_special_chars",
                category: .security,
                displayName: "密码需要特殊字符",
                description: "密码是否必须包含特殊字符",
                valueType: .boolean,
                defaultValue: .boolean(true),
                tags: ["security", "password"]
            ),
            
            ConfigurationDefinition(
                key: "security.failed_login_threshold",
                category: .security,
                displayName: "登录失败阈值",
                description: "账户锁定前允许的登录失败次数",
                valueType: .integer,
                defaultValue: .integer(5),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(3), "max": AnyValue.integer(10)],
                        errorMessage: "登录失败阈值必须在3-10次之间"
                    )
                ],
                tags: ["security", "authentication"]
            ),
            
            // Notification Settings
            ConfigurationDefinition(
                key: "notification.email_enabled",
                category: .notification,
                displayName: "启用邮件通知",
                description: "是否启用邮件通知功能",
                valueType: .boolean,
                defaultValue: .boolean(true),
                tags: ["notification", "email"]
            ),
            
            ConfigurationDefinition(
                key: "notification.smtp_server",
                category: .notification,
                displayName: "SMTP服务器",
                description: "邮件发送的SMTP服务器地址",
                valueType: .string,
                defaultValue: .string("smtp.gmail.com"),
                isSensitive: true,
                tags: ["notification", "email", "smtp"]
            ),
            
            // Production Settings
            ConfigurationDefinition(
                key: "production.auto_batch_execution",
                category: .production,
                displayName: "自动批次执行",
                description: "是否自动执行已提交的生产批次",
                valueType: .boolean,
                defaultValue: .boolean(false),
                tags: ["production", "automation"]
            ),
            
            ConfigurationDefinition(
                key: "production.batch_execution_delay",
                category: .production,
                displayName: "批次执行延迟",
                description: "批次自动执行的延迟时间（秒）",
                valueType: .integer,
                defaultValue: .integer(300),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(60), "max": AnyValue.integer(3600)],
                        errorMessage: "执行延迟必须在60-3600秒之间"
                    )
                ],
                tags: ["production", "timing"]
            ),
            
            // UI Settings
            ConfigurationDefinition(
                key: "ui.theme",
                category: .ui,
                displayName: "界面主题",
                description: "应用程序的界面主题",
                valueType: .string,
                defaultValue: .string("auto"),
                tags: ["ui", "theme"]
            ),
            
            ConfigurationDefinition(
                key: "ui.items_per_page",
                category: .ui,
                displayName: "每页显示项目数",
                description: "列表页面每页显示的项目数量",
                valueType: .integer,
                defaultValue: .integer(20),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(10), "max": AnyValue.integer(100)],
                        errorMessage: "每页项目数必须在10-100之间"
                    )
                ],
                tags: ["ui", "pagination"]
            ),
            
            // Backup Settings
            ConfigurationDefinition(
                key: "backup.auto_backup_enabled",
                category: .backup,
                displayName: "启用自动备份",
                description: "是否启用自动数据备份功能",
                valueType: .boolean,
                defaultValue: .boolean(true),
                tags: ["backup", "automation"]
            ),
            
            ConfigurationDefinition(
                key: "backup.backup_retention_days",
                category: .backup,
                displayName: "备份保留天数",
                description: "自动备份文件的保留天数",
                valueType: .integer,
                defaultValue: .integer(30),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(7), "max": AnyValue.integer(365)],
                        errorMessage: "备份保留天数必须在7-365天之间"
                    )
                ],
                tags: ["backup", "retention"]
            ),
            
            // Performance Settings
            ConfigurationDefinition(
                key: "performance.cache_ttl",
                category: .performance,
                displayName: "缓存生存时间",
                description: "系统缓存的生存时间（秒）",
                valueType: .integer,
                defaultValue: .integer(300),
                validationRules: [
                    ConfigurationDefinition.ValidationRule(
                        type: .range,
                        parameters: ["min": AnyValue.integer(60), "max": AnyValue.integer(3600)],
                        errorMessage: "缓存TTL必须在60-3600秒之间"
                    )
                ],
                requiresRestart: true,
                tags: ["performance", "cache"]
            )
        ]
        
        // Save default definitions
        saveConfigurationDefinitions()
    }
    
    private func loadCurrentSettings() {
        let settingsURL = configurationsDirectory.appendingPathComponent(settingsFileName)
        
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do {
                let data = try Data(contentsOf: settingsURL)
                let settings = try JSONDecoder().decode([ConfigurationSetting].self, from: data)
                currentSettings = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0) })
            } catch {
                print("Failed to load current settings: \(error)")
                createDefaultSettings()
            }
        } else {
            createDefaultSettings()
        }
    }
    
    private func createDefaultSettings() {
        for definition in configurationDefinitions {
            let setting = ConfigurationSetting(
                definitionId: definition.id,
                key: definition.key,
                value: definition.defaultValue,
                modifiedBy: "system"
            )
            currentSettings[definition.key] = setting
        }
        saveCurrentSettings()
    }
    
    private func saveConfigurationDefinitions() {
        let definitionsURL = configurationsDirectory.appendingPathComponent(definitionsFileName)
        do {
            let data = try JSONEncoder().encode(configurationDefinitions)
            try data.write(to: definitionsURL)
        } catch {
            print("Failed to save configuration definitions: \(error)")
        }
    }
    
    private func saveCurrentSettings() {
        let settingsURL = configurationsDirectory.appendingPathComponent(settingsFileName)
        do {
            let settings = Array(currentSettings.values)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL)
        } catch {
            print("Failed to save current settings: \(error)")
        }
    }
    
    private func saveChangeRequests() throws {
        let requestsURL = configurationsDirectory.appendingPathComponent("change_requests.json")
        let data = try JSONEncoder().encode(pendingChangeRequests)
        try data.write(to: requestsURL)
    }
    
    private func validateConfigurationValue(_ value: ConfigurationValue, against definition: ConfigurationDefinition) throws {
        // Type validation
        switch (definition.valueType, value) {
        case (.string, .string), (.integer, .integer), (.double, .double), (.boolean, .boolean):
            break // Valid
        default:
            throw ConfigurationError.invalidValueType
        }
        
        // Apply validation rules
        for rule in definition.validationRules {
            switch rule.type {
            case .range:
                try validateRange(value, rule: rule)
            case .length:
                try validateLength(value, rule: rule)
            case .regex:
                try validateRegex(value, rule: rule)
            case .required:
                if case .null = value {
                    throw ConfigurationError.validationFailed(rule.errorMessage)
                }
            case .custom:
                // Custom validation would be implemented here
                break
            }
        }
    }
    
    private func validateRange(_ value: ConfigurationValue, rule: ConfigurationDefinition.ValidationRule) throws {
        guard let minValue = rule.parameters["min"],
              let maxValue = rule.parameters["max"] else {
            return
        }
        
        switch value {
        case .integer(let intValue):
            if let min = minValue.intValue, let max = maxValue.intValue {
                if intValue < min || intValue > max {
                    throw ConfigurationError.validationFailed(rule.errorMessage)
                }
            }
        case .double(let doubleValue):
            if let min = minValue.doubleValue, let max = maxValue.doubleValue {
                if doubleValue < min || doubleValue > max {
                    throw ConfigurationError.validationFailed(rule.errorMessage)
                }
            }
        default:
            break
        }
    }
    
    private func validateLength(_ value: ConfigurationValue, rule: ConfigurationDefinition.ValidationRule) throws {
        guard case .string(let stringValue) = value,
              let minLength = rule.parameters["min"]?.intValue,
              let maxLength = rule.parameters["max"]?.intValue else {
            return
        }
        
        if stringValue.count < minLength || stringValue.count > maxLength {
            throw ConfigurationError.validationFailed(rule.errorMessage)
        }
    }
    
    private func validateRegex(_ value: ConfigurationValue, rule: ConfigurationDefinition.ValidationRule) throws {
        guard case .string(let stringValue) = value,
              let pattern = rule.parameters["pattern"]?.stringValue else {
            return
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: stringValue.utf16.count)
            if regex.firstMatch(in: stringValue, options: [], range: range) == nil {
                throw ConfigurationError.validationFailed(rule.errorMessage)
            }
        } catch {
            throw ConfigurationError.validationFailed("正则表达式验证失败")
        }
    }
    
    private func applyConfigurationChange(key: String, value: ConfigurationValue, reason: String) async throws {
        guard let definition = configurationDefinitions.first(where: { $0.key == key }) else {
            throw ConfigurationError.configurationNotFound(key)
        }
        
        let oldValue = currentSettings[key]?.value
        
        // Create or update setting
        let setting = ConfigurationSetting(
            definitionId: definition.id,
            key: key,
            value: value,
            modifiedBy: authService.currentUser?.id ?? "unknown"
        )
        
        currentSettings[key] = setting
        saveCurrentSettings()
        
        // Record change in history
        let changeRecord = ConfigurationChangeRecord(
            configurationKey: key,
            oldValue: oldValue ?? .null,
            newValue: value,
            changedBy: authService.currentUser?.id ?? "unknown",
            reason: reason
        )
        
        configurationHistory.insert(changeRecord, at: 0)
        
        // Keep only last 1000 records
        if configurationHistory.count > 1000 {
            configurationHistory = Array(configurationHistory.prefix(1000))
        }
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_changed",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "configuration_key": key,
                "old_value": oldValue?.displayValue ?? "null",
                "new_value": value.displayValue,
                "reason": reason
            ]
        )
        
        // Send notification if significant change
        if definition.requiresRestart || definition.category == .security {
            await notifyAdministrators(about: changeRecord)
        }
    }
    
    private func notifyAdministrators(about changeRequest: ConfigurationChangeRequest) async {
        guard let notificationEngine = notificationEngine else { return }
        
        try? await notificationEngine.sendImmediateNotification(
            title: "配置变更请求",
            body: "用户请求修改配置: \(changeRequest.configurationKey)",
            category: .system,
            priority: changeRequest.priority == .critical ? .high : .medium
        )
    }
    
    private func notifyAdministrators(about changeRecord: ConfigurationChangeRecord) async {
        guard let notificationEngine = notificationEngine else { return }
        
        try? await notificationEngine.sendImmediateNotification(
            title: "重要配置已修改",
            body: "配置 \(changeRecord.configurationKey) 已被修改",
            category: .system,
            priority: .high
        )
    }
}

// MARK: - Configuration Change Record (配置变更记录)

/// Record of a configuration change for history tracking
/// 用于历史跟踪的配置变更记录
struct ConfigurationChangeRecord: Identifiable, Codable {
    let id: String
    let configurationKey: String
    let oldValue: ConfigurationValue
    let newValue: ConfigurationValue
    let changedBy: String
    let changedAt: Date
    let reason: String
    
    init(
        configurationKey: String,
        oldValue: ConfigurationValue,
        newValue: ConfigurationValue,
        changedBy: String,
        reason: String
    ) {
        self.id = UUID().uuidString
        self.configurationKey = configurationKey
        self.oldValue = oldValue
        self.newValue = newValue
        self.changedBy = changedBy
        self.changedAt = Date()
        self.reason = reason
    }
}

// MARK: - Supporting Types (支持类型)

/// Type-erased value for validation parameters
/// 用于验证参数的类型擦除值
enum AnyValue: Codable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var intValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
    
    var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }
}

// MARK: - Error Types (错误类型)

enum ConfigurationError: LocalizedError {
    case insufficientPermissions
    case configurationNotFound(String)
    case readOnlyConfiguration
    case invalidValueType
    case validationFailed(String)
    case changeRequestNotFound
    case invalidRequestStatus
    case environmentMismatch
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足，无法修改系统配置"
        case .configurationNotFound(let key):
            return "找不到配置项: \(key)"
        case .readOnlyConfiguration:
            return "此配置为只读，无法修改"
        case .invalidValueType:
            return "配置值类型不匹配"
        case .validationFailed(let message):
            return "配置验证失败: \(message)"
        case .changeRequestNotFound:
            return "找不到指定的变更请求"
        case .invalidRequestStatus:
            return "变更请求状态无效"
        case .environmentMismatch:
            return "配置环境不匹配"
        }
    }
}

