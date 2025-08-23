//
//  ProductionAnalyticsEngine.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Analytics Time Periods (分析时间周期)

/// Time periods for analytics calculations
/// 分析计算的时间周期
enum AnalyticsTimePeriod: String, CaseIterable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case thisQuarter = "this_quarter"
    case lastQuarter = "last_quarter"
    case thisYear = "this_year"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .today: return "今日"
        case .yesterday: return "昨日"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .thisQuarter: return "本季度"
        case .lastQuarter: return "上季度"
        case .thisYear: return "本年"
        case .custom: return "自定义"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return (calendar.startOfDay(for: yesterday), calendar.startOfDay(for: now))
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            let startOfLastWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start ?? now
            let endOfLastWeek = calendar.date(byAdding: .day, value: 7, to: startOfLastWeek) ?? now
            return (startOfLastWeek, endOfLastWeek)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
            let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
            return (startOfLastMonth, endOfLastMonth)
        case .thisQuarter:
            let quarter = calendar.component(.quarter, from: now)
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let startOfQuarter = calendar.date(byAdding: .month, value: (quarter - 1) * 3, to: startOfYear) ?? now
            return (startOfQuarter, now)
        case .lastQuarter:
            let quarter = calendar.component(.quarter, from: now)
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let startOfLastQuarter = calendar.date(byAdding: .month, value: (quarter - 2) * 3, to: startOfYear) ?? now
            let endOfLastQuarter = calendar.date(byAdding: .month, value: 3, to: startOfLastQuarter) ?? now
            return (startOfLastQuarter, endOfLastQuarter)
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        case .custom:
            return (now, now) // Will be overridden with custom dates
        }
    }
}

// MARK: - Analytics Metrics (分析指标)

/// Key production metrics for analytics
/// 分析的关键生产指标
struct ProductionMetrics {
    let period: AnalyticsTimePeriod
    let startDate: Date
    let endDate: Date
    
    // Batch metrics
    let totalBatches: Int
    let completedBatches: Int
    let activeBatches: Int
    let rejectedBatches: Int
    let averageBatchDuration: TimeInterval
    let batchCompletionRate: Double
    
    // Machine metrics
    let totalMachines: Int
    let activeMachines: Int
    let machineUtilizationRate: Double
    let averageMachineUptime: TimeInterval
    let machineEfficiencyScore: Double
    
    // Production metrics
    let totalProductionHours: TimeInterval
    let plannedProductionHours: TimeInterval
    let actualProductionHours: TimeInterval
    let productivityIndex: Double
    let qualityScore: Double
    
    // Shift metrics
    let morningShiftBatches: Int
    let eveningShiftBatches: Int
    let shiftEfficiencyComparison: Double
    
    // Error metrics
    let systemErrors: Int
    let userErrors: Int
    let criticalIssues: Int
    let averageResolutionTime: TimeInterval
    
    // Trend data
    let trendData: [AnalyticsTrendPoint]
    
