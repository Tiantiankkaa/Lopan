//
//  OutOfStockActionButtons.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockActionButtons: View {
    let isInSelectionMode: Bool
    let hasActiveFilters: Bool
    let selectedItemsCount: Int
    
    // Selection mode actions
    let onSelectAll: () -> Void
    let onDelete: () -> Void
    let onExitSelection: () -> Void
    
    // Normal mode actions
    let onShowFilter: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isInSelectionMode {
                selectionModeButtons
            } else {
                normalModeButtons
            }
        }
    }
    
    private var selectionModeButtons: some View {
        HStack(spacing: 12) {
            Button(action: onSelectAll) {
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundColor(LopanColors.info)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(LopanColors.error)
            }
            .disabled(selectedItemsCount == 0)
            
            Button(action: onExitSelection) {
                Text("取消")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LopanColors.warning)
            }
        }
    }
    
    private var normalModeButtons: some View {
        HStack(spacing: 12) {
            // Filter button with indicator
            Button(action: onShowFilter) {
                ZStack {
                    Circle()
                        .fill(hasActiveFilters ? LopanColors.primary : LopanColors.backgroundSecondary)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(hasActiveFilters ? LopanColors.textOnPrimary : LopanColors.textPrimary)
                    
                    if hasActiveFilters {
                        Circle()
                            .fill(LopanColors.error)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -12)
                    }
                }
            }
            
            // Add button
            Button(action: onAdd) {
                Circle()
                    .fill(LopanColors.primary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(LopanColors.textPrimary)
                    )
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        // Normal mode
        OutOfStockActionButtons(
            isInSelectionMode: false,
            hasActiveFilters: true,
            selectedItemsCount: 0,
            onSelectAll: {},
            onDelete: {},
            onExitSelection: {},
            onShowFilter: {},
            onAdd: {}
        )
        
        // Selection mode
        OutOfStockActionButtons(
            isInSelectionMode: true,
            hasActiveFilters: false,
            selectedItemsCount: 3,
            onSelectAll: {},
            onDelete: {},
            onExitSelection: {},
            onShowFilter: {},
            onAdd: {}
        )
    }
    .padding()
}