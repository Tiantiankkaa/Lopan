//
//  CustomerOutOfStockRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

protocol CustomerOutOfStockRepository {
    func fetchOutOfStockRecords() async throws -> [CustomerOutOfStock]
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock?
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock]
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock]
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws
}