    init(
        period: AnalyticsTimePeriod,
        startDate: Date,
        endDate: Date,
        totalBatches: Int = 0,
        completedBatches: Int = 0,
        activeBatches: Int = 0,
        rejectedBatches: Int = 0,
        averageBatchDuration: TimeInterval = 0,
        totalMachines: Int = 0,
        activeMachines: Int = 0,
        machineUtilizationRate: Double = 0,
        averageMachineUptime: TimeInterval = 0,
        machineEfficiencyScore: Double = 0,
        totalProductionHours: TimeInterval = 0,
        plannedProductionHours: TimeInterval = 0,
        actualProductionHours: TimeInterval = 0,
        productivityIndex: Double = 0,
        qualityScore: Double = 0,
        morningShiftBatches: Int = 0,
        eveningShiftBatches: Int = 0,
        systemErrors: Int = 0,
        userErrors: Int = 0,
        criticalIssues: Int = 0,
        averageResolutionTime: TimeInterval = 0,
        trendData: [AnalyticsTrendPoint] = []
    ) {
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.totalBatches = totalBatches
        self.completedBatches = completedBatches
        self.activeBatches = activeBatches
        self.rejectedBatches = rejectedBatches
        self.averageBatchDuration = averageBatchDuration
        self.batchCompletionRate = totalBatches > 0 ? Double(completedBatches) / Double(totalBatches) : 0
        self.totalMachines = totalMachines
        self.activeMachines = activeMachines
        self.machineUtilizationRate = machineUtilizationRate
        self.averageMachineUptime = averageMachineUptime
        self.machineEfficiencyScore = machineEfficiencyScore
        self.totalProductionHours = totalProductionHours
        self.plannedProductionHours = plannedProductionHours
        self.actualProductionHours = actualProductionHours
        self.productivityIndex = productivityIndex
        self.qualityScore = qualityScore
        self.morningShiftBatches = morningShiftBatches
        self.eveningShiftBatches = eveningShiftBatches
        self.shiftEfficiencyComparison = morningShiftBatches + eveningShiftBatches > 0 ? 
            Double(morningShiftBatches) / Double(morningShiftBatches + eveningShiftBatches) : 0.5
        self.systemErrors = systemErrors
        self.userErrors = userErrors
        self.criticalIssues = criticalIssues
        self.averageResolutionTime = averageResolutionTime
        self.trendData = trendData
    }
}

/// Single point in analytics trend data
/// 分析趋势数据中的单个点
struct AnalyticsTrendPoint {
    let date: Date
    let value: Double
    let label: String
    let category: String
    
    init(date: Date, value: Double, label: String = "", category: String = "default") {
        self.date = date
        self.value = value
        self.label = label
        self.category = category
    }
}

// MARK: - Analytics Comparison (分析比较)

/// Comparison between two time periods
/// 两个时间周期之间的比较
struct AnalyticsComparison {
    let currentPeriod: ProductionMetrics
    let comparisonPeriod: ProductionMetrics
    let improvements: [String]
    let concerns: [String]
    let recommendations: [String]
    
    var overallTrend: AnalyticsTrend {
        let currentScore = calculateOverallScore(for: currentPeriod)
        let comparisonScore = calculateOverallScore(for: comparisonPeriod)
        
        if currentScore > comparisonScore * 1.05 {
            return .improving
        } else if currentScore < comparisonScore * 0.95 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateOverallScore(for metrics: ProductionMetrics) -> Double {
        return (metrics.batchCompletionRate * 0.3 +
                metrics.machineUtilizationRate * 0.25 +
                metrics.productivityIndex * 0.25 +
                metrics.qualityScore * 0.2)
    }
}

enum AnalyticsTrend {
    case improving
    case declining
    case stable
    
