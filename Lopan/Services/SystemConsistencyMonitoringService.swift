//
//  SystemConsistencyMonitoringService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - System Health Indicators (系统健康指标)

/// System health check categories
/// 系统健康检查类别
enum SystemHealthCategory: String, CaseIterable {
    case dataIntegrity = "data_integrity"
    case stateConsistency = "state_consistency"
    case performanceOptimization = "performance_optimization"
    case securityCompliance = "security_compliance"
    case operationalEfficiency = "operational_efficiency"
    
    var displayName: String {
        switch self {
        case .dataIntegrity:
            return "数据完整性"
        case .stateConsistency:
            return "状态一致性"
        case .performanceOptimization:
            return "性能优化"
        case .securityCompliance:
            return "安全合规"
        case .operationalEfficiency:
            return "运营效率"
        }
    }
    
    var icon: String {
        switch self {
        case .dataIntegrity:
            return "checkmark.shield"
        case .stateConsistency:
            return "arrow.triangle.2.circlepath"
        case .performanceOptimization:
            return "speedometer"
        case .securityCompliance:
            return "lock.shield"
        case .operationalEfficiency:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

/// System health status levels
/// 系统健康状态等级
enum ConsistencyHealthStatus: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case warning = "warning"
    case critical = "critical"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .warning: return "警告"
        case .critical: return "严重"
        case .unknown: return "未知"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
    
    var score: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .warning: return 0.6
        case .critical: return 0.3
        case .unknown: return 0.0
        }
    }
}

// MARK: - Health Check Result (健康检查结果)

/// Individual health check result
/// 单个健康检查结果
struct SystemHealthCheckResult: Identifiable {
    let id = UUID()
    let category: SystemHealthCategory
    let checkName: String
    let status: ConsistencyHealthStatus
    let message: String
    let details: [String]
    let recommendations: [String]
    let canAutoFix: Bool
    let lastChecked: Date
    let metadata: [String: Any]
    
    init(
        category: SystemHealthCategory,
        checkName: String,
        status: ConsistencyHealthStatus,
        message: String,
        details: [String] = [],
        recommendations: [String] = [],
        canAutoFix: Bool = false,
        metadata: [String: Any] = [:]
    ) {
        self.category = category
        self.checkName = checkName
        self.status = status
        self.message = message
        self.details = details
        self.recommendations = recommendations
        self.canAutoFix = canAutoFix
        self.lastChecked = Date()
        self.metadata = metadata
    }
}

/// Comprehensive system health report
/// 综合系统健康报告
struct SystemHealthReport {
    let timestamp: Date
    let overallStatus: ConsistencyHealthStatus
    let overallScore: Double
    let categoryResults: [SystemHealthCategory: [SystemHealthCheckResult]]
    let criticalIssues: [SystemHealthCheckResult]
    let autoFixableIssues: [SystemHealthCheckResult]
    let systemMetrics: ConsistencySystemMetrics
    
    init(results: [SystemHealthCheckResult], metrics: ConsistencySystemMetrics) {
        self.timestamp = Date()
        self.systemMetrics = metrics
        
        // Group results by category
        self.categoryResults = Dictionary(grouping: results, by: { $0.category })
        
        // Calculate overall score
        let totalScore = results.reduce(0.0) { $0 + $1.status.score }
        let maxScore = Double(results.count)
        self.overallScore = maxScore > 0 ? totalScore / maxScore : 0.0
        
        // Determine overall status
        if overallScore >= 0.9 {
            self.overallStatus = .excellent
        } else if overallScore >= 0.75 {
            self.overallStatus = .good
        } else if overallScore >= 0.5 {
            self.overallStatus = .warning
        } else {
            self.overallStatus = .critical
        }
        
        // Filter critical and auto-fixable issues
        self.criticalIssues = results.filter { $0.status == .critical }
        self.autoFixableIssues = results.filter { $0.canAutoFix && $0.status != .excellent && $0.status != .good }
    }
}

// MARK: - System Metrics (系统指标)

