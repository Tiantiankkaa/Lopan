//
//  VirtualListView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//  Enhanced for Phase 4: Performance & Polish - 60fps with 10K+ items
//

import SwiftUI
import Combine

// MARK: - Virtual List Protocol

protocol VirtualListItem: Identifiable, Hashable {
    var estimatedHeight: CGFloat { get }
    var actualHeight: CGFloat? { get set }
}

// MARK: - Virtual List Configuration

struct VirtualListConfiguration {
    let bufferSize: Int
    let estimatedItemHeight: CGFloat
    let maxVisibleItems: Int
    let prefetchRadius: Int
    let recyclingEnabled: Bool
    
    static let `default` = VirtualListConfiguration(
        bufferSize: 10,
        estimatedItemHeight: 120,
        maxVisibleItems: 50,
        prefetchRadius: 5,
        recyclingEnabled: true
    )
}

// MARK: - Virtual List State Manager

@MainActor
class VirtualListStateManager<Item: VirtualListItem>: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var visibleItems: [Item] = []
    @Published var isLoading = false
    @Published var totalHeight: CGFloat = 0
    @Published var scrollOffset: CGFloat = 0
    
    // MARK: - Private Properties
    
    private var allItems: [Item] = []
    fileprivate var itemHeights: [Item.ID: CGFloat] = [:]
    private var visibleRange: Range<Int> = 0..<0
    private let configuration: VirtualListConfiguration
    private var lastUpdateTime: Date = Date()
    private let throttleInterval: TimeInterval = 0.016 // 60fps
    
    // Performance metrics
    private var renderCount = 0
    private var avgRenderTime: Double = 0
    
    init(configuration: VirtualListConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Data Management
    
    func updateItems(_ newItems: [Item], viewportHeight: CGFloat = 800) {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let renderTime = CFAbsoluteTimeGetCurrent() - startTime
            updateRenderMetrics(renderTime)
        }
        
        let oldItemCount = allItems.count
        let wasInitialLoad = allItems.isEmpty
        allItems = newItems
        recalculateTotalHeight()
        
        if !newItems.isEmpty {
            let effectiveHeight = viewportHeight > 0 ? viewportHeight : 800
            
            if wasInitialLoad {
                // Initial load - show first 50 items
                visibleRange = calculateInitialVisibleRange(viewportHeight: effectiveHeight)
                print("🔄 VirtualList: Initial load \(newItems.count) items, showing range: \(visibleRange)")
            } else if newItems.count > oldItemCount {
                // Data appended - expand range to include new items
                let newEndIndex = min(newItems.count, visibleRange.upperBound + 25) // Add 25 more items
                visibleRange = visibleRange.lowerBound..<newEndIndex
                print("🔄 VirtualList: Appended data (\(oldItemCount) -> \(newItems.count)), expanded range to: \(visibleRange)")
            } else {
                // Data replaced - recalculate initial range
                visibleRange = calculateInitialVisibleRange(viewportHeight: effectiveHeight)
                print("🔄 VirtualList: Data replaced, reset range to: \(visibleRange)")
            }
        }
        
        updateVisibleItems()
        
        print("📊 VirtualList: Updated \(newItems.count) items, visible: \(visibleItems.count), range: \(visibleRange)")
    }
    
    func appendItems(_ newItems: [Item]) {
        allItems.append(contentsOf: newItems)
        recalculateTotalHeight()
        updateVisibleItems()
    }
    
    func removeItems(where predicate: (Item) -> Bool) {
        allItems.removeAll(where: predicate)
        
        // Clean up height cache
        let remainingIds = Set(allItems.map { $0.id })
        itemHeights = itemHeights.filter { remainingIds.contains($0.key) }
        
        recalculateTotalHeight()
        updateVisibleItems()
    }
    
    func updateItemHeight(_ height: CGFloat, for itemId: Item.ID) {
        guard height > 0 else { return }
        
        let oldHeight = itemHeights[itemId] ?? configuration.estimatedItemHeight
        itemHeights[itemId] = height
        
        // Update total height
        let heightDifference = height - oldHeight
        totalHeight += heightDifference
        
        // Throttle visible items update
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) > throttleInterval {
            updateVisibleItems()
            lastUpdateTime = now
        }
    }
    
    // MARK: - Scroll Management
    
    func expandVisibleRange(direction: ScrollDirection, viewportHeight: CGFloat) {
        let currentCount = visibleRange.count
        let totalItems = allItems.count
        
        guard totalItems > currentCount else { return }
        
        let pageSize = 50  // Minimum items per load
        let newEndIndex: Int
        
        switch direction {
        case .down:
            // Expand downward - show more items
            newEndIndex = min(totalItems, visibleRange.upperBound + pageSize)
        case .up:
            // For now, just expand down (can add up expansion later if needed)
            newEndIndex = min(totalItems, visibleRange.upperBound + pageSize)
        }
        
        let newRange = visibleRange.lowerBound..<newEndIndex
        
        if newRange != visibleRange {
            print("🔄 Expanding visible range: \(visibleRange) -> \(newRange) (\(direction))")
            visibleRange = newRange
            updateVisibleItems()
        }
    }
    
    enum ScrollDirection {
        case up, down
    }
    
    // MARK: - Private Methods
    
    private func calculateInitialVisibleRange(viewportHeight: CGFloat) -> Range<Int> {
        guard !allItems.isEmpty else { return 0..<0 }
        
        // Always start with at least 50 items or all items if less than 50
        let pageSize = 50
        let endIndex = min(allItems.count, pageSize)
        
        print("🎯 calculateInitialVisibleRange: viewport=\(viewportHeight), total=\(allItems.count), range=0..<\(endIndex)")
        
        return 0..<endIndex
    }
    
    private func updateVisibleItems() {
        guard !allItems.isEmpty else {
            visibleItems = []
            return
        }
        
        let newVisibleItems = Array(allItems[visibleRange])
        
        // Only update if actually changed to avoid unnecessary SwiftUI updates
        if newVisibleItems != visibleItems {
            visibleItems = newVisibleItems
        }
    }
    
    private func recalculateTotalHeight() {
        totalHeight = allItems.reduce(0) { total, item in
            return total + (itemHeights[item.id] ?? configuration.estimatedItemHeight)
        }
    }
    
    private func updateRenderMetrics(_ renderTime: Double) {
        renderCount += 1
        avgRenderTime = (avgRenderTime * Double(renderCount - 1) + renderTime) / Double(renderCount)
        
        // Log performance every 100 renders
        if renderCount % 100 == 0 {
            print("🚀 VirtualList Performance: \(renderCount) renders, avg \(String(format: "%.2f", avgRenderTime * 1000))ms")
        }
    }
    
    // MARK: - Utility Methods
    
    func refreshVisibleRange(viewportHeight: CGFloat) {
        guard !allItems.isEmpty else { 
            visibleItems = []
            return 
        }
        
        // Force refresh by expanding the range if possible
        let totalItems = allItems.count
        if visibleRange.upperBound < totalItems {
            let newEndIndex = min(totalItems, visibleRange.upperBound + 25)
            visibleRange = visibleRange.lowerBound..<newEndIndex
        }
        
        updateVisibleItems()
        
        print("🔄 VirtualList: Forced refresh - range: \(visibleRange), visible: \(visibleItems.count)")
    }
    
    func getOffsetForItem(at index: Int) -> CGFloat {
        guard index >= 0 && index < allItems.count else { return 0 }
        
        var offset: CGFloat = 0
        for i in 0..<index {
            let item = allItems[i]
            offset += itemHeights[item.id] ?? configuration.estimatedItemHeight
        }
        
        return offset
    }
    
    func scrollToItem(at index: Int, completion: @escaping (CGFloat) -> Void) {
        guard index >= 0 && index < allItems.count else { return }
        
        let targetOffset = getOffsetForItem(at: index)
        completion(targetOffset)
    }
    
    func getVisibleItemsInfo() -> (total: Int, visible: Int, range: Range<Int>) {
        return (total: allItems.count, visible: visibleItems.count, range: visibleRange)
    }
}

