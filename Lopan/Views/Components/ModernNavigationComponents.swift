//
//  ModernNavigationComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Modern Navigation Wrapper for iOS 16+ compatibility
struct ModernNavigationView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
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
                .foregroundColor(.red)
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
                Button(action: retryAction) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                }
                .foregroundColor(.blue)
                .accessibilityLabel("重试")
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
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text(actionTitle)
                    }
                }
                .accessibilityLabel(actionTitle)
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
                        text = ""
                    }
                    .foregroundColor(.secondary)
                    .accessibilityLabel("清除搜索")
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
                        .foregroundColor(.red)
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

// MARK: - Modern Sheet Extension
extension View {
    func modernSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(ModernSheet(isPresented: isPresented, content: content))
    }
}