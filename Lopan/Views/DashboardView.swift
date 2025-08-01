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
                    AdministratorDashboardView(authService: authService, navigationService: navigationService)
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
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("unauthorized_access".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("unauthorized_message".localized)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
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
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                Button("logout".localized) {
                    authService.logout()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
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
    @Environment(\.modelContext) private var modelContext
    @Query private var customers: [Customer]
    @Query private var products: [Product]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("salesperson_dashboard".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Database Status
                HStack(spacing: 20) {
                    VStack {
                        Text("\(customers.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("customers".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(products.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("products".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onTapGesture {
                    print("🔍 Database Status Check:")
                    print("   - Customers: \(customers.count)")
                    print("   - Products: \(products.count)")
                    print("   - Model Context: \(modelContext)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    NavigationLink(destination: CustomerOutOfStockListView()) {
                        DashboardCard(
                            title: "customer_out_of_stock_management".localized,
                            subtitle: "customer_out_of_stock_management_subtitle".localized,
                            icon: "exclamationmark.triangle",
                            color: .orange
                        )
                    }
                    
                    NavigationLink(destination: ReturnGoodsManagementView()) {
                        DashboardCard(
                            title: "return_goods_management".localized,
                            subtitle: "return_goods_management_subtitle".localized,
                            icon: "arrow.uturn.left",
                            color: .red
                        )
                    }
                    
                    NavigationLink(destination: CustomerManagementView()) {
                        DashboardCard(
                            title: "customer_management".localized,
                            subtitle: "customer_management_subtitle".localized,
                            icon: "person.2",
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: ProductManagementView()) {
                        DashboardCard(
                            title: "product_management".localized,
                            subtitle: "product_management_subtitle".localized,
                            icon: "cube.box",
                            color: .purple
                        )
                    }
                    
                    NavigationLink(destination: CustomerOutOfStockAnalyticsView()) {
                        DashboardCard(
                            title: "out_of_stock_analytics".localized,
                            subtitle: "out_of_stock_analytics_subtitle".localized,
                            icon: "chart.bar",
                            color: .green
                        )
                    }
                    
                    NavigationLink(destination: HistoricalBacktrackingView()) {
                        DashboardCard(
                            title: "历史回溯",
                            subtitle: "查看用户操作记录和历史变更",
                            icon: "clock.arrow.circlepath",
                            color: .indigo
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("salesperson_dashboard".localized)
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
    
    private func testAddCustomer() {
        let testCustomer = Customer(name: "测试客户", address: "测试地址", phone: "13800000000")
        modelContext.insert(testCustomer)
        
        do {
            try modelContext.save()
            print("✅ Test customer added successfully")
            print("✅ Total customers now: \(customers.count)")
        } catch {
            print("❌ Failed to add test customer: \(error)")
        }
    }
    
    private func testAddProduct() {
        let testProduct = Product(name: "测试产品", colors: ["红色"])
        
        // Add a size to the product
        let size = ProductSize(size: "M", product: testProduct)
        if testProduct.sizes == nil {
            testProduct.sizes = []
        }
        testProduct.sizes?.append(size)
        
        modelContext.insert(testProduct)
        modelContext.insert(size)
        
        do {
            try modelContext.save()
            print("✅ Test product added successfully")
            print("✅ Total products now: \(products.count)")
        } catch {
            print("❌ Failed to add test product: \(error)")
        }
    }
}

struct WarehouseKeeperDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("warehouse_keeper_dashboard".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    NavigationLink(destination: PackagingManagementView()) {
                        DashboardCard(
                            title: "包装管理",
                            subtitle: "管理日常产品包装数量和记录",
                            icon: "cube.box",
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: PackagingReminderView()) {
                        DashboardCard(
                            title: "任务提醒",
                            subtitle: "管理包装任务和截止日期提醒",
                            icon: "bell",
                            color: .red
                        )
                    }
                    
                    NavigationLink(destination: PackagingTeamManagementView()) {
                        DashboardCard(
                            title: "团队管理",
                            subtitle: "管理包装团队和专业分工",
                            icon: "person.2",
                            color: .green
                        )
                    }
                    
                    NavigationLink(destination: PackagingStatisticsView()) {
                        DashboardCard(
                            title: "包装统计",
                            subtitle: "查看包装数据统计和分析",
                            icon: "chart.bar",
                            color: .purple
                        )
                    }
                    
                    NavigationLink(destination: ProductionStyleListView()) {
                        DashboardCard(
                            title: "产品信息",
                            subtitle: "查看产品信息（来自销售部门）",
                            icon: "shirt",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("warehouse_keeper_dashboard".localized)
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

struct WorkshopManagerDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @EnvironmentObject var serviceFactory: ServiceFactory
    
    var body: some View {
        WorkshopManagerDashboard(
            repositoryFactory: serviceFactory.repositoryFactory,
            authService: authService,
            auditService: serviceFactory.auditingService,
            navigationService: navigationService
        )
    }
}

struct EVAGranulationDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    
    var body: some View {
        NavigationView {
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
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: RawMaterialView()) {
                        DashboardCard(
                            title: "raw_material_management".localized,
                            subtitle: "raw_material_management_subtitle".localized,
                            icon: "cube.box",
                            color: .orange
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
        NavigationView {
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
                            color: .red
                        )
                    }
                    
                    NavigationLink(destination: MachineMaintenanceView()) {
                        DashboardCard(
                            title: "machine_maintenance".localized,
                            subtitle: "machine_maintenance_subtitle".localized,
                            icon: "wrench.and.screwdriver",
                            color: .purple
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

struct AdministratorDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @EnvironmentObject var serviceFactory: ServiceFactory
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("administrator_dashboard".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    NavigationLink(destination: UserManagementView()) {
                        DashboardCard(
                            title: "user_management".localized,
                            subtitle: "user_management_subtitle".localized,
                            icon: "person.2",
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: BatchReviewView(
                        repositoryFactory: serviceFactory.repositoryFactory,
                        authService: authService,
                        auditService: serviceFactory.auditingService
                    )) {
                        DashboardCard(
                            title: "批次审核",
                            subtitle: "审核生产配置批次和管理生产计划",
                            icon: "checkmark.seal",
                            color: .indigo
                        )
                    }
                    
                    NavigationLink(destination: SystemOverviewView()) {
                        DashboardCard(
                            title: "system_overview".localized,
                            subtitle: "system_overview_subtitle".localized,
                            icon: "chart.pie",
                            color: .green
                        )
                    }
                    
                    NavigationLink(destination: CustomerOutOfStockListView()) {
                        DashboardCard(
                            title: "out_of_stock_management".localized,
                            subtitle: "out_of_stock_management_subtitle".localized,
                            icon: "exclamationmark.triangle",
                            color: .orange
                        )
                    }
                    
                    NavigationLink(destination: ProductionOverviewView()) {
                        DashboardCard(
                            title: "production_overview".localized,
                            subtitle: "production_overview_subtitle".localized,
                            icon: "gearshape.2",
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("administrator_dashboard".localized)
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
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
    DashboardView(authService: AuthenticationService(repositoryFactory: repositoryFactory))
} 