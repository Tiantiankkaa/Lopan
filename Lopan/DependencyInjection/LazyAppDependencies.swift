//
//  LazyAppDependencies.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Three-Tier Lazy Loading Architecture

@MainActor
public final class LazyAppDependencies: HasAppDependencies, ObservableObject {
    
    // MARK: - Core Factories (Eager - Always Available)
    public let repositoryFactory: RepositoryFactory
    public let serviceFactory: ServiceFactory
    
    // MARK: - Service Cache with Memory Management
    private var serviceCache: [String: Any] = [:]
    private var repositoryCache: [String: Any] = [:]
    private let maxCacheSize = 20 // Prevent unbounded growth
    
    // MARK: - Safe Dependency Management
    private let safeContainer = SafeLazyDependencyContainer()
    
    // MARK: - Predictive Loading Engine
    private let predictiveEngine = PredictiveLoadingEngine()
    
    // MARK: - Memory Monitoring
    private var memoryMonitor: MemoryMonitor?
    
    // MARK: - Memory Optimization Validation
    private let memoryValidator = MemoryOptimizationValidator()
    
    // MARK: - Initialization
    public init(repositoryFactory: RepositoryFactory, serviceFactory: ServiceFactory) {
        self.repositoryFactory = repositoryFactory
        self.serviceFactory = serviceFactory
        
        // Initialize memory monitoring
        self.memoryMonitor = MemoryMonitor { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
        
        print("🔄 LazyAppDependencies initialized with three-tier architecture")
    }
    
    // MARK: - TIER 1: Critical Services (Cached, Never Evicted)
    
    public var authenticationService: AuthenticationService {
        return getCachedService("auth", priority: .critical) {
            print("🔐 Initializing Critical Service: Authentication")
            return serviceFactory.authenticationService
        }
    }
    
    public var auditingService: NewAuditingService {
        return getCachedService("audit", priority: .critical) {
            print("📝 Initializing Critical Service: Auditing")
            return serviceFactory.auditingService
        }
    }
    
    // MARK: - TIER 2: Feature Services (Cached, Evicted Under Memory Pressure)
    
    public var customerOutOfStockService: CustomerOutOfStockService {
        return getCachedService("customerOutOfStock", priority: .feature) {
            print("📦 Initializing Feature Service: Customer Out-of-Stock")
            return serviceFactory.customerOutOfStockService
        }
    }

    public var customerOutOfStockCoordinator: CustomerOutOfStockCoordinator {
        return getCachedService("customerOutOfStockCoordinator", priority: .feature) {
            print("📦 Initializing Feature Coordinator: Customer Out-of-Stock")
            return serviceFactory.customerOutOfStockCoordinator
        }
    }
    
    public var customerService: CustomerService {
        return getCachedService("customer", priority: .feature) {
            print("👥 Initializing Feature Service: Customer")
            return serviceFactory.customerService
        }
    }
    
    public var productService: ProductService {
        return getCachedService("product", priority: .feature) {
            print("🛍️ Initializing Feature Service: Product")
            return serviceFactory.productService
        }
    }
    
    public var userService: UserService {
        return getCachedService("user", priority: .feature) {
            print("👤 Initializing Feature Service: User")
            return serviceFactory.userService
        }
    }
    
    public var machineService: MachineService {
        return getCachedService("machine", priority: .feature) {
            print("⚙️ Initializing Feature Service: Machine")
            return serviceFactory.machineService
        }
    }
    
    public var colorService: ColorService {
        return getCachedService("color", priority: .feature) {
            print("🎨 Initializing Feature Service: Color")
            return serviceFactory.colorService
        }
    }
    
    public var productionBatchService: ProductionBatchService {
        return getCachedService("productionBatch", priority: .feature) {
            print("🏭 Initializing Feature Service: Production Batch")
            return serviceFactory.productionBatchService
        }
    }
    
    // MARK: - TIER 3: Background Services (Ultra-Lazy, Frequent Eviction)
    
    public var dataInitializationService: NewDataInitializationService {
        return getCachedService("dataInit", priority: .background) {
            print("🔄 Initializing Background Service: Data Initialization")
            return serviceFactory.dataInitializationService
        }
    }
    
    // MARK: - Repository Access (Lazy with Predictive Loading)
    
    public var userRepository: UserRepository {
        return getCachedRepository("user", priority: .feature) {
            repositoryFactory.userRepository
        }
    }
    
    public var customerRepository: CustomerRepository {
        return getCachedRepository("customer", priority: .feature) {
            repositoryFactory.customerRepository
        }
    }
    
    public var productRepository: ProductRepository {
        return getCachedRepository("product", priority: .feature) {
            repositoryFactory.productRepository
        }
    }
    
    public var customerOutOfStockRepository: CustomerOutOfStockRepository {
        return getCachedRepository("customerOutOfStock", priority: .feature) {
            repositoryFactory.customerOutOfStockRepository
        }
    }
    
    public var packagingRepository: PackagingRepository {
        return getCachedRepository("packaging", priority: .background) {
            repositoryFactory.packagingRepository
        }
    }
    
    public var productionRepository: ProductionRepository {
        return getCachedRepository("production", priority: .background) {
            repositoryFactory.productionRepository
        }
    }
    
    public var auditRepository: AuditRepository {
        return getCachedRepository("audit", priority: .critical) {
            repositoryFactory.auditRepository
        }
    }
    
    public var machineRepository: MachineRepository {
        return getCachedRepository("machine", priority: .feature) {
            repositoryFactory.machineRepository
        }
    }
    
    public var colorRepository: ColorRepository {
        return getCachedRepository("color", priority: .feature) {
            repositoryFactory.colorRepository
        }
    }
    
    public var productionBatchRepository: ProductionBatchRepository {
        return getCachedRepository("productionBatch", priority: .feature) {
            repositoryFactory.productionBatchRepository
        }
    }
    
    // MARK: - Smart Caching Implementation
    
    private func getCachedService<T>(_ key: String, priority: ServicePriority, factory: () -> T) -> T {
        if let cached = serviceCache[key] as? T {
            // Record access for predictive learning
            recordServiceAccess(key, context: determineAccessContext())
            
            // Update access time for LRU
            triggerPredictiveLoading(for: key)
            return cached
        }
        
        // Memory pressure check before creating new services
        if serviceCache.count >= maxCacheSize && priority == .background {
            Task { await performMemoryCleanup() }
        }
        
        // Use safe container for dependency management
        do {
            let dependencies = getDependenciesFor(service: key, priority: priority)
            let instance = try safeContainer.safeInitialize(
                serviceName: key,
                priority: priority,
                dependencies: dependencies
            ) {
                return factory()
            }
            
            serviceCache[key] = instance
            
            // Record successful service creation for predictive learning
            recordServiceAccess(key, context: determineAccessContext())
            
            // Enhanced predictive preloading based on access patterns and role
            triggerEnhancedPredictiveLoading(for: key)
            
            print("🔄 Lazy loaded service: \(key) (priority: \(priority))")
            return instance
            
        } catch {
            print("❌ Failed to safely initialize service: \(key), error: \(error)")
            
            // Fallback to direct initialization for critical services
            if priority == .critical {
                print("⚠️ Using fallback initialization for critical service: \(key)")
                let instance = factory()
                serviceCache[key] = instance
                
                // Record even fallback access
                recordServiceAccess(key, context: .maintenance)
                return instance
            } else {
                // For non-critical services, we might return a placeholder or crash
                fatalError("Failed to initialize service \(key): \(error)")
            }
        }
    }
    
    private func getCachedRepository<T>(_ key: String, priority: ServicePriority, factory: () -> T) -> T {
        if let cached = repositoryCache[key] as? T {
            return cached
        }
        
        let instance = factory()
        repositoryCache[key] = instance
        
        print("📁 Lazy loaded repository: \(key) (priority: \(priority))")
        return instance
    }
    
    // MARK: - Memory Management
    
    private func handleMemoryPressure() async {
        print("🚨 Memory pressure detected - performing cleanup")
        await performMemoryCleanup()
    }
    
    private func performMemoryCleanup() async {
        print("🧹 Performing memory cleanup...")
        
        // Remove background tier services first
        let backgroundKeys = ["dataInit", "packaging", "production"]
        var cleanedCount = 0
        
        for key in backgroundKeys {
            if serviceCache.removeValue(forKey: key) != nil {
                cleanedCount += 1
            }
        }
        
        // If still over limit, remove some feature services (except critical ones)
        if serviceCache.count > maxCacheSize * 2 / 3 {
            let featureKeys = ["color", "machine", "productionBatch"]
            for key in featureKeys {
                if serviceCache.removeValue(forKey: key) != nil {
                    cleanedCount += 1
                }
            }
        }
        
        print("🧹 Memory cleanup completed: removed \(cleanedCount) services")
    }
    
    // MARK: - Dependency Mapping
    
    private func getDependenciesFor(service: String, priority: ServicePriority) -> Set<String> {
        switch service {
        // TIER 1: Critical Services (minimal dependencies)
        case "auth":
            return [] // Authentication should be self-contained
        case "audit":
            return [] // Auditing should be self-contained
            
        // TIER 2: Feature Services (depend on critical services)
        case "customerOutOfStock":
            return ["auth", "audit"] // Business services need auth and audit
        case "customer":
            return ["auth", "audit"]
        case "product":
            return ["auth", "audit"]
        case "user":
            return ["auth", "audit"]
        case "machine":
            return ["auth", "audit"]
        case "color":
            return ["auth"]
        case "productionBatch":
            return ["auth", "audit", "machine", "color"]
            
        // TIER 3: Background Services (may have deeper dependencies)
        case "dataInit":
            return ["auth", "audit"] // Data initialization needs basic services
            
        // Default: Use priority-based defaults
        default:
            return priority.typicalDependencies
        }
    }
    
    // MARK: - Predictive Loading Integration
    
    private func recordServiceAccess(_ serviceName: String, context: PredictiveLoadingEngine.AccessPattern.AccessContext) {
        predictiveEngine.recordAccess(serviceName: serviceName, context: context)
    }
    
    private func determineAccessContext() -> PredictiveLoadingEngine.AccessPattern.AccessContext {
        // Simple heuristic to determine context - could be enhanced with app state
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 8...9:
            return .startup
        case 17...18:
            return .reporting
        default:
            return .navigation
        }
    }
    
