//
//  CustomerRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
public protocol CustomerRepository {
    func fetchCustomers() async throws -> [Customer]
    func fetchCustomer(by id: String) async throws -> Customer?
    func addCustomer(_ customer: Customer) async throws
    func updateCustomer(_ customer: Customer) async throws
    func deleteCustomer(_ customer: Customer) async throws
    func deleteCustomers(_ customers: [Customer]) async throws
    func searchCustomers(query: String) async throws -> [Customer]
    func toggleFavorite(_ customer: Customer) async throws
    func updateLastViewed(_ customer: Customer) async throws

    /// Checks if a customer with the given name already exists
    /// - Parameters:
    ///   - name: The customer name to check (case-insensitive, whitespace-trimmed)
    ///   - excludingId: Optional customer ID to exclude from the check (for edit scenarios)
    /// - Returns: True if a duplicate name exists, false otherwise
    func checkDuplicateName(_ name: String, excludingId: String?) async throws -> Bool
}