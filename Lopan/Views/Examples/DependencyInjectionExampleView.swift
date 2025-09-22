//
//  DependencyInjectionExampleView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import SwiftUI

/// Example view demonstrating dependency injection usage patterns
struct DependencyInjectionExampleView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.customerOutOfStockDependencies) private var customerOutOfStockDeps
    @Environment(\.productionDependencies) private var productionDeps
    @Environment(\.userManagementDependencies) private var userManagementDeps
    
    var body: some View {
        NavigationStack {
            List {
                Section("App Dependencies") {
                    DependencyInfoRow(
                        title: "Repository Factory",
                        subtitle: String(describing: type(of: appDependencies.repositoryFactory))
                    )
                    
                    DependencyInfoRow(
                        title: "Service Factory", 
                        subtitle: String(describing: type(of: appDependencies.serviceFactory))
                    )
                    
                    DependencyInfoRow(
                        title: "Authentication Service",
                        subtitle: String(describing: type(of: appDependencies.authenticationService))
                    )
                }
                
                Section("Customer Out of Stock Dependencies") {
                    NavigationLink("Customer Out of Stock Management") {
                        CustomerOutOfStockDIExampleView()
                    }
                    
                    DependencyInfoRow(
                        title: "Customer Repository",
                        subtitle: String(describing: type(of: customerOutOfStockDeps.customerRepository))
                    )
                    
                    DependencyInfoRow(
                        title: "Product Repository",
                        subtitle: String(describing: type(of: customerOutOfStockDeps.productRepository))
                    )
                }
                
                Section("Production Dependencies") {
                    NavigationLink("Production Management") {
                        ProductionDIExampleView()
                    }
                    
                    DependencyInfoRow(
                        title: "Machine Service",
                        subtitle: String(describing: type(of: productionDeps.machineService))
                    )
                    
                    DependencyInfoRow(
                        title: "Production Batch Service",
                        subtitle: String(describing: type(of: productionDeps.productionBatchService))
                    )
                }
                
                Section("User Management Dependencies") {
                    NavigationLink("User Management") {
                        UserManagementDIExampleView()
                    }
                    
                    DependencyInfoRow(
                        title: "User Service",
                        subtitle: String(describing: type(of: userManagementDeps.userService))
                    )
                }
                
                Section("Testing") {
                    NavigationLink("Mock Dependencies Example") {
                        MockDependenciesExampleView()
                    }
                }
            }
            .navigationTitle("Dependency Injection")
        }
    }
}

/// Customer Out of Stock management view using DI
struct CustomerOutOfStockDIExampleView: View {
    @Environment(\.customerOutOfStockDependencies) private var dependencies
    @StateObject private var viewModel: CustomerOutOfStockDIViewModel
    
    init() {
        // In a real implementation, we'd access dependencies through a different pattern
        // This is a simplified example showing the concept
        _viewModel = StateObject(wrappedValue: CustomerOutOfStockDIViewModel(
            dependencies: CustomerOutOfStockDependencies.createMock()
        ))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.items, id: \.id) { item in
                    CustomerOutOfStockRowView(item: item)
                }
            }
        }
        .navigationTitle("Customer Out of Stock")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh") {
                    Task {
                        await viewModel.refreshData()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
    }
}

/// Production management view using DI
struct ProductionDIExampleView: View {
    @Environment(\.productionDependencies) private var dependencies
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Production Management")
                .font(.title2)
                .bold()
            
            Text("Using Production Dependencies:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("• Machine Service: \(String(describing: type(of: dependencies.machineService)))")
                Text("• Color Service: \(String(describing: type(of: dependencies.colorService)))")
                Text("• Production Batch Service: \(String(describing: type(of: dependencies.productionBatchService)))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

/// User management view using DI
struct UserManagementDIExampleView: View {
    @Environment(\.userManagementDependencies) private var dependencies
    
    var body: some View {
        VStack(spacing: 20) {
            Text("User Management")
                .font(.title2)
                .bold()
            
            Text("Using User Management Dependencies:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("• User Service: \(String(describing: type(of: dependencies.userService)))")
                Text("• Auth Service: \(String(describing: type(of: dependencies.authenticationService)))")
                Text("• Audit Service: \(String(describing: type(of: dependencies.auditingService)))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

/// Mock dependencies example for testing
struct MockDependenciesExampleView: View {
    @State private var useMockDependencies = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mock Dependencies for Testing")
                .font(.title2)
                .bold()
            
            Toggle("Use Mock Dependencies", isOn: $useMockDependencies)
                .padding()
            
            if useMockDependencies {
                MockCustomerOutOfStockView()
                    .withCustomerOutOfStockDependencies(.createMock())
            } else {
                Text("Using Production Dependencies")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

/// Mock customer out of stock view
struct MockCustomerOutOfStockView: View {
    @Environment(\.customerOutOfStockDependencies) private var dependencies
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Mock Customer Out of Stock View")
                .font(.headline)
            
            Text("Repository Type: \(String(describing: type(of: dependencies.customerOutOfStockRepository)))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Test Mock Data") {
                // This would use mock data in a real implementation
                print("Using mock customer out of stock repository")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Helper view for displaying dependency information
struct DependencyInfoRow: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Simplified customer out of stock row view
struct CustomerOutOfStockRowView: View {
    let item: CustomerOutOfStock
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.customer?.name ?? "Unknown Customer")
                    .font(.headline)
                Text(item.product?.name ?? "Unknown Product")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(item.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.status.color.opacity(0.2))
                .foregroundColor(item.status.color)
                .cornerRadius(4)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DependencyInjectionExampleView_Previews: PreviewProvider {
    static var previews: some View {
        DependencyInjectionExampleView()
            .withAppDependencies(AppDependencies.createMock())
    }
}
#endif