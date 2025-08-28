//
//  UnifiedErrorHandlingService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Error Categories and Types (错误分类和类型)

/// Comprehensive error categories for the production system
/// 生产系统的综合错误分类
enum ErrorCategory: String, CaseIterable, Codable {
    case authentication = "authentication"
    case authorization = "authorization"
    case validation = "validation"
    case business = "business"
    case system = "system"
    case network = "network"
    case database = "database"
    case configuration = "configuration"
    case integration = "integration"
    case performance = "performance"
    
    var displayName: String {
        switch self {
        case .authentication: return "认证错误"
        case .authorization: return "授权错误"
        case .validation: return "验证错误"
        case .business: return "业务逻辑错误"
        case .system: return "系统错误"
        case .network: return "网络错误"
        case .database: return "数据库错误"
        case .configuration: return "配置错误"
        case .integration: return "集成错误"
        case .performance: return "性能错误"
        }
    }
    
    var icon: String {
        switch self {
        case .authentication: return "person.badge.key"
        case .authorization: return "lock.shield"
        case .validation: return "checkmark.shield"
        case .business: return "briefcase"
        case .system: return "gear.badge.xmark"
        case .network: return "wifi.exclamationmark"
        case .database: return "cylinder.split.1x2"
        case .configuration: return "slider.horizontal.3"
        case .integration: return "link.badge.plus"
        case .performance: return "speedometer"
        }
    }
    
    var color: Color {
        switch self {
        case .authentication, .authorization: return .red
        case .validation, .business: return .orange
        case .system, .database: return .purple
        case .network, .integration: return .blue
        case .configuration: return .yellow
        case .performance: return .green
        }
    }
}

/// Error severity levels
/// 错误严重程度级别
enum ErrorSeverity: String, CaseIterable, Codable, Comparable {
    case trace = "trace"
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    case fatal = "fatal"
    
    var displayName: String {
        switch self {
        case .trace: return "跟踪"
        case .debug: return "调试"
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        case .critical: return "严重"
        case .fatal: return "致命"
        }
    }
    
    var color: Color {
        switch self {
        case .trace, .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        case .fatal: return .black
        }
    }
    
    var priority: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        case .fatal: return 6
        }
    }
    
    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.priority < rhs.priority
    }
}

// MARK: - Error Context (错误上下文)

/// Comprehensive context information for errors
/// 错误的综合上下文信息
struct ErrorContext: Codable {
    let timestamp: Date
    let userId: String?
    let sessionId: String?
    let requestId: String?
    let component: String
    let function: String
    let line: Int?
    let deviceInfo: DeviceInfo
    let appVersion: String
    let buildNumber: String
    let environment: String
    let additionalMetadata: [String: String]
    
    struct DeviceInfo: Codable {
        let platform: String
        let osVersion: String
        let deviceModel: String
        let language: String
        let timezone: String
        
        init() {
            self.platform = "iOS"
            self.osVersion = UIDevice.current.systemVersion
            self.deviceModel = UIDevice.current.model
            self.language = Locale.current.language.languageCode?.identifier ?? "unknown"
            self.timezone = TimeZone.current.identifier
        }
    }
    
    init(
        userId: String? = nil,
        sessionId: String? = nil,
        requestId: String? = nil,
        component: String,
        function: String = #function,
        line: Int? = #line,
        environment: String = "production",
        additionalMetadata: [String: String] = [:]
    ) {
        self.timestamp = Date()
        self.userId = userId
        self.sessionId = sessionId
        self.requestId = requestId
        self.component = component
        self.function = function
        self.line = line
        self.deviceInfo = DeviceInfo()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.environment = environment
        self.additionalMetadata = additionalMetadata
    }
}

// MARK: - Unified Error (统一错误)

/// Unified error structure that captures all necessary information for production systems
/// 统一错误结构，捕获生产系统所需的所有必要信息
struct UnifiedError: LocalizedError, Identifiable, Codable {
    let id: String
    let category: ErrorCategory
    let severity: ErrorSeverity
    let code: String
    let message: String
    let technicalMessage: String?
    let userFriendlyMessage: String
    let context: ErrorContext
    let underlyingError: String?
    let stackTrace: [String]?
    let recoveryActions: [RecoveryAction]
    let tags: [String]
    let correlationId: String?
    
