//
//  LopanPerformanceUtils.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI
import Combine

/// Comprehensive performance utilities for Lopan production management app
/// Provides memory management, caching, and performance optimization tools
public final class LopanPerformanceUtils {

    public static let shared = LopanPerformanceUtils()

    private init() {}

    // MARK: - Memory Management

    /// Memory pressure monitoring and handling
    public final class MemoryManager: ObservableObject {

        public static let shared = MemoryManager()

        @Published public var memoryPressureLevel: MemoryPressureLevel = .normal
        @Published public var shouldReduceQuality: Bool = false

        private var memoryPressureSource: DispatchSourceMemoryPressure?

        public enum MemoryPressureLevel {
            case normal
            case warning
            case critical

            var description: String {
                switch self {
                case .normal: return "正常"
                case .warning: return "警告"
                case .critical: return "严重"
                }
            }
        }

        private init() {
            setupMemoryPressureMonitoring()
        }

        private func setupMemoryPressureMonitoring() {
            memoryPressureSource = DispatchSource.makeMemoryPressureSource(
                eventMask: [.warning, .critical],
                queue: .main
            )

            memoryPressureSource?.setEventHandler { [weak self] in
                guard let self = self else { return }

                let event = self.memoryPressureSource?.mask

                if event?.contains(.critical) == true {
                    self.memoryPressureLevel = .critical
                    self.shouldReduceQuality = true
                    self.handleCriticalMemoryPressure()
                } else if event?.contains(.warning) == true {
                    self.memoryPressureLevel = .warning
                    self.shouldReduceQuality = true
                    self.handleMemoryWarning()
                }

                #if DEBUG
                print("🧠 LopanPerformance: Memory pressure level: \(self.memoryPressureLevel.description)")
                #endif
            }

            memoryPressureSource?.resume()
        }

        private func handleMemoryWarning() {
            // Clear non-essential caches
            LopanPerformanceImageCache.shared.clearOldEntries()

            // Post notification for views to reduce quality
            NotificationCenter.default.post(
                name: .lopanMemoryWarning,
                object: self
            )
        }

        private func handleCriticalMemoryPressure() {
            // Aggressive memory cleanup
            LopanPerformanceImageCache.shared.clearAll()

            // Post notification for emergency cleanup
            NotificationCenter.default.post(
                name: .lopanCriticalMemoryPressure,
                object: self
            )
        }

        deinit {
            memoryPressureSource?.cancel()
        }
    }

    // MARK: - Image Caching

    /// Intelligent image caching with memory pressure awareness
    public final class LopanPerformanceImageCache {

        public static let shared = LopanPerformanceImageCache()

        private let cache = NSCache<NSString, UIImage>()
        private let queue = DispatchQueue(label: "com.lopan.imagecache", qos: .utility)
        private var accessTimes: [String: Date] = [:]

        private init() {
            setupCache()
            observeMemoryWarnings()
        }

        private func setupCache() {
            cache.countLimit = 100
            cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        }

        private func observeMemoryWarnings() {
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.clearOldEntries()
            }
        }

        public func setImage(_ image: UIImage, forKey key: String) {
            queue.async { [weak self] in
                guard let self = self else { return }

                let cost = Int(image.size.width * image.size.height * 4) // Rough byte estimate
                self.cache.setObject(image, forKey: NSString(string: key), cost: cost)
                self.accessTimes[key] = Date()
            }
        }

        public func image(forKey key: String) -> UIImage? {
            let image = cache.object(forKey: NSString(string: key))
            if image != nil {
                queue.async { [weak self] in
                    self?.accessTimes[key] = Date()
                }
            }
            return image
        }

        public func clearOldEntries() {
            queue.async { [weak self] in
                guard let self = self else { return }

                let cutoffDate = Date().addingTimeInterval(-300) // 5 minutes ago
                let oldKeys = self.accessTimes.compactMap { key, date in
                    date < cutoffDate ? key : nil
                }

                oldKeys.forEach { key in
                    self.cache.removeObject(forKey: NSString(string: key))
                    self.accessTimes.removeValue(forKey: key)
                }

                #if DEBUG
                print("🗑️ LopanPerformance: Cleared \(oldKeys.count) old image cache entries")
                #endif
            }
        }