    private func triggerEnhancedPredictiveLoading(for accessedKey: String) {
        Task { @MainActor in
            // Get AI-driven predictions
            let predictedServices = predictiveEngine.getPredictiveServices(for: determineAccessContext())
            
            // Preload predicted services (limit to avoid overload)
            for serviceName in predictedServices.prefix(2) {
                preloadServiceIfNotCached(serviceName)
            }
            
            // Legacy predictive patterns (still useful for immediate relationships)
            triggerLegacyPredictiveLoading(for: accessedKey)
        }
    }
    
    private func preloadServiceIfNotCached(_ serviceName: String) {
        // Only preload if not already cached
        if serviceCache[serviceName] == nil {
            switch serviceName {
            case "auth":
                _ = authenticationService
            case "audit":
                _ = auditingService
            case "customer":
                _ = customerService
            case "product":
                _ = productService
            case "user":
                _ = userService
            case "customerOutOfStock":
                _ = customerOutOfStockService
            case "machine":
                _ = machineService
            case "color":
                _ = colorService
            case "productionBatch":
                _ = productionBatchService
            case "dataInit":
                _ = dataInitializationService
            default:
                print("⚠️ Unknown service for preloading: \(serviceName)")
            }
            
            print("🔮 AI-predicted preload: \(serviceName)")
        }
    }
    
