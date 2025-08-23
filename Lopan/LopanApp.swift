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
                        #if DEBUG
                        // 检查是否需要生成大规模测试数据
                        if ProcessInfo.processInfo.environment["LARGE_SAMPLE_DATA"] == "true" {
                            print("🚀 检测到大规模样本数据环境变量，开始生成大规模测试数据...")
                            let largeSampleDataService = CustomerOutOfStockSampleDataService(
                                repositoryFactory: repositoryFactory
                            )
                            await largeSampleDataService.initializeLargeScaleSampleData()
                        } else {
                            print("📊 使用标准样本数据...")
                            // Initialize sample data on first launch using new repository pattern
                            await serviceFactory.dataInitializationService.initializeSampleData()
                        }
                        #else
                        // 生产环境不加载任何样本数据
                        print("🏭 生产环境：跳过样本数据初始化")
                        #endif
                        
                        // Initialize workshop data (colors, machines, batches)
                        await serviceFactory.machineDataInitializationService.initializeAllSampleData()
                        // Start ProductionBatchService for automatic batch execution
                        _ = serviceFactory.productionBatchService // This will trigger lazy initialization and startService()
                    }
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
