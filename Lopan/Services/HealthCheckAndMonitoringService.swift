//
//  HealthCheckAndMonitoringService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Health Check and Monitoring Service (健康检查和监控服务)

/// Comprehensive system health monitoring and metrics collection service
/// 综合系统健康监控和指标收集服务
@MainActor
class HealthCheckAndMonitoringService: ObservableObject {
    
    // MARK: - Dependencies
    private let repositoryFactory: RepositoryFactory
    private let faultDetectionService: FaultDetectionAndRecoveryService
    private let errorHandlingService: UnifiedErrorHandlingService
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private let notificationEngine: NotificationEngine
    private let permissionService: AdvancedPermissionService
    
    // MARK: - State
    @Published var isMonitoring = false
    @Published var overallHealthStatus: OverallHealthStatus = .unknown
    @Published var systemMetrics: SystemMetrics = SystemMetrics()
    @Published var healthChecks: [HealthCheck] = []
    @Published var performanceMetrics: [PerformanceMetric] = []
    @Published var alerts: [HealthAlert] = []
    @Published var monitoringConfiguration: MonitoringConfiguration = MonitoringConfiguration()
    @Published var lastFullHealthCheck: Date?
    
    // MARK: - Health Check Components
    private let healthCheckers: [HealthChecker]
    private let metricsCollectors: [MetricsCollector]
    private let performanceMonitors: [PerformanceMonitor]
    
    // MARK: - Monitoring Tasks
    private var healthCheckTask: Task<Void, Never>?
    private var metricsCollectionTask: Task<Void, Never>?
    private var performanceMonitoringTask: Task<Void, Never>?
    private var alertProcessingTask: Task<Void, Never>?
    
    // MARK: - Configuration
    private let quickHealthCheckInterval: TimeInterval = 15.0 // 15 seconds
    private let fullHealthCheckInterval: TimeInterval = 300.0 // 5 minutes
    private let metricsCollectionInterval: TimeInterval = 30.0 // 30 seconds
    private let performanceMonitoringInterval: TimeInterval = 5.0 // 5 seconds
    
    // MARK: - Metrics Storage
    private var metricsHistory: [Date: SystemMetrics] = [:]
    private var performanceHistory: [Date: [PerformanceMetric]] = [:]
    private let maxHistoryRetention: TimeInterval = 86400 // 24 hours
    
    init(
        repositoryFactory: RepositoryFactory,
        faultDetectionService: FaultDetectionAndRecoveryService,
        errorHandlingService: UnifiedErrorHandlingService,
        auditService: NewAuditingService,
        authService: AuthenticationService,
        notificationEngine: NotificationEngine,
        permissionService: AdvancedPermissionService
    ) {
        self.repositoryFactory = repositoryFactory
        self.faultDetectionService = faultDetectionService
        self.errorHandlingService = errorHandlingService
        self.auditService = auditService
        self.authService = authService
        self.notificationEngine = notificationEngine
        self.permissionService = permissionService
        
        // Initialize health checkers
        self.healthCheckers = [
            DatabaseHealthChecker(repositoryFactory: repositoryFactory),
            ServiceHealthChecker(repositoryFactory: repositoryFactory),
            MemoryHealthChecker(),
            StorageHealthChecker(),
            NetworkHealthChecker(),
            SecurityHealthChecker(),
            ConfigurationHealthChecker()
        ]
        
        // Initialize metrics collectors
        self.metricsCollectors = [
            SystemResourceCollector(),
            DatabaseMetricsCollector(repositoryFactory: repositoryFactory),
            UserActivityCollector(repositoryFactory: repositoryFactory),
            ErrorMetricsCollector(errorHandlingService: errorHandlingService),
            SecurityMetricsCollector()
        ]
        
        // Initialize performance monitors
        self.performanceMonitors = [
            ResponseTimeMonitor(),
            ThroughputMonitor(),
            ResourceUtilizationMonitor(),
            ConcurrencyMonitor(),
            CachePerformanceMonitor()
        ]
        
        loadMonitoringConfiguration()
        setupHealthChecks()
    }
    
    // MARK: - Public Interface
    
    /// Start comprehensive system monitoring
    /// 启动综合系统监控
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start health check monitoring
        healthCheckTask = Task {
            await runHealthCheckLoop()
        }
        
        // Start metrics collection
        metricsCollectionTask = Task {
            await runMetricsCollectionLoop()
        }
        
        // Start performance monitoring
        performanceMonitoringTask = Task {
            await runPerformanceMonitoringLoop()
        }
        
        // Start alert processing
        alertProcessingTask = Task {
            await runAlertProcessingLoop()
        }
        
        // Log monitoring start
        try? await auditService.logSecurityEvent(
            event: "health_monitoring_started",
            userId: authService.currentUser?.id ?? "system",
            details: [
                "quick_check_interval": "\(quickHealthCheckInterval)",
                "full_check_interval": "\(fullHealthCheckInterval)",
                "metrics_interval": "\(metricsCollectionInterval)"
            ]
        )
        
