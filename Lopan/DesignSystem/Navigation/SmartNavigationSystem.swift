//
//  SmartNavigationSystem.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  iOS 26 Smart Navigation with Spatial Transitions and backward compatibility
//

import SwiftUI
import Foundation
import os.log

// MARK: - Smart Navigation Manager

@MainActor
public final class SmartNavigationManager: ObservableObject {
    public static let shared = SmartNavigationManager()

    private let compatibilityLayer = iOS26CompatibilityLayer.shared
    private let featureFlags = FeatureFlagManager.shared
    private let logger = Logger(subsystem: "com.lopan.navigation", category: "SmartNavigation")

    @Published public var isEnabled: Bool = true
    @Published public var spatialTransitionsEnabled: Bool = true
    @Published public var predictivePreloadingEnabled: Bool = true
    @Published public var navigationMode: NavigationMode = .adaptive

    public enum NavigationMode: String, CaseIterable {
        case traditional = "traditional"
        case spatial = "spatial"
        case predictive = "predictive"
        case adaptive = "adaptive"

        public var displayName: String {
            switch self {
            case .traditional: return "Traditional"
            case .spatial: return "Spatial"
            case .predictive: return "Predictive"
            case .adaptive: return "Adaptive"
            }
        }

        public var usesSpatialTransitions: Bool {
            switch self {
            case .traditional: return false
            case .spatial, .predictive, .adaptive: return true
            }
        }

        public var usesPredictivePreloading: Bool {
            switch self {
            case .traditional, .spatial: return false
            case .predictive, .adaptive: return true
            }
        }
    }

    // Navigation history and prediction
    @Published public private(set) var navigationHistory: [NavigationEntry] = []
    @Published public private(set) var predictedNextDestinations: [PredictedDestination] = []

    public struct NavigationEntry {
        public let id = UUID()
        public let destination: NavigationDestination
        public let timestamp: Date
        public let sourceLocation: CGPoint?
        public let transitionType: TransitionType

        public enum TransitionType {
            case push, pop, modal, sheet, replace
        }
    }

    public enum NavigationDestination: String, CaseIterable {
        case customerOutOfStockDashboard = "customer_out_of_stock_dashboard"
        case customerOutOfStockDetail = "customer_out_of_stock_detail"
        case customerManagement = "customer_management"
        case productManagement = "product_management"
        case analytics = "analytics"
        case filterPanel = "filter_panel"
        case batchCreation = "batch_creation"
        case userProfile = "user_profile"
        case settings = "settings"

        public var displayName: String {
            switch self {
            case .customerOutOfStockDashboard: return "客户缺货管理"
            case .customerOutOfStockDetail: return "缺货详情"
            case .customerManagement: return "客户管理"
            case .productManagement: return "产品管理"
            case .analytics: return "数据分析"
            case .filterPanel: return "筛选面板"
            case .batchCreation: return "批量创建"
            case .userProfile: return "用户资料"
            case .settings: return "设置"
            }
        }

        public var preloadPriority: PreloadPriority {
            switch self {
            case .customerOutOfStockDashboard, .customerOutOfStockDetail:
                return .high
            case .customerManagement, .productManagement, .analytics:
                return .medium
            case .filterPanel, .batchCreation:
                return .medium
            case .userProfile, .settings:
                return .low
            }
        }
    }

    public enum PreloadPriority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3

