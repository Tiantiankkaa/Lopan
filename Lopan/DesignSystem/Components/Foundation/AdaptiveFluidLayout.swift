//
//  AdaptiveFluidLayout.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/27.
//  iOS 26 Adaptive Fluid Layout System with backward compatibility
//

import SwiftUI
import Foundation
import os.log

// MARK: - Screen Helper (iOS 26 Compatible)

@MainActor
private func getMainScreen() -> UIScreen {
    if #available(iOS 26.0, *) {
        // iOS 26: Get screen from active window scene
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            return windowScene.screen
        }
        // Fallback to any window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen
        }
    }
    // Pre-iOS 26 or fallback
    return UIScreen.main
}

// MARK: - Adaptive Fluid Layout Manager

@MainActor
public final class AdaptiveFluidLayoutManager: ObservableObject {
    public static let shared = AdaptiveFluidLayoutManager()

    public let compatibilityLayer = iOS26CompatibilityLayer.shared
    public let featureFlags = FeatureFlagManager.shared
    private let logger = Logger(subsystem: "com.lopan.layout", category: "AdaptiveFluid")

    @Published public var currentSizeClass: SizeClassInfo = .unknown
    @Published public var layoutMode: LayoutMode = .adaptive
    @Published public var isOptimizedForAccessibility: Bool = false

    public enum LayoutMode: String, CaseIterable {
        case fixed = "fixed"
        case adaptive = "adaptive"
        case fluid = "fluid"
        case containerRelative = "container_relative"

        public var displayName: String {
            switch self {
            case .fixed: return "Fixed"
            case .adaptive: return "Adaptive"
            case .fluid: return "Fluid"
            case .containerRelative: return "Container Relative"
            }
        }

        public var usesAdvancedFeatures: Bool {
            switch self {
            case .fixed, .adaptive: return false
            case .fluid, .containerRelative: return true
            }
        }
    }

    public struct SizeClassInfo: Equatable {
        public let horizontal: UserInterfaceSizeClass
        public let vertical: UserInterfaceSizeClass
        public let screenSize: CGSize
        public let deviceType: DeviceType
        public let orientation: Orientation

        public static let unknown = SizeClassInfo(
            horizontal: .regular,
            vertical: .regular,
            screenSize: .zero,
            deviceType: .unknown,
            orientation: .portrait
        )

        public enum DeviceType: Equatable {
            case phone, pad, mac, unknown

            public var defaultColumnCount: Int {
                switch self {
                case .phone: return 2
                case .pad: return 4
                case .mac: return 6
                case .unknown: return 2
                }
            }

            public var maxColumnCount: Int {
                switch self {
                case .phone: return 3
                case .pad: return 6
                case .mac: return 8
                case .unknown: return 3
                }
            }
        }

        public enum Orientation: Equatable {
            case portrait, landscape, square
        }

        public var isCompact: Bool {
            horizontal == .compact || vertical == .compact
        }

        public var isPad: Bool {
            deviceType == .pad
        }

        public var isMac: Bool {
            deviceType == .mac
        }

        public var recommendedColumnCount: Int {
            switch (deviceType, orientation) {
            case (.phone, .portrait): return 2
            case (.phone, .landscape): return 3
            case (.phone, .square): return 2
            case (.pad, .portrait): return 3
            case (.pad, .landscape): return 4
            case (.pad, .square): return 3
            case (.mac, _): return 5
            case (.unknown, _): return 2
            }
        }

        public var spacing: CGFloat {
            switch deviceType {
            case .phone: return 12
            case .pad: return 16
            case .mac: return 20
            case .unknown: return 12
            }
        }

        public var padding: EdgeInsets {
            switch (deviceType, orientation) {
            case (.phone, .portrait):
                return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            case (.phone, .landscape):
                return EdgeInsets(top: 12, leading: 44, bottom: 12, trailing: 44)
            case (.phone, .square):
                return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            case (.pad, _):
                return EdgeInsets(top: 20, leading: 32, bottom: 20, trailing: 32)
            case (.mac, _):
                return EdgeInsets(top: 24, leading: 40, bottom: 24, trailing: 40)
            case (.unknown, _):
                return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            }
        }
    }

    private init() {
        setupLayoutMode()
        setupAccessibilityObserver()
        logger.info("📐 Adaptive Fluid Layout Manager initialized")
    }

