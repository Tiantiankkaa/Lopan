//
//  LocalRepositoryFactory.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalRepositoryFactory: RepositoryFactory {
    private let modelContext: ModelContext
    
    lazy var userRepository: UserRepository = LocalUserRepository(modelContext: modelContext)
    lazy var customerRepository: CustomerRepository = LocalCustomerRepository(modelContext: modelContext)
    lazy var productRepository: ProductRepository = LocalProductRepository(modelContext: modelContext)
    lazy var customerOutOfStockRepository: CustomerOutOfStockRepository = LocalCustomerOutOfStockRepository(modelContext: modelContext)
    lazy var packagingRepository: PackagingRepository = LocalPackagingRepository(modelContext: modelContext)
    lazy var productionRepository: ProductionRepository = LocalProductionRepository(modelContext: modelContext)
    lazy var auditRepository: AuditRepository = LocalAuditRepository(modelContext: modelContext)
    lazy var machineRepository: MachineRepository = LocalMachineRepository(context: modelContext)
    lazy var colorRepository: ColorRepository = LocalColorRepository(modelContext: modelContext)
    lazy var productionBatchRepository: ProductionBatchRepository = LocalProductionBatchRepository(modelContext: modelContext)
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}