        // Perform initial health check
        await performFullHealthCheck()
    }
    
    /// Stop system monitoring
    /// 停止系统监控
    func stopMonitoring() async {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Cancel monitoring tasks
        healthCheckTask?.cancel()
        metricsCollectionTask?.cancel()
        performanceMonitoringTask?.cancel()
        alertProcessingTask?.cancel()
        
        healthCheckTask = nil
        metricsCollectionTask = nil
        performanceMonitoringTask = nil
        alertProcessingTask = nil
        
        // Log monitoring stop
        try? await auditService.logSecurityEvent(
            event: "health_monitoring_stopped",
            userId: authService.currentUser?.id ?? "system",
            details: [:]
        )
        
        overallHealthStatus = .stopped
    }
    
    /// Perform manual health check
    /// 执行手动健康检查
    func performManualHealthCheck() async throws -> HealthCheckResult {
        guard await permissionService.hasPermission(.monitorSystemHealth).isGranted else {
            throw HealthMonitoringError.insufficientPermissions
        }
        
        return await performFullHealthCheck()
    }
    
    /// Get health status for specific component
    /// 获取特定组件的健康状态
    func getComponentHealth(_ component: String) -> HealthCheck? {
        return healthChecks.first { $0.component == component }
    }
    
    /// Get system metrics for time range
    /// 获取时间范围内的系统指标
    func getMetricsHistory(since: Date, until: Date = Date()) -> [Date: SystemMetrics] {
        return metricsHistory.filter { (date, _) in
            date >= since && date <= until
        }
    }
    
    /// Get performance metrics for time range
    /// 获取时间范围内的性能指标
    func getPerformanceHistory(since: Date, until: Date = Date()) -> [Date: [PerformanceMetric]] {
        return performanceHistory.filter { (date, _) in
            date >= since && date <= until
        }
    }
    
    /// Update monitoring configuration
    /// 更新监控配置
    func updateMonitoringConfiguration(_ configuration: MonitoringConfiguration) async throws {
        guard await permissionService.hasPermission(.manageSystemSettings).isGranted else {
            throw HealthMonitoringError.insufficientPermissions
        }
        
        self.monitoringConfiguration = configuration
        saveMonitoringConfiguration()
        
        // Log configuration update
        try await auditService.logSecurityEvent(
            event: "monitoring_configuration_updated",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "alerts_enabled": "\(configuration.alertsEnabled)",
                "retention_days": "\(configuration.metricsRetentionDays)"
            ]
        )
    }
    
    /// Acknowledge health alert
    /// 确认健康警报
    func acknowledgeAlert(_ alertId: String) async throws {
        guard let alertIndex = alerts.firstIndex(where: { $0.id == alertId }) else {
            throw HealthMonitoringError.alertNotFound
        }
        
        alerts[alertIndex].isAcknowledged = true
        alerts[alertIndex].acknowledgedAt = Date()
        alerts[alertIndex].acknowledgedBy = authService.currentUser?.id
        
        // Log alert acknowledgment
        try await auditService.logSecurityEvent(
            event: "health_alert_acknowledged",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "alert_id": alertId,
                "alert_type": alerts[alertIndex].type.rawValue
            ]
        )
    }
    
    /// Generate comprehensive health report
    /// 生成综合健康报告
    func generateHealthReport() async throws -> HealthReport {
        guard await permissionService.hasPermission(.viewSystemConfiguration).isGranted else {
            throw HealthMonitoringError.insufficientPermissions
        }
        
        let reportId = UUID().uuidString
        let generatedAt = Date()
        
        // Calculate overall health score
        let healthScore = calculateOverallHealthScore()
        
        // Get recent metrics
        let since24Hours = Date().addingTimeInterval(-86400)
        let recentMetrics = getMetricsHistory(since: since24Hours)
        let recentPerformance = getPerformanceHistory(since: since24Hours)
        
        // Analyze trends
        let trends = analyzeTrends(metrics: recentMetrics, performance: recentPerformance)
        
        // Get recommendations
        let recommendations = generateRecommendations()
        
        let report = HealthReport(
            id: reportId,
            generatedAt: generatedAt,
            generatedBy: authService.currentUser?.id ?? "system",
            overallHealthScore: healthScore,
            healthStatus: overallHealthStatus,
            systemMetrics: systemMetrics,
            healthChecks: healthChecks,
            activeAlerts: alerts.filter { !$0.isAcknowledged },
            trends: trends,
            recommendations: recommendations,
            reportPeriod: .last24Hours
        )
        
        // Log report generation
        try await auditService.logSecurityEvent(
            event: "health_report_generated",
            userId: authService.currentUser?.id ?? "system",
            details: [
                "report_id": reportId,
                "health_score": "\(healthScore)",
                "active_alerts": "\(alerts.filter { !$0.isAcknowledged }.count)"
            ]
        )
        
        return report
    }
    
    // MARK: - Private Implementation
    
    private func runHealthCheckLoop() async {
        while isMonitoring && !Task.isCancelled {
            do {
                // Alternate between quick and full health checks
                let useFullCheck = Int(Date().timeIntervalSince1970) % Int(fullHealthCheckInterval) < Int(quickHealthCheckInterval)
                
                if useFullCheck {
                    await performFullHealthCheck()
                } else {
                    await performQuickHealthCheck()
                }
                
                try await Task.sleep(nanoseconds: UInt64(quickHealthCheckInterval * 1_000_000_000))
            } catch {
                if !Task.isCancelled {
                    await errorHandlingService.logError(
                        category: .system,
                        severity: .warning,
                        code: "HEALTH_CHECK_ERROR",
                        message: "Health check failed",
                        underlyingError: error,
                        component: "HealthCheckAndMonitoringService",
                        additionalMetadata: ["operation": "health_check_loop"]
                    )
                }
                break
            }
        }
    }
    
    private func runMetricsCollectionLoop() async {
        while isMonitoring && !Task.isCancelled {
            do {
                await collectSystemMetrics()
                await cleanupOldMetrics()
                
                try await Task.sleep(nanoseconds: UInt64(metricsCollectionInterval * 1_000_000_000))
            } catch {
                if !Task.isCancelled {
                    await errorHandlingService.logError(
                        category: .system,
                        severity: .warning,
                        code: "HEALTH_CHECK_ERROR",
                        message: "Health check failed",
                        underlyingError: error,
                        component: "HealthCheckAndMonitoringService",
                        additionalMetadata: ["operation": "metrics_collection_loop"]
                    )
                }
                break
            }
        }
    }
    
    private func runPerformanceMonitoringLoop() async {
        while isMonitoring && !Task.isCancelled {
            do {
                await collectPerformanceMetrics()
                
                try await Task.sleep(nanoseconds: UInt64(performanceMonitoringInterval * 1_000_000_000))
            } catch {
                if !Task.isCancelled {
                    await errorHandlingService.logError(
                        category: .system,
                        severity: .warning,
                        code: "HEALTH_CHECK_ERROR",
                        message: "Health check failed",
                        underlyingError: error,
                        component: "HealthCheckAndMonitoringService",
                        additionalMetadata: ["operation": "performance_monitoring_loop"]
                    )
                }
                break
            }
        }
    }
    
    private func runAlertProcessingLoop() async {
        while isMonitoring && !Task.isCancelled {
            do {
                await processHealthAlerts()
                await cleanupOldAlerts()
                
                try await Task.sleep(nanoseconds: UInt64(10.0 * 1_000_000_000)) // Process alerts every 10 seconds
            } catch {
                if !Task.isCancelled {
                    await errorHandlingService.logError(
                        category: .system,
                        severity: .warning,
                        code: "HEALTH_CHECK_ERROR",
                        message: "Health check failed",
                        underlyingError: error,
                        component: "HealthCheckAndMonitoringService",
                        additionalMetadata: ["operation": "alert_processing_loop"]
                    )
                }
                break
            }
        }
    }
    
    @discardableResult
    private func performFullHealthCheck() async -> HealthCheckResult {
        let checkId = UUID().uuidString
        let startTime = Date()
        
        var results: [HealthCheck] = []
        var overallScore = 100
        
        // Run all health checkers
        for checker in healthCheckers {
            do {
                let result = try await checker.performHealthCheck()
                results.append(result)
                
                // Adjust overall score based on result
                switch result.status {
                case .healthy: break
                case .warning: overallScore -= 5
                case .critical: overallScore -= 15
                case .failing: overallScore -= 25
                }
                
            } catch {
                let failedCheck = HealthCheck(
                    component: checker.name,
                    status: .failing,
                    message: "Health check failed: \(error.localizedDescription)",
                    details: ["error": error.localizedDescription],
                    checkedAt: Date()
                )
                results.append(failedCheck)
                overallScore -= 25
            }
        }
        
        // Update state
        await MainActor.run {
            healthChecks = results
            lastFullHealthCheck = Date()
            
            // Determine overall health status
            let criticalChecks = results.filter { $0.status == .critical || $0.status == .failing }
            if criticalChecks.count >= 3 {
                overallHealthStatus = .critical
            } else if !criticalChecks.isEmpty {
                overallHealthStatus = .degraded
            } else if results.contains(where: { $0.status == .warning }) {
                overallHealthStatus = .warning
            } else {
                overallHealthStatus = .healthy
            }
        }
        
        let result = HealthCheckResult(
            checkId: checkId,
            startTime: startTime,
            endTime: Date(),
            healthChecks: results,
            overallScore: max(0, overallScore),
            overallStatus: overallHealthStatus
        )
        
        // Generate alerts for failed checks
        await generateAlertsForFailedChecks(results)
        
        return result
    }
    
    private func performQuickHealthCheck() async {
        // Quick health check only runs critical checkers
        let criticalCheckers = healthCheckers.filter { checker in
            checker.name.contains("Database") || checker.name.contains("Service")
        }
        
        for checker in criticalCheckers {
            do {
                let result = try await checker.performHealthCheck()
                
                // Update existing health check if found
                if let index = healthChecks.firstIndex(where: { $0.component == result.component }) {
                    await MainActor.run {
                        healthChecks[index] = result
                    }
                }
                
            } catch {
                await errorHandlingService.logError(
                    category: .system,
                    severity: .warning,
                    code: "HEALTH_CHECK_ERROR",
                    message: "Health check failed",
                    underlyingError: error,
                    component: "HealthCheckAndMonitoringService",
                    additionalMetadata: [
                        "checker": checker.name,
                        "operation": "quick_health_check"
                    ]
                )
            }
        }
    }
    
    private func collectSystemMetrics() async {
        var metrics = SystemMetrics()
        
        // Collect metrics from all collectors
        for collector in metricsCollectors {
            do {
                let collectedMetrics = try await collector.collectMetrics()
                metrics.merge(with: collectedMetrics)
            } catch {
                await errorHandlingService.logError(
                    category: .system,
                    severity: .warning,
                    code: "HEALTH_CHECK_ERROR",
                    message: "Health check failed",
                    underlyingError: error,
                    component: "HealthCheckAndMonitoringService",
                    additionalMetadata: [
                        "collector": collector.name,
                        "operation": "metrics_collection"
                    ]
                )
            }
        }
        
        // Update state and store in history
        await MainActor.run {
            systemMetrics = metrics
            metricsHistory[Date()] = metrics
        }
    }
    
    private func collectPerformanceMetrics() async {
        var allMetrics: [PerformanceMetric] = []
        
        // Collect performance metrics from all monitors
        for monitor in performanceMonitors {
            do {
                let metrics = try await monitor.collectMetrics()
                allMetrics.append(contentsOf: metrics)
            } catch {
                await errorHandlingService.logError(
                    category: .system,
                    severity: .warning,
                    code: "HEALTH_CHECK_ERROR",
                    message: "Health check failed",
                    underlyingError: error,
                    component: "HealthCheckAndMonitoringService",
                    additionalMetadata: [
                        "monitor": monitor.name,
                        "operation": "performance_collection"
                    ]
                )
            }
        }
        
        // Update state and store in history
        await MainActor.run {
            performanceMetrics = allMetrics
            performanceHistory[Date()] = allMetrics
        }
    }
    
    private func processHealthAlerts() async {
        // Check for new alerts based on health checks and metrics
        await generateAlertsFromMetrics()
        await generateAlertsFromPerformance()
        
        // Send notifications for new high-priority alerts
        let newCriticalAlerts = alerts.filter { 
            $0.priority == .critical && 
            !$0.isAcknowledged && 
            Date().timeIntervalSince($0.createdAt) < 60 // Within last minute
        }
        
        for alert in newCriticalAlerts {
            do {
                try await sendAlertNotification(alert)
            } catch {
                // Log error silently - notification failure shouldn't break monitoring
            }
        }
    }
    
    private func generateAlertsForFailedChecks(_ checks: [HealthCheck]) async {
        for check in checks {
            if check.status == .critical || check.status == .failing {
                let alert = HealthAlert(
                    type: .healthCheckFailed,
                    priority: check.status == .failing ? .critical : .high,
                    title: "\(check.component) 健康检查失败",
                    message: check.message,
                    component: check.component,
                    details: check.details
                )
                
                await MainActor.run {
                    alerts.append(alert)
                }
            }
        }
    }
    
    private func generateAlertsFromMetrics() async {
        // Check CPU usage
        if systemMetrics.cpuUsage > 0.9 {
            let alert = HealthAlert(
                type: .highResourceUsage,
                priority: .high,
                title: "CPU 使用率过高",
                message: "CPU 使用率: \(Int(systemMetrics.cpuUsage * 100))%",
                component: "System",
                details: ["cpu_usage": "\(systemMetrics.cpuUsage)"]
            )
            
            await MainActor.run {
                if !alerts.contains(where: { $0.type == .highResourceUsage && $0.component == "System" }) {
                    alerts.append(alert)
                }
            }
        }
        
        // Check memory usage
        if systemMetrics.memoryUsage > 0.85 {
            let alert = HealthAlert(
                type: .highResourceUsage,
                priority: systemMetrics.memoryUsage > 0.95 ? .critical : .high,
                title: "内存使用率过高",
                message: "内存使用率: \(Int(systemMetrics.memoryUsage * 100))%",
                component: "Memory",
                details: ["memory_usage": "\(systemMetrics.memoryUsage)"]
            )
            
            await MainActor.run {
                if !alerts.contains(where: { $0.type == .highResourceUsage && $0.component == "Memory" }) {
                    alerts.append(alert)
                }
            }
        }
        
        // Check error rate
        if systemMetrics.errorRate > 0.05 {
            let alert = HealthAlert(
                type: .highErrorRate,
                priority: systemMetrics.errorRate > 0.1 ? .critical : .high,
                title: "系统错误率过高",
                message: "错误率: \(String(format: "%.2f", systemMetrics.errorRate * 100))%",
                component: "System",
                details: ["error_rate": "\(systemMetrics.errorRate)"]
            )
            
            await MainActor.run {
                if !alerts.contains(where: { $0.type == .highErrorRate }) {
                    alerts.append(alert)
                }
            }
        }
    }
    
    private func generateAlertsFromPerformance() async {
        // Check response time
        let avgResponseTime = performanceMetrics
            .filter { $0.category == .responseTime }
            .reduce(0.0) { $0 + $1.value } / Double(max(1, performanceMetrics.filter { $0.category == .responseTime }.count))
        
        if avgResponseTime > 2.0 {
            let alert = HealthAlert(
                type: .performanceDegradation,
                priority: avgResponseTime > 5.0 ? .critical : .high,
                title: "系统响应时间过长",
                message: "平均响应时间: \(String(format: "%.2f", avgResponseTime))秒",
                component: "Performance",
                details: ["avg_response_time": "\(avgResponseTime)"]
            )
            
            await MainActor.run {
                if !alerts.contains(where: { $0.type == .performanceDegradation }) {
                    alerts.append(alert)
                }
            }
        }
    }
    
    private func sendAlertNotification(_ alert: HealthAlert) async throws {
        let notification = NotificationMessage(
            category: .system,
            priority: alert.priority == .critical ? .critical : .high,
            title: alert.title,
            body: alert.message,
            data: [
                "alert_id": alert.id,
                "component": alert.component,
                "alert_type": alert.type.rawValue
            ],
            targetUserIds: [],
            targetRoles: [.administrator],
            channels: [.inApp, .push]
        )
        
        try await notificationEngine.sendNotification(notification)
    }
    
    private func cleanupOldMetrics() async {
        let cutoffTime = Date().addingTimeInterval(-maxHistoryRetention)
        
        await MainActor.run {
            metricsHistory = metricsHistory.filter { (date, _) in
                date >= cutoffTime
            }
            
            performanceHistory = performanceHistory.filter { (date, _) in
                date >= cutoffTime
            }
        }
    }
    
    private func cleanupOldAlerts() async {
        let cutoffTime = Date().addingTimeInterval(-86400) // 24 hours
        
        await MainActor.run {
            alerts.removeAll { alert in
                alert.isAcknowledged && alert.createdAt < cutoffTime
            }
        }
    }
    
    private func calculateOverallHealthScore() -> Int {
        guard !healthChecks.isEmpty else { return 0 }
        
        var score = 100
        
        for check in healthChecks {
            switch check.status {
            case .healthy: break
            case .warning: score -= 5
            case .critical: score -= 15
            case .failing: score -= 25
            }
        }
        
        // Adjust based on active alerts
        let criticalAlerts = alerts.filter { $0.priority == .critical && !$0.isAcknowledged }.count
        let highAlerts = alerts.filter { $0.priority == .high && !$0.isAcknowledged }.count
        
        score -= criticalAlerts * 10
        score -= highAlerts * 5
        
        return max(0, score)
    }
    
    private func analyzeTrends(metrics: [Date: SystemMetrics], performance: [Date: [PerformanceMetric]]) -> [HealthTrend] {
        var trends: [HealthTrend] = []
        
        // Analyze CPU trend
        let cpuValues = metrics.values.map { $0.cpuUsage }
        if cpuValues.count > 2 {
            let trend = calculateTrend(values: cpuValues)
            trends.append(HealthTrend(
                component: "CPU",
                metric: "Usage",
                direction: trend.direction,
                changePercent: trend.changePercent,
                significance: trend.significance
            ))
        }
        
        // Analyze memory trend
        let memoryValues = metrics.values.map { $0.memoryUsage }
        if memoryValues.count > 2 {
            let trend = calculateTrend(values: memoryValues)
            trends.append(HealthTrend(
                component: "Memory",
                metric: "Usage",
                direction: trend.direction,
                changePercent: trend.changePercent,
                significance: trend.significance
            ))
        }
        
        // Analyze error rate trend
        let errorRateValues = metrics.values.map { $0.errorRate }
        if errorRateValues.count > 2 {
            let trend = calculateTrend(values: errorRateValues)
            trends.append(HealthTrend(
                component: "System",
                metric: "Error Rate",
                direction: trend.direction,
                changePercent: trend.changePercent,
                significance: trend.significance
            ))
        }
        
        return trends
    }
    
    private func calculateTrend(values: [Double]) -> (direction: TrendDirection, changePercent: Double, significance: TrendSignificance) {
        guard values.count >= 2 else {
            return (.stable, 0.0, .none)
        }
        
        let recent = Array(values.suffix(min(10, values.count))) // Last 10 values
        let firstHalf = Array(recent.prefix(recent.count / 2))
        let secondHalf = Array(recent.suffix(recent.count / 2))
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let change = (secondAvg - firstAvg) / firstAvg
        let changePercent = abs(change * 100)
        
        let direction: TrendDirection
        if change > 0.05 {
            direction = .increasing
        } else if change < -0.05 {
            direction = .decreasing
        } else {
            direction = .stable
        }
        
        let significance: TrendSignificance
        if changePercent > 20 {
            significance = .high
        } else if changePercent > 10 {
            significance = .medium
        } else if changePercent > 5 {
            significance = .low
        } else {
            significance = .none
        }
        
        return (direction, changePercent, significance)
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Analyze current state and generate recommendations
        if systemMetrics.memoryUsage > 0.8 {
            recommendations.append("考虑增加系统内存或优化内存使用")
        }
        
        if systemMetrics.cpuUsage > 0.8 {
            recommendations.append("监控CPU使用情况，考虑性能优化")
        }
        
        if systemMetrics.errorRate > 0.05 {
            recommendations.append("调查系统错误原因并实施修复措施")
        }
        
        let criticalAlerts = alerts.filter { $0.priority == .critical && !$0.isAcknowledged }.count
        if criticalAlerts > 0 {
            recommendations.append("立即处理 \(criticalAlerts) 个严重警报")
        }
        
        let failingChecks = healthChecks.filter { $0.status == .failing }.count
        if failingChecks > 0 {
            recommendations.append("修复 \(failingChecks) 个失败的健康检查")
        }
        
        if recommendations.isEmpty {
            recommendations.append("系统运行正常，继续定期监控")
        }
        
        return recommendations
    }
    
    private func setupHealthChecks() {
        // Initialize health checks with default values
        healthChecks = healthCheckers.map { checker in
            HealthCheck(
                component: checker.name,
                status: .healthy,
                message: "等待初始检查",
                details: [:],
                checkedAt: Date()
            )
        }
    }
    
    private func loadMonitoringConfiguration() {
        // Load configuration from user defaults or configuration file
        // This is a placeholder implementation
        monitoringConfiguration = MonitoringConfiguration()
    }
    
    private func saveMonitoringConfiguration() {
        // Save configuration to persistent storage
        // This is a placeholder implementation
    }
}

