//
//  InteractiveBarChart.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Interactive bar chart with touch gestures and fluid animations
//

import SwiftUI
import Foundation

// MARK: - Interactive Bar Chart

/// Modern interactive bar chart with touch gestures, tooltips, and smooth animations
struct InteractiveBarChart: View {
    let data: [BarChartItem]
    let maxValue: Double?
    let showLegend: Bool
    let animate: Bool

    @State private var selectedBar: BarChartItem?
    @State private var animationProgress: Double = 0
    @State private var hoveredBar: BarChartItem?

    private let minBarHeight: CGFloat = 4
    private let barSpacing: CGFloat = 12
    private let animationDuration: Double = 0.8

    init(
        data: [BarChartItem],
        maxValue: Double? = nil,
        showLegend: Bool = false,
        animate: Bool = true
    ) {
        self.data = data
        self.maxValue = maxValue
        self.showLegend = showLegend
        self.animate = animate
    }

    public var body: some View {
        VStack(spacing: 16) {
            chartContent
                .onAppear(perform: setupAnimation)

            if showLegend && !data.isEmpty {
                legendView
            }
        }
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    barColumn(for: item, at: index, in: geometry)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 40) // Space for value labels
            .padding(.bottom, 24) // Space for category labels
        }
    }

    private func barColumn(for item: BarChartItem, at index: Int, in geometry: GeometryProxy) -> some View {
        VStack(spacing: 6) {
            // Value label above bar
            if selectedBar?.id == item.id || hoveredBar?.id == item.id {
                Text(formatValue(item.value))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(item.color)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 0)

            // Bar
            barShape(for: item, maxHeight: geometry.size.height - 90)
                .onTapGesture {
                    handleBarTap(item)
                }

            // Category label below bar
            Text(item.category)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LopanColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func barShape(for item: BarChartItem, maxHeight: CGFloat) -> some View {
        let maxVal = maxValue ?? data.map(\.value).max() ?? 1
        let heightRatio = CGFloat(item.value / maxVal)
        let calculatedHeight = max(maxHeight * heightRatio * animationProgress, minBarHeight)
        let isActive = selectedBar?.id == item.id || hoveredBar?.id == item.id

        return RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        item.color,
                        item.color.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: calculatedHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        item.color.opacity(0.3),
                        lineWidth: isActive ? 2 : 0
                    )
            )
            .scaleEffect(isActive ? 1.05 : 1.0, anchor: .bottom)
            .shadow(
                color: item.color.opacity(isActive ? 0.3 : 0.1),
                radius: isActive ? 8 : 4,
                x: 0,
                y: 2
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
            .animation(.easeOut(duration: animationDuration), value: animationProgress)
    }

    // MARK: - Legend

    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(data, id: \.id) { item in
                    legendItem(for: item)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func legendItem(for item: BarChartItem) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LopanColors.textPrimary)

                if let subCategory = item.subCategory {
                    Text(subCategory)
                        .font(.system(size: 10))
                        .foregroundColor(LopanColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(selectedBar?.id == item.id ? 1.0 : 0.6)
        )
        .onTapGesture {
            handleBarTap(item)
        }
    }

    // MARK: - Interaction

    private func setupAnimation() {
        if animate {
            withAnimation(.easeOut(duration: animationDuration)) {
                animationProgress = 1.0
            }
        } else {
            animationProgress = 1.0
        }
    }

    private func handleBarTap(_ item: BarChartItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedBar?.id == item.id {
                selectedBar = nil
            } else {
                selectedBar = item
            }
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Horizontal Bar Chart

/// Horizontal version of the bar chart for space-constrained layouts
struct HorizontalBarChart: View {
    let data: [BarChartItem]
    let maxValue: Double?
    let animate: Bool

    @State private var selectedBar: BarChartItem?
    @State private var animationProgress: Double = 0

    private let barHeight: CGFloat = 32
    private let barSpacing: CGFloat = 12
    private let animationDuration: Double = 0.8

    init(
        data: [BarChartItem],
        maxValue: Double? = nil,
        animate: Bool = true
    ) {
        self.data = data
        self.maxValue = maxValue
        self.animate = animate
    }

    public var body: some View {
        VStack(spacing: barSpacing) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                horizontalBar(for: item, at: index)
            }
        }
        .padding(.vertical, 8)
        .onAppear(perform: setupAnimation)
    }

    private func horizontalBar(for item: BarChartItem, at index: Int) -> some View {
        HStack(spacing: 12) {
            // Category label
            Text(item.category)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(LopanColors.textPrimary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            // Bar
            GeometryReader { geometry in
                let maxVal = maxValue ?? data.map(\.value).max() ?? 1
                let widthRatio = CGFloat(item.value / maxVal)
                let barWidth = geometry.size.width * widthRatio * animationProgress
                let isActive = selectedBar?.id == item.id

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LopanColors.backgroundSecondary)
                        .frame(width: geometry.size.width, height: barHeight)

                    // Actual bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    item.color,
                                    item.color.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth, height: barHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    item.color.opacity(0.4),
                                    lineWidth: isActive ? 2 : 0
                                )
                        )
                        .scaleEffect(isActive ? 1.05 : 1.0, anchor: .leading)
                        .shadow(
                            color: item.color.opacity(isActive ? 0.3 : 0.15),
                            radius: isActive ? 6 : 3,
                            x: 2,
                            y: 0
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                }
            }
            .frame(height: barHeight)
            .onTapGesture {
                handleBarTap(item)
            }

            // Value label
            Text(formatValue(item.value))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(item.color)
                .frame(width: 50, alignment: .trailing)
        }
        .animation(.easeOut(duration: animationDuration), value: animationProgress)
    }

    private func setupAnimation() {
        if animate {
            withAnimation(.easeOut(duration: animationDuration)) {
                animationProgress = 1.0
            }
        } else {
            animationProgress = 1.0
        }
    }

    private func handleBarTap(_ item: BarChartItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedBar?.id == item.id {
                selectedBar = nil
            } else {
                selectedBar = item
            }
        }

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Grouped Bar Chart

