//
//  BatchMachineCoordinator.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Batch Machine Coordination Protocol (批次-机台协调协议)

/// Unified protocol for coordinating machine status and batch availability
/// 统一协调机台状态和批次可用性的协议
@MainActor
protocol BatchMachineCoordinator {
    /// Get machine with its current production context
    /// 获取机台及其当前生产上下文
    func getMachineProductionContext(_ machineId: String) async throws -> MachineProductionContext
    
    /// Get inheritable products for a new batch based on shift logic
    /// 根据班次逻辑获取新批次的可继承产品
    func getInheritableProducts(machineId: String, date: Date, shift: Shift) async throws -> [ProductConfig]
    
    /// Check if machine can accept new batch creation
    /// 检查机台是否可以接受新批次创建
    func canCreateBatch(machineId: String, date: Date, shift: Shift) async throws -> BatchCreationEligibility
}

// MARK: - Supporting Types (支持类型)

/// Comprehensive machine production context
/// 完整的机台生产上下文
struct MachineProductionContext {
    let machine: WorkshopMachine
    let activeBatch: ProductionBatch?
    let inheritableProducts: [ProductConfig]
    let lastUpdated: Date
    let isConsistent: Bool // Whether machine status matches batch status
    
    var isRunning: Bool {
        return machine.status == .running && machine.isActive
    }
    
    var hasActiveProducts: Bool {
        return !inheritableProducts.isEmpty
    }
}

/// Batch creation eligibility status
/// 批次创建资格状态
struct BatchCreationEligibility {
    let canCreate: Bool
    let reason: String?
    let availableProducts: [ProductConfig]
    let machineContext: MachineProductionContext
    
    static func eligible(with products: [ProductConfig], context: MachineProductionContext) -> BatchCreationEligibility {
        return BatchCreationEligibility(
            canCreate: true,
            reason: nil,
            availableProducts: products,
            machineContext: context
        )
    }
    
    static func ineligible(reason: String, context: MachineProductionContext) -> BatchCreationEligibility {
        return BatchCreationEligibility(
            canCreate: false,
            reason: reason,
            availableProducts: [],
            machineContext: context
        )
    }
}

// MARK: - Standard Implementation (标准实现)

/// Standard implementation of BatchMachineCoordinator
/// BatchMachineCoordinator的标准实现
@MainActor
class StandardBatchMachineCoordinator: ObservableObject, BatchMachineCoordinator {
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let productionBatchRepository: ProductionBatchRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - Intelligent Cache Management (智能缓存管理)
    
    /// Cache entry with metadata for intelligent invalidation
    /// 包含智能失效元数据的缓存条目
    private struct CacheEntry {
        let context: MachineProductionContext
        let timestamp: Date
        let accessCount: Int
        let lastAccessTime: Date
        let dependencyHash: String // Hash of data dependencies
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
        
        var timeSinceLastAccess: TimeInterval {
            Date().timeIntervalSince(lastAccessTime)
        }
        
        func withIncrementedAccess() -> CacheEntry {
            return CacheEntry(
                context: context,
                timestamp: timestamp,
                accessCount: accessCount + 1,
                lastAccessTime: Date(),
                dependencyHash: dependencyHash
            )
        }
    }
    
    /// Cache metrics for performance monitoring
    /// 性能监控的缓存指标
    private struct CacheMetrics {
        var hits: Int = 0
        var misses: Int = 0
        var invalidations: Int = 0
        var evictions: Int = 0
        var preloads: Int = 0
        
        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
        
        mutating func recordHit() { hits += 1 }
        mutating func recordMiss() { misses += 1 }
        mutating func recordInvalidation() { invalidations += 1 }
        mutating func recordEviction() { evictions += 1 }
        mutating func recordPreload() { preloads += 1 }
    }
    
    private var contextCache: [String: CacheEntry] = [:]
    private var metrics = CacheMetrics()
    private let maxCacheSize = 50 // Maximum cache entries
    private let baseCacheTimeout: TimeInterval = 30 // Base timeout: 30 seconds
    private let maxCacheTimeout: TimeInterval = 300 // Max timeout: 5 minutes
    private let accessCountMultiplier: TimeInterval = 10 // Bonus seconds per access
    
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
    
