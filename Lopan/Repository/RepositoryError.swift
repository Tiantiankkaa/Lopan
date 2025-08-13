//
//  RepositoryError.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation

enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case duplicateEntry(String)
    case invalidData(String)
    case saveFailed(String)
    
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
        }
    }
}