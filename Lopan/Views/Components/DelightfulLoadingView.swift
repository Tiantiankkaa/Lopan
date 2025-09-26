//
//  DelightfulLoadingView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct DelightfulLoadingView: View {
    let message: String
    let isLoadingMore: Bool
    
    @State private var animationOffset: CGFloat = -20
    @State private var animationOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var wavePhase: Double = 0
    
    init(message: String = "正在加载...", isLoadingMore: Bool = false) {
        self.message = message
        self.isLoadingMore = isLoadingMore
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoadingMore {
                loadMoreIndicator
            } else {
                mainLoadingIndicator
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isLoadingMore ? 60 : 200)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Main Loading Indicator
    
    private var mainLoadingIndicator: some View {
        VStack(spacing: 24) {
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [LopanColors.primary.opacity(0.3), LopanColors.primary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                
                // Inner rotating elements
                ForEach(0..<8) { index in
                    Circle()
                        .fill(LopanColors.primary.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .offset(y: -30)
                        .rotationEffect(.degrees(Double(index) * 45 + rotationAngle))
                        .scaleEffect(1.0 + 0.3 * sin(wavePhase + Double(index) * 0.5))
                }
                
                // Center logo or icon
                Image(systemName: "cube.box")
                    .font(.title)
                    .foregroundColor(LopanColors.info)
                    .scaleEffect(pulseScale)
            }
            
            // Loading text with typing effect
            loadingText
        }
    }
    
    // MARK: - Load More Indicator
    
    private var loadMoreIndicator: some View {
        HStack(spacing: 12) {
            // Compact spinner
            ZStack {
                Circle()
                    .stroke(LopanColors.primary.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(LopanColors.primary, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(rotationAngle))
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(animationOpacity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Loading Text
    
    private var loadingText: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(LopanColors.primary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.0 + 0.5 * sin(wavePhase + Double(index) * 0.5))
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: wavePhase
                        )
                }
            }
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        // Entrance animation
        withAnimation(.easeOut(duration: 0.5)) {
            animationOffset = 0
            animationOpacity = 1.0
        }
        
        // Continuous animations
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            wavePhase = .pi * 2
        }
    }
}

// MARK: - Skeleton Loading View

struct SimpleSkeletonLoadingView: View {
    let itemCount: Int
    
    @State private var animationPhase: CGFloat = 0
    
    init(itemCount: Int = 5) {
        self.itemCount = itemCount
    }
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<itemCount, id: \.self) { index in
                skeletonCard
                    .opacity(1.0 - CGFloat(index) * 0.1)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            animationPhase = 1.0
        }
    }
    
    private var skeletonCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar skeleton
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                    
                    // Subtitle skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(height: 12)
                        .frame(maxWidth: 200)
                }
                
                Spacer()
                
                // Status skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(shimmerGradient)
                    .frame(width: 60, height: 24)
            }
            
            Divider()
                .opacity(0.3)
            
            HStack {
                // Detail skeletons
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                LopanColors.backgroundTertiary,
                LopanColors.secondary,
                LopanColors.backgroundTertiary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Simple Pull to Refresh Indicator

struct SimplePullToRefreshIndicator: View {
    let pullProgress: CGFloat
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(LopanColors.secondary, lineWidth: 2)
                    .frame(width: 30, height: 30)
                
                Circle()
                    .trim(from: 0, to: pullProgress)
                    .stroke(LopanColors.primary, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                
                if pullProgress >= 1.0 {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(LopanColors.info)
                        .rotationEffect(.degrees(rotationAngle))
                }
            }
            
            Text(pullProgress >= 1.0 ? "释放刷新" : "下拉刷新")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .opacity(pullProgress > 0.1 ? 1.0 : 0.0)
        .scaleEffect(pullProgress > 0.1 ? 1.0 : 0.8)
        .animation(.easeInOut(duration: 0.2), value: pullProgress)
        .onChange(of: pullProgress) { _, progress in
            if progress >= 1.0 {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            } else {
                rotationAngle = 0
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        DelightfulLoadingView()
            .frame(height: 200)
        
        DelightfulLoadingView(message: "加载更多...", isLoadingMore: true)
        
        SimpleSkeletonLoadingView(itemCount: 3)
    }
    .background(LopanColors.backgroundSecondary)
}