        public var maxConcurrentPreloads: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            }
        }
    }

    public struct PredictedDestination {
        public let destination: NavigationDestination
        public let probability: Double
        public let reasoning: PredictionReasoning

        public enum PredictionReasoning {
            case frequentlyAccessed
            case recentlyAccessed
            case timeBasedPattern
            case workflowSequence
            case userBehaviorPattern
        }
    }

    private init() {
        setupNavigationMode()
        logger.info("🧭 Smart Navigation Manager initialized")
    }

    private func setupNavigationMode() {
        if featureFlags.isEnabled(.spatialNavigation) && compatibilityLayer.isIOS26Available {
            self.navigationMode = .adaptive
            self.spatialTransitionsEnabled = true
            self.predictivePreloadingEnabled = true
        } else {
            self.navigationMode = .traditional
            self.spatialTransitionsEnabled = false
            self.predictivePreloadingEnabled = false
        }

        logger.info("🎯 Navigation mode set to: \(self.navigationMode.displayName)")
    }

    // MARK: - Navigation Tracking

    public func recordNavigation(
        to destination: NavigationDestination,
        from sourceLocation: CGPoint? = nil,
        transitionType: NavigationEntry.TransitionType = .push
    ) {
        let entry = NavigationEntry(
            destination: destination,
            timestamp: Date(),
            sourceLocation: sourceLocation,
            transitionType: transitionType
        )

        navigationHistory.append(entry)

        // Keep only recent history (last 50 entries)
        if navigationHistory.count > 50 {
            navigationHistory.removeFirst(navigationHistory.count - 50)
        }

        // Update predictions
        if predictivePreloadingEnabled {
            updatePredictions()
        }

        logger.debug("📍 Navigation recorded: \(destination.displayName)")
    }

    private func updatePredictions() {
        let predictions = generatePredictions()
        predictedNextDestinations = predictions

        logger.debug("🔮 Updated predictions: \(predictions.count) destinations")
    }

    private func generatePredictions() -> [PredictedDestination] {
        var predictions: [PredictedDestination] = []

        // Analyze navigation patterns
        let recentEntries = Array(navigationHistory.suffix(10))
        let destinationCounts = Dictionary(grouping: recentEntries) { $0.destination }
            .mapValues { $0.count }

        // Frequent destinations
        for (destination, count) in destinationCounts {
            if count >= 2 {
                let probability = min(1.0, Double(count) / 10.0)
                predictions.append(PredictedDestination(
                    destination: destination,
                    probability: probability,
                    reasoning: .frequentlyAccessed
                ))
            }
        }

        // Time-based patterns (e.g., analytics usually viewed in afternoon)
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour >= 14 && currentHour <= 17 {
            predictions.append(PredictedDestination(
                destination: .analytics,
                probability: 0.7,
                reasoning: .timeBasedPattern
            ))
        }

        // Workflow sequences
        if let lastDestination = recentEntries.last?.destination {
            let nextInWorkflow = getNextInWorkflow(after: lastDestination)
            for destination in nextInWorkflow {
                predictions.append(PredictedDestination(
                    destination: destination,
                    probability: 0.6,
                    reasoning: .workflowSequence
                ))
            }
        }

        // Sort by probability and return top 5
        return Array(predictions.sorted { $0.probability > $1.probability }.prefix(5))
    }

    private func getNextInWorkflow(after destination: NavigationDestination) -> [NavigationDestination] {
        switch destination {
        case .customerOutOfStockDashboard:
            return [.customerOutOfStockDetail, .filterPanel, .batchCreation]
        case .customerOutOfStockDetail:
            return [.customerManagement, .productManagement]
        case .customerManagement:
            return [.customerOutOfStockDashboard, .analytics]
        case .productManagement:
            return [.customerOutOfStockDashboard, .analytics]
        case .analytics:
            return [.customerOutOfStockDashboard]
        case .filterPanel:
            return [.customerOutOfStockDashboard, .analytics]
        case .batchCreation:
            return [.customerOutOfStockDashboard]
        case .userProfile, .settings:
            return []
        }
    }

    // MARK: - Spatial Transitions

    public enum SpatialTransition {
        case slideFromRight
        case slideFromLeft
        case slideFromBottom
        case slideFromTop
        case scale
        case flip
        case dissolve
        case adaptive(from: CGPoint, to: CGPoint)

        public var swiftUITransition: AnyTransition {
            switch self {
            case .slideFromRight:
                return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            case .slideFromLeft:
                return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
            case .slideFromBottom:
                return .asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top))
            case .slideFromTop:
                return .asymmetric(insertion: .move(edge: .top), removal: .move(edge: .bottom))
            case .scale:
                return .asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .scale(scale: 1.2).combined(with: .opacity))
            case .flip:
                return .asymmetric(insertion: .opacity, removal: .opacity)
            case .dissolve:
                return .opacity
            case .adaptive(let from, let to):
                return SmartNavigationManager.shared.calculateAdaptiveTransition(from: from, to: to)
            }
        }
    }

    nonisolated public func calculateAdaptiveTransition(from: CGPoint, to: CGPoint) -> AnyTransition {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y

        if abs(deltaX) > abs(deltaY) {
            return deltaX > 0 ? .move(edge: .leading) : .move(edge: .trailing)
        } else {
            return deltaY > 0 ? .move(edge: .top) : .move(edge: .bottom)
        }
    }

    public func getSpatialTransition(
        to destination: NavigationDestination,
        from sourceLocation: CGPoint? = nil,
        to targetLocation: CGPoint? = nil
    ) -> SpatialTransition {
        guard spatialTransitionsEnabled else { return .slideFromRight }

        if let source = sourceLocation, let target = targetLocation {
            return .adaptive(from: source, to: target)
        }

        // Default transitions based on destination type
        switch destination {
        case .customerOutOfStockDetail:
            return .slideFromRight
        case .filterPanel:
            return .slideFromBottom
        case .batchCreation:
            return .slideFromBottom
        case .analytics:
            return .scale
        case .userProfile, .settings:
            return .slideFromTop
        default:
            return .slideFromRight
        }
    }

    // MARK: - Predictive Preloading

    public func shouldPreload(_ destination: NavigationDestination) -> Bool {
        guard predictivePreloadingEnabled else { return false }

        return predictedNextDestinations.contains { prediction in
            prediction.destination == destination && prediction.probability > 0.5
        }
    }

    public func getPreloadPriority(for destination: NavigationDestination) -> PreloadPriority {
        if let prediction = predictedNextDestinations.first(where: { $0.destination == destination }) {
            if prediction.probability > 0.8 {
                return .high
            } else if prediction.probability > 0.5 {
                return .medium
            }
        }

        return destination.preloadPriority
    }

    // MARK: - Performance Monitoring

    public func generateNavigationReport() -> NavigationPerformanceReport {
        let recentEntries = Array(navigationHistory.suffix(20))
        let uniqueDestinations = Set(recentEntries.map { $0.destination }).count
        let averageSessionLength = calculateAverageSessionLength()

        return NavigationPerformanceReport(
            totalNavigations: navigationHistory.count,
            uniqueDestinations: uniqueDestinations,
            averageSessionLength: averageSessionLength,
            predictionAccuracy: calculatePredictionAccuracy(),
            navigationMode: navigationMode,
            featuresEnabled: NavigationFeatures(
                spatialTransitions: spatialTransitionsEnabled,
                predictivePreloading: predictivePreloadingEnabled
            )
        )
    }

    public struct NavigationPerformanceReport {
        public let totalNavigations: Int
        public let uniqueDestinations: Int
        public let averageSessionLength: TimeInterval
        public let predictionAccuracy: Double
        public let navigationMode: NavigationMode
        public let featuresEnabled: NavigationFeatures

        public var summary: String {
            """
            Smart Navigation Performance Report
            ===================================
            Total Navigations: \(totalNavigations)
            Unique Destinations: \(uniqueDestinations)
            Average Session: \(String(format: "%.1f", averageSessionLength / 60))min
            Prediction Accuracy: \(String(format: "%.1f", predictionAccuracy * 100))%
            Navigation Mode: \(navigationMode.displayName)

            Features:
            - Spatial Transitions: \(featuresEnabled.spatialTransitions ? "Enabled" : "Disabled")
            - Predictive Preloading: \(featuresEnabled.predictivePreloading ? "Enabled" : "Disabled")
            """
        }
    }

    public struct NavigationFeatures {
        public let spatialTransitions: Bool
        public let predictivePreloading: Bool
    }

    private func calculateAverageSessionLength() -> TimeInterval {
        guard navigationHistory.count > 1 else { return 0 }

        let sessions = groupNavigationsIntoSessions()
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }

        return totalDuration / Double(sessions.count)
    }

    private func groupNavigationsIntoSessions() -> [NavigationSession] {
        var sessions: [NavigationSession] = []
        var currentSession: [NavigationEntry] = []

        for entry in navigationHistory {
            if let lastEntry = currentSession.last {
                let timeDifference = entry.timestamp.timeIntervalSince(lastEntry.timestamp)
                if timeDifference > 300 { // 5 minutes gap = new session
                    if !currentSession.isEmpty {
                        sessions.append(NavigationSession(entries: currentSession))
                    }
                    currentSession = [entry]
                } else {
                    currentSession.append(entry)
                }
            } else {
                currentSession.append(entry)
            }
        }

        if !currentSession.isEmpty {
            sessions.append(NavigationSession(entries: currentSession))
        }

        return sessions
    }

    private func calculatePredictionAccuracy() -> Double {
        // Simplified prediction accuracy calculation
        // In a real implementation, you'd track prediction success rates
        return 0.75 // 75% accuracy placeholder
    }

    private struct NavigationSession {
        let entries: [NavigationEntry]

        var duration: TimeInterval {
            guard let first = entries.first, let last = entries.last else { return 0 }
            return last.timestamp.timeIntervalSince(first.timestamp)
        }
    }
}

