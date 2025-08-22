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
    
    lazy var customerOutOfStockService: CustomerOutOfStockService = {
        let service = CustomerOutOfStockService(
            repositoryFactory: repositoryFactory,
            auditService: auditingService,
            authService: authenticationService
        )
        return service
    }()
    lazy var dataInitializationService = NewDataInitializationService(repositoryFactory: repositoryFactory)
    lazy var machineService: MachineService = {
        let service = MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditingService,
            authService: authenticationService,
            notificationEngine: notificationEngine,
            permissionService: advancedPermissionService
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
    
    lazy var productionBatchService: ProductionBatchService = {
        let service = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditingService,
            authService: authenticationService,
            machineService: machineService,
            notificationEngine: notificationEngine,
            permissionService: advancedPermissionService
        )
        registerForCleanup(service)
        // Start the service to enable automatic batch execution
        service.startService()
        return service
    }()
    
    // MARK: - Phase 2 Enhanced Services
    
    lazy var batchMachineCoordinator: StandardBatchMachineCoordinator = {
        let coordinator = StandardBatchMachineCoordinator(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditingService,
            authService: authenticationService
        )
        return coordinator
    }()
    
    lazy var cacheWarmingService: CacheWarmingService = {
        let service = CacheWarmingService(
            batchMachineCoordinator: batchMachineCoordinator,
            warmingStrategy: CombinedStrategy(strategies: [
                ActiveMachineStrategy(machineRepository: repositoryFactory.machineRepository), 
                RecentActivityStrategy(productionBatchRepository: repositoryFactory.productionBatchRepository)
            ]),
            auditService: auditingService,
            authService: authenticationService
        )
        return service
    }()
    
    lazy var machineStateSynchronizationService: MachineStateSynchronizationService = {
        let service = MachineStateSynchronizationService(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            batchMachineCoordinator: batchMachineCoordinator,
            auditService: auditingService,
            authService: authenticationService
        )
        return service
    }()
    
    lazy var systemConsistencyMonitoringService: SystemConsistencyMonitoringService = {
        let service = SystemConsistencyMonitoringService(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            batchMachineCoordinator: batchMachineCoordinator,
            synchronizationService: machineStateSynchronizationService,
            cacheWarmingService: cacheWarmingService,
            auditService: auditingService,
            authService: authenticationService
        )
        return service
    }()
    
    lazy var enhancedSecurityAuditService: EnhancedSecurityAuditService = {
        let service = EnhancedSecurityAuditService(
            baseAuditService: auditingService,
            authService: authenticationService
        )
        return service
    }()
    
    // MARK: - Phase 3 Analytics Services
    
    lazy var productionAnalyticsEngine: ProductionAnalyticsEngine = {
        let engine = ProductionAnalyticsEngine(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditingService,
            authService: authenticationService
        )
        return engine
    }()
    
    lazy var advancedReportGenerator: AdvancedReportGenerator = {
        let generator = AdvancedReportGenerator(
            analyticsEngine: productionAnalyticsEngine,
            auditService: enhancedSecurityAuditService,
            authService: authenticationService
        )
        return generator
    }()
    
    // MARK: - Phase 3 Notification Services
    
    lazy var notificationEngine: NotificationEngine = {
        let engine = NotificationEngine(
            auditService: auditingService,
            authService: authenticationService
        )
        return engine
    }()
    
    lazy var realTimeAlertService: RealTimeAlertService = {
        let service = RealTimeAlertService(
            notificationEngine: notificationEngine,
            auditService: auditingService,
            authService: authenticationService,
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository
        )
        return service
    }()
    
    // MARK: - Phase 3 Permission Services
    
    lazy var advancedPermissionService: AdvancedPermissionService = {
        let service = AdvancedPermissionService(
            authService: authenticationService,
            auditService: auditingService
        )
        return service
    }()
    
    lazy var roleManagementService: RoleManagementService = {
        let service = RoleManagementService(
            authService: authenticationService,
            auditService: auditingService,
            permissionService: advancedPermissionService
        )
        return service
    }()
    
    // MARK: - Phase 3 Data Management Services
    
    lazy var dataExportEngine: DataExportEngine = {
        let engine = DataExportEngine(
            repositoryFactory: repositoryFactory,
            auditService: auditingService,
            authService: authenticationService,
            permissionService: advancedPermissionService
        )
        return engine
    }()
    
    lazy var dataBackupService: DataBackupService = {
        let service = DataBackupService(
            repositoryFactory: repositoryFactory,
            exportEngine: dataExportEngine,
            auditService: auditingService,
            authService: authenticationService,
            permissionService: advancedPermissionService,
            notificationEngine: notificationEngine
        )
        return service
    }()
    
    lazy var dataImportEngine: DataImportEngine = {
        let engine = DataImportEngine(
            repositoryFactory: repositoryFactory,
            auditService: auditingService,
            authService: authenticationService,
            permissionService: advancedPermissionService,
            backupService: dataBackupService
        )
        return engine
    }()
    
    // MARK: - Phase 3 Configuration Management Services
    
    lazy var systemConfigurationService: SystemConfigurationService = {
        let service = SystemConfigurationService(
            auditService: auditingService,
            authService: authenticationService,
            permissionService: advancedPermissionService,
            notificationEngine: notificationEngine
        )
        return service
    }()
    
    lazy var configurationSecurityService: ConfigurationSecurityService = {
        let service = ConfigurationSecurityService(
            configurationService: systemConfigurationService,
            auditService: auditingService,
            authService: authenticationService,
            permissionService: advancedPermissionService
        )
        return service
    }()
    
    // MARK: - Phase 3 Error Handling and Recovery Services
    
    lazy var unifiedErrorHandlingService: UnifiedErrorHandlingService = {
        let service = UnifiedErrorHandlingService(
            auditService: auditingService,
            authService: authenticationService,
            notificationEngine: notificationEngine
        )
        return service
    }()
    
    lazy var faultDetectionAndRecoveryService: FaultDetectionAndRecoveryService = {
        let service = FaultDetectionAndRecoveryService(
            repositoryFactory: repositoryFactory,
            errorHandlingService: unifiedErrorHandlingService,
            auditService: auditingService,
            authService: authenticationService,
            notificationEngine: notificationEngine,
            permissionService: advancedPermissionService
        )
        return service
    }()
    
    lazy var healthCheckAndMonitoringService: HealthCheckAndMonitoringService = {
        let service = HealthCheckAndMonitoringService(
            repositoryFactory: repositoryFactory,
            faultDetectionService: faultDetectionAndRecoveryService,
            errorHandlingService: unifiedErrorHandlingService,
            auditService: auditingService,
            authService: authenticationService,
            notificationEngine: notificationEngine,
            permissionService: advancedPermissionService
        )
        return service
    }()
    
    lazy var productionDeploymentService: ProductionDeploymentService = {
        let service = ProductionDeploymentService(
            healthMonitoringService: healthCheckAndMonitoringService,
            faultDetectionService: faultDetectionAndRecoveryService,
            errorHandlingService: unifiedErrorHandlingService,
            configurationSecurityService: configurationSecurityService,
            dataBackupService: dataBackupService,
            auditService: auditingService,
            authService: authenticationService,
            notificationEngine: notificationEngine,
            permissionService: advancedPermissionService
        )
        return service
    }()
    
    // MARK: - Workshop Manager Service Provider
    
    lazy var workshopManagerServiceProvider: WorkshopManagerServiceProvider = {
        let provider = WorkshopManagerServiceProvider(
            repositoryFactory: repositoryFactory,
            authService: authenticationService,
            auditService: auditingService
        )
        return provider
    }()
    
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