//
//  DashboardView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @StateObject private var navigationService = WorkbenchNavigationService()
    
    var body: some View {
        Group {
            if let user = authService.currentUser {
                switch user.primaryRole {
                case .unauthorized:
                    UnauthorizedView(authService: authService)
                case .salesperson:
                    SalespersonDashboardView(authService: authService, navigationService: navigationService)
                        .onAppear { navigationService.setCurrentWorkbenchContext(.salesperson) }
                case .warehouseKeeper:
                    WarehouseKeeperDashboardView(authService: authService, navigationService: navigationService)
                        .onAppear { navigationService.setCurrentWorkbenchContext(.warehouseKeeper) }
                case .workshopManager:
                    WorkshopManagerDashboardView(authService: authService, navigationService: navigationService)
                case .evaGranulationTechnician:
                    EVAGranulationDashboardView(authService: authService, navigationService: navigationService)
                        .onAppear { navigationService.setCurrentWorkbenchContext(.evaGranulationTechnician) }
                case .workshopTechnician:
                    WorkshopTechnicianDashboardView(authService: authService, navigationService: navigationService)
                        .onAppear { navigationService.setCurrentWorkbenchContext(.workshopTechnician) }
                case .administrator:
                    SimplifiedAdministratorDashboardView(authService: authService, navigationService: navigationService)
                        .onAppear { navigationService.setCurrentWorkbenchContext(.administrator) }
                }
            } else {
                LoginView(authService: authService)
            }
        }
        .sheet(isPresented: $navigationService.showingWorkbenchSelector) {
            WorkbenchSelectorView(authService: authService, navigationService: navigationService)
        }
    }
}

