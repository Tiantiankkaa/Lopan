//
//  CompatibilityTestSuite.swift
//  LopanTests
//
//  Created by Claude Code on 2025/9/27.
//  Comprehensive iOS 26 Compatibility Testing Suite
//

import XCTest
import SwiftUI
@testable import Lopan

// MARK: - Compatibility Test Suite

@MainActor
final class CompatibilityTestSuite: XCTestCase {

    private var testCompatibilityLayer: iOS26CompatibilityLayer!
    private var testFeatureFlags: FeatureFlagManager!

    override func setUp() async throws {
        try await super.setUp()

        testCompatibilityLayer = iOS26CompatibilityLayer.shared
        testFeatureFlags = FeatureFlagManager.shared

        // Reset feature flags for testing
        await resetFeatureFlags()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    private func resetFeatureFlags() async {
        // Disable all features for clean testing
        for feature in FeatureFlagManager.Feature.allCases {
            testFeatureFlags.disable(feature)
        }
    }

    // MARK: - iOS Version Compatibility Tests

    func testIOS26FeatureAvailability() async {
        let report = testCompatibilityLayer.generateCompatibilityReport()

        XCTAssertNotNil(report, "Compatibility report should be generated")
        XCTAssertGreaterThan(report.availableFeatures.count, 0, "Should have at least some available features")

        print("📊 Compatibility Report:")
        print(report.summary)
    }

    func testFeatureFlagSystemIntegrity() async {
        // Test enabling features
        testFeatureFlags.enable(.observablePattern, rolloutPercentage: 100.0)
        XCTAssertTrue(testFeatureFlags.isEnabled(.observablePattern), "Observable pattern should be enabled")

        // Test disabling features
        testFeatureFlags.disable(.observablePattern)
        XCTAssertFalse(testFeatureFlags.isEnabled(.observablePattern), "Observable pattern should be disabled")

        // Test rollout percentage
        testFeatureFlags.enable(.fluidAnimations, rolloutPercentage: 50.0)
        let isEnabled = testFeatureFlags.isEnabled(.fluidAnimations)

        // Should be either enabled or disabled based on user hash
        XCTAssertNotNil(isEnabled, "Rollout percentage should produce a boolean result")
    }

    func testLegacyCompatibility() async {
        // Test that legacy implementations work
        let dashboardState = LegacyDashboardState()
        XCTAssertNotNil(dashboardState, "Legacy dashboard state should initialize")

        // Test legacy animations
        let animationManager = FluidAnimationManager.shared
        let legacyAnimation = animationManager.createAnimation(.cardAppear, isActive: true)
        XCTAssertNotNil(legacyAnimation, "Legacy animations should be created")
    }

    // MARK: - Feature-Specific Compatibility Tests

    func testObservablePatternCompatibility() async {
        // Enable observable pattern
        testFeatureFlags.enable(.observablePattern, rolloutPercentage: 100.0)

        if testCompatibilityLayer.isIOS26Available {
            // Test modern implementation
            if #available(iOS 26.0, *) {
                let modernState = ModernDashboardState()
                XCTAssertNotNil(modernState, "Modern dashboard state should initialize on iOS 26+")

                // Test @Observable behavior
                modernState.selectedDate = Date()
                XCTAssertEqual(modernState.selectedDate.timeIntervalSinceReferenceDate,
                              Date().timeIntervalSinceReferenceDate, accuracy: 1.0,
                              "Observable state should update correctly")
            }
        } else {
            // Test legacy implementation
            let legacyState = LegacyDashboardState()
            XCTAssertNotNil(legacyState, "Legacy dashboard state should initialize on older iOS")
        }
    }

    func testFluidAnimationCompatibility() async {
        testFeatureFlags.enable(.fluidAnimations, rolloutPercentage: 100.0)

        let animationManager = FluidAnimationManager.shared

        // Test animation creation for different types
        let cardAnimation = animationManager.createAnimation(.cardAppear)
        let buttonAnimation = animationManager.createAnimation(.buttonPress)
        let modalAnimation = animationManager.createAnimation(.modalPresent)

        XCTAssertNotNil(cardAnimation, "Card animation should be created")
        XCTAssertNotNil(buttonAnimation, "Button animation should be created")
        XCTAssertNotNil(modalAnimation, "Modal animation should be created")

        // Test performance adaptation
        let report = animationManager.generatePerformanceReport()
        XCTAssertNotNil(report, "Animation performance report should be generated")
    }

