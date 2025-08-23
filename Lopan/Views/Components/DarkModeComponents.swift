//
//  DarkModeComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Dark Mode Manager
@MainActor
class DarkModeManager: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    
    private let userDefaults = UserDefaults.standard
    private let colorSchemeKey = "user_color_scheme"
    
    init() {
        loadColorScheme()
    }
    
    private func loadColorScheme() {
        let savedScheme = userDefaults.string(forKey: colorSchemeKey)
        switch savedScheme {
        case "dark":
            colorScheme = .dark
        case "light":
            colorScheme = .light
        default:
            colorScheme = nil // Follow system
        }
    }
    
    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        
        let schemeString: String?
        switch scheme {
        case .dark:
            schemeString = "dark"
        case .light:
            schemeString = "light"
        case .none:
            schemeString = nil
        case .some(_):
            schemeString = nil
        }
        
        if let schemeString = schemeString {
            userDefaults.set(schemeString, forKey: colorSchemeKey)
        } else {
            userDefaults.removeObject(forKey: colorSchemeKey)
        }
    }
}

// MARK: - Dark Mode Colors
struct AdaptiveColors {
    // Background colors
    static let primaryBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
    
    // Text colors
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
    static let quaternaryText = Color(.quaternaryLabel)
    
    // Separator colors
    static let separator = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)
    
    // System colors that adapt
    static let systemBlue = Color(.systemBlue)
    static let systemGreen = Color(.systemGreen)
    static let systemRed = Color(.systemRed)
    static let systemOrange = Color(.systemOrange)
    static let systemYellow = Color(.systemYellow)
    static let systemPurple = Color(.systemPurple)
    static let systemPink = Color(.systemPink)
    static let systemIndigo = Color(.systemIndigo)
    static let systemTeal = Color(.systemTeal)
    
    // Fill colors
    static let fill = Color(.systemFill)
    static let secondaryFill = Color(.secondarySystemFill)
    static let tertiaryFill = Color(.tertiarySystemFill)
    static let quaternaryFill = Color(.quaternarySystemFill)
    
    // Custom status colors that adapt to dark mode
    static func statusColor(for status: OutOfStockStatus) -> Color {
        switch status {
        case .pending:
            return Color(.systemOrange)
        case .completed:
            return Color(.systemGreen)
        case .cancelled:
            return Color(.systemRed)
        }
    }
    
}

// MARK: - Dark Mode Adaptive Card
struct AdaptiveCard<Content: View>: View {
    let content: Content
    let padding: EdgeInsets
    let cornerRadius: CGFloat
    let shadow: Bool
    
    init(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        shadow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AdaptiveColors.secondaryBackground)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow ? AdaptiveColors.separator.opacity(0.3) : .clear,
                radius: shadow ? 4 : 0,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Dark Mode Theme Preview
struct DarkModeThemePreview: View {
    let colorScheme: ColorScheme?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("主题预览")
                    .font(.headline)
                    .foregroundColor(AdaptiveColors.primaryText)
                Spacer()
                Circle()
                    .fill(AdaptiveColors.systemBlue)
                    .frame(width: 12, height: 12)
            }
            
            // Sample content
            AdaptiveCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("示例卡片")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AdaptiveColors.primaryText)
                    
                    Text("这是一个适应暗黑模式的卡片示例")
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.secondaryText)
                    
                    HStack {
                        Badge(text: "待处理", color: AdaptiveColors.statusColor(for: .pending))
                        Spacer()
                    }
                }
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("主要按钮") {}
                    .buttonStyle(.borderedProminent)
                
                Button("次要按钮") {}
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(AdaptiveColors.primaryBackground)
        .preferredColorScheme(colorScheme)
    }
}

// MARK: - Adaptive Badge
struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Dark Mode Settings View
struct DarkModeSettingsView: View {
    @StateObject private var darkModeManager = DarkModeManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ModernNavigationView {
            List {
                Section(header: Text("外观设置")) {
                    ThemeOption(
                        title: "跟随系统",
                        description: "根据系统设置自动切换",
                        isSelected: darkModeManager.colorScheme == nil,
                        onSelect: {
                            darkModeManager.setColorScheme(nil)
                        }
                    )
                    
                    ThemeOption(
                        title: "浅色模式",
                        description: "始终使用浅色主题",
                        isSelected: darkModeManager.colorScheme == .light,
                        onSelect: {
                            darkModeManager.setColorScheme(.light)
                        }
                    )
                    
                    ThemeOption(
                        title: "深色模式",
                        description: "始终使用深色主题",
                        isSelected: darkModeManager.colorScheme == .dark,
                        onSelect: {
                            darkModeManager.setColorScheme(.dark)
                        }
                    )
                }
                
                Section(header: Text("预览")) {
                    DarkModeThemePreview(colorScheme: darkModeManager.colorScheme)
                }
            }
            .navigationTitle("外观设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(darkModeManager.colorScheme)
    }
}

// MARK: - Theme Option Row
struct ThemeOption: View {
    let title: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AdaptiveColors.primaryText)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.secondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AdaptiveColors.systemBlue)
                        .accessibilityLabel("已选中")
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已选中" : "未选中")
        .accessibilityHint("轻点选择\(title)")
    }
}

// MARK: - View Extensions for Dark Mode
extension View {
    func adaptiveForegroundColor() -> some View {
        self.foregroundColor(AdaptiveColors.primaryText)
    }
    
    func adaptiveSecondaryForegroundColor() -> some View {
        self.foregroundColor(AdaptiveColors.secondaryText)
    }
    
    func adaptiveBackground() -> some View {
        self.background(AdaptiveColors.primaryBackground)
    }
    
    func adaptiveSecondaryBackground() -> some View {
        self.background(AdaptiveColors.secondaryBackground)
    }
    
    func adaptiveCardStyle(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        shadow: Bool = true
    ) -> some View {
        self
            .padding(padding)
            .background(AdaptiveColors.secondaryBackground)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow ? AdaptiveColors.separator.opacity(0.3) : .clear,
                radius: shadow ? 4 : 0,
                x: 0,
                y: 2
            )
    }
    
    func statusBadge(for status: OutOfStockStatus) -> some View {
        self
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AdaptiveColors.statusColor(for: status).opacity(0.2))
            .foregroundColor(AdaptiveColors.statusColor(for: status))
            .cornerRadius(4)
    }
    
}

// MARK: - App-wide Dark Mode Support
struct DarkModeEnvironment: ViewModifier {
    @StateObject private var darkModeManager = DarkModeManager()
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(darkModeManager.colorScheme)
            .environmentObject(darkModeManager)
    }
}

extension View {
    func supportsDarkMode() -> some View {
        self.modifier(DarkModeEnvironment())
    }
}