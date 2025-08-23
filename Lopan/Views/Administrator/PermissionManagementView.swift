//
//  PermissionManagementView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import SwiftData

// MARK: - Permission Management Main View (权限管理主视图)

/// Comprehensive permission and role management interface for administrators
/// 管理员的综合权限和角色管理界面
struct PermissionManagementView: View {
    @EnvironmentObject var serviceFactory: ServiceFactory
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    
    @State private var selectedTab: PermissionTab = .roleOverview
    @State private var showingRoleEditor = false
    @State private var showingPermissionEditor = false
    @State private var showingElevationRequests = false
    @State private var selectedRole: UserRole?
    @State private var searchText = ""
    
    enum PermissionTab: String, CaseIterable {
        case roleOverview = "role_overview"
        case permissions = "permissions"
        case assignments = "assignments"
        case elevations = "elevations"
        case audit = "audit"
        
        var displayName: String {
            switch self {
            case .roleOverview: return "角色概览"
            case .permissions: return "权限管理"
            case .assignments: return "角色分配"
            case .elevations: return "权限提升"
            case .audit: return "审计日志"
            }
        }
        
        var icon: String {
            switch self {
            case .roleOverview: return "person.3.sequence"
            case .permissions: return "key"
            case .assignments: return "person.badge.plus"
            case .elevations: return "arrow.up.circle"
            case .audit: return "doc.text.magnifyingglass"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                contentView
            }
            .navigationTitle("权限管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Quick actions menu
                        Menu {
                            Button("创建新角色") {
                                showingRoleEditor = true
                            }
                            
                            Button("批量权限设置") {
                                showingPermissionEditor = true
                            }
                            
                            Button("查看提升请求") {
                                showingElevationRequests = true
                            }
                            
                            Divider()
                            
                            Button("导出权限报告") {
                                exportPermissionReport()
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        
                        // Search
                        if selectedTab == .assignments || selectedTab == .audit {
                            Button(action: { /* Toggle search */ }) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRoleEditor) {
                RoleEditorView(
                    role: selectedRole,
                    permissionService: permissionService,
                    roleManagementService: roleManagementService
                )
            }
            .sheet(isPresented: $showingPermissionEditor) {
                BulkPermissionEditorView(
                    permissionService: permissionService,
                    roleManagementService: roleManagementService
                )
            }
            .sheet(isPresented: $showingElevationRequests) {
                ElevationRequestsView(roleManagementService: roleManagementService)
            }
        }
    }
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(PermissionTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.title3)
                            
                            Text(tab.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                    }
                    .background(
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
            }
            .padding(.horizontal)
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .roleOverview:
            RoleOverviewView(
                permissionService: permissionService,
                roleManagementService: roleManagementService,
                onEditRole: { role in
                    selectedRole = role
                    showingRoleEditor = true
                }
            )
        case .permissions:
            PermissionMatrixView(
                permissionService: permissionService,
                roleManagementService: roleManagementService
            )
        case .assignments:
            RoleAssignmentView(
                roleManagementService: roleManagementService,
                searchText: $searchText
            )
        case .elevations:
            ElevationManagementView(roleManagementService: roleManagementService)
        case .audit:
            PermissionAuditView(
                roleManagementService: roleManagementService,
                searchText: $searchText
            )
        }
    }
    
    private func exportPermissionReport() {
        // Implementation for exporting permission reports
        print("Exporting permission report...")
    }
}

// MARK: - Role Overview View (角色概览视图)

/// Overview of all roles and their basic information
/// 所有角色及其基本信息的概览
struct RoleOverviewView: View {
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    let onEditRole: (UserRole) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                    RoleCard(
                        role: role,
                        permissionService: permissionService,
                        roleManagementService: roleManagementService,
                        onEdit: { onEditRole(role) }
                    )
                }
            }
            .padding()
        }
    }
}

/// Individual role card displaying role information
/// 显示角色信息的单个角色卡片
struct RoleCard: View {
    let role: UserRole
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    let onEdit: () -> Void
    
    private var roleDistribution: [UserRole: Int] {
        roleManagementService.getRoleDistribution()
    }
    
