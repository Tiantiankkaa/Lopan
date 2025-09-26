//
//  ThemeProvider.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Theme provider for managing app-wide theming and design tokens
/// Supports light/dark mode and custom theme configurations
class ThemeProvider: ObservableObject {
    @Published var currentTheme: LopanTheme = .system
    @Published var preferredColorScheme: ColorScheme?
    
    static let shared = ThemeProvider()
    
    private init() {
        // Load saved theme preference
        if let savedTheme = UserDefaults.standard.object(forKey: "lopan_theme") as? String,
           let theme = LopanTheme(rawValue: savedTheme) {
            currentTheme = theme
            updateColorScheme()
        }
    }
    
    func setTheme(_ theme: LopanTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "lopan_theme")
        updateColorScheme()
    }
    
    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            preferredColorScheme = .light
        case .dark:
            preferredColorScheme = .dark
        case .system:
            preferredColorScheme = nil
        }
    }
}

// MARK: - Theme Extension
extension LopanTheme: RawRepresentable {
    var rawValue: String {
        switch self {
        case .light: return "light"
        case .dark: return "dark"
        case .system: return "system"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "light": self = .light
        case "dark": self = .dark
        case "system": self = .system
        default: return nil
        }
    }
}

// MARK: - Theme Environment Modifier
struct LopanThemeModifier: ViewModifier {
    @StateObject private var themeProvider = ThemeProvider.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.lopanTheme, themeProvider.currentTheme)
            .preferredColorScheme(themeProvider.preferredColorScheme)
            .environmentObject(themeProvider)
    }
}

extension View {
    /// Applies Lopan theme configuration to the view hierarchy
    func lopanTheme() -> some View {
        self.modifier(LopanThemeModifier())
    }
}

// MARK: - Theme Settings View
struct ThemeSettingsView: View {
    @EnvironmentObject private var themeProvider: ThemeProvider
    
    var body: some View {
        LopanCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: LopanSpacing.md) {
                Text("主题设置")
                    .font(LopanTypography.titleMedium)
                    .foregroundColor(LopanColors.textPrimary)
                
                VStack(spacing: LopanSpacing.sm) {
                    ForEach(LopanTheme.allCases, id: \.self) { theme in
                        ThemeOptionRow(
                            theme: theme,
                            isSelected: themeProvider.currentTheme == theme
                        ) {
                            themeProvider.setTheme(theme)
                        }
                    }
                }
            }
        }
    }
}

struct ThemeOptionRow: View {
    let theme: LopanTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            LopanHapticEngine.shared.light()
            onTap()
        }) {
            HStack {
                Image(systemName: theme.icon)
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                    .frame(width: 24)
                
                Text(theme.displayName)
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(LopanColors.textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(LopanColors.primary)
                }
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                    .fill(isSelected ? LopanColors.primaryLight : LopanColors.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Theme Icon Extension
extension LopanTheme {
    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }
}