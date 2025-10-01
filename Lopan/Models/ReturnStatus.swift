//
//  ReturnStatus.swift
//  Lopan
//
//  Extracted for shared usage between views and view models.
//

import SwiftUI

enum ReturnStatus: CaseIterable {
    case needsReturn
    case partialReturn
    case completed
    
    var displayName: String {
        switch self {
        case .needsReturn:
            return "pending_return".localized
        case .partialReturn:
            return "partial_return".localized
        case .completed:
            return "completed_return".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .needsReturn:
            return "exclamationmark.triangle.fill"
        case .partialReturn:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    var chipColor: Color {
        switch self {
        case .needsReturn:
            return LopanColors.warning
        case .partialReturn:
            return LopanColors.info
        case .completed:
            return LopanColors.success
        }
    }
}
