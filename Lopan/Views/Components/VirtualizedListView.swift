//
//  VirtualizedListView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct VirtualizedListView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let content: (Item, Int) -> Content
    let onScrollToBottom: (() -> Void)?
    let onItemAppear: ((Item, Int) -> Void)?
    let onItemDisappear: ((Item, Int) -> Void)?
    
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var containerHeight: CGFloat = 0
    
    private let bufferSize: Int = 5 // Extra items to render above/below visible area
    private let bottomLoadThreshold: CGFloat = 200 // Trigger load more when this close to bottom
    
    init(
        items: [Item],
        itemHeight: CGFloat = 120,
        onScrollToBottom: (() -> Void)? = nil,
        onItemAppear: ((Item, Int) -> Void)? = nil,
        onItemDisappear: ((Item, Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item, Int) -> Content
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.content = content
        self.onScrollToBottom = onScrollToBottom
        self.onItemAppear = onItemAppear
        self.onItemDisappear = onItemDisappear
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Top spacer for items before visible range
                    if visibleRange.lowerBound > 0 {
                        Spacer()
                            .frame(height: CGFloat(visibleRange.lowerBound) * itemHeight)
                    }
                    
                    // Visible items
                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { localIndex, item in
                        let globalIndex = visibleRange.lowerBound + localIndex
                        
                        content(item, globalIndex)
                            .frame(height: itemHeight)
                            .onAppear {
                                onItemAppear?(item, globalIndex)
                            }
                            .onDisappear {
                                onItemDisappear?(item, globalIndex)
                            }
                    }
                    
                    // Bottom spacer for items after visible range
                    if visibleRange.upperBound < items.count {
                        Spacer()
                            .frame(height: CGFloat(items.count - visibleRange.upperBound) * itemHeight)
                    }
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear
                            .onAppear {
                                updateContentHeight(scrollGeometry.size.height)
                            }
                            .onChange(of: scrollGeometry.frame(in: .named("scroll")).minY) { _, offset in
                                updateScrollOffset(-offset)
                            }
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onAppear {
                containerHeight = geometry.size.height
                updateVisibleRange()
            }
            .onChange(of: scrollOffset) { _, _ in
                updateVisibleRange()
                checkForBottomLoad()
            }
            .onChange(of: items.count) { _, _ in
                updateVisibleRange()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var visibleItems: ArraySlice<Item> {
        guard visibleRange.lowerBound >= 0 && visibleRange.upperBound <= items.count else {
            return ArraySlice([])
        }
        return items[visibleRange]
    }
    
    private var totalContentHeight: CGFloat {
        CGFloat(items.count) * itemHeight
    }
    
    // MARK: - Helper Methods
    
    private func updateScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
    }
    
    private func updateContentHeight(_ height: CGFloat) {
        contentHeight = height
    }
    
    private func updateVisibleRange() {
        guard containerHeight > 0 && itemHeight > 0 else { return }
        
        // Calculate which items should be visible based on scroll position
        let startIndex = max(0, Int(scrollOffset / itemHeight) - bufferSize)
        let visibleItemCount = Int(containerHeight / itemHeight) + 1 + (bufferSize * 2)
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        let newRange = startIndex..<endIndex
        
        if newRange != visibleRange {
            visibleRange = newRange
        }
    }
    
    private func checkForBottomLoad() {
        let distanceFromBottom = totalContentHeight - scrollOffset - containerHeight
        
        if distanceFromBottom < bottomLoadThreshold {
            onScrollToBottom?()
        }
    }
}

// MARK: - Optimized Customer Out of Stock List

struct OptimizedOutOfStockList: View {
    @ObservedObject var viewModel: CustomerOutOfStockViewModel
    
    @State private var visibleItemIds: Set<String> = []
    @State private var itemHeights: [String: CGFloat] = [:]
    
    var body: some View {
        VirtualizedListView(
            items: viewModel.items,
            itemHeight: estimatedItemHeight,
            onScrollToBottom: {
                Task {
                    await viewModel.loadNextPage()
                }
            },
            onItemAppear: { item, index in
                handleItemAppear(item, at: index)
            },
            onItemDisappear: { item, index in
                handleItemDisappear(item, at: index)
            }
        ) { item, index in
            OptimizedOutOfStockCard(
                item: item,
                index: index,
                isSelected: viewModel.selectedItems.contains(item.id),
                isInSelectionMode: viewModel.isInSelectionMode,
                onTap: {
                    if viewModel.isInSelectionMode {
                        viewModel.toggleSelection(for: item)
                    } else {
                        // Navigate to detail
                    }
                },
                onLongPress: {
                    if !viewModel.isInSelectionMode {
                        viewModel.enterSelectionMode()
                        viewModel.toggleSelection(for: item)
                    }
                },
                onSwipeAction: { action in
                    handleSwipeAction(action, for: item)
                },
                onHeightCalculated: { height in
                    itemHeights[item.id] = height
                }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        }
    }
    
    // MARK: - Helper Methods
    
    private var estimatedItemHeight: CGFloat {
        let avgHeight = itemHeights.values.reduce(0, +) / max(1, CGFloat(itemHeights.count))
        return avgHeight > 0 ? avgHeight : 120 // Default height
    }
    
    private func handleItemAppear(_ item: CustomerOutOfStock, at index: Int) {
        visibleItemIds.insert(item.id)
        
        // Preload adjacent items if needed
        if index >= viewModel.items.count - 5 {
            Task {
                await viewModel.loadNextPage()
            }
        }
    }
    
    private func handleItemDisappear(_ item: CustomerOutOfStock, at index: Int) {
        visibleItemIds.remove(item.id)
    }
    
    private func handleSwipeAction(_ action: EnhancedOutOfStockCardView.SwipeAction, for item: CustomerOutOfStock) {
        switch action {
        case .delete:
            // Handle delete
            print("Delete item: \(item.id)")
        case .complete:
            // Handle mark as complete
            print("Complete item: \(item.id)")
        case .edit:
            // Handle edit
            print("Edit item: \(item.id)")
        }
    }
}

// MARK: - Optimized Card Component

struct OptimizedOutOfStockCard: View {
    let item: CustomerOutOfStock
    let index: Int
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSwipeAction: (EnhancedOutOfStockCardView.SwipeAction) -> Void
    let onHeightCalculated: (CGFloat) -> Void
    
    @State private var cardHeight: CGFloat = 0
    
    var body: some View {
        EnhancedOutOfStockCardView(
            item: item,
            isSelected: isSelected,
            isInSelectionMode: isInSelectionMode,
            onTap: onTap,
            onLongPress: onLongPress,
            onSwipeAction: onSwipeAction
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        let height = geometry.size.height
                        if height != cardHeight {
                            cardHeight = height
                            onHeightCalculated(height)
                        }
                    }
            }
        )
        .id(item.id) // Ensure view identity for reuse
    }
}

// MARK: - Performance Monitoring

struct ListPerformanceMonitor: View {
    @ObservedObject var viewModel: CustomerOutOfStockViewModel
    @State private var fps: Double = 60.0
    @State private var memoryUsage: Double = 0.0
    @State private var renderTime: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("性能监控")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack {
                performanceMetric("FPS", value: fps, unit: "", color: fps > 55 ? .green : fps > 45 ? .orange : .red)
                performanceMetric("内存", value: memoryUsage, unit: "MB", color: memoryUsage < 100 ? .green : .orange)
                performanceMetric("渲染", value: renderTime, unit: "ms", color: renderTime < 16 ? .green : .orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemBackground).opacity(0.8))
        )
        .onAppear {
            startPerformanceMonitoring()
        }
    }
    
    private func performanceMetric(_ title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    private func startPerformanceMonitoring() {
        // Simplified performance monitoring
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Simulate FPS calculation
            fps = Double.random(in: 55...60)
            
            // Simulate memory usage
            memoryUsage = Double.random(in: 80...120)
            
            // Simulate render time
            renderTime = Double.random(in: 12...18)
        }
    }
}

#Preview {
    OptimizedOutOfStockList(
        viewModel: CustomerOutOfStockViewModel(service: .placeholder())
    )
}