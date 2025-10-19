//
//  SafeLazyDependencyContainer.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import Foundation
import SwiftUI

// MARK: - Circular Dependency Detection and Safe Initialization

@MainActor
public final class SafeLazyDependencyContainer: ObservableObject {
    
    // MARK: - Dependency Tracking
    private var initializationStack: Set<String> = []
    private var dependencyGraph: [String: Set<String>] = [:]
    private var initializationOrder: [String] = []
    private var failedInitializations: Set<String> = []
    
    // MARK: - Thread Safety
    private let isolationQueue = DispatchQueue(label: "com.lopan.dependency.isolation", qos: .userInitiated)
    
    // MARK: - Error Types
    public enum DependencyError: Error, LocalizedError {
        case circularDependency(path: [String])
        case initializationFailed(service: String, underlyingError: Error)
        case maxRetryExceeded(service: String)
        case dependencyUnavailable(service: String, missingDependency: String)
        
        public var errorDescription: String? {
            switch self {
            case .circularDependency(let path):
                return "Circular dependency detected: \(path.joined(separator: " → "))"
            case .initializationFailed(let service, let error):
                return "Failed to initialize \(service): \(error.localizedDescription)"
            case .maxRetryExceeded(let service):
                return "Maximum retry attempts exceeded for service: \(service)"
            case .dependencyUnavailable(let service, let dependency):
                return "Service \(service) requires unavailable dependency: \(dependency)"
            }
        }
    }
    
    // MARK: - Initialization Context
    public struct InitializationContext {
        let serviceName: String
        let priority: ServicePriority
        let dependencies: Set<String>
        let retryCount: Int
        let timestamp: Date
        
        init(serviceName: String, priority: ServicePriority, dependencies: Set<String> = [], retryCount: Int = 0) {
            self.serviceName = serviceName
            self.priority = priority
            self.dependencies = dependencies
            self.retryCount = retryCount
            self.timestamp = Date()
        }
    }
    
    // MARK: - Safe Initialization
    public func safeInitialize<T>(
        serviceName: String,
        priority: ServicePriority,
        dependencies: Set<String> = [],
        factory: () throws -> T
    ) throws -> T {
        // Check for circular dependency before attempting initialization
        try detectCircularDependency(serviceName: serviceName, dependencies: dependencies)
        
        // Record dependency relationships
        dependencyGraph[serviceName] = dependencies
        
        // Check if we can safely initialize (all dependencies available)
        try validateDependencyAvailability(serviceName: serviceName, dependencies: dependencies)
        
        // Track initialization start
        initializationStack.insert(serviceName)
        defer { initializationStack.remove(serviceName) }
        
        do {
            print("🔧 Safe initializing service: \(serviceName) with priority: \(priority)")
            let result = try factory()
            
            // Record successful initialization
            initializationOrder.append(serviceName)
            failedInitializations.remove(serviceName)
            
            print("✅ Successfully initialized service: \(serviceName)")
            return result
            
        } catch {
            // Record failed initialization
            failedInitializations.insert(serviceName)
            
            print("❌ Failed to initialize service: \(serviceName), error: \(error)")
            throw DependencyError.initializationFailed(service: serviceName, underlyingError: error)
        }
    }
    
    // MARK: - Circular Dependency Detection
    private func detectCircularDependency(serviceName: String, dependencies: Set<String>) throws {
        // Check if service is already in initialization stack
        if initializationStack.contains(serviceName) {
            let path = Array(initializationStack) + [serviceName]
            throw DependencyError.circularDependency(path: path)
        }
        
        // Check for indirect circular dependencies using DFS
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        
        try performCircularDependencyCheck(
            current: serviceName,
            dependencies: dependencies,
            visited: &visited,
            recursionStack: &recursionStack
        )
    }
    
