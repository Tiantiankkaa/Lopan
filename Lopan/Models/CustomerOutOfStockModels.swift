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
    var hasPartialReturn: Bool?  // NEW: Filter for records with returnQuantity > 0

    init(
        customer: Customer? = nil,
        product: Product? = nil,
        status: OutOfStockStatus? = nil,
        dateRange: (start: Date, end: Date)? = nil,
        searchText: String = "",
        page: Int = 0,
        pageSize: Int = 50,
        sortOrder: CustomerOutOfStockNavigationState.SortOrder = .newestFirst,
        hasPartialReturn: Bool? = nil
    ) {
        self.customer = customer
        self.product = product
        self.status = status
        self.dateRange = dateRange
        self.searchText = searchText
        self.page = page
        self.pageSize = pageSize
        self.sortOrder = sortOrder
        self.hasPartialReturn = hasPartialReturn
    }

    // MARK: - Optimization Helpers

    func isEquivalent(to other: OutOfStockFilterCriteria) -> Bool {
        return customer?.id == other.customer?.id &&
               product?.id == other.product?.id &&
               status == other.status &&
               searchText == other.searchText &&
               dateRangesEqual(self.dateRange, other.dateRange) &&
               sortOrder == other.sortOrder
    }

    private func dateRangesEqual(_ range1: (start: Date, end: Date)?, _ range2: (start: Date, end: Date)?) -> Bool {
        switch (range1, range2) {
        case (nil, nil):
            return true
        case let (r1?, r2?):
            return abs(r1.start.timeIntervalSince(r2.start)) < 1.0 &&
                   abs(r1.end.timeIntervalSince(r2.end)) < 1.0
        default:
            return false
        }
    }
}

// MARK: - Statistics Models

struct OutOfStockStatistics {
    let totalItems: Int
    let pendingCount: Int
    let partiallyDeliveredCount: Int
    let fullyDeliveredCount: Int
    let totalQuantity: Int
    let totalDeliveredQuantity: Int
    let averageProcessingTime: TimeInterval
}

// MARK: - Error Handling

enum CustomerOutOfStockError: LocalizedError {
    case networkTimeout
    case dataProcessingTimeout
    case largeDatasetTimeout(recordCount: Int)
    case retryExhausted(attempts: Int)
    case memoryPressure
    case invalidData(reason: String)
    case coordinatorError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkTimeout:
            return NSLocalizedString("Network request timed out. Please check your internet connection.", comment: "Network timeout error")
        case .dataProcessingTimeout:
            return NSLocalizedString("Data processing took too long. Please try with a smaller date range.", comment: "Data processing timeout")
        case .largeDatasetTimeout(let count):
            return NSLocalizedString("Dataset too large (\(count) records). Please filter your data or try a smaller time range.", comment: "Large dataset timeout")
        case .retryExhausted(let attempts):
            return NSLocalizedString("Request failed after \(attempts) attempts. Please try again later.", comment: "Retry exhausted error")
        case .memoryPressure:
            return NSLocalizedString("Insufficient memory to process this request. Please close other apps and try again.", comment: "Memory pressure error")
        case .invalidData(let reason):
            return NSLocalizedString("Invalid data: \(reason)", comment: "Invalid data error")
        case .coordinatorError(let underlying):
            return underlying.localizedDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkTimeout:
            return NSLocalizedString("Check your internet connection and try again.", comment: "Network timeout recovery")
        case .dataProcessingTimeout:
            return NSLocalizedString("Try filtering to a smaller date range or fewer records.", comment: "Processing timeout recovery")
        case .largeDatasetTimeout:
            return NSLocalizedString("Use filters to reduce the data size, or process in smaller batches.", comment: "Large dataset recovery")
        case .retryExhausted:
            return NSLocalizedString("Wait a moment and try the operation again.", comment: "Retry exhausted recovery")
        case .memoryPressure:
            return NSLocalizedString("Close other apps to free up memory, or restart the app.", comment: "Memory pressure recovery")
        case .invalidData:
            return NSLocalizedString("Check your data input and try again.", comment: "Invalid data recovery")
        case .coordinatorError:
            return NSLocalizedString("Try the operation again, or contact support if the issue persists.", comment: "Coordinator error recovery")
        }
    }
}