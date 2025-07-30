//
//  LopanTypography.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Typography system for Lopan production management app
/// Supports Dynamic Type accessibility and consistent text hierarchy
struct LopanTypography {
    
    // MARK: - Display Styles (Large headlines)
    static let displayLarge = Font.system(size: 57, weight: .regular, design: .default)
    static let displayMedium = Font.system(size: 45, weight: .regular, design: .default)
    static let displaySmall = Font.system(size: 36, weight: .regular, design: .default)
    
    // MARK: - Headline Styles
    static let headlineLarge = Font.system(size: 32, weight: .medium, design: .default)
    static let headlineMedium = Font.system(size: 28, weight: .medium, design: .default)
    static let headlineSmall = Font.system(size: 24, weight: .medium, design: .default)
    
    // MARK: - Title Styles
    static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
    static let titleMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let titleSmall = Font.system(size: 14, weight: .semibold, design: .default)
    
    // MARK: - Body Styles
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    // MARK: - Label Styles
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // MARK: - Button Typography
    static let buttonLarge = Font.system(size: 16, weight: .semibold, design: .default)
    static let buttonMedium = Font.system(size: 14, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 12, weight: .semibold, design: .default)
    
    // MARK: - Caption and Supporting Text
    static let caption = Font.system(size: 10, weight: .regular, design: .default)
    static let overline = Font.system(size: 10, weight: .medium, design: .default)
    
    // MARK: - Monospace (for data display)
    static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let codeMedium = Font.system(size: 14, weight: .regular, design: .monospaced)
}

// MARK: - Text Style Extensions
extension View {
    /// Applies display large typography style
    func displayLarge() -> some View {
        self.font(LopanTypography.displayLarge)
    }
    
    /// Applies display medium typography style
    func displayMedium() -> some View {
        self.font(LopanTypography.displayMedium)
    }
    
    /// Applies display small typography style
    func displaySmall() -> some View {
        self.font(LopanTypography.displaySmall)
    }
    
    /// Applies headline large typography style
    func headlineLarge() -> some View {
        self.font(LopanTypography.headlineLarge)
    }
    
    /// Applies headline medium typography style
    func headlineMedium() -> some View {
        self.font(LopanTypography.headlineMedium)
    }
    
    /// Applies headline small typography style
    func headlineSmall() -> some View {
        self.font(LopanTypography.headlineSmall)
    }
    
    /// Applies title large typography style
    func titleLarge() -> some View {
        self.font(LopanTypography.titleLarge)
    }
    
    /// Applies title medium typography style
    func titleMedium() -> some View {
        self.font(LopanTypography.titleMedium)
    }
    
    /// Applies title small typography style
    func titleSmall() -> some View {
        self.font(LopanTypography.titleSmall)
    }
    
    /// Applies body large typography style
    func bodyLarge() -> some View {
        self.font(LopanTypography.bodyLarge)
    }
    
    /// Applies body medium typography style
    func bodyMedium() -> some View {
        self.font(LopanTypography.bodyMedium)
    }
    
    /// Applies body small typography style
    func bodySmall() -> some View {
        self.font(LopanTypography.bodySmall)
    }
    
    /// Applies label large typography style
    func labelLarge() -> some View {
        self.font(LopanTypography.labelLarge)
    }
    
    /// Applies label medium typography style
    func labelMedium() -> some View {
        self.font(LopanTypography.labelMedium)
    }
    
    /// Applies label small typography style
    func labelSmall() -> some View {
        self.font(LopanTypography.labelSmall)
    }
    
    /// Applies button large typography style
    func buttonLarge() -> some View {
        self.font(LopanTypography.buttonLarge)
    }
    
    /// Applies button medium typography style
    func buttonMedium() -> some View {
        self.font(LopanTypography.buttonMedium)
    }
    
    /// Applies button small typography style
    func buttonSmall() -> some View {
        self.font(LopanTypography.buttonSmall)
    }
    
    /// Applies caption typography style
    func caption() -> some View {
        self.font(LopanTypography.caption)
    }
    
    /// Applies overline typography style
    func overline() -> some View {
        self.font(LopanTypography.overline)
    }
}

// MARK: - Text Color Extensions
extension Text {
    /// Sets text color to primary
    func primaryText() -> Text {
        self.foregroundColor(LopanColors.textPrimary)
    }
    
    /// Sets text color to secondary
    func secondaryText() -> Text {
        self.foregroundColor(LopanColors.textSecondary)
    }
    
    /// Sets text color to tertiary
    func tertiaryText() -> Text {
        self.foregroundColor(LopanColors.textTertiary)
    }
    
    /// Sets text color to on primary (for buttons)
    func onPrimaryText() -> Text {
        self.foregroundColor(LopanColors.textOnPrimary)
    }
    
    /// Sets text color to on dark backgrounds
    func onDarkText() -> Text {
        self.foregroundColor(LopanColors.textOnDark)
    }
}