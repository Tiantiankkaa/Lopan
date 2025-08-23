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
                .dynamicTypeSize(.small...DynamicTypeSize.accessibility1)
            
            Button(action: {
                withHapticFeedback(.light) {
                    onRemove()
                }
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
    let selectedReturnStatus: ReturnStatus?
    let selectedCustomer: Customer?
    let selectedAddress: String?
    let isFilteringByDate: Bool
    let selectedDate: Date
    
    let onRemoveReturnStatus: () -> Void
    let onRemoveCustomer: () -> Void
    let onRemoveAddress: () -> Void
    let onRemoveDateFilter: () -> Void
    let onClearAllFilters: () -> Void
    
    var hasActiveFilters: Bool {
        selectedReturnStatus != nil || 
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
                        withHapticFeedback(.light) {
                            onClearAllFilters()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityLabel("清除所有筛选条件")
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let status = selectedReturnStatus {
                            ReturnFilterChip(
                                title: status.displayName,
                                color: .blue,
                                onRemove: onRemoveReturnStatus
                            )
                        }
                        
                        if let customer = selectedCustomer {
                            ReturnFilterChip(
                                title: customer.name,
                                color: .green,
                                onRemove: onRemoveCustomer
                            )
                        }
                        
                        if let address = selectedAddress {
                            ReturnFilterChip(
                                title: String(address.prefix(10)) + (address.count > 10 ? "..." : ""),
                                color: .orange,
                                onRemove: onRemoveAddress
                            )
                        }
                        
                        if isFilteringByDate {
                            ReturnFilterChip(
                                title: selectedDate.formatted(.dateTime.month().day()),
                                color: .purple,
                                onRemove: onRemoveDateFilter
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
        }
    }
}

// Helper function for haptic feedback
func withHapticFeedback<T>(_ style: UIImpactFeedbackGenerator.FeedbackStyle, _ action: () -> T) -> T {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
    return action()
}

#Preview {
    VStack(spacing: 20) {
        ReturnFilterChip(title: "待还货", color: .blue) { }
        ReturnFilterChip(title: "张三", color: .green) { }
        ReturnFilterChip(title: "今天", color: .purple) { }
    }
    .padding()
}