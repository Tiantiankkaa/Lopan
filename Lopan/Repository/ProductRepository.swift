//
//  ProductRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

public protocol ProductRepository {
    func fetchProducts() async throws -> [Product]
    func fetchProduct(by id: String) async throws -> Product?
    func addProduct(_ product: Product) async throws
    func updateProduct(_ product: Product) async throws
    func deleteProduct(_ product: Product) async throws
    func deleteProducts(_ products: [Product]) async throws
    func searchProducts(query: String) async throws -> [Product]
}