//
//  ShimmerSkeletonCard.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  iOS 26 Liquid Glass shimmer skeleton for loading states
//

import SwiftUI

// MARK: - Shimmer Skeleton Card

/// Beautiful loading skeleton matching OutOfStockCardView layout
/// Features iOS 26 Liquid Glass shimmer animation
struct ShimmerSkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            // Header row (customer name + status badge)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                    // Customer name
                    RoundedRectangle(cornerRadius: 6)
                        .fill(shimmerGradient)
                        .frame(width: 140, height: 20)

                    // Region subtitle
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 80, height: 14)
                }

                Spacer()

                // Status badge placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(shimmerGradient)
                    .frame(width: 70, height: 24)
            }

            // OOS duration text
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 120, height: 12)

            Divider()
                .opacity(0.3)

            // Top critical product
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 180, height: 14)

            // Progress bar section
            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                // Units + percentage labels
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 90, height: 12)

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 30, height: 12)
                }

                // Progress bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 8)
            }

            // Last update text
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 110, height: 12)
        }
        .padding(LopanSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            withAnimation(shimmerAnimation) {
                isAnimating = true
            }
        }
    }

    // MARK: - Shimmer Gradient

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(uiColor: .systemGray5),
                Color(uiColor: .systemGray6),
                Color(uiColor: .systemGray5)
            ]),
            startPoint: isAnimating ? .trailing : .leading,
            endPoint: isAnimating ? .bottomTrailing : .bottomLeading
        )
    }

    // MARK: - iOS 26 Smooth Animation

    @available(iOS 26.0, *)
    private var smoothShimmerAnimation: Animation {
        .smooth(duration: 1.5).repeatForever(autoreverses: false)
    }

    private var shimmerAnimation: Animation {
        if #available(iOS 26.0, *) {
            return smoothShimmerAnimation
        } else {
            return .easeInOut(duration: 1.5).repeatForever(autoreverses: false)
        }
    }
}

// MARK: - Shimmer Skeleton List

/// List of shimmer skeleton cards for loading states
struct ShimmerSkeletonList: View {
    let count: Int

    init(count: Int = 6) {
        self.count = count
    }

    var body: some View {
        LazyVStack(spacing: LopanSpacing.md) {
            ForEach(0..<count, id: \.self) { index in
                ShimmerSkeletonCard()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(
                        .easeOut(duration: 0.3).delay(Double(index) * 0.05),
                        value: index
                    )
            }
        }
        .padding(.horizontal, LopanSpacing.md)
    }
}

// MARK: - Preview

#Preview("Single Skeleton Card") {
    ShimmerSkeletonCard()
        .padding()
}

#Preview("Skeleton List") {
    ScrollView {
        ShimmerSkeletonList(count: 5)
            .padding(.vertical)
    }
}

#Preview("Dark Mode") {
    ScrollView {
        ShimmerSkeletonList(count: 3)
            .padding(.vertical)
    }
    .preferredColorScheme(.dark)
}
