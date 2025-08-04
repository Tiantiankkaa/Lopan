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
    @StateObject private var sessionService: SessionSecurityService
    @StateObject private var productionBatchService: ProductionBatchService
    @StateObject private var batchOperationCoordinator: BatchOperationCoordinator
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService, navigationService: WorkbenchNavigationService? = nil) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        self.navigationService = navigationService
        
        // Validate user permissions and warn if insufficient
        if let currentUser = authService.currentUser {
            if !currentUser.roles.contains(.workshopManager) && !currentUser.roles.contains(.administrator) {
                print("⚠️ Workshop Manager Dashboard initialized without proper permissions for user: \(currentUser.name)")
            }
        } else {
            print("⚠️ Workshop Manager Dashboard initialized without authenticated user (likely during logout)")
        }
        
        // Initialize shared service instances - always initialize to prevent crashes
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
        
        // Initialize batch processing services
        let sessionSvc = SessionSecurityService(auditingService: auditService)
        self._sessionService = StateObject(wrappedValue: sessionSvc)
        
        let productionBatchSvc = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        self._productionBatchService = StateObject(wrappedValue: productionBatchSvc)
        
        let batchCoordinator = BatchOperationCoordinator(
            batchRepository: repositoryFactory.batchOperationRepository,
            productionBatchService: productionBatchSvc,
            auditingService: auditService,
            sessionService: sessionSvc
        )
        self._batchOperationCoordinator = StateObject(wrappedValue: batchCoordinator)
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
                
                // Batch Processing & Approval
                BatchProcessingDashboardView(
                    repositoryFactory: repositoryFactory,
                    authService: authService,
                    auditService: auditService,
                    coordinator: batchOperationCoordinator,
                    productionBatchService: productionBatchService,
                    sessionService: sessionService
                )
                .tabItem {
                    Image(systemName: "square.stack.3d.down.right")
                    Text("批次处理")
                }
                .tag(4)
                
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
                .tag(5)
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