// MARK: - Supporting Types (支持类型)

/// Overall health status
/// 整体健康状态
enum OverallHealthStatus: String, CaseIterable {
    case unknown = "unknown"
    case healthy = "healthy"
    case warning = "warning"
    case degraded = "degraded"
    case critical = "critical"
    case stopped = "stopped"
    
    var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .healthy: return "健康"
        case .warning: return "警告"
        case .degraded: return "降级"
        case .critical: return "严重"
        case .stopped: return "已停止"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .healthy: return .green
        case .warning: return .yellow
        case .degraded: return .orange
        case .critical: return .red
        case .stopped: return .gray
        }
    }
}

/// Individual health check result
/// 单个健康检查结果
struct HealthCheck: Identifiable {
    let id: String
    let component: String
    var status: HealthStatus
    var message: String
    var details: [String: String]
    var checkedAt: Date
    
    init(component: String, status: HealthStatus, message: String, details: [String: String], checkedAt: Date) {
        self.id = UUID().uuidString
        self.component = component
        self.status = status
        self.message = message
        self.details = details
        self.checkedAt = checkedAt
    }
}

enum HealthStatus: String, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    case failing = "failing"
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .failing: return .red
        }
    }
}

/// System metrics collection
/// 系统指标收集
struct SystemMetrics {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var diskUsage: Double = 0.0
    var networkBytesIn: Int64 = 0
    var networkBytesOut: Int64 = 0
    var activeConnections: Int = 0
    var databaseConnections: Int = 0
    var errorRate: Double = 0.0
    var responseTime: Double = 0.0
    var throughput: Double = 0.0
    var activeUsers: Int = 0
    var collectedAt: Date = Date()
    
