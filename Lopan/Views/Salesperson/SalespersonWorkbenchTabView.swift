//
//  SalespersonWorkbenchTabView.swift
//  Lopan
//
//  Created by Codex on 2025/10/05.
//

import SwiftUI

// MARK: - Tab Definition

private enum SalespersonTab: String, CaseIterable, Identifiable {
    case overview
    case stockouts
    case returns
    case customers

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .overview:
            return "salesperson_tab_overview".localizedKey
        case .stockouts:
            return "salesperson_tab_stockouts".localizedKey
        case .returns:
            return "salesperson_tab_returns".localizedKey
        case .customers:
            return "salesperson_tab_customers".localizedKey
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.grid.2x2"
        case .stockouts:
            return "exclamationmark.bubble"
        case .returns:
            return "arrow.uturn.backward.circle"
        case .customers:
            return "person.2"
        }
    }
}

// MARK: - Main View

struct SalespersonWorkbenchTabView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService

    @AppStorage("salesperson.selectedTab") private var storedTabValue: String = SalespersonTab.overview.rawValue
    @State private var selectedTab: SalespersonTab = .overview

    // Environment
    @Environment(\.enhancedLiquidGlass) private var glassManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $selectedTab) {
            SalespersonDashboardView(authService: authService, navigationService: navigationService)
                .tabItem {
                    Label(SalespersonTab.overview.titleKey, systemImage: SalespersonTab.overview.systemImage)
                }
                .tag(SalespersonTab.overview)

            tabContainer {
                CustomerOutOfStockDashboard()
            }
            .tabItem {
                Label(SalespersonTab.stockouts.titleKey, systemImage: SalespersonTab.stockouts.systemImage)
            }
            .tag(SalespersonTab.stockouts)

            tabContainer {
                DeliveryManagementView()
            }
            .tabItem {
                Label(SalespersonTab.returns.titleKey, systemImage: SalespersonTab.returns.systemImage)
            }
            .tag(SalespersonTab.returns)

            tabContainer {
                CustomerManagementView()
            }
            .tabItem {
                Label(SalespersonTab.customers.titleKey, systemImage: SalespersonTab.customers.systemImage)
            }
            .tag(SalespersonTab.customers)
        }
        .onAppear {
            selectedTab = SalespersonTab(rawValue: storedTabValue) ?? .overview
            configureTabBarAppearance()
        }
        .onChange(of: selectedTab) { _, newValue in
            storedTabValue = newValue.rawValue
        }
    }

    // MARK: - Tab Bar Configuration

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()

        // Configure blur effect for liquid glass
        appearance.configureWithTransparentBackground()

        // Create custom blur effect
        let blurEffect = UIBlurEffect(style: colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        appearance.backgroundEffect = blurEffect

        // Add subtle background color overlay for depth
        let backgroundColor = UIColor(colorScheme == .dark ?
            Color.black.opacity(0.3) : Color.white.opacity(0.5))
        appearance.backgroundColor = backgroundColor

        // Configure shadow for depth perception
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        appearance.shadowImage = createShadowImage()

        // Apply to all tab bar states
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    private func createShadowImage() -> UIImage? {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.black.withAlphaComponent(0.1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Tab Container Helper

extension SalespersonWorkbenchTabView {

    @ViewBuilder
    private func tabContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { navigationService.showWorkbenchSelector() }) {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("workbench_manage".localized)
                        .accessibilityHint("workbench_manage_hint".localized)
                    }
                }
        }
    }
}
