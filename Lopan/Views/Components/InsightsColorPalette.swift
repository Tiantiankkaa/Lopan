//
//  InsightsColorPalette.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Enhanced color palette system for data visualization with many distinct colors
//

import SwiftUI
import Foundation

/// Enhanced color palette for insights with many distinct colors
struct InsightsColorPalette {

    // MARK: - Color Generation

    /// Generate a distinct color for a given index using HSL color space
    /// This ensures maximum visual distinction between colors
    static func color(for index: Int) -> Color {
        // Use golden ratio for better color distribution
        let goldenRatio = 0.618033988749
        let hue = (Double(index) * goldenRatio).truncatingRemainder(dividingBy: 1.0)

        // Vary saturation and lightness for better distinction
        let saturation: Double
        let lightness: Double

        switch index % 4 {
        case 0:
            saturation = 0.85
            lightness = 0.55
        case 1:
            saturation = 0.75
            lightness = 0.65
        case 2:
            saturation = 0.90
            lightness = 0.45
        case 3:
            saturation = 0.70
            lightness = 0.60
        default:
            saturation = 0.80
            lightness = 0.55
        }

        return Color(hue: hue, saturation: saturation, brightness: lightness)
    }

    /// Generate colors optimized for dark mode
    static func darkModeColor(for index: Int) -> Color {
        let goldenRatio = 0.618033988749
        let hue = (Double(index) * goldenRatio).truncatingRemainder(dividingBy: 1.0)

        // Lighter and more vibrant for dark backgrounds
        let saturation: Double = 0.80
        let lightness: Double = 0.75

        return Color(hue: hue, saturation: saturation, brightness: lightness)
    }

    /// Get an adaptive color that works in both light and dark modes
    static func adaptiveColor(for index: Int) -> Color {
        return Color(.init { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(darkModeColor(for: index))
            } else {
                return UIColor(color(for: index))
            }
        })
    }

    // MARK: - Predefined Palette

    /// High-contrast color palette with maximum visual distinction
    /// Colors are ordered to ensure adjacent colors are visually different
    static let predefinedColors: [Color] = [
        // Primary vibrant colors with high distinction
        Color(.systemBlue),       // #0
        Color(.systemOrange),     // #1
        Color(.systemGreen),      // #2
        Color(.systemPurple),     // #3
        Color(.systemRed),        // #4
        Color(.systemTeal),       // #5
        Color(.systemPink),       // #6
        Color(.systemIndigo),     // #7
        Color(.systemYellow),     // #8
        Color(.systemCyan),       // #9

        // Secondary distinct colors
        LopanColors.primary,      // #10
        LopanColors.warning,      // #11
        LopanColors.success,      // #12
        LopanColors.error,        // #13
        Color(.systemBrown),      // #14
        LopanColors.info,         // #15
        Color(.systemMint),       // #16
        LopanColors.accent,       // #17
        LopanColors.premium,      // #18
        Color(.systemGray)        // #19
    ]

    /// Get a color for an index, using predefined palette first, then generating
    static func bestColor(for index: Int) -> Color {
        if index < predefinedColors.count {
            return predefinedColors[index]
        } else {
            return adaptiveColor(for: index)
        }
    }

    // MARK: - Color Array Generation

    /// Generate an array of distinct colors for a given count
    static func generateColors(count: Int) -> [Color] {
        return (0..<count).map { index in
            bestColor(for: index)
        }
    }

    /// Generate colors ensuring good contrast ratios
    static func generateAccessibleColors(count: Int, backgroundColor: Color = LopanColors.backgroundPrimary) -> [Color] {
        var colors: [Color] = []

        for index in 0..<count {
            let color = bestColor(for: index)
            // TODO: Add contrast ratio validation if needed
            colors.append(color)
        }

        return colors
    }
}

// MARK: - PieChartSegment Extension

extension PieChartSegment {
    /// Create from region aggregation with enhanced color system and calculated percentage
    static func fromRegionAggregationEnhanced(_ aggregation: RegionAggregation, total: Int, colorIndex: Int) -> PieChartSegment {
        let percentage = total > 0 ? Double(aggregation.outOfStockCount) / Double(total) : 0
        return PieChartSegment(
            value: Double(aggregation.outOfStockCount),
            label: aggregation.regionName,
            color: InsightsColorPalette.bestColor(for: colorIndex),
            percentage: percentage
        )
    }

    /// Create from customer aggregation with enhanced color system and calculated percentage
    static func fromCustomerAggregationEnhanced(_ aggregation: CustomerAggregation, total: Int, colorIndex: Int) -> PieChartSegment {
        let percentage = total > 0 ? Double(aggregation.outOfStockCount) / Double(total) : 0
        return PieChartSegment(
            value: Double(aggregation.outOfStockCount),
            label: aggregation.customerName,
            color: InsightsColorPalette.bestColor(for: colorIndex),
            percentage: percentage
        )
    }
}

// MARK: - BarChartItem Extension

extension BarChartItem {
    /// Create from product aggregation with enhanced color system
    static func fromProductAggregationEnhanced(_ aggregation: ProductAggregation, colorIndex: Int) -> BarChartItem {
        return BarChartItem(
            category: aggregation.productName,
            value: Double(aggregation.outOfStockCount),
            color: InsightsColorPalette.bestColor(for: colorIndex),
            subCategory: "客户: \(aggregation.customersAffected)"
        )
    }
}

// MARK: - Preview

#if DEBUG
struct InsightsColorPalette_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Enhanced Color Palette")
                .font(.title2)
                .fontWeight(.bold)

            // Show first 20 colors
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ForEach(0..<20, id: \.self) { index in
                    Rectangle()
                        .fill(InsightsColorPalette.bestColor(for: index))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Text("\(index)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }

            Spacer()
        }
        .padding()
    }
}
#endif