    mutating func merge(with other: SystemMetrics) {
        // Merge metrics, taking the maximum or sum as appropriate
        cpuUsage = max(cpuUsage, other.cpuUsage)
        memoryUsage = max(memoryUsage, other.memoryUsage)
        diskUsage = max(diskUsage, other.diskUsage)
        networkBytesIn += other.networkBytesIn
        networkBytesOut += other.networkBytesOut
        activeConnections = max(activeConnections, other.activeConnections)
        databaseConnections = max(databaseConnections, other.databaseConnections)
        errorRate = max(errorRate, other.errorRate)
        responseTime = max(responseTime, other.responseTime)
        throughput += other.throughput
        activeUsers = max(activeUsers, other.activeUsers)
    }
}

/// Performance metric
/// 性能指标
struct PerformanceMetric: Identifiable {
    let id: String
    let name: String
    let category: PerformanceCategory
    let value: Double
    let unit: String
    let collectedAt: Date
    let tags: [String: String]
    
    init(name: String, category: PerformanceCategory, value: Double, unit: String, tags: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.collectedAt = Date()
        self.tags = tags
    }
}

enum PerformanceCategory: String, CaseIterable {
    case responseTime = "response_time"
    case throughput = "throughput"
    case resourceUtilization = "resource_utilization"
    case concurrency = "concurrency"
    case cachePerformance = "cache_performance"
    case databasePerformance = "database_performance"
}