    var displayName: String {
        switch self {
        case .improving: return "改善"
        case .declining: return "下降"
        case .stable: return "稳定"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
}

// MARK: - Production Analytics Engine (生产分析引擎)

/// Advanced production analytics and reporting engine
/// 高级生产分析和报告引擎
@MainActor
class ProductionAnalyticsEngine: ObservableObject {
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let productionBatchRepository: ProductionBatchRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var currentMetrics: ProductionMetrics?
    @Published var isCalculating = false
    @Published var lastCalculationTime: Date?
    @Published var cachedMetrics: [String: ProductionMetrics] = [:]
    @Published var realtimeData: [AnalyticsTrendPoint] = []
    
    // MARK: - Configuration
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let maxTrendPoints = 100
    private let realtimeUpdateInterval: TimeInterval = 60 // 1 minute
    
    private var realtimeTimer: Timer?
    
    init(
        machineRepository: MachineRepository,
        productionBatchRepository: ProductionBatchRepository,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.machineRepository = machineRepository
        self.productionBatchRepository = productionBatchRepository
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Core Analytics Methods
    
    /// Calculate production metrics for specified time period
    /// 计算指定时间段的生产指标
    func calculateMetrics(for period: AnalyticsTimePeriod, customStart: Date? = nil, customEnd: Date? = nil) async -> ProductionMetrics {
        isCalculating = true
        
        let (startDate, endDate) = if period == .custom, let customStart = customStart, let customEnd = customEnd {
            (customStart, customEnd)
        } else {
            period.dateRange
        }
        
        // Check cache first
        let cacheKey = "\(period.rawValue)_\(startDate.timeIntervalSince1970)_\(endDate.timeIntervalSince1970)"
        if let cachedMetrics = cachedMetrics[cacheKey],
           Date().timeIntervalSince(lastCalculationTime ?? Date.distantPast) < cacheExpirationTime {
            isCalculating = false
            return cachedMetrics
        }
        
        do {
            // Fetch raw data
            let allBatches = try await productionBatchRepository.fetchBatches(from: startDate, to: endDate, shift: nil)
            let allMachines = try await machineRepository.fetchAllMachines()
            
            // Calculate batch metrics
            let batchMetrics = calculateBatchMetrics(from: allBatches, in: startDate...endDate)
            
            // Calculate machine metrics
            let machineMetrics = calculateMachineMetrics(from: allMachines, batches: allBatches, in: startDate...endDate)
            
            // Calculate production metrics
            let productionMetrics = calculateProductionMetrics(from: allBatches, machines: allMachines, in: startDate...endDate)
            
            // Calculate shift metrics
            let shiftMetrics = calculateShiftMetrics(from: allBatches)
            
            // Calculate error metrics (would need audit data)
            let errorMetrics = await calculateErrorMetrics(in: startDate...endDate)
            
            // Generate trend data
            let trendData = await generateTrendData(for: period, startDate: startDate, endDate: endDate)
            
            // Combine all metrics
            let metrics = ProductionMetrics(
                period: period,
                startDate: startDate,
                endDate: endDate,
                totalBatches: batchMetrics.total,
                completedBatches: batchMetrics.completed,
                activeBatches: batchMetrics.active,
                rejectedBatches: batchMetrics.rejected,
                averageBatchDuration: batchMetrics.averageDuration,
                totalMachines: machineMetrics.total,
                activeMachines: machineMetrics.active,
                machineUtilizationRate: machineMetrics.utilizationRate,
                averageMachineUptime: machineMetrics.averageUptime,
                machineEfficiencyScore: machineMetrics.efficiencyScore,
                totalProductionHours: productionMetrics.totalHours,
                plannedProductionHours: productionMetrics.plannedHours,
                actualProductionHours: productionMetrics.actualHours,
                productivityIndex: productionMetrics.productivityIndex,
                qualityScore: productionMetrics.qualityScore,
                morningShiftBatches: shiftMetrics.morning,
                eveningShiftBatches: shiftMetrics.evening,
                systemErrors: errorMetrics.systemErrors,
                userErrors: errorMetrics.userErrors,
                criticalIssues: errorMetrics.criticalIssues,
                averageResolutionTime: errorMetrics.averageResolutionTime,
                trendData: trendData
            )
            
            // Cache results
            cachedMetrics[cacheKey] = metrics
            currentMetrics = metrics
            lastCalculationTime = Date()
            
            // Log analytics calculation
            try? await auditService.logSecurityEvent(
                event: "analytics_calculated",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "period": period.displayName,
                    "batch_count": "\(batchMetrics.total)",
                    "machine_count": "\(machineMetrics.total)"
                ]
            )
            
            isCalculating = false
            return metrics
            
        } catch {
            try? await auditService.logSecurityEvent(
                event: "analytics_calculation_failed",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "error": error.localizedDescription,
                    "operation": "calculate_analytics"
                ]
            )
            
            isCalculating = false
            return ProductionMetrics(period: period, startDate: startDate, endDate: endDate)
        }
    }
    
    /// Compare metrics between two time periods
    /// 比较两个时间段之间的指标
    func compareMetrics(current: AnalyticsTimePeriod, comparison: AnalyticsTimePeriod) async -> AnalyticsComparison {
        let currentMetrics = await calculateMetrics(for: current)
        let comparisonMetrics = await calculateMetrics(for: comparison)
        
        var improvements: [String] = []
        var concerns: [String] = []
        var recommendations: [String] = []
        
        // Analyze batch completion rate
        if currentMetrics.batchCompletionRate > comparisonMetrics.batchCompletionRate {
            improvements.append("批次完成率提升 \(String(format: "%.1f", (currentMetrics.batchCompletionRate - comparisonMetrics.batchCompletionRate) * 100))%")
        } else if currentMetrics.batchCompletionRate < comparisonMetrics.batchCompletionRate {
            concerns.append("批次完成率下降 \(String(format: "%.1f", (comparisonMetrics.batchCompletionRate - currentMetrics.batchCompletionRate) * 100))%")
            recommendations.append("分析批次延迟原因，优化生产流程")
        }
        
        // Analyze machine utilization
        if currentMetrics.machineUtilizationRate > comparisonMetrics.machineUtilizationRate {
            improvements.append("机台利用率提升 \(String(format: "%.1f", (currentMetrics.machineUtilizationRate - comparisonMetrics.machineUtilizationRate) * 100))%")
        } else if currentMetrics.machineUtilizationRate < comparisonMetrics.machineUtilizationRate {
            concerns.append("机台利用率下降 \(String(format: "%.1f", (comparisonMetrics.machineUtilizationRate - currentMetrics.machineUtilizationRate) * 100))%")
            recommendations.append("检查机台维护计划，优化排产安排")
        }
        
        // Analyze productivity
        if currentMetrics.productivityIndex > comparisonMetrics.productivityIndex {
            improvements.append("生产效率提升 \(String(format: "%.1f", (currentMetrics.productivityIndex - comparisonMetrics.productivityIndex) * 100))%")
        } else if currentMetrics.productivityIndex < comparisonMetrics.productivityIndex {
            concerns.append("生产效率下降 \(String(format: "%.1f", (comparisonMetrics.productivityIndex - currentMetrics.productivityIndex) * 100))%")
            recommendations.append("分析生产瓶颈，实施效率改进措施")
        }
        
        // Analyze errors
        if currentMetrics.systemErrors < comparisonMetrics.systemErrors {
            improvements.append("系统错误减少 \(comparisonMetrics.systemErrors - currentMetrics.systemErrors) 个")
        } else if currentMetrics.systemErrors > comparisonMetrics.systemErrors {
            concerns.append("系统错误增加 \(currentMetrics.systemErrors - comparisonMetrics.systemErrors) 个")
            recommendations.append("加强系统监控，提升系统稳定性")
        }
        
        return AnalyticsComparison(
            currentPeriod: currentMetrics,
            comparisonPeriod: comparisonMetrics,
            improvements: improvements,
            concerns: concerns,
            recommendations: recommendations
        )
    }
    
    // MARK: - Real-time Analytics
    
    /// Start real-time analytics data collection
    /// 开始实时分析数据收集
    func startRealtimeAnalytics() {
        guard realtimeTimer == nil else { return }
        
        realtimeTimer = Timer.scheduledTimer(withTimeInterval: realtimeUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateRealtimeData()
            }
        }
        
        // Initial update
        Task {
            await updateRealtimeData()
        }
    }
    
