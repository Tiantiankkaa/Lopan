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
    case addCustomer

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
        case .addCustomer:
            return "添加"
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
        case .addCustomer:
            return "plus"
        }
    }
}

// MARK: - Main View

struct SalespersonWorkbenchTabView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService

    @AppStorage("salesperson.selectedTab") private var storedTabValue: String = SalespersonTab.overview.rawValue
    @State private var selectedTab: SalespersonTab = .overview
    @State private var showingAddCustomer = false

    // Environment
    @Environment(\.enhancedLiquidGlass) private var glassManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appDependencies) private var appDependencies

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Overview
            Tab(value: SalespersonTab.overview) {
                SalespersonDashboardView(authService: authService, navigationService: navigationService)
            } label: {
                Label(SalespersonTab.overview.titleKey, systemImage: SalespersonTab.overview.systemImage)
            }

            // Tab 2: Out of Stock
            Tab(value: SalespersonTab.stockouts) {
                tabContainer {
                    CustomerOutOfStockDashboard()
                }
            } label: {
                Label(SalespersonTab.stockouts.titleKey, systemImage: SalespersonTab.stockouts.systemImage)
            }

            // Tab 3: Returns
            Tab(value: SalespersonTab.returns) {
                tabContainer {
                    DeliveryManagementView()
                }
            } label: {
                Label(SalespersonTab.returns.titleKey, systemImage: SalespersonTab.returns.systemImage)
            }

            // Tab 4: Customers
            Tab(value: SalespersonTab.customers) {
                tabContainer {
                    CustomerManagementView()
                }
            } label: {
                Label(SalespersonTab.customers.titleKey, systemImage: SalespersonTab.customers.systemImage)
            }

            // Tab 5: Add Customer (conditional - only on Customer tab, with search role for spacing)
            if selectedTab == .customers {
                Tab(value: SalespersonTab.addCustomer, role: .search) {
                    Color.clear // Placeholder - triggers sheet via onChange
                } label: {
                    Label(SalespersonTab.addCustomer.titleKey, systemImage: SalespersonTab.addCustomer.systemImage)
                }
            }
        }
        .onAppear {
            selectedTab = SalespersonTab(rawValue: storedTabValue) ?? .overview
            configureTabBarAppearance()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Intercept "Add Customer" tab selection
            if newValue == .addCustomer {
                showingAddCustomer = true
                // Immediately revert to previous tab (don't stay on add button)
                selectedTab = oldValue
            } else {
                storedTabValue = newValue.rawValue
            }
        }
        .sheet(isPresented: $showingAddCustomer) {
            AddCustomerView(onSave: { customer in
                Task {
                    do {
                        let repository = appDependencies.serviceFactory.repositoryFactory.customerRepository
                        try await repository.addCustomer(customer)
                    } catch {
                        print("Error saving customer: \(error)")
                    }
                }
            })
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

