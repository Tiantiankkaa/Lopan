//
//  CommonNavigationHeader.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct CommonNavigationHeader<ActionButtons: View>: View {
    let title: String
    let subtitle: String?
    let hasActiveFilters: Bool
    let activeFiltersCount: Int
    let headerAnimationOffset: CGFloat
    let onDismiss: () -> Void
    let actionButtons: ActionButtons
    
    init(
        title: String,
        subtitle: String? = nil,
        hasActiveFilters: Bool = false,
        activeFiltersCount: Int = 0,
        headerAnimationOffset: CGFloat = 0,
        onDismiss: @escaping () -> Void,
        @ViewBuilder actionButtons: () -> ActionButtons
    ) {
        self.title = title
        self.subtitle = subtitle
        self.hasActiveFilters = hasActiveFilters
        self.activeFiltersCount = activeFiltersCount
        self.headerAnimationOffset = headerAnimationOffset
        self.onDismiss = onDismiss
        self.actionButtons = actionButtons()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Navigation header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if hasActiveFilters {
                        Text("\(activeFiltersCount) 个筛选条件已激活")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    actionButtons
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(
            LopanColors.background
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .offset(y: headerAnimationOffset)
    }
}

#Preview {
    CommonNavigationHeader(
        title: "客户缺货管理",
        hasActiveFilters: true,
        activeFiltersCount: 3,
        onDismiss: {}
    ) {
        HStack(spacing: 12) {
            Button(action: {}) {
                Circle()
                    .fill(LopanColors.primary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LopanColors.textPrimary)
                    )
            }
            
            Button(action: {}) {
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