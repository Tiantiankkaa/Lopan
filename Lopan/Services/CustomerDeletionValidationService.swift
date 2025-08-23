//
//  CustomerDeletionValidationService.swift
//  Lopan
//
//  Created by Claude Code for Customer Deletion Safety
//

import Foundation
import SwiftData

@MainActor
class CustomerDeletionValidationService: ObservableObject {
    private let modelContext: ModelContext
    
    struct DeletionValidationResult {
        let canDelete: Bool
        let pendingOutOfStockCount: Int
        let completedOutOfStockCount: Int
        let totalOutOfStockCount: Int
        let warningMessage: String?
        let impactSummary: String
        let pendingRecords: [CustomerOutOfStock]
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func validateCustomerDeletion(_ customer: Customer) async throws -> DeletionValidationResult {
        // Fetch all CustomerOutOfStock records
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let allRecords = try modelContext.fetch(descriptor)
        
        // Filter records related to this customer
        let customerRecords = allRecords.filter { record in
            record.customer?.id == customer.id
        }
        
        let pendingRecords = customerRecords.filter { $0.status == .pending }
        let completedRecords = customerRecords.filter { $0.status == .completed }
        let cancelledRecords = customerRecords.filter { $0.status == .cancelled }
        
        let canDelete = pendingRecords.isEmpty
        let warningMessage = pendingRecords.isEmpty ? nil : 
            "该客户有 \(pendingRecords.count) 条待处理的缺货记录，删除后这些记录将变为孤立记录。"
        
        let impactSummary = buildImpactSummary(
            customer: customer,
            pendingCount: pendingRecords.count,
            completedCount: completedRecords.count,
            cancelledCount: cancelledRecords.count,
            totalCount: customerRecords.count
        )
        
        return DeletionValidationResult(
            canDelete: canDelete,
            pendingOutOfStockCount: pendingRecords.count,
            completedOutOfStockCount: completedRecords.count,
            totalOutOfStockCount: customerRecords.count,
            warningMessage: warningMessage,
            impactSummary: impactSummary,
            pendingRecords: pendingRecords
        )
    }
    
    func prepareCustomerForDeletion(_ customer: Customer) async throws {
        // Cache customer information in related out-of-stock records before deletion
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let allRecords = try modelContext.fetch(descriptor)
        let customerRecords = allRecords.filter { record in
            record.customer?.id == customer.id
        }
        
        for record in customerRecords {
            // Preserve customer information in notes for future reference
            let customerReference = "（原客户：\(customer.name) - \(customer.customerNumber)）"
            
            if let existingNotes = record.notes, !existingNotes.isEmpty {
                record.notes = existingNotes + " " + customerReference
            } else {
                record.notes = customerReference
            }
            
            // Nullify the customer reference to prevent crashes
            record.customer = nil
            record.updatedAt = Date()
        }
        
        try modelContext.save()
    }
    
    private func buildImpactSummary(customer: Customer, pendingCount: Int, completedCount: Int, cancelledCount: Int, totalCount: Int) -> String {
        var summary = "删除客户「\(customer.name)」的影响分析：\n\n"
        
        if totalCount == 0 {
            summary += "• 无相关缺货记录，可以安全删除"
        } else {
            summary += "• 相关缺货记录总计：\(totalCount) 条\n"
            
            if pendingCount > 0 {
                summary += "• 待处理记录：\(pendingCount) 条 ⚠️\n"
            }
            if completedCount > 0 {
                summary += "• 已完成记录：\(completedCount) 条\n"
            }
            if cancelledCount > 0 {
                summary += "• 已取消记录：\(cancelledCount) 条\n"
            }
            
            summary += "\n删除后，这些记录将保留但失去客户关联。"
            
            if pendingCount > 0 {
                summary += "\n\n⚠️ 建议：先处理完待处理的缺货记录再删除客户。"
            }
        }
        
        return summary
    }
}