    init(
        category: ErrorCategory,
        severity: ErrorSeverity,
        code: String,
        message: String,
        technicalMessage: String? = nil,
        userFriendlyMessage: String? = nil,
        context: ErrorContext,
        underlyingError: Error? = nil,
        stackTrace: [String]? = nil,
        recoveryActions: [RecoveryAction] = [],
        tags: [String] = [],
        correlationId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.category = category
        self.severity = severity
        self.code = code
        self.message = message
        self.technicalMessage = technicalMessage
        self.userFriendlyMessage = userFriendlyMessage ?? Self.generateUserFriendlyMessage(for: category, severity: severity)
        self.context = context
        self.underlyingError = underlyingError?.localizedDescription
        self.stackTrace = stackTrace
        self.recoveryActions = recoveryActions
        self.tags = tags
        self.correlationId = correlationId
    }
    
    var errorDescription: String? {
        return userFriendlyMessage
    }
    
    private static func generateUserFriendlyMessage(for category: ErrorCategory, severity: ErrorSeverity) -> String {
        switch (category, severity) {
        case (.authentication, _):
            return "请检查您的登录凭据并重试"
        case (.authorization, _):
            return "您没有权限执行此操作"
        case (.validation, _):
            return "输入的数据无效，请检查并重新输入"
        case (.business, _):
            return "操作无法完成，请稍后重试"
        case (.network, _):
            return "网络连接出现问题，请检查网络连接"
        case (.database, _):
            return "数据访问出现问题，请稍后重试"
        case (.system, .critical), (.system, .fatal):
            return "系统出现严重错误，请联系技术支持"
        case (.system, _):
            return "系统繁忙，请稍后重试"
        case (.configuration, _):
            return "系统配置有误，请联系管理员"
        case (.integration, _):
            return "外部服务连接失败，请稍后重试"
        case (.performance, _):
            return "系统响应较慢，请耐心等待"
        }
    }
}

// MARK: - Recovery Action (恢复操作)

/// Actions that can be taken to recover from errors
/// 可以采取的错误恢复操作
struct RecoveryAction: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let actionType: ActionType
    let parameters: [String: String]
    let isAutomatic: Bool
    let estimatedTime: TimeInterval?
    
    enum ActionType: String, CaseIterable, Codable {
        case retry = "retry"
        case refresh = "refresh"
        case logout = "logout"
        case navigate = "navigate"
        case contact = "contact"
        case restart = "restart"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .retry: return "重试"
            case .refresh: return "刷新"
            case .logout: return "重新登录"
            case .navigate: return "转到其他页面"
            case .contact: return "联系支持"
            case .restart: return "重启应用"
            case .custom: return "自定义操作"
            }
        }
    }
    
    init(
        title: String,
        description: String,
        actionType: ActionType,
        parameters: [String: String] = [:],
        isAutomatic: Bool = false,
        estimatedTime: TimeInterval? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.actionType = actionType
        self.parameters = parameters
        self.isAutomatic = isAutomatic
        self.estimatedTime = estimatedTime
    }
}

// MARK: - Error Event (错误事件)

/// A logged error event with additional tracking information
/// 带有额外跟踪信息的记录错误事件
struct ErrorEvent: Identifiable, Codable {
    let id: String
    let error: UnifiedError
    let firstOccurrence: Date
    var lastOccurrence: Date
    var occurrenceCount: Int
    var reportedBy: [String] // User IDs who reported this error
    var status: ErrorStatus
    var assignedTo: String?
    var resolution: ErrorResolution?
    var notes: [ErrorNote]
    
    enum ErrorStatus: String, CaseIterable, Codable {
        case new = "new"
        case acknowledged = "acknowledged"
        case investigating = "investigating"
        case resolved = "resolved"
        case dismissed = "dismissed"
        
        var displayName: String {
            switch self {
            case .new: return "新建"
            case .acknowledged: return "已确认"
            case .investigating: return "调查中"
            case .resolved: return "已解决"
            case .dismissed: return "已忽略"
            }
        }
        
        var color: Color {
            switch self {
            case .new: return .red
            case .acknowledged: return .orange
            case .investigating: return .blue
            case .resolved: return .green
            case .dismissed: return .gray
            }
        }
    }
    
    struct ErrorNote: Identifiable, Codable {
        let id: String
        let note: String
        let addedBy: String
        let addedAt: Date
        
        init(note: String, addedBy: String) {
            self.id = UUID().uuidString
            self.note = note
            self.addedBy = addedBy
            self.addedAt = Date()
        }
    }
    
    struct ErrorResolution: Codable {
        let resolvedBy: String
        let resolvedAt: Date
        let resolutionType: ResolutionType
        let description: String
        let preventionMeasures: [String]
        
        enum ResolutionType: String, CaseIterable, Codable {
            case fixed = "fixed"
            case workaround = "workaround"
            case duplicate = "duplicate"
            case notReproducible = "not_reproducible"
            case byDesign = "by_design"
            
