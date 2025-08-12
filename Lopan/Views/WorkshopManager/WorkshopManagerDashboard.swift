//
//  WorkshopManagerDashboard.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct WorkshopManagerDashboard: View {
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    let navigationService: WorkbenchNavigationService?
    
    @State private var selectedTab = 0
    @State private var showingAddMachine = false
    @State private var showingAddColor = false
    
    // Simplified service instances - let each view create its own to avoid dependency cycles
    @State private var servicesInitialized = false
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService, navigationService: WorkbenchNavigationService? = nil) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        self.navigationService = navigationService
    }
    
    var body: some View {
        // Runtime permission check - show error view if no permissions
        if let currentUser = authService.currentUser,
           currentUser.roles.contains(.workshopManager) || currentUser.roles.contains(.administrator) {
            workshopManagerContent
        } else {
            unauthorizedAccessView
        }
    }
    
    private var workshopManagerContent: some View {
        TabView(selection: $selectedTab) {
                // Machine Management
                MachineManagementView(
                    authService: authService,
                    repositoryFactory: repositoryFactory,
                    auditService: auditService,
                    showingAddMachine: $showingAddMachine
                )
                .tabItem {
                    Image(systemName: "gearshape.2")
                    Text("设备管理")
                }
                .tag(0)
                
                // Color Management
                ColorManagementView(
                    authService: authService,
                    repositoryFactory: repositoryFactory,
                    auditService: auditService,
                    showingAddColor: $showingAddColor
                )
                .tabItem {
                    Image(systemName: "paintpalette")
                    Text("颜色管理")
                }
                .tag(1)
                
                // Gun Color Settings
                GunColorSettingsView(
                    repositoryFactory: repositoryFactory,
                    authService: authService,
                    auditService: auditService
                )
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("基础配置")
                }
                .tag(2)
                
                // Production Configuration
                ProductionConfigurationView(
                    repositoryFactory: repositoryFactory,
                    authService: authService,
                    auditService: auditService
                )
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("生产配置")
                }
                .tag(3)
                
                // Batch Processing & Approval (simplified to prevent crashes)
                BatchProcessingPlaceholderView(
                    repositoryFactory: repositoryFactory,
                    authService: authService,
                    auditService: auditService
                )
                .tabItem {
                    Image(systemName: "square.stack.3d.down.right")
                    Text("批次处理")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onAppear {
            // Initialize workbench context when entering workshop manager dashboard
            navigationService?.setCurrentWorkbenchContext(.workshopManager)
        }
        // Sheets are now handled by individual views to avoid service dependency issues
    }
    
    private var unauthorizedAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("访问权限不足")
                .font(.title)
                .fontWeight(.bold)
            
            Text("您没有访问车间管理系统的权限。请联系管理员获取相应权限。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            if authService.currentUser == nil {
                Text("用户未登录或正在登出")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private var canManageColors: Bool {
        authService.currentUser?.hasRole(.workshopManager) == true ||
        authService.currentUser?.hasRole(.administrator) == true
    }
}

// MARK: - Temporary Placeholder View
struct BatchProcessingPlaceholderView: View {
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("批次处理中心")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("批次处理功能正在优化中，即将重新上线")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Text("2025年8月12日")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
struct WorkshopManagerDashboard_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self,
            ColorCard.self, ProductionBatch.self, ProductConfig.self,
            User.self, AuditLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        WorkshopManagerDashboard(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService,
            navigationService: nil
        )
    }
}