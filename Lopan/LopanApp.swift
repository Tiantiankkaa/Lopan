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
    var sharedModelContainer: ModelContainer = {
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
            Item.self, // Keep for backward compatibility
        ])
        
        // For now, use in-memory storage to avoid schema migration issues
        // This will be reset to persistent storage once the app is stable
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DashboardView(authService: AuthenticationService(modelContext: sharedModelContainer.mainContext))
                .onAppear {
                    // Initialize sample data on first launch
                    // For development, you can temporarily force reinitialization by uncommenting the next line
                    // DataInitializationService.clearAllData(modelContext: sharedModelContainer.mainContext)
                    DataInitializationService.initializeSampleData(modelContext: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
