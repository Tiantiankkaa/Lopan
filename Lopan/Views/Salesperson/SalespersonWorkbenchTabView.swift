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
    case search

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
        case .search:
            return "搜索"
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
        case .search:
            return "magnifyingglass"
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

    // Customer filter selection
    @State private var selectedCustomerFilter: CustomerFilterTab = .all

    // Scroll state from CustomerManagementView
    @State private var isCustomerScrolled: Bool = false

    // Manual collapse flag - prioritizes user tap over scroll events
    @State private var manuallyCollapsed: Bool = false

    // Search state for Tab search role
    @State private var searchText = ""

    // Environment
    @Environment(\.enhancedLiquidGlass) private var glassManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appDependencies) private var appDependencies

    // MARK: - Proxy Binding for Tab Selection

    /// Detects taps on currently selected tab (including repeat taps)
    private var tabSelectionBinding: Binding<SalespersonTab> {
        Binding(
            get: { self.selectedTab },
            set: { newValue in
                // Detect tap on already selected Customer tab
                if newValue == .customers && self.selectedTab == .customers && self.isCustomerScrolled {
                    // User tapped on already selected Customer tab while scrolled
                    self.isCustomerScrolled = false
                }

                // Normal tab selection (including search)
                self.selectedTab = newValue
                self.storedTabValue = newValue.rawValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelectionBinding) {
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
                    CustomerManagementView(
                        selectedTab: $selectedCustomerFilter,
                        isScrolled: $isCustomerScrolled,
                        manuallyCollapsed: $manuallyCollapsed,
                        searchText: $searchText
                    )
                }
            } label: {
                Label(SalespersonTab.customers.titleKey, systemImage: SalespersonTab.customers.systemImage)
            }

            // Tab 5: Search (only visible on Customer tab)
            if selectedTab == .customers || selectedTab == .search {
                Tab(value: SalespersonTab.search, role: .search) {
                    tabContainer {
                        CustomerManagementView(
                            selectedTab: $selectedCustomerFilter,
                            isScrolled: $isCustomerScrolled,
                            manuallyCollapsed: $manuallyCollapsed,
                            searchText: $searchText
                        )
                    }
                } label: {
                    Label(SalespersonTab.search.titleKey, systemImage: SalespersonTab.search.systemImage)
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索客户")
        .tabBarMinimizeBehavior(.onScrollDown) // iOS 26 Liquid Glass scroll behavior
        .onTabBarTap { tappedIndex in
            // Map tab index to SalespersonTab enum
            // Index mapping: 0=overview, 1=stockouts, 2=returns, 3=customers, 4=addCustomer(conditional)

            // Check if Customer tab (index 3) was tapped while already selected and scrolled
            if tappedIndex == 3 && selectedTab == .customers && isCustomerScrolled {
                // Animate the state change to ensure smooth UI update
                withAnimation(.easeInOut(duration: 0.2)) {
                    manuallyCollapsed = true  // Prioritize user tap over scroll events
                    isCustomerScrolled = false
                }

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
        .onAppear {
            selectedTab = SalespersonTab(rawValue: storedTabValue) ?? .overview
            configureTabBarAppearance()
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