    /// Stop real-time analytics data collection
    /// 停止实时分析数据收集
    func stopRealtimeAnalytics() {
        realtimeTimer?.invalidate()
        realtimeTimer = nil
    }
    
    /// Update real-time analytics data
    /// 更新实时分析数据
    private func updateRealtimeData() async {
        do {
            let now = Date()
            let activeBatches = try await productionBatchRepository.fetchActiveBatches()
            let activeMachines = try await machineRepository.fetchAllMachines().filter { $0.isActive }
            
            // Calculate real-time metrics
            let batchCount = Double(activeBatches.count)
            let machineUtilization = activeMachines.isEmpty ? 0.0 : 
                Double(activeMachines.filter { $0.status == .running }.count) / Double(activeMachines.count)
            
            // Add trend points
            let batchTrendPoint = AnalyticsTrendPoint(
                date: now,
                value: batchCount,
                label: "Active Batches",
                category: "batches"
            )
            
            let machineUtilizationPoint = AnalyticsTrendPoint(
                date: now,
                value: machineUtilization * 100,
                label: "Machine Utilization %",
                category: "machines"
            )
            
            // Update real-time data
            realtimeData.append(contentsOf: [batchTrendPoint, machineUtilizationPoint])
            
            // Maintain max trend points
            if realtimeData.count > maxTrendPoints {
                realtimeData.removeFirst(realtimeData.count - maxTrendPoints)
            }
            
        } catch {
            try? await auditService.logSecurityEvent(
                event: "realtime_analytics_update_failed",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "error": error.localizedDescription,
                    "operation": "update_realtime_analytics"
                ]
            )
        }
    }
    