    // MARK: - Protocol Implementation
    
    func getMachineProductionContext(_ machineId: String) async throws -> MachineProductionContext {
        // Check cache with intelligent invalidation
        if let cachedEntry = contextCache[machineId] {
            let adaptiveTimeout = calculateAdaptiveTimeout(for: cachedEntry)
            
            if cachedEntry.age < adaptiveTimeout {
                // Cache hit - update access tracking
                contextCache[machineId] = cachedEntry.withIncrementedAccess()
                metrics.recordHit()
                return cachedEntry.context
            } else {
                // Cache expired - remove entry
                contextCache.removeValue(forKey: machineId)
                metrics.recordInvalidation()
            }
        }
        
        metrics.recordMiss()
        
        // Validate basic permissions
        guard authService.currentUser != nil else {
            throw BatchMachineCoordinatorError.validationFailed("用户未登录")
        }
        
        // Fetch fresh data
        let machines = try await machineRepository.fetchAllMachines()
        guard let machine = machines.first(where: { $0.id == machineId }) else {
            throw BatchMachineCoordinatorError.machineNotFound(machineId)
        }
        
        let activeBatch = try await fetchActiveBatchForMachine(machineId)
        let inheritableProducts = try await getInheritableProducts(machineId: machineId, date: Date(), shift: getCurrentShift())
        
        let context = MachineProductionContext(
            machine: machine,
            activeBatch: activeBatch,
            inheritableProducts: inheritableProducts,
            lastUpdated: Date(),
            isConsistent: validateMachineConsistency(machine: machine, batch: activeBatch)
        )
        
        // Cache the result with intelligent metadata
        let dependencyHash = generateDependencyHash(machine: machine, batch: activeBatch, products: inheritableProducts)
        let cacheEntry = CacheEntry(
            context: context,
            timestamp: Date(),
            accessCount: 1,
            lastAccessTime: Date(),
            dependencyHash: dependencyHash
        )
        
        // Ensure cache doesn't exceed max size
        if contextCache.count >= maxCacheSize {
            evictLeastRecentlyUsed()
        }
        
        contextCache[machineId] = cacheEntry
        
        return context
    }
    
    func getInheritableProducts(machineId: String, date: Date, shift: Shift) async throws -> [ProductConfig] {
        // Basic permission check
        guard authService.currentUser != nil else {
            throw BatchMachineCoordinatorError.validationFailed("用户未登录")
        }
        
        let previousShiftInfo = getPreviousShiftInfo(for: date, shift: shift)
        
        // First try to get products from previous shift
        let previousShiftBatches = try await productionBatchRepository.fetchBatches(
            forDate: previousShiftInfo.date,
            shift: previousShiftInfo.shift
        )
        
        let machineBatches = previousShiftBatches.filter { batch in
            batch.machineId == machineId
        }
        
        let runningBatches = machineBatches.filter { batch in
            batch.status == .active
        }
        
        var products: [ProductConfig] = []
        
        // Extract products from previous shift batches
        for batch in runningBatches {
            for product in batch.products {
                let inheritableProduct = ProductConfig(
                    batchId: "", // Will be set when new batch is created
                    productName: product.productName,
                    primaryColorId: product.primaryColorId,
                    occupiedStations: product.occupiedStations,
                    secondaryColorId: product.secondaryColorId,
                    productId: product.productId,
                    stationCount: product.stationCount,
                    gunAssignment: product.gunAssignment
                )
                products.append(inheritableProduct)
            }
        }
        
        // If no products found but machine is running, check current active batches
        if products.isEmpty {
            let machine = try await machineRepository.fetchMachine(byId: machineId)
            if let machine = machine, machine.status == .running && machine.isActive {
                // Use optimized query to get the latest batch for the specific machine and shift
                if let specificBatch = try await productionBatchRepository.fetchLatestBatchForMachineAndShift(
                    machineId: machineId,
                    date: previousShiftInfo.date,
                    shift: previousShiftInfo.shift
                ), specificBatch.status == .active {
                    
                    for product in specificBatch.products {
                        let inheritableProduct = ProductConfig(
                            batchId: "",
                            productName: product.productName,
                            primaryColorId: product.primaryColorId,
                            occupiedStations: product.occupiedStations,
                            secondaryColorId: product.secondaryColorId,
                            productId: product.productId,
                            stationCount: product.stationCount,
                            gunAssignment: product.gunAssignment
                        )
                        products.append(inheritableProduct)
                    }
                }
            }
        }
        
        // Validate inheritance logic for next day evening shifts
        if products.isEmpty {
            let isValidInheritance = validateInheritanceLogic(date: date, shift: shift, previousShiftInfo: previousShiftInfo)
            if !isValidInheritance {
                // Return empty array if inheritance logic is invalid
                // This will trigger proper error handling in the UI
                return []
            }
        }
        
        return products
    }
    
