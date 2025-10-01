//
//  InteractivePieChart.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Interactive pie chart with hover animations and detailed tooltips
//

import SwiftUI
import Foundation
import Darwin

/// Interactive pie chart with hover/tap animations and tooltips
struct InteractivePieChart: View {

    // MARK: - Properties

    let data: [PieChartSegment]
    let animate: Bool
    let showTooltips: Bool

    @State private var selectedSegment: PieChartSegment?
    @State private var animationProgress: Double = 0
    @State private var tooltipLocation: CGPoint = .zero
    @State private var showTooltip: Bool = false

    // MARK: - Initialization

    init(data: [PieChartSegment], animate: Bool = true, showTooltips: Bool = true) {
        self.data = data
        self.animate = animate
        self.showTooltips = showTooltips
    }

    // MARK: - Constants

    private let expansionOffset: CGFloat = 8
    private let animationDuration: Double = 0.3

    // MARK: - Body

    var body: some View {
        pieChartContent
            .onAppear(perform: setupAnimation)
            .onTapGesture(perform: handleBackgroundTap)
    }

    // MARK: - Chart Content

    private var pieChartContent: some View {
        ZStack {
            pieSegments
            centerContent
            tooltipOverlay
        }
    }

    private var pieSegments: some View {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, segment in
            pieSlice(for: segment, at: index)
        }
    }

    private func pieSlice(for segment: PieChartSegment, at index: Int) -> some View {
        InteractivePieSlice(
            segment: segment,
            startAngle: startAngle(for: index),
            endAngle: endAngle(for: index),
            progress: animationProgress,
            isSelected: selectedSegment?.id == segment.id,
            expansionOffset: expansionOffset
        )
        .foregroundColor(segment.color)
        .onTapGesture {
            handleSegmentTap(segment)
        }
        .onLongPressGesture(minimumDuration: 0) {
            handleSegmentPress(segment, isPressing: true)
        }
    }

    @ViewBuilder
    private var tooltipOverlay: some View {
        if showTooltip && showTooltips, let selectedSegment = selectedSegment {
            tooltipView(for: selectedSegment)
                .position(tooltipLocation)
                .animation(.easeInOut(duration: 0.2), value: tooltipLocation)
        }
    }

    private func setupAnimation() {
        if animate {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        } else {
            animationProgress = 1.0
        }
    }

    private func handleBackgroundTap() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            selectedSegment = nil
            showTooltip = false
        }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 4) {
            if let selected = selectedSegment {
                // Show selected segment details
                VStack(spacing: 2) {
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
                }
            } else {
                // Show total
                VStack(spacing: 2) {
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
        }
        .animation(.easeInOut(duration: animationDuration), value: selectedSegment?.id)
    }

    // MARK: - Tooltip

    private func tooltipView(for segment: PieChartSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(segment.color)
                    .frame(width: 8, height: 8)

                Text(segment.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            HStack {
                Text("数量:")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)

                Text("\(Int(segment.value))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            HStack {
                Text("占比:")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)

                Text("\(String(format: "%.1f", segment.percentage * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(segment.color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(segment.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(showTooltip ? 1.0 : 0.8)
        .opacity(showTooltip ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showTooltip)
    }

    // MARK: - Interaction Handlers

    private func handleSegmentTap(_ segment: PieChartSegment) {
        withAnimation(.easeInOut(duration: animationDuration)) {
            if selectedSegment?.id == segment.id {
                selectedSegment = nil
                showTooltip = false
            } else {
                selectedSegment = segment
                showTooltip = showTooltips
                updateTooltipLocation(for: segment)
            }
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func handleSegmentPress(_ segment: PieChartSegment, isPressing: Bool) {
        if isPressing {
            withAnimation(.easeInOut(duration: 0.1)) {
                selectedSegment = segment
                showTooltip = showTooltips
                updateTooltipLocation(for: segment)
            }
        } else if !showTooltips {
            // If tooltips are disabled, deselect after brief highlight
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: animationDuration)) {
                    selectedSegment = nil
                    showTooltip = false
                }
            }
        }
    }

    private func updateTooltipLocation(for segment: PieChartSegment) {
        guard let index = data.firstIndex(where: { $0.id == segment.id }) else { return }

        let midAngle = (startAngle(for: index).radians + endAngle(for: index).radians) / 2
        let radius: CGFloat = 100 // Approximate radius for tooltip positioning

        tooltipLocation = CGPoint(
            x: Darwin.cos(midAngle) * radius * 0.6,
            y: Darwin.sin(midAngle) * radius * 0.6
        )
    }

    // MARK: - Computed Properties

    private var totalValue: Int {
        Int(data.reduce(0) { $0 + $1.value })
    }

    // MARK: - Angle Calculations

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

// MARK: - Interactive Pie Slice

private struct InteractivePieSlice: Shape {
    let segment: PieChartSegment
    let startAngle: Angle
    let endAngle: Angle
    var progress: Double
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
        let radius = min(rect.width, rect.height) / 2 * 0.85

        let currentEndAngle = Angle.degrees(
            startAngle.degrees + (endAngle.degrees - startAngle.degrees) * progress
        )

        // Calculate expansion offset for selected segment
        let midAngle = (startAngle.radians + currentEndAngle.radians) / 2
        let expansionX = isSelected ? Darwin.cos(midAngle) * expansionOffset : 0
        let expansionY = isSelected ? Darwin.sin(midAngle) * expansionOffset : 0
        let expandedCenter = CGPoint(
            x: center.x + expansionX,
            y: center.y + expansionY
        )

        var path = Path()

        // Move to center
        path.move(to: expandedCenter)

        // Draw line to start of arc
        let startPoint = CGPoint(
            x: expandedCenter.x + radius * Darwin.cos(startAngle.radians),
            y: expandedCenter.y + radius * Darwin.sin(startAngle.radians)
        )
        path.addLine(to: startPoint)

        // Draw arc
        path.addArc(
            center: expandedCenter,
            radius: radius,
            startAngle: startAngle,
            endAngle: currentEndAngle,
            clockwise: false
        )

        // Close path back to center
        path.closeSubpath()

        return path
    }
}

// MARK: - Enhanced Pie Chart (Original)

struct EnhancedPieChart: View {
    let data: [PieChartSegment]
    let animate: Bool

    init(data: [PieChartSegment], animate: Bool = true) {
        self.data = data
        self.animate = animate
    }

    var body: some View {
        InteractivePieChart(data: data, animate: animate, showTooltips: false)
    }
}

// MARK: - Enhanced Customer Pie Chart

struct EnhancedCustomerPieChart: View {
    let data: [PieChartSegment]
    let animate: Bool

    init(data: [PieChartSegment], animate: Bool = true) {
        self.data = data
        self.animate = animate
    }

    var body: some View {
        InteractivePieChart(data: data, animate: animate, showTooltips: true)
    }
}

// MARK: - Preview

#if DEBUG
struct InteractivePieChart_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = [
            PieChartSegment(value: 35, label: "上海", color: LopanColors.primary),
            PieChartSegment(value: 25, label: "北京", color: LopanColors.success),
            PieChartSegment(value: 20, label: "广州", color: LopanColors.warning),
            PieChartSegment(value: 15, label: "深圳", color: LopanColors.error),
            PieChartSegment(value: 5, label: "其他", color: LopanColors.info)
        ]

        VStack(spacing: 40) {
            Text("Interactive Pie Chart")
                .font(.title2)
                .fontWeight(.bold)

            InteractivePieChart(data: sampleData)
                .frame(width: 300, height: 300)

            Text("Tap segments to see details")
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
        }
        .padding()
    }
}
#endif