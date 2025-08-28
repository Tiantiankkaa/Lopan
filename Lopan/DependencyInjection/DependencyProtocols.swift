//
//  DependencyProtocols.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation

// MARK: - Repository Dependencies

public protocol HasUserRepository {
    var userRepository: UserRepository { get }
}

public protocol HasCustomerRepository {
    var customerRepository: CustomerRepository { get }
}

public protocol HasProductRepository {
    var productRepository: ProductRepository { get }
}

public protocol HasCustomerOutOfStockRepository {
    var customerOutOfStockRepository: CustomerOutOfStockRepository { get }
}

public protocol HasPackagingRepository {
    var packagingRepository: PackagingRepository { get }
}

public protocol HasProductionRepository {
    var productionRepository: ProductionRepository { get }
}

public protocol HasAuditRepository {
    var auditRepository: AuditRepository { get }
}

public protocol HasMachineRepository {
    var machineRepository: MachineRepository { get }
}

public protocol HasColorRepository {
    var colorRepository: ColorRepository { get }
}

public protocol HasProductionBatchRepository {
    var productionBatchRepository: ProductionBatchRepository { get }
}

// MARK: - Service Dependencies

public protocol HasAuthenticationService {
    var authenticationService: AuthenticationService { get }
}

public protocol HasCustomerService {
    var customerService: CustomerService { get }
}

public protocol HasProductService {
    var productService: ProductService { get }
}

public protocol HasUserService {
    var userService: UserService { get }
}

public protocol HasAuditingService {
    var auditingService: NewAuditingService { get }
}

public protocol HasCustomerOutOfStockService {
    var customerOutOfStockService: CustomerOutOfStockService { get }
}

public protocol HasDataInitializationService {
    var dataInitializationService: NewDataInitializationService { get }
}

public protocol HasMachineService {
    var machineService: MachineService { get }
}

public protocol HasColorService {
    var colorService: ColorService { get }
}

public protocol HasProductionBatchService {
    var productionBatchService: ProductionBatchService { get }
}

// MARK: - Core Dependencies

public protocol HasRepositoryFactory {
    var repositoryFactory: RepositoryFactory { get }
}

public protocol HasServiceFactory {
    var serviceFactory: ServiceFactory { get }
}

// MARK: - Combined Dependencies for Specific Domains

public protocol HasCustomerOutOfStockDependencies: HasCustomerOutOfStockRepository, 
                                           HasCustomerRepository, 
                                           HasProductRepository,
                                           HasAuditingService,
                                           HasAuthenticationService {
}

public protocol HasProductionDependencies: HasMachineRepository,
                                   HasColorRepository,
                                   HasProductionBatchRepository,
                                   HasProductionBatchService,
                                   HasMachineService,
                                   HasColorService {
}

public protocol HasUserManagementDependencies: HasUserRepository,
                                       HasUserService,
                                       HasAuthenticationService,
                                       HasAuditingService {
}

// MARK: - App Level Dependencies

public protocol HasAppDependencies: HasRepositoryFactory,
                            HasServiceFactory,
                            HasAuthenticationService,
                            HasCustomerOutOfStockDependencies,
                            HasProductionDependencies,
                            HasUserManagementDependencies {
}