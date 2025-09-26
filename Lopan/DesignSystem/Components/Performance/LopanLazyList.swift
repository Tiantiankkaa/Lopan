//
//  LopanLazyList.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI

/// High-performance lazy loading list with built-in skeleton states and infinite scroll
/// Optimized for large datasets with accessibility and iOS 26 performance patterns
public struct LopanLazyList<Data: RandomAccessCollection, Content: View, SkeletonContent: View>: View
where Data.Element: Identifiable, Data.Element: Hashable {

    // MARK: - Properties

    private let data: Data
    private let content: (Data.Element) -> Content
    private let skeletonContent: () -> SkeletonContent
    private let configuration: Configuration

    @State private var isLoading: Bool
    @State private var hasReachedEnd = false
    @State private var scrollPosition: String?

    // MARK: - Configuration

    public struct Configuration {
        let isLoading: Bool
        let skeletonCount: Int
        let spacing: CGFloat
        let showsIndicators: Bool
        let onLoadMore: (() -> Void)?
        let onRefresh: (() -> Void)?
        let loadMoreThreshold: Int
        let accessibilityLabel: String

        public init(
            isLoading: Bool = false,
            skeletonCount: Int = 5,
            spacing: CGFloat = LopanSpacing.sm,
            showsIndicators: Bool = false,
            onLoadMore: (() -> Void)? = nil,
            onRefresh: (() -> Void)? = nil,
            loadMoreThreshold: Int = 3,
            accessibilityLabel: String = "列表"
        ) {
            self.isLoading = isLoading
            self.skeletonCount = skeletonCount
            self.spacing = spacing
            self.showsIndicators = showsIndicators
            self.onLoadMore = onLoadMore
            self.onRefresh = onRefresh
            self.loadMoreThreshold = loadMoreThreshold
            self.accessibilityLabel = accessibilityLabel
        }
    }

    // MARK: - Initialization

    public init(
        data: Data,
        configuration: Configuration = Configuration(),
        @ViewBuilder content: @escaping (Data.Element) -> Content,
        @ViewBuilder skeletonContent: @escaping () -> SkeletonContent
    ) {
        self.data = data
        self.content = content
        self.skeletonContent = skeletonContent
        self.configuration = configuration
        self._isLoading = State(initialValue: configuration.isLoading)
    }

    // MARK: - Body

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: configuration.showsIndicators) {
                LazyVStack(spacing: configuration.spacing) {
                    if isLoading && data.isEmpty {
                        // Initial loading skeleton
                        ForEach(0..<configuration.skeletonCount, id: \.self) { index in
                            skeletonContent()
                                .lopanAccessibility(
                                    role: .loading,
                                    label: "加载中的列表项 \(index + 1)",
                                    hint: "等待内容加载"
                                )
                                .animation(
                                    LopanAnimation.listItemAppear.delay(Double(index) * 0.05),
                                    value: isLoading
                                )
                        }
                    } else {
                        // Actual content
                        ForEach(Array(data.enumerated()), id: \.element) { index, item in
                            content(item)
                                .onAppear {
                                    checkForLoadMore(at: index)
                                }
                                .transition(.lopanListItemTransition)
                                .animation(
                                    LopanAnimation.listItemAppear.delay(Double(index % 10) * 0.02),
                                    value: data.count
                                )
                        }

                        // Loading more skeleton at bottom
                        if isLoading && !data.isEmpty {
                            VStack(spacing: configuration.spacing) {
                                ForEach(0..<3, id: \.self) { index in
                                    skeletonContent()
                                        .lopanAccessibility(
                                            role: .loading,
                                            label: "加载更多内容 \(index + 1)",
                                            hint: "正在获取更多数据"
                                        )
                                }
                            }
                            .transition(.lopanListItemTransition)
                        }
                    }
                }
                .padding(.horizontal, LopanSpacing.md)
                .padding(.vertical, LopanSpacing.sm)
            }
            .scrollPosition(id: $scrollPosition)
            .refreshable {
                await performRefresh()
            }
            .lopanAccessibility(
                role: .list,
                label: configuration.accessibilityLabel,
                hint: data.isEmpty ? "列表为空" : "包含 \(data.count) 个项目"
            )
        }
        .animation(LopanAnimation.contentRefresh, value: isLoading)
        .onChange(of: configuration.isLoading) { _, newValue in
            isLoading = newValue
        }
    }

    // MARK: - Private Methods

    private func checkForLoadMore(at index: Int) {
        let thresholdIndex = data.count - configuration.loadMoreThreshold
        if index >= thresholdIndex && !isLoading && !hasReachedEnd {
            configuration.onLoadMore?()
        }
    }

    @MainActor
    private func performRefresh() async {
        guard let onRefresh = configuration.onRefresh else { return }

        LopanHapticEngine.shared.perform(.pullToRefresh)

        // Reset end state on refresh
        hasReachedEnd = false

        await withCheckedContinuation { continuation in
            onRefresh()
            continuation.resume()
        }
    }
}

