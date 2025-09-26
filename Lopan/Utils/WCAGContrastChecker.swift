//
//  WCAGContrastChecker.swift
//  Lopan
//
//  WCAG 2.1 contrast ratio checker for iOS 26 compliance
//  Validates all LopanColors combinations against accessibility standards
//

import SwiftUI
import UIKit

/// WCAG 2.1 contrast ratio checker and validator
public struct WCAGContrastChecker {

    // MARK: - WCAG Standards

    /// WCAG 2.1 AA contrast ratios
    public enum ContrastStandard {
        case normalText    // 4.5:1 ratio required
        case largeText     // 3:1 ratio required
        case graphical     // 3:1 ratio required

        var requiredRatio: Double {
            switch self {
            case .normalText: return 4.5
            case .largeText, .graphical: return 3.0
            }
        }
    }

    // MARK: - Contrast Calculation

    /// Calculate contrast ratio between two colors
    public static func contrastRatio(foreground: Color, background: Color) -> Double {
        let fgLuminance = relativeLuminance(of: foreground)
        let bgLuminance = relativeLuminance(of: background)

        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Check if color combination meets WCAG standard
    public static func meetsStandard(_ standard: ContrastStandard,
                                   foreground: Color,
                                   background: Color) -> Bool {
        let ratio = contrastRatio(foreground: foreground, background: background)
        return ratio >= standard.requiredRatio
    }

    // MARK: - Luminance Calculation

    private static func relativeLuminance(of color: Color) -> Double {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let sRGBRed = linearizeRGB(red)
        let sRGBGreen = linearizeRGB(green)
        let sRGBBlue = linearizeRGB(blue)

        return 0.2126 * sRGBRed + 0.7152 * sRGBGreen + 0.0722 * sRGBBlue
    }

    private static func linearizeRGB(_ component: CGFloat) -> Double {
        let value = Double(component)
        if value <= 0.03928 {
            return value / 12.92
        } else {
            return pow((value + 0.055) / 1.055, 2.4)
        }
    }
}

// MARK: - LopanColors Audit

extension WCAGContrastChecker {

    /// Comprehensive audit of all LopanColors combinations
    public static func auditLopanColors() -> ContrastAuditResult {
        var results: [ColorCombination] = []

        // Text on background combinations
        let textColors = [
            ("textPrimary", LopanColors.textPrimary),
            ("textSecondary", LopanColors.textSecondary),
            ("textTertiary", LopanColors.textTertiary),
            ("textOnPrimary", LopanColors.textOnPrimary),
            ("textOnDark", LopanColors.textOnDark)
        ]

        let backgroundColors = [
            ("background", LopanColors.background),
            ("backgroundPrimary", LopanColors.backgroundPrimary),
            ("backgroundSecondary", LopanColors.backgroundSecondary),
            ("backgroundTertiary", LopanColors.backgroundTertiary),
            ("surface", LopanColors.surface),
            ("surfaceElevated", LopanColors.surfaceElevated),
            ("primary", LopanColors.primary),
            ("glassMorphism", LopanColors.glassMorphism),
            ("glassMorphismStrong", LopanColors.glassMorphismStrong)
        ]

        // Test all text/background combinations
        for (textName, textColor) in textColors {
            for (bgName, bgColor) in backgroundColors {
                let normalRatio = contrastRatio(foreground: textColor, background: bgColor)
                let meetsNormal = normalRatio >= ContrastStandard.normalText.requiredRatio
                let meetsLarge = normalRatio >= ContrastStandard.largeText.requiredRatio

                results.append(ColorCombination(
                    foregroundName: textName,
                    backgroundName: bgName,
                    ratio: normalRatio,
                    meetsNormalText: meetsNormal,
                    meetsLargeText: meetsLarge
                ))
            }
        }

        // Test semantic color combinations (status, role colors)
        let semanticColors = [
            ("success", LopanColors.success),
            ("warning", LopanColors.warning),
            ("error", LopanColors.error),
            ("info", LopanColors.info)
        ]

        for (colorName, color) in semanticColors {
            for (bgName, bgColor) in backgroundColors {
                let normalRatio = contrastRatio(foreground: color, background: bgColor)
                let meetsNormal = normalRatio >= ContrastStandard.normalText.requiredRatio
                let meetsLarge = normalRatio >= ContrastStandard.largeText.requiredRatio

                results.append(ColorCombination(
                    foregroundName: colorName,
                    backgroundName: bgName,
                    ratio: normalRatio,
                    meetsNormalText: meetsNormal,
                    meetsLargeText: meetsLarge
                ))
            }
        }

        return ContrastAuditResult(combinations: results)
    }

    /// Generate high contrast variants for failed combinations
    public static func generateHighContrastVariants() -> [String: Color] {
        var variants: [String: Color] = [:]

        // High contrast text colors
        variants["textPrimaryHighContrast"] = LopanColors.textPrimary
        variants["textSecondaryHighContrast"] = LopanColors.textPrimary.opacity(0.8)
        variants["textTertiaryHighContrast"] = LopanColors.textPrimary.opacity(0.6)

        // High contrast background colors
        variants["backgroundHighContrast"] = LopanColors.backgroundPrimary
        variants["surfaceHighContrast"] = LopanColors.backgroundPrimary

        // High contrast semantic colors
        variants["successHighContrast"] = LopanColors.success.opacity(0.9)
        variants["warningHighContrast"] = LopanColors.warning.opacity(0.9)
        variants["errorHighContrast"] = LopanColors.error.opacity(0.9)
        variants["infoHighContrast"] = LopanColors.info.opacity(0.9)

        return variants
    }
}

// MARK: - Result Types

public struct ColorCombination {
    let foregroundName: String
    let backgroundName: String
    let ratio: Double
    let meetsNormalText: Bool
    let meetsLargeText: Bool

    var status: String {
        if meetsNormalText { return "✅ PASS" }
        if meetsLargeText { return "⚠️ LARGE TEXT ONLY" }
        return "❌ FAIL"
    }
}

public struct ContrastAuditResult {
    let combinations: [ColorCombination]

    var failedCombinations: [ColorCombination] {
        combinations.filter { !$0.meetsNormalText }
    }

    var passedCombinations: [ColorCombination] {
        combinations.filter { $0.meetsNormalText }
    }

    var summary: String {
        let total = combinations.count
        let passed = passedCombinations.count
        let failed = failedCombinations.count
        let percentage = Int((Double(passed) / Double(total)) * 100)

        return """
        WCAG Contrast Audit Summary:
        Total combinations tested: \(total)
        Passed (≥4.5:1): \(passed) (\(percentage)%)
        Failed (<4.5:1): \(failed)
        """
    }

    func printDetailed() {
        print(summary)
        print("\n=== FAILED COMBINATIONS ===")
        for combo in failedCombinations {
            print("\(combo.foregroundName) on \(combo.backgroundName): \(String(format: "%.2f", combo.ratio)):1 \(combo.status)")
        }
    }
}