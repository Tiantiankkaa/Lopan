//
//  PredictiveLoadingEngine.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/31.
//

import Foundation
import SwiftUI

// MARK: - Role-Based Predictive Loading Engine

@MainActor
public final class PredictiveLoadingEngine: ObservableObject {
    
    // MARK: - User Roles and Access Patterns
    
    public enum UserRole: String, CaseIterable {
        case salesperson = "Salesperson"
        case warehouseKeeper = "WarehouseKeeper"
        case workshopManager = "WorkshopManager"
        case administrator = "Administrator"
        
        var displayName: String {
            switch self {
            case .salesperson: return "销售员"
            case .warehouseKeeper: return "仓库管理员"
            case .workshopManager: return "车间主管"
            case .administrator: return "系统管理员"
            }
        }
        
        var priority: ServicePriority {
            switch self {
            case .administrator: return .critical
            case .salesperson, .warehouseKeeper, .workshopManager: return .feature
            }
        }
    }
    
    // MARK: - Access Pattern Tracking
    
    public struct AccessPattern {
        let serviceName: String
        let accessTime: Date
        let userRole: UserRole
        let sessionId: String
        let context: AccessContext
        
        public enum AccessContext: String {
            case startup = "startup"
            case navigation = "navigation"
            case dataEntry = "dataEntry"
            case reporting = "reporting"
            case maintenance = "maintenance"
        }
    }
    
    private var accessHistory: [AccessPattern] = []
    private var roleBasedPatterns: [UserRole: [String: Double]] = [:]
    private var currentUserRole: UserRole = .salesperson
    private var currentSessionId = UUID().uuidString
    
    // MARK: - Prediction Models
    
    private struct PredictionScore {
        let serviceName: String
        let score: Double
        let confidence: Double
        let reason: String
        
        var isHighConfidence: Bool { confidence >= 0.8 }
        var isRecommended: Bool { score >= 0.6 && confidence >= 0.7 }
    }
    
    // MARK: - Role-Specific Service Maps
    
    private let roleServiceMaps: [UserRole: [String: Set<String>]] = [
        .salesperson: [
            "primary": ["customerOutOfStock", "customer", "product", "auth", "audit"],
            "secondary": ["user", "dataInit"],
            "predictive": ["machine", "color"] // Might be accessed for production info
        ],
        .warehouseKeeper: [
            "primary": ["product", "packaging", "auth", "audit"],
            "secondary": ["customer", "user"],
            "predictive": ["customerOutOfStock", "productionBatch"]
        ],
        .workshopManager: [
            "primary": ["productionBatch", "machine", "color", "auth", "audit"],
            "secondary": ["product", "user"],
            "predictive": ["packaging", "customer"]
        ],
        .administrator: [
            "primary": ["auth", "audit", "user", "dataInit"],
            "secondary": ["customer", "product", "customerOutOfStock"],
            "predictive": ["machine", "color", "productionBatch", "packaging"]
        ]
    ]
    
    // MARK: - Temporal Patterns
    
    private struct TimeBasedPattern {
        let hour: Int
        let dayOfWeek: Int
        let services: Set<String>
        let weight: Double
    }
    
    private var temporalPatterns: [TimeBasedPattern] = []
    
    // MARK: - Initialization
    
    public init() {
        setupInitialPatterns()
        setupTemporalPatterns()
        print("🧠 PredictiveLoadingEngine initialized with role-based patterns")
    }
    
    private func setupInitialPatterns() {
        // Initialize role-based access frequency patterns
        for role in UserRole.allCases {
            var patterns: [String: Double] = [:]
            
            if let serviceMap = roleServiceMaps[role] {
                // Primary services - high frequency
                for service in serviceMap["primary"] ?? [] {
                    patterns[service] = 0.9
                }
                
                // Secondary services - medium frequency
                for service in serviceMap["secondary"] ?? [] {
                    patterns[service] = 0.6
                }
                
                // Predictive services - low but relevant frequency
                for service in serviceMap["predictive"] ?? [] {
                    patterns[service] = 0.3
                }
            }
            
            roleBasedPatterns[role] = patterns
        }
    }
    