            var displayName: String {
                switch self {
                case .fixed: return "已修复"
                case .workaround: return "临时解决方案"
                case .duplicate: return "重复问题"
                case .notReproducible: return "无法重现"
                case .byDesign: return "设计如此"
                }
            }
        }
    }
    
    init(error: UnifiedError, reportedBy: String) {
        self.id = UUID().uuidString
        self.error = error
        self.firstOccurrence = Date()
        self.lastOccurrence = Date()
        self.occurrenceCount = 1
        self.reportedBy = [reportedBy]
        self.status = .new
        self.notes = []
    }
    
    mutating func recordOccurrence(reportedBy: String) {
        self.lastOccurrence = Date()
        self.occurrenceCount += 1
        
        if !self.reportedBy.contains(reportedBy) {
            self.reportedBy.append(reportedBy)
        }
    }
}

// MARK: - Unified Error Handling Service (统一错误处理服务)

/// Comprehensive error handling and logging service for production systems
/// 生产系统的综合错误处理和日志服务
@MainActor
public class UnifiedErrorHandlingService: ObservableObject {
    
    // MARK: - Dependencies
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private let notificationEngine: NotificationEngine?
    
    // MARK: - State
    @Published var recentErrors: [ErrorEvent] = []
    @Published var errorStats: ErrorStatistics = ErrorStatistics()
    @Published var isLoggingEnabled = true
    @Published var currentLogLevel: ErrorSeverity = .warning
    @Published var activeAlerts: [ErrorAlert] = []
    
    // MARK: - Configuration
    private let maxRecentErrors = 1000
    private let errorThresholds: [ErrorSeverity: Int] = [
        .critical: 1,
        .error: 5,
        .warning: 20
    ]
    
    // MARK: - Logging Infrastructure
    private let systemLogger = Logger(subsystem: "com.lopan.production", category: "ErrorHandling")
    private let errorLogDirectory: URL
    private let errorQueue = DispatchQueue(label: "com.lopan.error-handling", qos: .utility)
    private var logFileHandle: FileHandle?
    
    // MARK: - Error Aggregation
    private var errorAggregator: ErrorAggregator
    private var performanceMonitor: ErrorPerformanceMonitor
    
    init(
        auditService: NewAuditingService,
        authService: AuthenticationService,
        notificationEngine: NotificationEngine? = nil
    ) {
        self.auditService = auditService
        self.authService = authService
        self.notificationEngine = notificationEngine
        
        // Setup logging directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.errorLogDirectory = documentsURL.appendingPathComponent("ErrorLogs")
        
        // Initialize components
        self.errorAggregator = ErrorAggregator()
        self.performanceMonitor = ErrorPerformanceMonitor()
        
        setupLoggingInfrastructure()
        startPerformanceMonitoring()
        loadRecentErrors()
        calculateErrorStatistics()
    }
    
    // MARK: - Core Error Handling (核心错误处理)
    
    /// Log an error with comprehensive context
    /// 记录具有综合上下文的错误
    func logError(
        category: ErrorCategory,
        severity: ErrorSeverity,
        code: String,
        message: String,
        technicalMessage: String? = nil,
        userFriendlyMessage: String? = nil,
        underlyingError: Error? = nil,
        component: String,
        function: String = #function,
        line: Int = #line,
        additionalMetadata: [String: String] = [:],
        tags: [String] = [],
        correlationId: String? = nil
    ) async {
        // Check if logging is enabled and meets severity threshold
        guard isLoggingEnabled && severity >= currentLogLevel else { return }
        
        // Create error context
        let context = ErrorContext(
            userId: authService.currentUser?.id,
            sessionId: "current_session",
            requestId: correlationId,
            component: component,
            function: function,
            line: line,
            additionalMetadata: additionalMetadata
        )
        
        // Generate appropriate recovery actions
        let recoveryActions = generateRecoveryActions(for: category, severity: severity, code: code)
        
        // Create unified error
        let unifiedError = UnifiedError(
            category: category,
            severity: severity,
            code: code,
            message: message,
            technicalMessage: technicalMessage,
            userFriendlyMessage: userFriendlyMessage,
            context: context,
            underlyingError: underlyingError,
            stackTrace: extractStackTrace(),
            recoveryActions: recoveryActions,
            tags: tags,
            correlationId: correlationId
        )
        
        // Process error asynchronously
        errorQueue.async { [weak self] in
            self?.processError(unifiedError)
        }
        
        // Update UI on main thread
        await processErrorOnMainThread(unifiedError)
    }
    
