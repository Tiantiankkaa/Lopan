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

    // Customer filter selection
    @State private var selectedCustomerFilter: CustomerFilterTab = .all

    // Scroll state from CustomerManagementView
    @State private var isCustomerScrolled: Bool = false

    // Manual collapse flag - prioritizes user tap over scroll events
    @State private var manuallyCollapsed: Bool = false

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
                print("📍 [TabView] Tab tapped: \(newValue.rawValue) (current: \(self.selectedTab.rawValue))")

                // Detect tap on already selected Customer tab
                if newValue == .customers && self.selectedTab == .customers && self.isCustomerScrolled {
                    // User tapped on already selected Customer tab while scrolled
                    self.isCustomerScrolled = false
                    print("🎯 [TabView] Tapped current Customer tab, collapsing filter bar (iOS 26 native behavior)")
                }

                // Intercept "Add Customer" tab
                if newValue == .addCustomer {
                    self.showingAddCustomer = true
                    // Don't change selectedTab
                } else {
                    self.selectedTab = newValue
                    self.storedTabValue = newValue.rawValue
                }
            }
        )
    }

    var body: some View {
        let _ = print("🎯 [TabView] Body render - selectedTab: \(selectedTab.rawValue), isCustomerScrolled: \(isCustomerScrolled)")

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
                        manuallyCollapsed: $manuallyCollapsed
                    )
                }
            } label: {
                Label(SalespersonTab.customers.titleKey, systemImage: SalespersonTab.customers.systemImage)
            }

            // Tab 5: Add Customer (only visible on Customer tab)
            if selectedTab == .customers {
                Tab(value: SalespersonTab.addCustomer, role: .search) {
                    Color.clear
                } label: {
                    Label(SalespersonTab.addCustomer.titleKey, systemImage: SalespersonTab.addCustomer.systemImage)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown) // iOS 26 Liquid Glass scroll behavior
        .tabViewBottomAccessory {
            // Show filter controls only when on Customer tab AND scrolled down
            if selectedTab == .customers && isCustomerScrolled {
                CustomerFilterAccessoryView(selectedFilter: $selectedCustomerFilter)
            }
        }
        .onTabBarTap { tappedIndex in
            // Map tab index to SalespersonTab enum
            // Index mapping: 0=overview, 1=stockouts, 2=returns, 3=customers, 4=addCustomer(conditional)
            print("🎯 [UIKit] Tab bar tapped at index: \(tappedIndex)")

            // Check if Customer tab (index 3) was tapped while already selected and scrolled
            if tappedIndex == 3 && selectedTab == .customers && isCustomerScrolled {
                print("✨ [UIKit] Customer tab tapped while scrolled, collapsing filter bar")

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
            print("🎬 SalespersonWorkbenchTabView appeared")
        }
        .onChange(of: selectedCustomerFilter) { _, newValue in
            print("🔍 Customer filter changed: \(newValue.rawValue)")
        }
        .onChange(of: isCustomerScrolled) { oldValue, newValue in
            print("🔄 [TabView] isCustomerScrolled changed: \(oldValue) → \(newValue)")
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