/// Bar chart that supports grouping multiple data series
struct GroupedBarChart: View {
    let groups: [String]
    let series: [[BarChartItem]]
    let animate: Bool

    @State private var animationProgress: Double = 0

    private let barSpacing: CGFloat = 4
    private let groupSpacing: CGFloat = 20

    init(
        groups: [String],
        series: [[BarChartItem]],
        animate: Bool = true
    ) {
        self.groups = groups
        self.series = series
        self.animate = animate
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: groupSpacing) {
                    ForEach(Array(series.enumerated()), id: \.offset) { groupIndex, groupData in
                        groupColumn(data: groupData, maxHeight: geometry.size.height - 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 24)
            }
        }
        .onAppear(perform: setupAnimation)
    }

    private func groupColumn(data: [BarChartItem], maxHeight: CGFloat) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(data, id: \.id) { item in
                    groupBar(for: item, maxHeight: maxHeight)
                }
            }

            if let firstItem = data.first {
                Text(firstItem.category)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LopanColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func groupBar(for item: BarChartItem, maxHeight: CGFloat) -> some View {
        let maxVal = series.flatMap { $0 }.map(\.value).max() ?? 1
        let heightRatio = CGFloat(item.value / maxVal)
        let barHeight = max(maxHeight * heightRatio * animationProgress, 4)

        return RoundedRectangle(cornerRadius: 6)
            .fill(item.color)
            .frame(width: 24, height: barHeight)
            .shadow(color: item.color.opacity(0.2), radius: 3, x: 0, y: 2)
    }

    private func setupAnimation() {
        if animate {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        } else {
            animationProgress = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Vertical Bar Chart") {
    let sampleData = [
        BarChartItem(category: "产品A", value: 450, color: LopanColors.Jewel.sapphire, subCategory: "客户: 25"),
        BarChartItem(category: "产品B", value: 350, color: LopanColors.Jewel.emerald, subCategory: "客户: 20"),
        BarChartItem(category: "产品C", value: 280, color: LopanColors.Jewel.amethyst, subCategory: "客户: 18"),
        BarChartItem(category: "产品D", value: 220, color: LopanColors.Jewel.ruby, subCategory: "客户: 15"),
        BarChartItem(category: "产品E", value: 180, color: LopanColors.Jewel.citrine, subCategory: "客户: 12")
    ]

    VStack(spacing: 20) {
        Text("Interactive Bar Chart")
            .font(.title2.weight(.bold))

        InteractiveBarChart(data: sampleData, showLegend: true)
            .frame(height: 300)
            .chartContainerGlass()
            .padding()
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Horizontal Bar Chart") {
    let sampleData = [
        BarChartItem(category: "上海", value: 450, color: LopanColors.primary),
        BarChartItem(category: "北京", value: 380, color: LopanColors.success),
        BarChartItem(category: "广州", value: 320, color: LopanColors.warning),
        BarChartItem(category: "深圳", value: 280, color: LopanColors.info),
        BarChartItem(category: "成都", value: 220, color: LopanColors.Jewel.amethyst)
    ]

    VStack(spacing: 20) {
        Text("Horizontal Bar Chart")
            .font(.title2.weight(.bold))

        HorizontalBarChart(data: sampleData)
            .chartContainerGlass()
            .padding()
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}