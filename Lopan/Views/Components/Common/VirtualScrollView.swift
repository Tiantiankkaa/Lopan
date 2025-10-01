//
//  VirtualScrollView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/28.
//  Virtual scrolling implementation for large datasets with progressive loading
//

import SwiftUI

// MARK: - Virtual Scroll View for Large Datasets

struct VirtualScrollView<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let loadMoreAction: (() -> Void)?
    let isLoading: Bool
    let hasMoreData: Bool
    let viewBuilder: (Item) -> ItemView

    @State private var scrollPosition: CGFloat = 0
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var containerHeight: CGFloat = 0

    // Virtual scrolling configuration
    private let bufferSize: Int = 10 // Items to render outside visible area
    private let loadMoreThreshold: CGFloat = 500 // Distance from bottom to trigger load more

    init(
        items: [Item],
        itemHeight: CGFloat,
        isLoading: Bool = false,
        hasMoreData: Bool = true,
        loadMoreAction: (() -> Void)? = nil,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.isLoading = isLoading
        self.hasMoreData = hasMoreData
        self.loadMoreAction = loadMoreAction
        self.viewBuilder = itemView
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Virtual content - only render visible items plus buffer
                        ForEach(visibleItems, id: \.id) { item in
                            viewBuilder(item)
                                .frame(height: itemHeight)
                                .id(item.id)
                        }

                        // Load more indicator
                        if isLoading {
                            ProgressiveLoadingIndicator()
                                .frame(height: 60)
                        }

                        // Invisible trigger for load more
                        if hasMoreData && !isLoading {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    loadMoreAction?()
                                }
                        }
                    }
                    .background(
                        // Track scroll position
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: scrollGeometry.frame(in: .named("scrollView")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollPosition = -value
                    updateVisibleRange(containerHeight: geometry.size.height)
                }
                .onAppear {
                    containerHeight = geometry.size.height
                    updateVisibleRange(containerHeight: geometry.size.height)
                }
                .onChange(of: items.count) { _, _ in
                    updateVisibleRange(containerHeight: containerHeight)
                }
            }
        }
    }

    private var visibleItems: [Item] {
        let startIndex = max(0, visibleRange.lowerBound - bufferSize)
        let endIndex = min(items.count, visibleRange.upperBound + bufferSize)

        guard startIndex < endIndex && endIndex <= items.count else {
            return []
        }

        return Array(items[startIndex..<endIndex])
    }

    private func updateVisibleRange(containerHeight: CGFloat) {
        let totalHeight = CGFloat(items.count) * itemHeight

        guard totalHeight > 0 && itemHeight > 0 else {
            visibleRange = 0..<0
            return
        }

        let visibleTop = scrollPosition
        let visibleBottom = scrollPosition + containerHeight

        let startIndex = max(0, Int(visibleTop / itemHeight))
        let endIndex = min(items.count, Int(ceil(visibleBottom / itemHeight)) + 1)

        visibleRange = startIndex..<endIndex
    }
}

// MARK: - Progressive Loading Indicator

struct ProgressiveLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0.2),
                    value: isAnimating
                )

            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0.4),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Scroll Position Tracking

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Smart Skeleton Loading for Virtual Scroll

struct SmartSkeletonList: View {
    let itemCount: Int
    let itemHeight: CGFloat

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<itemCount, id: \.self) { index in
                SkeletonItemView()
                    .frame(height: itemHeight)
                    .opacity(calculateOpacity(for: index))
            }
        }
    }

    private func calculateOpacity(for index: Int) -> Double {
        // Fade out skeleton items further down the list
        let fadeStart = max(6, itemCount / 3)
        if index < fadeStart {
            return 1.0
        } else {
            let fadeRange = Double(itemCount - fadeStart)
            let position = Double(index - fadeStart)
            return max(0.3, 1.0 - (position / fadeRange) * 0.7)
        }
    }
}

struct SkeletonItemView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(
            Animation.easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}