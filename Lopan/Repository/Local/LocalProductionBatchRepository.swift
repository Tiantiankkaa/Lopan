//
//  LocalProductionBatchRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
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
    
    func deleteBatch(id: String) async throws {
        guard let batch = try await fetchBatchById(id) else {
            throw RepositoryError.notFound("ProductionBatch with id \(id) not found")
        }
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
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Batch Number Generation Support
    
    func fetchLatestBatchNumber(forDate dateString: String, batchType: BatchType) async throws -> String? {
        let batchPrefix = "\(batchType.prefix)-\(dateString)-"
        let allBatches = try await fetchAllBatches()
        
        // Filter batches that match the date and type prefix
        let matchingBatches = allBatches.filter { batch in
            batch.batchNumber.hasPrefix(batchPrefix)
        }
        
        // Extract sequence numbers and find the highest one
        var maxSequence = 0
        for batch in matchingBatches {
            let batchNumber = batch.batchNumber
            if let suffixRange = batchNumber.range(of: batchPrefix) {
                let suffix = String(batchNumber[suffixRange.upperBound...])
                if let sequenceNumber = Int(suffix) {
                    maxSequence = max(maxSequence, sequenceNumber)
                }
            }
        }
        
        return maxSequence > 0 ? "\(batchPrefix)\(String(format: "%04d", maxSequence))" : nil
    }
    
    // MARK: - Shift-aware Batch Operations Implementation (班次感知批次操作实现)
    
    func fetchBatches(forDate date: Date, shift: Shift) async throws -> [ProductionBatch] {
        // Use a simpler approach due to Predicate complexity issues
        let allBatches = try await fetchAllBatches()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return allBatches.filter { batch in
            guard let targetDate = batch.targetDate,
                  let batchShift = batch.shift else { return false }
            
            return targetDate >= startOfDay && 
                   targetDate < endOfDay && 
                   batchShift == shift
        }.sorted { $0.submittedAt > $1.submittedAt }
    }
    
    func fetchBatches(forDate date: Date) async throws -> [ProductionBatch] {
        // Use a simpler approach due to Predicate complexity issues
        let allBatches = try await fetchAllBatches()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return allBatches.filter { batch in
            guard let targetDate = batch.targetDate else { return false }
            return targetDate >= startOfDay && targetDate < endOfDay
        }.sorted { $0.submittedAt > $1.submittedAt }
    }
    
    func fetchShiftAwareBatches() async throws -> [ProductionBatch] {
        // Use a simpler approach due to Predicate complexity issues
        let allBatches = try await fetchAllBatches()
        return allBatches.filter { batch in
            return batch.targetDate != nil && batch.shift != nil
        }
    }
    
    
    func fetchBatches(from startDate: Date, to endDate: Date, shift: Shift?) async throws -> [ProductionBatch] {
        // Use a simpler approach due to Predicate complexity issues
        let allBatches = try await fetchAllBatches()
        
        return allBatches.filter { batch in
            guard let targetDate = batch.targetDate else { return false }
            
            let isInDateRange = targetDate >= startDate && targetDate <= endDate
            
            if let requiredShift = shift {
                return isInDateRange && batch.shift == requiredShift
            } else {
                return isInDateRange
            }
        }
    }
    
    func hasConflictingBatches(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool {
        // Use a simpler approach due to Predicate complexity issues
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let allBatches = try await fetchAllBatches()
        
        let conflicts = allBatches.filter { batch in
            guard let targetDate = batch.targetDate,
                  let batchShift = batch.shift else { return false }
            
            // Check if it's in the same date range and shift
            let isInSameDateShift = targetDate >= startOfDay && 
                                  targetDate < endOfDay && 
                                  batchShift == shift
            
            // Check if it's the same machine
            let isSameMachine = batch.machineId == machineId
            
            // Check if it's not the excluded batch
            let isNotExcluded = excludingBatchId == nil || batch.id != excludingBatchId!
            
            // Check if it's not rejected or completed
            let isActive = batch.status != .rejected && batch.status != .completed
            
            return isInSameDateShift && isSameMachine && isNotExcluded && isActive
        }
        
        return !conflicts.isEmpty
    }
    
    func fetchBatchesRequiringMigration() async throws -> [ProductionBatch] {
        // Use a simpler approach due to Predicate complexity issues
        let allBatches = try await fetchAllBatches()
        return allBatches.filter { batch in
            // Legacy batches that could be migrated
            return (batch.targetDate == nil || batch.shift == nil) && 
                   batch.status == .unsubmitted
        }
    }
    
    // MARK: - Optimized Query Methods Implementation (优化查询方法实现)
    
    func fetchActiveBatchForMachine(_ machineId: String) async throws -> ProductionBatch? {
        let activeBatches = try await fetchActiveBatches()
        return activeBatches.first { $0.machineId == machineId }
    }
    
    func fetchLatestBatchForMachineAndShift(machineId: String, date: Date, shift: Shift) async throws -> ProductionBatch? {
        let batches = try await fetchBatches(forDate: date, shift: shift)
        let machineBatches = batches.filter { $0.machineId == machineId }
        return machineBatches.first // Already sorted by submittedAt desc in fetchBatches
    }
    
    func fetchActiveBatchesWithStatus(_ statuses: [BatchStatus]) async throws -> [ProductionBatch] {
        let allBatches = try await fetchAllBatches()
        return allBatches.filter { batch in
            statuses.contains(batch.status)
        }.sorted { $0.submittedAt > $1.submittedAt }
    }
    
    func fetchBatchesForMachine(_ machineId: String, statuses: [BatchStatus], from startDate: Date? = nil, to endDate: Date? = nil) async throws -> [ProductionBatch] {
        let allBatches = try await fetchAllBatches()
        
        return allBatches.filter { batch in
            // Filter by machine
            guard batch.machineId == machineId else { return false }
            
            // Filter by status
            guard statuses.contains(batch.status) else { return false }
            
            // Filter by date range if provided
            if let startDate = startDate, let endDate = endDate, let targetDate = batch.targetDate {
                let calendar = Calendar.current
                let startOfStartDate = calendar.startOfDay(for: startDate)
                let endOfEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
                
                return targetDate >= startOfStartDate && targetDate < endOfEndDate
            }
            
            return true
        }.sorted { $0.submittedAt > $1.submittedAt }
    }
}