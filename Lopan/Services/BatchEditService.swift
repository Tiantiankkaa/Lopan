//
//  BatchEditService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/14.
//

import Foundation
import SwiftUI

/// Service for managing batch data in edit views
/// 用于在编辑视图中管理批次数据的服务
@MainActor
class BatchEditService: ObservableObject {
    
    // MARK: - Published Properties (发布属性)
    
    @Published var batchInfo: BatchDetailInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties (私有属性)
    
    private let batchId: String
    private let repository: ProductionBatchRepository
    
    // MARK: - Initialization (初始化)
    
    init(batchId: String, repository: ProductionBatchRepository) {
        self.batchId = batchId
        self.repository = repository
    }
    
    // MARK: - Public Methods (公共方法)
    
    /// Load batch information from repository
    /// 从仓储加载批次信息
    func loadBatch() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let batch = try await repository.fetchBatchById(batchId) {
                batchInfo = BatchDetailInfo(from: batch)
            } else {
                errorMessage = "批次不存在或已被删除"
            }
        } catch {
            errorMessage = "加载批次失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Refresh batch information
    /// 刷新批次信息
    func refreshBatch() async {
        await loadBatch()
    }
    
    /// Check if batch exists and is valid
    /// 检查批次是否存在且有效
    var isValidBatch: Bool {
        return batchInfo != nil && errorMessage == nil
    }
    
    /// Get current batch ID
    /// 获取当前批次ID
    var currentBatchId: String {
        return batchId
    }
}