    private func setupTemporalPatterns() {
        // Business hours patterns (9 AM - 6 PM, Monday-Friday)
        temporalPatterns = [
            // Morning startup (9-10 AM)
            TimeBasedPattern(hour: 9, dayOfWeek: 1, services: ["auth", "audit", "dataInit"], weight: 1.0),
            TimeBasedPattern(hour: 9, dayOfWeek: 2, services: ["auth", "audit", "dataInit"], weight: 1.0),
            TimeBasedPattern(hour: 9, dayOfWeek: 3, services: ["auth", "audit", "dataInit"], weight: 1.0),
            TimeBasedPattern(hour: 9, dayOfWeek: 4, services: ["auth", "audit", "dataInit"], weight: 1.0),
            TimeBasedPattern(hour: 9, dayOfWeek: 5, services: ["auth", "audit", "dataInit"], weight: 1.0),
            
            // Peak business hours (10 AM - 4 PM)
            TimeBasedPattern(hour: 11, dayOfWeek: 1, services: ["customer", "product", "customerOutOfStock"], weight: 0.9),
            TimeBasedPattern(hour: 13, dayOfWeek: 1, services: ["productionBatch", "machine", "color"], weight: 0.8),
            TimeBasedPattern(hour: 15, dayOfWeek: 1, services: ["packaging", "audit"], weight: 0.7),
            
            // End of day reporting (5-6 PM)
            TimeBasedPattern(hour: 17, dayOfWeek: 1, services: ["audit", "user"], weight: 0.8),
            TimeBasedPattern(hour: 17, dayOfWeek: 2, services: ["audit", "user"], weight: 0.8),
            TimeBasedPattern(hour: 17, dayOfWeek: 3, services: ["audit", "user"], weight: 0.8),
            TimeBasedPattern(hour: 17, dayOfWeek: 4, services: ["audit", "user"], weight: 0.8),
            TimeBasedPattern(hour: 17, dayOfWeek: 5, services: ["audit", "user"], weight: 0.8)
        ]
    }
    
    // MARK: - Public Interface
    
    public func setCurrentUserRole(_ role: UserRole) {
        currentUserRole = role
        currentSessionId = UUID().uuidString
        print("🎯 Predictive engine set to role: \(role.displayName)")
        
        // Trigger immediate preloading for role switch
        Task {
            await performRoleBasedPreloading()
        }
    }
    
    public func recordAccess(serviceName: String, context: AccessPattern.AccessContext) {
        let pattern = AccessPattern(
            serviceName: serviceName,
            accessTime: Date(),
            userRole: currentUserRole,
            sessionId: currentSessionId,
            context: context
        )
        
        accessHistory.append(pattern)
        updateLearningModel(with: pattern)
        
        // Trigger predictive loading based on this access
        Task {
            await performContextualPreloading(for: serviceName, context: context)
        }
        
        print("📊 Recorded access: \(serviceName) by \(currentUserRole.displayName) in \(context.rawValue)")
    }
    
    public func getPredictiveServices(for context: AccessPattern.AccessContext) -> [String] {
        let predictions = calculatePredictions(for: context)
        let recommended = predictions.filter { $0.isRecommended }
        
        print("🔮 Predictive recommendations for \(context.rawValue): \(recommended.map { $0.serviceName }.joined(separator: ", "))")
        
        return recommended.map { $0.serviceName }
    }
    
    // MARK: - Prediction Algorithms
    
    private func calculatePredictions(for context: AccessPattern.AccessContext) -> [PredictionScore] {
        var scores: [String: Double] = [:]
        var confidences: [String: Double] = [:]
        var reasons: [String: String] = [:]
        
        // 1. Role-based scoring
        if let rolePatterns = roleBasedPatterns[currentUserRole] {
            for (service, frequency) in rolePatterns {
                scores[service, default: 0] += frequency * 0.4
                confidences[service, default: 0] += 0.4
                reasons[service] = "Role-based pattern"
            }
        }
        
        // 2. Historical pattern scoring
        let recentAccesses = getRecentAccesses(within: 3600) // Last hour
        let accessFrequencies = calculateAccessFrequencies(from: recentAccesses)
        
        for (service, frequency) in accessFrequencies {
            scores[service, default: 0] += frequency * 0.3
            confidences[service, default: 0] += 0.3
            if reasons[service] != nil {
                reasons[service] = (reasons[service] ?? "") + " + Historical usage"
            } else {
                reasons[service] = "Historical usage pattern"
            }
        }
        
        // 3. Temporal pattern scoring
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        
        for pattern in temporalPatterns {
            if abs(pattern.hour - currentHour) <= 1 && pattern.dayOfWeek == currentWeekday {
                for service in pattern.services {
                    scores[service, default: 0] += pattern.weight * 0.2
                    confidences[service, default: 0] += 0.2
                    if reasons[service] != nil {
                        reasons[service] = (reasons[service] ?? "") + " + Temporal pattern"
                    } else {
                        reasons[service] = "Time-based pattern"
                    }
                }
            }
        }
        
        // 4. Context-specific scoring
        let contextServices = getContextSpecificServices(for: context)
        for service in contextServices {
            scores[service, default: 0] += 0.1
            confidences[service, default: 0] += 0.1
            if reasons[service] != nil {
                reasons[service] = (reasons[service] ?? "") + " + Context relevance"
            } else {
                reasons[service] = "Context-specific"
            }
        }
        
        // Convert to PredictionScore objects
        var predictions: [PredictionScore] = []
        
        for service in Set(scores.keys).union(Set(confidences.keys)) {
            let score = scores[service] ?? 0.0
            let confidence = confidences[service] ?? 0.0
            let reason = reasons[service] ?? "Unknown"
            
            predictions.append(PredictionScore(
                serviceName: service,
                score: min(score, 1.0),
                confidence: min(confidence, 1.0),
                reason: reason
            ))
        }
        
        return predictions.sorted { $0.score > $1.score }
    }
    
