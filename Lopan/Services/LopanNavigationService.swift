//
//  LopanNavigationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI

/// Centralized navigation service for Lopan production management app
/// Provides modern NavigationStack patterns with backward compatibility and type-safe navigation
@available(iOS 16.0, *)
public final class LopanNavigationService: ObservableObject {

    // MARK: - Navigation Path Management

    @Published public var path = NavigationPath()
    @Published public var currentTab: MainTab = .dashboard

    // MARK: - Navigation State

    @Published public var isPresentingModal: Bool = false
    @Published public var modalContent: AnyView?
    @Published public var alertContent: AlertContent?

    // MARK: - Singleton Instance

    public static let shared = LopanNavigationService()

    private init() {}

    // MARK: - Navigation Actions

    /// Navigate to a specific destination
    public func navigate(to destination: NavigationDestination) {
        path.append(destination)

        // Perform haptic feedback for navigation
        LopanHapticEngine.shared.perform(.navigationTap)

        // Announce navigation for accessibility
        announceNavigation(to: destination)
    }

    /// Navigate back one step
    public func navigateBack() {
        guard !path.isEmpty else { return }
        path.removeLast()

        LopanHapticEngine.shared.perform(.backNavigation)
        LopanAccessibilityAnnouncer.announce("已返回上一页面")
    }

    /// Navigate to root
    public func navigateToRoot() {
        path = NavigationPath()

        LopanHapticEngine.shared.perform(.backNavigation)
        LopanAccessibilityAnnouncer.announce("已返回主页面")
    }

    /// Navigate to a specific tab
    public func navigateToTab(_ tab: MainTab) {
        currentTab = tab
        path = NavigationPath() // Clear navigation stack when switching tabs

        LopanHapticEngine.shared.perform(.tabSwitch)
        LopanAccessibilityAnnouncer.announce("已切换到\(tab.title)")
    }

    /// Present a modal view
    public func presentModal<Content: View>(_ content: Content) {
        modalContent = AnyView(content)
        isPresentingModal = true

        LopanHapticEngine.shared.perform(.modalPresent)
    }

    /// Dismiss the current modal
    public func dismissModal() {
        isPresentingModal = false
        modalContent = nil

        LopanHapticEngine.shared.perform(.modalDismiss)
    }

    /// Show an alert
    public func showAlert(
        title: String,
        message: String,
        primaryButton: AlertButton? = nil,
        secondaryButton: AlertButton? = nil
    ) {
        alertContent = AlertContent(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )

        LopanHapticEngine.shared.perform(.alert)
    }

    /// Dismiss the current alert
    public func dismissAlert() {
        alertContent = nil
    }

    // MARK: - Accessibility Support

    private func announceNavigation(to destination: NavigationDestination) {
        let title = destination.accessibilityTitle
        LopanAccessibilityAnnouncer.announce("正在导航到\(title)")
    }

    // MARK: - Deep Link Support

    /// Handle deep link navigation
    public func handleDeepLink(_ url: URL) {
        // Parse URL and navigate accordingly
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              scheme == "lopan" else { return }

        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }

        switch pathComponents.first {
        case "customer":
            if pathComponents.count > 1 {
                let customerID = pathComponents[1]
                navigate(to: .customerDetail(customerID))
            } else {
                navigateToTab(.customers)
            }
        case "batch":
            if pathComponents.count > 1 {
                let batchID = pathComponents[1]
                navigate(to: .batchDetail(batchID))
            } else {
                navigateToTab(.production)
            }
        case "settings":
            navigate(to: .settings)
        default:
            navigateToTab(.dashboard)
        }
    }
}

// MARK: - Navigation Destinations

public enum NavigationDestination: Hashable, Identifiable {
    // Customer Management
    case customerList
    case customerDetail(String)
    case customerCreate
    case customerEdit(String)

    // Product Management
    case productList
    case productDetail(String)
    case productCreate
    case productEdit(String)

