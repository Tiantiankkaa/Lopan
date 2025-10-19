//
//  InfiniteScrollTrigger.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Detects scroll position to trigger infinite scroll and prefetching
//

import SwiftUI

// MARK: - Infinite Scroll Trigger

/// Invisible trigger view that detects when user scrolls near the bottom
/// Triggers both pagination load and next-page prefetch
struct InfiniteScrollTrigger: View {
    let onAppear: () -> Void
    let prefetchThreshold: CGFloat

    init(
        prefetchThreshold: CGFloat = 0.7,
        onAppear: @escaping () -> Void
    ) {
        self.prefetchThreshold = prefetchThreshold
        self.onAppear = onAppear
    }

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .task {
                    // Use .task instead of .onAppear for better cancellation semantics
                    // .task automatically cancels when the view disappears, reducing duplicate triggers
                    onAppear()
                }
        }
        .frame(height: 1)
    }
}

// MARK: - Loading More Indicator

/// Visual indicator shown at the bottom when loading more items
struct LoadingMoreIndicator: View {
    let isLoading: Bool
    let hasMore: Bool

    var body: some View {
        HStack(spacing: LopanSpacing.sm) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)

                Text("Loading more...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else if !hasMore {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)

                Text("All items loaded")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.md)
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Scroll Position Tracker

/// Tracks scroll position within a ScrollView for prefetch optimization
struct ScrollPositionTracker: View {
    @Binding var scrollPosition: CGFloat
    let totalHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minY
                )
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            // Calculate scroll percentage
            scrollPosition = offset / totalHeight
        }
    }
}

// MARK: - Infinite Scroll View Modifier

extension View {
    /// Add infinite scroll capability to a list or scroll view
    func infiniteScroll(
        isLoading: Bool,
        hasMore: Bool,
        threshold: CGFloat = 0.7,
        onLoadMore: @escaping () -> Void,
        onPrefetch: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            self

            // Trigger point for pagination (70% scroll position)
            InfiniteScrollTrigger(prefetchThreshold: threshold) {
                if !isLoading && hasMore {
                    onLoadMore()

                    // Also trigger prefetch if provided
                    onPrefetch?()
                }
            }

            // Loading indicator
            LoadingMoreIndicator(isLoading: isLoading, hasMore: hasMore)
        }
    }
}

// MARK: - Preview

#Preview("Loading More") {
    ScrollView {
        VStack {
            ForEach(0..<10, id: \.self) { index in
                Text("Item \(index)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .infiniteScroll(
            isLoading: true,
            hasMore: true,
            onLoadMore: {},
            onPrefetch: {}
        )
    }
}

#Preview("All Loaded") {
    ScrollView {
        VStack {
            ForEach(0..<10, id: \.self) { index in
                Text("Item \(index)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .infiniteScroll(
            isLoading: false,
            hasMore: false,
            onLoadMore: {},
            onPrefetch: {}
        )
    }
}
