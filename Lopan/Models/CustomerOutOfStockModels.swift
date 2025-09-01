//
//  CustomerOutOfStockModels.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation

// MARK: - Request Models

public struct OutOfStockCreationRequest {
    let customer: Customer?
    let product: Product?
    let productSize: ProductSize?
    let quantity: Int
    let notes: String?
    let createdBy: String
    
    // Helper properties for placeholder mode
    var customerName: String? { customer?.name }
    var productName: String? { product?.name }
}

// MARK: - Filter Models

public struct OutOfStockFilterCriteria {
    var customer: Customer?
    var product: Product?
    var status: OutOfStockStatus?
    var dateRange: (start: Date, end: Date)?
    var searchText: String
    var page: Int
    var pageSize: Int
    var sortOrder: CustomerOutOfStockNavigationState.SortOrder
    
    init(
        customer: Customer? = nil,
        product: Product? = nil,
        status: OutOfStockStatus? = nil,
        dateRange: (start: Date, end: Date)? = nil,
        searchText: String = "",
        page: Int = 0,
        pageSize: Int = 50,
        sortOrder: CustomerOutOfStockNavigationState.SortOrder = .newestFirst
    ) {
        self.customer = customer
        self.product = product
        self.status = status
        self.dateRange = dateRange
        self.searchText = searchText
        self.page = page
        self.pageSize = pageSize
        self.sortOrder = sortOrder
    }
}

// MARK: - Statistics Models

struct OutOfStockStatistics {
    let totalItems: Int
    let pendingCount: Int
    let partiallyReturnedCount: Int
    let fullyReturnedCount: Int
    let totalQuantity: Int
    let totalReturnedQuantity: Int
    let averageProcessingTime: TimeInterval
}