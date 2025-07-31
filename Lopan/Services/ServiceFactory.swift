//
//  ServiceFactory.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
class ServiceFactory: ObservableObject {
    private let repositoryFactory: RepositoryFactory
    
    lazy var authenticationService = AuthenticationService(repositoryFactory: repositoryFactory)
    lazy var customerService = CustomerService(repositoryFactory: repositoryFactory)
    lazy var productService = ProductService(repositoryFactory: repositoryFactory)
    lazy var userService = UserService(repositoryFactory: repositoryFactory)
    lazy var auditingService = NewAuditingService(repositoryFactory: repositoryFactory)
    lazy var dataInitializationService = NewDataInitializationService(repositoryFactory: repositoryFactory)
    
    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
}