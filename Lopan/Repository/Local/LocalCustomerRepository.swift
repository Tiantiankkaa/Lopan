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
        modelContext.delete(customer)
        try modelContext.save()
    }
    
    func deleteCustomers(_ customers: [Customer]) async throws {
        for customer in customers {
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