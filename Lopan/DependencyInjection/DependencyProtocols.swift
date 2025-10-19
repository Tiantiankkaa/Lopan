//
//  DependencyProtocols.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation

// MARK: - Repository Dependencies

@MainActor
public protocol HasUserRepository {
    var userRepository: UserRepository { get }
}

@MainActor
public protocol HasCustomerRepository {
    var customerRepository: CustomerRepository { get }
}

@MainActor
public protocol HasProductRepository {
    var productRepository: ProductRepository { get }
}

@MainActor
public protocol HasCustomerOutOfStockRepository {
    var customerOutOfStockRepository: CustomerOutOfStockRepository { get }
}

@MainActor
public protocol HasPackagingRepository {
    var packagingRepository: PackagingRepository { get }
}

@MainActor
public protocol HasProductionRepository {
    var productionRepository: ProductionRepository { get }
}

@MainActor
public protocol HasAuditRepository {
    var auditRepository: AuditRepository { get }
}

@MainActor
public protocol HasMachineRepository {
    var machineRepository: MachineRepository { get }
}

@MainActor
public protocol HasColorRepository {
    var colorRepository: ColorRepository { get }
}

@MainActor
public protocol HasProductionBatchRepository {
    var productionBatchRepository: ProductionBatchRepository { get }
}

@MainActor
public protocol HasSalesRepository {
    var salesRepository: SalesRepository { get }
}

// MARK: - Service Dependencies

@MainActor
public protocol HasAuthenticationService {
    var authenticationService: AuthenticationService { get }
}

@MainActor
public protocol HasCustomerService {
    var customerService: CustomerService { get }
}

@MainActor
public protocol HasProductService {
    var productService: ProductService { get }
}

@MainActor
public protocol HasUserService {
    var userService: UserService { get }
}

@MainActor
public protocol HasAuditingService {
    var auditingService: NewAuditingService { get }
}

@MainActor
public protocol HasCustomerOutOfStockService {
    var customerOutOfStockService: CustomerOutOfStockService { get }
}

@MainActor
public protocol HasCustomerOutOfStockCoordinator {
    var customerOutOfStockCoordinator: CustomerOutOfStockCoordinator { get }
}

@MainActor
public protocol HasDataInitializationService {
    var dataInitializationService: NewDataInitializationService { get }
}

@MainActor
public protocol HasMachineService {
    var machineService: MachineService { get }
}

@MainActor
public protocol HasColorService {
    var colorService: ColorService { get }
}

@MainActor
public protocol HasProductionBatchService {
    var productionBatchService: ProductionBatchService { get }
}

@MainActor
public protocol HasSalesService {
    var salesService: SalesService { get }
}

// MARK: - Core Dependencies

@MainActor
public protocol HasRepositoryFactory {
    var repositoryFactory: RepositoryFactory { get }
}

@MainActor
public protocol HasServiceFactory {
    var serviceFactory: ServiceFactory { get }
}

// MARK: - Combined Dependencies for Specific Domains

@MainActor
public protocol HasCustomerOutOfStockDependencies: HasCustomerOutOfStockRepository,
                                           HasCustomerRepository,
                                           HasProductRepository,
                                           HasAuditingService,
                                           HasAuthenticationService,
                                           HasCustomerOutOfStockService,
                                           HasCustomerOutOfStockCoordinator {
}

@MainActor
public protocol HasProductionDependencies: HasMachineRepository,
                                   HasColorRepository,
                                   HasProductionBatchRepository,
                                   HasProductionBatchService,
                                   HasMachineService,
                                   HasColorService {
}

@MainActor
public protocol HasUserManagementDependencies: HasUserRepository,
                                       HasUserService,
                                       HasAuthenticationService,
                                       HasAuditingService {
}

// MARK: - App Level Dependencies

@MainActor
public protocol HasAppDependencies: HasRepositoryFactory,
                            HasServiceFactory,
                            HasAuthenticationService,
                            HasCustomerService,
                            HasProductService,
                            HasDataInitializationService,
                            HasCustomerOutOfStockDependencies,
                            HasProductionDependencies,
                            HasUserManagementDependencies,
                            HasSalesRepository,
                            HasSalesService {
}