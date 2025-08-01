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
                Text("工作台操作")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let currentUser = authService.currentUser {
                    VStack(spacing: 4) {
                        Text("当前用户：\(currentUser.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let currentContext = navigationService.currentWorkbenchContext {
                            Text("当前工作台：\(currentContext.displayName)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                if let currentUser = authService.currentUser {
                    let categories = navigationService.getWorkbenchCategories(for: currentUser)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // 主工作台部分
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("主工作台")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                WorkbenchCard(
                                    role: categories.primary,
                                    isCurrentRole: categories.current == categories.primary,
                                    onSelect: {
                                        returnToPrimaryWorkbench()
                                    }
                                )
                            }
                            
                            // 授权工作台部分（如果有的话）
                            if categories.hasMultipleAccess {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("授权工作台")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        Text("(\(categories.authorized.count))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        ForEach(categories.authorized, id: \.self) { role in
                                            WorkbenchCard(
                                                role: role,
                                                isCurrentRole: categories.current == role,
                                                onSelect: {
                                                    switchToWorkbench(role)
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // 系统操作部分
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("系统操作")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                VStack(spacing: 8) {
                                    // 退出工作台按钮
                                    Button("退出工作台") {
                                        exitWorkbench()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    
                                    // 完全退出登录按钮
                                    Button("退出登录") {
                                        authService.logout()
                                        dismiss()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("未登录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 20)
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
            // Use the new context-aware method
            authService.switchToWorkbenchWithContext(role, navigationService: navigationService)
            dismiss()
        }
    }
    
    private func returnToPrimaryWorkbench() {
        authService.returnToPrimaryWorkbench(navigationService: navigationService)
        dismiss()
    }
    
    private func exitWorkbench() {
        // Clear workbench context
        navigationService.clearWorkbenchContext()
        
        // Exit workbench session
        authService.exitWorkbench()
        
        // Dismiss the selector - this will return user to login/main screen
        dismiss()
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
    let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
    let authService = AuthenticationService(repositoryFactory: repositoryFactory)
    let navigationService = WorkbenchNavigationService()
    
    WorkbenchSelectorView(authService: authService, navigationService: navigationService)
}
