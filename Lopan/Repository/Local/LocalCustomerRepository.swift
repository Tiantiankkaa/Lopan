//
//  LocalCustomerRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalCustomerRepository: CustomerRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchCustomers() async throws -> [Customer] {
        let descriptor = FetchDescriptor<Customer>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchCustomer(by id: String) async throws -> Customer? {
        let descriptor = FetchDescriptor<Customer>()
        let customers = try modelContext.fetch(descriptor)
        return customers.first { $0.id == id }
    }
    
    func addCustomer(_ customer: Customer) async throws {
        modelContext.insert(customer)
        try modelContext.save()
    }
    
    func updateCustomer(_ customer: Customer) async throws {
        try modelContext.save()
    }
    
    func deleteCustomer(_ customer: Customer) async throws {
        // First, safely handle related CustomerOutOfStock records to prevent crashes
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let allRecords = try modelContext.fetch(descriptor)
        let relatedRecords = allRecords.filter { record in
            record.customer?.id == customer.id
        }
        
        // Cache customer information and nullify references to prevent dangling pointers
        for record in relatedRecords {
            // Preserve customer information in notes for audit trail
            let customerInfo = "（原客户：\(customer.name) - \(customer.customerNumber)）"
            if let existingNotes = record.notes, !existingNotes.isEmpty {
                record.notes = existingNotes + " " + customerInfo
            } else {
                record.notes = customerInfo
            }
            
            // Nullify the customer reference to prevent crashes when accessing deleted customer
            record.customer = nil
            record.updatedAt = Date()
        }
        
        // Now safe to delete the customer
        modelContext.delete(customer)
        try modelContext.save()
    }
    
    func deleteCustomers(_ customers: [Customer]) async throws {
        // Handle multiple customer deletions safely
        let descriptor = FetchDescriptor<CustomerOutOfStock>()
        let allRecords = try modelContext.fetch(descriptor)
        
        for customer in customers {
            // Find related records for each customer
            let relatedRecords = allRecords.filter { record in
                record.customer?.id == customer.id
            }
            
            // Cache customer information and nullify references
            for record in relatedRecords {
                let customerInfo = "（原客户：\(customer.name) - \(customer.customerNumber)）"
                if let existingNotes = record.notes, !existingNotes.isEmpty {
                    record.notes = existingNotes + " " + customerInfo
                } else {
                    record.notes = customerInfo
                }
                record.customer = nil
                record.updatedAt = Date()
            }
            
            // Delete the customer
            modelContext.delete(customer)
        }
        
        try modelContext.save()
    }
    
    func searchCustomers(query: String) async throws -> [Customer] {
        let descriptor = FetchDescriptor<Customer>()
        let customers = try modelContext.fetch(descriptor)
        
        return customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(query) ||
            customer.address.localizedCaseInsensitiveContains(query) ||
            customer.phone.localizedCaseInsensitiveContains(query)
        }
    }
}