/// Key system performance and operational metrics
/// 关键系统性能和运营指标
struct ConsistencySystemMetrics {
    let totalMachines: Int
    let activeMachines: Int
    let runningMachines: Int
    let totalBatches: Int
    let activeBatches: Int
    let completedBatches: Int
    let averageProcessingTime: TimeInterval
    let cacheHitRate: Double
    let inconsistencyCount: Int
    let lastSyncTime: Date?
    let systemUptime: TimeInterval
    
    var machineUtilization: Double {
        return totalMachines > 0 ? Double(runningMachines) / Double(totalMachines) : 0.0
    }
    
    var batchCompletionRate: Double {
        let processedBatches = activeBatches + completedBatches
        return processedBatches > 0 ? Double(completedBatches) / Double(processedBatches) : 0.0
    }
}

// MARK: - System Consistency Monitoring Service (系统一致性监控服务)

/// Comprehensive system consistency monitoring and automatic repair service
/// 综合系统一致性监控和自动修复服务
@MainActor
class SystemConsistencyMonitoringService: ObservableObject {
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let productionBatchRepository: ProductionBatchRepository
    private let batchMachineCoordinator: StandardBatchMachineCoordinator
    private let synchronizationService: MachineStateSynchronizationService
    private let cacheWarmingService: CacheWarmingService
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var currentHealthReport: SystemHealthReport?
    @Published var isMonitoring = false
    @Published var autoRepairEnabled = true
    @Published var lastMonitoringTime: Date?
    @Published var monitoringHistory: [SystemHealthReport] = []
    
    // MARK: - Configuration
    private let monitoringInterval: TimeInterval = 300 // 5 minutes
    private let maxHistorySize = 24 // Keep 24 reports (2 hours at 5-minute intervals)
    private var monitoringTimer: Timer?
    
