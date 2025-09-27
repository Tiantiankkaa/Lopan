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
            let appDependencies = AppDependencies.create(
                for: determineAppEnvironment(),
                modelContext: Self.sharedModelContainer.mainContext
            )
            
            DashboardView(authService: appDependencies.authenticationService)
                .withAppDependencies(appDependencies)
                .onAppear {
                    // PHASE 1: Initialize Performance Monitoring System (FIXED - Now with conditional enabling)
                    #if DEBUG
                    // Enable lightweight monitoring in debug builds
                    LopanPerformanceProfiler.shared.startMonitoring(lightweight: true)
                    print("🎯 Lightweight performance monitoring enabled in DEBUG build")
                    #else
                    // Production builds only enable monitoring if explicitly requested
                    print("🎯 Performance monitoring requires explicit environment variable in production")
                    #endif

                    // PHASE 3: Activate Production Monitoring System (CONTROLLED)
                    let isProduction = determineAppEnvironment() == .production
                    if #available(iOS 26.0, *) {
                        if !isProduction {
                            // Only enable in debug/development builds for now
                            // LopanProductionMonitoring.shared.startMonitoring(isProduction: false)
                            print("📊 Production monitoring available for debug builds")
                        } else {
                            print("📊 Production monitoring disabled in production build")
                        }
                    } else {
                        print("⚠️ Production monitoring requires iOS 26.0+")
                    }

                    // PHASE 4: Initialize ViewPreloadManager for Predictive Loading (CONDITIONAL)
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["ENABLE_VIEW_PRELOAD"] == "true" {
                        _ = ViewPreloadManager.shared
                        print("🎬 ViewPreloadManager enabled in DEBUG with environment flag")
                    } else {
                        print("🎬 ViewPreloadManager disabled (set ENABLE_VIEW_PRELOAD=true to enable)")
                    }
                    #else
                    print("🎬 ViewPreloadManager disabled in production builds")
                    #endif

                    Task {
                        #if DEBUG
                        // 检查是否需要生成大规模测试数据
                        if ProcessInfo.processInfo.environment["LARGE_SAMPLE_DATA"] == "true" {
                            print("🚀 检测到大规模样本数据环境变量，开始生成大规模测试数据...")
                            let largeSampleDataService = CustomerOutOfStockSampleDataService(
                                repositoryFactory: appDependencies.repositoryFactory
                            )
                            await largeSampleDataService.initializeLargeScaleSampleData()
                        } else {
                            print("📊 使用标准样本数据...")
                            // Initialize sample data on first launch using new repository pattern
                            await appDependencies.dataInitializationService.initializeSampleData()
                        }
                        #else
                        // 生产环境不加载任何样本数据
                        print("🏭 生产环境：跳过样本数据初始化")
                        #endif

                        // Initialize workshop data (colors, machines, batches)
                        await appDependencies.serviceFactory.machineDataInitializationService.initializeAllSampleData()
                        // Start ProductionBatchService for automatic batch execution
                        _ = appDependencies.productionBatchService // This will trigger lazy initialization and startService()
                    }
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }
    
    // MARK: - Environment Detection
    
    private func determineAppEnvironment() -> AppEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .development
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .testing
        } else {
            return .development
        }
        #else
        return .production
        #endif
    }
}