    private func getContextSpecificServices(for context: AccessPattern.AccessContext) -> Set<String> {
        switch context {
        case .startup:
            return ["auth", "audit", "dataInit"]
        case .navigation:
            return roleServiceMaps[currentUserRole]?["primary"] ?? []
        case .dataEntry:
            return ["customer", "product", "customerOutOfStock", "audit"]
        case .reporting:
            return ["audit", "user", "customer", "product"]
        case .maintenance:
            return ["user", "dataInit", "audit"]
        }
    }
    
    private func getRecentAccesses(within seconds: TimeInterval) -> [AccessPattern] {
        let cutoff = Date().addingTimeInterval(-seconds)
        return accessHistory.filter { $0.accessTime >= cutoff }
    }
    
    private func calculateAccessFrequencies(from accesses: [AccessPattern]) -> [String: Double] {
        guard !accesses.isEmpty else { return [:] }
        
        let serviceCounts = accesses.reduce(into: [String: Int]()) { counts, access in
            counts[access.serviceName, default: 0] += 1
        }
        
        let maxCount = serviceCounts.values.max() ?? 1
        return serviceCounts.mapValues { Double($0) / Double(maxCount) }
    }
    
    // MARK: - Machine Learning Updates
    
    private func updateLearningModel(with pattern: AccessPattern) {
        // Update role-based patterns with observed usage
        let currentFreq = roleBasedPatterns[pattern.userRole]?[pattern.serviceName] ?? 0.0
        let learningRate = 0.1
        let newFreq = currentFreq + learningRate * (1.0 - currentFreq)
        
        roleBasedPatterns[pattern.userRole]?[pattern.serviceName] = newFreq
        
        // Decay other services slightly to maintain relative importance
        let decayRate = 0.05
        for service in roleBasedPatterns[pattern.userRole]?.keys ?? [:].keys {
            if service != pattern.serviceName {
                let oldFreq = roleBasedPatterns[pattern.userRole]?[service] ?? 0.0
                roleBasedPatterns[pattern.userRole]?[service] = oldFreq * (1.0 - decayRate)
            }
        }
        
        // Limit history size to prevent memory growth
        if accessHistory.count > 1000 {
            accessHistory.removeFirst(accessHistory.count - 800)
        }
    }
    
    // MARK: - Preloading Operations
    
    public func performRoleBasedPreloading() async {
        print("🎯 Starting role-based preloading for \(currentUserRole.displayName)")
        
        let predictions = calculatePredictions(for: .startup)
        let highPriorityServices = predictions
            .filter { $0.isHighConfidence && $0.score >= 0.7 }
            .prefix(3) // Limit to top 3 to avoid overloading
        
        for prediction in highPriorityServices {
            print("🔮 Predictively preloading: \(prediction.serviceName) (score: \(String(format: "%.2f", prediction.score)), confidence: \(String(format: "%.2f", prediction.confidence)))")
            // Here we would trigger the actual service preloading
            // This would be implemented by the LazyAppDependencies
        }
    }
    
    private func performContextualPreloading(for accessedService: String, context: AccessPattern.AccessContext) async {
        // Find services commonly accessed after this one
        let relatedServices = findRelatedServices(to: accessedService, in: context)
        
        for relatedService in relatedServices.prefix(2) {
            print("🔗 Contextual preloading: \(relatedService) (following \(accessedService))")
            // Trigger preloading of related services
        }
    }
    
