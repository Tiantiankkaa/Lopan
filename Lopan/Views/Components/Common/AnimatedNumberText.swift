//
//  AnimatedNumberText.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Smooth animated number transitions with iOS 26 content transitions
//

import SwiftUI
import Foundation

// MARK: - Enhanced Animated Number Text

/// Enhanced animated text component that smoothly transitions between number values
struct EnhancedAnimatedNumber: View {
    let value: Double
    let format: FloatingPointFormatStyle<Double>
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color

    @State private var displayValue: Double

    init(
        value: Double,
        format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0)),
        font: Font = .system(size: 32, weight: .bold, design: .rounded),
        fontWeight: Font.Weight = .bold,
        foregroundColor: Color = LopanColors.textPrimary
    ) {
        self.value = value
        self.format = format
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        _displayValue = State(initialValue: value)
    }

    var body: some View {
        Text(displayValue, format: format)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(foregroundColor)
            .monospacedDigit()
            .contentTransition(.numericText(value: displayValue))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayValue)
            .onChange(of: value) { oldValue, newValue in
                displayValue = newValue
            }
    }
}

// MARK: - Enhanced Animated Integer

/// Enhanced animated text for integer values with counting effect
struct EnhancedAnimatedInteger: View {
    let value: Int
    let prefix: String
    let suffix: String
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color