    // MARK: - Helper Calculation Methods
    
    /// Calculate batch-related metrics
    /// 计算批次相关指标
    private func calculateBatchMetrics(from batches: [ProductionBatch], in dateRange: ClosedRange<Date>) -> (total: Int, completed: Int, active: Int, rejected: Int, averageDuration: TimeInterval) {
        let filteredBatches = batches.filter { batch in
            dateRange.contains(batch.submittedAt)
        }
        
        let total = filteredBatches.count
        let completed = filteredBatches.filter { $0.status == .completed }.count
        let active = filteredBatches.filter { $0.status == .active }.count
        let rejected = filteredBatches.filter { $0.status == .rejected }.count
        
        let completedBatches = filteredBatches.filter { $0.status == .completed && $0.executionTime != nil && $0.completedAt != nil }
        let averageDuration = completedBatches.isEmpty ? 0 : 
            completedBatches.reduce(0) { total, batch in
                if let executionTime = batch.executionTime, let completedAt = batch.completedAt {
                    return total + completedAt.timeIntervalSince(executionTime)
                }
                return total
            } / Double(completedBatches.count)
        
        return (total, completed, active, rejected, averageDuration)
    }
    
    /// Calculate machine-related metrics
    /// 计算机台相关指标
    private func calculateMachineMetrics(from machines: [WorkshopMachine], batches: [ProductionBatch], in dateRange: ClosedRange<Date>) -> (total: Int, active: Int, utilizationRate: Double, averageUptime: TimeInterval, efficiencyScore: Double) {
        let total = machines.count
        let active = machines.filter { $0.isActive }.count
        let utilizationRate = total > 0 ? Double(machines.filter { $0.status == .running }.count) / Double(total) : 0
        
        // Calculate efficiency based on batch completion rates per machine
        let machineEfficiencies = machines.map { machine in
            let machineBatches = batches.filter { $0.machineId == machine.id }
            let completedBatches = machineBatches.filter { $0.status == .completed }
            return machineBatches.isEmpty ? 0.0 : Double(completedBatches.count) / Double(machineBatches.count)
        }
        
        let efficiencyScore = machineEfficiencies.isEmpty ? 0 : machineEfficiencies.reduce(0, +) / Double(machineEfficiencies.count)
        
        // Simplified uptime calculation (would need more detailed monitoring data)
        let averageUptime: TimeInterval = 8 * 3600 * utilizationRate // Assuming 8-hour shifts
        
        return (total, active, utilizationRate, averageUptime, efficiencyScore)
    }
    