struct UnauthorizedView: View {
    @ObservedObject var authService: AuthenticationService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.warning)
                
                Text("unauthorized_access".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("unauthorized_message".localized)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(LopanColors.textSecondary)
                    .padding(.horizontal, 40)
                
                VStack(spacing: 16) {
                    Text("current_user_info".localized)
                        .font(.headline)
                    
                    if let user = authService.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("name".localized)
                                Text(user.name)
                            }
                            HStack {
                                Text("wechat_id".localized)
                                Text(user.wechatId ?? user.phone ?? user.appleUserId ?? "未设置")
                            }
                            HStack {
                                Text("registration_time".localized)
                                Text(user.createdAt, style: .date)
                            }
                        }
                        .font(.subheadline)
                        .padding()
                        .background(LopanColors.secondary.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                Button("logout".localized) {
                    authService.logout()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LopanColors.error)
                .foregroundColor(LopanColors.textPrimary)
                .cornerRadius(10)
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("unauthorized".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SalespersonDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @Environment(\.appDependencies) private var appDependencies
    @State private var customers: [Customer] = []
    @State private var products: [Product] = []
    @State private var isLoading: Bool = false
    @State private var lastRefreshTime: Date? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("salesperson_dashboard".localized)
                    .font(.title)
                    .fontWeight(.bold)
                    
                
                // Enhanced Data Statistics
                dataStatisticsView
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    NavigationLink(destination: CustomerOutOfStockDashboard()) {
                        DashboardCard(
                            title: "customer_out_of_stock_management".localized,
                            subtitle: "customer_out_of_stock_management_subtitle".localized,
                            icon: "exclamationmark.triangle",
                            color: LopanColors.roleWarehouseKeeper
                        )
                    }
                    
                    NavigationLink(destination: GiveBackManagementView()) {
                        DashboardCard(
                            title: "return_goods_management".localized,
                            subtitle: "return_goods_management_subtitle".localized,
                            icon: "arrow.uturn.left",
                            color: LopanColors.error
                        )
                    }
                    
                    NavigationLink(destination: CustomerManagementView()) {
                        DashboardCard(
                            title: "customer_management".localized,
                            subtitle: "customer_management_subtitle".localized,
                            icon: "person.2",
                            color: LopanColors.roleSalesperson
                        )
                    }
                    
                    NavigationLink(destination: ProductManagementView()) {
                        DashboardCard(
                            title: "product_management".localized,
                            subtitle: "product_management_subtitle".localized,
                            icon: "cube.box",
                            color: LopanColors.roleAdministrator
                        )
                    }
                    
                    NavigationLink(destination: CustomerOutOfStockAnalyticsView()) {
                        DashboardCard(
                            title: "out_of_stock_analytics".localized,
                            subtitle: "out_of_stock_analytics_subtitle".localized,
                            icon: "chart.bar",
                            color: LopanColors.roleWorkshopManager
                        )
                    }
                    
                    NavigationLink(destination: HistoricalBacktrackingView()) {
                        DashboardCard(
                            title: "历史回溯",
                            subtitle: "查看用户操作记录和历史变更",
                            icon: "clock.arrow.circlepath",
                            color: LopanColors.roleWorkshopTechnician
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("salesperson_dashboard".localized)
            .navigationBarTitleDisplayMode(.inline)
            .adaptiveBackground()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("销售员工作台")
            .accessibilityHint("包含数据统计和各类功能入口")
            .onAppear {
                loadDashboardData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigationService.showWorkbenchSelector()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                            Text("工作台操作")
                        }
                        .font(.caption)
                    }
                    .accessibilityLabel("工作台操作")
                    .accessibilityHint("打开工作台选择器，切换到其他角色的工作台")
                }
            }
        }
    }
    
    private func loadDashboardData() {
        Task {
            // Update UI on MainActor
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                // Perform async operations outside MainActor context
                let loadedCustomers = try await appDependencies.repositoryFactory.customerRepository.fetchCustomers()
                let loadedProducts = try await appDependencies.repositoryFactory.productRepository.fetchProducts()
                
                // Update UI on MainActor
                await MainActor.run {
                    self.customers = loadedCustomers
                    self.products = loadedProducts
                    self.lastRefreshTime = Date()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "加载数据失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("Error loading dashboard data: \(error)")
            }
        }
    }
    
    // MARK: - Enhanced Data Statistics View
    private var dataStatisticsView: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在加载数据...")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                } else if let errorMessage = errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(LopanColors.warning)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(LopanColors.error)
                        .multilineTextAlignment(.center)
                } else if let lastRefreshTime = lastRefreshTime {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LopanColors.success)
                    Text("最后更新: \(lastRefreshTime, style: .time)")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                Spacer()
                
                Button(action: loadDashboardData) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新数据")
            }
            
            // Data cards
            if isLoading {
                HStack(spacing: 20) {
                    loadingCard("客户")
                    loadingCard("产品")
                }
            } else {
                HStack(spacing: 20) {
                    StatCard(
                        title: "客户",
                        count: customers.count,
                        color: LopanColors.roleSalesperson
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("客户数量: \(customers.count)")
                    
                    StatCard(
                        title: "产品",
                        count: products.count,
                        color: LopanColors.roleAdministrator
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("产品数量: \(products.count)")
                }
            }
        }
        .padding()
        .background(LopanColors.background)
        .cornerRadius(16)
        .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LopanColors.backgroundTertiary, lineWidth: 1)
        )
    }
    
    // MARK: - Loading Card Helper
    private func loadingCard(_ title: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .frame(height: 32)
            
            Text(title)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LopanColors.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // Test functions removed for production build optimization
}

struct WarehouseKeeperDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    
    var body: some View {
        WarehouseKeeperTabView(
            authService: authService,
            navigationService: navigationService
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    navigationService.showWorkbenchSelector()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                        Text("工作台操作")
                    }
                    .font(.caption)
                }
            }
        }
    }
}

