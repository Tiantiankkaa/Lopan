//
//  OutOfStockProgressBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Enhanced progress bar with gradient fills matching status colors
//

import SwiftUI

// MARK: - Out-of-Stock Progress Bar

/// Progress bar showing delivery fulfillment with gradient animations
struct OutOfStockProgressBar: View {
    let completed: Int
    let total: Int
    let status: OutOfStockStatus

    @State private var animatedProgress: CGFloat = 0

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            // Units and percentage labels
            HStack {
                Text("\(completed)/\(total) units")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(progressPercentage)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(status.color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .systemGray5))
                        .frame(height: 8)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(
                            width: geometry.size.width * animatedProgress,
                            height: 8
                        )
                        .animation(smoothAnimation, value: animatedProgress)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            // Animate progress on appear
            withAnimation(smoothAnimation.delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(smoothAnimation) {
                animatedProgress = newValue
            }
        }
    }

    // MARK: - Progress Gradient

    private var progressGradient: LinearGradient {
        let baseColor = status.color

        return LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.8),
                baseColor,
                baseColor.opacity(0.9)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - iOS 26 Smooth Animation

    @available(iOS 26.0, *)
    private var smoothIOS26Animation: Animation {
        .smooth(duration: 0.6)
    }

    private var smoothAnimation: Animation {
        if #available(iOS 26.0, *) {
            return smoothIOS26Animation
        } else {
            return .spring(response: 0.6, dampingFraction: 0.8)
        }
    }
}

// MARK: - Convenience Initializer

extension OutOfStockProgressBar {
    /// Create progress bar from CustomerOutOfStock item
    init(item: CustomerOutOfStock) {
        self.init(
            completed: item.deliveryQuantity,
            total: item.quantity,
            status: item.status
        )
    }
}

// MARK: - Preview

#Preview("Different Progress Levels") {
    VStack(spacing: 24) {
        // Pending - Low progress
        VStack(alignment: .leading) {
            Text("Pending (20%)")
                .font(.caption)
                .foregroundColor(.secondary)
            OutOfStockProgressBar(completed: 10, total: 50, status: .pending)
        }

        // Pending - Medium progress
        VStack(alignment: .leading) {
            Text("Pending (62%)")
                .font(.caption)
                .foregroundColor(.secondary)
            OutOfStockProgressBar(completed: 310, total: 500, status: .pending)
        }

        // Completed - Full
        VStack(alignment: .leading) {
            Text("Completed (100%)")
                .font(.caption)
                .foregroundColor(.secondary)
            OutOfStockProgressBar(completed: 12, total: 12, status: .completed)
        }

        // Refunded - Zero
        VStack(alignment: .leading) {
            Text("Refunded (0%)")
                .font(.caption)
                .foregroundColor(.secondary)
            OutOfStockProgressBar(completed: 0, total: 5, status: .refunded)
        }
    }
    .padding()
    .previewDisplayName("Different Progress Levels")
}

#Preview("Dark Mode") {
    VStack(spacing: 24) {
        OutOfStockProgressBar(completed: 310, total: 500, status: .pending)
        OutOfStockProgressBar(completed: 12, total: 12, status: .completed)
        OutOfStockProgressBar(completed: 0, total: 5, status: .refunded)
    }
    .padding()
    .preferredColorScheme(.dark)
    .previewDisplayName("Dark Mode")
}

#Preview("In Card Layout") {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Ava Harper")
                .font(.headline)
            Spacer()
            Text("Pending")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(LopanColors.warning.opacity(0.2))
                .foregroundColor(LopanColors.warning)
                .cornerRadius(12)
        }

        Text("OOS since Oct 25 (16 days)")
            .font(.caption)
            .foregroundColor(.secondary)

        Divider()

        Text("Top critical: SKU-XYZ-123 • 50")
            .font(.subheadline)
            .foregroundColor(.secondary)

        OutOfStockProgressBar(completed: 310, total: 500, status: .pending)

        Text("Last update: John Doe")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .secondarySystemBackground))
    )
    .padding()
    .previewDisplayName("In Card Layout")
}