    private func setupLayoutMode() {
        if featureFlags.isEnabled(.adaptiveLayouts) && compatibilityLayer.isIOS26Available {
            if #available(iOS 26.0, *) {
                layoutMode = .containerRelative
            } else {
                layoutMode = .fluid
            }
        } else {
            layoutMode = .adaptive
        }

        logger.info("📏 Layout mode set to: \(self.layoutMode.displayName)")
    }

    private func setupAccessibilityObserver() {
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleContentSizeCategoryChange()
            }
        }
    }

    private func handleContentSizeCategoryChange() {
        let isLargeContentSize = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
        isOptimizedForAccessibility = isLargeContentSize

        logger.info("♿ Content size category changed - accessibility optimization: \(self.isOptimizedForAccessibility)")
    }

    public func updateSizeClass(_ horizontal: UserInterfaceSizeClass, _ vertical: UserInterfaceSizeClass, screenSize: CGSize) {
        let deviceType = determineDeviceType(screenSize: screenSize)
        let orientation = determineOrientation(screenSize: screenSize)

        let newSizeClass = SizeClassInfo(
            horizontal: horizontal,
            vertical: vertical,
            screenSize: screenSize,
            deviceType: deviceType,
            orientation: orientation
        )

        // Only update if values actually changed
        guard newSizeClass.horizontal != currentSizeClass.horizontal ||
              newSizeClass.vertical != currentSizeClass.vertical ||
              newSizeClass.deviceType != currentSizeClass.deviceType ||
              newSizeClass.orientation != currentSizeClass.orientation ||
              abs(newSizeClass.screenSize.width - currentSizeClass.screenSize.width) > 1 ||
              abs(newSizeClass.screenSize.height - currentSizeClass.screenSize.height) > 1 else {
            return
        }

        currentSizeClass = newSizeClass
        logger.debug("📱 Size class updated: \(String(describing: horizontal)) x \(String(describing: vertical)), device: \(String(describing: deviceType)), orientation: \(String(describing: orientation))")
    }

    private func determineDeviceType(screenSize: CGSize) -> SizeClassInfo.DeviceType {
        let maxDimension = max(screenSize.width, screenSize.height)

        if maxDimension > 1200 {
            return .mac
        } else if maxDimension > 1000 {
            return .pad
        } else if maxDimension > 100 {
            return .phone
        } else {
            return .unknown
        }
    }

    private func determineOrientation(screenSize: CGSize) -> SizeClassInfo.Orientation {
        let ratio = screenSize.width / screenSize.height

        if abs(ratio - 1.0) < 0.1 {
            return .square
        } else if screenSize.width > screenSize.height {
            return .landscape
        } else {
            return .portrait
        }
    }
}

// MARK: - Adaptive Grid Layout

public struct AdaptiveFluidGrid<Content: View>: View {
    let columns: [GridItem]
    let spacing: CGFloat
    let content: () -> Content

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var layoutManager = AdaptiveFluidLayoutManager.shared

