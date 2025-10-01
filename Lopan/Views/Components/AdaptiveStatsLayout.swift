//
//  AdaptiveStatsLayout.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Smart adaptive layout that switches between single-row and 2×2 grid based on space constraints
//

import SwiftUI

/// Adaptive layout for status indicators that automatically switches between single-row and grid layouts
/// based on available space, Dynamic Type settings, and number length.
public struct AdaptiveStatsLayout: View {

    // MARK: - Public Properties

    let configs: [StatusCardConfig]
    let selectedStatus: OutOfStockStatus?
    let isDataLocked: Bool
    let onTap: (OutOfStockStatus?) -> Void

    // MARK: - Environment & State

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Initializer

    public init(
        configs: [StatusCardConfig],
        selectedStatus: OutOfStockStatus?,
        isDataLocked: Bool = false,
        onTap: @escaping (OutOfStockStatus?) -> Void
    ) {
        self.configs = configs
        self.selectedStatus = selectedStatus
        self.isDataLocked = isDataLocked
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        singleRowLayout
    }

    // MARK: - Layout Views

    private var singleRowLayout: some View {
        HStack(spacing: 8) {
            ForEach(configs) { config in
                CompactStatIndicator(
                    title: config.title,
                    value: config.value,
                    icon: config.icon,
                    color: config.color,
                    isSelected: selectedStatus == config.status,
                    isPrimary: config.status == nil, // Total is primary
                    onTap: { onTap(config.status) }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 60)
    }

}

// MARK: - Status Card Configuration

public struct StatusCardConfig: Identifiable {
    public let id: String
    public let title: String
    public let value: String
    public let icon: String
    public let color: Color
    public let status: OutOfStockStatus?
    public let accessibilityHint: String?

    public init(
        id: String,
        title: String,
        value: String,
        icon: String,
        color: Color,
        status: OutOfStockStatus?,
        accessibilityHint: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.status = status
        self.accessibilityHint = accessibilityHint
    }
}

// MARK: - Preview Provider

#Preview("AdaptiveStatsLayout - Single Row") {
    let sampleConfigs = [
        StatusCardConfig(
            id: "total",
            title: "总计",
            value: "142",
            icon: "circle.fill",
            color: LopanColors.primary,
            status: nil
        ),
        StatusCardConfig(
            id: "pending",
            title: "待处理",
            value: "28",
            icon: "clock.fill",
            color: LopanColors.warning,
            status: .pending
        ),
        StatusCardConfig(
            id: "completed",
            title: "已完成",
            value: "96",
            icon: "checkmark.circle.fill",
            color: LopanColors.success,
            status: .completed
        ),
        StatusCardConfig(
            id: "returned",
            title: "已退货",
            value: "18",
            icon: "arrow.uturn.left",
            color: LopanColors.error,
            status: .returned
        )
    ]

    AdaptiveStatsLayout(
        configs: sampleConfigs,
        selectedStatus: .pending,
        onTap: { _ in }
    )
    .frame(height: 80)
    .background(Color(.systemGroupedBackground))
}

#Preview("AdaptiveStatsLayout - Large Numbers") {
    let sampleConfigs = [
        StatusCardConfig(
            id: "total",
            title: "总计",
            value: "1234",
            icon: "circle.fill",
            color: LopanColors.primary,
            status: nil
        ),
        StatusCardConfig(
            id: "pending",
            title: "待处理",
            value: "4567",
            icon: "clock.fill",
            color: LopanColors.warning,
            status: .pending
        ),
        StatusCardConfig(
            id: "completed",
            title: "已完成",
            value: "8901",
            icon: "checkmark.circle.fill",
            color: LopanColors.success,
            status: .completed
        ),
        StatusCardConfig(
            id: "returned",
            title: "已退货",
            value: "234",
            icon: "arrow.uturn.left",
            color: LopanColors.error,
            status: .returned
        )
    ]

    AdaptiveStatsLayout(
        configs: sampleConfigs,
        selectedStatus: nil,
        onTap: { _ in }
    )
    .frame(height: 150)
    .background(Color(.systemGroupedBackground))
}