    /// Calculate production-related metrics
    /// 计算生产相关指标
    private func calculateProductionMetrics(from batches: [ProductionBatch], machines: [WorkshopMachine], in dateRange: ClosedRange<Date>) -> (totalHours: TimeInterval, plannedHours: TimeInterval, actualHours: TimeInterval, productivityIndex: Double, qualityScore: Double) {
        let timeSpan = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let plannedHours = timeSpan // Simplified: assume all time is planned production time
        
        let completedBatches = batches.filter { $0.status == .completed && $0.executionTime != nil && $0.completedAt != nil }
        let actualHours = completedBatches.reduce(0) { total, batch in
            if let executionTime = batch.executionTime, let completedAt = batch.completedAt {
                return total + completedAt.timeIntervalSince(executionTime)
            }
            return total
        }
        
        let totalHours = actualHours
        let productivityIndex = plannedHours > 0 ? actualHours / plannedHours : 0
        
        // Quality score based on rejection rate
        let totalBatches = batches.count
        let rejectedBatches = batches.filter { $0.status == .rejected }.count
        let qualityScore = totalBatches > 0 ? Double(totalBatches - rejectedBatches) / Double(totalBatches) : 1.0
        
        return (totalHours, plannedHours, actualHours, productivityIndex, qualityScore)
    }
    
    /// Calculate shift-related metrics
    /// 计算班次相关指标
    private func calculateShiftMetrics(from batches: [ProductionBatch]) -> (morning: Int, evening: Int) {
        let morningBatches = batches.filter { $0.shift == .morning }.count
        let eveningBatches = batches.filter { $0.shift == .evening }.count
        
        return (morningBatches, eveningBatches)
    }
    
    /// Calculate error-related metrics
    /// 计算错误相关指标
    private func calculateErrorMetrics(in dateRange: ClosedRange<Date>) async -> (systemErrors: Int, userErrors: Int, criticalIssues: Int, averageResolutionTime: TimeInterval) {
        // This would typically fetch from audit logs
        // For now, return placeholder values
        return (0, 0, 0, 0)
    }
    
    /// Generate trend data for visualization
    /// 生成用于可视化的趋势数据
    private func generateTrendData(for period: AnalyticsTimePeriod, startDate: Date, endDate: Date) async -> [AnalyticsTrendPoint] {
        var trendPoints: [AnalyticsTrendPoint] = []
        let calendar = Calendar.current
        
        // Generate daily trend points for the period
        var currentDate = startDate
        while currentDate <= endDate {
            do {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                let dayBatches = try await productionBatchRepository.fetchBatches(from: currentDate, to: dayEnd, shift: nil)
                
                let completedCount = dayBatches.filter { $0.status == .completed }.count
                let trendPoint = AnalyticsTrendPoint(
                    date: currentDate,
                    value: Double(completedCount),
                    label: "Completed Batches",
                    category: "daily_completion"
                )
                
                trendPoints.append(trendPoint)
                currentDate = dayEnd
            } catch {
                // Skip failed days
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
            }
        }
        
        return trendPoints
    }
    
    // MARK: - Cache Management
    
    /// Clear analytics cache
    /// 清除分析缓存
    func clearCache() {
        cachedMetrics.removeAll()
        lastCalculationTime = nil
        
        Task {
            try? await auditService.logSecurityEvent(
                event: "analytics_cache_cleared",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "operation": "clear_analytics_cache",
                    "trigger": "manual"
                ]
            )
        }
    }
    
    /// Get cache statistics
    /// 获取缓存统计信息
    func getCacheStatistics() -> (entries: Int, oldestEntry: Date?, newestEntry: Date?) {
        let entries = cachedMetrics.count
        let timestamps = cachedMetrics.values.map { $0.startDate }
        let oldestEntry = timestamps.min()
        let newestEntry = timestamps.max()
        
        return (entries, oldestEntry, newestEntry)
    }
    
    deinit {
        realtimeTimer?.invalidate()
        realtimeTimer = nil
    }
}