    /// Handle business logic errors
    /// 处理业务逻辑错误
    func handleBusinessError(
        code: String,
        message: String,
        severity: ErrorSeverity = .error,
        component: String,
        userFriendlyMessage: String? = nil,
        recoveryActions: [RecoveryAction] = [],
        function: String = #function,
        line: Int = #line
    ) async {
        await logError(
            category: .business,
            severity: severity,
            code: code,
            message: message,
            userFriendlyMessage: userFriendlyMessage,
            component: component,
            function: function,
            line: line
        )
    }
    
    /// Handle validation errors
    /// 处理验证错误
    func handleValidationError(
        field: String,
        value: Any?,
        rule: String,
        component: String,
        function: String = #function,
        line: Int = #line
    ) async {
        let message = "Validation failed for field '\(field)' with rule '\(rule)'"
        let userMessage = "输入的 \(field) 不符合要求，请检查后重新输入"
        
        await logError(
            category: .validation,
            severity: .warning,
            code: "VALIDATION_FAILED",
            message: message,
            userFriendlyMessage: userMessage,
            component: component,
            function: function,
            line: line,
            additionalMetadata: [
                "field": field,
                "value": String(describing: value),
                "rule": rule
            ],
            tags: ["validation", field]
        )
    }
    
    /// Handle system errors
    /// 处理系统错误
    func handleSystemError(
        error: Error,
        component: String,
        severity: ErrorSeverity = .error,
        function: String = #function,
        line: Int = #line
    ) async {
        await logError(
            category: .system,
            severity: severity,
            code: "SYSTEM_ERROR",
            message: error.localizedDescription,
            technicalMessage: String(describing: error),
            underlyingError: error,
            component: component,
            function: function,
            line: line
        )
    }
    
    /// Handle network errors
    /// 处理网络错误
    func handleNetworkError(
        error: Error,
        url: String?,
        httpStatusCode: Int?,
        component: String,
        function: String = #function,
        line: Int = #line
    ) async {
        var metadata: [String: String] = [:]
        if let url = url { metadata["url"] = url }
        if let statusCode = httpStatusCode { metadata["http_status"] = "\(statusCode)" }
        
        let severity: ErrorSeverity = {
            if let statusCode = httpStatusCode {
                switch statusCode {
                case 400...499: return .warning
                case 500...599: return .error
                default: return .warning
                }
            }
            return .error
        }()
        
        await logError(
            category: .network,
            severity: severity,
            code: "NETWORK_ERROR",
            message: error.localizedDescription,
            underlyingError: error,
            component: component,
            function: function,
            line: line,
            additionalMetadata: metadata,
            tags: ["network", "http"]
        )
    }
    
    // MARK: - Error Recovery (错误恢复)
    
    /// Execute a recovery action
    /// 执行恢复操作
    func executeRecoveryAction(_ action: RecoveryAction, for errorId: String) async -> Bool {
        do {
            switch action.actionType {
            case .retry:
                return await handleRetryAction(action, errorId: errorId)
            case .refresh:
                return await handleRefreshAction(action, errorId: errorId)
            case .logout:
                return await handleLogoutAction(action, errorId: errorId)
            case .navigate:
                return await handleNavigateAction(action, errorId: errorId)
            case .contact:
                return await handleContactAction(action, errorId: errorId)
            case .restart:
                return await handleRestartAction(action, errorId: errorId)
            case .custom:
                return await handleCustomAction(action, errorId: errorId)
            }
        } catch {
            await logError(
                category: .system,
                severity: .error,
                code: "RECOVERY_ACTION_FAILED",
                message: "Failed to execute recovery action: \(action.title)",
                underlyingError: error,
                component: "UnifiedErrorHandlingService"
            )
            return false
        }
    }
    
    // MARK: - Error Analytics (错误分析)
    
    /// Get error statistics for a time period
    /// 获取时间段内的错误统计
    func getErrorStatistics(for period: TimePeriod) -> ErrorStatistics {
        let filteredErrors = filterErrorsByPeriod(recentErrors, period: period)
        return calculateStatistics(from: filteredErrors)
    }
    
    /// Get error trends
    /// 获取错误趋势
    func getErrorTrends(for period: TimePeriod) -> [ErrorTrend] {
        let filteredErrors = filterErrorsByPeriod(recentErrors, period: period)
        return calculateTrends(from: filteredErrors, period: period)
    }
    
    /// Get top error patterns
    /// 获取主要错误模式
    func getTopErrorPatterns(limit: Int = 10) -> [ErrorPattern] {
        return errorAggregator.getTopPatterns(limit: limit)
    }
    
    // MARK: - Error Management (错误管理)
    
