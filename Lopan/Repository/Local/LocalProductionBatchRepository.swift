//
//  LocalProductionBatchRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

class LocalProductionBatchRepository: ProductionBatchRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAllBatches() async throws -> [ProductionBatch] {
        let descriptor = FetchDescriptor<ProductionBatch>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchBatchesByStatus(_ status: BatchStatus) async throws -> [ProductionBatch] {
        let statusRawValue = status.rawValue
        let descriptor = FetchDescriptor<ProductionBatch>(
            predicate: #Predicate { $0.status.rawValue == statusRawValue },
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchBatchesByMachine(_ machineId: String) async throws -> [ProductionBatch] {
        let descriptor = FetchDescriptor<ProductionBatch>(
            predicate: #Predicate { $0.machineId == machineId },
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchBatchById(_ id: String) async throws -> ProductionBatch? {
        let descriptor = FetchDescriptor<ProductionBatch>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func addBatch(_ batch: ProductionBatch) async throws {
        modelContext.insert(batch)
        try modelContext.save()
    }
    
    func updateBatch(_ batch: ProductionBatch) async throws {
        batch.updatedAt = Date()
        try modelContext.save()
    }
    
    func deleteBatch(_ batch: ProductionBatch) async throws {
        modelContext.delete(batch)
        try modelContext.save()
    }
    
    func fetchPendingBatches() async throws -> [ProductionBatch] {
        // Alternative implementation to avoid predicate issues
        let allBatches = try await fetchAllBatches()
        return allBatches.filter { $0.status == .pending }
    }
    
    func fetchActiveBatches() async throws -> [ProductionBatch] {
        // Alternative implementation to avoid predicate issues
        let allBatches = try await fetchAllBatches()
        return allBatches.filter { $0.status == .active }
    }
    
    func fetchBatchHistory(limit: Int? = nil) async throws -> [ProductionBatch] {
        var descriptor = FetchDescriptor<ProductionBatch>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Product Config Operations
    func addProductConfig(_ productConfig: ProductConfig, toBatch batchId: String) async throws {
        productConfig.batchId = batchId
        modelContext.insert(productConfig)
        try modelContext.save()
    }
    
    func updateProductConfig(_ productConfig: ProductConfig) async throws {
        productConfig.updatedAt = Date()
        try modelContext.save()
    }
    
    func removeProductConfig(_ productConfig: ProductConfig) async throws {
        modelContext.delete(productConfig)
        try modelContext.save()
    }
    
    func fetchProductConfigs(forBatch batchId: String) async throws -> [ProductConfig] {
        let descriptor = FetchDescriptor<ProductConfig>(
            predicate: #Predicate { $0.batchId == batchId },
            sortBy: [SortDescriptor(\.priority), SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }
}