    private var userCount: Int {
        roleDistribution[role] ?? 0
    }
    
    private var permissionCount: Int {
        permissionService.getCurrentUserPermissions().count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("\(userCount) 用户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("编辑", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            // Statistics
            VStack(spacing: 8) {
                HStack {
                    Label("\(permissionCount)", systemImage: "key")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("权限数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label(getRoleLevel(role), systemImage: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text("等级")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick actions
            HStack {
                Button("分配用户") {
                    // Show user assignment dialog
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("查看详情") {
                    // Show role details
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getRoleLevel(_ role: UserRole) -> String {
        switch role {
        case .administrator: return "L4 管理员"
        case .workshopManager: return "L3 主管"
        case .workshopTechnician, .evaGranulationTechnician: return "L2 技术员"
        case .salesperson, .warehouseKeeper: return "L1 操作员"
        case .unauthorized: return "L0 未授权"
        }
    }
}

// MARK: - Permission Matrix View (权限矩阵视图)

/// Matrix view showing permissions across all roles
/// 显示所有角色权限的矩阵视图
struct PermissionMatrixView: View {
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    
    @State private var selectedCategory: PermissionCategory?
    @State private var showingCategoryFilter = false
    
    private var groupedPermissions: [PermissionCategory: [Permission]] {
        var grouped: [PermissionCategory: [Permission]] = [:]
        
        for permission in Permission.allCases {
            let category = permission.category
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(permission)
        }
        
        return grouped
    }
    
    private var filteredPermissions: [Permission] {
        if let category = selectedCategory {
            return groupedPermissions[category] ?? []
        }
        return Permission.allCases
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            categoryFilterBar
            
            // Permission matrix
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    // Header row with roles
                    headerRow
                    
                    // Permission rows
                    ForEach(filteredPermissions, id: \.self) { permission in
                        PermissionRow(
                            permission: permission,
                            permissionService: permissionService,
                            roleManagementService: roleManagementService
                        )
                    }
                }
            }
        }
    }
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(selectedCategory == nil ? "全部 ✓" : "全部") {
                    selectedCategory = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(selectedCategory == nil ? .white : .blue)
                .background(selectedCategory == nil ? Color.blue : Color.clear)
                
                ForEach(PermissionCategory.allCases, id: \.self) { category in
                    Button(selectedCategory == category ? "\(category.displayName) ✓" : category.displayName) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(selectedCategory == category ? .white : .blue)
                    .background(selectedCategory == category ? Color.blue : Color.clear)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Permission name column
            Text("权限")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 150, alignment: .leading)
                .padding(.horizontal, 8)
            
            // Role columns
            ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                Text(role.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
    }
}

/// Individual permission row in the matrix
/// 矩阵中的单个权限行
struct PermissionRow: View {
    let permission: Permission
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    
    var body: some View {
        HStack(spacing: 0) {
            // Permission name
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(permission.category.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 150, alignment: .leading)
            .padding(.horizontal, 8)
            
            // Role permission checkboxes
            ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                PermissionCheckbox(
                    permission: permission,
                    role: role,
                    permissionService: permissionService,
                    roleManagementService: roleManagementService
                )
                .frame(width: 80)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary.opacity(0.3)),
            alignment: .bottom
        )
    }
}

/// Checkbox for individual permission assignment
/// 单个权限分配的复选框
struct PermissionCheckbox: View {
    let permission: Permission
    let role: UserRole
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    
    @State private var hasPermission = false
    @State private var isLoading = false
    
    var body: some View {
        Button(action: togglePermission) {
            Image(systemName: hasPermission ? "checkmark.square.fill" : "square")
                .foregroundColor(hasPermission ? .blue : .gray)
                .font(.title3)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1.0)
        .onAppear {
            checkPermission()
        }
    }
    
    private func checkPermission() {
        // In a real implementation, this would check if the role has the permission
        // For now, we'll use a simple mock
        hasPermission = mockRoleHasPermission(role: role, permission: permission)
    }
    
    private func togglePermission() {
        isLoading = true
        
        Task {
            do {
                if hasPermission {
                    try await permissionService.revokePermissionFromRole(permission, role: role)
                } else {
                    try await permissionService.grantPermissionToRole(permission, role: role)
                }
                
                await MainActor.run {
                    hasPermission.toggle()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Show error message
                }
            }
        }
    }
    
    private func mockRoleHasPermission(role: UserRole, permission: Permission) -> Bool {
        // Mock implementation - in real app, this would check actual permissions
        switch role {
        case .administrator:
            return true
        case .workshopManager:
            return permission.category == .batchManagement || 
                   permission.category == .machineManagement || 
                   permission.category == .productionManagement
        case .workshopTechnician:
            return permission.category == .machineManagement && 
                   [.viewMachine, .operateMachine, .maintainMachine].contains(permission)
        case .salesperson:
            return permission.category == .customerManagement
        case .warehouseKeeper:
            return permission.category == .inventoryManagement
        case .evaGranulationTechnician:
            return permission == .qualityControl || permission == .viewInventory
        case .unauthorized:
            return false
        }
    }
}

// MARK: - Role Assignment View (角色分配视图)

/// View for managing user role assignments
/// 管理用户角色分配的视图
struct RoleAssignmentView: View {
    @ObservedObject var roleManagementService: RoleManagementService
    @Binding var searchText: String
    
    @State private var showingAssignmentDialog = false
    @State private var selectedUserId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // Assignment list
            List {
                ForEach(filteredAssignments, id: \.id) { assignment in
                    RoleAssignmentRow(
                        assignment: assignment,
                        roleManagementService: roleManagementService
                    )
                }
            }
            .listStyle(.plain)
        }
        .sheet(isPresented: $showingAssignmentDialog) {
            RoleAssignmentDialog(
                userId: selectedUserId ?? "",
                roleManagementService: roleManagementService
            )
        }
    }
    
    private var searchBar: some View {
        HStack {
            TextField("搜索用户或角色...", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            Button("分配角色") {
                showingAssignmentDialog = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
    }
    
    private var filteredAssignments: [RoleAssignment] {
        if searchText.isEmpty {
            return roleManagementService.roleAssignments
        }
        return roleManagementService.roleAssignments.filter { assignment in
            assignment.role.displayName.localizedCaseInsensitiveContains(searchText) ||
            assignment.userId.localizedCaseInsensitiveContains(searchText)
        }
    }
}

/// Individual role assignment row
/// 单个角色分配行
struct RoleAssignmentRow: View {
    let assignment: RoleAssignment
    @ObservedObject var roleManagementService: RoleManagementService
    
    @State private var showingRevokeConfirmation = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(assignment.role.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !assignment.isValid {
                        Text("已失效")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                
                Text("用户: \(assignment.userId)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("分配于: \(assignment.assignedAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let expiresAt = assignment.expiresAt {
                        Text("• 过期于: \(expiresAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if !assignment.reason.isEmpty {
                    Text("原因: \(assignment.reason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            VStack {
                if assignment.isValid {
                    Button("撤销") {
                        showingRevokeConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
                
                Button("详情") {
                    // Show assignment details
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "确认撤销角色",
            isPresented: $showingRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("撤销角色", role: .destructive) {
                revokeRole()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要撤销用户 \(assignment.userId) 的 \(assignment.role.displayName) 角色吗？")
        }
    }
    
    private func revokeRole() {
        Task {
            do {
                try await roleManagementService.revokeRole(
                    assignment.role,
                    from: assignment.userId,
                    reason: "管理员撤销"
                )
            } catch {
                // Handle error
                print("Failed to revoke role: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views and Components

/// Role assignment dialog for adding new assignments
/// 添加新分配的角色分配对话框
struct RoleAssignmentDialog: View {
    let userId: String
    @ObservedObject var roleManagementService: RoleManagementService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRole: UserRole = .salesperson
    @State private var expirationDate = Date().addingTimeInterval(365 * 24 * 3600)
    @State private var hasExpiration = false
    @State private var reason = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("角色信息") {
                    Picker("选择角色", selection: $selectedRole) {
                        ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    
                    TextField("分配原因", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("有效期设置") {
                    Toggle("设置过期时间", isOn: $hasExpiration)
                    
                    if hasExpiration {
                        DatePicker("过期时间", selection: $expirationDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("分配角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("分配") {
                        assignRole()
                    }
                    .disabled(reason.isEmpty)
                }
            }
        }
    }
    
    private func assignRole() {
        Task {
            do {
                try await roleManagementService.assignRole(
                    selectedRole,
                    to: userId,
                    expiresAt: hasExpiration ? expirationDate : nil,
                    reason: reason
                )
                dismiss()
            } catch {
                // Handle error
                print("Failed to assign role: \(error)")
            }
        }
    }
}

/// Elevation requests management view
/// 权限提升请求管理视图
struct ElevationRequestsView: View {
    @ObservedObject var roleManagementService: RoleManagementService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(roleManagementService.getPendingElevationRequests(), id: \.id) { request in
                    ElevationRequestRow(
                        request: request,
                        roleManagementService: roleManagementService
                    )
                }
            }
            .navigationTitle("权限提升请求")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// Individual elevation request row
/// 单个权限提升请求行
struct ElevationRequestRow: View {
    let request: RoleElevationRequest
    @ObservedObject var roleManagementService: RoleManagementService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.requesterName)
                    .font(.headline)
                
                Spacer()
                
                Text(request.status.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(request.status.color)
                    .cornerRadius(8)
            }
            
            Text("请求角色: \(request.targetRole.displayName)")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("原因: \(request.requestReason)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("持续时间: \(formatDuration(request.requestedDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if request.status == .pending {
                    HStack {
                        Button("批准") {
                            approveRequest(true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("拒绝") {
                            approveRequest(false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func approveRequest(_ approved: Bool) {
        Task {
            do {
                try await roleManagementService.reviewElevationRequest(
                    request.id,
                    approved: approved,
                    notes: approved ? "管理员批准" : "管理员拒绝"
                )
            } catch {
                print("Failed to review request: \(error)")
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days)天"
        } else {
            return "\(hours)小时"
        }
    }
}

// MARK: - Additional Supporting Views

/// Role editor for creating/modifying roles
/// 创建/修改角色的角色编辑器
struct RoleEditorView: View {
    let role: UserRole?
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("角色编辑器")
                    .font(.title)
                    .padding()
                
                Text("功能开发中...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle(role?.displayName ?? "新建角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// Bulk permission editor
/// 批量权限编辑器
struct BulkPermissionEditorView: View {
    @ObservedObject var permissionService: AdvancedPermissionService
    @ObservedObject var roleManagementService: RoleManagementService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("批量权限编辑器")
                    .font(.title)
                    .padding()
                
                Text("功能开发中...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("批量权限设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// Elevation management view
/// 权限提升管理视图
struct ElevationManagementView: View {
    @ObservedObject var roleManagementService: RoleManagementService
    
    var body: some View {
        VStack {
            Text("权限提升管理")
                .font(.title2)
                .padding()
            
            Text("显示权限提升统计和管理...")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

/// Permission audit view
/// 权限审计视图
struct PermissionAuditView: View {
    @ObservedObject var roleManagementService: RoleManagementService
    @Binding var searchText: String
    
    var body: some View {
        VStack {
            Text("权限审计日志")
                .font(.title2)
                .padding()
            
            Text("显示权限变更审计日志...")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct PermissionManagementView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let modelContext = container.mainContext
        
        PermissionManagementView(
            permissionService: AdvancedPermissionService(
                authService: AuthenticationService(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext), serviceFactory: ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext))),
                auditService: NewAuditingService(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext))
            ),
            roleManagementService: RoleManagementService(
                authService: AuthenticationService(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext), serviceFactory: ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext))),
                auditService: NewAuditingService(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext)),
                permissionService: AdvancedPermissionService(
                    authService: AuthenticationService(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext), serviceFactory: ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext))),
                    auditService: NewAuditingService(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext))
                )
            )
        )
        .environmentObject(ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext)))
    }
}
#endif