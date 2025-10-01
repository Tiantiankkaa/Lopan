//
//  CloudRepositoryFactory.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation

// MARK: - Cloud Repository Factory

@MainActor
final class CloudRepositoryFactory: RepositoryFactory {
    private let cloudProvider: CloudProvider
    private let authenticationService: AuthenticationService?
    
    // MARK: - Repository Instances
    
    lazy var userRepository: UserRepository = CloudUserRepository(cloudProvider: cloudProvider)
    lazy var customerRepository: CustomerRepository = CloudCustomerRepository(cloudProvider: cloudProvider)
    lazy var productRepository: ProductRepository = CloudProductRepository(cloudProvider: cloudProvider)
    lazy var customerOutOfStockRepository: CustomerOutOfStockRepository = CloudCustomerOutOfStockRepository(cloudProvider: cloudProvider)
    lazy var packagingRepository: PackagingRepository = CloudPackagingRepository(cloudProvider: cloudProvider)
    lazy var productionRepository: ProductionRepository = CloudProductionRepository(cloudProvider: cloudProvider)
    lazy var auditRepository: AuditRepository = CloudAuditRepository(cloudProvider: cloudProvider)
    lazy var machineRepository: MachineRepository = CloudMachineRepository(cloudProvider: cloudProvider)
    lazy var colorRepository: ColorRepository = CloudColorRepository(cloudProvider: cloudProvider)
    lazy var productionBatchRepository: ProductionBatchRepository = CloudProductionBatchRepository(cloudProvider: cloudProvider)
    lazy var salesRepository: SalesRepository = CloudSalesRepository(cloudProvider: cloudProvider)
    
    init(cloudProvider: CloudProvider, authenticationService: AuthenticationService? = nil) {
        self.cloudProvider = cloudProvider
        self.authenticationService = authenticationService
    }
    
    // MARK: - Factory Methods
    
    static func create(for environment: CloudEnvironment, authService: AuthenticationService? = nil) -> CloudRepositoryFactory {
        let cloudProvider = CloudProviderFactory.create(for: environment, authService: authService)
        return CloudRepositoryFactory(cloudProvider: cloudProvider, authenticationService: authService)
    }
}

// MARK: - Hybrid Repository Factory (supports both Local and Cloud)

@MainActor
final class HybridRepositoryFactory: RepositoryFactory {
    private let localFactory: LocalRepositoryFactory
    private let cloudFactory: CloudRepositoryFactory?
    private let isCloudEnabled: Bool
    
    init(localFactory: LocalRepositoryFactory, cloudFactory: CloudRepositoryFactory?, isCloudEnabled: Bool = false) {
        self.localFactory = localFactory
        self.cloudFactory = cloudFactory
        self.isCloudEnabled = isCloudEnabled && cloudFactory != nil
    }
    
    // MARK: - Repository Properties
    
    @MainActor var userRepository: UserRepository {
        return isCloudEnabled ? cloudFactory!.userRepository : localFactory.userRepository
    }
    
    @MainActor var customerRepository: CustomerRepository {
        return isCloudEnabled ? cloudFactory!.customerRepository : localFactory.customerRepository
    }
    
    @MainActor var productRepository: ProductRepository {
        return isCloudEnabled ? cloudFactory!.productRepository : localFactory.productRepository
    }
    
    @MainActor var customerOutOfStockRepository: CustomerOutOfStockRepository {
        return isCloudEnabled ? cloudFactory!.customerOutOfStockRepository : localFactory.customerOutOfStockRepository
    }
    
    @MainActor var packagingRepository: PackagingRepository {
        return isCloudEnabled ? cloudFactory!.packagingRepository : localFactory.packagingRepository
    }
    
    @MainActor var productionRepository: ProductionRepository {
        return isCloudEnabled ? cloudFactory!.productionRepository : localFactory.productionRepository
    }
    
    @MainActor var auditRepository: AuditRepository {
        return isCloudEnabled ? cloudFactory!.auditRepository : localFactory.auditRepository
    }
    
    @MainActor var machineRepository: MachineRepository {
        return isCloudEnabled ? cloudFactory!.machineRepository : localFactory.machineRepository
    }
    
    @MainActor var colorRepository: ColorRepository {
        return isCloudEnabled ? cloudFactory!.colorRepository : localFactory.colorRepository
    }
    
    @MainActor var productionBatchRepository: ProductionBatchRepository {
        return isCloudEnabled ? cloudFactory!.productionBatchRepository : localFactory.productionBatchRepository
    }

    @MainActor var salesRepository: SalesRepository {
        return isCloudEnabled ? cloudFactory!.salesRepository : localFactory.salesRepository
    }

    // MARK: - Cloud Migration Support
    
    func enableCloudRepositories() {
        // This would be called during cloud migration
        // Implementation would handle gradual migration
    }
    
    func disableCloudRepositories() {
        // This would be called for rollback scenarios
        // Implementation would switch back to local repositories
    }
    