    /// Update error status
    /// 更新错误状态
    func updateErrorStatus(_ errorId: String, status: ErrorEvent.ErrorStatus, assignedTo: String? = nil) async {
        guard let index = recentErrors.firstIndex(where: { $0.id == errorId }) else { return }
        
        recentErrors[index].status = status
        if let assignedTo = assignedTo {
            recentErrors[index].assignedTo = assignedTo
        }
        
        // Log status change
        try? await auditService.logSecurityEvent(
            event: "error_status_updated",
            userId: authService.currentUser?.id ?? "system",
            details: [
                "error_id": errorId,
                "old_status": recentErrors[index].status.rawValue,
                "new_status": status.rawValue,
                "assigned_to": assignedTo ?? ""
            ]
        )
        
        saveErrorEvents()
    }
    
    /// Add note to error
    /// 为错误添加备注
    func addErrorNote(_ errorId: String, note: String) async {
        guard let index = recentErrors.firstIndex(where: { $0.id == errorId }) else { return }
        
        let errorNote = ErrorEvent.ErrorNote(
            note: note,
            addedBy: authService.currentUser?.id ?? "system"
        )
        
        recentErrors[index].notes.append(errorNote)
        
        saveErrorEvents()
    }
    
    /// Resolve error
    /// 解决错误
    func resolveError(
        _ errorId: String,
        resolutionType: ErrorEvent.ErrorResolution.ResolutionType,
        description: String,
        preventionMeasures: [String] = []
    ) async {
        guard let index = recentErrors.firstIndex(where: { $0.id == errorId }) else { return }
        
        let resolution = ErrorEvent.ErrorResolution(
            resolvedBy: authService.currentUser?.id ?? "system",
            resolvedAt: Date(),
            resolutionType: resolutionType,
            description: description,
            preventionMeasures: preventionMeasures
        )
        
        recentErrors[index].status = .resolved
        recentErrors[index].resolution = resolution
        
        // Log resolution
        try? await auditService.logSecurityEvent(
            event: "error_resolved",
            userId: authService.currentUser?.id ?? "system",
            details: [
                "error_id": errorId,
                "resolution_type": resolutionType.rawValue,
                "description": description
            ]
        )
        
        saveErrorEvents()
    }
    
    // MARK: - Private Methods (私有方法)
    
    private func setupLoggingInfrastructure() {
        // Create error log directory
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: errorLogDirectory, withIntermediateDirectories: true)
        
        // Setup log file
        setupLogFile()
        
