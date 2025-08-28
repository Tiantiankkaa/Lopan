//
//  RepositoryError.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation

// MARK: - Repository Error Types

enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case duplicateKey(String)
    case invalidInput(String)
    case connectionFailed(String)
    case operationTimeout(String)
    case insufficientPermissions(String)
    case dataCorruption(String)
    case unknownError(Error)
    case authenticationFailed(String)
    case conflictDetected(String)
    case rateLimited(String)
    case serverError(String)
    case saveFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return "Not Found: \(message)"
        case .duplicateKey(let message):
            return "Duplicate Key: \(message)"
        case .invalidInput(let message):
            return "Invalid Input: \(message)"
        case .connectionFailed(let message):
            return "Connection Failed: \(message)"
        case .operationTimeout(let message):
            return "Operation Timeout: \(message)"
        case .insufficientPermissions(let message):
            return "Insufficient Permissions: \(message)"
        case .dataCorruption(let message):
            return "Data Corruption: \(message)"
        case .unknownError(let error):
            return "Unknown Error: \(error.localizedDescription)"
        case .authenticationFailed(let message):
            return "Authentication Failed: \(message)"
        case .conflictDetected(let message):
            return "Conflict Detected: \(message)"
        case .rateLimited(let message):
            return "Rate Limited: \(message)"
        case .serverError(let message):
            return "Server Error: \(message)"
        case .saveFailed(let message):
            return "Save Failed: \(message)"
        case .deleteFailed(let message):
            return "Delete Failed: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .notFound:
            return "The requested resource was not found in the data store."
        case .duplicateKey:
            return "A resource with the same identifier already exists."
        case .invalidInput:
            return "The provided input does not meet the required criteria."
        case .connectionFailed:
            return "Unable to establish connection to the data store."
        case .operationTimeout:
            return "The operation took too long to complete."
        case .insufficientPermissions:
            return "The current user does not have sufficient permissions."
        case .dataCorruption:
            return "The data in the store appears to be corrupted."
        case .unknownError:
            return "An unexpected error occurred."
        case .authenticationFailed:
            return "Authentication credentials are invalid or expired."
        case .conflictDetected:
            return "The operation conflicts with the current state of the resource."
        case .rateLimited:
            return "Too many requests have been made in a short time period."
        case .serverError:
            return "The server encountered an internal error."
        case .saveFailed:
            return "Failed to save data to the repository."
        case .deleteFailed:
            return "Failed to delete data from the repository."
        }
    }
}

// MARK: - Domain-Specific Errors

enum CustomerOutOfStockRepositoryError: Error, LocalizedError {
    case customerNotFound(String)
    case productNotFound(String)
    case invalidDateRange(Date, Date)
    case invalidStatus(String)
    case recordAlreadyExists(String)
    
    var errorDescription: String? {
        switch self {
        case .customerNotFound(let customerId):
            return "Customer not found: \(customerId)"
        case .productNotFound(let productId):
            return "Product not found: \(productId)"
        case .invalidDateRange(let start, let end):
            return "Invalid date range: \(start) to \(end)"
        case .invalidStatus(let status):
            return "Invalid out of stock status: \(status)"
        case .recordAlreadyExists(let recordId):
            return "Out of stock record already exists: \(recordId)"
        }
    }
}

enum UserRepositoryError: Error, LocalizedError {
    case userNotFound(String)
    case usernameAlreadyExists(String)
    case invalidRole(String)
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let userId):
            return "User not found: \(userId)"
        case .usernameAlreadyExists(let username):
            return "Username already exists: \(username)"
        case .invalidRole(let role):
            return "Invalid user role: \(role)"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

// MARK: - Error Mapping Utilities

extension RepositoryError {
    static func from(_ error: Error) -> RepositoryError {
        if let repositoryError = error as? RepositoryError {
            return repositoryError
        }
        
        // Map common system errors
        if let nsError = error as? NSError {
            switch nsError.code {
            case NSFileReadNoSuchFileError:
                return .notFound(nsError.localizedDescription)
            case NSURLErrorTimedOut:
                return .operationTimeout(nsError.localizedDescription)
            case NSURLErrorCannotConnectToHost:
                return .connectionFailed(nsError.localizedDescription)
            default:
                return .unknownError(error)
            }
        }
        
        return .unknownError(error)
    }
}

// MARK: - Result Type Extensions

extension Result where Failure == RepositoryError {
    static func repositorySuccess(_ value: Success) -> Self {
        .success(value)
    }
    
    static func repositoryFailure(_ error: RepositoryError) -> Self {
        .failure(error)
    }
    
    static func repositoryFailure(_ error: Error) -> Self {
        .failure(RepositoryError.from(error))
    }
}