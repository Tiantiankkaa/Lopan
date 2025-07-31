//
//  CustomerService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
@Observable
class CustomerService {
    private let customerRepository: CustomerRepository
    private let auditingService: NewAuditingService
    
    var customers: [Customer] = []
    var isLoading = false
    var error: Error?
    
    init(repositoryFactory: RepositoryFactory) {
        self.customerRepository = repositoryFactory.customerRepository
        self.auditingService = NewAuditingService(repositoryFactory: repositoryFactory)
    }
    
    func loadCustomers() async {
        isLoading = true
        error = nil
        
        do {
            customers = try await customerRepository.fetchCustomers()
        } catch {
            self.error = error
            print("❌ Error loading customers: \(error)")
        }
        
        isLoading = false
    }
    
    func addCustomer(_ customer: Customer, createdBy: String) async -> Bool {
        do {
            try await customerRepository.addCustomer(customer)
            await loadCustomers() // Refresh the list
            
            // Log the creation
            await auditingService.logCreate(
                entityType: .customer,
                entityId: customer.id,
                entityDescription: customer.name,
                operatorUserId: createdBy,
                operatorUserName: createdBy,
                createdData: [
                    "name": customer.name,
                    "address": customer.address,
                    "phone": customer.phone
                ]
            )
            
            return true
        } catch {
            self.error = error
            print("❌ Error adding customer: \(error)")
            return false
        }
    }
    
    func updateCustomer(_ customer: Customer, updatedBy: String, beforeData: [String: Any]) async -> Bool {
        do {
            try await customerRepository.updateCustomer(customer)
            await loadCustomers() // Refresh the list
            
            // Log the update
            await auditingService.logUpdate(
                entityType: .customer,
                entityId: customer.id,
                entityDescription: customer.name,
                operatorUserId: updatedBy,
                operatorUserName: updatedBy,
                beforeData: beforeData,
                afterData: [
                    "name": customer.name,
                    "address": customer.address,
                    "phone": customer.phone
                ] as [String: Any],
                changedFields: ["name", "address", "phone"] // Could be more sophisticated
            )
            
            return true
        } catch {
            self.error = error
            print("❌ Error updating customer: \(error)")
            return false
        }
    }
    
    func deleteCustomer(_ customer: Customer, deletedBy: String) async -> Bool {
        do {
            // Log before deletion
            await auditingService.logDelete(
                entityType: .customer,
                entityId: customer.id,
                entityDescription: customer.name,
                operatorUserId: deletedBy,
                operatorUserName: deletedBy,
                deletedData: [
                    "name": customer.name,
                    "address": customer.address,
                    "phone": customer.phone
                ]
            )
            
            try await customerRepository.deleteCustomer(customer)
            await loadCustomers() // Refresh the list
            
            return true
        } catch {
            self.error = error
            print("❌ Error deleting customer: \(error)")
            return false
        }
    }
    
    func deleteCustomers(_ customers: [Customer], deletedBy: String) async -> Bool {
        do {
            let batchId = UUID().uuidString
            
            // Log batch operation
            await auditingService.logBatchOperation(
                operationType: .delete,
                entityType: .customer,
                batchId: batchId,
                operatorUserId: deletedBy,
                operatorUserName: deletedBy,
                affectedEntityIds: customers.map { $0.id },
                operationSummary: [
                    "operation": "batch_delete_customers",
                    "count": customers.count,
                    "customer_names": customers.map { $0.name }
                ]
            )
            
            try await customerRepository.deleteCustomers(customers)
            await loadCustomers() // Refresh the list
            
            return true
        } catch {
            self.error = error
            print("❌ Error deleting customers: \(error)")
            return false
        }
    }
    
    func searchCustomers(query: String) async -> [Customer] {
        if query.isEmpty {
            return customers
        }
        
        do {
            return try await customerRepository.searchCustomers(query: query)
        } catch {
            self.error = error
            print("❌ Error searching customers: \(error)")
            return []
        }
    }
}