/// Health alert
/// 健康警报
struct HealthAlert: Identifiable {
    let id: String
    let type: AlertType
    let priority: AlertPriority
    let title: String
    let message: String
    let component: String
    let details: [String: String]
    let createdAt: Date
    var isAcknowledged: Bool = false
    var acknowledgedAt: Date?
    var acknowledgedBy: String?
    
    init(type: AlertType, priority: AlertPriority, title: String, message: String, component: String, details: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.type = type
        self.priority = priority
        self.title = title
        self.message = message
        self.component = component
        self.details = details
        self.createdAt = Date()
    }
}

enum AlertType: String, CaseIterable {
    case healthCheckFailed = "health_check_failed"
    case highResourceUsage = "high_resource_usage"
    case performanceDegradation = "performance_degradation"
    case highErrorRate = "high_error_rate"
    case serviceDown = "service_down"
    case securityBreach = "security_breach"
    case configurationError = "configuration_error"
}

enum AlertPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// Monitoring configuration
/// 监控配置
struct MonitoringConfiguration {
    var alertsEnabled: Bool = true
    var metricsRetentionDays: Int = 7
    var healthCheckIntervalSeconds: Int = 300
    var metricsCollectionIntervalSeconds: Int = 30
    var performanceMonitoringEnabled: Bool = true
    var notificationChannels: [String] = ["email", "push"]
    var alertThresholds: [String: Double] = [
        "cpu_usage": 0.8,
        "memory_usage": 0.85,
        "disk_usage": 0.9,
        "error_rate": 0.05,
        "response_time": 2.0
    ]
}