// MARK: - Virtual List View

struct VirtualListView<Item: VirtualListItem, Content: View>: View {
    
    @StateObject private var stateManager: VirtualListStateManager<Item>
    @State private var scrollViewHeight: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    
    let items: [Item]
    let content: (Item) -> Content
    let onItemAppear: ((Int, Item) -> Void)?
    let onScrollToBottom: (() -> Void)?
    
    private let configuration: VirtualListConfiguration
    
    init(
        items: [Item],
        configuration: VirtualListConfiguration = .default,
        onItemAppear: ((Int, Item) -> Void)? = nil,
        onScrollToBottom: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.content = content
        self.onItemAppear = onItemAppear
        self.onScrollToBottom = onScrollToBottom
        self.configuration = configuration
        self._stateManager = StateObject(wrappedValue: VirtualListStateManager<Item>(configuration: configuration))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        
                        // Scroll expansion sentinel (top)
                        if stateManager.visibleItems.count >= 30 {
                            LopanColors.clear
                                .frame(height: 1)
                                .onAppear {
                                    print("🔍 Top expansion sentinel appeared - expanding up")
                                    stateManager.expandVisibleRange(direction: .up, viewportHeight: geometry.size.height)
                                }
                                .id("top-sentinel")
                        }
                        
                        // Visible items with scroll detection
                        ForEach(Array(stateManager.visibleItems.enumerated()), id: \.element.id) { index, item in
                            content(item)
                                .background(
                                    GeometryReader { itemGeometry in
                                        LopanColors.clear
                                            .onAppear {
                                                let actualHeight = itemGeometry.size.height
                                                stateManager.updateItemHeight(actualHeight, for: item.id)
                                                
                                                // Trigger item appear callback
                                                if let actualIndex = items.firstIndex(where: { $0.id == item.id }) {
                                                    onItemAppear?(actualIndex, item)
                                                }
                                                
                                                // Check if we're near the end and need to expand
                                                let visibleInfo = stateManager.getVisibleItemsInfo()
                                                if index >= visibleInfo.visible - 10 && visibleInfo.visible < visibleInfo.total {
                                                    print("📝 Item \(index) appeared, expanding range (visible: \(visibleInfo.visible), total: \(visibleInfo.total))")
                                                    stateManager.expandVisibleRange(direction: .down, viewportHeight: geometry.size.height)
                                                }
                                            }
                                            .onChange(of: itemGeometry.size.height) { newHeight in
                                                stateManager.updateItemHeight(newHeight, for: item.id)
                                            }
                                    }
                                )
                                .id(item.id)
                        }
                        
                        // Bottom expansion sentinel
                        LopanColors.clear
                            .frame(height: 1)
                            .onAppear {
                                print("🔍 Bottom expansion sentinel appeared - expanding down")
                                stateManager.expandVisibleRange(direction: .down, viewportHeight: geometry.size.height)
                            }
                            .id("bottom-expansion-sentinel")
                        
                        // Load more trigger for pagination
                        if !items.isEmpty {
                            LopanColors.clear
                                .frame(height: 50)
                                .onAppear {
                                    let visibleInfo = stateManager.getVisibleItemsInfo()
                                    print("🖼 Load more trigger appeared (visible: \(visibleInfo.visible) of \(visibleInfo.total))")
                                    if visibleInfo.visible >= visibleInfo.total - 5 {
                                        onScrollToBottom?()
                                    }
                                }
                                .id("load-more-trigger")
                        }
                    }
                }
                .onAppear {
                    scrollViewHeight = geometry.size.height
                    stateManager.updateItems(items, viewportHeight: geometry.size.height)
                    print("🚀 VirtualListView initialized with \(items.count) items")
                }
                .onChange(of: items) { newItems in
                    stateManager.updateItems(newItems, viewportHeight: scrollViewHeight)
                }
                .onChange(of: geometry.size.height) { newHeight in
                    scrollViewHeight = newHeight
                    print("📏 Viewport height changed: \(newHeight)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldTriggerLoadMore() -> Bool {
        let visibleInfo = stateManager.getVisibleItemsInfo()
        return visibleInfo.visible >= items.count - 10 && visibleInfo.visible < visibleInfo.total
    }
}