    private func performCircularDependencyCheck(
        current: String,
        dependencies: Set<String>,
        visited: inout Set<String>,
        recursionStack: inout Set<String>
    ) throws {
        visited.insert(current)
        recursionStack.insert(current)
        
        // Check all dependencies of current service
        for dependency in dependencies {
            if !visited.contains(dependency) {
                // Recursively check dependency's dependencies
                let dependencyDeps = dependencyGraph[dependency] ?? []
                try performCircularDependencyCheck(
                    current: dependency,
                    dependencies: dependencyDeps,
                    visited: &visited,
                    recursionStack: &recursionStack
                )
            } else if recursionStack.contains(dependency) {
                // Found circular dependency
                let path = Array(recursionStack) + [dependency]
                throw DependencyError.circularDependency(path: path)
            }
        }
        
        recursionStack.remove(current)
    }
    
    // MARK: - Dependency Availability Validation
    private func validateDependencyAvailability(serviceName: String, dependencies: Set<String>) throws {
        for dependency in dependencies {
            // Check if dependency has failed initialization recently
            if failedInitializations.contains(dependency) {
                throw DependencyError.dependencyUnavailable(service: serviceName, missingDependency: dependency)
            }
        }
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    public func initializeWithRetry<T>(
        serviceName: String,
        priority: ServicePriority,
        dependencies: Set<String> = [],
        maxRetries: Int = 3,
        factory: @escaping () throws -> T
    ) async throws -> T {
        var _lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try safeInitialize(
                    serviceName: serviceName,
                    priority: priority,
                    dependencies: dependencies,
                    factory: factory
                )
            } catch {
                _lastError = error
                
                // Don't retry circular dependency errors
                if case .circularDependency = error as? DependencyError {
                    throw error
                }
                
                // Exponential backoff for retry
                let delay = min(pow(2.0, Double(attempt)) * 0.1, 2.0) // Max 2 seconds
                print("⚠️ Retry attempt \(attempt + 1)/\(maxRetries) for \(serviceName) in \(delay)s")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted
        throw DependencyError.maxRetryExceeded(service: serviceName)
    }
    
    // MARK: - Dependency Ordering
    public func getOptimalInitializationOrder() -> [String] {
        var ordered: [String] = []
        var visited: Set<String> = []
        
        // Topological sort to determine optimal initialization order
        for serviceName in dependencyGraph.keys {
            if !visited.contains(serviceName) {
                topologicalSort(serviceName: serviceName, visited: &visited, ordered: &ordered)
            }
        }
        
        return ordered.reversed()
    }
    
    private func topologicalSort(serviceName: String, visited: inout Set<String>, ordered: inout [String]) {
        visited.insert(serviceName)
        
        let dependencies = dependencyGraph[serviceName] ?? []
        for dependency in dependencies {
            if !visited.contains(dependency) {
                topologicalSort(serviceName: dependency, visited: &visited, ordered: &ordered)
            }
        }
        
        ordered.append(serviceName)
    }
    
    // MARK: - Health Monitoring
    public struct DependencyHealth {
        let totalServices: Int
        let successfulInitializations: Int
        let failedInitializations: Int
        let circularDependencies: [String]
        let averageInitializationTime: TimeInterval
        let criticalFailures: [String]
        
        var healthScore: Double {
            guard totalServices > 0 else { return 1.0 }
            let successRate = Double(successfulInitializations) / Double(totalServices)
            let circularPenalty = Double(circularDependencies.count) * 0.1
            let criticalPenalty = Double(criticalFailures.count) * 0.2
            
            return max(0.0, successRate - circularPenalty - criticalPenalty)
        }
    }
    
    public func getDependencyHealth() -> DependencyHealth {
        let totalServices = dependencyGraph.count
        let successfulCount = totalServices - failedInitializations.count
        let failedCount = failedInitializations.count
        
        // Detect current circular dependencies
        let circularDeps = detectExistingCircularDependencies()
        
        // Identify critical service failures
        let criticalFailures = failedInitializations.filter { serviceName in
            // Critical services are those with high fan-out (many dependents)
            let dependentCount = dependencyGraph.values.reduce(0) { count, deps in
                count + (deps.contains(serviceName) ? 1 : 0)
            }
            return dependentCount >= 3
        }
        
        return DependencyHealth(
            totalServices: totalServices,
            successfulInitializations: successfulCount,
            failedInitializations: failedCount,
            circularDependencies: Array(circularDeps),
            averageInitializationTime: 0.1, // Would be calculated from actual timing data
            criticalFailures: Array(criticalFailures)
        )
    }
    
    private func detectExistingCircularDependencies() -> Set<String> {
        var circularServices: Set<String> = []
        var visited: Set<String> = []
        
        for serviceName in dependencyGraph.keys {
            if !visited.contains(serviceName) {
                var recursionStack: Set<String> = []
                detectCircularInGraph(
                    current: serviceName,
                    visited: &visited,
                    recursionStack: &recursionStack,
                    circularServices: &circularServices
                )
            }
        }
        
        return circularServices
    }
    
    private func detectCircularInGraph(
        current: String,
        visited: inout Set<String>,
        recursionStack: inout Set<String>,
        circularServices: inout Set<String>
    ) {
        visited.insert(current)
        recursionStack.insert(current)
        
        let dependencies = dependencyGraph[current] ?? []
        for dependency in dependencies {
            if !visited.contains(dependency) {
                detectCircularInGraph(
                    current: dependency,
                    visited: &visited,
                    recursionStack: &recursionStack,
                    circularServices: &circularServices
                )
            } else if recursionStack.contains(dependency) {
                // Found circular dependency
                circularServices.insert(current)
                circularServices.insert(dependency)
            }
        }
        
        recursionStack.remove(current)
    }
    
    // MARK: - Debug Information
    public func printDependencyGraph() {
        print("📊 Dependency Graph:")
        for (service, dependencies) in dependencyGraph {
            let depString = dependencies.isEmpty ? "None" : dependencies.joined(separator: ", ")
            print("  \(service) → [\(depString)]")
        }
        
        print("\n📈 Initialization Statistics:")
        print("  Total services: \(dependencyGraph.count)")
        print("  Successfully initialized: \(initializationOrder.count)")
        print("  Failed initializations: \(failedInitializations.count)")
        
        if !failedInitializations.isEmpty {
            print("  Failed services: \(failedInitializations.joined(separator: ", "))")
        }
        
        let health = getDependencyHealth()
        print("  Health score: \(String(format: "%.2f", health.healthScore * 100))%")
    }
    
    // MARK: - Recovery Operations
    public func resetFailedService(_ serviceName: String) {
        failedInitializations.remove(serviceName)
        print("🔄 Reset failed service: \(serviceName)")
    }
    
    public func clearAllFailures() {
        let count = failedInitializations.count
        failedInitializations.removeAll()
        print("🧹 Cleared \(count) failed service initializations")
    }
    
    // MARK: - Graceful Shutdown
    public func shutdownDependencies() {
        let shutdownOrder = initializationOrder.reversed()
        print("🛑 Shutting down dependencies in reverse order:")
        
        for serviceName in shutdownOrder {
            print("  Shutting down: \(serviceName)")
            // Here we would call cleanup methods if services had them
        }
        
        // Clear all tracking data
        initializationStack.removeAll()
        dependencyGraph.removeAll()
        initializationOrder.removeAll()
        failedInitializations.removeAll()
        
        print("✅ Dependency shutdown complete")
    }
}

// MARK: - Enhanced Service Priority with Dependency Information

extension ServicePriority {
    
    /// Get the typical dependencies for services of this priority level
    var typicalDependencies: Set<String> {
        switch self {
        case .critical:
            return [] // Critical services should have minimal dependencies
        case .feature:
            return ["auth", "audit"] // Feature services typically depend on critical services
        case .background:
            return ["auth", "audit"] // Background services also need basic critical services
        }
    }
    
    /// Get the maximum allowed dependency depth for this priority level
    var maxDependencyDepth: Int {
        switch self {
        case .critical:
            return 0 // Critical services should be self-contained
        case .feature:
            return 2 // Feature services can have moderate dependency chains
        case .background:
            return 3 // Background services can have deeper dependency chains
        }
    }
    
    /// Get the initialization timeout for this priority level
    var initializationTimeout: TimeInterval {
        switch self {
        case .critical:
            return 1.0 // Critical services must initialize quickly
        case .feature:
            return 3.0 // Feature services get reasonable time
        case .background:
            return 5.0 // Background services can take longer
        }
    }
}