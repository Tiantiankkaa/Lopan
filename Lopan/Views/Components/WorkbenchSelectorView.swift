//
//  WorkbenchSelectorView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/29.
//

import SwiftUI
import SwiftData

struct WorkbenchSelectorView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("切换工作台")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let currentUser = authService.currentUser {
                    Text("当前用户：\(currentUser.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                let accessibleRoles = authService.currentUser != nil ? navigationService.getAccessibleWorkbenches(for: authService.currentUser!) : []
                
                if accessibleRoles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("暂无可访问的工作台")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("请联系管理员分配相应权限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(accessibleRoles, id: \.self) { role in
                                WorkbenchCard(
                                    role: role,
                                    isCurrentRole: role == authService.currentUser?.primaryRole,
                                    onSelect: {
                                        switchToWorkbench(role)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // 退出登录按钮
                Button("退出登录") {
                    authService.logout()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("工作台选择")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func switchToWorkbench(_ role: UserRole) {
        guard let currentUser = authService.currentUser else { return }
        
        // 检查权限 - 管理员可以访问所有工作台，其他用户必须拥有该角色
        if navigationService.canAccessWorkbench(user: currentUser, targetRole: role) {
            // If switching to original role and user has originalRole, reset to original
            if role == currentUser.originalRole && currentUser.originalRole != nil {
                authService.resetToOriginalRole()
            } else {
                authService.switchToWorkbenchRole(role)
            }
            dismiss()
        }
    }
}

struct WorkbenchCard: View {
    let role: UserRole
    let isCurrentRole: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: iconForRole(role))
                    .font(.system(size: 30))
                    .foregroundColor(colorForRole(role))
                
                Text(role.displayName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if isCurrentRole {
                    Text("当前工作台")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isCurrentRole ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isCurrentRole)
    }
    
    private func iconForRole(_ role: UserRole) -> String {
        switch role {
        case .salesperson:
            return "person.2"
        case .warehouseKeeper:
            return "building.2"
        case .workshopManager:
            return "gearshape.2"
        case .evaGranulationTechnician:
            return "drop.fill"
        case .workshopTechnician:
            return "wrench.and.screwdriver"
        case .administrator:
            return "person.crop.circle.badge.checkmark"
        case .unauthorized:
            return "lock"
        }
    }
    
    private func colorForRole(_ role: UserRole) -> Color {
        switch role {
        case .salesperson:
            return .blue
        case .warehouseKeeper:
            return .orange
        case .workshopManager:
            return .green
        case .evaGranulationTechnician:
            return .cyan
        case .workshopTechnician:
            return .purple
        case .administrator:
            return .red
        case .unauthorized:
            return .gray
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let authService = AuthenticationService(modelContext: container.mainContext)
    let navigationService = WorkbenchNavigationService()
    
    WorkbenchSelectorView(authService: authService, navigationService: navigationService)
}