        public func clearAll() {
            cache.removeAllObjects()
            queue.async { [weak self] in
                self?.accessTimes.removeAll()
            }

            #if DEBUG
            print("🗑️ LopanPerformance: Cleared all image cache entries")
            #endif
        }
    }

    // MARK: - Data Pagination

    /// Smart pagination manager for large datasets
    public final class PaginationManager<T: Identifiable>: ObservableObject {

        @Published public var items: [T] = []
        @Published public var isLoading = false
        @Published public var hasMorePages = true
        @Published public var error: Error?

        private let pageSize: Int
        private let loadDataHandler: (Int, Int) async throws -> ([T], Bool)
        private var currentPage = 0

        public init(
            pageSize: Int = 20,
            loadData: @escaping (Int, Int) async throws -> ([T], Bool) // (page, size) -> (items, hasMore)
        ) {
            self.pageSize = pageSize
            self.loadDataHandler = loadData
        }

        @MainActor
        public func loadInitialData() async {
            guard !isLoading else { return }

            isLoading = true
            error = nil
            items.removeAll()
            currentPage = 0

            do {
                let (newItems, hasMore) = try await loadDataHandler(currentPage, pageSize)
                items = newItems
                hasMorePages = hasMore
                currentPage += 1
            } catch {
                self.error = error
                #if DEBUG
                print("❌ LopanPerformance: Pagination initial load error: \\(error)")
                #endif
            }

            isLoading = false
        }

        @MainActor
        public func loadNextPage() async {
            guard !isLoading && hasMorePages else { return }

            isLoading = true

            do {
                let (newItems, hasMore) = try await loadDataHandler(currentPage, pageSize)
                items.append(contentsOf: newItems)
                hasMorePages = hasMore
                currentPage += 1

                #if DEBUG
                print("📄 LopanPerformance: Loaded page \\(currentPage), items: \\(newItems.count)")
                #endif
            } catch {
                self.error = error
                #if DEBUG
                print("❌ LopanPerformance: Pagination load error: \\(error)")
                #endif
            }

            isLoading = false
        }

        @MainActor
        public func refresh() async {
            await loadInitialData()
        }
    }

    // MARK: - View Performance Monitoring

    /// Performance monitoring for individual views
    public struct ViewPerformanceModifier: ViewModifier {

        let viewName: String
        @State private var renderStartTime: Date?
        @StateObject private var monitor = LopanPerformanceMonitor.shared

        public func body(content: Content) -> some View {
            content
                .onAppear {
                    renderStartTime = Date()
                    monitor.startTiming(for: "\\(viewName)_render")
                }
                .onDisappear {
                    if let startTime = renderStartTime {
                        let renderTime = Date().timeIntervalSince(startTime)
                        monitor.endTiming(for: "\\(viewName)_render")

                        #if DEBUG
                        if renderTime > 0.1 { // Warn for slow renders
                            print("⚠️ LopanPerformance: \(viewName) slow render: \(String(format: "%.3f", renderTime))s")
                        }
                        #endif
                    }
                }
        }
    }

    // MARK: - Throttling and Debouncing

    /// Throttle rapid state changes to improve performance
    public final class Throttler: ObservableObject {

        @Published public var value: String = ""

        private let delay: TimeInterval
        private var cancellable: AnyCancellable?

        public init(delay: TimeInterval = 0.3) {
            self.delay = delay
        }

        public func throttle<T: Equatable>(_ input: Published<T>.Publisher) -> AnyPublisher<T, Never> {
            input
                .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
                .removeDuplicates()
                .eraseToAnyPublisher()
        }
    }

    // MARK: - Background Task Management

    /// Manage background tasks efficiently
    public final class BackgroundTaskManager {

        public static let shared = BackgroundTaskManager()

        private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        private let queue = DispatchQueue(label: "com.lopan.background", qos: .utility)

        private init() {}

        public func performBackgroundTask<T>(
            name: String,
            task: @escaping () async throws -> T
        ) async throws -> T {
            return try await withCheckedThrowingContinuation { continuation in
                backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: name) {
                    self.endBackgroundTask()
                }

                Task {
                    do {
                        let result = try await task()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }

                    self.endBackgroundTask()
                }
            }
        }

        private func endBackgroundTask() {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    public static let lopanMemoryWarning = Notification.Name("LopanMemoryWarning")
    public static let lopanCriticalMemoryPressure = Notification.Name("LopanCriticalMemoryPressure")
}

