//
//  OutOfStockStatusTabBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockStatusTabBar: View {
    @Binding var selectedStatus: CustomerOutOfStockNavigationState.StatusFilter
    let statusCounts: [OutOfStockStatus: Int]
    let totalCount: Int
    
    private var tabs: [TabItem] {
        [
            TabItem(status: .all, title: "全部"),
            TabItem(status: .pending, title: "待处理"),
            TabItem(status: .completed, title: "已完成"),
            TabItem(status: .returned, title: "已退")
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress info
            progressInfo
            
            // Tab bar
            HStack(spacing: 0) {
                ForEach(tabs, id: \.status) { tab in
                    TabItemView(
                        tab: tab,
                        count: getCountForTab(tab),
                        isSelected: selectedStatus == tab.status,
                        onTap: {
                            selectedStatus = tab.status
                        }
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(LopanColors.background)
    }
    
    private var progressInfo: some View {
        HStack {
            Text("已加载 \(statusCounts.values.reduce(0, +)) / \(totalCount)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func getCountForTab(_ tab: TabItem) -> Int {
        switch tab.status {
        case .all:
            return totalCount
        case .pending:
            return statusCounts[.pending] ?? 0
        case .completed:
            return statusCounts[.completed] ?? 0
        case .returned:
            return statusCounts[.returned] ?? 0
        }
    }
}

// MARK: - Tab Item Model

private struct TabItem {
    let status: CustomerOutOfStockNavigationState.StatusFilter
    let title: String
}

// MARK: - Tab Item View

private struct TabItemView: View {
    let tab: TabItem
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(tab.title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? LopanColors.info : LopanColors.textPrimary)
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LopanColors.backgroundTertiary)
                            )
                    } else if tab.status == .all {
                        Text("1...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LopanColors.backgroundTertiary)
                            )
                    }
                }
                
                // Selection indicator
                Rectangle()
                    .fill(isSelected ? LopanColors.primary : LopanColors.clear)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OutOfStockStatusTabBar(
        selectedStatus: .constant(.all),
        statusCounts: [
            .pending: 20,
            .completed: 24,
            .returned: 5
        ],
        totalCount: 187
    )
}