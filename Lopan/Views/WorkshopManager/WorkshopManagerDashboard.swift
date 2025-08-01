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
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService, navigationService: WorkbenchNavigationService? = nil) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        self.navigationService = navigationService
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Machine Management
            MachineManagementView(
                repositoryFactory: repositoryFactory,
                authService: authService,
                auditService: auditService
            )
            .tabItem {
                Image(systemName: "gearshape.2")
                Text("设备管理")
            }
            .tag(0)
            
            // Color Management
            ColorManagementView(
                repositoryFactory: repositoryFactory,
                authService: authService,
                auditService: auditService
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
            
            // Batch History
            BatchHistoryView(
                repositoryFactory: repositoryFactory,
                authService: authService,
                auditService: auditService
            )
            .tabItem {
                Image(systemName: "clock.arrow.circlepath")
                Text("批次历史")
            }
            .tag(4)
        }
        .accentColor(.blue)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let navigationService = navigationService {
                    Button(action: {
                        navigationService.showWorkbenchSelector()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("切换工作台")
                        }
                        .font(.caption)
                    }
                }
            }
        }
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