        // Configure system logger
        configureSystemLogger()
    }
    
    private func setupLogFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let logFileName = "errors-\(dateFormatter.string(from: Date())).log"
        let logFileURL = errorLogDirectory.appendingPathComponent(logFileName)
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        logFileHandle = try? FileHandle(forWritingTo: logFileURL)
        logFileHandle?.seekToEndOfFile()
    }
    
    private func configureSystemLogger() {
        // Additional system logger configuration if needed
    }
    
    private func processError(_ error: UnifiedError) {
        // Write to system log
        writeToSystemLog(error)
        
        // Write to file log
        writeToFileLog(error)
        
        // Aggregate error patterns
        errorAggregator.addError(error)
        
        // Check for error thresholds
        checkErrorThresholds(error)
    }
    
    private func processErrorOnMainThread(_ error: UnifiedError) async {
        // Find existing error event or create new one
        let reportedBy = authService.currentUser?.id ?? "anonymous"
        
        if let existingIndex = recentErrors.firstIndex(where: { 
            $0.error.code == error.code && 
            $0.error.category == error.category &&
            $0.error.message == error.message 
        }) {
            // Update existing error
            recentErrors[existingIndex].recordOccurrence(reportedBy: reportedBy)
        } else {
            // Create new error event
            let errorEvent = ErrorEvent(error: error, reportedBy: reportedBy)
            recentErrors.insert(errorEvent, at: 0)
            
            // Limit recent errors
            if recentErrors.count > maxRecentErrors {
                recentErrors = Array(recentErrors.prefix(maxRecentErrors))
            }
        }
        
        // Update statistics
        updateErrorStatistics(with: error)
        
        // Check for alerts
        await checkForErrorAlerts(error)
        
        // Save to persistent storage
        saveErrorEvents()
    }
    
    private func writeToSystemLog(_ error: UnifiedError) {
        let logMessage = """
        [\(error.severity.rawValue.uppercased())] \(error.category.rawValue) | \(error.code)
        Message: \(error.message)
        Component: \(error.context.component)
        Function: \(error.context.function)
        User: \(error.context.userId ?? "anonymous")
        """
        
        switch error.severity {
        case .trace, .debug:
            systemLogger.debug("\(logMessage)")
        case .info:
            systemLogger.info("\(logMessage)")
        case .warning:
            systemLogger.notice("\(logMessage)")
        case .error:
            systemLogger.error("\(logMessage)")
        case .critical, .fatal:
            systemLogger.critical("\(logMessage)")
        }
    }
    
    private func writeToFileLog(_ error: UnifiedError) {
        guard let logFileHandle = logFileHandle else { return }
        
        let logEntry = createStructuredLogEntry(error)
        if let logData = logEntry.data(using: .utf8) {
            logFileHandle.write(logData)
        }
    }
    
    private func createStructuredLogEntry(_ error: UnifiedError) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(error)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Failed to encode error: \(error.localizedDescription)\n"
        }
    }
    
    private func generateRecoveryActions(for category: ErrorCategory, severity: ErrorSeverity, code: String) -> [RecoveryAction] {
        var actions: [RecoveryAction] = []
        
        switch category {
        case .authentication:
            actions.append(RecoveryAction(
                title: "重新登录",
                description: "清除当前会话并重新登录",
                actionType: .logout
            ))
            
        case .authorization:
            actions.append(RecoveryAction(
                title: "联系管理员",
                description: "请联系系统管理员获取必要权限",
                actionType: .contact,
                parameters: ["type": "administrator"]
            ))
            
        case .validation:
            actions.append(RecoveryAction(
                title: "检查输入",
                description: "检查并修正输入的数据",
                actionType: .custom,
                parameters: ["action": "validate_input"]
            ))
            
        case .network:
            actions.append(RecoveryAction(
                title: "重试请求",
                description: "重新发送网络请求",
                actionType: .retry,
                isAutomatic: severity <= .warning,
                estimatedTime: 3.0
            ))
            
        case .system:
            if severity >= .critical {
                actions.append(RecoveryAction(
                    title: "重启应用",
                    description: "重启应用程序以恢复正常状态",
                    actionType: .restart
                ))
            } else {
                actions.append(RecoveryAction(
                    title: "刷新页面",
                    description: "刷新当前页面以重新加载数据",
                    actionType: .refresh
                ))
            }
            
        default:
            actions.append(RecoveryAction(
                title: "重试操作",
                description: "重试失败的操作",
                actionType: .retry
            ))
        }
        
        return actions
    }
    
    private func extractStackTrace() -> [String]? {
        // In a real implementation, this would capture the actual stack trace
        // For now, return a placeholder
        return nil
    }
    
    private func updateErrorStatistics(with error: UnifiedError) {
        errorStats.totalErrors += 1
        
        switch error.severity {
        case .warning:
            errorStats.warningCount += 1
        case .error:
            errorStats.errorCount += 1
        case .critical, .fatal:
            errorStats.criticalCount += 1
        default:
            break
        }
        
        errorStats.errorsByCategory[error.category, default: 0] += 1
        errorStats.lastUpdated = Date()
    }
    
    private func checkForErrorAlerts(_ error: UnifiedError) async {
        // Check if error meets alert criteria
        if error.severity >= .critical {
            let alert = ErrorAlert(
                id: UUID().uuidString,
                error: error,
                alertType: .immediate,
                createdAt: Date()
            )
            
            activeAlerts.append(alert)
            
            // Send notification if critical
            await sendErrorNotification(error)
        }
        
        // Check for error pattern alerts
        if let pattern = errorAggregator.checkForNewPatterns(error) {
            let alert = ErrorAlert(
                id: UUID().uuidString,
                error: error,
                alertType: .pattern,
                createdAt: Date(),
                pattern: pattern
            )
            
            activeAlerts.append(alert)
        }
    }
    
    private func sendErrorNotification(_ error: UnifiedError) async {
        guard let notificationEngine = notificationEngine else { return }
        
        try? await notificationEngine.sendImmediateNotification(
            title: "严重错误警报",
            body: error.userFriendlyMessage,
            category: .system,
            priority: .high
        )
    }
    
    private func checkErrorThresholds(_ error: UnifiedError) {
        // Check if error count exceeds thresholds
        guard let threshold = errorThresholds[error.severity] else { return }
        
        let recentErrorsOfSameSeverity = recentErrors.filter { 
            $0.error.severity == error.severity &&
            $0.firstOccurrence.timeIntervalSinceNow > -3600 // Last hour
        }
        
        if recentErrorsOfSameSeverity.count >= threshold {
            // Trigger threshold alert
            Task {
                await sendThresholdAlert(severity: error.severity, count: recentErrorsOfSameSeverity.count)
            }
        }
    }
    
    private func sendThresholdAlert(severity: ErrorSeverity, count: Int) async {
        guard let notificationEngine = notificationEngine else { return }
        
        try? await notificationEngine.sendImmediateNotification(
            title: "错误阈值警报",
            body: "过去一小时内发生了 \(count) 个 \(severity.displayName) 级别的错误",
            category: .system,
            priority: .high
        )
    }
    
    // MARK: - Recovery Action Handlers (恢复操作处理器)
    
    private func handleRetryAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        // Implementation would depend on the specific error context
        // For now, return success
        return true
    }
    
    private func handleRefreshAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        // Implementation for refresh action
        return true
    }
    
    private func handleLogoutAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        authService.logout()
        return true
    }
    
    private func handleNavigateAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        // Implementation for navigation action
        return true
    }
    
    private func handleContactAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        // Implementation for contact action
        return true
    }
    
    private func handleRestartAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        // Implementation for restart action
        // In iOS, this would typically mean showing a restart prompt
        return false
    }
    
    private func handleCustomAction(_ action: RecoveryAction, errorId: String) async -> Bool {
        // Implementation for custom actions based on parameters
        return true
    }
    
    // MARK: - Persistence (持久化)
    
    private func loadRecentErrors() {
        let errorsURL = errorLogDirectory.appendingPathComponent("recent_errors.json")
        
        guard FileManager.default.fileExists(atPath: errorsURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: errorsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            recentErrors = try decoder.decode([ErrorEvent].self, from: data)
        } catch {
            print("Failed to load recent errors: \(error)")
        }
    }
    
    private func saveErrorEvents() {
        let errorsURL = errorLogDirectory.appendingPathComponent("recent_errors.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recentErrors)
            try data.write(to: errorsURL)
        } catch {
            print("Failed to save error events: \(error)")
        }
    }
    
    private func calculateErrorStatistics() {
        errorStats = calculateStatistics(from: recentErrors)
    }
    
    private func calculateStatistics(from events: [ErrorEvent]) -> ErrorStatistics {
        var stats = ErrorStatistics()
        
        stats.totalErrors = events.reduce(0) { $0 + $1.occurrenceCount }
        stats.warningCount = events.filter { $0.error.severity == .warning }.reduce(0) { $0 + $1.occurrenceCount }
        stats.errorCount = events.filter { $0.error.severity == .error }.reduce(0) { $0 + $1.occurrenceCount }
        stats.criticalCount = events.filter { $0.error.severity >= .critical }.reduce(0) { $0 + $1.occurrenceCount }
        
        // Calculate errors by category
        for event in events {
            stats.errorsByCategory[event.error.category, default: 0] += event.occurrenceCount
        }
        
        stats.lastUpdated = Date()
        return stats
    }
    
    private func filterErrorsByPeriod(_ events: [ErrorEvent], period: TimePeriod) -> [ErrorEvent] {
        let cutoffDate = Date().addingTimeInterval(-period.timeInterval)
        return events.filter { $0.lastOccurrence >= cutoffDate }
    }
    
    private func calculateTrends(from events: [ErrorEvent], period: TimePeriod) -> [ErrorTrend] {
        // Implementation for calculating error trends
        return []
    }
    
    private func startPerformanceMonitoring() {
        performanceMonitor.startMonitoring { [weak self] metrics in
            Task { @MainActor in
                await self?.handlePerformanceMetrics(metrics)
            }
        }
    }
    
    private func handlePerformanceMetrics(_ metrics: SystemPerformanceMetrics) async {
        // Handle performance-related errors
        if metrics.memoryUsage > 0.9 {
            await logError(
                category: .performance,
                severity: .warning,
                code: "HIGH_MEMORY_USAGE",
                message: "Memory usage is critically high: \(Int(metrics.memoryUsage * 100))%",
                component: "PerformanceMonitor"
            )
        }
        
        if metrics.cpuUsage > 0.8 {
            await logError(
                category: .performance,
                severity: .warning,
                code: "HIGH_CPU_USAGE",
                message: "CPU usage is high: \(Int(metrics.cpuUsage * 100))%",
                component: "PerformanceMonitor"
            )
        }
    }
}

