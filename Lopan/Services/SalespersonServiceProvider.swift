//
//  SalespersonServiceProvider.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation

@MainActor
class SalespersonServiceProvider: ObservableObject {
    private let repositoryFactory: RepositoryFactory
    private let authService: AuthenticationService
    private let auditService: NewAuditingService
    
    // MARK: - Core Services
    lazy var customerService: CustomerService = {
        CustomerService(repositoryFactory: repositoryFactory)
    }()
    
    lazy var productService: ProductService = {
        ProductService(repositoryFactory: repositoryFactory)
    }()
    
    lazy var customerOutOfStockService: CustomerOutOfStockService = {
        CustomerOutOfStockService(
            repositoryFactory: repositoryFactory,
            auditService: auditService,
            authService: authService
        )
    }()
    
    // MARK: - Initialization
    init(
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        auditService: NewAuditingService
    ) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
    }
    
    // MARK: - Helper Methods
    var currentUserId: String {
        return authService.currentUser?.id ?? "unknown"
    }
    
    var currentUserName: String {
        return authService.currentUser?.name ?? "unknown"
    }
}

// MARK: - Service Factory Integration
extension ServiceFactory {
    var salespersonServiceProvider: SalespersonServiceProvider {
        return SalespersonServiceProvider(
            repositoryFactory: repositoryFactory,
            authService: authenticationService,
            auditService: auditingService
        )
    }
}