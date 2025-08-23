//
//  ReturnItemRow.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/18.
//

import SwiftUI

struct EnhancedReturnGoodsRowView: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    
    private var returnStatusText: String {
        if item.isFullyReturned {
            return "fully_returned".localized
        } else if item.hasPartialReturn {
            return "partially_returned".localized
        } else if item.needsReturn {
            return "needs_return".localized
        } else {
            return item.status.displayName
        }
    }
    
    private var returnStatusColor: Color {
        if item.isFullyReturned {
            return .green
        } else if item.hasPartialReturn {
            return .blue
        } else if item.needsReturn {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var returnStatusIcon: String {
        if item.isFullyReturned {
            return "checkmark.circle.fill"
        } else if item.hasPartialReturn {
            return "clock.fill"
        } else if item.needsReturn {
            return "exclamationmark.triangle.fill"
        } else {
            return "circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection Button (in editing mode)
            if isEditing {
                Button(action: {
                    withHapticFeedback(.light) {
                        onSelect()
                    }
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isSelected ? "已选择" : "未选择")
                .accessibilityHint("双击以\(isSelected ? "取消选择" : "选择")此还货记录")
            }
            
            // Main Content
            VStack(alignment: .leading, spacing: 12) {
                // Header Row
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.customerDisplayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .dynamicTypeSize(.small...DynamicTypeSize.accessibility2)
                            .lineLimit(1)
                        
                        Text(item.customer?.address ?? "地址已删除")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: returnStatusIcon)
                            .font(.caption2)
                        
                        Text(returnStatusText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(returnStatusColor.opacity(0.15))
                    .foregroundColor(returnStatusColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(returnStatusColor.opacity(0.3), lineWidth: 0.5)
                    )
                    .accessibilityLabel("还货状态：\(returnStatusText)")
                }
                
                // Product Information
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.productDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .dynamicTypeSize(.small...DynamicTypeSize.accessibility1)
                    
                    // Quantity Information Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ], spacing: 8) {
                        QuantityInfoItem(
                            title: "原始数量",
                            value: "\(item.quantity)",
                            color: .secondary
                        )
                        
                        if item.returnQuantity > 0 {
                            QuantityInfoItem(
                                title: "已还数量",
                                value: "\(item.returnQuantity)",
                                color: .blue
                            )
                        }
                        
                        QuantityInfoItem(
                            title: "剩余数量",
                            value: "\(item.remainingQuantity)",
                            color: item.remainingQuantity > 0 ? .orange : .green
                        )
                    }
                }
                
                // Date Information
                if let returnDate = item.returnDate {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("还货日期：\(returnDate.formatted(.dateTime.month().day().year()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.05) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.blue.opacity(0.3) : Color(.systemGray5),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .shadow(
            color: isSelected ? Color.blue.opacity(0.1) : Color.black.opacity(0.05),
            radius: isSelected ? 4 : 2,
            x: 0,
            y: isSelected ? 2 : 1
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.customerDisplayName)的还货记录")
        .accessibilityValue("产品：\(item.productDisplayName)，状态：\(returnStatusText)，剩余数量：\(item.remainingQuantity)")
        .accessibilityHint(isEditing ? "可选择进行批量操作" : "双击查看详情")
    }
}

struct QuantityInfoItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }
}

struct ReturnItemsList: View {
    let items: [CustomerOutOfStock]
    let isEditing: Bool
    let selectedItems: Set<String>
    let onItemSelection: (CustomerOutOfStock) -> Void
    let onItemTap: (CustomerOutOfStock) -> Void
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(items) { item in
                if isEditing {
                    EnhancedReturnGoodsRowView(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        isEditing: isEditing,
                        onSelect: { onItemSelection(item) }
                    )
                } else {
                    Button(action: { onItemTap(item) }) {
                        EnhancedReturnGoodsRowView(
                            item: item,
                            isSelected: false,
                            isEditing: false,
                            onSelect: { }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("查看\(item.customerDisplayName)的还货详情")
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

struct EmptyReturnStateView: View {
    let isEditing: Bool
    let totalItemsCount: Int
    let onInitializeSampleData: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.uturn.left.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text(isEditing ? "暂无可批量处理的还货记录" : "暂无还货记录")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("总记录数: \(totalItemsCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !isEditing && totalItemsCount == 0 {
                    Text("可能是筛选条件过于严格，或者暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let onInitialize = onInitializeSampleData, totalItemsCount == 0 {
                Button(action: onInitialize) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("初始化示例数据")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                .accessibilityLabel("初始化示例数据")
                .accessibilityHint("添加一些示例还货记录用于测试")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEditing ? "暂无可批量处理的还货记录" : "暂无还货记录")
        .accessibilityValue("总记录数: \(totalItemsCount)")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            EmptyReturnStateView(
                isEditing: false,
                totalItemsCount: 0,
                onInitializeSampleData: { }
            )
            
            EmptyReturnStateView(
                isEditing: true,
                totalItemsCount: 5,
                onInitializeSampleData: nil
            )
        }
    }
    .background(Color(.systemGroupedBackground))
}