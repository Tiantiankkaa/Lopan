//
//  ServiceFactory.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

// MARK: - Service Cleanup Protocol
protocol ServiceCleanupProtocol {
    func cleanup()
}

@MainActor
class ServiceFactory: ObservableObject {
    let repositoryFactory: RepositoryFactory
    
    // MARK: - Service Cleanup Management
    private var cleanupServices: [ServiceCleanupProtocol] = []
    
    lazy var authenticationService: AuthenticationService = {
        let service = AuthenticationService(repositoryFactory: repositoryFactory, serviceFactory: self)
        return service
    }()
    lazy var customerService = CustomerService(repositoryFactory: repositoryFactory)
    lazy var productService = ProductService(repositoryFactory: repositoryFactory)
    lazy var userService = UserService(repositoryFactory: repositoryFactory)
    lazy var auditingService = NewAuditingService(repositoryFactory: repositoryFactory)
    lazy var dataInitializationService = NewDataInitializationService(repositoryFactory: repositoryFactory)
    lazy var machineService: MachineService = {
        let service = MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditingService,
            authService: authenticationService
        )
        registerForCleanup(service)
        return service
    }()
    
    lazy var colorService: ColorService = {
        let service = ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditingService,
            authService: authenticationService
        )
        registerForCleanup(service)
        return service
    }()
    lazy var machineDataInitializationService = MachineDataInitializationService(repositoryFactory: repositoryFactory)
    
    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
    
    // MARK: - Service Cleanup Management
    func registerForCleanup(_ service: ServiceCleanupProtocol) {
        cleanupServices.append(service)
    }
    
    func cleanupAllServices() async {
        // Cleanup all registered services
        for service in cleanupServices {
            service.cleanup()
        }
        
        // Wait a brief moment for tasks to cancel
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        print("✅ All services cleaned up successfully")
    }
}