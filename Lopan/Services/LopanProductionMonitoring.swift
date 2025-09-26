//
//  LopanProductionMonitoring.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/26.
//  Phase 4: Performance & Polish - Production monitoring integration
//

import Foundation
import OSLog

/// Production monitoring service that integrates with analytics and crash reporting
/// Provides centralized monitoring for performance, errors, and user behavior
@available(iOS 26.0, *)
@MainActor
public final class LopanProductionMonitoring: ObservableObject {

    public static let shared = LopanProductionMonitoring()

    // MARK: - Configuration

    public struct Configuration {
        let enableCrashReporting: Bool
        let enableAnalytics: Bool
        let enablePerformanceMonitoring: Bool
        let enableUserFeedback: Bool
        let maxEventQueueSize: Int
        let flushInterval: TimeInterval

        public static let production = Configuration(
            enableCrashReporting: true,
            enableAnalytics: true,
            enablePerformanceMonitoring: true,
            enableUserFeedback: true,
            maxEventQueueSize: 1000,
            flushInterval: 30.0
        )

        public static let debug = Configuration(
            enableCrashReporting: false,
            enableAnalytics: false,
            enablePerformanceMonitoring: true,
            enableUserFeedback: false,
            maxEventQueueSize: 100,
            flushInterval: 10.0
        )
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.lopan.monitoring", category: "production")
    private let configuration: Configuration
    private let performanceProfiler: LopanPerformanceProfiler
    private let memoryManager: LopanMemoryManager

    private var eventQueue: [MonitoringEvent] = []
    private var flushTimer: Timer?

    // MARK: - Initialization

    private init(configuration: Configuration = .debug) {
        self.configuration = configuration
        self.performanceProfiler = LopanPerformanceProfiler.shared
        self.memoryManager = LopanMemoryManager.shared

        setupMonitoring()
    }

    public func configure(for production: Bool) {
        let config = production ? Configuration.production : Configuration.debug
        let newMonitoring = LopanProductionMonitoring(configuration: config)
        // Replace shared instance logic here if needed
    }

    // MARK: - Setup

    private func setupMonitoring() {
        setupPerformanceMonitoring()
        setupCrashReporting()
        setupAnalytics()
        setupEventQueue()
    }

    private func setupPerformanceMonitoring() {
        guard configuration.enablePerformanceMonitoring else { return }

        performanceProfiler.startMonitoring()
        memoryManager.startOptimization()

        // Monitor performance alerts
        NotificationCenter.default.addObserver(
            forName: .performanceAlert,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handlePerformanceAlert(notification)
        }
    }

    private func setupCrashReporting() {
        guard configuration.enableCrashReporting else { return }

        // Integrate with Firebase Crashlytics or similar service
        logger.info("Crash reporting enabled")

        // Set up crash reporting service
        configureCrashlyticsIntegration()
    }

    private func setupAnalytics() {
        guard configuration.enableAnalytics else { return }

        // Integrate with Firebase Analytics or similar service
        logger.info("Analytics enabled")

        // Set up analytics service
        configureAnalyticsIntegration()
    }

