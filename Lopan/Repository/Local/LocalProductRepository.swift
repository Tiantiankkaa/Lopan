//
//  LocalProductRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalProductRepository: ProductRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchProducts() async throws -> [Product] {
        let descriptor = FetchDescriptor<Product>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchProduct(by id: String) async throws -> Product? {
        let descriptor = FetchDescriptor<Product>()
        let products = try modelContext.fetch(descriptor)
        return products.first { $0.id == id }
    }
    
    func addProduct(_ product: Product) async throws {
        modelContext.insert(product)
        try modelContext.save()
    }
    
    func updateProduct(_ product: Product) async throws {
        try modelContext.save()
    }
    
    func deleteProduct(_ product: Product) async throws {
        modelContext.delete(product)
        try modelContext.save()
    }
    
    func deleteProducts(_ products: [Product]) async throws {
        for product in products {
            modelContext.delete(product)
        }
        try modelContext.save()
    }
    
    func searchProducts(query: String) async throws -> [Product] {
        let descriptor = FetchDescriptor<Product>()
        let products = try modelContext.fetch(descriptor)

        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(query) ||
            product.sku.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Pagination Support

    func fetchProducts(limit: Int, offset: Int, sortBy: [SortDescriptor<Product>]?, status: Product.InventoryStatus?) async throws -> [Product] {
        // Use provided sort descriptors or default to name ascending
        let sortDescriptors = sortBy ?? [SortDescriptor(\Product.name, order: .forward)]

        var descriptor = FetchDescriptor<Product>(
            sortBy: sortDescriptors
        )

        // Apply status filter if provided
        if let status = status {
            descriptor.predicate = #Predicate<Product> { product in
                product.cachedInventoryStatus == status.rawValue
            }
        }

        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        return try modelContext.fetch(descriptor)
    }

    func fetchProductCount(status: Product.InventoryStatus?) async throws -> Int {
        // If status filter provided, use predicate for efficient counting
        if let status = status {
            var descriptor = FetchDescriptor<Product>()
            descriptor.predicate = #Predicate<Product> { product in
                product.cachedInventoryStatus == status.rawValue
            }
            let products = try modelContext.fetch(descriptor)
            return products.count
        }

        // No filter - count all products
        let descriptor = FetchDescriptor<Product>()
        let products = try modelContext.fetch(descriptor)
        return products.count
    }
}