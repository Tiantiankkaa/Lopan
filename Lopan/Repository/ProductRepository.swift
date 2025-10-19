//
//  ProductRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
public protocol ProductRepository {
    func fetchProducts() async throws -> [Product]
    func fetchProduct(by id: String) async throws -> Product?
    func addProduct(_ product: Product) async throws
    func updateProduct(_ product: Product) async throws
    func deleteProduct(_ product: Product) async throws
    func deleteProducts(_ products: [Product]) async throws
    func searchProducts(query: String) async throws -> [Product]

    // MARK: - Pagination Support

    /// Fetch products with pagination support
    /// - Parameters:
    ///   - limit: Maximum number of products to fetch
    ///   - offset: Number of products to skip
    ///   - sortBy: Sort descriptor for ordering (default: name ascending)
    ///   - status: Optional inventory status filter
    /// - Returns: Array of products for the specified page
    func fetchProducts(limit: Int, offset: Int, sortBy: [SortDescriptor<Product>]?, status: Product.InventoryStatus?) async throws -> [Product]

    /// Get total count of products matching optional filter
    /// - Parameter status: Optional inventory status filter
    /// - Returns: Total number of products
    func fetchProductCount(status: Product.InventoryStatus?) async throws -> Int
}