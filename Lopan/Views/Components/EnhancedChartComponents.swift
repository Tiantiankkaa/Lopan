//
//  EnhancedChartComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Enhanced chart components for multiple visualization types with animations
//

import SwiftUI
import Foundation
import Darwin

// MARK: - Enhanced Donut Chart (Interactive)

struct EnhancedDonutChart: View {
    let data: [PieChartSegment]
    let animate: Bool
    let innerRadius: CGFloat
    let showCenterContent: Bool

    @State private var animationProgress: Double = 0
    @Binding var selectedSegment: PieChartSegment?

    private let animationDuration: Double = 0.3
    private let expansionOffset: CGFloat = 8

    init(
        data: [PieChartSegment],
        animate: Bool = true,
        innerRadius: CGFloat = 0.4,
        showCenterContent: Bool = true,
        selectedSegment: Binding<PieChartSegment?>
    ) {
        self.data = data
        self.animate = animate
        self.innerRadius = innerRadius
        self.showCenterContent = showCenterContent
        self._selectedSegment = selectedSegment
    }

    // Convenience initializer for backward compatibility
    init(data: [PieChartSegment], animate: Bool = true, innerRadius: CGFloat = 0.4) {
        self.data = data
        self.animate = animate
        self.innerRadius = innerRadius
        self.showCenterContent = true
        self._selectedSegment = .constant(nil)
    }

    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, segment in
                InteractiveDonutSlice(
                    segment: segment,
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index),
                    progress: animationProgress,
                    innerRadius: innerRadius,
                    isSelected: selectedSegment?.id == segment.id,
                    expansionOffset: expansionOffset
                )
                .foregroundColor(segment.color)
                .onTapGesture {
                    handleSegmentTap(segment)
                }
            }

            // Center content (optional)
            if showCenterContent {
                VStack(spacing: 4) {
                    if let selected = selectedSegment {
                        // Show selected segment details
                        Text("\(Int(selected.value))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(selected.color)
                            .transition(.scale.combined(with: .opacity))

                        Text(selected.label)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .transition(.scale.combined(with: .opacity))

                        Text(String(format: "%.0f%%", selected.percentage * 100))
                            .font(.caption2)
                            .foregroundColor(LopanColors.textSecondary)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Show total
                        Text("\(totalValue)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .transition(.scale.combined(with: .opacity))

                        Text("总计")
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: animationDuration), value: selectedSegment?.id)
            } else {
                // Minimal hint when center is empty
                Image(systemName: "hand.tap")
                    .font(.title3)
                    .foregroundColor(LopanColors.textTertiary.opacity(0.5))
                    .opacity(selectedSegment == nil ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: animationDuration), value: selectedSegment?.id)
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
        .onTapGesture {
            // Tap on center area to deselect
            withAnimation(.easeInOut(duration: animationDuration)) {
                selectedSegment = nil
            }
        }
    }

    private func handleSegmentTap(_ segment: PieChartSegment) {
        withAnimation(.easeInOut(duration: animationDuration)) {
            if selectedSegment?.id == segment.id {
                selectedSegment = nil
            } else {
                selectedSegment = segment
            }
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private var totalValue: Int {
        Int(data.reduce(0) { $0 + $1.value })
    }

    private func startAngle(for index: Int) -> Angle {
        let precedingValues = data.prefix(index).reduce(0) { $0 + $1.value }
        let ratio = precedingValues / data.reduce(0) { $0 + $1.value }
        return .degrees(ratio * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let precedingValues = data.prefix(index + 1).reduce(0) { $0 + $1.value }
        let ratio = precedingValues / data.reduce(0) { $0 + $1.value }
        return .degrees(ratio * 360 - 90)
    }
}

private struct InteractiveDonutSlice: Shape {
    let segment: PieChartSegment
    let startAngle: Angle
    let endAngle: Angle
    var progress: Double
    let innerRadius: CGFloat
    var isSelected: Bool
    let expansionOffset: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(progress, isSelected ? 1.0 : 0.0)
        }
        set {
            progress = newValue.first
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseOuterRadius = min(rect.width, rect.height) / 2 * 0.8

        // Add expansion effect when selected
        let outerRadius = baseOuterRadius + (isSelected ? expansionOffset : 0)
        let innerRadiusActual = outerRadius * innerRadius

        let currentEndAngle = Angle.degrees(
            startAngle.degrees + (endAngle.degrees - startAngle.degrees) * progress
        )

        // Calculate offset for selected segment (move outward from center)
        let midAngle = (startAngle.radians + currentEndAngle.radians) / 2
        let offsetX = isSelected ? Darwin.cos(midAngle) * expansionOffset * 0.5 : 0
        let offsetY = isSelected ? Darwin.sin(midAngle) * expansionOffset * 0.5 : 0
        let adjustedCenter = CGPoint(x: center.x + offsetX, y: center.y + offsetY)

        var path = Path()
        path.addArc(
            center: adjustedCenter,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: currentEndAngle,
            clockwise: false
        )
        path.addLine(to: CGPoint(
            x: adjustedCenter.x + innerRadiusActual * Darwin.cos(currentEndAngle.radians),
            y: adjustedCenter.y + innerRadiusActual * Darwin.sin(currentEndAngle.radians)
        ))
        path.addArc(
            center: adjustedCenter,
            radius: innerRadiusActual,
            startAngle: currentEndAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Enhanced Bar Chart

struct EnhancedBarChart: View {
    let data: [BarChartItem]
    let animate: Bool

    @State private var animationProgress: Double = 0

    init(data: [BarChartItem], animate: Bool = true) {
        self.data = data
        self.animate = animate
    }

    var body: some View {
        VStack(spacing: LopanSpacing.sm) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 4) {
                    HStack {
                        Text(item.category)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(item.value))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LopanColors.backgroundSecondary)
                                .frame(height: 8)

                            // Progress bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.color)
                                .frame(width: geometry.size.width * CGFloat(item.value / maxValue) * animationProgress, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }

    private var maxValue: Double {
        data.map { $0.value }.max() ?? 1
    }
}

// MARK: - Enhanced Horizontal Bar Chart

struct EnhancedHorizontalBarChart: View {
    let data: [BarChartItem]
    let animate: Bool
    let maxHeight: CGFloat?

    @State private var animationProgress: Double = 0

    // Calculate if scrolling is needed
    private var needsScrolling: Bool {
        // Each row is approximately 32px (20px bar + 12px spacing)
        let estimatedHeight = CGFloat(data.count) * 32
        return maxHeight != nil && estimatedHeight > maxHeight!
    }

    init(data: [BarChartItem], animate: Bool = true, maxHeight: CGFloat? = 300) {
        self.data = data
        self.animate = animate
        self.maxHeight = maxHeight
    }

    var body: some View {
        Group {
            if needsScrolling && maxHeight != nil {
                // Use ScrollView when content exceeds max height
                ScrollView(.vertical, showsIndicators: true) {
                    contentView
                        .padding(.trailing, 4) // Add padding for scroll indicator
                }
                .frame(maxHeight: maxHeight)
            } else {
                // Use plain VStack when content fits
                contentView
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: LopanSpacing.sm) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                HorizontalBarRow(
                    item: item,
                    maxValue: maxValue,
                    progress: animationProgress
                )
            }
        }
    }

    private var maxValue: Double {
        data.map { $0.value }.max() ?? 1
    }
}

private struct HorizontalBarRow: View {
    let item: BarChartItem
    let maxValue: Double
    let progress: Double

    private var barWidth: CGFloat {
        CGFloat(item.value / maxValue) * progress
    }

    var body: some View {
        HStack(spacing: LopanSpacing.sm) {
            // Category label
            Text(item.category)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(2)

            // Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LopanColors.backgroundSecondary)
                        .frame(height: 20)

                    // Progress bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color)
                        .frame(width: geometry.size.width * barWidth, height: 20)
                }
            }
            .frame(height: 20)

            // Value label
            Text("\(Int(item.value))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Enhanced Area Chart

struct EnhancedAreaChart: View {
    let data: [ChartDataPoint]
    let animate: Bool

    @State private var animationProgress: Double = 0

    init(data: [ChartDataPoint], animate: Bool = true) {
        self.data = data
        self.animate = animate
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                chartGrid(in: geometry.size)

                // Area path
                areaPath(in: geometry.size)
                    .fill(
                        LinearGradient(
                            colors: [
                                LopanColors.primary.opacity(0.3),
                                LopanColors.primary.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(
                        Rectangle()
                            .size(width: geometry.size.width * animationProgress, height: geometry.size.height)
                    )

                // Line path
                linePath(in: geometry.size)
                    .stroke(LopanColors.primary, lineWidth: 2)
                    .clipShape(
                        Rectangle()
                            .size(width: geometry.size.width * animationProgress, height: geometry.size.height)
                    )

                // Data points
                if animationProgress > 0.8 {
                    dataPoints(in: geometry.size)
                }
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }

    private func chartGrid(in size: CGSize) -> some View {
        Path { path in
            let gridLines = 5
            for i in 0...gridLines {
                let y = CGFloat(i) * size.height / CGFloat(gridLines)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(LopanColors.border.opacity(0.3), lineWidth: 0.5)
    }

    private func areaPath(in size: CGSize) -> Path {
        guard !data.isEmpty else { return Path() }

        let maxY = data.map { $0.y }.max() ?? 1
        let minY = data.map { $0.y }.min() ?? 0
        let range = maxY - minY

        var path = Path()

        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: size.height))

        // Add data points
        for (index, point) in data.enumerated() {
            let x = CGFloat(index) * size.width / CGFloat(data.count - 1)
            let y = size.height - CGFloat((point.y - minY) / range) * size.height

            if index == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Close path to bottom right
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()

        return path
    }

    private func linePath(in size: CGSize) -> Path {
        guard !data.isEmpty else { return Path() }

        let maxY = data.map { $0.y }.max() ?? 1
        let minY = data.map { $0.y }.min() ?? 0
        let range = maxY - minY

        var path = Path()

        for (index, point) in data.enumerated() {
            let x = CGFloat(index) * size.width / CGFloat(data.count - 1)
            let y = size.height - CGFloat((point.y - minY) / range) * size.height

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func dataPoints(in size: CGSize) -> some View {
        let maxY = data.map { $0.y }.max() ?? 1
        let minY = data.map { $0.y }.min() ?? 0
        let range = maxY - minY

        return ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
            let x = CGFloat(index) * size.width / CGFloat(data.count - 1)
            let y = size.height - CGFloat((point.y - minY) / range) * size.height

            Circle()
                .fill(LopanColors.primary)
                .frame(width: 6, height: 6)
                .position(x: x, y: y)
                .opacity(animationProgress)
        }
    }
}

// MARK: - Enhanced Line Chart

struct EnhancedLineChart: View {
    let data: [ChartDataPoint]
    let animate: Bool

    @State private var animationProgress: Double = 0

    init(data: [ChartDataPoint], animate: Bool = true) {
        self.data = data
        self.animate = animate
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                chartGrid(in: geometry.size)

                // Line path
                linePath(in: geometry.size)
                    .trim(from: 0, to: animationProgress)
                    .stroke(LopanColors.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Data points
                if animationProgress > 0.8 {
                    dataPoints(in: geometry.size)
                }
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }

    private func chartGrid(in size: CGSize) -> some View {
        Path { path in
            let gridLines = 5
            for i in 0...gridLines {
                let y = CGFloat(i) * size.height / CGFloat(gridLines)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(LopanColors.border.opacity(0.3), lineWidth: 0.5)
    }

    private func linePath(in size: CGSize) -> Path {
        guard !data.isEmpty else { return Path() }

        let maxY = data.map { $0.y }.max() ?? 1
        let minY = data.map { $0.y }.min() ?? 0
        let range = maxY - minY

        var path = Path()

        for (index, point) in data.enumerated() {
            let x = CGFloat(index) * size.width / CGFloat(data.count - 1)
            let y = size.height - CGFloat((point.y - minY) / range) * size.height

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func dataPoints(in size: CGSize) -> some View {
        let maxY = data.map { $0.y }.max() ?? 1
        let minY = data.map { $0.y }.min() ?? 0
        let range = maxY - minY

        return ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
            let x = CGFloat(index) * size.width / CGFloat(data.count - 1)
            let y = size.height - CGFloat((point.y - minY) / range) * size.height

            Circle()
                .fill(LopanColors.primary)
                .frame(width: 6, height: 6)
                .position(x: x, y: y)
                .scaleEffect(animationProgress)
        }
    }
}

// MARK: - Enhanced Scatter Chart

struct EnhancedScatterChart: View {
    let data: [ChartDataPoint]
    let animate: Bool

    @State private var animationProgress: Double = 0

    init(data: [ChartDataPoint], animate: Bool = true) {
        self.data = data
        self.animate = animate
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                chartGrid(in: geometry.size)

                // Scatter points
                scatterPoints(in: geometry.size)
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }

    private func chartGrid(in size: CGSize) -> some View {
        Path { path in
            let gridLines = 5
            for i in 0...gridLines {
                let y = CGFloat(i) * size.height / CGFloat(gridLines)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))

                let x = CGFloat(i) * size.width / CGFloat(gridLines)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        .stroke(LopanColors.border.opacity(0.3), lineWidth: 0.5)
    }

    private func scatterPoints(in size: CGSize) -> some View {
        let maxX = data.map { $0.x }.max() ?? 1
        let minX = data.map { $0.x }.min() ?? 0
        let maxY = data.map { $0.y }.max() ?? 1
        let minY = data.map { $0.y }.min() ?? 0
        let rangeX = maxX - minX
        let rangeY = maxY - minY

        return ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
            let x = CGFloat((point.x - minX) / rangeX) * size.width
            let y = size.height - CGFloat((point.y - minY) / rangeY) * size.height

            Circle()
                .fill(point.color)
                .frame(width: 8, height: 8)
                .position(x: x, y: y)
                .scaleEffect(animationProgress)
                .opacity(animationProgress)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EnhancedChartComponents_Previews: PreviewProvider {
    static var previews: some View {
        let samplePieData = [
            PieChartSegment(value: 30, label: "A", color: .blue),
            PieChartSegment(value: 25, label: "B", color: .green),
            PieChartSegment(value: 20, label: "C", color: .orange)
        ]

        let sampleBarData = [
            BarChartItem(category: "Product A", value: 30, color: .blue),
            BarChartItem(category: "Product B", value: 25, color: .green),
            BarChartItem(category: "Product C", value: 20, color: .orange)
        ]

        let sampleLineData = [
            ChartDataPoint(x: 1, y: 10, label: "Jan"),
            ChartDataPoint(x: 2, y: 15, label: "Feb"),
            ChartDataPoint(x: 3, y: 12, label: "Mar"),
            ChartDataPoint(x: 4, y: 18, label: "Apr")
        ]

        VStack(spacing: 30) {
            EnhancedDonutChart(data: samplePieData)
                .frame(height: 200)

            EnhancedHorizontalBarChart(data: sampleBarData)
                .frame(height: 150)

            EnhancedLineChart(data: sampleLineData)
                .frame(height: 150)
        }
        .padding()
    }
}
#endif