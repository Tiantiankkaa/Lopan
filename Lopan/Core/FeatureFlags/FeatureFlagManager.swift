//
//  FeatureFlagManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  Progressive feature rollout system for iOS 26 modernization
//

import SwiftUI
import Foundation
import os.log

// MARK: - Feature Flag Manager

@MainActor
public final class FeatureFlagManager: ObservableObject {
    nonisolated(unsafe) public static let shared = FeatureFlagManager()

    private let logger = Logger(subsystem: "com.lopan.featureflags", category: "FeatureManagement")
    private let userDefaults = UserDefaults.standard
    private let compatibilityLayer = iOS26CompatibilityLayer.shared

    // MARK: - Feature Definitions

    public enum Feature: String, CaseIterable {
        // Phase 1: Foundation
        case observablePattern = "observable_pattern"
        case compatibilityLayer = "compatibility_layer"
        case performanceMonitoring = "performance_monitoring"

        // Phase 2: Visual Modernization
        case glassMorphismV2 = "glass_morphism_v2"
        case fluidAnimations = "fluid_animations"
        case adaptiveLayouts = "adaptive_layouts"
        case spatialHierarchy = "spatial_hierarchy"

        // Phase 3: Interaction Enhancement
        case spatialNavigation = "spatial_navigation"
        case pressureGestures = "pressure_gestures"
        case intelligentPreloading = "intelligent_preloading"
        case predictiveUI = "predictive_ui"

        // Phase 4: Performance & Accessibility
        case enhancedAccessibility = "enhanced_accessibility"
        case spatialAudio = "spatial_audio"
        case metalRendering = "metal_rendering"
        case backgroundOptimization = "background_optimization"

        public var displayName: String {
            switch self {
            case .observablePattern:
                return "Observable Pattern Migration"
            case .compatibilityLayer:
                return "iOS 26 Compatibility Layer"
            case .performanceMonitoring:
                return "Performance Monitoring"
            case .glassMorphismV2:
                return "Glass Morphism v2"
            case .fluidAnimations:
                return "Fluid Animations"
            case .adaptiveLayouts:
                return "Adaptive Layouts"
            case .spatialHierarchy:
                return "Spatial Hierarchy"
            case .spatialNavigation:
                return "Spatial Navigation"
            case .pressureGestures:
                return "Pressure Gestures"
            case .intelligentPreloading:
                return "Intelligent Preloading"
            case .predictiveUI:
                return "Predictive UI"
            case .enhancedAccessibility:
                return "Enhanced Accessibility"
            case .spatialAudio:
                return "Spatial Audio"
            case .metalRendering:
                return "Metal Rendering"
            case .backgroundOptimization:
                return "Background Optimization"
            }
        }

        public var description: String {
            switch self {
            case .observablePattern:
                return "Modern @Observable state management for iOS 26"
            case .compatibilityLayer:
                return "Version-aware feature detection and fallbacks"
            case .performanceMonitoring:
                return "Real-time performance tracking and optimization"
            case .glassMorphismV2:
                return "Enhanced glass materials with liquid effects"
            case .fluidAnimations:
                return "Smooth spring animations and micro-interactions"
            case .adaptiveLayouts:
                return "Container-relative and responsive layouts"
            case .spatialHierarchy:
                return "Depth-based visual hierarchy system"
            case .spatialNavigation:
                return "Gesture-driven spatial transitions"
            case .pressureGestures:
                return "3D Touch and pressure-sensitive interactions"
            case .intelligentPreloading:
                return "ML-powered predictive view preloading"
            case .predictiveUI:
                return "User behavior prediction and adaptive interface"
            case .enhancedAccessibility:
                return "iOS 26 accessibility features and spatial audio"
            case .spatialAudio:
                return "3D audio cues for VoiceOver navigation"
            case .metalRendering:
                return "Hardware-accelerated UI rendering"
            case .backgroundOptimization:
                return "Enhanced background task processing"
            }
        }

        public var phase: Int {
            switch self {
            case .observablePattern, .compatibilityLayer, .performanceMonitoring:
                return 1
            case .glassMorphismV2, .fluidAnimations, .adaptiveLayouts, .spatialHierarchy:
                return 2
            case .spatialNavigation, .pressureGestures, .intelligentPreloading, .predictiveUI:
                return 3
            case .enhancedAccessibility, .spatialAudio, .metalRendering, .backgroundOptimization:
                return 4
            }
        }