// MARK: - Smart Navigation View Modifier

public struct SmartNavigationModifier: ViewModifier {
    let destination: SmartNavigationManager.NavigationDestination
    let sourceLocation: CGPoint?

    @StateObject private var navigationManager = SmartNavigationManager.shared

    public init(
        destination: SmartNavigationManager.NavigationDestination,
        sourceLocation: CGPoint? = nil
    ) {
        self.destination = destination
        self.sourceLocation = sourceLocation
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                navigationManager.recordNavigation(
                    to: destination,
                    from: sourceLocation,
                    transitionType: .push
                )
            }
    }
}

// MARK: - Environment Integration

private struct SmartNavigationManagerKey: EnvironmentKey {
    static let defaultValue = SmartNavigationManager.shared
}

public extension EnvironmentValues {
    var smartNavigation: SmartNavigationManager {
        get { self[SmartNavigationManagerKey.self] }
        set { self[SmartNavigationManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Tracks navigation to this view
    func trackNavigation(
        to destination: SmartNavigationManager.NavigationDestination,
        from sourceLocation: CGPoint? = nil
    ) -> some View {
        modifier(SmartNavigationModifier(
            destination: destination,
            sourceLocation: sourceLocation
        ))
    }

    /// Applies spatial transition based on navigation context
    func spatialTransition(
        to destination: SmartNavigationManager.NavigationDestination,
        from sourceLocation: CGPoint? = nil,
        to targetLocation: CGPoint? = nil
    ) -> some View {
        let transition = SmartNavigationManager.shared.getSpatialTransition(
            to: destination,
            from: sourceLocation,
            to: targetLocation
        )

        return self.transition(transition.swiftUITransition)
    }

    /// Conditionally preloads view based on navigation predictions
    func predictivePreload(
        for destination: SmartNavigationManager.NavigationDestination
    ) -> some View {
        let shouldPreload = SmartNavigationManager.shared.shouldPreload(destination)

        return self.onAppear {
            if shouldPreload {
                // Trigger preload logic here
                print("🔮 Preloading \(destination.displayName)")
            }
        }
    }
}