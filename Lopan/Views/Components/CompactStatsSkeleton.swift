//
//  CompactStatsSkeleton.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Skeleton loading view for compact status indicators
//

import SwiftUI

/// A skeleton loading view that matches the CompactStatIndicator layout during data loading.
public struct CompactStatsSkeleton: View {

    // MARK: - Environment & Metrics

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 8

    // MARK: - Animation State

    @State private var isAnimating = false

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                skeletonIndicator(isPrimary: index == 0)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Skeleton Indicator

    private func skeletonIndicator(isPrimary: Bool = false) -> some View {
        VStack(spacing: 2) {
            // Icon skeleton at top
            Circle()
                .fill(skeletonColor)
                .frame(width: 12, height: 12)

            // Value skeleton in middle
            RoundedRectangle(cornerRadius: 4)
                .fill(skeletonColor)
                .frame(width: 32, height: 18)

            // Title skeleton at bottom
            RoundedRectangle(cornerRadius: 3)
                .fill(skeletonColor)
                .frame(width: 24, height: 10)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, verticalPadding)
        .frame(minHeight: 60)
        .frame(maxWidth: .infinity)
        .background(skeletonBackground)
    }

    // MARK: - Computed Properties

    private var skeletonColor: Color {
        LopanColors.textSecondary.opacity(isAnimating ? 0.15 : 0.08)
    }

    private var skeletonBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LopanColors.backgroundSecondary.opacity(colorScheme == .dark ? 0.3 : 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LopanColors.border.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// MARK: - Preview Provider

#Preview("CompactStatsSkeleton") {
    VStack(spacing: 20) {
        CompactStatsSkeleton()
            .frame(height: 56)
            .padding(.horizontal, 16)

        // Comparison with actual indicators
        HStack(spacing: 8) {
            CompactStatIndicator(
                title: "总计",
                value: "142",
                icon: "circle.fill",
                color: LopanColors.primary,
                isPrimary: true
            )
            CompactStatIndicator(
                title: "待处理",
                value: "28",
                icon: "clock.fill",
                color: LopanColors.warning
            )
            CompactStatIndicator(
                title: "已完成",
                value: "96",
                icon: "checkmark.circle.fill",
                color: LopanColors.success
            )
            CompactStatIndicator(
                title: "已退货",
                value: "18",
                icon: "arrow.uturn.left",
                color: LopanColors.error
            )
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}