        public var requiresIOS26: Bool {
            switch self {
            case .compatibilityLayer, .performanceMonitoring:
                return false // These work on all versions
            default:
                return true // Most features require iOS 26
            }
        }

        public var riskLevel: RiskLevel {
            switch self {
            case .compatibilityLayer, .performanceMonitoring:
                return .low
            case .observablePattern, .glassMorphismV2, .fluidAnimations:
                return .low
            case .adaptiveLayouts, .spatialHierarchy, .enhancedAccessibility:
                return .medium
            case .spatialNavigation, .intelligentPreloading, .spatialAudio:
                return .medium
            case .pressureGestures, .predictiveUI, .metalRendering, .backgroundOptimization:
                return .high
            }
        }
    }

    public enum RiskLevel: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3

        public var displayName: String {
            switch self {
            case .low: return "Low Risk"
            case .medium: return "Medium Risk"
            case .high: return "High Risk"
            }
        }

        public var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }

    // MARK: - Feature State Management

    @Published public private(set) var enabledFeatures: Set<Feature> = []
    @Published public private(set) var rolloutPercentages: [Feature: Double] = [:]
    @Published public private(set) var featureMetrics: [Feature: FeatureMetrics] = [:]

    public struct FeatureMetrics {
        public let enabledAt: Date
        public let usageCount: Int
        public let averagePerformance: TimeInterval
        public let errorRate: Double
        public let userSatisfaction: Double?

        public var isHealthy: Bool {
            errorRate < 0.05 && averagePerformance < 1.0
        }

        public var healthScore: Double {
            let performanceScore = max(0, 1.0 - (averagePerformance / 2.0))
            let errorScore = max(0, 1.0 - (errorRate * 20))
            let satisfactionScore = userSatisfaction ?? 0.8

            return (performanceScore + errorScore + satisfactionScore) / 3.0
        }
    }

    nonisolated private init() {
        Task { @MainActor in
            loadFeatureStates()
            logInitialState()
        }
    }

    // MARK: - Feature Control

    public func isEnabled(_ feature: Feature) -> Bool {
        // Check if feature is compatible with current iOS version
        guard isFeatureCompatible(feature) else {
            logger.debug("🚫 Feature \(feature.rawValue) not compatible with current iOS version")
            return false
        }

        // Check manual override
        if let override = getManualOverride(feature) {
            return override
        }

        // Check rollout percentage
        let rolloutPercentage = rolloutPercentages[feature] ?? 0.0
        let userHash = getUserHash()
        let shouldEnable = (userHash % 100) < Int(rolloutPercentage * 100)

        return enabledFeatures.contains(feature) && shouldEnable
    }

    public func enable(_ feature: Feature, rolloutPercentage: Double = 100.0) {
        guard isFeatureCompatible(feature) else {
            logger.warning("❌ Cannot enable incompatible feature: \(feature.rawValue)")
            return
        }

        enabledFeatures.insert(feature)
        rolloutPercentages[feature] = min(100.0, max(0.0, rolloutPercentage))

        // Initialize metrics
        if featureMetrics[feature] == nil {
            featureMetrics[feature] = FeatureMetrics(
                enabledAt: Date(),
                usageCount: 0,
                averagePerformance: 0.0,
                errorRate: 0.0,
                userSatisfaction: nil
            )
        }

        saveFeatureStates()
        logger.info("✅ Feature enabled: \(feature.displayName) (\(String(format: "%.1f", rolloutPercentage))%)")
    }

    public func disable(_ feature: Feature) {
        enabledFeatures.remove(feature)
        rolloutPercentages.removeValue(forKey: feature)

        saveFeatureStates()
        logger.info("🔴 Feature disabled: \(feature.displayName)")
    }

    public func setRolloutPercentage(_ feature: Feature, percentage: Double) {
        let clampedPercentage = min(100.0, max(0.0, percentage))
        rolloutPercentages[feature] = clampedPercentage

        saveFeatureStates()
        logger.info("📊 Rollout updated: \(feature.displayName) -> \(String(format: "%.1f", clampedPercentage))%")
    }

    // MARK: - Bulk Operations

    public func enablePhase(_ phase: Int, rolloutPercentage: Double = 100.0) {
        let phaseFeatures = Feature.allCases.filter { $0.phase == phase }

        for feature in phaseFeatures {
            enable(feature, rolloutPercentage: rolloutPercentage)
        }

        logger.info("🚀 Phase \(phase) enabled with \(String(format: "%.1f", rolloutPercentage))% rollout")
    }

    public func disablePhase(_ phase: Int) {
        let phaseFeatures = Feature.allCases.filter { $0.phase == phase }

        for feature in phaseFeatures {
            disable(feature)
        }

        logger.info("⏸️ Phase \(phase) disabled")
    }

    public func enableLowRiskFeatures() {
        let lowRiskFeatures = Feature.allCases.filter { $0.riskLevel == .low }

        for feature in lowRiskFeatures {
            enable(feature, rolloutPercentage: 100.0)
        }

        logger.info("🔓 All low-risk features enabled")
    }

    // MARK: - Feature Health Monitoring

    public func recordFeatureUsage(_ feature: Feature, performance: TimeInterval, success: Bool) {
        guard let metrics = featureMetrics[feature] else { return }

        let newUsageCount = metrics.usageCount + 1
        let newAveragePerformance = (metrics.averagePerformance * Double(metrics.usageCount) + performance) / Double(newUsageCount)
        let newErrorRate = success ?
            (metrics.errorRate * Double(metrics.usageCount)) / Double(newUsageCount) :
            (metrics.errorRate * Double(metrics.usageCount) + 1.0) / Double(newUsageCount)

        featureMetrics[feature] = FeatureMetrics(
            enabledAt: metrics.enabledAt,
            usageCount: newUsageCount,
            averagePerformance: newAveragePerformance,
            errorRate: newErrorRate,
            userSatisfaction: metrics.userSatisfaction
        )

        // Auto-disable unhealthy features
        if let updatedMetrics = featureMetrics[feature], !updatedMetrics.isHealthy {
            logger.warning("⚠️ Feature \(feature.displayName) showing poor health metrics")

            if updatedMetrics.errorRate > 0.1 { // 10% error rate threshold
                logger.critical("🚨 Auto-disabling feature due to high error rate: \(feature.displayName)")
                disable(feature)
            }
        }
    }

    public func getFeatureHealth(_ feature: Feature) -> FeatureMetrics? {
        return featureMetrics[feature]
    }

    public func getHealthyFeatures() -> [Feature] {
        return enabledFeatures.filter { feature in
            guard let metrics = featureMetrics[feature] else { return true }
            return metrics.isHealthy
        }
    }

    public func getUnhealthyFeatures() -> [Feature] {
        return enabledFeatures.filter { feature in
            guard let metrics = featureMetrics[feature] else { return false }
            return !metrics.isHealthy
        }
    }

    // MARK: - Emergency Controls

    public func emergencyDisableAll() {
        logger.critical("🚨 EMERGENCY: Disabling all features")

        enabledFeatures.removeAll()
        rolloutPercentages.removeAll()
        saveFeatureStates()

        logger.critical("🔴 All features disabled for emergency")
    }

    public func emergencyRollback(to safeFeatures: [Feature]) {
        logger.critical("🚨 EMERGENCY ROLLBACK: Rolling back to safe feature set")

        enabledFeatures = Set(safeFeatures)
        rolloutPercentages = safeFeatures.reduce(into: [:]) { result, feature in
            result[feature] = 100.0
        }
        saveFeatureStates()

        logger.critical("↩️ Rollback completed to \(safeFeatures.count) safe features")
    }

    // MARK: - Reporting

    public func generateFeatureReport() -> FeatureReport {
        let totalFeatures = Feature.allCases.count
        let enabledCount = enabledFeatures.count
        let healthyCount = getHealthyFeatures().count
        let unhealthyCount = getUnhealthyFeatures().count

        let averageHealth = featureMetrics.values.map { $0.healthScore }.reduce(0, +) / Double(max(1, featureMetrics.count))

        return FeatureReport(
            totalFeatures: totalFeatures,
            enabledFeatures: enabledCount,
            healthyFeatures: healthyCount,
            unhealthyFeatures: unhealthyCount,
            averageHealthScore: averageHealth,
            features: Feature.allCases.map { feature in
                FeatureStatus(
                    feature: feature,
                    isEnabled: isEnabled(feature),
                    rolloutPercentage: rolloutPercentages[feature] ?? 0.0,
                    metrics: featureMetrics[feature]
                )
            }
        )
    }

    public struct FeatureReport {
        public let totalFeatures: Int
        public let enabledFeatures: Int
        public let healthyFeatures: Int
        public let unhealthyFeatures: Int
        public let averageHealthScore: Double
        public let features: [FeatureStatus]

        public var summary: String {
            """
            Feature Flag Report
            ===================
            Total Features: \(totalFeatures)
            Enabled: \(enabledFeatures) (\(String(format: "%.1f", Double(enabledFeatures) / Double(totalFeatures) * 100))%)
            Healthy: \(healthyFeatures)
            Unhealthy: \(unhealthyFeatures)
            Average Health: \(String(format: "%.1f", averageHealthScore * 100))%
            """
        }
    }

    public struct FeatureStatus {
        public let feature: Feature
        public let isEnabled: Bool
        public let rolloutPercentage: Double
        public let metrics: FeatureMetrics?
    }

    // MARK: - Persistence

    private func saveFeatureStates() {
        let enabledFeatureNames = enabledFeatures.map { $0.rawValue }
        userDefaults.set(enabledFeatureNames, forKey: "lopan_enabled_features")

        let rolloutData = rolloutPercentages.reduce(into: [String: Double]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        userDefaults.set(rolloutData, forKey: "lopan_rollout_percentages")
    }

    private func loadFeatureStates() {
        if let enabledFeatureNames = userDefaults.array(forKey: "lopan_enabled_features") as? [String] {
            enabledFeatures = Set(enabledFeatureNames.compactMap { Feature(rawValue: $0) })
        }

        if let rolloutData = userDefaults.dictionary(forKey: "lopan_rollout_percentages") as? [String: Double] {
            rolloutPercentages = rolloutData.reduce(into: [:]) { result, pair in
                if let feature = Feature(rawValue: pair.key) {
                    result[feature] = pair.value
                }
            }
        }
    }

    // MARK: - Utility Methods

    private func isFeatureCompatible(_ feature: Feature) -> Bool {
        if feature.requiresIOS26 {
            return compatibilityLayer.isIOS26Available
        }
        return true
    }

    private func getManualOverride(_ feature: Feature) -> Bool? {
        return userDefaults.object(forKey: "lopan_override_\(feature.rawValue)") as? Bool
    }

    private func getUserHash() -> Int {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return abs(deviceId.hashValue)
    }

    private func logInitialState() {
        logger.info("🎛️ Feature Flag Manager initialized")
        logger.info("📊 \(self.enabledFeatures.count) features enabled")

        for feature in self.enabledFeatures {
            let percentage = rolloutPercentages[feature] ?? 100.0
            logger.info("✅ \(feature.displayName): \(String(format: "%.1f", percentage))%")
        }
    }
}

