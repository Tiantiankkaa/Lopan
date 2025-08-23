//
//  CacheWarmingService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Cache Warming Strategy Protocol (缓存预热策略协议)

/// Strategy for determining which machines to preload in cache
/// 确定哪些机台需要预加载到缓存中的策略
protocol CacheWarmingStrategy {
    /// Get machines to preload based on strategy criteria
    /// 根据策略标准获取需要预加载的机台
    func getMachinesToPreload() async throws -> [String]
    
    /// Get strategy name for monitoring
    /// 获取策略名称用于监控
    var strategyName: String { get }
}

// MARK: - Concrete Warming Strategies (具体预热策略)

/// Strategy based on active/running machines
/// 基于活跃/运行中机台的策略
class ActiveMachineStrategy: CacheWarmingStrategy {
    private let machineRepository: MachineRepository
    
    var strategyName: String { "active_machines" }
    
    init(machineRepository: MachineRepository) {
        self.machineRepository = machineRepository
    }
    
    func getMachinesToPreload() async throws -> [String] {
        let machines = try await machineRepository.fetchAllMachines()
        return machines
            .filter { $0.isActive && $0.status == .running }
            .map { $0.id }
    }
}

/// Strategy based on recent batch activity
/// 基于最近批次活动的策略
class RecentActivityStrategy: CacheWarmingStrategy {
    private let productionBatchRepository: ProductionBatchRepository
    private let lookbackHours: Int
    
    var strategyName: String { "recent_activity" }
    
    init(productionBatchRepository: ProductionBatchRepository, lookbackHours: Int = 24) {
        self.productionBatchRepository = productionBatchRepository
        self.lookbackHours = lookbackHours
    }
    
    func getMachinesToPreload() async throws -> [String] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -lookbackHours, to: endDate) ?? endDate
        
        let recentBatches = try await productionBatchRepository.fetchBatches(
            from: startDate, 
            to: endDate, 
            shift: nil
        )
        
        // Get unique machine IDs from recent batches
        let machineIds = Set(recentBatches.map { $0.machineId })
        return Array(machineIds)
    }
}

/// Combined strategy using multiple approaches
/// 结合多种方法的组合策略
class CombinedStrategy: CacheWarmingStrategy {
    private let strategies: [CacheWarmingStrategy]
    
    var strategyName: String { "combined_strategy" }
    
    init(strategies: [CacheWarmingStrategy]) {
        self.strategies = strategies
    }
    
    func getMachinesToPreload() async throws -> [String] {
        var allMachineIds = Set<String>()
        
        for strategy in strategies {
            let machineIds = try await strategy.getMachinesToPreload()
            allMachineIds.formUnion(machineIds)
        }
        
        return Array(allMachineIds)
    }
}

// MARK: - Cache Warming Service (缓存预热服务)

/// Service for intelligent cache warming and background optimization
/// 智能缓存预热和后台优化服务
@MainActor
class CacheWarmingService: ObservableObject {
    
    // MARK: - Dependencies
    private let batchMachineCoordinator: StandardBatchMachineCoordinator
    private let warmingStrategy: CacheWarmingStrategy
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var isWarming = false
    @Published var lastWarmingTime: Date?
    @Published var warmingResults: CacheWarmingResults?
    
    // MARK: - Configuration
    private let warmingInterval: TimeInterval = 300 // 5 minutes
    private let maxConcurrentWarmings = 5
    private var warmingTimer: Timer?
    
    struct CacheWarmingResults {
        let startTime: Date
        let endTime: Date
        let machinesWarmed: Int
        let successCount: Int
        let failureCount: Int
        let strategyUsed: String
        
        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
        
        var successRate: Double {
            let total = successCount + failureCount
            return total > 0 ? Double(successCount) / Double(total) : 0.0
        }
    }
    
    init(
        batchMachineCoordinator: StandardBatchMachineCoordinator,
        warmingStrategy: CacheWarmingStrategy,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.batchMachineCoordinator = batchMachineCoordinator
        self.warmingStrategy = warmingStrategy
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Service Lifecycle
    
    /// Start automatic cache warming with periodic timer
    /// 启动带周期定时器的自动缓存预热
    func startAutomaticWarming() {
        guard warmingTimer == nil else { return }
        
        warmingTimer = Timer.scheduledTimer(withTimeInterval: warmingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCacheWarming()
            }
        }
        
        // Perform initial warming
        Task {
            await performCacheWarming()
        }
    }
    
    /// Stop automatic cache warming
    /// 停止自动缓存预热
    func stopAutomaticWarming() {
        warmingTimer?.invalidate()
        warmingTimer = nil
    }
    
    // MARK: - Cache Warming Operations
    
    /// Perform cache warming operation
    /// 执行缓存预热操作
    func performCacheWarming() async {
        guard !isWarming else { return }
        
        isWarming = true
        let startTime = Date()
        
        do {
            let machineIds = try await warmingStrategy.getMachinesToPreload()
            
            var successCount = 0
            var failureCount = 0
            
            // Perform warming with controlled concurrency
            await withTaskGroup(of: Bool.self) { group in
                let semaphore = DispatchSemaphore(value: maxConcurrentWarmings)
                
                for machineId in machineIds {
                    group.addTask { [weak self] in
                        semaphore.wait()
                        defer { semaphore.signal() }
                        
                        do {
                            _ = try await self?.batchMachineCoordinator.getMachineProductionContext(machineId)
                            return true
                        } catch {
                            return false
                        }
                    }
                }
                
                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failureCount += 1
                    }
                }
            }
            
