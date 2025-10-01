//
//  DonutChartStatsCard.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Statistics card component for donut chart - displays outside the chart
//

import SwiftUI

/// Statistics card for displaying donut chart data in a coordinated, readable format
struct DonutChartStatsCard: View {

    // MARK: - Properties

    let totalValue: Int
    let selectedSegment: PieChartSegment?
    let totalLabel: String
    let itemCount: Int?

    // MARK: - Initialization

    init(
        totalValue: Int,
        selectedSegment: PieChartSegment? = nil,
        totalLabel: String = "总计",
        itemCount: Int? = nil
    ) {
        self.totalValue = totalValue
        self.selectedSegment = selectedSegment
        self.totalLabel = totalLabel
        self.itemCount = itemCount
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            if let selected = selectedSegment {
                // Selected segment view
                selectedSegmentContent(selected)
            } else {
                // Total view
                totalContent
            }
        }
        .padding(.horizontal, LopanSpacing.md)
        .padding(.vertical, LopanSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(LopanColors.backgroundSecondary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                        .stroke(
                            selectedSegment?.color.opacity(0.3) ?? LopanColors.border.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.3), value: selectedSegment?.id)
    }

    // MARK: - Total Content

    private var totalContent: some View {
        HStack(spacing: LopanSpacing.sm) {
            // Icon
            Image(systemName: "chart.pie.fill")
                .font(.title3)
                .foregroundColor(LopanColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(totalLabel)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)

                Text("\(totalValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()

            if let count = itemCount {
                Text("\(count) 个地区")
                    .font(.caption)
                    .foregroundColor(LopanColors.textTertiary)
                    .padding(.horizontal, LopanSpacing.sm)
                    .padding(.vertical, LopanSpacing.xs)
                    .background(
                        Capsule()
                            .fill(LopanColors.backgroundPrimary)
                    )
            }
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Selected Segment Content

    private func selectedSegmentContent(_ segment: PieChartSegment) -> some View {
        HStack(spacing: LopanSpacing.sm) {
            // Color indicator
            Circle()
                .fill(segment.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(segment.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text("\(Int(segment.value))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(segment.color)

                    Text("包")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
            }

            Spacer()

            // Percentage badge
            Text(String(format: "%.0f%%", segment.percentage * 100))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, LopanSpacing.sm)
                .padding(.vertical, LopanSpacing.xs)
                .background(
                    Capsule()
                        .fill(segment.color)
                )

            // Tap hint
            Image(systemName: "hand.tap")
                .font(.caption)
                .foregroundColor(LopanColors.textTertiary)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Preview

#if DEBUG
struct DonutChartStatsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Default state
            DonutChartStatsCard(
                totalValue: 592,
                itemCount: 8
            )

            // Selected state
            DonutChartStatsCard(
                totalValue: 592,
                selectedSegment: PieChartSegment(
                    value: 53,
                    label: "Ibadan",
                    color: LopanColors.success,
                    percentage: 0.089
                ),
                itemCount: 8
            )
        }
        .padding()
        .background(LopanColors.backgroundPrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
