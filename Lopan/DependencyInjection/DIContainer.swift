//
//  DIContainer.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Dependency Injection Container Protocol

protocol DIContainer {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) -> T
    func resolveOptional<T>(_ type: T.Type) -> T?
}

// MARK: - Container Implementation

class LopanDIContainer: DIContainer, ObservableObject {
    static let shared = LopanDIContainer()
    
    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]
    private var isConfigured = false
    
    private init() {}
    
    // MARK: - Registration Methods
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
    }
    
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = {
            if let singleton = self.singletons[key] as? T {
                return singleton
            }
            let instance = factory()
            self.singletons[key] = instance
            return instance
        }
    }
    
    // MARK: - Resolution Methods
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        // Check factories
        if let factory = factories[key], let instance = factory() as? T {
            return instance
        }
        
        fatalError("No registration found for type \(type)")
    }
    
    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        // Check factories
        if let factory = factories[key], let instance = factory() as? T {
            return instance
        }
        
        return nil
    }
    
    // MARK: - Configuration
    
    func configure(for environment: AppEnvironment) {
        guard !isConfigured else {
            print("⚠️ DI Container already configured")
            return
        }
        
        switch environment {
        case .development:
            configureDevelopmentDependencies()
        case .testing:
            configureTestingDependencies()
        case .production:
            configureProductionDependencies()
        }
        
        isConfigured = true
        print("✅ DI Container configured for \(environment)")
    }
    
    // MARK: - Environment-Specific Configurations
    
    private func configureDevelopmentDependencies() {
        // Local SwiftData repositories for development
        registerRepositories(useCloud: false)
        registerServices()
        registerUseCases()
        registerUtilities()
    }
    
    private func configureTestingDependencies() {
        // Mock repositories for testing
        registerMockRepositories()
        registerServices()
        registerUseCases()
        registerUtilities()
    }
    
    private func configureProductionDependencies() {
        // Using local repositories for production (cloud repositories disabled)
        registerRepositories(useCloud: false)
        registerServices()
        registerUseCases()
        registerUtilities()
    }
    
    // MARK: - Repository Registration
    
    private func registerRepositories(useCloud: Bool) {
        // Cloud repositories temporarily disabled - protocol conformance issues
        // if useCloud {
        //     // Cloud repositories
        //     register(CloudProvider.self) {
        //         HTTPCloudProvider(baseURL: AppConfig.shared.apiBaseURL)
        //     }
        //     
        //     register(CustomerOutOfStockRepository.self) {
        //         CloudCustomerOutOfStockRepository(cloudProvider: self.resolve(CloudProvider.self))
        //     }
        //     
        //     register(CustomerRepository.self) {
        //         CloudCustomerRepository(cloudProvider: self.resolve(CloudProvider.self))
        //     }
        //     
        //     register(ProductRepository.self) {
        //         CloudProductRepository(cloudProvider: self.resolve(CloudProvider.self))
        //     }
        //     
        //     register(UserRepository.self) {
        //         CloudUserRepository(cloudProvider: self.resolve(CloudProvider.self))
        //     }
        //     
        // } else {
            // Local SwiftData repositories
            register(ModelContainer.self) {
                AppModelContainer.shared.container
            }
            
            register(ModelContext.self) {
                MainActor.assumeIsolated {
                    self.resolve(ModelContainer.self).mainContext
                }
            }
            
            register(CustomerOutOfStockRepository.self) {
                MainActor.assumeIsolated {
                    LocalCustomerOutOfStockRepository(modelContext: self.resolve(ModelContext.self))
                }
            }
            
            register(CustomerRepository.self) {
                MainActor.assumeIsolated {
                    LocalCustomerRepository(modelContext: self.resolve(ModelContext.self))
                }
            }
            
            register(ProductRepository.self) {
                MainActor.assumeIsolated {
                    LocalProductRepository(modelContext: self.resolve(ModelContext.self))
                }
            }
            
            register(UserRepository.self) {
                MainActor.assumeIsolated {
                    LocalUserRepository(modelContext: self.resolve(ModelContext.self))
                }
            }
            
            register(AuditRepository.self) {
                MainActor.assumeIsolated {
                    LocalAuditRepository(modelContext: self.resolve(ModelContext.self))
                }
            }
        // }
    }
    
    private func registerMockRepositories() {
        // TODO: Implement mock repositories for testing
        // register(CustomerOutOfStockRepository.self) {
        //     MockCustomerOutOfStockRepository()
        // }
        // 
        // register(CustomerRepositoryProtocol.self) {
        //     MockCustomerRepository()
        // }
        // 
        // register(ProductRepositoryProtocol.self) {
        //     MockProductRepository()
        // }
        // 
        // register(UserRepositoryProtocol.self) {
        //     MockUserRepository()
        // }
        print("⚠️ Mock repositories not implemented yet")
    }
    
    // MARK: - Service Registration
    
    private func registerServices() {
        // First register the factory and core services
        registerSingleton(LocalRepositoryFactory.self) {
            MainActor.assumeIsolated {
                LocalRepositoryFactory(modelContext: self.resolve(ModelContext.self))
            }
        }
        
        registerSingleton(NewAuditingService.self) {
            MainActor.assumeIsolated {
                NewAuditingService(modelContext: self.resolve(ModelContext.self))
            }
        }
        
        registerSingleton(AuthenticationService.self) {
            MainActor.assumeIsolated {
                AuthenticationService(
                    repositoryFactory: self.resolve(LocalRepositoryFactory.self)
                )
            }
        }
        
        // Then register other services that depend on them
        registerSingleton(CustomerOutOfStockService.self) {
            MainActor.assumeIsolated {
                CustomerOutOfStockService(
                    repositoryFactory: self.resolve(LocalRepositoryFactory.self),
                    auditService: self.resolve(NewAuditingService.self),
                    authService: self.resolve(AuthenticationService.self)
                )
            }
        }
        
        registerSingleton(CustomerService.self) {
            MainActor.assumeIsolated {
                CustomerService(
                    repositoryFactory: self.resolve(LocalRepositoryFactory.self)
                )
            }
        }
        
        registerSingleton(ProductService.self) {
            MainActor.assumeIsolated {
                ProductService(
                    repositoryFactory: self.resolve(LocalRepositoryFactory.self)
                )
            }
        }
        
        registerSingleton(AuditingService.self) {
            MainActor.assumeIsolated {
                AuditingService(auditRepository: self.resolve(AuditRepository.self))
            }
        }
        
        registerSingleton(ExcelService.self) {
            ExcelService.shared
        }
    }
    
    // MARK: - Use Cases Registration
    
    private func registerUseCases() {
        // Use Cases temporarily disabled for compilation
        // TODO: Re-implement Use Cases with correct model structure
        print("📋 Use Cases registration skipped - requires model alignment")
    }
    
    // MARK: - Utilities Registration
    
    private func registerUtilities() {
        registerSingleton(KeyboardHandler.self) {
            KeyboardHandler()
        }
        
        registerSingleton(CommonMemoryManager.self) {
            CommonMemoryManager.shared
        }
    }
    
    // MARK: - Reset (for testing)
    
    func reset() {
        factories.removeAll()
        singletons.removeAll()
        isConfigured = false
    }
}

// MARK: - App Environment

enum AppEnvironment {
    case development
    case testing
    case production
    
    static var current: AppEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .testing
        }
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - App Configuration

class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var apiBaseURL: String
    @Published var enableAnalytics: Bool
    @Published var logLevel: LogLevel
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    private init() {
        self.apiBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://api.lopanng.com"
        self.enableAnalytics = ProcessInfo.processInfo.environment["ENABLE_ANALYTICS"] != "false"
        self.logLevel = LogLevel(rawValue: ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "INFO") ?? .info
    }
}

// MARK: - View Extension for DI

extension View {
    func withDependencyInjection() -> some View {
        self.environmentObject(LopanDIContainer.shared)
    }
}

// MARK: - Property Wrapper for Injection

@propertyWrapper
struct Inject<T> {
    let wrappedValue: T
    
    init() {
        self.wrappedValue = LopanDIContainer.shared.resolve(T.self)
    }
}

@propertyWrapper
struct InjectOptional<T> {
    let wrappedValue: T?
    
    init() {
        self.wrappedValue = LopanDIContainer.shared.resolveOptional(T.self)
    }
}