// MARK: - Supporting Types (支持类型)

/// Time periods for error analysis
/// 错误分析的时间段
enum TimePeriod: CaseIterable {
    case lastHour
    case last24Hours
    case lastWeek
    case lastMonth
    
    var timeInterval: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last24Hours: return 86400
        case .lastWeek: return 604800
        case .lastMonth: return 2592000
        }
    }
    
    var displayName: String {
        switch self {
        case .lastHour: return "过去1小时"
        case .last24Hours: return "过去24小时"
        case .lastWeek: return "过去7天"
        case .lastMonth: return "过去30天"
        }
    }
}

/// Error statistics
/// 错误统计
struct ErrorStatistics {
    var totalErrors: Int = 0
    var warningCount: Int = 0
    var errorCount: Int = 0
    var criticalCount: Int = 0
    var errorsByCategory: [ErrorCategory: Int] = [:]
    var lastUpdated: Date = Date()
    
    var errorRate: Double {
        let timeInterval = Date().timeIntervalSince(lastUpdated)
        return timeInterval > 0 ? Double(totalErrors) / timeInterval : 0
    }
}

/// Error trend data
/// 错误趋势数据
struct ErrorTrend {
    let date: Date
    let count: Int
    let severity: ErrorSeverity
    let category: ErrorCategory
}

