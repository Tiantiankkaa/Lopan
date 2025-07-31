//
//  LocalCustomerOutOfStockRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalCustomerOutOfStockRepository: CustomerOutOfStockRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchOutOfStockRecords() async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock? {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try modelContext.fetch(descriptor)
        return records.first { $0.id == id }
    }
    
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try modelContext.fetch(descriptor)
        return records.filter { $0.customer?.id == customer.id }
    }
    
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock] {
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let records = try modelContext.fetch(descriptor)
        return records.filter { $0.product?.id == product.id }
    }
    
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        modelContext.insert(record)
        try modelContext.save()
    }
    
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        try modelContext.save()
    }
    
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        modelContext.delete(record)
        try modelContext.save()
    }
    
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws {
        for record in records {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}