//
//  RepositoryError.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//  Enhanced by Claude Code on 2025/8/22.
//

import Foundation

enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case duplicateEntry(String)
    case invalidData(String)
    case saveFailed(String)
    case invalidStatusFilter(String)
    case predicateConstructionFailed(String)
    case invalidFilterCombination(String)
    case databaseError(Error)
    case invalidPageParameters(page: Int, pageSize: Int)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return "Not found: \(message)"
        case .duplicateEntry(let message):
            return "Duplicate entry: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .invalidStatusFilter:
            return "Invalid status filter provided"
        case .predicateConstructionFailed:
            return "Unable to construct database query"
        case .invalidFilterCombination:
            return "Invalid combination of filters"
        case .databaseError(let error):
            return "Database operation failed: \(error.localizedDescription)"
        case .invalidPageParameters(let page, let pageSize):
            return "Invalid pagination parameters: page=\(page), pageSize=\(pageSize)"
        }
    }
    
    var sanitizedMessage: String {
        switch self {
        case .invalidStatusFilter:
            return "Invalid filter selection. Please try again."
        case .predicateConstructionFailed:
            return "Unable to apply filter. Please try again."
        case .invalidFilterCombination:
            return "Filter combination not supported. Please adjust filters."
        case .databaseError:
            return "Unable to load data. Please try again."
        case .invalidPageParameters:
            return "Unable to load more data. Please refresh the view."
        case .notFound:
            return "Data not found. Please refresh or try different criteria."
        case .duplicateEntry:
            return "This item already exists. Please check your input."
        case .invalidData:
            return "Invalid data provided. Please check your input."
        case .saveFailed:
            return "Failed to save data. Please try again."
        }
    }
    
    var isRetriable: Bool {
        switch self {
        case .databaseError:
            return true
        case .invalidPageParameters:
            return false
        case .invalidStatusFilter, .predicateConstructionFailed, .invalidFilterCombination:
            return false
        case .notFound, .duplicateEntry, .invalidData, .saveFailed:
            return true
        }
    }
}

extension RepositoryError {
    static func invalidStatus(_ status: OutOfStockStatus?) -> RepositoryError {
        let statusString = status?.rawValue ?? "unknown"
        return .invalidStatusFilter(statusString)
    }
}