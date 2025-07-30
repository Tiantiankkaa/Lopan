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
    static let primary = Color("BrandPrimary") 
    static let primaryLight = Color("PrimaryLight")
    static let primaryDark = Color("PrimaryDark")
    
    // MARK: - Secondary Colors
    static let secondary = Color("Secondary")
    static let secondaryLight = Color("SecondaryLight")
    static let secondaryDark = Color("SecondaryDark")
    
    // MARK: - Accent Colors
    static let accent = Color("Accent")
    static let accentLight = Color("AccentLight")
    static let accentDark = Color("AccentDark")
    
    // MARK: - Semantic Colors
    static let success = Color("Success")
    static let successLight = Color("SuccessLight")
    static let successDark = Color("SuccessDark")
    
    static let warning = Color("Warning")
    static let warningLight = Color("WarningLight")
    static let warningDark = Color("WarningDark")
    
    static let error = Color("Error")
    static let errorLight = Color("ErrorLight")
    static let errorDark = Color("ErrorDark")
    
    static let info = Color("Info")
    static let infoLight = Color("InfoLight")
    static let infoDark = Color("InfoDark")
    
    // MARK: - Neutral Colors
    static let background = Color("Background")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundTertiary = Color("BackgroundTertiary")
    
    static let surface = Color("Surface")
    static let surfaceElevated = Color("SurfaceElevated")
    
    // MARK: - Text Colors
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    static let textOnPrimary = Color("TextOnPrimary")
    static let textOnDark = Color("TextOnDark")
    
    // MARK: - Border Colors
    static let border = Color("Border")
    static let borderLight = Color("BorderLight")
    static let borderStrong = Color("BorderStrong")
    
    // MARK: - Glass Morphism (iOS 26 Liquid Glass trend)
    static let glassMorphism = Color("GlassMorphism")
    static let glassMorphismStrong = Color("GlassMorphismStrong")
    
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