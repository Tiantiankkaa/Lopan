//
//  FilterChip.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/18.
//

import SwiftUI

struct ReturnFilterChip: View {
    let title: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                
            
            Button(action: {
                LopanHapticEngine.shared.light()
                onRemove()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .accessibilityLabel("移除筛选条件：\(title)")
            .accessibilityHint("双击移除此筛选条件")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("活动筛选条件：\(title)")
        .accessibilityHint("双击右侧按钮可移除此筛选条件")
    }
}

struct ActiveFiltersIndicator: View {
    let selectedDeliveryStatus: DeliveryStatus?
    let selectedCustomer: Customer?
    let selectedAddress: String?
    let isFilteringByDate: Bool
    let selectedDate: Date

    let onRemoveDeliveryStatus: () -> Void
    let onRemoveCustomer: () -> Void
    let onRemoveAddress: () -> Void
    let onRemoveDateFilter: () -> Void
    let onClearAllFilters: () -> Void

    var hasActiveFilters: Bool {
        selectedDeliveryStatus != nil ||
        selectedCustomer != nil ||
        selectedAddress != nil ||
        isFilteringByDate
    }
    
    var body: some View {
        if hasActiveFilters {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前筛选条件")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("清除全部") {
                        LopanHapticEngine.shared.light()
                        onClearAllFilters()
                    }
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
                    .accessibilityLabel("清除所有筛选条件")
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let status = selectedDeliveryStatus {
                            ReturnFilterChip(
                                title: status.displayName,
                                color: status.chipColor,
                                onRemove: onRemoveDeliveryStatus
                            )
                        }
                        
                        if let customer = selectedCustomer {
                            ReturnFilterChip(
                                title: customer.name,
                                color: LopanColors.success,
                                onRemove: onRemoveCustomer
                            )
                        }
                        
                        if let address = selectedAddress {
                            ReturnFilterChip(
                                title: String(address.prefix(10)) + (address.count > 10 ? "..." : ""),
                                color: LopanColors.warning,
                                onRemove: onRemoveAddress
                            )
                        }
                        
                        if isFilteringByDate {
                            ReturnFilterChip(
                                title: selectedDate.formatted(.dateTime.month().day()),
                                color: LopanColors.premium,
                                onRemove: onRemoveDateFilter
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .background(LopanColors.backgroundTertiary.opacity(0.5))
            .cornerRadius(8)
        }
    }
}


#Preview {
    VStack(spacing: 20) {
        ReturnFilterChip(title: "待还货", color: LopanColors.primary) { }
        ReturnFilterChip(title: "张三", color: LopanColors.success) { }
        ReturnFilterChip(title: "今天", color: LopanColors.premium) { }
    }
    .padding()
}