    func getCloudSyncStatus() async throws -> CloudSyncStatus? {
        guard let cloudFactory = cloudFactory,
              let cloudOutOfStockRepo = cloudFactory.customerOutOfStockRepository as? CloudCustomerOutOfStockRepository else {
            return nil
        }
        
        return try await cloudOutOfStockRepo.syncWithCloud()
    }
}

// MARK: - Feature Flag Support

enum RepositoryFeatureFlag {
    case useCloudCustomerOutOfStock
    case useCloudCustomers
    case useCloudProducts
    case useCloudAudit
    case useCloudAll
    
    var isEnabled: Bool {
        // This would integrate with your feature flag system
        // For now, returning false to maintain current behavior
        switch self {
        case .useCloudCustomerOutOfStock:
            return ProcessInfo.processInfo.environment["USE_CLOUD_OUT_OF_STOCK"] == "true"
        case .useCloudCustomers:
            return ProcessInfo.processInfo.environment["USE_CLOUD_CUSTOMERS"] == "true"
        case .useCloudProducts:
            return ProcessInfo.processInfo.environment["USE_CLOUD_PRODUCTS"] == "true"
        case .useCloudAudit:
            return ProcessInfo.processInfo.environment["USE_CLOUD_AUDIT"] == "true"
        case .useCloudAll:
            return ProcessInfo.processInfo.environment["USE_CLOUD_ALL"] == "true"
        }
    }
}

// MARK: - Feature Flag-Aware Repository Factory

@MainActor
final class FeatureFlagRepositoryFactory: RepositoryFactory {
    private let localFactory: LocalRepositoryFactory
    private let cloudFactory: CloudRepositoryFactory?
    
    init(localFactory: LocalRepositoryFactory, cloudFactory: CloudRepositoryFactory? = nil) {
        self.localFactory = localFactory
        self.cloudFactory = cloudFactory
    }
    
    var userRepository: UserRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.userRepository
        }
        return localFactory.userRepository
    }
    
    var customerRepository: CustomerRepository {
        if RepositoryFeatureFlag.useCloudCustomers.isEnabled || RepositoryFeatureFlag.useCloudAll.isEnabled,
           let cloudFactory = cloudFactory {
            return cloudFactory.customerRepository
        }
        return localFactory.customerRepository
    }
    
    var productRepository: ProductRepository {
        if RepositoryFeatureFlag.useCloudProducts.isEnabled || RepositoryFeatureFlag.useCloudAll.isEnabled,
           let cloudFactory = cloudFactory {
            return cloudFactory.productRepository
        }
        return localFactory.productRepository
    }
    
    var customerOutOfStockRepository: CustomerOutOfStockRepository {
        if RepositoryFeatureFlag.useCloudCustomerOutOfStock.isEnabled || RepositoryFeatureFlag.useCloudAll.isEnabled,
           let cloudFactory = cloudFactory {
            return cloudFactory.customerOutOfStockRepository
        }
        return localFactory.customerOutOfStockRepository
    }
    
    var packagingRepository: PackagingRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.packagingRepository
        }
        return localFactory.packagingRepository
    }
    
    var productionRepository: ProductionRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.productionRepository
        }
        return localFactory.productionRepository
    }
    
    var auditRepository: AuditRepository {
        if RepositoryFeatureFlag.useCloudAudit.isEnabled || RepositoryFeatureFlag.useCloudAll.isEnabled,
           let cloudFactory = cloudFactory {
            return cloudFactory.auditRepository
        }
        return localFactory.auditRepository
    }
    
    var machineRepository: MachineRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.machineRepository
        }
        return localFactory.machineRepository
    }
    
    var colorRepository: ColorRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.colorRepository
        }
        return localFactory.colorRepository
    }
    
    var productionBatchRepository: ProductionBatchRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.productionBatchRepository
        }
        return localFactory.productionBatchRepository
    }

    var salesRepository: SalesRepository {
        if RepositoryFeatureFlag.useCloudAll.isEnabled, let cloudFactory = cloudFactory {
            return cloudFactory.salesRepository
        }
        return localFactory.salesRepository
    }
}

// MARK: - Repository Factory Extensions

extension RepositoryFactory {
    
    // MARK: - Health Checks
    
    func performHealthCheck() async -> [String: Bool] {
        var healthStatus: [String: Bool] = [:]
        
        // Check each repository's health
        do {
            _ = try await customerRepository.fetchCustomers()
            healthStatus["CustomerRepository"] = true
        } catch {
            healthStatus["CustomerRepository"] = false
        }
        
        do {
            _ = try await productRepository.fetchProducts()
            healthStatus["ProductRepository"] = true
        } catch {
            healthStatus["ProductRepository"] = false
        }
        
        do {
            let criteria = OutOfStockFilterCriteria()
            _ = try await customerOutOfStockRepository.fetchOutOfStockRecords(criteria: criteria, page: 0, pageSize: 1)
            healthStatus["CustomerOutOfStockRepository"] = true
        } catch {
            healthStatus["CustomerOutOfStockRepository"] = false
        }
        
        return healthStatus
    }
    
    // MARK: - Migration Support
    
    func validateDataIntegrity() async -> Bool {
        // Implementation would validate data consistency
        // between local and cloud repositories
        return true
    }
}
