//
//  WorkshopManagerServiceProvider.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/15.
//

import Foundation
import SwiftUI
import SwiftData

/// 车间经理工作台服务提供者
/// Centralized service provider for Workshop Manager module
@MainActor
public class WorkshopManagerServiceProvider: ObservableObject {
    
    // MARK: - Dependencies
    let repositoryFactory: RepositoryFactory
    let authService: AuthenticationService
    let auditService: NewAuditingService
    
    // MARK: - Service Instances
    private var _batchService: ProductionBatchService?
    private var _colorService: ColorService?
    private var _machineService: MachineService?
    private var _productService: ProductService?
    private var _batchEditPermissionService: StandardBatchEditPermissionService?
    private var _batchMachineCoordinator: StandardBatchMachineCoordinator?
    private var _cacheWarmingService: CacheWarmingService?
    private var _synchronizationService: MachineStateSynchronizationService?
    private var _systemMonitoringService: SystemConsistencyMonitoringService?
    private var _enhancedSecurityService: EnhancedSecurityAuditService?
    
    // MARK: - Initialization
    init(repositoryFactory: RepositoryFactory,
         authService: AuthenticationService,
         auditService: NewAuditingService) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
    }
    
    // MARK: - Service Accessors
    
    /// 生产批次服务
    /// Production batch service
    var batchService: ProductionBatchService {
        if _batchService == nil {
            _batchService = ProductionBatchService(
                productionBatchRepository: repositoryFactory.productionBatchRepository,
                machineRepository: repositoryFactory.machineRepository,
                colorRepository: repositoryFactory.colorRepository,
                auditService: auditService,
                authService: authService
            )
        }
        return _batchService!
    }
    
    /// 颜色服务
    /// Color service
    var colorService: ColorService {
        if _colorService == nil {
            _colorService = ColorService(
                colorRepository: repositoryFactory.colorRepository,
                machineRepository: repositoryFactory.machineRepository,
                auditService: auditService,
                authService: authService
            )
        }
        return _colorService!
    }
    
    /// 设备服务
    /// Machine service
    var machineService: MachineService {
        if _machineService == nil {
            _machineService = MachineService(
                machineRepository: repositoryFactory.machineRepository,
                auditService: auditService,
                authService: authService
            )
        }
        return _machineService!
    }
    
    /// 产品服务
    /// Product service
    var productService: ProductService {
        if _productService == nil {
            _productService = ProductService(
                repositoryFactory: repositoryFactory
            )
        }
        return _productService!
    }
    
    /// 批次编辑权限服务
    /// Batch edit permission service
    var batchEditPermissionService: StandardBatchEditPermissionService {
        if _batchEditPermissionService == nil {
            _batchEditPermissionService = StandardBatchEditPermissionService(
                authService: authService
            )
        }
        return _batchEditPermissionService!
    }
    
    /// Batch machine coordinator
    var batchMachineCoordinator: StandardBatchMachineCoordinator {
        if _batchMachineCoordinator == nil {
            _batchMachineCoordinator = StandardBatchMachineCoordinator(
                machineRepository: repositoryFactory.machineRepository,
                productionBatchRepository: repositoryFactory.productionBatchRepository,
                auditService: auditService,
                authService: authService
            )
        }
        return _batchMachineCoordinator!
    }
    
    /// Cache warming service
    var cacheWarmingService: CacheWarmingService {
        if _cacheWarmingService == nil {
            _cacheWarmingService = CacheWarmingServiceFactory.createService(
                batchMachineCoordinator: batchMachineCoordinator,
                machineRepository: repositoryFactory.machineRepository,
                productionBatchRepository: repositoryFactory.productionBatchRepository,
                auditService: auditService,
                authService: authService,
                strategy: .combined
            )
        }
        return _cacheWarmingService!
    }
    
    /// Synchronization service
    var synchronizationService: MachineStateSynchronizationService {
        if _synchronizationService == nil {
            _synchronizationService = MachineStateSynchronizationService(
                machineRepository: repositoryFactory.machineRepository,
                productionBatchRepository: repositoryFactory.productionBatchRepository,
                batchMachineCoordinator: batchMachineCoordinator,
                auditService: auditService,
                authService: authService
            )
        }
        return _synchronizationService!
    }
    
    /// System monitoring service
    var systemMonitoringService: SystemConsistencyMonitoringService {
        if _systemMonitoringService == nil {
            _systemMonitoringService = SystemConsistencyMonitoringService(
                machineRepository: repositoryFactory.machineRepository,
                productionBatchRepository: repositoryFactory.productionBatchRepository,
                batchMachineCoordinator: batchMachineCoordinator,
                synchronizationService: synchronizationService,
                cacheWarmingService: cacheWarmingService,
                auditService: auditService,
                authService: authService
            )
        }
        return _systemMonitoringService!
    }
    
    /// Enhanced security audit service
    var enhancedSecurityService: EnhancedSecurityAuditService {
        if _enhancedSecurityService == nil {
            _enhancedSecurityService = EnhancedSecurityAuditService(
                baseAuditService: auditService,
                authService: authService
            )
        }
        return _enhancedSecurityService!
    }
    
    // MARK: - Service Management
    
    /// 清理所有服务
    /// Clean up all services
    func cleanup() {
        _batchService = nil
        _colorService = nil
        _machineService = nil
        _productService = nil
        _batchEditPermissionService = nil
    }
    
    /// 刷新所有服务数据
    /// Refresh all service data
    func refreshAllData() async {
        await withTaskGroup(of: Void.self) { group in
            if let batchService = _batchService {
                group.addTask {
                    await batchService.loadBatches()
                    await batchService.loadPendingBatches()
                }
            }
            
            if let colorService = _colorService {
                group.addTask {
                    await colorService.loadColors()
                }
            }
            
            if let machineService = _machineService {
                group.addTask {
                    await machineService.loadMachines()
                }
            }
            
            if let productService = _productService {
                group.addTask {
                    await productService.loadProducts()
                }
            }
        }
    }
}

// MARK: - Environment Key

/// Environment key for WorkshopManagerServiceProvider
struct WorkshopManagerServiceProviderKey: EnvironmentKey {
    static let defaultValue: WorkshopManagerServiceProvider? = nil
}

extension EnvironmentValues {
    var workshopServiceProvider: WorkshopManagerServiceProvider? {
        get { self[WorkshopManagerServiceProviderKey.self] }
        set { self[WorkshopManagerServiceProviderKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// 设置车间经理服务提供者到环境中
    /// Set workshop manager service provider in environment
    func workshopServiceProvider(_ provider: WorkshopManagerServiceProvider) -> some View {
        self.environment(\.workshopServiceProvider, provider)
    }
}

// MARK: - Factory Methods

extension WorkshopManagerServiceProvider {
    /// 创建用于预览的服务提供者
    /// Create service provider for previews
    static func forPreview() -> WorkshopManagerServiceProvider {
        let schema = Schema([ProductionBatch.self, WorkshopMachine.self, User.self, AuditLog.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        return WorkshopManagerServiceProvider(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
    
    /// 创建用于测试的服务提供者
    /// Create service provider for testing
    static func forTesting(
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        auditService: NewAuditingService
    ) -> WorkshopManagerServiceProvider {
        return WorkshopManagerServiceProvider(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}
