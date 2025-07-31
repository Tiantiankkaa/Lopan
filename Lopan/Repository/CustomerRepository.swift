//
//  CustomerRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

protocol CustomerRepository {
    func fetchCustomers() async throws -> [Customer]
    func fetchCustomer(by id: String) async throws -> Customer?
    func addCustomer(_ customer: Customer) async throws
    func updateCustomer(_ customer: Customer) async throws
    func deleteCustomer(_ customer: Customer) async throws
    func deleteCustomers(_ customers: [Customer]) async throws
    func searchCustomers(query: String) async throws -> [Customer]
}