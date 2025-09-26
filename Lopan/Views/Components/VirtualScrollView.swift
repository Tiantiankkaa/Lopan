//
//  VirtualScrollView.swift
//  Lopan
//
//  Created by Claude Code for Performance Optimization
//

import SwiftUI

struct VirtualScrollView<Content: View, Item: Identifiable & Equatable>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let content: (Item) -> Content
    
    @State private var visibleItems: [Item] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    
    // Performance tracking
    @State private var isScrolling = false
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollTime = Date()
    
    // Prefetch settings
    private let bufferCount = 3 // Items to load before/after visible area
    private let prefetchThreshold: CGFloat = 100 // Distance to start prefetching
    
    init(
        items: [Item],
        itemHeight: CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleItemsWithBuffer, id: \.id) { item in
                            content(item)
                                .frame(height: itemHeight)
                                .id(item.id)
                                .onAppear {
                                    prefetchIfNeeded(item: item)
                                }
                        }
                        .background(
                            GeometryReader { itemGeometry in
                                LopanColors.clear
                                    .onAppear {
                                        updateScrollOffset(itemGeometry.frame(in: .named("scroll")).minY)
                                    }
                                    .onChange(of: itemGeometry.frame(in: .named("scroll")).minY) { _, newValue in
                                        updateScrollOffset(newValue)
                                    }
                            }
                        )
                    }
                    .frame(height: CGFloat(items.count) * itemHeight)
                }
                .coordinateSpace(name: "scroll")
                .onAppear {
                    containerHeight = geometry.size.height
                    updateVisibleItems()
                }
                .onChange(of: scrollOffset) { _, _ in
                    updateVisibleItems()
                    trackScrollVelocity()
                }
                .onChange(of: items) { _, _ in
                    updateVisibleItems()
                }
            }
        }
    }
    
    private var visibleItemsWithBuffer: [Item] {
        let visibleCount = Int(containerHeight / itemHeight) + 1
        let startIndex = max(0, Int(-scrollOffset / itemHeight) - bufferCount)
        let endIndex = min(items.count, startIndex + visibleCount + (bufferCount * 2))
        
        return Array(items[startIndex..<endIndex])
    }
    
    private func updateScrollOffset(_ newOffset: CGFloat) {
        scrollOffset = newOffset
    }
    
    private func updateVisibleItems() {
        let visibleCount = Int(containerHeight / itemHeight) + 1
        let startIndex = max(0, Int(-scrollOffset / itemHeight))
        let endIndex = min(items.count, startIndex + visibleCount)
        
        visibleItems = Array(items[startIndex..<endIndex])
    }
    
    private func prefetchIfNeeded(item: Item) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Prefetch next items if we're near the end of visible items
        let remainingItems = items.count - itemIndex
        if remainingItems <= bufferCount {
            // Trigger prefetch for additional data if needed
            NotificationCenter.default.post(
                name: NSNotification.Name("PrefetchData"),
                object: nil,
                userInfo: ["itemIndex": itemIndex]
            )
        }
    }
    
    private func trackScrollVelocity() {
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastScrollTime)
        
        if timeDelta > 0 {
            scrollVelocity = abs(scrollOffset) / CGFloat(timeDelta)
            
            // Adaptive quality based on scroll speed
            let isHighVelocity = scrollVelocity > 1000
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollVelocityChanged"),
                object: nil,
                userInfo: [
                    "velocity": scrollVelocity,
                    "isHighSpeed": isHighVelocity
                ]
            )
        }
        
        lastScrollTime = currentTime
    }
}

// MARK: - Performance Monitoring

class ScrollPerformanceMonitor: ObservableObject {
    @Published var isHighPerformanceMode = false
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var scrollPerformance: ScrollPerformance = .smooth
    
    enum MemoryPressure {
        case normal
        case warning
        case critical
    }
    
    enum ScrollPerformance {
        case smooth
        case laggy
        case stuttering
    }
    
    private var frameRates: [Double] = []
    private let maxFrameRateEntries = 60
    
    init() {
        setupPerformanceMonitoring()
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor memory pressure
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.memoryPressure = .warning
            self.enableHighPerformanceMode()
        }
        
        // Monitor scroll performance
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ScrollVelocityChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let velocity = notification.userInfo?["velocity"] as? CGFloat {
                self.updateScrollPerformance(velocity: velocity)
            }
        }
    }
    
    func recordFrameRate(_ frameRate: Double) {
        frameRates.append(frameRate)
        if frameRates.count > maxFrameRateEntries {
            frameRates.removeFirst()
        }
        
        let averageFrameRate = frameRates.reduce(0, +) / Double(frameRates.count)
        updateScrollPerformance(averageFrameRate: averageFrameRate)
    }
    
    private func updateScrollPerformance(velocity: CGFloat) {
        if velocity > 2000 {
            enableHighPerformanceMode()
        }
    }
    
    private func updateScrollPerformance(averageFrameRate: Double) {
        if averageFrameRate < 45 {
            scrollPerformance = .stuttering
            enableHighPerformanceMode()
        } else if averageFrameRate < 55 {
            scrollPerformance = .laggy
        } else {
            scrollPerformance = .smooth
            disableHighPerformanceMode()
        }
    }
    
    private func enableHighPerformanceMode() {
        guard !isHighPerformanceMode else { return }
        isHighPerformanceMode = true
        
        // Reduce visual effects
        NotificationCenter.default.post(
            name: NSNotification.Name("EnableHighPerformanceMode"),
            object: nil
        )
    }
    
    private func disableHighPerformanceMode() {
        guard isHighPerformanceMode else { return }
        
        // Delay before disabling to avoid flickering
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isHighPerformanceMode = false
            NotificationCenter.default.post(
                name: NSNotification.Name("DisableHighPerformanceMode"),
                object: nil
            )
        }
    }
}

// MARK: - Virtual Scroll Image Cache

class VirtualScrollImageCache: ObservableObject {
    static let shared = VirtualScrollImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let memoryCapacity = 100 * 1024 * 1024 // 100MB
    private let maxConcurrentOperations = 5
    
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = maxConcurrentOperations
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    init() {
        cache.totalCostLimit = memoryCapacity
        setupMemoryWarnings()
    }
    
    private func setupMemoryWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.clearCache()
        }
    }
    
    func image(for key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Estimated memory cost
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
    }
    
    func prefetchImages(for keys: [String], data: [String: Data]) {
        for key in keys {
            guard image(for: key) == nil, let imageData = data[key] else { continue }
            
            operationQueue.addOperation { [weak self] in
                if let image = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        self?.setImage(image, for: key)
                    }
                }
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Lazy Loading Modifier

struct LazyLoadingModifier: ViewModifier {
    let threshold: CGFloat
    let onAppear: () -> Void
    
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    LopanColors.clear
                        .onAppear {
                            if !hasAppeared {
                                hasAppeared = true
                                onAppear()
                            }
                        }
                }
            )
    }
}

extension View {
    func lazyLoading(threshold: CGFloat = 50, onAppear: @escaping () -> Void) -> some View {
        self.modifier(LazyLoadingModifier(threshold: threshold, onAppear: onAppear))
    }
}

struct VirtualScrollView_Previews: PreviewProvider {
    static var previews: some View {
        struct SampleItem: Identifiable, Equatable {
            let id = UUID()
            let title: String
        }
        
        let sampleItems = (1...1000).map { SampleItem(title: "Item \($0)") }
        
        return VirtualScrollView(items: sampleItems, itemHeight: 60) { item in
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(LopanColors.backgroundTertiary)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