    func canCreateBatch(machineId: String, date: Date, shift: Shift) async throws -> BatchCreationEligibility {
        // Basic permission check
        guard authService.currentUser != nil else {
            throw BatchMachineCoordinatorError.validationFailed("用户未登录")
        }
        
        let context = try await getMachineProductionContext(machineId)
        
        // Check machine status
        guard context.machine.isActive else {
            return .ineligible(reason: "机台已禁用", context: context)
        }
        
        guard context.machine.status != .maintenance && context.machine.status != .error else {
            return .ineligible(reason: "机台处于\(context.machine.status.displayName)状态", context: context)
        }
        
        // Check for conflicting batches
        let hasConflict = try await productionBatchRepository.hasConflictingBatches(
            forDate: date,
            shift: shift,
            machineId: machineId,
            excludingBatchId: nil
        )
        
        guard !hasConflict else {
            return .ineligible(reason: "该时段已存在冲突的批次", context: context)
        }
        
        // Get inheritable products
        let products = try await getInheritableProducts(machineId: machineId, date: date, shift: shift)
        
        return .eligible(with: products, context: context)
    }
    
    // MARK: - Helper Methods
    
    private func fetchActiveBatchForMachine(_ machineId: String) async throws -> ProductionBatch? {
        return try await productionBatchRepository.fetchActiveBatchForMachine(machineId)
    }
    
    private func validateMachineConsistency(machine: WorkshopMachine, batch: ProductionBatch?) -> Bool {
        if machine.status == .running {
            return batch != nil && batch?.status == .active
        } else {
            return batch == nil || batch?.status != .active
        }
    }
    
    private func getCurrentShift() -> Shift {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? .morning : .evening
    }
    
    private func getPreviousShiftInfo(for date: Date, shift: Shift) -> (date: Date, shift: Shift) {
        if shift == .evening {
            // Evening shift copies from same day morning shift
            return (date: date, shift: .morning)
        } else {
            // Morning shift copies from previous day evening shift
            let calendar = Calendar.current
            let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            return (date: previousDay, shift: .evening)
        }
    }
    
    /// Validates the logic for inheriting products based on date and shift
    /// 验证基于日期和班次的产品继承逻辑
    private func validateInheritanceLogic(date: Date, shift: Shift, previousShiftInfo: (date: Date, shift: Shift)) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        
        // Check if this is a next day evening shift
        if shift == .evening && targetDate > today {
            // For next day evening shifts, the previous shift should be same day morning
            // This is already handled correctly by getPreviousShiftInfo
            // But we need to ensure that we don't fall back to any random active batch
            
            // If we're creating a next day evening batch and there's no morning batch for that day,
            // we should not allow inheritance from any other batch
            return false // Return false to prevent inappropriate inheritance
        }
        