/// Health check result
/// 健康检查结果
struct HealthCheckResult {
    let checkId: String
    let startTime: Date
    let endTime: Date
    let healthChecks: [HealthCheck]
    let overallScore: Int
    let overallStatus: OverallHealthStatus
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var summary: String {
        "健康检查完成 - 总分: \(overallScore)/100, 状态: \(overallStatus.displayName)"
    }
}

/// Health trend analysis
/// 健康趋势分析
struct HealthTrend {
    let component: String
    let metric: String
    let direction: TrendDirection
    let changePercent: Double
    let significance: TrendSignificance
    
    var description: String {
        let directionText = direction == .increasing ? "上升" : direction == .decreasing ? "下降" : "稳定"
        return "\(component) \(metric) \(directionText) \(String(format: "%.1f", changePercent))%"
    }
}

enum TrendDirection: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

enum TrendSignificance: String, CaseIterable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
}

/// Comprehensive health report
/// 综合健康报告
struct HealthReport {
    let id: String
    let generatedAt: Date
    let generatedBy: String
    let overallHealthScore: Int
    let healthStatus: OverallHealthStatus
    let systemMetrics: SystemMetrics
    let healthChecks: [HealthCheck]
    let activeAlerts: [HealthAlert]
    let trends: [HealthTrend]
    let recommendations: [String]
    let reportPeriod: ReportPeriod
}

enum ReportPeriod: String, CaseIterable {
    case lastHour = "last_hour"
    case last24Hours = "last_24_hours"
    case lastWeek = "last_week"
    case lastMonth = "last_month"
    
    var displayName: String {
        switch self {
        case .lastHour: return "过去1小时"
        case .last24Hours: return "过去24小时"
        case .lastWeek: return "过去一周"
        case .lastMonth: return "过去一月"
        }
    }
}

// MARK: - Health Checker Protocol (健康检查器协议)

protocol HealthChecker {
    var name: String { get }
    func performHealthCheck() async throws -> HealthCheck
}

// MARK: - Metrics Collector Protocol (指标收集器协议)

protocol MetricsCollector {
    var name: String { get }
    func collectMetrics() async throws -> SystemMetrics
}

// MARK: - Performance Monitor Protocol (性能监控器协议)

protocol PerformanceMonitor {
    var name: String { get }
    func collectMetrics() async throws -> [PerformanceMetric]
}

// MARK: - Concrete Health Checkers (具体健康检查器)

struct DatabaseHealthChecker: HealthChecker {
    let name = "Database"
    let repositoryFactory: RepositoryFactory
    
    func performHealthCheck() async throws -> HealthCheck {
        do {
            let start = Date()
            _ = try await repositoryFactory.userRepository.fetchUsers()
            let responseTime = Date().timeIntervalSince(start)
            
            let status: HealthStatus
            let message: String
            
            if responseTime > 5.0 {
                status = .critical
                message = "数据库响应时间过长: \(String(format: "%.2f", responseTime))秒"
            } else if responseTime > 2.0 {
                status = .warning
                message = "数据库响应时间偏慢: \(String(format: "%.2f", responseTime))秒"
            } else {
                status = .healthy
                message = "数据库连接正常"
            }
            
            return HealthCheck(
                component: name,
                status: status,
                message: message,
                details: ["response_time": "\(responseTime)"],
                checkedAt: Date()
            )
        } catch {
            return HealthCheck(
                component: name,
                status: .failing,
                message: "数据库连接失败: \(error.localizedDescription)",
                details: ["error": error.localizedDescription],
                checkedAt: Date()
            )
        }
    }
}

