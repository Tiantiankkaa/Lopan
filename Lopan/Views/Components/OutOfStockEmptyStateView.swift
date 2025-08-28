//
//  OutOfStockEmptyStateView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import SwiftUI

struct OutOfStockEmptyStateView: View {
    let hasActiveFilters: Bool
    let onClearFilters: () -> Void
    let onAddNew: () -> Void
    
    var body: some View {
        CustomerOutOfStockEmptyState(
            hasFilter: hasActiveFilters,
            onAddRecord: onAddNew,
            onClearFilter: hasActiveFilters ? onClearFilters : nil
        )
    }
}

// MARK: - Legacy Support

extension OutOfStockEmptyStateView {
    /// Convenience initializer for backward compatibility
    init(
        hasActiveFilters: Bool,
        searchText: String = "",
        onClearFilters: @escaping () -> Void,
        onAddNew: @escaping () -> Void
    ) {
        self.hasActiveFilters = hasActiveFilters || !searchText.isEmpty
        self.onClearFilters = onClearFilters
        self.onAddNew = onAddNew
    }
}

// MARK: - Preview

#if DEBUG
struct OutOfStockEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // No data state
            OutOfStockEmptyStateView(
                hasActiveFilters: false,
                onClearFilters: { },
                onAddNew: { }
            )
            .previewDisplayName("No Data")
            
            // Filtered results state
            OutOfStockEmptyStateView(
                hasActiveFilters: true,
                onClearFilters: { },
                onAddNew: { }
            )
            .previewDisplayName("No Filter Results")
        }
    }
}
#endif