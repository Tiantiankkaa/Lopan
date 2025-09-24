//
//  SelectionSummaryBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/18.
//

import SwiftUI

struct SelectionSummaryBar: View {
    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onSecondaryAction: () -> Void
    let secondaryActionText: String
    
    init(
        selectedCount: Int,
        totalCount: Int,
        onSelectAll: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void,
        secondaryActionText: String = "操作"
    ) {
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.onSelectAll = onSelectAll
        self.onSecondaryAction = onSecondaryAction
        self.secondaryActionText = secondaryActionText
    }
    
    private var isAllSelected: Bool {
        selectedCount == totalCount && totalCount > 0
    }
    
    private var selectionText: String {
        if selectedCount == 0 {
            return "未选择任何项目"
        } else if isAllSelected {
            return "已选择全部 \(totalCount) 项"
        } else {
            return "已选择 \(selectedCount) / \(totalCount) 项"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection Status
            HStack(spacing: 8) {
                Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedCount > 0 ? .blue : .gray)
                    .font(.system(size: 16, weight: .medium))
                
                Text(selectionText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedCount > 0 ? .primary : .secondary)
                    
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(selectionText)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                if selectedCount > 0 {
                    Button(action: {
                        withHapticFeedback(.light) {
                            onSecondaryAction()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: secondaryActionText == "还货" ? "arrow.uturn.backward.circle" : "xmark.circle")
                                .font(.system(size: 14, weight: .medium))
                            Text(secondaryActionText)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(secondaryActionText == "还货" ? LopanColors.success.opacity(0.1) : LopanColors.error.opacity(0.1))
                        .foregroundColor(secondaryActionText == "还货" ? .green : .red)
                        .cornerRadius(16)
                    }
                    .accessibilityLabel(secondaryActionText == "还货" ? "处理还货" : "删除选择")
                    .accessibilityHint(secondaryActionText == "还货" ? "处理选中的还货项目" : "清除所有已选择的项目")
                }
                
                if totalCount > 0 {
                    Button(action: {
                        withHapticFeedback(.medium) {
                            onSelectAll()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isAllSelected ? "minus.circle" : "plus.circle")
                                .font(.system(size: 14, weight: .medium))
                            Text(isAllSelected ? "取消" : "全选")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(LopanColors.primary.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    }
                    .accessibilityLabel(isAllSelected ? "取消" : "全选")
                    .accessibilityHint(isAllSelected ? "取消选择所有项目" : "选择所有项目")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedCount > 0 ? LopanColors.primary.opacity(0.05) : LopanColors.secondary.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedCount > 0 ? LopanColors.primary.opacity(0.2) : LopanColors.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: selectedCount)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("选择摘要")
    }
}

struct BatchOperationHeader: View {
    let selectedCount: Int
    let totalCount: Int
    let onCancel: () -> Void
    let onProcess: () -> Void
    let onSelectAll: () -> Void
    let onSecondaryAction: () -> Void
    let processButtonText: String
    let secondaryActionText: String
    let processHint: String?
    let canProcess: Bool
    
    init(
        selectedCount: Int,
        totalCount: Int,
        onCancel: @escaping () -> Void,
        onProcess: @escaping () -> Void,
        onSelectAll: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void,
        processButtonText: String = "处理",
        secondaryActionText: String = "操作",
        processHint: String? = nil,
        canProcess: Bool? = nil
    ) {
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.onCancel = onCancel
        self.onProcess = onProcess
        self.onSelectAll = onSelectAll
        self.onSecondaryAction = onSecondaryAction
        self.processButtonText = processButtonText
        self.secondaryActionText = secondaryActionText
        self.processHint = processHint
        self.canProcess = canProcess ?? (selectedCount > 0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Action Bar
            HStack {
                Button(action: {
                    withHapticFeedback(.light) {
                        onCancel()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                        Text("取消")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                }
                .accessibilityLabel("取消批量操作")
                .accessibilityHint("退出批量选择模式")
                
                Spacer()
                
                Text("批量操作模式")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !processButtonText.isEmpty {
                    Button(action: {
                        withHapticFeedback(.medium) {
                            onProcess()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text(processButtonText)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(canProcess ? .blue : .secondary)
                    }
                    .disabled(!canProcess)
                    .accessibilityLabel("处理选中项目")
                    .accessibilityHint(canProcess ? (processHint ?? "处理选中的项目") : "请先选择要处理的项目")
                }
            }
            
            // Selection Summary
            SelectionSummaryBar(
                selectedCount: selectedCount,
                totalCount: totalCount,
                onSelectAll: onSelectAll,
                onSecondaryAction: onSecondaryAction,
                secondaryActionText: secondaryActionText
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    LopanColors.primary.opacity(0.08),
                    LopanColors.primary.opacity(0.04)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.primary.opacity(0.2)),
            alignment: .bottom
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("批量操作工具栏")
    }
}

#Preview {
    VStack(spacing: 20) {
        SelectionSummaryBar(
            selectedCount: 3,
            totalCount: 10,
            onSelectAll: { },
            onSecondaryAction: { }
        )
        
        BatchOperationHeader(
            selectedCount: 5,
            totalCount: 15,
            onCancel: { },
            onProcess: { },
            onSelectAll: { },
            onSecondaryAction: { },
            processButtonText: "还货处理",
            secondaryActionText: "删除"
        )
        
        SelectionSummaryBar(
            selectedCount: 0,
            totalCount: 8,
            onSelectAll: { },
            onSecondaryAction: { }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
