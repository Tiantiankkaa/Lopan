//
//  DeliveryStatus.swift
//  Lopan
//
//  Extracted for shared usage between views and view models.
//  Tracks delivery status for customer out-of-stock fulfillment.
//

import SwiftUI

enum DeliveryStatus: CaseIterable {
    case needsDelivery
    case partialDelivery
    case completed

    var displayName: String {
        switch self {
        case .needsDelivery:
            return "pending_delivery".localized
        case .partialDelivery:
            return "partial_delivery".localized
        case .completed:
            return "completed_delivery".localized
        }
    }

    var systemImage: String {
        switch self {
        case .needsDelivery:
            return "exclamationmark.triangle.fill"
        case .partialDelivery:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }

    var chipColor: Color {
        switch self {
        case .needsDelivery:
            return LopanColors.warning
        case .partialDelivery:
            return LopanColors.info
        case .completed:
            return LopanColors.success
        }
    }
}