/// Error pattern information
/// 错误模式信息
struct ErrorPattern {
    let pattern: String
    let count: Int
    let severity: ErrorSeverity
    let categories: [ErrorCategory]
    let firstSeen: Date
    let lastSeen: Date
}

/// Error alert
/// 错误警报
struct ErrorAlert: Identifiable {
    let id: String
    let error: UnifiedError
    let alertType: AlertType
    let createdAt: Date
    let pattern: ErrorPattern?
    
    enum AlertType {
        case immediate
        case threshold
        case pattern
    }
    
    init(id: String, error: UnifiedError, alertType: AlertType, createdAt: Date, pattern: ErrorPattern? = nil) {
        self.id = id
        self.error = error
        self.alertType = alertType
        self.createdAt = createdAt
        self.pattern = pattern
    }
}

/// Performance metrics
/// 系统性能指标
struct SystemPerformanceMetrics {
    let timestamp: Date
    let memoryUsage: Double // 0.0 to 1.0
    let cpuUsage: Double // 0.0 to 1.0
    let diskUsage: Double // 0.0 to 1.0
    let networkLatency: TimeInterval
}

// MARK: - Error Aggregator (错误聚合器)

class ErrorAggregator {
    private var errorPatterns: [String: ErrorPattern] = [:]
    private var recentErrors: [UnifiedError] = []
    
    func addError(_ error: UnifiedError) {
        recentErrors.append(error)
        
        // Keep only last 10000 errors for pattern analysis
        if recentErrors.count > 10000 {
            recentErrors = Array(recentErrors.suffix(10000))
        }
        
        // Update patterns
        updatePatterns(with: error)
    }
    
    func getTopPatterns(limit: Int) -> [ErrorPattern] {
        return Array(errorPatterns.values)
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
    
    func checkForNewPatterns(_ error: UnifiedError) -> ErrorPattern? {
        let patternKey = "\(error.category.rawValue):\(error.code)"
        
        if let existingPattern = errorPatterns[patternKey] {
            // Check if this is a significant increase
            if existingPattern.count > 10 && error.severity >= .error {
                return existingPattern
            }
        }
        
        return nil
    }
    
    private func updatePatterns(with error: UnifiedError) {
        let patternKey = "\(error.category.rawValue):\(error.code)"
        
        if var existingPattern = errorPatterns[patternKey] {
            existingPattern = ErrorPattern(
                pattern: existingPattern.pattern,
                count: existingPattern.count + 1,
                severity: max(existingPattern.severity, error.severity),
                categories: existingPattern.categories,
                firstSeen: existingPattern.firstSeen,
                lastSeen: Date()
            )
            errorPatterns[patternKey] = existingPattern
        } else {
            let newPattern = ErrorPattern(
                pattern: patternKey,
                count: 1,
                severity: error.severity,
                categories: [error.category],
                firstSeen: Date(),
                lastSeen: Date()
            )
            errorPatterns[patternKey] = newPattern
        }
    }
}

// MARK: - Performance Monitor (性能监控器)

class ErrorPerformanceMonitor {
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var metricsCallback: ((SystemPerformanceMetrics) -> Void)?
    
    func startMonitoring(callback: @escaping (SystemPerformanceMetrics) -> Void) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        metricsCallback = callback
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.collectMetrics()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        metricsCallback = nil
    }
    
    private func collectMetrics() {
        let metrics = SystemPerformanceMetrics(
            timestamp: Date(),
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            diskUsage: getDiskUsage(),
            networkLatency: getNetworkLatency()
        )
        
        metricsCallback?(metrics)
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }
        
        return 0.0
    }
    
    private func getCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a real implementation, this would use more sophisticated methods
        return 0.0
    }
    
    private func getDiskUsage() -> Double {
        // Simplified disk usage calculation
        return 0.0
    }
    
    private func getNetworkLatency() -> TimeInterval {
        // Simplified network latency measurement
        return 0.0
    }
}