    init(
        machineRepository: MachineRepository,
        productionBatchRepository: ProductionBatchRepository,
        batchMachineCoordinator: StandardBatchMachineCoordinator,
        synchronizationService: MachineStateSynchronizationService,
        cacheWarmingService: CacheWarmingService,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.machineRepository = machineRepository
        self.productionBatchRepository = productionBatchRepository
        self.batchMachineCoordinator = batchMachineCoordinator
        self.synchronizationService = synchronizationService
        self.cacheWarmingService = cacheWarmingService
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Service Lifecycle
    
    /// Start comprehensive system monitoring
    /// 启动综合系统监控
    func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSystemHealthCheck()
            }
        }
        
        isMonitoring = true
        
        // Perform initial health check
        Task {
            await performSystemHealthCheck()
        }
        
        Task {
            try? await auditService.logSecurityEvent(
                event: "system_monitoring_started",
                userId: authService.currentUser?.id ?? "system",
                details: ["message": "System consistency monitoring started with \(monitoringInterval)s interval"]
            )
        }
    }
    
    /// Stop system monitoring
    /// 停止系统监控
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        
        Task {
            try? await auditService.logSecurityEvent(
                event: "system_monitoring_stopped",
                userId: authService.currentUser?.id ?? "system",
                details: ["message": "System consistency monitoring stopped"]
            )
        }
    }
    
    // MARK: - Health Checks Implementation
    
    /// Perform comprehensive system health check
    /// 执行综合系统健康检查
    func performSystemHealthCheck() async {
        guard !isMonitoring || monitoringTimer != nil else { return }
        
        do {
            // Collect system metrics
            let metrics = try await collectSystemMetrics()
            
            // Perform all health checks
            var healthResults: [SystemHealthCheckResult] = []
            
            // Data integrity checks
            healthResults.append(contentsOf: await performDataIntegrityChecks())
            
            // State consistency checks
            healthResults.append(contentsOf: await performStateConsistencyChecks())
            
            // Performance optimization checks
            healthResults.append(contentsOf: await performPerformanceChecks(metrics: metrics))
            
            // Security compliance checks
            healthResults.append(contentsOf: await performSecurityChecks())
            
            // Operational efficiency checks
            healthResults.append(contentsOf: await performOperationalChecks(metrics: metrics))
            
            // Generate comprehensive report
            let report = SystemHealthReport(results: healthResults, metrics: metrics)
            currentHealthReport = report
            lastMonitoringTime = Date()
            
            // Add to history (maintain size limit)
            monitoringHistory.append(report)
            if monitoringHistory.count > maxHistorySize {
                monitoringHistory.removeFirst(monitoringHistory.count - maxHistorySize)
            }
            
            // Perform automatic repairs if enabled
            if autoRepairEnabled && !report.autoFixableIssues.isEmpty {
                await performAutomaticRepairs(for: report.autoFixableIssues)
            }
            
            // Log system health status
            try? await auditService.logSecurityEvent(
                event: "system_health_check_completed",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "status": report.overallStatus.displayName,
                    "score": String(format: "%.2f", report.overallScore),
                    "critical_issues": "\(report.criticalIssues.count)",
                    "auto_fixable_issues": "\(report.autoFixableIssues.count)"
                ]
            )
            
        } catch {
            try? await auditService.logSecurityEvent(
                event: "system_health_check_failed",
                userId: authService.currentUser?.id ?? "system",
                details: ["error": "System health check failed: \(error.localizedDescription)"]
            )
        }
    }
    
    /// Collect key system metrics
    /// 收集关键系统指标
    private func collectSystemMetrics() async throws -> ConsistencySystemMetrics {
        let machines = try await machineRepository.fetchAllMachines()
        let allBatches = try await productionBatchRepository.fetchAllBatches()
        let activeBatches = try await productionBatchRepository.fetchActiveBatches()
        let completedBatches = allBatches.filter { $0.status == .completed }
        
        let cacheMetrics = batchMachineCoordinator.getCacheMetrics()
        let inconsistencyCount = synchronizationService.detectedInconsistencies.count
        
        // Calculate average processing time for completed batches
        let averageProcessingTime: TimeInterval = {
            let batchesWithDuration = completedBatches.compactMap { batch -> TimeInterval? in
                guard let start = batch.executionTime, let end = batch.completedAt else { return nil }
                return end.timeIntervalSince(start)
            }
            return batchesWithDuration.isEmpty ? 0 : batchesWithDuration.reduce(0, +) / Double(batchesWithDuration.count)
        }()
        
        return ConsistencySystemMetrics(
            totalMachines: machines.count,
            activeMachines: machines.filter { $0.isActive }.count,
            runningMachines: machines.filter { $0.status == .running && $0.isActive }.count,
            totalBatches: allBatches.count,
            activeBatches: activeBatches.count,
            completedBatches: completedBatches.count,
            averageProcessingTime: averageProcessingTime,
            cacheHitRate: cacheMetrics.hitRate,
            inconsistencyCount: inconsistencyCount,
            lastSyncTime: synchronizationService.lastScanTime,
            systemUptime: ProcessInfo.processInfo.systemUptime
        )
    }
    
    // MARK: - Individual Health Check Categories
    
    /// Perform data integrity checks
    /// 执行数据完整性检查
    private func performDataIntegrityChecks() async -> [SystemHealthCheckResult] {
        var results: [SystemHealthCheckResult] = []
        
        do {
            // Check for orphaned product configs
            let allBatches = try await productionBatchRepository.fetchAllBatches()
            let batchIds = Set(allBatches.map { $0.id })
            
            var orphanedConfigs = 0
            for batch in allBatches {
                for product in batch.products {
                    if !batchIds.contains(product.batchId) {
                        orphanedConfigs += 1
                    }
                }
            }
            
            let orphanedConfigStatus: ConsistencyHealthStatus = {
                if orphanedConfigs == 0 { return .excellent }
                else if orphanedConfigs <= 5 { return .warning }
                else { return .critical }
            }()
            
            results.append(SystemHealthCheckResult(
                category: .dataIntegrity,
                checkName: "产品配置完整性",
                status: orphanedConfigStatus,
                message: orphanedConfigs == 0 ? "所有产品配置正常" : "发现 \(orphanedConfigs) 个孤立的产品配置",
                details: orphanedConfigs > 0 ? ["孤立配置可能影响数据一致性"] : [],
                recommendations: orphanedConfigs > 0 ? ["清理孤立的产品配置", "检查批次删除流程"] : [],
                canAutoFix: orphanedConfigs > 0
            ))
            
            // Check for batch number consistency
            let batchNumbers = allBatches.map { $0.batchNumber }
            let uniqueBatchNumbers = Set(batchNumbers)
            let duplicateCount = batchNumbers.count - uniqueBatchNumbers.count
            
            let duplicateStatus: ConsistencyHealthStatus = duplicateCount == 0 ? .excellent : .critical
            
            results.append(SystemHealthCheckResult(
                category: .dataIntegrity,
                checkName: "批次编号唯一性",
                status: duplicateStatus,
                message: duplicateCount == 0 ? "所有批次编号唯一" : "发现 \(duplicateCount) 个重复的批次编号",
                recommendations: duplicateCount > 0 ? ["修复重复的批次编号", "加强编号生成验证"] : [],
                canAutoFix: false
            ))
            
        } catch {
            results.append(SystemHealthCheckResult(
                category: .dataIntegrity,
                checkName: "数据完整性检查",
                status: .unknown,
                message: "无法执行数据完整性检查: \(error.localizedDescription)"
            ))
        }
        
        return results
    }
    
    /// Perform state consistency checks
    /// 执行状态一致性检查
    private func performStateConsistencyChecks() async -> [SystemHealthCheckResult] {
        var results: [SystemHealthCheckResult] = []
        
        let inconsistencies = synchronizationService.detectedInconsistencies
        let highSeverityCount = inconsistencies.filter { $0.severity == .high }.count
        let mediumSeverityCount = inconsistencies.filter { $0.severity == .medium }.count
        let lowSeverityCount = inconsistencies.filter { $0.severity == .low }.count
        
        let consistencyStatus: ConsistencyHealthStatus = {
            if highSeverityCount > 0 { return .critical }
            else if mediumSeverityCount > 0 { return .warning }
            else if lowSeverityCount > 0 { return .good }
            else { return .excellent }
        }()
        
        results.append(SystemHealthCheckResult(
            category: .stateConsistency,
            checkName: "机台-批次状态一致性",
            status: consistencyStatus,
            message: inconsistencies.isEmpty ? "所有状态一致" : "发现 \(inconsistencies.count) 个状态不一致问题",
            details: [
                "高优先级: \(highSeverityCount)",
                "中优先级: \(mediumSeverityCount)",
                "低优先级: \(lowSeverityCount)"
            ],
            recommendations: inconsistencies.isEmpty ? [] : [
                "运行状态同步修复",
                "检查机台和批次状态更新流程"
            ],
            canAutoFix: inconsistencies.contains { $0.autoFixable }
        ))
        
        return results
    }
    
    /// Perform performance optimization checks
    /// 执行性能优化检查
    private func performPerformanceChecks(metrics: ConsistencySystemMetrics) async -> [SystemHealthCheckResult] {
        var results: [SystemHealthCheckResult] = []
        
        // Cache performance check
        let cacheStatus: ConsistencyHealthStatus = {
            if metrics.cacheHitRate >= 0.9 { return .excellent }
            else if metrics.cacheHitRate >= 0.7 { return .good }
            else if metrics.cacheHitRate >= 0.5 { return .warning }
            else { return .critical }
        }()
        
        results.append(SystemHealthCheckResult(
            category: .performanceOptimization,
            checkName: "缓存性能",
            status: cacheStatus,
            message: "缓存命中率: \(String(format: "%.1f", metrics.cacheHitRate * 100))%",
            recommendations: metrics.cacheHitRate < 0.7 ? [
                "增加缓存预热频率",
                "优化缓存策略",
                "检查缓存大小配置"
            ] : [],
            canAutoFix: metrics.cacheHitRate < 0.7
        ))
        
        // Machine utilization check
        let utilizationStatus: ConsistencyHealthStatus = {
            if metrics.machineUtilization >= 0.8 { return .excellent }
            else if metrics.machineUtilization >= 0.6 { return .good }
            else if metrics.machineUtilization >= 0.4 { return .warning }
            else { return .critical }
        }()
        
        results.append(SystemHealthCheckResult(
            category: .performanceOptimization,
            checkName: "机台利用率",
            status: utilizationStatus,
            message: "机台利用率: \(String(format: "%.1f", metrics.machineUtilization * 100))%",
            details: [
                "运行中机台: \(metrics.runningMachines)/\(metrics.totalMachines)"
            ],
            recommendations: metrics.machineUtilization < 0.6 ? [
                "检查机台状态",
                "优化生产调度",
                "分析机台停机原因"
            ] : []
        ))
        
        return results
    }
    
    /// Perform security compliance checks
    /// 执行安全合规检查
    private func performSecurityChecks() async -> [SystemHealthCheckResult] {
        var results: [SystemHealthCheckResult] = []
        
        // User authentication check
        let authStatus: ConsistencyHealthStatus = authService.currentUser != nil ? .excellent : .critical
        
        results.append(SystemHealthCheckResult(
            category: .securityCompliance,
            checkName: "用户认证状态",
            status: authStatus,
            message: authService.currentUser != nil ? "用户已认证" : "用户未认证",
            recommendations: authService.currentUser == nil ? ["请重新登录"] : []
        ))
        
        return results
    }
    
    /// Perform operational efficiency checks
    /// 执行运营效率检查
    private func performOperationalChecks(metrics: ConsistencySystemMetrics) async -> [SystemHealthCheckResult] {
        var results: [SystemHealthCheckResult] = []
        
        // Batch completion rate check
        let completionStatus: ConsistencyHealthStatus = {
            if metrics.batchCompletionRate >= 0.9 { return .excellent }
            else if metrics.batchCompletionRate >= 0.75 { return .good }
            else if metrics.batchCompletionRate >= 0.5 { return .warning }
            else { return .critical }
        }()
        
        results.append(SystemHealthCheckResult(
            category: .operationalEfficiency,
            checkName: "批次完成率",
            status: completionStatus,
            message: "批次完成率: \(String(format: "%.1f", metrics.batchCompletionRate * 100))%",
            details: [
                "已完成: \(metrics.completedBatches)",
                "执行中: \(metrics.activeBatches)"
            ],
            recommendations: metrics.batchCompletionRate < 0.75 ? [
                "检查批次执行流程",
                "分析延迟原因",
                "优化批次管理"
            ] : []
        ))
        
        return results
    }
    
    // MARK: - Automatic Repair
    
    /// Perform automatic repairs for identified issues
    /// 对识别的问题执行自动修复
    private func performAutomaticRepairs(for issues: [SystemHealthCheckResult]) async {
        var successCount = 0
        var failureCount = 0
        
        for issue in issues {
            do {
                let repaired = try await performAutomaticRepair(for: issue)
                if repaired {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            } catch {
                failureCount += 1
                try? await auditService.logSecurityEvent(
                    event: "automatic_repair_failed",
                    userId: authService.currentUser?.id ?? "system",
                    details: ["error": "Failed to auto-repair \(issue.checkName): \(error.localizedDescription)"]
                )
            }
        }
        
        try? await auditService.logSecurityEvent(
            event: "automatic_repairs_completed",
            userId: authService.currentUser?.id ?? "system",
            details: ["success_count": "\(successCount)", "failure_count": "\(failureCount)"]
        )
    }
    
    /// Perform automatic repair for a specific issue
    /// 对特定问题执行自动修复
    private func performAutomaticRepair(for issue: SystemHealthCheckResult) async throws -> Bool {
        switch issue.category {
        case .stateConsistency:
            await synchronizationService.performAutomaticSynchronization()
            return true
        case .performanceOptimization:
            if issue.checkName.contains("缓存") {
                await cacheWarmingService.performCacheWarming()
                return true
            }
        case .dataIntegrity:
            if issue.checkName.contains("产品配置") {
                // Could implement orphaned config cleanup here
                return false // Not implemented yet
            }
        default:
            return false
        }
        
        return false
    }
    
    // MARK: - Manual Operations
    
    /// Manually trigger health check
    /// 手动触发健康检查
    func triggerManualHealthCheck() async {
        await performSystemHealthCheck()
    }
    
    /// Toggle automatic repair functionality
    /// 切换自动修复功能
    func toggleAutoRepair() {
        autoRepairEnabled.toggle()
        
        Task {
            try? await auditService.logSecurityEvent(
                event: "auto_repair_toggled",
                userId: authService.currentUser?.id ?? "system",
                details: ["status": "Auto repair \(autoRepairEnabled ? "enabled" : "disabled")"]
            )
        }
    }
    
    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
    }
}