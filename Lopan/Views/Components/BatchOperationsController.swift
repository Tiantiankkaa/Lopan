//
//  BatchOperationsController.swift
//  Lopan
//
//  Created by Claude Code for Product Management Redesign
//

import SwiftUI

struct BatchOperationsController: View {
    @Binding var isBatchMode: Bool
    @Binding var selectedItems: Set<String>
    let totalItems: Int
    let filteredItems: [String]
    let onBulkAction: (BatchAction) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    
    @State private var showingActionSheet = false
    @State private var pendingAction: BatchAction?
    @State private var animateSelectionCount = false
    
    enum BatchAction: CaseIterable {
        case delete
        case export
        
        var title: String {
            switch self {
            case .delete: return "删除选中项目"
            case .export: return "导出选中项目"
            }
        }
        
        var icon: String {
            switch self {
            case .delete: return "trash"
            case .export: return "square.and.arrow.up"
            }
        }
        
        var style: BatchActionStyle {
            switch self {
            case .delete: return .destructive
            case .export: return .primary
            }
        }
        
        var isDestructive: Bool {
            switch self {
            case .delete: return true
            case .export: return false
            }
        }
    }
    
    enum BatchActionStyle {
        case primary
        case secondary
        case destructive
        
        var color: Color {
            switch self {
            case .primary: return LopanColors.primary
            case .secondary: return LopanColors.textSecondary
            case .destructive: return LopanColors.error
            }
        }
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            if isBatchMode {
                batchModeHeader
                batchModeToolbar
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isBatchMode)
        .sheet(isPresented: $showingActionSheet) {
            batchActionSheet
        }
    }
    
    // MARK: - Batch Mode Header
    
    private var batchModeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LopanColors.primary)
                    
                    Text("批量操作模式")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                }
                
                Text(selectionSummary)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
                    .scaleEffect(animateSelectionCount ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateSelectionCount)
                    .onChange(of: selectedItems.count) { _, _ in
                        withAnimation {
                            animateSelectionCount = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                animateSelectionCount = false
                            }
                        }
                    }
            }
            
            Spacer()
            
            Button("退出") {
                exitBatchMode()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(LopanColors.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(LopanColors.primary.opacity(0.05))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .bottom
        )
    }
    
    private var selectionSummary: String {
        if selectedItems.isEmpty {
            return "未选择任何项目"
        } else if selectedItems.count == 1 {
            return "已选择 1 个项目"
        } else {
            return "已选择 \(selectedItems.count) 个项目"
        }
    }
    
    // MARK: - Batch Mode Toolbar
    
    private var batchModeToolbar: some View {
        HStack(spacing: 16) {
            // Selection Toggle Button
            selectAllToggleButton
            
            Spacer()
            
            // Action Button
            if !selectedItems.isEmpty {
                Button(action: { showingActionSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("操作")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(LopanColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LopanColors.primary)
                    .clipShape(Capsule())
                }
                .scaleEffect(selectedItems.isEmpty ? 0.8 : 1.0)
                .opacity(selectedItems.isEmpty ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: selectedItems.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(LopanColors.backgroundPrimary)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .bottom
        )
        .shadow(color: LopanColors.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var selectAllToggleButton: some View {
        let isAllSelected = selectedItems.count == filteredItems.count && !filteredItems.isEmpty
        
        return Button(action: {
            LopanHapticEngine.shared.light()
            
            Task { @MainActor in
                if isAllSelected {
                    onDeselectAll()
                } else {
                    onSelectAll()
                }
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: isAllSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(LopanColors.primary)
                
                Text(isAllSelected ? "取消全选" : "全选")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textPrimary)
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
        }
        .disabled(filteredItems.isEmpty)
        .scaleEffect(filteredItems.isEmpty ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedItems.count)
    }
    
    // MARK: - Batch Action Sheet
    
    private var batchActionSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.down.right.fill")
                            .font(.title2)
                            .foregroundColor(LopanColors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("批量操作")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.textPrimary)
                            
                            Text("对 \(selectedItems.count) 个选中项目执行操作")
                                .font(.subheadline)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Divider()
                }
                
                // Actions
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(BatchAction.allCases, id: \.self) { action in
                            batchActionRow(action)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingActionSheet = false
                    }
                    .foregroundColor(LopanColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func batchActionRow(_ action: BatchAction) -> some View {
        Button(action: {
            pendingAction = action
            showingActionSheet = false
            
            if action.isDestructive {
                // Show confirmation for destructive actions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onBulkAction(action)
                }
            } else {
                onBulkAction(action)
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(action.style.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    if action.isDestructive {
                        Text("此操作不可撤销")
                            .font(.caption)
                            .foregroundColor(LopanColors.error)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LopanColors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(LopanColors.backgroundPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .bottom
        )
    }
    
    
    // MARK: - Actions
    
    private func exitBatchMode() {
        LopanHapticEngine.shared.light()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isBatchMode = false
            selectedItems.removeAll()
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isBatchMode = true
    @Previewable @State var selectedItems: Set<String> = ["1", "2"]
    let sampleItems = ["1", "2", "3", "4", "5"]
    
    return VStack {
        BatchOperationsController(
            isBatchMode: $isBatchMode,
            selectedItems: $selectedItems,
            totalItems: 10,
            filteredItems: sampleItems,
            onBulkAction: { action in
                print("Bulk action: \(action)")
            },
            onSelectAll: {
                selectedItems = Set(sampleItems)
            },
            onDeselectAll: {
                selectedItems.removeAll()
            }
        )
        
        Spacer()
        
        Button("Toggle Batch Mode") {
            isBatchMode.toggle()
        }
        .padding()
    }
}