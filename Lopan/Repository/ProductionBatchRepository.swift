//
//  ProductionBatchRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

protocol ProductionBatchRepository {
    func fetchAllBatches() async throws -> [ProductionBatch]
    func fetchBatchesByStatus(_ status: BatchStatus) async throws -> [ProductionBatch]
    func fetchBatchesByMachine(_ machineId: String) async throws -> [ProductionBatch]
    func fetchBatchById(_ id: String) async throws -> ProductionBatch?
    func addBatch(_ batch: ProductionBatch) async throws
    func updateBatch(_ batch: ProductionBatch) async throws
    func deleteBatch(_ batch: ProductionBatch) async throws
    func fetchPendingBatches() async throws -> [ProductionBatch]
    func fetchActiveBatches() async throws -> [ProductionBatch]
    func fetchBatchHistory(limit: Int?) async throws -> [ProductionBatch]
    
    // Product Config operations
    func addProductConfig(_ productConfig: ProductConfig, toBatch batchId: String) async throws
    func updateProductConfig(_ productConfig: ProductConfig) async throws
    func removeProductConfig(_ productConfig: ProductConfig) async throws
    func fetchProductConfigs(forBatch batchId: String) async throws -> [ProductConfig]
}