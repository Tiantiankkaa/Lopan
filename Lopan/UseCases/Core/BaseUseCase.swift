//
//  BaseUseCase.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation

// MARK: - Base Use Case Protocols

protocol UseCase {
    associatedtype Request
    associatedtype Response
    
    func execute(_ request: Request) async throws -> Response
}

protocol SimpleUseCase {
    associatedtype Response
    
    func execute() async throws -> Response
}

protocol VoidUseCase {
    associatedtype Request
    
    func execute(_ request: Request) async throws
}

// MARK: - Base Use Case Implementation

class BaseUseCase {
    let auditingService: AuditingService
    
    init(auditingService: AuditingService) {
        self.auditingService = auditingService
    }
    
    // MARK: - Common Validation Methods
    
    func validateId(_ id: String, fieldName: String = "ID") throws {
        guard !id.isEmpty else {
            throw RepositoryError.invalidInput("\(fieldName) cannot be empty")
        }
    }
    
    func validateUserId(_ userId: String) throws {
        guard !userId.isEmpty else {
            throw RepositoryError.invalidInput("User ID cannot be empty")
        }
    }
    
    func validatePagination(page: Int, pageSize: Int, maxPageSize: Int = 1000) throws {
        guard page >= 0 else {
            throw RepositoryError.invalidInput("Page number cannot be negative, got: \(page)")
        }
        
        guard pageSize > 0 else {
            throw RepositoryError.invalidInput("Page size must be positive, got: \(pageSize)")
        }
        
        guard pageSize <= maxPageSize else {
            throw RepositoryError.invalidInput("Page size too large: \(pageSize) (max: \(maxPageSize))")
        }
    }
    
    func validateDateRange(_ startDate: Date, _ endDate: Date) throws {
        guard startDate <= endDate else {
            throw RepositoryError.invalidInput("Start date must be before or equal to end date")
        }
        
        let calendar = Calendar.current
        let monthsApart = calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
        
        guard monthsApart <= 12 else {
            throw RepositoryError.invalidInput("Date range cannot exceed 12 months")
        }
    }
    
    func validateBatchSize<T>(_ items: [T], maxSize: Int) throws {
        guard !items.isEmpty else {
            throw RepositoryError.invalidInput("Batch cannot be empty")
        }
        
        guard items.count <= maxSize else {
            throw RepositoryError.invalidInput("Batch size too large: \(items.count) (max: \(maxSize))")
        }
    }
    
    // MARK: - Common Error Handling
    
    func handleRepositoryError<T>(
        _ operation: @autoclosure () async throws -> T,
        entityType: String,
        entityId: String?,
        operationType: AuditOperation,
        performedBy: String?,
        details: String
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            await auditingService.logError(
                operation: operationType,
                entityType: entityType,
                entityId: entityId,
                error: error,
                details: details,
                performedBy: performedBy
            )
            throw error
        }
    }
    
    // MARK: - Common Audit Logging
    
    func logSuccess(
        operation: AuditOperation,
        entityType: String,
        entityId: String?,
        performedBy: String,
        details: String
    ) async {
        await auditingService.logOperation(
            operation: operation,
            entityType: entityType,
            entityId: entityId,
            performedBy: performedBy,
            details: details
        )
    }
}

// MARK: - Result Types

enum UseCaseResult<T> {
    case success(T)
    case failure(Error)
    
    var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

// MARK: - Validation Utilities

struct UseCaseValidationResult {
    let isValid: Bool
    let errors: [String]
    
    static let valid = UseCaseValidationResult(isValid: true, errors: [])
    
    static func invalid(_ errors: [String]) -> UseCaseValidationResult {
        return UseCaseValidationResult(isValid: false, errors: errors)
    }
    
    static func invalid(_ error: String) -> UseCaseValidationResult {
        return UseCaseValidationResult(isValid: false, errors: [error])
    }
}

protocol Validatable {
    func validate() -> UseCaseValidationResult
}

// MARK: - Common Request Types

struct PaginationRequest {
    let page: Int
    let pageSize: Int
    
    init(page: Int = 0, pageSize: Int = 20) {
        self.page = max(0, page)
        self.pageSize = min(max(1, pageSize), 1000)
    }
}

struct UserActionRequest {
    let performedBy: String
    let timestamp: Date
    let reason: String?
    
    init(performedBy: String, reason: String? = nil) {
        self.performedBy = performedBy
        self.timestamp = Date()
        self.reason = reason
    }
}

// MARK: - Use Case Factory (Temporarily Disabled)
// TODO: Re-implement Use Case Factory when specific Use Cases are ready

// protocol UseCaseFactory {
//     func makeGetCustomerOutOfStockUseCase() -> GetCustomerOutOfStockUseCase
//     func makeCreateCustomerOutOfStockUseCase() -> CreateCustomerOutOfStockUseCase
//     func makeUpdateCustomerOutOfStockUseCase() -> UpdateCustomerOutOfStockUseCase
//     func makeDeleteCustomerOutOfStockUseCase() -> DeleteCustomerOutOfStockUseCase
// }
// 
// class DefaultUseCaseFactory: UseCaseFactory {
//     private let container: LopanDIContainer
//     
//     init(container: LopanDIContainer) {
//         self.container = container
//     }
//     
//     func makeGetCustomerOutOfStockUseCase() -> GetCustomerOutOfStockUseCase {
//         return container.resolve(GetCustomerOutOfStockUseCase.self)
//     }
//     
//     func makeCreateCustomerOutOfStockUseCase() -> CreateCustomerOutOfStockUseCase {
//         return container.resolve(CreateCustomerOutOfStockUseCase.self)
//     }
//     
//     func makeUpdateCustomerOutOfStockUseCase() -> UpdateCustomerOutOfStockUseCase {
//         return container.resolve(UpdateCustomerOutOfStockUseCase.self)
//     }
//     
//     func makeDeleteCustomerOutOfStockUseCase() -> DeleteCustomerOutOfStockUseCase {
//         return container.resolve(DeleteCustomerOutOfStockUseCase.self)
//     }
// }