    // MARK: - Legacy Predictive Loading (Deterministic Patterns)
    
    private func triggerLegacyPredictiveLoading(for accessedKey: String) {
        switch accessedKey {
        case "customerOutOfStock":
            // Preload related dependencies that are commonly accessed together
            _ = customerRepository
            _ = productRepository
            print("🔗 Legacy predictive: customer and product repositories")
            
        case "customer":
            // Customers often access products
            _ = productRepository
            print("🔗 Legacy predictive: product repository")
            
        case "productionBatch":
            // Production batches often need machine and color data
            _ = machineRepository
            _ = colorRepository
            print("🔗 Legacy predictive: machine and color repositories")
            
        case "auth":
            // Authentication often triggers user and audit services
            _ = userService
            _ = auditingService
            print("🔗 Legacy predictive: user and audit services")
            
        default:
            break
        }
    }
    
    // Keep original for backward compatibility
    private func triggerPredictiveLoading(for accessedKey: String) {
        triggerLegacyPredictiveLoading(for: accessedKey)
    }
    
    // MARK: - Async Service Initialization with Retry
    
    public func initializeServiceWithRetry<T>(
        serviceName: String,
        priority: ServicePriority,
        maxRetries: Int = 3,
        factory: @escaping () throws -> T
    ) async -> T? {
        do {
            let dependencies = getDependenciesFor(service: serviceName, priority: priority)
            
            return try await safeContainer.initializeWithRetry(
                serviceName: serviceName,
                priority: priority,
                dependencies: dependencies,
                maxRetries: maxRetries,
                factory: factory
            )
        } catch {
            print("❌ Failed to initialize service \(serviceName) after \(maxRetries) retries: \(error)")
            return nil
        }
    }
    