    // Batch Management
    case batchList
    case batchDetail(String)
    case batchCreate
    case batchEdit(String)

    // Reports and Analytics
    case analytics
    case reports
    case exportData

    // Settings and Configuration
    case settings
    case userProfile
    case systemConfig
    case about

    // Authentication
    case login
    case register
    case forgotPassword

    public var id: String {
        switch self {
        case .customerList: return "customerList"
        case .customerDetail(let id): return "customerDetail-\(id)"
        case .customerCreate: return "customerCreate"
        case .customerEdit(let id): return "customerEdit-\(id)"
        case .productList: return "productList"
        case .productDetail(let id): return "productDetail-\(id)"
        case .productCreate: return "productCreate"
        case .productEdit(let id): return "productEdit-\(id)"
        case .batchList: return "batchList"
        case .batchDetail(let id): return "batchDetail-\(id)"
        case .batchCreate: return "batchCreate"
        case .batchEdit(let id): return "batchEdit-\(id)"
        case .analytics: return "analytics"
        case .reports: return "reports"
        case .exportData: return "exportData"
        case .settings: return "settings"
        case .userProfile: return "userProfile"
        case .systemConfig: return "systemConfig"
        case .about: return "about"
        case .login: return "login"
        case .register: return "register"
        case .forgotPassword: return "forgotPassword"
        }
    }

    public var accessibilityTitle: String {
        switch self {
        case .customerList: return "客户列表"
        case .customerDetail: return "客户详情"
        case .customerCreate: return "新建客户"
        case .customerEdit: return "编辑客户"
        case .productList: return "产品列表"
        case .productDetail: return "产品详情"
        case .productCreate: return "新建产品"
        case .productEdit: return "编辑产品"
        case .batchList: return "批次列表"
        case .batchDetail: return "批次详情"
        case .batchCreate: return "新建批次"
        case .batchEdit: return "编辑批次"
        case .analytics: return "数据分析"
        case .reports: return "报表"
        case .exportData: return "数据导出"
        case .settings: return "设置"
        case .userProfile: return "用户资料"
        case .systemConfig: return "系统配置"
        case .about: return "关于"
        case .login: return "登录"
        case .register: return "注册"
        case .forgotPassword: return "忘记密码"
        }
    }
}

// MARK: - Main Tabs