// MARK: - Environment Integration

private struct FeatureFlagManagerKey: EnvironmentKey {
    static let defaultValue = FeatureFlagManager.shared
}

public extension EnvironmentValues {
    var featureFlags: FeatureFlagManager {
        get { self[FeatureFlagManagerKey.self] }
        set { self[FeatureFlagManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI Integration

public extension View {
    /// Conditionally show view based on feature flag
    @ViewBuilder
    func featureGated(_ feature: FeatureFlagManager.Feature) -> some View {
        if FeatureFlagManager.shared.isEnabled(feature) {
            self
        } else {
            EmptyView()
        }
    }

    /// Apply different view modifiers based on feature availability
    @ViewBuilder
    func featureAdaptive<EnabledContent: View, DisabledContent: View>(
        _ feature: FeatureFlagManager.Feature,
        @ViewBuilder enabled: () -> EnabledContent,
        @ViewBuilder disabled: () -> DisabledContent
    ) -> some View {
        if FeatureFlagManager.shared.isEnabled(feature) {
            enabled()
        } else {
            disabled()
        }
    }
}

// MARK: - Performance Measurement Helper

public extension FeatureFlagManager {
    func measureFeaturePerformance<T>(
        _ feature: Feature,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        var success = true

        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordFeatureUsage(feature, performance: duration, success: success)
        }

        do {
            let result = try await operation()
            return result
        } catch {
            success = false
            throw error
        }
    }
}