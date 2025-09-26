//
//  EnhancedSkeletonAnimation.swift
//  Lopan
//
//  Created by Claude Code on 2025/1/20.
//  Enhanced skeleton loading with border animations and shimmer effects
//

import SwiftUI

// MARK: - Enhanced Skeleton Card for Date Switching

struct EnhancedOutOfStockSkeletonCard: View {
    @State private var strokeProgress: CGFloat = 0.0
    @State private var breathingScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -300
    @State private var hasAppeared = false
    
    let itemIndex: Int
    
    init(itemIndex: Int = 0) {
        self.itemIndex = itemIndex
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Main content skeleton
            VStack(alignment: .leading, spacing: 12) {
                // Header: Customer name and status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Customer name skeleton
                        skeletonRectangle(width: 120, height: 18)
                            .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1), value: strokeProgress)
                        
                        // Customer address skeleton
                        skeletonRectangle(width: 180, height: 12)
                            .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1 + 0.2), value: strokeProgress)
                    }
                    
                    Spacer()
                    
                    // Status badge skeleton
                    skeletonRectangle(width: 60, height: 24)
                        .cornerRadius(12)
                        .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1 + 0.1), value: strokeProgress)
                }
                
                // Product information skeleton
                HStack(spacing: 12) {
                    // Product icon placeholder
                    Circle()
                        .fill(LopanColors.backgroundTertiary)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(LopanColors.primary.opacity(0.3), lineWidth: 1)
                                .scaleEffect(breathingScale)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Product name skeleton
                        skeletonRectangle(width: 100, height: 16)
                            .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1 + 0.3), value: strokeProgress)
                        
                        // Quantity skeleton
                        skeletonRectangle(width: 60, height: 12)
                            .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1 + 0.4), value: strokeProgress)
                    }
                    
                    Spacer()
                    
                    // Date skeleton
                    VStack(alignment: .trailing, spacing: 2) {
                        skeletonRectangle(width: 50, height: 12)
                            .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1 + 0.5), value: strokeProgress)
                        
                        skeletonRectangle(width: 40, height: 10)
                            .animation(.easeInOut(duration: 1.0).delay(Double(itemIndex) * 0.1 + 0.6), value: strokeProgress)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .overlay(
                    // Shimmer overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LopanColors.clear,
                                    LopanColors.textPrimary.opacity(0.4),
                                    LopanColors.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .clipped()
                )
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            // Border animation
            RoundedRectangle(cornerRadius: 16)
                .trim(from: 0.0, to: strokeProgress)
                .stroke(
                    LinearGradient(
                        colors: [LopanColors.primary.opacity(0.3), LopanColors.primary.opacity(0.6), LopanColors.primary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .scaleEffect(breathingScale)
        )
        .scaleEffect(breathingScale)
        .onAppear {
            // Only animate if hasn't appeared yet to prevent re-triggering
            guard !hasAppeared else { return }
            hasAppeared = true
            
            // Staggered appearance animation
            let delay = Double(itemIndex) * 0.05
            
            withAnimation(.easeInOut(duration: 0.8).delay(delay)) {
                strokeProgress = 1.0
            }
            
            // Breathing animation
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                    .delay(delay + 0.5)
            ) {
                breathingScale = 1.02
            }
            
            // Shimmer animation
            withAnimation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                    .delay(delay + 1.0)
            ) {
                shimmerOffset = 400
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在加载缺货记录 \(itemIndex + 1)")
    }
    
    private func skeletonRectangle(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(
                LinearGradient(
                    colors: [
                        LopanColors.backgroundTertiary,
                        LopanColors.backgroundTertiary,
                        LopanColors.backgroundTertiary
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
    }
}

// MARK: - Enhanced Skeleton List for Date Switching

struct EnhancedSkeletonList: View {
    let itemCount: Int
    @State private var isVisible = false
    
    init(itemCount: Int = 6) {
        self.itemCount = max(1, min(itemCount, 8)) // Clamp between 1-8
    }
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { index in
                EnhancedOutOfStockSkeletonCard(itemIndex: index)
                    .opacity(isVisible ? 1.0 : 0.0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: isVisible)
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在加载列表数据")
        .accessibilityValue("共\(itemCount)项内容正在加载")
    }
}

// MARK: - Skeleton Statistics Cards for Date Switching

struct EnhancedSkeletonStatsCards: View {
    @State private var animationPhase: CGFloat = 0.0
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                skeletonStatCard(index: index)
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
            
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animationPhase = 1.0
            }
        }
    }
    
    private func skeletonStatCard(index: Int) -> some View {
        VStack(spacing: 8) {
            // Icon row with spacer (matching real QuickStatCard layout)
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LopanColors.backgroundTertiary)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LopanColors.primary.opacity(0.3), lineWidth: 1)
                            .scaleEffect(1.0 + animationPhase * 0.05)
                    )
                
                Spacer()
                
                // Trend indicator skeleton (optional placeholder)
                Circle()
                    .fill(LopanColors.backgroundTertiary)
                    .frame(width: 10, height: 10)
            }
            
            // Value and title section
            VStack(spacing: 2) {
                // Value skeleton (larger to match bold text)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [LopanColors.backgroundTertiary, LopanColors.backgroundTertiary, LopanColors.backgroundTertiary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 48, height: 24)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [LopanColors.clear, LopanColors.textPrimary.opacity(0.3), LopanColors.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .clipped()
                    )
                
                // Title skeleton (wider to match real text)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LopanColors.backgroundTertiary)
                    .frame(width: 50, height: 10)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity) // Expand to fill available width like real cards
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LopanColors.primary.opacity(0.2), lineWidth: 1)
                .scaleEffect(1.0 + animationPhase * 0.02)
        )
        .scaleEffect(1.0 - animationPhase * 0.01)
        .animation(.easeInOut(duration: 1.0).delay(Double(index) * 0.1), value: animationPhase)
    }
}

// MARK: - Preview

#Preview("Enhanced Skeleton Animations") {
    ScrollView {
        VStack(spacing: 30) {
            Group {
                Text("增强统计卡片骨架")
                    .font(.headline)
                EnhancedSkeletonStatsCards()
                
                Text("增强列表骨架")
                    .font(.headline)
                EnhancedSkeletonList(itemCount: 3)
            }
        }
        .padding()
    }
    .background(LopanColors.background)
}