public enum MainTab: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case customers = "customers"
    case products = "products"
    case production = "production"
    case reports = "reports"
    case settings = "settings"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "概览"
        case .customers: return "客户"
        case .products: return "产品"
        case .production: return "生产"
        case .reports: return "报表"
        case .settings: return "设置"
        }
    }

    public var iconName: String {
        switch self {
        case .dashboard: return "house"
        case .customers: return "person.2"
        case .products: return "cube.box"
        case .production: return "gear"
        case .reports: return "chart.bar"
        case .settings: return "gearshape"
        }
    }

    public var selectedIconName: String {
        switch self {
        case .dashboard: return "house.fill"
        case .customers: return "person.2.fill"
        case .products: return "cube.box.fill"
        case .production: return "gear"
        case .reports: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Alert Support

public struct AlertContent: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let primaryButton: AlertButton?
    public let secondaryButton: AlertButton?
}

public struct AlertButton {
    public let title: String
    public let action: () -> Void
    public let style: ButtonStyle

    public enum ButtonStyle {
        case `default`
        case cancel
        case destructive
    }

    public init(title: String, style: ButtonStyle = .default, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
}

// MARK: - SwiftUI Integration

/// Main navigation wrapper for iOS 16+
@available(iOS 16.0, *)
public struct LopanNavigationStack<Content: View>: View {
    @StateObject private var navigationService = LopanNavigationService.shared
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        NavigationStack(path: $navigationService.path) {
            content
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environmentObject(navigationService)
        .sheet(isPresented: $navigationService.isPresentingModal) {
            if let modalContent = navigationService.modalContent {
                modalContent
                    .environmentObject(navigationService)
            }
        }
        .alert(
            navigationService.alertContent?.title ?? "",
            isPresented: .init(
                get: { navigationService.alertContent != nil },
                set: { _ in navigationService.dismissAlert() }
            )
        ) {
            alertButtons()
        } message: {
            if let message = navigationService.alertContent?.message {
                Text(message)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .customerList:
            Text("Customer List View") // Replace with actual view
        case .customerDetail(let id):
            Text("Customer Detail: \(id)") // Replace with actual view
        case .customerCreate:
            Text("Create Customer") // Replace with actual view
        case .customerEdit(let id):
            Text("Edit Customer: \(id)") // Replace with actual view
        case .productList:
            Text("Product List View") // Replace with actual view
        case .productDetail(let id):
            Text("Product Detail: \(id)") // Replace with actual view
        case .productCreate:
            Text("Create Product") // Replace with actual view
        case .productEdit(let id):
            Text("Edit Product: \(id)") // Replace with actual view
        case .batchList:
            Text("Batch List View") // Replace with actual view
        case .batchDetail(let id):
            Text("Batch Detail: \(id)") // Replace with actual view
        case .batchCreate:
            Text("Create Batch") // Replace with actual view
        case .batchEdit(let id):
            Text("Edit Batch: \(id)") // Replace with actual view
        case .analytics:
            Text("Analytics View") // Replace with actual view
        case .reports:
            Text("Reports View") // Replace with actual view
        case .exportData:
            Text("Export Data View") // Replace with actual view
        case .settings:
            Text("Settings View") // Replace with actual view
        case .userProfile:
            Text("User Profile View") // Replace with actual view
        case .systemConfig:
            Text("System Config View") // Replace with actual view
        case .about:
            Text("About View") // Replace with actual view
        case .login:
            Text("Login View") // Replace with actual view
        case .register:
            Text("Register View") // Replace with actual view
        case .forgotPassword:
            Text("Forgot Password View") // Replace with actual view
        }
    }

    @ViewBuilder
    private func alertButtons() -> some View {
        if let alertContent = navigationService.alertContent {
            if let primaryButton = alertContent.primaryButton {
                Button(primaryButton.title, action: primaryButton.action)
            }

            if let secondaryButton = alertContent.secondaryButton {
                Button(secondaryButton.title, action: secondaryButton.action)
            }
        }
    }
}

// MARK: - Legacy Navigation Support

/// Fallback navigation wrapper for iOS < 16
@available(iOS, introduced: 14.0, deprecated: 17.0, message: "Legacy NavigationView removed - iOS 17+ uses NavigationStack exclusively")
public struct LegacyNavigationView<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // iOS 17+ - Use NavigationStack instead of legacy NavigationView
        NavigationStack {
            content
        }
    }
}

// MARK: - Universal Navigation Wrapper

/// Universal navigation wrapper that chooses the appropriate implementation
public struct LopanUniversalNavigation<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // iOS 17+ only - NavigationStack is now the standard
        LopanNavigationStack {
            content
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Navigate to a destination using the navigation service
    public func navigate(to destination: NavigationDestination) {
        if #available(iOS 16.0, *) {
            LopanNavigationService.shared.navigate(to: destination)
        }
    }

    /// Navigate back using the navigation service
    public func navigateBack() {
        if #available(iOS 16.0, *) {
            LopanNavigationService.shared.navigateBack()
        }
    }

    /// Present a modal using the navigation service
    public func presentModal<Content: View>(_ content: Content) {
        if #available(iOS 16.0, *) {
            LopanNavigationService.shared.presentModal(content)
        }
    }
}

// MARK: - Environment Values

private struct NavigationServiceKey: EnvironmentKey {
    @available(iOS 16.0, *)
    static let defaultValue = LopanNavigationService.shared
}

extension EnvironmentValues {
    @available(iOS 16.0, *)
    public var navigationService: LopanNavigationService {
        get { self[NavigationServiceKey.self] }
        set { self[NavigationServiceKey.self] = newValue }
    }
}