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
    
    // Create service instances at dashboard level for sharing
    @StateObject private var machineService: MachineService
    @StateObject private var colorService: ColorService
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService, navigationService: WorkbenchNavigationService? = nil) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        self.navigationService = navigationService
        
        // Initialize shared service instances
        self._machineService = StateObject(wrappedValue: MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
        
        self._colorService = StateObject(wrappedValue: ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
                // Machine Management
                MachineManagementView(
                    machineService: machineService,
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
                    colorService: colorService,
                    authService: authService,
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
        .onAppear {
            // Initialize workbench context when entering workshop manager dashboard
            navigationService?.setCurrentWorkbenchContext(.workshopManager)
        }
        .sheet(isPresented: $showingAddMachine) {
            AddMachineSheet(machineService: machineService)
        }
        .sheet(isPresented: $showingAddColor) {
            AddColorSheet(colorService: colorService)
        }
    }
    
    // MARK: - Helper Methods
    
    private var canManageColors: Bool {
        authService.currentUser?.hasRole(.workshopManager) == true ||
        authService.currentUser?.hasRole(.administrator) == true
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