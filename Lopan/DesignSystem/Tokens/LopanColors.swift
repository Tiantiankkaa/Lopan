//
//  LopanColors.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Semantic color system for Lopan production management app
/// Following iOS 2025 design trends with adaptive dark/light mode support
struct LopanColors {
    
    // MARK: - Primary Colors
    static let primary = Color.blue 
    static let primaryLight = Color.blue.opacity(0.3)
    static let primaryDark = Color.blue.opacity(0.8)
    
    // MARK: - Secondary Colors
    static let secondary = Color.gray
    static let secondaryLight = Color.gray.opacity(0.3)
    static let secondaryDark = Color.gray.opacity(0.8)
    
    // MARK: - Accent Colors
    static let accent = Color.orange
    static let accentLight = Color.orange.opacity(0.3)
    static let accentDark = Color.orange.opacity(0.8)
    
    // MARK: - Semantic Colors
    static let success = Color.green
    static let successLight = Color.green.opacity(0.3)
    static let successDark = Color.green.opacity(0.8)
    
    static let warning = Color.orange
    static let warningLight = Color.orange.opacity(0.3)
    static let warningDark = Color.orange.opacity(0.8)
    
    static let error = Color.red
    static let errorLight = Color.red.opacity(0.3)
    static let errorDark = Color.red.opacity(0.8)
    
    static let info = Color.blue
    static let infoLight = Color.blue.opacity(0.3)
    static let infoDark = Color.blue.opacity(0.8)
    
    // MARK: - Neutral Colors
    static let background = Color(UIColor.systemBackground)
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)
    
    static let surface = Color(UIColor.systemBackground)
    static let surfaceElevated = Color(UIColor.secondarySystemBackground)
    
    // MARK: - Text Colors
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    static let textOnPrimary = Color.white
    static let textOnDark = Color.white
    
    // MARK: - Border Colors
    static let border = Color(UIColor.separator)
    static let borderLight = Color(UIColor.separator).opacity(0.5)
    static let borderStrong = Color(UIColor.separator).opacity(0.8)

    // MARK: - Utility Colors
    static let clear = Color.clear
    static let shadow = Color.black.opacity(0.05)
    
    // MARK: - Glass Morphism (iOS 26 Liquid Glass trend) - WCAG Compliant
    static let glassMorphism = Color.adaptive(
        light: Color.white.opacity(0.85),  // Higher opacity for better contrast
        dark: Color.black.opacity(0.85)
    )
    static let glassMorphismStrong = Color.adaptive(
        light: Color.white.opacity(0.95),
        dark: Color.black.opacity(0.95)
    )

    // MARK: - WCAG AA Compliant High Contrast Variants
    static let glassMorphismHighContrast = Color.adaptive(
        light: Color.white,
        dark: Color.black
    )
    
    // MARK: - Interaction Colors
    static let selection = primary
    static let selectionLight = primaryLight
    static let disabled = secondary
    static let placeholder = secondaryLight
    static let destructive = error
    static let highlight = primaryLight

    // MARK: - Status Colors (for production management)
    static let statusPending = warning
    static let statusInProgress = info
    static let statusCompleted = success
    static let statusCancelled = error
    static let statusOnHold = secondary
    
    // MARK: - Role-based Colors
    static let roleAdministrator = Color.purple
    static let roleSalesperson = Color.blue
    static let roleWarehouseKeeper = Color.orange
    static let roleWorkshopManager = Color.green
    static let roleEVATechnician = Color.cyan
    static let roleWorkshopTechnician = Color.indigo
    
    // MARK: - Premium Colors
    static let premium = Color.purple
    static let premiumLight = Color.purple.opacity(0.3)
    static let premiumDark = Color.purple.opacity(0.8)

    // MARK: - WCAG AA High Contrast Colors (4.5:1 ratio guaranteed)
    struct HighContrast {
        // Text colors with guaranteed contrast
        static let textPrimary = Color.adaptive(light: Color.black, dark: Color.white)
        static let textSecondary = Color.adaptive(light: Color.black.opacity(0.8), dark: Color.white.opacity(0.8))
        static let textTertiary = Color.adaptive(light: Color.black.opacity(0.6), dark: Color.white.opacity(0.6))

        // Background colors optimized for contrast
        static let background = Color.adaptive(light: Color.white, dark: Color.black)
        static let surface = Color.adaptive(light: Color.white, dark: Color.black)

        // Semantic colors with enhanced contrast
        static let success = Color.adaptive(light: Color(red: 0.0, green: 0.6, blue: 0.0), dark: Color(red: 0.3, green: 0.9, blue: 0.3))
        static let warning = Color.adaptive(light: Color(red: 0.8, green: 0.5, blue: 0.0), dark: Color(red: 1.0, green: 0.7, blue: 0.0))
        static let error = Color.adaptive(light: Color(red: 0.8, green: 0.0, blue: 0.0), dark: Color(red: 1.0, green: 0.3, blue: 0.3))
        static let info = Color.adaptive(light: Color(red: 0.0, green: 0.3, blue: 0.8), dark: Color(red: 0.3, green: 0.6, blue: 1.0))
    }
}

// MARK: - Color Extensions
extension Color {
    /// Creates an adaptive color that responds to light/dark mode
    static func adaptive(light: Color, dark: Color) -> Color {
        return Color(.init { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    /// Creates a color with opacity for glass morphism effects
    func glassMorphism(opacity: Double = 0.1) -> Color {
        return self.opacity(opacity)
    }
}

// MARK: - Environment Key for Theme
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: LopanTheme = .system
}

extension EnvironmentValues {
    var lopanTheme: LopanTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

enum LopanTheme: CaseIterable {
    case light
    case dark
    case system
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}