struct ServiceHealthChecker: HealthChecker {
    let name = "Services"
    let repositoryFactory: RepositoryFactory
    
    func performHealthCheck() async throws -> HealthCheck {
        var failedServices: [String] = []
        let services = ["User", "Batch", "Machine", "Color"]
        
        for service in services {
            // Simulate service health check
            let isHealthy = Bool.random() ? true : Double.random(in: 0...1) > 0.1 // 90% success rate
            if !isHealthy {
                failedServices.append(service)
            }
        }
        
        let status: HealthStatus
        let message: String
        
        if failedServices.count >= 2 {
            status = .failing
            message = "多个服务不可用: \(failedServices.joined(separator: ", "))"
        } else if !failedServices.isEmpty {
            status = .critical
            message = "服务不可用: \(failedServices.joined(separator: ", "))"
        } else {
            status = .healthy
            message = "所有服务运行正常"
        }
        
        return HealthCheck(
            component: name,
            status: status,
            message: message,
            details: ["failed_services": failedServices.joined(separator: ",")],
            checkedAt: Date()
        )
    }
}

struct MemoryHealthChecker: HealthChecker {
    let name = "Memory"
    
    func performHealthCheck() async throws -> HealthCheck {
        let memoryUsage = getMemoryUsage()
        
        let status: HealthStatus
        let message: String
        
        if memoryUsage > 0.95 {
            status = .critical
            message = "内存使用率危险: \(Int(memoryUsage * 100))%"
        } else if memoryUsage > 0.85 {
            status = .warning
            message = "内存使用率偏高: \(Int(memoryUsage * 100))%"
        } else {
            status = .healthy
            message = "内存使用正常: \(Int(memoryUsage * 100))%"
        }
        
        return HealthCheck(
            component: name,
            status: status,
            message: message,
            details: ["memory_usage": "\(memoryUsage)"],
            checkedAt: Date()
        )
    }
    
    private func getMemoryUsage() -> Double {
        // Simplified memory usage calculation
        return Double.random(in: 0.3...0.95)
    }
}

struct StorageHealthChecker: HealthChecker {
    let name = "Storage"
    
    func performHealthCheck() async throws -> HealthCheck {
        let diskUsage = getDiskUsage()
        
        let status: HealthStatus
        let message: String
        
        if diskUsage > 0.95 {
            status = .critical
            message = "磁盘空间不足: \(Int(diskUsage * 100))%"
        } else if diskUsage > 0.85 {
            status = .warning
            message = "磁盘空间紧张: \(Int(diskUsage * 100))%"
        } else {
            status = .healthy
            message = "存储空间充足: \(Int(diskUsage * 100))%"
        }
        
        return HealthCheck(
            component: name,
            status: status,
            message: message,
            details: ["disk_usage": "\(diskUsage)"],
            checkedAt: Date()
        )
    }
    
    private func getDiskUsage() -> Double {
        // Simplified disk usage calculation
        return Double.random(in: 0.4...0.9)
    }
}

struct NetworkHealthChecker: HealthChecker {
    let name = "Network"
    
    func performHealthCheck() async throws -> HealthCheck {
        // Simulate network connectivity check
        let latency = Double.random(in: 10...200) // ms
        let isConnected = latency < 150
        
        let status: HealthStatus
        let message: String
        
        if !isConnected {
            status = .failing
            message = "网络连接失败"
        } else if latency > 100 {
            status = .warning
            message = "网络延迟较高: \(Int(latency))ms"
        } else {
            status = .healthy
            message = "网络连接正常: \(Int(latency))ms"
        }
        
        return HealthCheck(
            component: name,
            status: status,
            message: message,
            details: ["latency": "\(latency)", "connected": "\(isConnected)"],
            checkedAt: Date()
        )
    }
}

struct SecurityHealthChecker: HealthChecker {
    let name = "Security"
    
    func performHealthCheck() async throws -> HealthCheck {
        // Simulate security check
        let hasVulnerabilities = Double.random(in: 0...1) < 0.1 // 10% chance
        let encryptionEnabled = true
        let certificateValid = true
        
        let status: HealthStatus
        let message: String
        
        if hasVulnerabilities {
            status = .critical
            message = "检测到安全漏洞"
        } else if !encryptionEnabled || !certificateValid {
            status = .warning
            message = "安全配置需要注意"
        } else {
            status = .healthy
            message = "安全状态良好"
        }
        
        return HealthCheck(
            component: name,
            status: status,
            message: message,
            details: [
                "vulnerabilities": "\(hasVulnerabilities)",
                "encryption": "\(encryptionEnabled)",
                "certificate": "\(certificateValid)"
            ],
            checkedAt: Date()
        )
    }
}

struct ConfigurationHealthChecker: HealthChecker {
    let name = "Configuration"
    
    func performHealthCheck() async throws -> HealthCheck {
        // Simulate configuration validation
        let hasErrors = Double.random(in: 0...1) < 0.05 // 5% chance
        let isOptimized = Double.random(in: 0...1) > 0.2 // 80% chance
        
        let status: HealthStatus
        let message: String
        
        if hasErrors {
            status = .critical
            message = "配置存在错误"
        } else if !isOptimized {
            status = .warning
            message = "配置可以优化"
        } else {
            status = .healthy
            message = "配置正常"
        }
        
        return HealthCheck(
            component: name,
            status: status,
            message: message,
            details: [
                "has_errors": "\(hasErrors)",
                "is_optimized": "\(isOptimized)"
            ],
            checkedAt: Date()
        )
    }
}