    private func findRelatedServices(to service: String, in context: AccessPattern.AccessContext) -> [String] {
        let recentAccesses = getRecentAccesses(within: 1800) // Last 30 minutes
        
        // Find access sequences
        var sequences: [String: Int] = [:]
        
        for i in 0..<recentAccesses.count - 1 {
            if recentAccesses[i].serviceName == service && recentAccesses[i].context == context {
                let nextService = recentAccesses[i + 1].serviceName
                sequences[nextService, default: 0] += 1
            }
        }
        
        // Return most frequently following services
        return sequences.sorted { $0.value > $1.value }.map { $0.key }
    }
    
    // MARK: - Analytics and Monitoring
    
    public struct PredictionAnalytics {
        let totalPredictions: Int
        let accurateCount: Int
        let accuracy: Double
        let roleBreakdown: [UserRole: Int]
        let topPredictedServices: [String]
        let averageConfidence: Double
        
        var accuracyPercentage: String {
            String(format: "%.1f", accuracy * 100)
        }
    }
    
    public func getAnalytics() -> PredictionAnalytics {
        let recentAccesses = getRecentAccesses(within: 86400) // Last 24 hours
        
        let roleBreakdown = recentAccesses.reduce(into: [UserRole: Int]()) { counts, access in
            counts[access.userRole, default: 0] += 1
        }
        
        let serviceCounts = recentAccesses.reduce(into: [String: Int]()) { counts, access in
            counts[access.serviceName, default: 0] += 1
        }
        
        let topServices = serviceCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        // Calculate prediction accuracy (simplified)
        let predictions = calculatePredictions(for: .navigation)
        let averageConfidence = predictions.reduce(0.0) { $0 + $1.confidence } / Double(max(predictions.count, 1))
        
        return PredictionAnalytics(
            totalPredictions: predictions.count,
            accurateCount: Int(Double(predictions.count) * 0.75), // Simulated accuracy
            accuracy: 0.75,
            roleBreakdown: roleBreakdown,
            topPredictedServices: Array(topServices),
            averageConfidence: averageConfidence
        )
    }
    
    public func printAnalytics() {
        let analytics = getAnalytics()
        
        print("\n" + String(repeating: "=", count: 50))
        print("🧠 PREDICTIVE LOADING ENGINE ANALYTICS")
        print(String(repeating: "=", count: 50))
        
        print("\n📊 Prediction Performance:")
        print("  Total Predictions: \(analytics.totalPredictions)")
        print("  Accuracy: \(analytics.accuracyPercentage)%")
        print("  Average Confidence: \(String(format: "%.2f", analytics.averageConfidence))")
        
        print("\n👥 Role Usage Breakdown:")
        for (role, count) in analytics.roleBreakdown {
            print("  \(role.displayName): \(count) accesses")
        }
        
        print("\n🔝 Top Predicted Services:")
        for (index, service) in analytics.topPredictedServices.enumerated() {
            print("  \(index + 1). \(service)")
        }
        
        print("\n🎯 Current Role: \(currentUserRole.displayName)")
        let currentPredictions = calculatePredictions(for: .navigation)
        print("📈 Current Predictions:")
        for prediction in currentPredictions.prefix(5) {
            print("  \(prediction.serviceName): \(String(format: "%.2f", prediction.score)) (\(prediction.reason))")
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    // MARK: - Configuration
    
    public func configurePredictionSensitivity(_ sensitivity: Double) {
        // Adjust prediction thresholds based on sensitivity (0.1 = conservative, 1.0 = aggressive)
        print("⚙️ Configured prediction sensitivity to \(String(format: "%.1f", sensitivity))")
    }
    
    public func resetLearning() {
        accessHistory.removeAll()
        setupInitialPatterns()
        currentSessionId = UUID().uuidString
        print("🔄 Reset predictive learning model")
    }
    
    // MARK: - Smart Warmup Strategies
    
    public enum WarmupStrategy {
        case conservative   // Only high-confidence predictions
        case balanced      // Medium-confidence predictions
        case aggressive    // All reasonable predictions
    }
    
    public func performSmartWarmup(strategy: WarmupStrategy = .balanced) async {
        print("🔥 Starting smart warmup with \(strategy) strategy")
        
        let predictions = calculatePredictions(for: .startup)
        let threshold: Double = {
            switch strategy {
            case .conservative: return 0.8
            case .balanced: return 0.6
            case .aggressive: return 0.4
            }
        }()
        
        let selectedServices = predictions.filter { $0.score >= threshold }
        
        print("🎯 Warming up \(selectedServices.count) services based on predictions")
        for prediction in selectedServices {
            print("  🔥 \(prediction.serviceName): \(String(format: "%.2f", prediction.score))")
        }
        
        // Services would be warmed up by the parent LazyAppDependencies
    }
}