    public init(
        columns: [GridItem]? = nil,
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = columns ?? []
        self.spacing = spacing ?? 12
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                gridContent(for: geometry)
            }
        }
        .onAppear {
            Task { @MainActor in
                updateLayoutManagerAsync(geometry: nil)
            }
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            Task { @MainActor in
                updateLayoutManagerAsync(geometry: nil)
            }
        }
        .onChange(of: verticalSizeClass) { _, _ in
            Task { @MainActor in
                updateLayoutManagerAsync(geometry: nil)
            }
        }
    }

    @ViewBuilder
    private func gridContent(for geometry: GeometryProxy) -> some View {
        LazyVGrid(
            columns: adaptiveColumns(for: geometry.size),
            spacing: adaptiveSpacing,
            pinnedViews: []
        ) {
            content()
        }
        .frame(maxWidth: layoutManagerShouldUseContainerRelative ? .infinity : nil)
        .padding(layoutManager.currentSizeClass.padding)
        .animation(currentAnimation, value: layoutManager.currentSizeClass.recommendedColumnCount)
    }

    private var layoutManagerShouldUseContainerRelative: Bool {
        layoutManager.compatibilityLayer.isIOS26Available && layoutManager.featureFlags.isEnabled(.adaptiveLayouts)
    }

    private var currentAnimation: Animation {
        if layoutManager.compatibilityLayer.isIOS26Available,
           layoutManager.featureFlags.isEnabled(.adaptiveLayouts) {
            if #available(iOS 26.0, *) {
                return .smooth(duration: 0.4)
            }
        }
        return .easeInOut(duration: 0.3)
    }

    @State private var cachedColumns: [GridItem] = []
    @State private var cachedSize: CGSize = .zero

    private func adaptiveColumns(for size: CGSize) -> [GridItem] {
        // Use cached values to avoid state updates during rendering
        if !columns.isEmpty {
            return columns
        }

        if cachedSize != size {
            // Schedule async update instead of immediate update
            Task { @MainActor in
                updateLayoutManagerAsync(geometry: size)
            }
        }

        let columnCount = layoutManager.currentSizeClass.recommendedColumnCount
        return Array(repeating: GridItem(.flexible(), spacing: adaptiveSpacing), count: columnCount)
    }

    private var adaptiveSpacing: CGFloat {
        spacing > 0 ? spacing : layoutManager.currentSizeClass.spacing
    }

    private func updateLayoutManager(geometry: CGSize?) {
        let screen = getMainScreen()
        let size = geometry ?? CGSize(width: screen.bounds.width, height: screen.bounds.height)
        layoutManager.updateSizeClass(
            horizontalSizeClass ?? .regular,
            verticalSizeClass ?? .regular,
            screenSize: size
        )
    }

    private func updateLayoutManagerAsync(geometry: CGSize?) {
        guard cachedSize != geometry else { return }

        let screen = getMainScreen()
        let size = geometry ?? CGSize(width: screen.bounds.width, height: screen.bounds.height)
        cachedSize = size

        layoutManager.updateSizeClass(
            horizontalSizeClass ?? .regular,
            verticalSizeClass ?? .regular,
            screenSize: size
        )

        let columnCount = layoutManager.currentSizeClass.recommendedColumnCount
        cachedColumns = Array(repeating: GridItem(.flexible(), spacing: adaptiveSpacing), count: columnCount)
    }
}

// MARK: - Adaptive Container

public struct AdaptiveFluidContainer<Content: View>: View {
    let content: () -> Content
    let maxWidth: CGFloat?
    let alignment: HorizontalAlignment

    @StateObject private var layoutManager = AdaptiveFluidLayoutManager.shared

    public init(
        maxWidth: CGFloat? = nil,
        alignment: HorizontalAlignment = .center,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxWidth = maxWidth
        self.alignment = alignment
        self.content = content
    }

