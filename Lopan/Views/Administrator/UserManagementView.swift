//
//  UserManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct UserManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var searchText = ""
    @State private var selectedRole: UserRole? = nil
    
    var filteredUsers: [User] {
        var filtered = users
        
        if !searchText.isEmpty {
            filtered = filtered.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                (user.wechatId?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (user.phone?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (user.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if let role = selectedRole {
            filtered = filtered.filter { $0.roles.contains(role) }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search and Filter
                VStack(spacing: 12) {
                    TextField("搜索用户姓名、账号信息...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "全部", isSelected: selectedRole == nil) {
                                selectedRole = nil
                            }
                            
                            ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                                FilterChip(title: role.displayName, isSelected: selectedRole == role) {
                                    selectedRole = selectedRole == role ? nil : role
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                
                // Users List
                List {
                    ForEach(filteredUsers) { user in
                        UserRowView(user: user, canEditRoles: !user.isAdministrator) { roles, primaryRole in
                            updateUserRoles(user: user, roles: roles, primaryRole: primaryRole)
                        }
                    }
                    .onDelete(perform: deleteUsers)
                }
            }
            .navigationTitle("用户管理")
        }
    }
    
    private func updateUserRoles(user: User, roles: [UserRole], primaryRole: UserRole) {
        user.roles = roles
        user.primaryRole = primaryRole
        try? modelContext.save()
    }
    
    private func deleteUsers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredUsers[index])
            }
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct UserRowView: View {
    let user: User
    let canEditRoles: Bool
    let onRoleChange: ([UserRole], UserRole) -> Void
    
    @State private var showingRolePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(user.name)
                        .font(.headline)
                    Text(user.wechatId ?? user.phone ?? user.appleUserId ?? "未知用户")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if user.isAdministrator {
                        // Administrators have access to all workbenches by default
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("管理员")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                            
                            Text("可访问所有工作台")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else if canEditRoles {
                        // Regular users with editable roles
                        Button(action: { showingRolePicker = true }) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("主要: \(user.primaryRole.displayName)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(primaryRoleColor.opacity(0.2))
                                    .foregroundColor(primaryRoleColor)
                                    .cornerRadius(4)
                                
                                if user.roles.count > 1 {
                                    Text("共\(user.roles.count)个角色")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        // Display-only role information
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("主要: \(user.primaryRole.displayName)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(primaryRoleColor.opacity(0.2))
                                .foregroundColor(primaryRoleColor)
                                .cornerRadius(4)
                            
                            if user.roles.count > 1 {
                                Text("共\(user.roles.count)个角色")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text(user.isActive ? "活跃" : "非活跃")
                        .font(.caption2)
                        .foregroundColor(user.isActive ? .green : .red)
                }
            }
            
            HStack {
                Text("注册时间: \(user.createdAt, style: .date)")
                Spacer()
                if let lastLogin = user.lastLoginAt {
                    Text("最后登录: \(lastLogin, style: .date)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingRolePicker) {
            if canEditRoles && !user.isAdministrator {
                MultiRolePickerView(currentRoles: user.roles, currentPrimaryRole: user.primaryRole) { newRoles, newPrimaryRole in
                    onRoleChange(newRoles, newPrimaryRole)
                    showingRolePicker = false
                }
            }
        }
    }
    
    private var primaryRoleColor: Color {
        switch user.primaryRole {
        case .administrator:
            return .purple
        case .salesperson:
            return .blue
        case .warehouseKeeper:
            return .orange
        case .workshopManager:
            return .green
        case .evaGranulationTechnician:
            return .cyan
        case .workshopTechnician:
            return .red
        case .unauthorized:
            return .gray
        }
    }
}

struct MultiRolePickerView: View {
    let currentRoles: [UserRole]
    let currentPrimaryRole: UserRole
    let onRolesSelected: ([UserRole], UserRole) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRoles: Set<UserRole>
    @State private var primaryRole: UserRole
    
    init(currentRoles: [UserRole], currentPrimaryRole: UserRole, onRolesSelected: @escaping ([UserRole], UserRole) -> Void) {
        self.currentRoles = currentRoles
        self.currentPrimaryRole = currentPrimaryRole
        self.onRolesSelected = onRolesSelected
        self._selectedRoles = State(initialValue: Set(currentRoles))
        self._primaryRole = State(initialValue: currentPrimaryRole)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("选择用户角色") {
                        ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                            HStack {
                                Button(action: { toggleRole(role) }) {
                                    HStack {
                                        Text(role.displayName)
                                        Spacer()
                                        if selectedRoles.contains(role) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    if !selectedRoles.isEmpty {
                        Section("主要角色") {
                            ForEach(Array(selectedRoles).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { role in
                                Button(action: { primaryRole = role }) {
                                    HStack {
                                        Text(role.displayName)
                                        Spacer()
                                        if role == primaryRole {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .navigationTitle("角色管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let rolesArray = Array(selectedRoles)
                        onRolesSelected(rolesArray, primaryRole)
                    }
                    .disabled(selectedRoles.isEmpty || !selectedRoles.contains(primaryRole))
                }
            }
        }
    }
    
    private func toggleRole(_ role: UserRole) {
        if selectedRoles.contains(role) {
            selectedRoles.remove(role)
            if primaryRole == role && !selectedRoles.isEmpty {
                primaryRole = selectedRoles.first!
            }
        } else {
            selectedRoles.insert(role)
            if selectedRoles.count == 1 {
                primaryRole = role
            }
        }
    }
}


struct RoleSelectionView: View {
    @Binding var selectedRoles: Set<UserRole>
    @Binding var primaryRole: UserRole
    let excludeAdministrator: Bool
    
    init(selectedRoles: Binding<Set<UserRole>>, primaryRole: Binding<UserRole>, excludeAdministrator: Bool = false) {
        self._selectedRoles = selectedRoles
        self._primaryRole = primaryRole
        self.excludeAdministrator = excludeAdministrator
    }
    
    var availableRoles: [UserRole] {
        var roles = UserRole.allCases.filter { $0 != .unauthorized }
        if excludeAdministrator {
            roles = roles.filter { $0 != .administrator }
        }
        return roles
    }
    
    var body: some View {
        List {
            Section("选择角色") {
                ForEach(availableRoles, id: \.self) { role in
                    Button(action: { toggleRole(role) }) {
                        HStack {
                            Text(role.displayName)
                            Spacer()
                            if selectedRoles.contains(role) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if !selectedRoles.isEmpty {
                Section("设置主要角色") {
                    ForEach(Array(selectedRoles).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { role in
                        Button(action: { primaryRole = role }) {
                            HStack {
                                Text(role.displayName)
                                Spacer()
                                if role == primaryRole {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("角色选择")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleRole(_ role: UserRole) {
        if selectedRoles.contains(role) {
            selectedRoles.remove(role)
            if primaryRole == role && !selectedRoles.isEmpty {
                primaryRole = selectedRoles.first!
            }
        } else {
            selectedRoles.insert(role)
            if selectedRoles.count == 1 {
                primaryRole = role
            }
        }
    }
}

#Preview {
    UserManagementView()
        .modelContainer(for: User.self, inMemory: true)
} 