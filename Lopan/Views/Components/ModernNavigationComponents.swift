//
//  ModernNavigationComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Modern Navigation Wrapper - Replaced with LopanNavigationService
/// This component has been replaced by LopanUniversalNavigation from LopanNavigationService
/// All new navigation should use the centralized LopanNavigationService pattern

// MARK: - Navigation Button Components

/// Modern navigation button with haptic feedback and accessibility
struct LopanNavigationButton: View {
    let title: String
    let destination: String? // Will be converted to NavigationDestination when available
    let systemImage: String?
    let action: (() -> Void)?
    let style: ButtonStyle

    enum ButtonStyle {
        case plain
        case bordered
        case prominent
    }

    init(
        _ title: String,
        destination: String? = nil,
        systemImage: String? = nil,
        style: ButtonStyle = .plain,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.destination = destination
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: performAction) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .modifier(ButtonStyleModifier(style: style))
        .lopanAccessibility(
            role: .navigation,
            label: title,
            hint: "点击导航到\(title)"
        )
    }

    private func performAction() {
        LopanHapticEngine.shared.perform(.navigationTap)

        // For now, just perform the action - navigation destination handling will be implemented later
        action?()
    }
}

/// Navigation toolbar with consistent styling
struct LopanNavigationToolbar: View {
    let title: String
    let leadingItems: [NavigationToolbarItem]
    let trailingItems: [NavigationToolbarItem]

    init(
        title: String,
        leadingItems: [NavigationToolbarItem] = [],
        trailingItems: [NavigationToolbarItem] = []
    ) {
        self.title = title
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
    }

    var body: some View {
        HStack {
            HStack(spacing: 16) {
                ForEach(leadingItems) { item in
                    navigationToolbarButton(for: item)
                }
            }

            Spacer()

            Text(title)
                .lopanTitleMedium()
                .foregroundColor(LopanColors.textPrimary)
                .lopanAccessibility(
                    role: .navigation,
                    label: "页面标题",
                    value: title
                )

            Spacer()

            HStack(spacing: 16) {
                ForEach(trailingItems) { item in
                    navigationToolbarButton(for: item)
                }
            }
        }
        .padding(.horizontal, LopanSpacing.md)
        .frame(height: 44)
        .background(LopanColors.surface)
    }

    @ViewBuilder
    private func navigationToolbarButton(for item: NavigationToolbarItem) -> some View {
        Button(action: item.action) {
            if let systemImage = item.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
            } else {
                Text(item.title)
                    .lopanBodyMedium()
            }
        }
        .foregroundColor(item.isDestructive ? LopanColors.error : LopanColors.primary)
        .lopanAccessibility(
            role: .button,
            label: item.title,
            hint: item.accessibilityHint
        )
        .lopanMinimumTouchTarget()
        .onTapGesture {
            LopanHapticEngine.shared.perform(.buttonTap)
        }
    }
}

struct NavigationToolbarItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String?
    let isDestructive: Bool
    let accessibilityHint: String
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.accessibilityHint = accessibilityHint ?? "点击\(title)"
        self.action = action
    }
}

// MARK: - Modern Sheet Presentation
struct ModernSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: SheetContent
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> SheetContent) {
        self._isPresented = isPresented
        self.sheetContent = content()
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .sheet(isPresented: $isPresented) {
                    self.sheetContent
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.medium, .large])
                }
        } else {
            content
                .sheet(isPresented: $isPresented) {
                    self.sheetContent
                }
        }
    }
}


// MARK: - Loading State Component
struct LoadingStateView: View {
    let message: String
    let isLoading: Bool
    
    init(_ message: String = "加载中...", isLoading: Bool = true) {
        self.message = message
        self.isLoading = isLoading
    }
    
    var body: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("正在加载: \(message)")
        }
    }
}

// MARK: - Error State Component
struct ErrorStateView: View {
    let title: String
    let message: String?
    let retryAction: (() -> Void)?
    
    init(
        title: String = "出现错误",
        message: String? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(LopanColors.error)
                .accessibilityHidden(true)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let retryAction = retryAction {
                Button(action: {
                    LopanHapticEngine.shared.perform(.buttonTap)
                    retryAction()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                }
                .foregroundColor(LopanColors.info)
                .lopanAccessibility(
                    role: .button,
                    label: "重试",
                    hint: "点击重新加载内容"
                )
                .lopanMinimumTouchTarget()
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message != nil ? "\(title). \(message!)" : title)
    }
}

// MARK: - Empty State Component
struct EmptyStateView: View {
    let title: String
    let message: String?
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String? = nil,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    LopanHapticEngine.shared.perform(.primaryAction)
                    action()
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text(actionTitle)
                    }
                }
                .lopanAccessibility(
                    role: .button,
                    label: actionTitle,
                    hint: "点击执行\(actionTitle)"
                )
                .lopanMinimumTouchTarget()
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message != nil ? "\(title). \(message!)" : title)
    }
}

// MARK: - Search Bar with Accessibility
struct AccessibleSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSearchButtonClicked: (() -> Void)?
    
    init(
        text: Binding<String>,
        placeholder: String = "搜索",
        onSearchButtonClicked: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearchButtonClicked = onSearchButtonClicked
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            // Use .searchable for iOS 15+
            EmptyView()
        } else {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel(placeholder)
                    .onSubmit {
                        onSearchButtonClicked?()
                    }
                
                if !text.isEmpty {
                    Button("清除") {
                        LopanHapticEngine.shared.perform(.buttonTap)
                        text = ""
                    }
                    .foregroundColor(.secondary)
                    .lopanAccessibility(
                        role: .button,
                        label: "清除搜索",
                        hint: "点击清空搜索内容"
                    )
                    .lopanMinimumTouchTarget()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Accessibility-Enhanced Form Field
struct AccessibleFormField<Content: View>: View {
    let label: String
    let isRequired: Bool
    let content: Content
    
    init(
        _ label: String,
        isRequired: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.isRequired = isRequired
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(LopanColors.error)
                        .accessibilityLabel("必填项")
                }
            }
            
            content
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Additional UI Components
// Extensions for adaptiveBackground are in DarkModeComponents.swift

// MARK: - Button Style Modifier
private struct ButtonStyleModifier: ViewModifier {
    let style: LopanNavigationButton.ButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .plain:
            content.buttonStyle(PlainButtonStyle())
        case .bordered:
            content.buttonStyle(BorderedButtonStyle())
        case .prominent:
            content.buttonStyle(BorderedProminentButtonStyle())
        }
    }
}

// MARK: - Modern Sheet Extension
extension View {
    func modernSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(ModernSheet(isPresented: isPresented, content: content))
    }
}
