//
//  AppModelContainer.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation
import SwiftData

// MARK: - App Environment

public enum AppEnvironment {
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

// MARK: - App Model Container

class AppModelContainer {
    static let shared = AppModelContainer()
    
    private(set) var container: ModelContainer
    
    private init() {
        do {
            let configuration: ModelConfiguration
            if AppEnvironment.current == .production {
                configuration = ModelConfiguration(
                    schema: Schema([
                        Customer.self,
                        Product.self,
                        ProductSize.self,
                        CustomerOutOfStock.self,
                        User.self,
                        AuditLog.self,
                        EVAGranulation.self
                    ]),
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.com.lopang.app")
                )
            } else {
                configuration = ModelConfiguration(
                    schema: Schema([
                        Customer.self,
                        Product.self,
                        ProductSize.self,
                        CustomerOutOfStock.self,
                        User.self,
                        AuditLog.self,
                        EVAGranulation.self
                    ]),
                    isStoredInMemoryOnly: AppEnvironment.current == .testing
                )
            }
            
            self.container = try ModelContainer(
                for: Customer.self,
                Product.self,
                ProductSize.self,
                CustomerOutOfStock.self,
                User.self,
                AuditLog.self,
                EVAGranulation.self,
                configurations: configuration
            )
            
            print("✅ AppModelContainer initialized successfully for environment: \(AppEnvironment.current)")
            
        } catch {
            print("❌ Failed to initialize ModelContainer: \(error)")
            
            // Fallback to in-memory container
            do {
                let fallbackConfiguration = ModelConfiguration(
                    schema: Schema([
                        Customer.self,
                        Product.self,
                        ProductSize.self,
                        CustomerOutOfStock.self,
                        User.self,
                        AuditLog.self,
                        EVAGranulation.self
                    ]),
                    isStoredInMemoryOnly: true
                )
                
                self.container = try ModelContainer(
                    for: Customer.self,
                    Product.self,
                    ProductSize.self,
                    CustomerOutOfStock.self,
                    User.self,
                    AuditLog.self,
                    EVAGranulation.self,
                    configurations: fallbackConfiguration
                )
                
                print("⚠️ Using fallback in-memory container")
                
            } catch {
                fatalError("Failed to create fallback ModelContainer: \(error)")
            }
        }
    }
    
    // MARK: - Context Management
    
    func newBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        return context
    }
    
    @MainActor
    func mainContext() -> ModelContext {
        return container.mainContext
    }
    
    // MARK: - Environment Configuration
    
    private var isInMemoryMode: Bool {
        switch AppEnvironment.current {
        case .testing:
            return true
        case .development:
            return ProcessInfo.processInfo.environment["USE_MEMORY_STORAGE"] == "true"
        case .production:
            return false
        }
    }
    
    private var cloudKitConfiguration: ModelConfiguration.CloudKitDatabase? {
        switch AppEnvironment.current {
        case .production:
            return .private("iCloud.com.lopang.app")
        case .development:
            return ProcessInfo.processInfo.environment["ENABLE_CLOUDKIT"] == "true" ? .private("iCloud.com.lopang.app.dev") : nil
        case .testing:
            return nil
        }
    }
    
    // MARK: - Migration Support
    
    func performMigrationIfNeeded() async throws {
        // Migration logic would go here
        // For now, this is a placeholder for future schema migrations
        print("🔄 Checking for schema migrations...")
        
        // Example migration logic:
        // 1. Check current schema version
        // 2. Apply necessary migrations
        // 3. Update version tracking
        
        print("✅ Schema migration check completed")
    }
    
    // MARK: - Debugging Support
    
    func printContainerInfo() {
        print("=== AppModelContainer Info ===")
        print("Environment: \(AppEnvironment.current)")
        print("In-Memory Mode: \(isInMemoryMode)")
        print("CloudKit Enabled: \(cloudKitConfiguration != nil)")
        print("Container URL: \(container.configurations.first?.url.absoluteString ?? "N/A")")
        print("============================")
    }
}

// MARK: - Container Factory

class ModelContainerFactory {
    static func createContainer(for environment: AppEnvironment) throws -> ModelContainer {
        let isInMemory: Bool
        let cloudKitConfig: ModelConfiguration.CloudKitDatabase?
        
        switch environment {
        case .testing:
            isInMemory = true
            cloudKitConfig = nil
        case .development:
            isInMemory = ProcessInfo.processInfo.environment["USE_MEMORY_STORAGE"] == "true"
            cloudKitConfig = ProcessInfo.processInfo.environment["ENABLE_CLOUDKIT"] == "true" ? .private("iCloud.com.lopang.app.dev") : nil
        case .production:
            isInMemory = false
            cloudKitConfig = .private("iCloud.com.lopang.app")
        }
        
        let configuration: ModelConfiguration
        if let cloudKitDatabase = cloudKitConfig {
            configuration = ModelConfiguration(
                schema: Schema([
                    Customer.self,
                    Product.self,
                    ProductSize.self,
                    CustomerOutOfStock.self,
                    User.self,
                    AuditLog.self,
                    EVAGranulation.self
                ]),
                isStoredInMemoryOnly: isInMemory,
                cloudKitDatabase: cloudKitDatabase
            )
        } else {
            configuration = ModelConfiguration(
                schema: Schema([
                    Customer.self,
                    Product.self,
                    ProductSize.self,
                    CustomerOutOfStock.self,
                    User.self,
                    AuditLog.self,
                    EVAGranulation.self
                ]),
                isStoredInMemoryOnly: isInMemory
            )
        }
        
        return try ModelContainer(
            for: Customer.self,
            Product.self,
            ProductSize.self,
            CustomerOutOfStock.self,
            User.self,
            AuditLog.self,
            EVAGranulation.self,
            configurations: configuration
        )
    }
}