// MARK: - CustomerOutOfStock Extension

extension CustomerOutOfStock: VirtualListItem {
    var estimatedHeight: CGFloat { 120 }
    var actualHeight: CGFloat? {
        get { return nil } // This would be stored in a separate dictionary in practice
        set { /* Store in external dictionary */ }
    }
}

// MARK: - Virtual List Modifiers

extension VirtualListView {
    func onItemAppear(_ callback: @escaping (Int, Item) -> Void) -> VirtualListView {
        return VirtualListView(
            items: items,
            configuration: configuration,
            onItemAppear: callback,
            onScrollToBottom: onScrollToBottom,
            content: content
        )
    }
    
    func onScrollToBottom(_ callback: @escaping () -> Void) -> VirtualListView {
        return VirtualListView(
            items: items,
            configuration: configuration,
            onItemAppear: onItemAppear,
            onScrollToBottom: callback,
            content: content
        )
    }
}

// MARK: - Performance Optimized Card View

struct VirtualListItemCard<Item: VirtualListItem, Content: View>: View {
    let item: Item
    let content: Content
    
    @State private var isVisible = false
    
    init(item: Item, @ViewBuilder content: () -> Content) {
        self.item = item
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isVisible {
                content
                    .onAppear {
                        isVisible = true
                    }
                    .onDisappear {
                        isVisible = false
                    }
            } else {
                // Placeholder with estimated height
                Rectangle()
                    .fill(LopanColors.clear)
                    .frame(height: item.estimatedHeight)
                    .onAppear {
                        // Delay to avoid immediate loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isVisible = true
                        }
                    }
            }
        }
    }
}

#Preview {
    struct MockItem: VirtualListItem {
        let id = UUID()
        let title: String
        let subtitle: String
        let estimatedHeight: CGFloat = 80
        var actualHeight: CGFloat?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: MockItem, rhs: MockItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    let mockItems = (1...10000).map { index in
        MockItem(
            title: "Item \(index)",
            subtitle: "This is a subtitle for item \(index)"
        )
    }
    
    return VirtualListView(items: mockItems) { item in
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
            Text(item.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LopanColors.background)
        .cornerRadius(8)
        .padding(.horizontal)
    }
    .onScrollToBottom {
        print("Reached bottom - load more data")
    }
}