            let endTime = Date()
            let results = CacheWarmingResults(
                startTime: startTime,
                endTime: endTime,
                machinesWarmed: machineIds.count,
                successCount: successCount,
                failureCount: failureCount,
                strategyUsed: warmingStrategy.strategyName
            )
            
            warmingResults = results
            lastWarmingTime = endTime
            
            // Log warming completion
            try? await auditService.logSecurityEvent(
                event: "cache_warming_completed",
                userId: authService.currentUser?.id ?? "system",
                details: [
                    "machines_warmed": "\(machineIds.count)",
                    "strategy": warmingStrategy.strategyName,
                    "success_count": "\(successCount)",
                    "failure_count": "\(failureCount)",
                    "duration": "\(String(format: "%.2f", results.duration))s"
                ]
            )
            
        } catch {
            try? await auditService.logSecurityEvent(
                event: "cache_warming_failed",
                userId: authService.currentUser?.id ?? "system",
                details: ["strategy": warmingStrategy.strategyName, "error": error.localizedDescription]
            )
        }
        
        isWarming = false
    }
    
    /// Manually trigger cache warming
    /// 手动触发缓存预热
    func warmCacheManually() async {
        await performCacheWarming()
    }
    
    /// Warm cache for specific machines
    /// 为特定机台预热缓存
    func warmCache(for machineIds: [String]) async {
        guard !isWarming else { return }
        
        isWarming = true
        
        await batchMachineCoordinator.preloadCache(for: machineIds)
        
        try? await auditService.logSecurityEvent(
            event: "manual_cache_warming",
            userId: authService.currentUser?.id ?? "system",
            details: ["machines": machineIds.joined(separator: ", ")]
        )
        
        isWarming = false
    }
    
    // MARK: - Cache Analysis and Optimization
    
    /// Analyze cache performance and suggest optimizations
    /// 分析缓存性能并建议优化
    func analyzeCachePerformance() -> CacheAnalysisResult {
        let metrics = batchMachineCoordinator.getCacheMetrics()
        
        var recommendations: [String] = []
        
        // Analyze hit rate
        if metrics.hitRate < 0.7 {
            recommendations.append("缓存命中率较低 (\(String(format: "%.1f", metrics.hitRate * 100))%)，考虑增加预热频率或调整缓存策略")
        }
        
        // Analyze eviction rate
        if metrics.evictions > Int(Double(metrics.hits) * 0.1) {
            recommendations.append("缓存驱逐率较高，考虑增加缓存大小或优化访问模式")
        }
        
        // Analyze cache utilization
        if metrics.entries < 10 && metrics.hits > 0 {
            recommendations.append("缓存利用率较低，可能需要更积极的预热策略")
        }
        
        if recommendations.isEmpty {
            recommendations.append("缓存性能良好，无需调整")
        }
        
        return CacheAnalysisResult(
            hitRate: metrics.hitRate,
            cacheEntries: metrics.entries,
            totalHits: metrics.hits,
            totalMisses: metrics.misses,
            evictions: metrics.evictions,
            recommendations: recommendations
        )
    }
    
    struct CacheAnalysisResult {
        let hitRate: Double
        let cacheEntries: Int
        let totalHits: Int
        let totalMisses: Int
        let evictions: Int
        let recommendations: [String]
    }
    
    deinit {
        Task { @MainActor in
            stopAutomaticWarming()
        }
    }
}

// MARK: - Cache Warming Service Factory (缓存预热服务工厂)

/// Factory for creating cache warming services with appropriate strategies
/// 创建具有适当策略的缓存预热服务的工厂
struct CacheWarmingServiceFactory {
    
    @MainActor static func createService(
        batchMachineCoordinator: StandardBatchMachineCoordinator,
        machineRepository: MachineRepository,
        productionBatchRepository: ProductionBatchRepository,
        auditService: NewAuditingService,
        authService: AuthenticationService,
        strategy: WarmingStrategyType = .combined
    ) -> CacheWarmingService {
        
        let warmingStrategy: CacheWarmingStrategy
        
        switch strategy {
        case .activeMachines:
            warmingStrategy = ActiveMachineStrategy(machineRepository: machineRepository)
        case .recentActivity:
            warmingStrategy = RecentActivityStrategy(productionBatchRepository: productionBatchRepository)
        case .combined:
            let activeStrategy = ActiveMachineStrategy(machineRepository: machineRepository)
            let recentStrategy = RecentActivityStrategy(productionBatchRepository: productionBatchRepository)
            warmingStrategy = CombinedStrategy(strategies: [activeStrategy, recentStrategy])
        }
        
        return CacheWarmingService(
            batchMachineCoordinator: batchMachineCoordinator,
            warmingStrategy: warmingStrategy,
            auditService: auditService,
            authService: authService
        )
    }
}

enum WarmingStrategyType {
    case activeMachines
    case recentActivity
    case combined
}