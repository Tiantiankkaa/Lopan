//
//  RepositoryFactory.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

protocol RepositoryFactory {
    var userRepository: UserRepository { get }
    var customerRepository: CustomerRepository { get }
    var productRepository: ProductRepository { get }
    var customerOutOfStockRepository: CustomerOutOfStockRepository { get }
    var packagingRepository: PackagingRepository { get }
    var productionRepository: ProductionRepository { get }
    var auditRepository: AuditRepository { get }
    var machineRepository: MachineRepository { get }
    var colorRepository: ColorRepository { get }
    var productionBatchRepository: ProductionBatchRepository { get }
}