    public var body: some View {
        if layoutManager.featureFlags.isEnabled(.adaptiveLayouts) && layoutManager.compatibilityLayer.isIOS26Available {
            if #available(iOS 26.0, *) {
                modernContainer
            } else {
                legacyContainer
            }
        } else {
            legacyContainer
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var modernContainer: some View {
        VStack(alignment: alignment) {
            content()
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            if let maxWidth = maxWidth {
                return min(width, maxWidth)
            }
            return width
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    @ViewBuilder
    private var legacyContainer: some View {
        VStack(alignment: alignment) {
            content()
        }
        .frame(maxWidth: maxWidth ?? .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

// MARK: - Responsive Dashboard Cards

public struct ResponsiveDashboardCards<Content: View>: View {
    let content: () -> Content
    let minimumCardWidth: CGFloat
    let maximumCardWidth: CGFloat

    @StateObject private var layoutManager = AdaptiveFluidLayoutManager.shared

    public init(
        minimumCardWidth: CGFloat = 150,
        maximumCardWidth: CGFloat = 300,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minimumCardWidth = minimumCardWidth
        self.maximumCardWidth = maximumCardWidth
        self.content = content
    }

    public var body: some View {
        AdaptiveFluidGrid(
            columns: responsiveColumns,
            spacing: layoutManager.currentSizeClass.spacing
        ) {
            content()
        }
    }

    private var responsiveColumns: [GridItem] {
        let columnCount = layoutManager.currentSizeClass.recommendedColumnCount
        let spacing = layoutManager.currentSizeClass.spacing

        return Array(repeating: GridItem(
            .adaptive(minimum: minimumCardWidth, maximum: maximumCardWidth),
            spacing: spacing
        ), count: columnCount)
    }
}

// MARK: - Environment Integration

private struct AdaptiveFluidLayoutManagerKey: EnvironmentKey {
    static let defaultValue = AdaptiveFluidLayoutManager.shared
}

public extension EnvironmentValues {
    var adaptiveLayout: AdaptiveFluidLayoutManager {
        get { self[AdaptiveFluidLayoutManagerKey.self] }
        set { self[AdaptiveFluidLayoutManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Applies adaptive fluid layout container
    func adaptiveContainer(
        maxWidth: CGFloat? = nil,
        alignment: HorizontalAlignment = .center
    ) -> some View {
        AdaptiveFluidContainer(maxWidth: maxWidth, alignment: alignment) {
            self
        }
    }

    /// Creates responsive dashboard card grid
    func responsiveDashboardGrid(
        minimumCardWidth: CGFloat = 150,
        maximumCardWidth: CGFloat = 300
    ) -> some View {
        ResponsiveDashboardCards(
            minimumCardWidth: minimumCardWidth,
            maximumCardWidth: maximumCardWidth
        ) {
            self
        }
    }

    /// Applies size class-aware padding
    func adaptivePadding() -> some View {
        self.modifier(AdaptivePaddingModifier())
    }

    /// Applies size class-aware spacing
    func adaptiveSpacing(_ factor: CGFloat = 1.0) -> some View {
        self.modifier(AdaptiveSpacingModifier(factor: factor))
    }
}

// MARK: - Adaptive Modifiers

public struct AdaptivePaddingModifier: ViewModifier {
    @StateObject private var layoutManager = AdaptiveFluidLayoutManager.shared

    public func body(content: Content) -> some View {
        content
            .padding(layoutManager.currentSizeClass.padding)
    }
}

public struct AdaptiveSpacingModifier: ViewModifier {
    let factor: CGFloat
    @StateObject private var layoutManager = AdaptiveFluidLayoutManager.shared

    public init(factor: CGFloat = 1.0) {
        self.factor = factor
    }

    public func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .padding(.vertical, layoutManager.currentSizeClass.spacing * factor)
        } else {
            content
                .padding(.vertical, layoutManager.currentSizeClass.spacing * factor)
        }
    }
}

// MARK: - Layout Performance Monitoring

public extension AdaptiveFluidLayoutManager {
    func generateLayoutReport() -> LayoutPerformanceReport {
        return LayoutPerformanceReport(
            currentSizeClass: currentSizeClass,
            layoutMode: layoutMode,
            isOptimizedForAccessibility: isOptimizedForAccessibility,
            deviceCapabilities: DeviceCapabilities()
        )
    }

    struct LayoutPerformanceReport {
        public let currentSizeClass: SizeClassInfo
        public let layoutMode: LayoutMode
        public let isOptimizedForAccessibility: Bool
        public let deviceCapabilities: DeviceCapabilities

        public var summary: String {
            """
            Adaptive Layout Performance Report
            ==================================
            Size Class: \(currentSizeClass.horizontal) x \(currentSizeClass.vertical)
            Device Type: \(currentSizeClass.deviceType)
            Orientation: \(currentSizeClass.orientation)
            Layout Mode: \(layoutMode.displayName)
            Accessibility Optimized: \(isOptimizedForAccessibility)

            Recommended Columns: \(currentSizeClass.recommendedColumnCount)
            Spacing: \(String(format: "%.1f", currentSizeClass.spacing))pt
            Padding: T\(String(format: "%.0f", currentSizeClass.padding.top)) L\(String(format: "%.0f", currentSizeClass.padding.leading)) B\(String(format: "%.0f", currentSizeClass.padding.bottom)) R\(String(format: "%.0f", currentSizeClass.padding.trailing))

            Device Memory: \(deviceCapabilities.totalMemoryMB)MB
            CPU Cores: \(deviceCapabilities.processorCount)
            """
        }
    }

    struct DeviceCapabilities {
        public let totalMemoryMB: Int
        public let processorCount: Int
        public let screenScale: CGFloat

        @MainActor
        public init() {
            self.totalMemoryMB = Int(ProcessInfo.processInfo.physicalMemory / 1_000_000)
            self.processorCount = ProcessInfo.processInfo.processorCount
            self.screenScale = getMainScreen().scale
        }
    }
}
