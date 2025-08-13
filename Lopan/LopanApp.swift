//
//  LopanApp.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

@main
struct LopanApp: App {
    
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            CustomerOutOfStock.self,
            Customer.self,
            Product.self,
            ProductSize.self,
            ProductionStyle.self,
            WorkshopProduction.self,
            EVAGranulation.self,
            WorkshopIssue.self,
            PackagingRecord.self,
            PackagingTeam.self,
            AuditLog.self,
            Item.self, // Keep for backward compatibility
            // Workshop Manager Models
            WorkshopMachine.self,
            WorkshopStation.self,
            WorkshopGun.self,
            ColorCard.self,
            ProductionBatch.self,
            ProductConfig.self,
        ])
        
        // For now, use in-memory storage to avoid schema migration issues
        // This will be reset to persistent storage once the app is stable
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            print("Creating ModelContainer...")
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("ModelContainer created successfully")
            return container
        } catch {
            print("ModelContainer creation failed: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            let repositoryFactory = LocalRepositoryFactory(modelContext: Self.sharedModelContainer.mainContext)
            let serviceFactory = ServiceFactory(repositoryFactory: repositoryFactory)
            
            DashboardView(authService: serviceFactory.authenticationService)
                .environmentObject(serviceFactory)
                .onAppear {
                    Task {
                        // Initialize sample data on first launch using new repository pattern
                        await serviceFactory.dataInitializationService.initializeSampleData()
                        // Initialize workshop data (colors, machines, batches)
                        await serviceFactory.machineDataInitializationService.initializeAllSampleData()
                    }
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