struct WorkshopManagerDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @Environment(\.appDependencies) private var appDependencies
    
    var body: some View {
        NavigationStack {
            WorkshopManagerDashboard(
                repositoryFactory: appDependencies.repositoryFactory,
                authService: authService,
                auditService: appDependencies.auditingService,
                navigationService: navigationService
            )
            .navigationTitle("workshop_manager_dashboard".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigationService.showWorkbenchSelector()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                            Text("工作台操作")
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

struct EVAGranulationDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("eva_granulation_dashboard".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    NavigationLink(destination: EVAGranulationListView()) {
                        DashboardCard(
                            title: "granulation_records".localized,
                            subtitle: "granulation_records_subtitle".localized,
                            icon: "drop.fill",
                            color: LopanColors.roleSalesperson
                        )
                    }
                    
                    NavigationLink(destination: RawMaterialView()) {
                        DashboardCard(
                            title: "raw_material_management".localized,
                            subtitle: "raw_material_management_subtitle".localized,
                            icon: "cube.box",
                            color: LopanColors.roleWarehouseKeeper
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("eva_granulation_dashboard".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigationService.showWorkbenchSelector()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                            Text("工作台操作")
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

struct WorkshopTechnicianDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("workshop_technician_dashboard".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    NavigationLink(destination: WorkshopIssueListView()) {
                        DashboardCard(
                            title: "issue_reports".localized,
                            subtitle: "issue_reports_subtitle".localized,
                            icon: "exclamationmark.triangle",
                            color: LopanColors.error
                        )
                    }
                    
                    NavigationLink(destination: MachineMaintenanceView()) {
                        DashboardCard(
                            title: "machine_maintenance".localized,
                            subtitle: "machine_maintenance_subtitle".localized,
                            icon: "wrench.and.screwdriver",
                            color: LopanColors.roleAdministrator
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("workshop_technician_dashboard".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigationService.showWorkbenchSelector()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                            Text("工作台操作")
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

struct SimplifiedAdministratorDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @Environment(\.appDependencies) private var appDependencies
    
    @State private var navigationPath = NavigationPath()
    
    // Dashboard items defined inline for simplicity
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    // Header section
                    headerView
                    
                    // Dashboard cards
                    LazyVStack(spacing: 12) {
                        ModernDashboardCard(
                            title: "用户管理",
                            subtitle: "管理系统用户、角色和权限设置",
                            icon: "person.2.circle",
                            color: LopanColors.roleSalesperson
                        ) {
                            navigationPath.append("UserManagement")
                        }
                        
                        ModernDashboardCard(
                            title: "批次管理",
                            subtitle: "审核生产配置批次和查看历史记录",
                            icon: "doc.text.magnifyingglass",
                            color: LopanColors.roleWorkshopTechnician
                        ) {
                            navigationPath.append("BatchManagement")
                        }
                        
                        ModernDashboardCard(
                            title: "系统概览",
                            subtitle: "查看系统整体运行状态和统计信息",
                            icon: "chart.bar.doc.horizontal",
                            color: LopanColors.roleWorkshopManager
                        ) {
                            navigationPath.append("SystemOverview")
                        }
                        
                        ModernDashboardCard(
                            title: "生产概览",
                            subtitle: "监控生产线状态和设备运行情况",
                            icon: "gearshape.2.fill",
                            color: LopanColors.roleAdministrator
                        ) {
                            navigationPath.append("ProductionOverview")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(LopanColors.backgroundSecondary)
            .navigationTitle("管理员控制台")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    workbenchButton
                }
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "UserManagement":
                    UserManagementView()
                case "BatchManagement":
                    BatchManagementView(
                        repositoryFactory: appDependencies.repositoryFactory,
                        authService: authService,
                        auditService: appDependencies.auditingService
                    )
                case "SystemOverview":
                    SystemConfigurationView()
                case "ProductionOverview":
                    AnalyticsDashboardView(serviceFactory: appDependencies.serviceFactory)
                default:
                    Text("Unknown destination")
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("欢迎使用管理员控制台")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Text("全面管理系统用户、审核生产批次并监控整体运营状况")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private var workbenchButton: some View {
        Button(action: {
            navigationService.showWorkbenchSelector()
        }) {
            Label("工作台操作", systemImage: "gearshape.arrow.triangle.2.circlepath")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityLabel("切换工作台")
        .accessibilityHint("双击以显示工作台选择器")
    }
    
    // Navigation functions removed - using NavigationLink directly
}

struct DashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                .multilineTextAlignment(.center)
                
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(LopanColors.secondary.opacity(0.1))
        .cornerRadius(12)
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
    DashboardView(authService: AuthenticationService(repositoryFactory: repositoryFactory))
} 