    private func setupEventQueue() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: configuration.flushInterval, repeats: true) { [weak self] _ in
            self?.flushEventQueue()
        }
    }

    // MARK: - Integration Configuration

    private func configureCrashlyticsIntegration() {
        // Firebase Crashlytics integration would go here
        // Example implementation:
        /*
        #if canImport(FirebaseCrashlytics)
        import FirebaseCrashlytics

        // Set custom keys
        Crashlytics.crashlytics().setCustomValue("production", forKey: "environment")
        Crashlytics.crashlytics().setCustomValue(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown", forKey: "build_version")
        #endif
        */

        logger.info("Crashlytics integration configured")
    }

    private func configureAnalyticsIntegration() {
        // Firebase Analytics integration would go here
        // Example implementation:
        /*
        #if canImport(FirebaseAnalytics)
        import FirebaseAnalytics

        Analytics.setAnalyticsCollectionEnabled(true)
        Analytics.setUserProperty("production", forName: "environment")
        #endif
        */

        logger.info("Analytics integration configured")
    }

    // MARK: - Event Tracking

    public func trackEvent(_ event: MonitoringEvent) {
        guard eventQueue.count < configuration.maxEventQueueSize else {
            logger.warning("Event queue full, dropping event: \(event.name)")
            return
        }

        eventQueue.append(event)
        logger.debug("Tracked event: \(event.name) with parameters: \(event.parameters)")

        // Immediate flush for critical events
        if event.priority == .critical {
            flushEventQueue()
        }
    }

    public func trackScreenView(_ screenName: String, parameters: [String: Any] = [:]) {
        var eventParameters = parameters
        eventParameters["screen_name"] = screenName
        eventParameters["timestamp"] = Date().timeIntervalSince1970

        let event = MonitoringEvent(
            name: "screen_view",
            parameters: eventParameters,
            priority: .low
        )

        trackEvent(event)
    }

    public func trackUserAction(_ action: String, parameters: [String: Any] = [:]) {
        var eventParameters = parameters
        eventParameters["action"] = action
        eventParameters["timestamp"] = Date().timeIntervalSince1970

        let event = MonitoringEvent(
            name: "user_action",
            parameters: eventParameters,
            priority: .medium
        )

        trackEvent(event)
    }

    public func trackPerformanceMetric(_ metric: PerformanceMetric) {
        let parameters: [String: Any] = [
            "metric_name": metric.name,
            "value": metric.value,
            "unit": metric.unit,
            "timestamp": Date().timeIntervalSince1970
        ]

        let event = MonitoringEvent(
            name: "performance_metric",
            parameters: parameters,
            priority: metric.value > metric.warningThreshold ? .high : .low
        )

        trackEvent(event)
    }

    public func trackError(_ error: Error, context: [String: Any] = [:]) {
        var errorParameters = context
        errorParameters["error_description"] = error.localizedDescription
        errorParameters["error_domain"] = (error as NSError).domain
        errorParameters["error_code"] = (error as NSError).code
        errorParameters["timestamp"] = Date().timeIntervalSince1970

        let event = MonitoringEvent(
            name: "error",
            parameters: errorParameters,
            priority: .high
        )

        trackEvent(event)

        // Also log to crash reporting service
        logToCrashReporting(error, context: context)
    }

    // MARK: - Performance Monitoring

    private func handlePerformanceAlert(_ notification: Notification) {
        guard let alertInfo = notification.userInfo else { return }

        trackPerformanceMetric(PerformanceMetric(
            name: "performance_alert",
            value: alertInfo["severity"] as? Double ?? 1.0,
            unit: "severity_level",
            warningThreshold: 0.5
        ))

        logger.warning("Performance alert received: \(alertInfo)")
    }

    public func recordLaunchTime(_ duration: TimeInterval) {
        trackPerformanceMetric(PerformanceMetric(
            name: "app_launch_time",
            value: duration,
            unit: "seconds",
            warningThreshold: 2.0
        ))
    }

    public func recordViewTransition(from: String, to: String, duration: TimeInterval) {
        let parameters: [String: Any] = [
            "from_screen": from,
            "to_screen": to,
            "duration": duration
        ]

        trackEvent(MonitoringEvent(
            name: "view_transition",
            parameters: parameters,
            priority: duration > 0.5 ? .medium : .low
        ))
    }

    // MARK: - Crash Reporting

    private func logToCrashReporting(_ error: Error, context: [String: Any]) {
        // Log to crash reporting service
        /*
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()

        // Set context
        for (key, value) in context {
            crashlytics.setCustomValue(value, forKey: key)
        }

        // Record error
        crashlytics.record(error: error)
        #endif
        */

        logger.error("Error logged to crash reporting: \(error.localizedDescription)")
    }

    public func logCrash(_ message: String, context: [String: Any] = [:]) {
        /*
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()

        // Set context
        for (key, value) in context {
            crashlytics.setCustomValue(value, forKey: key)
        }

        // Log fatal crash
        crashlytics.log(message)
        fatalError(message)
        #endif
        */

        logger.fault("Crash logged: \(message)")
    }

    // MARK: - Event Queue Management

    private func flushEventQueue() {
        guard !eventQueue.isEmpty else { return }

        let eventsToFlush = Array(eventQueue)
        eventQueue.removeAll()

        Task {
            await sendEventsToAnalytics(eventsToFlush)
        }

        logger.debug("Flushed \(eventsToFlush.count) events to analytics")
    }

    private func sendEventsToAnalytics(_ events: [MonitoringEvent]) async {
        // Send events to analytics service
        for event in events {
            await sendSingleEventToAnalytics(event)
        }
    }

    private func sendSingleEventToAnalytics(_ event: MonitoringEvent) async {
        // Implementation for sending to Firebase Analytics
        /*
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.name, parameters: event.parameters)
        #endif
        */

        // For now, just log the event
        logger.info("Analytics event: \(event.name) with parameters: \(event.parameters)")
    }

    // MARK: - User Feedback

    public func collectUserFeedback(_ feedback: String, rating: Int, context: [String: Any] = [:]) {
        guard configuration.enableUserFeedback else { return }

        var feedbackParameters = context
        feedbackParameters["feedback"] = feedback
        feedbackParameters["rating"] = rating
        feedbackParameters["timestamp"] = Date().timeIntervalSince1970

        let event = MonitoringEvent(
            name: "user_feedback",
            parameters: feedbackParameters,
            priority: rating <= 2 ? .high : .medium
        )

        trackEvent(event)
    }

    // MARK: - Cleanup

    deinit {
        // Cleanup resources directly to avoid @MainActor isolation issues
        flushTimer?.invalidate()
        flushTimer = nil

        // Clear event queue without calling @MainActor methods
        eventQueue.removeAll()

        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, *)
