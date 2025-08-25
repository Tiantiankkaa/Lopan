//
//  RepositoryProtocols.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation

// MARK: - Generic Repository Protocol

protocol Repository {
    associatedtype Entity
    associatedtype ID: Hashable
    
    func findById(_ id: ID) async throws -> Entity?
    func findAll() async throws -> [Entity]
    func save(_ entity: Entity) async throws -> Entity
    func delete(_ entity: Entity) async throws
    func deleteById(_ id: ID) async throws
}

// MARK: - Paginated Repository Protocol

protocol PaginatedRepository: Repository {
    func findAll(page: Int, pageSize: Int) async throws -> PaginatedResult<Entity>
    func count() async throws -> Int
}

struct PaginatedResult<T> {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    
    init(items: [T], totalCount: Int, page: Int, pageSize: Int) {
        self.items = items
        self.totalCount = totalCount
        self.page = page
        self.pageSize = pageSize
        self.hasNextPage = (page + 1) * pageSize < totalCount
        self.hasPreviousPage = page > 0
    }
}

// MARK: - Filtered Repository Protocol

protocol FilteredRepository: PaginatedRepository {
    associatedtype FilterCriteria
    
    func findFiltered(
        criteria: FilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> PaginatedResult<Entity>
    
    func countFiltered(criteria: FilterCriteria) async throws -> Int
}

// MARK: - Cacheable Repository Protocol

protocol CacheableRepository: Repository {
    func invalidateCache() async
    func invalidateCache(for id: ID) async
    func preload(ids: [ID]) async throws
}

// MARK: - Batch Operations Repository Protocol

protocol BatchRepository: Repository {
    func saveAll(_ entities: [Entity]) async throws -> [Entity]
    func deleteAll(_ entities: [Entity]) async throws
    func deleteAll(ids: [ID]) async throws
}

// MARK: - Customer Out of Stock Repository Protocol

protocol CustomerOutOfStockRepositoryProtocol: 
    FilteredRepository, 
    CacheableRepository, 
    BatchRepository 
where Entity == CustomerOutOfStock, 
      ID == String, 
      FilterCriteria == OutOfStockFilterCriteria {
    
    // Specific domain methods
    func findByCustomer(_ customerId: String) async throws -> [CustomerOutOfStock]
    func findByProduct(_ productId: String) async throws -> [CustomerOutOfStock]
    func findByStatus(_ status: OutOfStockStatus) async throws -> [CustomerOutOfStock]
    func findByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [CustomerOutOfStock]
    
    // Analytics methods
    func getStatusCounts(for criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int]
    func getCustomerCounts(for criteria: OutOfStockFilterCriteria) async throws -> [String: Int]
    func getProductCounts(for criteria: OutOfStockFilterCriteria) async throws -> [String: Int]
}

// MARK: - User Repository Protocol

protocol UserRepositoryProtocol: Repository where Entity == User, ID == String {
    func findByUsername(_ username: String) async throws -> User?
    func findByRole(_ role: UserRole) async throws -> [User]
    func updateLastLogin(_ userId: String) async throws
}

// MARK: - Customer Repository Protocol

protocol CustomerRepositoryProtocol: 
    FilteredRepository, 
    CacheableRepository 
where Entity == Customer, 
      ID == String, 
      FilterCriteria == CustomerFilterCriteria {
    
    func findByName(_ name: String) async throws -> [Customer]
    func findByAddress(_ address: String) async throws -> [Customer]
    func searchByText(_ searchText: String) async throws -> [Customer]
}

struct CustomerFilterCriteria {
    let name: String?
    let address: String?
    let searchText: String?
    let isActive: Bool?
    
    init(
        name: String? = nil,
        address: String? = nil,
        searchText: String? = nil,
        isActive: Bool? = nil
    ) {
        self.name = name
        self.address = address
        self.searchText = searchText
        self.isActive = isActive
    }
}

// MARK: - Product Repository Protocol

protocol ProductRepositoryProtocol: 
    FilteredRepository, 
    CacheableRepository 
where Entity == Product, 
      ID == String, 
      FilterCriteria == ProductFilterCriteria {
    
    func findByCategory(_ category: String) async throws -> [Product]
    func findByName(_ name: String) async throws -> [Product]
    func searchByText(_ searchText: String) async throws -> [Product]
}

struct ProductFilterCriteria {
    let name: String?
    let category: String?
    let searchText: String?
    let isActive: Bool?
    
    init(
        name: String? = nil,
        category: String? = nil,
        searchText: String? = nil,
        isActive: Bool? = nil
    ) {
        self.name = name
        self.category = category
        self.searchText = searchText
        self.isActive = isActive
    }
}