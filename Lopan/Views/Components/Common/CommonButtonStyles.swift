//
//  CommonButtonStyles.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Common Circular Button

struct CommonCircularButton: View {
    let icon: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let accessibilityLabel: String
    let accessibilityHint: String?
    let action: () -> Void
    
    init(
        icon: String,
        size: CGFloat = 44, // HIG compliant default
        backgroundColor: Color = .accentColor,
        foregroundColor: Color = .white,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = max(44, size) // Ensure minimum 44pt
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundColor(foregroundColor)
                        .accessibilityHidden(true) // Icon is decorative
                )
        }
        .frame(minWidth: 44, minHeight: 44) // Ensure touch target
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Common Filter Button with Badge

struct CommonFilterButton: View {
    let hasActiveFilters: Bool
    let action: () -> Void
    
    private var accessibilityLabel: String {
        hasActiveFilters ? "筛选条件（已激活）" : "筛选条件"
    }
    
    private var accessibilityHint: String {
        hasActiveFilters ? "打开筛选面板，当前有活跃筛选条件" : "打开筛选面板设置筛选条件"
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(hasActiveFilters ? Color.accentColor : Color(.systemGray5))
                    .frame(width: 44, height: 44) // HIG compliant size
                
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(hasActiveFilters ? .white : .primary)
                    .accessibilityHidden(true)
                
                if hasActiveFilters {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 14, y: -14)
                        .accessibilityHidden(true) // Badge is decorative
                }
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Common Text Button

struct CommonTextButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    init(
        title: String,
        color: Color = .accentColor,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: 44) // HIG compliant touch target height
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Common Icon Button

struct CommonIconButton: View {
    let icon: String
    let color: Color
    let isDisabled: Bool
    let accessibilityLabel: String
    let accessibilityHint: String?
    let action: () -> Void
    
    init(
        icon: String,
        color: Color = .accentColor,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isDisabled ? .secondary : color)
                .frame(minWidth: 44, minHeight: 44) // HIG compliant touch target
                .accessibilityHidden(true) // Icon is decorative
        }
        .disabled(isDisabled)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            CommonCircularButton(
                icon: "plus",
                accessibilityLabel: "添加项目",
                accessibilityHint: "创建新的记录",
                action: {}
            )
            CommonCircularButton(
                icon: "trash",
                backgroundColor: .red,
                accessibilityLabel: "删除",
                accessibilityHint: "删除选中的项目",
                action: {}
            )
            CommonFilterButton(hasActiveFilters: true, action: {})
        }
        
        HStack(spacing: 15) {
            CommonTextButton(title: "取消", color: .orange, action: {})
            CommonIconButton(
                icon: "checkmark.circle",
                accessibilityLabel: "确认",
                accessibilityHint: "确认当前操作",
                action: {}
            )
            CommonIconButton(
                icon: "trash",
                color: .red,
                isDisabled: true,
                accessibilityLabel: "删除（不可用）",
                accessibilityHint: "删除功能当前不可用",
                action: {}
            )
        }
    }
    .padding()
}