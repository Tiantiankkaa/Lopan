//
//  ProductService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
@Observable
class ProductService {
    private let productRepository: ProductRepository
    private let auditingService: NewAuditingService
    
    var products: [Product] = []
    var isLoading = false
    var error: Error?
    
    init(repositoryFactory: RepositoryFactory) {
        self.productRepository = repositoryFactory.productRepository
        self.auditingService = NewAuditingService(repositoryFactory: repositoryFactory)
    }
    
    func loadProducts() async {
        isLoading = true
        error = nil
        
        do {
            products = try await productRepository.fetchProducts()
        } catch {
            self.error = error
            print("❌ Error loading products: \(error)")
        }
        
        isLoading = false
    }
    
    func addProduct(_ product: Product, createdBy: String) async -> Bool {
        do {
            try await productRepository.addProduct(product)
            await loadProducts() // Refresh the list
            
            // Log the creation
            await auditingService.logCreate(
                entityType: .product,
                entityId: product.id,
                entityDescription: product.name,
                operatorUserId: createdBy,
                operatorUserName: createdBy,
                createdData: [
                    "name": product.name,
                    "colors": product.colors,
                    "sizes_count": product.sizes?.count ?? 0
                ]
            )
            
            return true
        } catch {
            self.error = error
            print("❌ Error adding product: \(error)")
            return false
        }
    }
    
    func updateProduct(_ product: Product, updatedBy: String, beforeData: [String: Any]) async -> Bool {
        do {
            try await productRepository.updateProduct(product)
            await loadProducts() // Refresh the list
            
            // Log the update
            await auditingService.logUpdate(
                entityType: .product,
                entityId: product.id,
                entityDescription: product.name,
                operatorUserId: updatedBy,
                operatorUserName: updatedBy,
                beforeData: beforeData,
                afterData: [
                    "name": product.name,
                    "colors": product.colors,
                    "sizes_count": product.sizes?.count ?? 0
                ] as [String: Any],
                changedFields: ["name", "colors", "sizes"]
            )
            
            return true
        } catch {
            self.error = error
            print("❌ Error updating product: \(error)")
            return false
        }
    }
    
    func deleteProduct(_ product: Product, deletedBy: String) async -> Bool {
        do {
            // Log before deletion
            await auditingService.logDelete(
                entityType: .product,
                entityId: product.id,
                entityDescription: product.name,
                operatorUserId: deletedBy,
                operatorUserName: deletedBy,
                deletedData: [
                    "name": product.name,
                    "colors": product.colors,
                    "sizes_count": product.sizes?.count ?? 0
                ]
            )
            
            try await productRepository.deleteProduct(product)
            await loadProducts() // Refresh the list
            
            return true
        } catch {
            self.error = error
            print("❌ Error deleting product: \(error)")
            return false
        }
    }
    
    func deleteProducts(_ products: [Product], deletedBy: String) async -> Bool {
        do {
            let batchId = UUID().uuidString
            
            // Log batch operation
            await auditingService.logBatchOperation(
                operationType: .delete,
                entityType: .product,
                batchId: batchId,
                operatorUserId: deletedBy,
                operatorUserName: deletedBy,
                affectedEntityIds: products.map { $0.id },
                operationSummary: [
                    "operation": "batch_delete_products",
                    "count": products.count,
                    "product_names": products.map { $0.name }
                ]
            )
            
            try await productRepository.deleteProducts(products)
            await loadProducts() // Refresh the list
            
            return true
        } catch {
            self.error = error
            print("❌ Error deleting products: \(error)")
            return false
        }
    }
    
    func searchProducts(query: String) async -> [Product] {
        if query.isEmpty {
            return products
        }
        
        do {
            return try await productRepository.searchProducts(query: query)
        } catch {
            self.error = error
            print("❌ Error searching products: \(error)")
            return []
        }
    }
}