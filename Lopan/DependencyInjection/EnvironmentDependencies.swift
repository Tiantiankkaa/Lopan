//
//  EnvironmentDependencies.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import SwiftUI
import SwiftData

// MARK: - Environment Keys

private struct AppDependenciesKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: HasAppDependencies = {
        // ⚠️ WARNING: This default value should NOT be used in production
        // It creates a separate, empty ModelContainer that won't share data with the main app
        // The proper way is to inject dependencies through .withAppDependencies() modifier
        // This placeholder exists only to satisfy the EnvironmentKey protocol requirement

        print("⚠️ WARNING: Using default AppDependencies with empty container")
        print("   → This means the view was not properly initialized with app dependencies")
        print("   → Data will be empty. Ensure .withAppDependencies() is called in view hierarchy")

        return MainActor.assumeIsolated {
            let modelContainer = try! ModelContainer(
                for: User.self,
                     Customer.self,
                     Product.self,
                     CustomerOutOfStock.self,
                     PackagingRecord.self,
                     AuditLog.self,
                     WorkshopMachine.self,
                     ColorCard.self,
                     ProductionBatch.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            // Use LazyAppDependencies for better performance
            return LazyAppDependencies.create(
                for: .development,
                modelContext: modelContainer.mainContext
            )
        }
    }()
}

private struct CustomerOutOfStockDependenciesKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = MainActor.assumeIsolated {
        CustomerOutOfStockDependencies(appDependencies: AppDependenciesKey.defaultValue)
    }
}

private struct ProductionDependenciesKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = MainActor.assumeIsolated {
        ProductionDependencies(appDependencies: AppDependenciesKey.defaultValue)
    }
}

private struct UserManagementDependenciesKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = MainActor.assumeIsolated {
        UserManagementDependencies(appDependencies: AppDependenciesKey.defaultValue)
    }
}

// MARK: - Environment Values Extensions

extension EnvironmentValues {
    
    /// Main app dependencies container (supports both AppDependencies and LazyAppDependencies)
    public var appDependencies: HasAppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
    
    /// Customer out of stock specific dependencies
    public var customerOutOfStockDependencies: CustomerOutOfStockDependencies {
        get { self[CustomerOutOfStockDependenciesKey.self] }
        set { self[CustomerOutOfStockDependenciesKey.self] = newValue }
    }
    
    /// Production management specific dependencies
    public var productionDependencies: ProductionDependencies {
        get { self[ProductionDependenciesKey.self] }
        set { self[ProductionDependenciesKey.self] = newValue }
    }
    
    /// User management specific dependencies
    public var userManagementDependencies: UserManagementDependencies {
        get { self[UserManagementDependenciesKey.self] }
        set { self[UserManagementDependenciesKey.self] = newValue }
    }
}

// MARK: - View Extensions for Dependency Injection

extension View {
    
    /// Injects the main app dependencies into the environment
    public func withAppDependencies(_ dependencies: HasAppDependencies) -> some View {
        self
            .environment(\.appDependencies, dependencies)
            .environment(\.customerOutOfStockDependencies, CustomerOutOfStockDependencies(appDependencies: dependencies))
            .environment(\.productionDependencies, ProductionDependencies(appDependencies: dependencies))
            .environment(\.userManagementDependencies, UserManagementDependencies(appDependencies: dependencies))
    }
    
    /// Injects specific domain dependencies for testing or specific contexts
    public func withCustomerOutOfStockDependencies(_ dependencies: CustomerOutOfStockDependencies) -> some View {
        self.environment(\.customerOutOfStockDependencies, dependencies)
    }
    
    /// Injects production dependencies
    public func withProductionDependencies(_ dependencies: ProductionDependencies) -> some View {
        self.environment(\.productionDependencies, dependencies)
    }
    
    /// Injects user management dependencies
    public func withUserManagementDependencies(_ dependencies: UserManagementDependencies) -> some View {
        self.environment(\.userManagementDependencies, dependencies)
    }
}

// MARK: - Dependency Resolution Helpers

extension View {
    
    /// Resolves dependencies from environment for customer out of stock features
    @MainActor
    func resolveCustomerOutOfStockDependencies() -> CustomerOutOfStockDependencies {
        // This would be used in ViewModels or complex views that need to resolve dependencies
        return CustomerOutOfStockDependenciesKey.defaultValue
    }
    
    /// Resolves dependencies from environment for production features
    @MainActor
    func resolveProductionDependencies() -> ProductionDependencies {
        return ProductionDependenciesKey.defaultValue
    }
    
    /// Resolves dependencies from environment for user management features
    @MainActor
    func resolveUserManagementDependencies() -> UserManagementDependencies {
        return UserManagementDependenciesKey.defaultValue
    }
}

// MARK: - Mock Dependencies for Testing

#if DEBUG
extension AppDependencies {
    
    /// Creates mock dependencies for testing
    @MainActor
    static func createMock() -> AppDependencies {
        let mockContext = ModelContext(try! ModelContainer(for: 
            User.self,
            Customer.self,
            Product.self,
            CustomerOutOfStock.self,
            PackagingRecord.self,
            AuditLog.self,
            WorkshopMachine.self,
            ColorCard.self,
            ProductionBatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ))
        
        return AppDependencies.create(for: .testing, modelContext: mockContext)
    }
}

extension CustomerOutOfStockDependencies {
    
    /// Creates mock customer out of stock dependencies for testing
    @MainActor
    static func createMock() -> CustomerOutOfStockDependencies {
        return CustomerOutOfStockDependencies(appDependencies: AppDependencies.createMock())
    }
}

extension ProductionDependencies {
    
    /// Creates mock production dependencies for testing
    @MainActor
    static func createMock() -> ProductionDependencies {
        return ProductionDependencies(appDependencies: AppDependencies.createMock())
    }
}

extension UserManagementDependencies {
    
    /// Creates mock user management dependencies for testing
    @MainActor
    static func createMock() -> UserManagementDependencies {
        return UserManagementDependencies(appDependencies: AppDependencies.createMock())
    }
}
#endif