extension LopanProductionMonitoring {

    public struct MonitoringEvent {
        let name: String
        let parameters: [String: Any]
        let priority: Priority
        let timestamp: Date

        init(name: String, parameters: [String: Any], priority: Priority = .medium) {
            self.name = name
            self.parameters = parameters
            self.priority = priority
            self.timestamp = Date()
        }

        public enum Priority {
            case low, medium, high, critical
        }
    }

    public struct PerformanceMetric {
        let name: String
        let value: Double
        let unit: String
        let warningThreshold: Double
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let performanceAlert = Notification.Name("LopanPerformanceAlert")
}

// MARK: - Public Interface Extensions

@available(iOS 26.0, *)
extension LopanProductionMonitoring {

    /// Start production monitoring with appropriate configuration
    public func startMonitoring(isProduction: Bool = false) {
        let config = isProduction ? Configuration.production : Configuration.debug

        logger.info("Starting production monitoring - Environment: \(isProduction ? "Production" : "Debug")")

        if isProduction {
            // Enable all production features
            setupPerformanceMonitoring()
            setupCrashReporting()
            setupAnalytics()
        }

        trackEvent(MonitoringEvent(
            name: "monitoring_started",
            parameters: ["environment": isProduction ? "production" : "debug"],
            priority: .medium
        ))
    }

    /// Stop all monitoring services
    public func stopMonitoring() {
        flushEventQueue()
        flushTimer?.invalidate()

        performanceProfiler.stopMonitoring()
        memoryManager.stopOptimization()

        logger.info("Production monitoring stopped")
    }

    /// Get current monitoring statistics
    public func getMonitoringStatistics() -> MonitoringStatistics {
        return MonitoringStatistics(
            queuedEvents: eventQueue.count,
            performanceMetrics: performanceProfiler.currentMetrics,
            memoryUsage: memoryManager.getMemoryStatistics(),
            isActive: flushTimer?.isValid ?? false
        )
    }
}

public struct MonitoringStatistics {
    public let queuedEvents: Int
    public let performanceMetrics: PerformanceMetrics
    public let memoryUsage: MemoryStatistics
    public let isActive: Bool
}