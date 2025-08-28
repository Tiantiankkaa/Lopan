//
//  AppDependencies.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Core App Dependencies

@MainActor
public final class AppDependencies: HasAppDependencies, ObservableObject {
    
    // MARK: - Core Factories
    public let repositoryFactory: RepositoryFactory
    public let serviceFactory: ServiceFactory
    
    // MARK: - Repository Dependencies
    public var userRepository: UserRepository { repositoryFactory.userRepository }
    public var customerRepository: CustomerRepository { repositoryFactory.customerRepository }
    public var productRepository: ProductRepository { repositoryFactory.productRepository }
    public var customerOutOfStockRepository: CustomerOutOfStockRepository { repositoryFactory.customerOutOfStockRepository }
    public var packagingRepository: PackagingRepository { repositoryFactory.packagingRepository }
    public var productionRepository: ProductionRepository { repositoryFactory.productionRepository }
    public var auditRepository: AuditRepository { repositoryFactory.auditRepository }
    public var machineRepository: MachineRepository { repositoryFactory.machineRepository }
    public var colorRepository: ColorRepository { repositoryFactory.colorRepository }
    public var productionBatchRepository: ProductionBatchRepository { repositoryFactory.productionBatchRepository }
    
    // MARK: - Service Dependencies
    public var authenticationService: AuthenticationService { serviceFactory.authenticationService }
    public var customerService: CustomerService { serviceFactory.customerService }
    public var productService: ProductService { serviceFactory.productService }
    public var userService: UserService { serviceFactory.userService }
    public var auditingService: NewAuditingService { serviceFactory.auditingService }
    public var customerOutOfStockService: CustomerOutOfStockService { serviceFactory.customerOutOfStockService }
    public var dataInitializationService: NewDataInitializationService { serviceFactory.dataInitializationService }
    public var machineService: MachineService { serviceFactory.machineService }
    public var colorService: ColorService { serviceFactory.colorService }
    public var productionBatchService: ProductionBatchService { serviceFactory.productionBatchService }
    
    // MARK: - Initialization
    public init(repositoryFactory: RepositoryFactory, serviceFactory: ServiceFactory) {
        self.repositoryFactory = repositoryFactory
        self.serviceFactory = serviceFactory
    }
    
    // MARK: - Factory Method
    public static func create(for environment: AppEnvironment, modelContext: ModelContext) -> AppDependencies {
        let repositoryFactory = ServiceFactory.createRepositoryFactory(for: environment, modelContext: modelContext)
        let serviceFactory = ServiceFactory(repositoryFactory: repositoryFactory)
        
        return AppDependencies(repositoryFactory: repositoryFactory, serviceFactory: serviceFactory)
    }
}

// MARK: - Specific Domain Dependencies

@MainActor
public final class CustomerOutOfStockDependencies: HasCustomerOutOfStockDependencies, ObservableObject {
    private let appDependencies: AppDependencies
    
    public var customerOutOfStockRepository: CustomerOutOfStockRepository { appDependencies.customerOutOfStockRepository }
    public var customerRepository: CustomerRepository { appDependencies.customerRepository }
    public var productRepository: ProductRepository { appDependencies.productRepository }
    public var auditingService: NewAuditingService { appDependencies.auditingService }
    public var authenticationService: AuthenticationService { appDependencies.authenticationService }
    public var customerOutOfStockService: CustomerOutOfStockService { appDependencies.customerOutOfStockService }
    
    public init(appDependencies: AppDependencies) {
        self.appDependencies = appDependencies
    }
}

@MainActor
public final class ProductionDependencies: HasProductionDependencies, ObservableObject {
    private let appDependencies: AppDependencies
    
    public var machineRepository: MachineRepository { appDependencies.machineRepository }
    public var colorRepository: ColorRepository { appDependencies.colorRepository }
    public var productionBatchRepository: ProductionBatchRepository { appDependencies.productionBatchRepository }
    public var productionBatchService: ProductionBatchService { appDependencies.productionBatchService }
    public var machineService: MachineService { appDependencies.machineService }
    public var colorService: ColorService { appDependencies.colorService }
    
    public init(appDependencies: AppDependencies) {
        self.appDependencies = appDependencies
    }
}

@MainActor
public final class UserManagementDependencies: HasUserManagementDependencies, ObservableObject {
    private let appDependencies: AppDependencies
    
    public var userRepository: UserRepository { appDependencies.userRepository }
    public var userService: UserService { appDependencies.userService }
    public var authenticationService: AuthenticationService { appDependencies.authenticationService }
    public var auditingService: NewAuditingService { appDependencies.auditingService }
    
    public init(appDependencies: AppDependencies) {
        self.appDependencies = appDependencies
    }
}