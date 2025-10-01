//
//  DashboardView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

enum DashboardVisualStyle {
    case premium
    case standard
}

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
                    SalespersonWorkbenchTabView(authService: authService, navigationService: navigationService)
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
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.card))
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
                .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.card))
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("unauthorized".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
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
            .background(Color(UIColor.systemBackground))
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
        VStack(spacing: LopanSpacing.md) {
            // Icon section
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(spacing: LopanSpacing.xs) {
                Text(title)
                    .lopanLabelMedium()
                    .foregroundColor(LopanColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(subtitle)
                    .lopanCaption()
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 140)
        .padding(LopanSpacing.md)
        .background(
            Color(UIColor.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - View Extensions for Modern UI

extension View {
    /// Conditional view modifier for iOS 26 features
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform,
        else elseTransform: ((Self) -> Transform)? = nil
    ) -> some View {
        if condition {
            transform(self)
        } else if let elseTransform = elseTransform {
            elseTransform(self)
        } else {
            self
        }
    }

    /// Press events modifier for interactive feedback
    func pressEvents(onChanged: @escaping (Bool) -> Void) -> some View {
        self.modifier(PressEventsModifier(onChanged: onChanged))
    }
}

private struct PressEventsModifier: ViewModifier {
    let onChanged: (Bool) -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onChanged(true)
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onChanged(false)
                        }
                    }
            )
    }
}

// MARK: - Dashboard Card Button Style

private struct DashboardCardPressedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private extension EnvironmentValues {
    var dashboardCardIsPressed: Bool {
        get { self[DashboardCardPressedKey.self] }
        set { self[DashboardCardPressedKey.self] = newValue }
    }
}

struct DashboardCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.dashboardCardIsPressed, configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Modern Dashboard Card (using existing design system component)

#Preview {
    let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
    DashboardView(authService: AuthenticationService(repositoryFactory: repositoryFactory))
}