        return true // Allow inheritance for all other cases
    }
    
    // MARK: - Intelligent Cache Management Methods (智能缓存管理方法)
    
    /// Calculate adaptive timeout based on access patterns
    /// 根据访问模式计算自适应超时时间
    private func calculateAdaptiveTimeout(for entry: CacheEntry) -> TimeInterval {
        // Base timeout + bonus time based on access frequency
        let accessBonus = min(Double(entry.accessCount) * accessCountMultiplier, maxCacheTimeout - baseCacheTimeout)
        return baseCacheTimeout + accessBonus
    }
    
    /// Generate dependency hash for cache invalidation
    /// 生成用于缓存失效的依赖哈希
    private func generateDependencyHash(machine: WorkshopMachine, batch: ProductionBatch?, products: [ProductConfig]) -> String {
        var hasher = Hasher()
        hasher.combine(machine.id)
        hasher.combine(machine.status.rawValue)
        hasher.combine(machine.isActive)
        hasher.combine(machine.updatedAt)
        
        if let batch = batch {
            hasher.combine(batch.id)
            hasher.combine(batch.status.rawValue)
            hasher.combine(batch.updatedAt)
        }
        
        for product in products {
            hasher.combine(product.id)
            hasher.combine(product.primaryColorId)
            hasher.combine(product.updatedAt)
        }
        
        return String(hasher.finalize())
    }
    
    /// Evict least recently used cache entry
    /// 驱逐最近最少使用的缓存条目
    private func evictLeastRecentlyUsed() {
        guard !contextCache.isEmpty else { return }
        
        let oldestEntry = contextCache.min { lhs, rhs in
            lhs.value.lastAccessTime < rhs.value.lastAccessTime
        }
        
        if let (machineId, _) = oldestEntry {
            contextCache.removeValue(forKey: machineId)
            metrics.recordEviction()
        }
    }
    
    /// Preload cache for frequently accessed machines
    /// 为频繁访问的机台预加载缓存
    func preloadCache(for machineIds: [String]) async {
        for machineId in machineIds {
            // Only preload if not already cached
            if contextCache[machineId] == nil {
                do {
                    _ = try await getMachineProductionContext(machineId)
                    metrics.recordPreload()
                } catch {
                    // Log preload failure but don't throw - it's not critical
                    try? await auditService.logSecurityEvent(
                        event: "cache_preload_failed",
                        userId: authService.currentUser?.id ?? "system",
                        details: ["machine_id": machineId, "error": error.localizedDescription]
                    )
                }
            }
        }
    }
    
    /// Intelligently invalidate cache based on data changes
    /// 基于数据变化智能地使缓存失效
    func invalidateCache(for machineId: String? = nil, reason: String = "manual") {
        if let machineId = machineId {
            if contextCache.removeValue(forKey: machineId) != nil {
                metrics.recordInvalidation()
            }
        } else {
            let removedCount = contextCache.count
            contextCache.removeAll()
            metrics.invalidations += removedCount
        }
        
        // Log cache invalidation for monitoring
        Task {
            try? await auditService.logSecurityEvent(
                event: "cache_invalidated",
                userId: authService.currentUser?.id ?? "system",
                details: ["machine_id": machineId ?? "all", "reason": reason]
            )
        }
    }
    
    /// Get cache performance metrics
    /// 获取缓存性能指标
    func getCacheMetrics() -> (hitRate: Double, entries: Int, hits: Int, misses: Int, invalidations: Int, evictions: Int, preloads: Int) {
        return (
            hitRate: metrics.hitRate,
            entries: contextCache.count,
            hits: metrics.hits,
            misses: metrics.misses,
            invalidations: metrics.invalidations,
            evictions: metrics.evictions,
            preloads: metrics.preloads
        )
    }
    
    /// Reset cache metrics for testing/debugging
    /// 重置缓存指标用于测试/调试
    func resetCacheMetrics() {
        metrics = CacheMetrics()
    }
    
    /// Clear cache for specific machine or all machines
    /// 清除特定机台或所有机台的缓存
    @available(*, deprecated, message: "Use invalidateCache(for:reason:) instead")
    func clearCache(for machineId: String? = nil) {
        invalidateCache(for: machineId, reason: "legacy_clear_cache")
    }
}

// MARK: - Error Types (错误类型)

enum BatchMachineCoordinatorError: LocalizedError {
    case machineNotFound(String)
    case batchNotFound(String)
    case inconsistentState(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .machineNotFound(let id):
            return "未找到机台: \(id)"
        case .batchNotFound(let id):
            return "未找到批次: \(id)"
        case .inconsistentState(let description):
            return "状态不一致: \(description)"
        case .validationFailed(let reason):
            return "验证失败: \(reason)"
        }
    }
}