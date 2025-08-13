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
    func deleteBatch(id: String) async throws
    func fetchPendingBatches() async throws -> [ProductionBatch]
    func fetchActiveBatches() async throws -> [ProductionBatch]
    func fetchBatchHistory(limit: Int?) async throws -> [ProductionBatch]
    
    // Product Config operations
    func addProductConfig(_ productConfig: ProductConfig, toBatch batchId: String) async throws
    func updateProductConfig(_ productConfig: ProductConfig) async throws
    func removeProductConfig(_ productConfig: ProductConfig) async throws
    func fetchProductConfigs(forBatch batchId: String) async throws -> [ProductConfig]
    
    // Batch number generation support
    func fetchLatestBatchNumber(forDate dateString: String) async throws -> String?
    
    // MARK: - Shift-aware Batch Operations (班次感知批次操作)
    
    /// Fetch batches by target date and shift
    /// 按目标日期和班次获取批次
    func fetchBatches(forDate date: Date, shift: Shift) async throws -> [ProductionBatch]
    
    /// Fetch batches by target date (all shifts)
    /// 按目标日期获取批次（所有班次）
    func fetchBatches(forDate date: Date) async throws -> [ProductionBatch]
    
    /// Fetch shift-aware batches only
    /// 仅获取班次感知批次
    func fetchShiftAwareBatches() async throws -> [ProductionBatch]
    
    /// Fetch legacy batches only
    /// 仅获取传统批次
    func fetchLegacyBatches() async throws -> [ProductionBatch]
    
    /// Fetch batches in date range with optional shift filter
    /// 获取日期范围内的批次，可选班次过滤
    func fetchBatches(from startDate: Date, to endDate: Date, shift: Shift?) async throws -> [ProductionBatch]
    
    /// Check if there are conflicting batches for the same date/shift/machine
    /// 检查同一日期/班次/机器是否有冲突的批次
    func hasConflictingBatches(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool
    
    /// Fetch batches requiring migration to shift-aware format
    /// 获取需要迁移为班次感知格式的批次
    func fetchBatchesRequiringMigration() async throws -> [ProductionBatch]
}