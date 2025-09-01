//
//  SkeletonLoadingView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//  Enhanced skeleton loading states for better user experience
//

import SwiftUI

// MARK: - Simple Skeleton Shape (to avoid conflicts with DelightfulLoadingStates)

struct SimpleSkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray6),
                        Color(.systemGray5),
                        Color(.systemGray6)
                    ],
                    startPoint: UnitPoint(x: -0.5, y: 0.5),
                    endPoint: UnitPoint(x: 1.5, y: 0.5)
                )
            )
            .frame(width: width, height: height)
            .offset(x: isAnimating ? 200 : -200)
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("加载中")
            .accessibilityValue("内容正在加载，请稍候")
    }
    
    static let text = SimpleSkeletonShape(width: nil, height: 16, cornerRadius: 8)
    static let title = SimpleSkeletonShape(width: nil, height: 24, cornerRadius: 12)
    static let subtitle = SimpleSkeletonShape(width: 120, height: 14, cornerRadius: 7)
    static let card = SimpleSkeletonShape(width: nil, height: 120, cornerRadius: 12)
    static let avatar = SimpleSkeletonShape(width: 48, height: 48, cornerRadius: 24)
    static let button = SimpleSkeletonShape(width: 100, height: 44, cornerRadius: 8)
}

// MARK: - Skeleton Card for Out-of-Stock Items

struct OutOfStockSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Status indicator skeleton
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 12, height: 12)
                
                // Title skeleton
                SimpleSkeletonShape.title
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Menu button skeleton
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
            }
            
            // Customer info skeleton
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SimpleSkeletonShape.subtitle
            }
            
            // Product info skeleton
            HStack(spacing: 8) {
                Image(systemName: "cube.box")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SimpleSkeletonShape.subtitle
            }
            
            Divider()
            
            // Action buttons skeleton
            HStack(spacing: 12) {
                SimpleSkeletonShape.button
                SimpleSkeletonShape.button
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在加载缺货记录")
    }
}

// MARK: - Skeleton List View

struct SkeletonListView: View {
    let itemCount: Int
    
    init(itemCount: Int = 5) {
        self.itemCount = itemCount
    }
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                OutOfStockSkeletonCard()
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在加载列表数据")
        .accessibilityValue("共\(itemCount)项内容正在加载")
    }
}

// MARK: - Search Bar Skeleton

struct SearchBarSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Search field skeleton
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                SimpleSkeletonShape(width: nil, height: 20, cornerRadius: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter button skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .frame(width: 44, height: 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("搜索功能正在加载")
    }
}

// MARK: - Statistics Cards Skeleton

struct StatisticsCardsSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(spacing: 8) {
                    SimpleSkeletonShape(width: 40, height: 32, cornerRadius: 16)
                    SimpleSkeletonShape(width: 60, height: 12, cornerRadius: 6)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("统计数据正在加载")
    }
}

// MARK: - Loading states now handled by SmartLoadingController

// Export enhanced skeleton components
typealias EnhancedDateSwitchingSkeleton = EnhancedSkeletonList
typealias EnhancedStatsSkeleton = EnhancedSkeletonStatsCards

// MARK: - Preview Helpers

#Preview("Skeleton Components") {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                Text("搜索栏骨架")
                    .font(.headline)
                SearchBarSkeleton()
                
                Text("统计卡片骨架")
                    .font(.headline)
                StatisticsCardsSkeleton()
                
                Text("列表骨架")
                    .font(.headline)
                SkeletonListView(itemCount: 3)
            }
        }
        .padding()
    }
}