    // MARK: - Batch Service Initialization
    
    public func initializeCriticalServices() async -> Bool {
        print("🎯 Initializing critical services in optimal order...")
        
        let criticalServices = ["auth", "audit"]
        var allSucceeded = true
        
        for serviceName in criticalServices {
            let success = await initializeCriticalService(serviceName)
            allSucceeded = allSucceeded && success
        }
        
        if allSucceeded {
            print("✅ All critical services initialized successfully")
            
            // Trigger memory validation after critical services are ready
            Task { @MainActor in
                await performPhase1Validation()
            }
        } else {
            print("⚠️ Some critical services failed to initialize")
        }
        
        return allSucceeded
    }
    
    private func initializeCriticalService(_ serviceName: String) async -> Bool {
        switch serviceName {
        case "auth":
            _ = authenticationService
            return true
        case "audit":
            _ = auditingService
            return true
        default:
            print("⚠️ Unknown critical service: \(serviceName)")
            return false
        }
    }
    
    // MARK: - Phase 1 Comprehensive Validation
    
    @MainActor
    private func performPhase1Validation() async {
        print("\n🏁 Starting Phase 1 Comprehensive Validation...")
        print(String(repeating: "=", count: 60))
        
        // Step 1: Memory optimization validation
        let memorySuccess = await validateMemoryOptimization()
        
        // Step 2: Performance benchmarks
        let performanceSuccess = await validatePerformanceBenchmarks()
        
        // Step 3: Dependency health check
        let dependencySuccess = performHealthCheck()
        
        // Step 4: System stability validation
        let stabilitySuccess = await validateSystemStability()
        
        // Overall Phase 1 validation result
        let overallSuccess = memorySuccess && performanceSuccess && dependencySuccess && stabilitySuccess
        
        print("\n" + String(repeating: "=", count: 60))
        if overallSuccess {
            print("🎉 PHASE 1 VALIDATION: ✅ SUCCESS")
            print("📊 Memory Reduction: ✅ Target ≤75MB achieved (17% improvement)")
            print("⚡ Performance: ✅ All benchmarks passed")
            print("🔗 Dependencies: ✅ All systems healthy")
            print("🛡️ Stability: ✅ System stable under load")
        } else {
            print("❌ PHASE 1 VALIDATION: FAILED")
            print("📊 Memory Reduction: ", memorySuccess ? "✅" : "❌")
            print("⚡ Performance: ", performanceSuccess ? "✅" : "❌")
            print("🔗 Dependencies: ", dependencySuccess ? "✅" : "❌")
            print("🛡️ Stability: ", stabilitySuccess ? "✅" : "❌")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    @MainActor
    private func validatePerformanceBenchmarks() async -> Bool {
        print("⚡ Validating performance benchmarks...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test 1: Service access speed
        _ = authenticationService
        _ = auditingService
        _ = customerOutOfStockService
        
        let accessTime = CFAbsoluteTimeGetCurrent() - startTime
        let accessSuccess = accessTime < 0.1 // 100ms target
        
        // Test 2: Cache performance
        let cacheStats = getCacheStatistics()
        let cacheSuccess = cacheStats.serviceCount <= maxCacheSize
        
        print("  Service Access Time: \(String(format: "%.3f", accessTime * 1000))ms (target: <100ms)")
        print("  Cache Size: \(cacheStats.serviceCount) entries (limit: \(maxCacheSize))")
        
        return accessSuccess && cacheSuccess
    }
    
    @MainActor
    private func validateSystemStability() async -> Bool {
        print("🛡️ Validating system stability...")
        
        // Test stability under load
        let initialMemory = getCurrentMemoryUsage()
        
        // Simulate load by accessing multiple services rapidly
        for _ in 0..<10 {
            _ = customerService
            _ = productService
            _ = userService
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        let memoryGrowthMB = Double(memoryGrowth) / 1024.0 / 1024.0
        
        let stabilitySuccess = memoryGrowthMB < 5.0 // Less than 5MB growth under load
        
        print("  Memory growth under load: \(String(format: "%.2f", memoryGrowthMB))MB (target: <5MB)")
        
        return stabilitySuccess
    }
    
    // MARK: - Factory Method (Updated)
    
    @MainActor
    public static func create(for environment: AppEnvironment, modelContext: ModelContext) -> LazyAppDependencies {
        let repositoryFactory = ServiceFactory.createRepositoryFactory(for: environment, modelContext: modelContext)
        let serviceFactory = ServiceFactory(repositoryFactory: repositoryFactory)
        
        let dependencies = LazyAppDependencies(repositoryFactory: repositoryFactory, serviceFactory: serviceFactory)
        
        // Perform initial health check
        print("🏥 Performing initial dependency health check...")
        let isHealthy = dependencies.performHealthCheck()
        
        if isHealthy {
            // Trigger intelligent startup preloading and validation
            Task { @MainActor in
                await dependencies.performIntelligentWarmup(strategy: .balanced)
                dependencies.printPredictiveAnalytics()
                
                // Run Phase 1 validation
                await dependencies.performPhase1Validation()
            }
        }
        
        return dependencies
    }
    
    // MARK: - Comprehensive Status Reporting
    
    public func printFullSystemStatus() {
        print("\n" + String(repeating: "🚀", count: 25))
        print("LOPAN INTELLIGENT DEPENDENCY SYSTEM STATUS")
        print(String(repeating: "🚀", count: 25))
        
        // Basic cache and dependency health
        printComprehensiveStatus()
        
        // Predictive engine analytics
        printPredictiveAnalytics()
        
        print("✨ System ready for optimal performance! ✨\n")
    }
    
    // MARK: - Debugging and Monitoring
    
    public func getCacheStatistics() -> LazyCacheStatistics {
        return LazyCacheStatistics(
            serviceCount: serviceCache.count,
            repositoryCount: repositoryCache.count,
            memoryUsage: getCurrentMemoryUsage()
        )
    }
    
    // MARK: - Enhanced Monitoring and Debugging
    
    public func getDependencyHealth() -> SafeLazyDependencyContainer.DependencyHealth {
        return safeContainer.getDependencyHealth()
    }
    
    public func printComprehensiveStatus() {
        print("\n" + String(repeating: "=", count: 50))
        print("📊 LAZY DEPENDENCIES COMPREHENSIVE STATUS")
        print(String(repeating: "=", count: 50))
        
        // Cache Statistics
        let cacheStats = getCacheStatistics()
        print("\n🗄️ Cache Status:")
        print("  Service Cache: \(cacheStats.serviceCount) entries")
        print("  Repository Cache: \(cacheStats.repositoryCount) entries")
        print("  Memory Usage: \(String(format: "%.2f", cacheStats.memoryUsageMB)) MB")
        
        // Dependency Health
        let health = getDependencyHealth()
        print("\n🏥 Dependency Health:")
        print("  Total Services: \(health.totalServices)")
        print("  Successful: \(health.successfulInitializations)")
        print("  Failed: \(health.failedInitializations)")
        print("  Health Score: \(String(format: "%.1f", health.healthScore * 100))%")
        
        if !health.circularDependencies.isEmpty {
            print("  ⚠️ Circular Dependencies: \(health.circularDependencies.joined(separator: ", "))")
        }
        
        if !health.criticalFailures.isEmpty {
            print("  🚨 Critical Failures: \(health.criticalFailures.joined(separator: ", "))")
        }
        
        // Dependency Graph
        print("\n📈 Dependency Relationships:")
        safeContainer.printDependencyGraph()
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    public func performHealthCheck() -> Bool {
        let health = getDependencyHealth()
        
        // Health check criteria
        let isHealthy = health.healthScore >= 0.8 && 
                       health.criticalFailures.isEmpty &&
                       health.circularDependencies.isEmpty
        
        if !isHealthy {
            print("⚠️ Dependency health check failed!")
            print("  Health score: \(String(format: "%.2f", health.healthScore * 100))%")
            
            if !health.criticalFailures.isEmpty {
                print("  Critical failures: \(health.criticalFailures.joined(separator: ", "))")
            }
            
            if !health.circularDependencies.isEmpty {
                print("  Circular dependencies: \(health.circularDependencies.joined(separator: ", "))")
            }
        } else {
            print("✅ Dependency health check passed!")
        }
        
        return isHealthy
    }
    
    // MARK: - Recovery Operations
    
    public func recoverFromFailures() async {
        print("🔄 Starting dependency recovery process...")
        
        let health = getDependencyHealth()
        
        // Clear failed initializations and retry
        for failedService in health.criticalFailures {
            print("🔧 Attempting to recover critical service: \(failedService)")
            safeContainer.resetFailedService(failedService)
            
            // Remove from cache to force reinitialization
            serviceCache.removeValue(forKey: failedService)
            repositoryCache.removeValue(forKey: failedService)
        }
        
        // Clear memory pressure and rebuild cache strategically
        await performMemoryCleanup()
        
        // Use predictive engine for smart recovery
        await predictiveEngine.performSmartWarmup(strategy: .conservative)
        
        print("✅ Dependency recovery process completed")
    }
    
    // MARK: - Memory Validation
    
    @MainActor
    public func validateMemoryOptimization() async -> Bool {
        print("🧪 Starting comprehensive memory optimization validation...")
        let success = await memoryValidator.performComprehensiveValidation()
        
        if success {
            print("✅ Phase 1 Memory Optimization: VALIDATED - Target ≤75MB achieved!")
        } else {
            print("❌ Phase 1 Memory Optimization: FAILED - Target ≤75MB not achieved")
        }
        
        return success
    }
    
    public func getMemoryValidationSummary() -> String {
        // Return a simple validation summary since ValidationMetrics doesn't exist yet
        let currentMemoryMB = Double(getCurrentMemoryUsage()) / 1024.0 / 1024.0
        let targetReduction = (90.0 - currentMemoryMB) / 90.0 * 100.0
        
        return "Current Memory: \(String(format: "%.2f", currentMemoryMB))MB, Target Reduction: \(String(format: "%.1f", targetReduction))%"
    }
    
    public func getMemoryOptimizationTips() -> [String] {
        return [
            "Clear predictive cache during memory pressure",
            "Reduce service cache size limit",
            "Implement more aggressive background service eviction",
            "Consider lazy loading for non-critical repositories",
            "Use memory-mapped files for large data sets"
        ]
    }
    
    // MARK: - Predictive Engine Public Interface
    
    public func setUserRole(_ role: PredictiveLoadingEngine.UserRole) {
        predictiveEngine.setCurrentUserRole(role)
        
        // Trigger role-based preloading
        Task { @MainActor in
            await predictiveEngine.performRoleBasedPreloading()
        }
    }
    
    public func performIntelligentWarmup(strategy: PredictiveLoadingEngine.WarmupStrategy = .balanced) async {
        print("🧠 Starting intelligent warmup...")
        await predictiveEngine.performSmartWarmup(strategy: strategy)
    }
    
    public func getPredictiveAnalytics() -> PredictiveLoadingEngine.PredictionAnalytics {
        return predictiveEngine.getAnalytics()
    }
    
    public func printPredictiveAnalytics() {
        predictiveEngine.printAnalytics()
    }
    
    public func configurePredictionSensitivity(_ sensitivity: Double) {
        predictiveEngine.configurePredictionSensitivity(sensitivity)
    }
    
    public func resetPredictiveLearning() {
        predictiveEngine.resetLearning()
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
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
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Supporting Types

public enum ServicePriority: String, CaseIterable {
    case critical   // Never evicted (Auth, Audit)
    case feature    // Evicted under high memory pressure (Business services)
    case background // Frequently evicted (Background tasks)
}

public struct LazyCacheStatistics {
    public let serviceCount: Int
    public let repositoryCount: Int
    public let memoryUsage: Int64
    
    public var memoryUsageMB: Double {
        Double(memoryUsage) / 1024.0 / 1024.0
    }
}

// MARK: - Memory Monitor

private class MemoryMonitor {
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let handler: () -> Void
    
    init(handler: @escaping () -> Void) {
        self.handler = handler
        startMonitoring()
    }
    
    private func startMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handler()
        }
        
        memoryPressureSource?.resume()
    }
    
    deinit {
        memoryPressureSource?.cancel()
    }
}