    @State private var displayValue: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        value: Int,
        prefix: String = "",
        suffix: String = "",
        font: Font = .system(size: 28, weight: .bold, design: .rounded),
        fontWeight: Font.Weight = .bold,
        foregroundColor: Color = LopanColors.textPrimary
    ) {
        self.value = value
        self.prefix = prefix
        self.suffix = suffix
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        _displayValue = State(initialValue: value)
    }

    var body: some View {
        HStack(spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
                    .font(font)
                    .fontWeight(fontWeight)
                    .foregroundColor(foregroundColor.opacity(0.8))
            }

            Text("\(displayValue)")
                .font(font)
                .fontWeight(fontWeight)
                .foregroundColor(foregroundColor)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(displayValue)))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayValue)

            if !suffix.isEmpty {
                Text(suffix)
                    .font(font)
                    .fontWeight(fontWeight)
                    .foregroundColor(foregroundColor.opacity(0.8))
            }
        }
        .onChange(of: value) { oldValue, newValue in
            if reduceMotion {
                displayValue = newValue
            } else {
                animateValue(from: oldValue, to: newValue)
            }
        }
    }

    private func animateValue(from start: Int, to end: Int) {
        let difference = abs(end - start)

        // For small differences, animate smoothly
        if difference <= 100 {
            displayValue = end
        } else {
            // For large differences, use step animation
            let steps = min(difference, 20) // Max 20 steps
            let increment = (end - start) / steps

            for step in 1...steps {
                let delay = Double(step) * 0.03
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if step == steps {
                        displayValue = end
                    } else {
                        displayValue = start + (increment * step)
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Animated Currency

/// Enhanced animated text for currency values with proper formatting
struct EnhancedAnimatedCurrency: View {
    let value: Double
    let currencyCode: String
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color

    @State private var displayValue: Double

    init(
        value: Double,
        currencyCode: String = "CNY",
        font: Font = .system(size: 28, weight: .bold, design: .rounded),
        fontWeight: Font.Weight = .bold,
        foregroundColor: Color = LopanColors.textPrimary
    ) {
        self.value = value
        self.currencyCode = currencyCode
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        _displayValue = State(initialValue: value)
    }

    var body: some View {
        Text(displayValue, format: .currency(code: currencyCode))
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(foregroundColor)
            .monospacedDigit()
            .contentTransition(.numericText(value: displayValue))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayValue)
            .onChange(of: value) { oldValue, newValue in
                displayValue = newValue
            }
    }
}

// MARK: - Enhanced Animated Percentage

/// Enhanced animated text for percentage values
struct EnhancedAnimatedPercentage: View {
    let value: Double
    let decimalPlaces: Int
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color

    @State private var displayValue: Double

    init(
        value: Double,
        decimalPlaces: Int = 1,
        font: Font = .system(size: 24, weight: .semibold, design: .rounded),
        fontWeight: Font.Weight = .semibold,
        foregroundColor: Color = LopanColors.textPrimary
    ) {
        self.value = value
        self.decimalPlaces = decimalPlaces
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        _displayValue = State(initialValue: value)
    }

    var body: some View {
        Text(displayValue, format: .percent.precision(.fractionLength(decimalPlaces)))
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(foregroundColor)
            .monospacedDigit()
            .contentTransition(.numericText(value: displayValue))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayValue)
            .onChange(of: value) { oldValue, newValue in
                displayValue = newValue
            }
    }
}

// MARK: - Animated Stat Card

/// Card component with animated statistics
struct AnimatedStatCard: View {
    let title: String
    let value: Double
    let format: StatFormat
    let trend: TrendIndicator?
    let icon: String?

    enum StatFormat {
        case integer
        case decimal(places: Int)
        case currency(code: String)
        case percentage(places: Int)
    }

    enum TrendIndicator {
        case up(value: Double)
        case down(value: Double)
        case neutral

        var color: Color {
            switch self {
            case .up: return LopanColors.success
            case .down: return LopanColors.error
            case .neutral: return LopanColors.textSecondary
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var text: String {
            switch self {
            case .up(let value): return "+\(String(format: "%.1f", value))%"
            case .down(let value): return "\(String(format: "%.1f", value))%"
            case .neutral: return "0%"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.primary)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LopanColors.textSecondary)

                Spacer()

                if let trend = trend {
                    HStack(spacing: 4) {
                        Image(systemName: trend.icon)
                            .font(.system(size: 10, weight: .bold))

                        Text(trend.text)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(trend.color)
                }
            }

            // Animated value
            animatedValueView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LopanColors.primary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var animatedValueView: some View {
        switch format {
        case .integer:
            EnhancedAnimatedInteger(
                value: Int(value),
                font: .system(size: 28, weight: .bold, design: .rounded),
                foregroundColor: LopanColors.textPrimary
            )

        case .decimal(let places):
            EnhancedAnimatedNumber(
                value: value,
                format: .number.precision(.fractionLength(places)),
                font: .system(size: 28, weight: .bold, design: .rounded),
                foregroundColor: LopanColors.textPrimary
            )

        case .currency(let code):
            EnhancedAnimatedCurrency(
                value: value,
                currencyCode: code,
                font: .system(size: 28, weight: .bold, design: .rounded),
                foregroundColor: LopanColors.textPrimary
            )

        case .percentage(let places):
            EnhancedAnimatedPercentage(
                value: value / 100,
                decimalPlaces: places,
                font: .system(size: 28, weight: .bold, design: .rounded),
                foregroundColor: LopanColors.textPrimary
            )
        }
    }
}

// MARK: - Preview

#Preview("Animated Numbers") {
    struct PreviewWrapper: View {
        @State private var value: Double = 1234.56
        @State private var intValue: Int = 42
        @State private var percentage: Double = 67.8

        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Animated Numbers")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(spacing: 16) {
                        EnhancedAnimatedNumber(value: value)

                        EnhancedAnimatedInteger(
                            value: intValue,
                            suffix: " items"
                        )

                        EnhancedAnimatedCurrency(value: value)

                        EnhancedAnimatedPercentage(value: percentage / 100)
                    }

                    Button("Randomize Values") {
                        value = Double.random(in: 100...9999)
                        intValue = Int.random(in: 10...999)
                        percentage = Double.random(in: 0...100)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Animated Stat Cards") {
    struct StatsPreview: View {
        @State private var totalOrders: Double = 1234
        @State private var revenue: Double = 56789.50
        @State private var completion: Double = 87.5

        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    AnimatedStatCard(
                        title: "Total Orders",
                        value: totalOrders,
                        format: .integer,
                        trend: .up(value: 12.5),
                        icon: "cart.fill"
                    )

                    AnimatedStatCard(
                        title: "Revenue",
                        value: revenue,
                        format: .currency(code: "CNY"),
                        trend: .up(value: 8.3),
                        icon: "yensign.circle.fill"
                    )

                    AnimatedStatCard(
                        title: "Completion Rate",
                        value: completion,
                        format: .percentage(places: 1),
                        trend: .down(value: -2.1),
                        icon: "checkmark.circle.fill"
                    )

                    Button("Update Values") {
                        totalOrders = Double.random(in: 1000...2000)
                        revenue = Double.random(in: 50000...100000)
                        completion = Double.random(in: 70...95)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    return StatsPreview()
}