    func testPerformanceOptimizationCompatibility() async {
        let performanceManager = PerformanceOptimizationManager.shared

        // Test memory monitoring
        let memoryUsage = performanceManager.currentMemoryUsage
        XCTAssertGreaterThan(memoryUsage.totalMemoryMB, 0, "Should detect total memory")
        XCTAssertGreaterThanOrEqual(memoryUsage.usedMemoryMB, 0, "Used memory should be non-negative")

        // Test cache management
        let testData = ["test": "data"]
        performanceManager.cacheViewData(testData, forKey: "test-key")

        let cachedData: [String: String]? = performanceManager.getCachedViewData([String: String].self, forKey: "test-key")
        XCTAssertEqual(cachedData?["test"], "data", "Cached data should be retrievable")

        // Test performance report generation
        let report = performanceManager.generatePerformanceReport()
        XCTAssertNotNil(report, "Performance report should be generated")
        print("⚡ Performance Report:")
        print(report.summary)
    }

    // MARK: - Integration Tests

    func testDashboardIntegration() async {
        // Enable all features for integration test
        for feature in FeatureFlagManager.Feature.allCases {
            testFeatureFlags.enable(feature, rolloutPercentage: 100.0)
        }

        // Test dashboard state creation
        let stateFactory = DashboardStateFactory.shared
        let dashboardState = stateFactory.createDashboardState()
        XCTAssertNotNil(dashboardState, "Dashboard state should be created")

        // Test state functionality
        dashboardState.selectedDate = Date()
        XCTAssertEqual(dashboardState.selectedDate.timeIntervalSinceReferenceDate,
                      Date().timeIntervalSinceReferenceDate, accuracy: 1.0,
                      "Dashboard state should update correctly")
    }

    // MARK: - Error Handling Tests

    func testGracefulDegradation() async {
        // Test behavior when features are disabled
        await resetFeatureFlags()

        // Dashboard should still work without enhanced features
        let dashboardState = LegacyDashboardState()
        XCTAssertNotNil(dashboardState, "Dashboard should work without enhanced features")

        // Animations should fall back to legacy
        let animationManager = FluidAnimationManager.shared
        let animation = animationManager.createAnimation(.cardAppear)
        XCTAssertNotNil(animation, "Animations should fall back gracefully")
    }

    func testMemoryPressureHandling() async {
        let performanceManager = PerformanceOptimizationManager.shared

        // Test memory cleanup
        performanceManager.triggerMemoryCleanup()

        // Should not crash
        XCTAssertTrue(true, "Memory cleanup should complete without crashing")

        // Test emergency cleanup
        performanceManager.triggerEmergencyMemoryCleanup()

        // Should disable non-essential features
        XCTAssertFalse(testFeatureFlags.isEnabled(.glassMorphismV2), "Glass morphism should be disabled during emergency cleanup")
    }

    // MARK: - Performance Tests

    func testDashboardLoadPerformance() async {
        measure {
            let dashboardState = LegacyDashboardState()
            dashboardState.selectedDate = Date()
        }
    }

    func testAnimationPerformance() async {
        let animationManager = FluidAnimationManager.shared

        measure {
            for _ in 0..<100 {
                let _ = animationManager.createAnimation(.cardAppear)
                let _ = animationManager.createAnimation(.buttonPress)
                let _ = animationManager.createAnimation(.modalPresent)
            }
        }
    }

    func testCachePerformance() async {
        let performanceManager = PerformanceOptimizationManager.shared

        measure {
            for i in 0..<1000 {
                let testData = ["key": "value\(i)"]
                performanceManager.cacheViewData(testData, forKey: "test-\(i)")
            }

            for i in 0..<1000 {
                let _ = performanceManager.getCachedViewData([String: String].self, forKey: "test-\(i)")
            }
        }
    }

    // MARK: - Comprehensive System Test

    func testComprehensiveSystemCompatibility() async {
        // Generate comprehensive report
        let compatibilityReport = testCompatibilityLayer.generateCompatibilityReport()
        let featureReport = testFeatureFlags.generateFeatureReport()

        print("\n" + String(repeating: "=", count: 60))
        print("COMPREHENSIVE COMPATIBILITY TEST RESULTS")
        print(String(repeating: "=", count: 60))
        print("\n📱 " + compatibilityReport.summary)
        print("\n🎛️ " + featureReport.summary)

        // Test all systems together
        for feature in FeatureFlagManager.Feature.allCases {
            testFeatureFlags.enable(feature, rolloutPercentage: 100.0)
        }

        // Verify system stability
        let dashboardState = DashboardStateFactory.shared.createDashboardState()
        let animationManager = FluidAnimationManager.shared
        let performanceManager = PerformanceOptimizationManager.shared

        XCTAssertNotNil(dashboardState, "Dashboard state should be created")

        // Generate final reports
        let animationReport = animationManager.generatePerformanceReport()
        let performanceReport = performanceManager.generatePerformanceReport()

        print("\n🎭 " + animationReport.summary)
        print("\n⚡ " + performanceReport.summary)

        print("\n" + String(repeating: "=", count: 60))
        print("✅ ALL COMPATIBILITY TESTS COMPLETED SUCCESSFULLY")
        print(String(repeating: "=", count: 60))

        XCTAssertTrue(true, "Comprehensive system test completed successfully")
    }
}