// MARK: - Concrete Metrics Collectors (具体指标收集器)

struct SystemResourceCollector: MetricsCollector {
    let name = "System Resources"
    
    func collectMetrics() async throws -> SystemMetrics {
        var metrics = SystemMetrics()
        
        // Simulate resource collection
        metrics.cpuUsage = Double.random(in: 0.1...0.9)
        metrics.memoryUsage = Double.random(in: 0.3...0.85)
        metrics.diskUsage = Double.random(in: 0.4...0.8)
        metrics.activeConnections = Int.random(in: 5...50)
        
        return metrics
    }
}

struct DatabaseMetricsCollector: MetricsCollector {
    let name = "Database Metrics"
    let repositoryFactory: RepositoryFactory
    
    func collectMetrics() async throws -> SystemMetrics {
        var metrics = SystemMetrics()
        
        // Simulate database metrics collection
        metrics.databaseConnections = Int.random(in: 2...20)
        metrics.responseTime = Double.random(in: 0.1...2.0)
        
        return metrics
    }
}

struct UserActivityCollector: MetricsCollector {
    let name = "User Activity"
    let repositoryFactory: RepositoryFactory
    
    func collectMetrics() async throws -> SystemMetrics {
        var metrics = SystemMetrics()
        
        // Simulate user activity collection
        metrics.activeUsers = Int.random(in: 0...25)
        metrics.throughput = Double.random(in: 10...100)
        
        return metrics
    }
}

struct ErrorMetricsCollector: MetricsCollector {
    let name = "Error Metrics"
    let errorHandlingService: UnifiedErrorHandlingService
    
    func collectMetrics() async throws -> SystemMetrics {
        var metrics = SystemMetrics()
        
        // Simulate error metrics collection
        metrics.errorRate = Double.random(in: 0.0...0.1)
        
        return metrics
    }
}

struct SecurityMetricsCollector: MetricsCollector {
    let name = "Security Metrics"
    
    func collectMetrics() async throws -> SystemMetrics {
        var metrics = SystemMetrics()
        
        // Security metrics would be collected here
        // This is a placeholder implementation
        
        return metrics
    }
}

// MARK: - Concrete Performance Monitors (具体性能监控器)

struct ResponseTimeMonitor: PerformanceMonitor {
    let name = "Response Time"
    
    func collectMetrics() async throws -> [PerformanceMetric] {
        return [
            PerformanceMetric(
                name: "API Response Time",
                category: .responseTime,
                value: Double.random(in: 0.1...2.0),
                unit: "seconds",
                tags: ["endpoint": "api"]
            ),
            PerformanceMetric(
                name: "Database Response Time",
                category: .responseTime,
                value: Double.random(in: 0.05...1.0),
                unit: "seconds",
                tags: ["component": "database"]
            )
        ]
    }
}

struct ThroughputMonitor: PerformanceMonitor {
    let name = "Throughput"
    
    func collectMetrics() async throws -> [PerformanceMetric] {
        return [
            PerformanceMetric(
                name: "Requests per Second",
                category: .throughput,
                value: Double.random(in: 10...100),
                unit: "requests/sec"
            ),
            PerformanceMetric(
                name: "Transactions per Second",
                category: .throughput,
                value: Double.random(in: 5...50),
                unit: "transactions/sec"
            )
        ]
    }
}

struct ResourceUtilizationMonitor: PerformanceMonitor {
    let name = "Resource Utilization"
    
    func collectMetrics() async throws -> [PerformanceMetric] {
        return [
            PerformanceMetric(
                name: "CPU Utilization",
                category: .resourceUtilization,
                value: Double.random(in: 0.1...0.9) * 100,
                unit: "percent"
            ),
            PerformanceMetric(
                name: "Memory Utilization",
                category: .resourceUtilization,
                value: Double.random(in: 0.3...0.85) * 100,
                unit: "percent"
            )
        ]
    }
}

struct ConcurrencyMonitor: PerformanceMonitor {
    let name = "Concurrency"
    
    func collectMetrics() async throws -> [PerformanceMetric] {
        return [
            PerformanceMetric(
                name: "Active Threads",
                category: .concurrency,
                value: Double(Int.random(in: 5...50)),
                unit: "threads"
            ),
            PerformanceMetric(
                name: "Queue Length",
                category: .concurrency,
                value: Double(Int.random(in: 0...20)),
                unit: "items"
            )
        ]
    }
}

struct CachePerformanceMonitor: PerformanceMonitor {
    let name = "Cache Performance"
    
    func collectMetrics() async throws -> [PerformanceMetric] {
        return [
            PerformanceMetric(
                name: "Cache Hit Rate",
                category: .cachePerformance,
                value: Double.random(in: 0.7...0.98) * 100,
                unit: "percent"
            ),
            PerformanceMetric(
                name: "Cache Size",
                category: .cachePerformance,
                value: Double.random(in: 100...1000),
                unit: "MB"
            )
        ]
    }
}

// MARK: - Error Types (错误类型)

enum HealthMonitoringError: LocalizedError {
    case insufficientPermissions
    case alertNotFound
    case configurationError
    case monitoringNotStarted
    case healthCheckFailed(String)
    case metricsCollectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足，无法执行健康监控操作"
        case .alertNotFound:
            return "找不到指定的警报"
        case .configurationError:
            return "监控配置错误"
        case .monitoringNotStarted:
            return "健康监控未启动"
        case .healthCheckFailed(let reason):
            return "健康检查失败: \(reason)"
        case .metricsCollectionFailed(let reason):
            return "指标收集失败: \(reason)"
        }
    }
}