// MARK: - SwiftUI Extensions

extension View {
    /// Add performance monitoring to any view
    public func lopanPerformanceMonitored(viewName: String) -> some View {
        self.modifier(LopanPerformanceUtils.ViewPerformanceModifier(viewName: viewName))
    }

    /// Reduce quality under memory pressure
    public func lopanMemoryOptimized() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .lopanMemoryWarning)) { notification in
            // Views can override this to reduce quality
        }
    }

    /// Smart image loading with caching
    public func lopanCachedImage(url: String, placeholder: Image = Image(systemName: "photo")) -> some View {
        self.overlay(
            LopanAsyncImage(url: url, placeholder: placeholder)
        )
    }
}

// MARK: - Cached Image Component

/// High-performance async image with intelligent caching
private struct LopanAsyncImage: View {
    let url: String
    let placeholder: Image

    @State private var image: UIImage?
    @State private var isLoading = false
    @StateObject private var memoryManager = LopanPerformanceUtils.MemoryManager.shared

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: memoryManager.shouldReduceQuality ? .fit : .fill)
            } else if isLoading {
                LopanSkeletonView(style: .rectangular(width: nil, height: 200))
            } else {
                placeholder
                    .foregroundColor(LopanColors.textTertiary)
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check cache first
        if let cachedImage = LopanPerformanceUtils.LopanPerformanceImageCache.shared.image(forKey: url) {
            self.image = cachedImage
            return
        }

        // Load from network
        isLoading = true

        do {
            guard let imageUrl = URL(string: url) else { return }
            let (data, _) = try await URLSession.shared.data(from: imageUrl)

            if let uiImage = UIImage(data: data) {
                // Resize if under memory pressure
                let finalImage = memoryManager.shouldReduceQuality
                    ? uiImage.resized(to: CGSize(width: 200, height: 200))
                    : uiImage

                LopanPerformanceUtils.LopanPerformanceImageCache.shared.setImage(finalImage, forKey: url)

                await MainActor.run {
                    self.image = finalImage
                }
            }
        } catch {
            #if DEBUG
            print("❌ LopanPerformance: Image load error: \\(error)")
            #endif
        }

        isLoading = false
    }
}

// MARK: - UIImage Extensions

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Performance Dashboard (Debug)

#if DEBUG
public struct LopanPerformanceDashboard: View {
    @StateObject private var monitor = LopanPerformanceMonitor.shared
    @StateObject private var memoryManager = LopanPerformanceUtils.MemoryManager.shared

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                Section("内存状态") {
                    HStack {
                        Text("内存压力等级")
                        Spacer()
                        Text(memoryManager.memoryPressureLevel.description)
                            .foregroundColor(colorForMemoryLevel(memoryManager.memoryPressureLevel))
                    }

                    HStack {
                        Text("降低质量模式")
                        Spacer()
                        Text(memoryManager.shouldReduceQuality ? "开启" : "关闭")
                            .foregroundColor(memoryManager.shouldReduceQuality ? LopanColors.warning : LopanColors.success)
                    }
                }

                Section("加载时间") {
                    ForEach(Array(monitor.loadTimes.keys), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(String(format: "%.3f", monitor.loadTimes[key] ?? 0))s")
                                .foregroundColor(colorForLoadTime(monitor.loadTimes[key] ?? 0))
                        }
                    }
                }

                Section("滚动性能") {
                    ForEach(Array(monitor.scrollPerformance.keys), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(String(format: "%.1f", monitor.scrollPerformance[key] ?? 0))fps")
                                .foregroundColor(colorForFPS(monitor.scrollPerformance[key] ?? 0))
                        }
                    }
                }
            }
            .navigationTitle("性能监控")
        }
    }

    private func colorForMemoryLevel(_ level: LopanPerformanceUtils.MemoryManager.MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func colorForLoadTime(_ time: TimeInterval) -> Color {
        time < 0.1 ? .green : time < 0.5 ? .orange : .red
    }

    private func colorForFPS(_ fps: Double) -> Color {
        fps >= 55 ? .green : fps >= 30 ? .orange : .red
    }
}
#endif