// MARK: - Grid Variant

/// High-performance lazy loading grid with built-in skeleton states
public struct LopanLazyGrid<Data: RandomAccessCollection, Content: View, SkeletonContent: View>: View
where Data.Element: Identifiable, Data.Element: Hashable {

    // MARK: - Properties

    private let data: Data
    private let columns: [GridItem]
    private let content: (Data.Element) -> Content
    private let skeletonContent: () -> SkeletonContent
    private let configuration: LopanLazyList<Data, Content, SkeletonContent>.Configuration

    @State private var isLoading: Bool

    // MARK: - Initialization

    public init(
        data: Data,
        columns: [GridItem],
        configuration: LopanLazyList<Data, Content, SkeletonContent>.Configuration = .init(),
        @ViewBuilder content: @escaping (Data.Element) -> Content,
        @ViewBuilder skeletonContent: @escaping () -> SkeletonContent
    ) {
        self.data = data
        self.columns = columns
        self.content = content
        self.skeletonContent = skeletonContent
        self.configuration = configuration
        self._isLoading = State(initialValue: configuration.isLoading)
    }

    // MARK: - Body

    public var body: some View {
        ScrollView(.vertical, showsIndicators: configuration.showsIndicators) {
            LazyVGrid(columns: columns, spacing: configuration.spacing) {
                if isLoading && data.isEmpty {
                    // Initial loading skeleton
                    ForEach(0..<configuration.skeletonCount, id: \.self) { index in
                        skeletonContent()
                            .lopanAccessibility(
                                role: .loading,
                                label: "加载中的网格项 \(index + 1)",
                                hint: "等待内容加载"
                            )
                            .animation(
                                LopanAnimation.listItemAppear.delay(Double(index) * 0.03),
                                value: isLoading
                            )
                    }
                } else {
                    // Actual content
                    ForEach(Array(data.enumerated()), id: \.element) { index, item in
                        content(item)
                            .onAppear {
                                checkForLoadMore(at: index)
                            }
                            .transition(.lopanScaleAndFade)
                            .animation(
                                LopanAnimation.listItemAppear.delay(Double(index % 12) * 0.02),
                                value: data.count
                            )
                    }

                    // Loading more skeleton
                    if isLoading && !data.isEmpty {
                        ForEach(0..<(columns.count * 2), id: \.self) { index in
                            skeletonContent()
                                .lopanAccessibility(
                                    role: .loading,
                                    label: "加载更多网格项 \(index + 1)",
                                    hint: "正在获取更多数据"
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, LopanSpacing.sm)
        }
        .refreshable {
            await performRefresh()
        }
        .lopanAccessibility(
            role: .grid,
            label: configuration.accessibilityLabel,
            hint: data.isEmpty ? "网格为空" : "包含 \(data.count) 个项目"
        )
        .animation(LopanAnimation.contentRefresh, value: isLoading)
        .onChange(of: configuration.isLoading) { _, newValue in
            isLoading = newValue
        }
    }

    private func checkForLoadMore(at index: Int) {
        let thresholdIndex = data.count - configuration.loadMoreThreshold
        if index >= thresholdIndex && !isLoading {
            configuration.onLoadMore?()
        }
    }

    @MainActor
    private func performRefresh() async {
        guard let onRefresh = configuration.onRefresh else { return }

        LopanHapticEngine.shared.perform(.pullToRefresh)

        await withCheckedContinuation { continuation in
            onRefresh()
            continuation.resume()
        }
    }
}

// MARK: - Performance Monitoring

/// Performance monitoring utility for lazy loading components
public final class LopanPerformanceMonitor: ObservableObject {

    public static let shared = LopanPerformanceMonitor()

    @Published public var loadTimes: [String: TimeInterval] = [:]
    @Published public var scrollPerformance: [String: Double] = [:]

    private var startTimes: [String: Date] = [:]

    private init() {}

    /// Start timing a loading operation
    public func startTiming(for operation: String) {
        startTimes[operation] = Date()
    }

    /// End timing and record the result
    public func endTiming(for operation: String) {
        guard let startTime = startTimes[operation] else { return }
        let duration = Date().timeIntervalSince(startTime)
        loadTimes[operation] = duration
        startTimes.removeValue(forKey: operation)

        #if DEBUG
        print("📊 LopanPerformance: \(operation) took \(String(format: "%.3f", duration))s")
        #endif
    }

    /// Record scroll performance metrics
    public func recordScrollPerformance(for component: String, fps: Double) {
        scrollPerformance[component] = fps

        #if DEBUG
        if fps < 55 {
            print("⚠️ LopanPerformance: \\(component) scroll performance below 55fps: \\(fps)")
        }
        #endif
    }

    /// Get performance summary
    public var performanceSummary: String {
        var summary = "📊 LopanPerformance Summary:\\n"

        if !loadTimes.isEmpty {
            summary += "Load Times:\\n"
            for (operation, time) in loadTimes.sorted(by: { $0.value > $1.value }) {
                summary += "  • \(operation): \(String(format: "%.3f", time))s\n"
            }
        }

        if !scrollPerformance.isEmpty {
            summary += "Scroll Performance:\\n"
            for (component, fps) in scrollPerformance.sorted(by: { $0.value < $1.value }) {
                let status = fps >= 55 ? "✅" : "⚠️"
                summary += "  \(status) \(component): \(String(format: "%.1f", fps))fps\n"
            }
        }

        return summary
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Add performance monitoring to any view
    public func lopanPerformanceMonitored(
        operation: String,
        monitor: LopanPerformanceMonitor = .shared
    ) -> some View {
        self
            .onAppear {
                monitor.startTiming(for: operation)
            }
            .onDisappear {
                monitor.endTiming(for: operation)
            }
    }
}

// MARK: - Common List Configurations

extension LopanLazyList.Configuration {

    /// Configuration for user management lists
    public static func userManagement(
        isLoading: Bool = false,
        onLoadMore: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil
    ) -> Self {
        Self(
            isLoading: isLoading,
            skeletonCount: 8,
            spacing: LopanSpacing.sm,
            onLoadMore: onLoadMore,
            onRefresh: onRefresh,
            loadMoreThreshold: 5,
            accessibilityLabel: "用户管理列表"
        )
    }

    /// Configuration for product lists
    public static func productManagement(
        isLoading: Bool = false,
        onLoadMore: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil
    ) -> Self {
        Self(
            isLoading: isLoading,
            skeletonCount: 6,
            spacing: LopanSpacing.md,
            onLoadMore: onLoadMore,
            onRefresh: onRefresh,
            loadMoreThreshold: 3,
            accessibilityLabel: "产品管理列表"
        )
    }

    /// Configuration for dashboard components
    public static func dashboard(
        isLoading: Bool = false,
        onRefresh: (() -> Void)? = nil
    ) -> Self {
        Self(
            isLoading: isLoading,
            skeletonCount: 4,
            spacing: LopanSpacing.lg,
            onRefresh: onRefresh,
            accessibilityLabel: "仪表板"
        )
    }
}

// MARK: - Preview

#Preview {
    struct SampleItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    struct ContentView: View {
        @State private var items: [SampleItem] = []
        @State private var isLoading = true

        var body: some View {
            LopanLazyList(
                data: items,
                configuration: .userManagement(
                    isLoading: isLoading,
                    onLoadMore: loadMore,
                    onRefresh: refresh
                )
            ) { item in
                VStack(alignment: .leading) {
                    Text(item.title)
                        .lopanTitleMedium()
                    Text(item.subtitle)
                        .lopanBodySmall()
                        .foregroundColor(LopanColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(LopanColors.surface)
                .cornerRadius(LopanCornerRadius.card)
            } skeletonContent: {
                LopanSkeletonView.userListItem()
            }
            .onAppear {
                loadInitialData()
            }
        }

        private func loadInitialData() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                items = (1...10).map { SampleItem(title: "项目 \($0)", subtitle: "描述 \($0)") }
                isLoading = false
            }
        }

        private func loadMore() {
            let startIndex = items.count + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                items.append(contentsOf: (startIndex...(startIndex + 5)).map {
                    SampleItem(title: "项目 \($0)", subtitle: "描述 \($0)")
                })
            }
        }

        private func refresh() {
            items = []
            isLoading = true
            loadInitialData()
        }
    }

    return ContentView()
}