//
//  PermissionAwareComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import SwiftData

// MARK: - Permission-Aware UI Components (权限感知UI组件)

/// Button that shows/hides based on user permissions
/// 根据用户权限显示/隐藏的按钮
struct PermissionAwareButton: View {
    let permission: Permission
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case plain
    }
    
    init(_ title: String, permission: Permission, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.permission = permission
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Group {
            if isLoading {
                Button(title) { }
                    .disabled(true)
                    .opacity(0.5)
            } else if hasPermission {
                getButtonStyle()
            } else {
                EmptyView()
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    @ViewBuilder
    private func getButtonStyle() -> some View {
        switch style {
        case .primary:
            Button(title, action: action).buttonStyle(.borderedProminent)
        case .secondary:
            Button(title, action: action).buttonStyle(.bordered)
        case .destructive:
            Button(title, action: action).buttonStyle(.bordered)
        case .plain:
            Button(title, action: action).buttonStyle(.plain)
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

/// View that conditionally shows content based on permissions
/// 根据权限有条件显示内容的视图
struct PermissionGuarded<Content: View>: View {
    let permission: Permission
    let content: Content
    let fallback: AnyView?
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    init(permission: Permission, @ViewBuilder content: () -> Content, fallback: (() -> AnyView)? = nil) {
        self.permission = permission
        self.content = content()
        self.fallback = fallback?()
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if hasPermission {
                content
            } else if let fallback = fallback {
                fallback
            } else {
                EmptyView()
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

/// Navigation link that respects permissions
/// 尊重权限的导航链接
struct PermissionAwareNavigationLink<Destination: View>: View {
    let permission: Permission
    let title: String
    let destination: Destination
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    init(_ title: String, permission: Permission, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.permission = permission
        self.destination = destination()
    }
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    Text(title)
                        .foregroundColor(.secondary)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            } else if hasPermission {
                NavigationLink(title, destination: destination)
            } else {
                HStack {
                    Text(title)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "lock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

/// Menu item that respects permissions
/// 尊重权限的菜单项
struct PermissionAwareMenuItem: View {
    let permission: Permission
    let title: String
    let icon: String?
    let action: () -> Void
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    init(_ title: String, permission: Permission, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.permission = permission
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Group {
            if !isLoading && hasPermission {
                Button(action: action) {
                    if let icon = icon {
                        Label(title, systemImage: icon)
                    } else {
                        Text(title)
                    }
                }
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

/// Tab view item that respects permissions
/// 尊重权限的标签视图项
struct PermissionAwareTab<Content: View>: View {
    let permission: Permission
    let title: String
    let icon: String
    let content: Content
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    init(_ title: String, icon: String, permission: Permission, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.permission = permission
        self.content = content()
    }
    
    var body: some View {
        Group {
            if !isLoading && hasPermission {
                content
                    .tabItem {
                        Label(title, systemImage: icon)
                    }
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

// MARK: - Permission Status Indicators (权限状态指示器)

/// Shows user's current permission level for a specific action
/// 显示用户对特定操作的当前权限级别
struct PermissionStatusIndicator: View {
    let permission: Permission
    let compact: Bool
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var permissionResult: PermissionResult?
    @State private var isLoading = true
    
    init(for permission: Permission, compact: Bool = false) {
        self.permission = permission
        self.compact = compact
    }
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    if !compact {
                        Text("检查权限中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if let result = permissionResult {
                HStack(spacing: 4) {
                    Image(systemName: result.isGranted ? "checkmark.shield" : "xmark.shield")
                        .foregroundColor(result.isGranted ? .green : .red)
                        .font(compact ? .caption : .body)
                    
                    if !compact {
                        Text(result.isGranted ? "有权限" : "无权限")
                            .font(.caption)
                            .foregroundColor(result.isGranted ? .green : .red)
                    }
                }
                .help(result.reason)
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            permissionResult = result
            isLoading = false
        }
    }
}

/// Shows a comprehensive permission summary for the current user
/// 显示当前用户的综合权限摘要
struct UserPermissionSummary: View {
    @Environment(\.appDependencies) private var appDependencies
    @State private var permissionsByCategory: [PermissionCategory: [Permission]] = [:]
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("权限概览")
                .font(.headline)
                .fontWeight(.bold)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载权限信息...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(PermissionCategory.allCases, id: \.self) { category in
                    if let permissions = permissionsByCategory[category], !permissions.isEmpty {
                        PermissionCategoryRow(category: category, permissions: permissions)
                    }
                }
                
                if permissionsByCategory.isEmpty {
                    Text("当前用户没有任何权限")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .task {
            await loadPermissions()
        }
    }
    
    private func loadPermissions() async {
        await MainActor.run {
            permissionsByCategory = appDependencies.serviceFactory.advancedPermissionService.getPermissionsByCategory()
            isLoading = false
        }
    }
}

/// Row showing permissions for a specific category
/// 显示特定类别权限的行
struct PermissionCategoryRow: View {
    let category: PermissionCategory
    let permissions: [Permission]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(permissions.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(permissions, id: \.self) { permission in
                        HStack {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(permission.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - View Modifiers (视图修饰符)

/// View modifier that requires specific permission to display content
/// 需要特定权限才能显示内容的视图修饰符
struct RequirePermissionModifier: ViewModifier {
    let permission: Permission
    let fallback: AnyView?
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    func body(content: Content) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if hasPermission {
                content
            } else if let fallback = fallback {
                fallback
            } else {
                VStack {
                    Image(systemName: "lock")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("权限不足")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

extension View {
    /// Require specific permission to show this view
    /// 需要特定权限才能显示此视图
    func requirePermission(_ permission: Permission, fallback: (() -> AnyView)? = nil) -> some View {
        modifier(RequirePermissionModifier(permission: permission, fallback: fallback?()))
    }
    
    /// Show permission status for this view
    /// 显示此视图的权限状态
    func showPermissionStatus(for permission: Permission, compact: Bool = true) -> some View {
        HStack {
            self
            PermissionStatusIndicator(for: permission, compact: compact)
        }
    }
}

// MARK: - Permission-Aware Form Controls (权限感知表单控件)

/// Text field that can be disabled based on permissions
/// 可根据权限禁用的文本字段
struct PermissionAwareTextField: View {
    let title: String
    let permission: Permission
    @Binding var text: String
    let axis: Axis
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    init(_ title: String, text: Binding<String>, permission: Permission, axis: Axis = .horizontal) {
        self.title = title
        self._text = text
        self.permission = permission
        self.axis = axis
    }
    
    var body: some View {
        TextField(title, text: $text, axis: axis)
            .disabled(isLoading || !hasPermission)
            .opacity((isLoading || !hasPermission) ? 0.6 : 1.0)
            .task {
                await checkPermission()
            }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

/// Picker that can be disabled based on permissions
/// 可根据权限禁用的选择器
struct PermissionAwarePicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    let permission: Permission
    @Binding var selection: SelectionValue
    let content: Content
    
    @Environment(\.appDependencies) private var appDependencies
    @State private var hasPermission = false
    @State private var isLoading = true
    
    init(_ title: String, selection: Binding<SelectionValue>, permission: Permission, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.permission = permission
        self.content = content()
    }
    
    var body: some View {
        Picker(title, selection: $selection) {
            content
        }
        .disabled(isLoading || !hasPermission)
        .opacity((isLoading || !hasPermission) ? 0.6 : 1.0)
        .task {
            await checkPermission()
        }
    }
    
    private func checkPermission() async {
        let result = await appDependencies.serviceFactory.advancedPermissionService.hasPermission(permission)
        await MainActor.run {
            hasPermission = result.isGranted
            isLoading = false
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct PermissionAwareComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PermissionAwareButton("创建批次", permission: .createBatch) {
                print("Create batch")
            }
            
            PermissionStatusIndicator(for: .editBatch)
            
            UserPermissionSummary()
        }
        .padding()
        .environmentObject(ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: ModelContext(try! ModelContainer(for: User.self)))))
    }
}
#endif