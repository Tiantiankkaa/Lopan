//
//  LopanToolbar.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI

struct LopanToolbar: View {
    let primaryAction: LopanToolbarAction?
    let secondaryActions: [LopanToolbarAction]
    let batchModeEnabled: Bool
    let selectedCount: Int
    let batchActions: [LopanToolbarAction]
    let onToggleBatchMode: () -> Void
    
    init(
        primaryAction: LopanToolbarAction? = nil,
        secondaryActions: [LopanToolbarAction] = [],
        batchModeEnabled: Bool = false,
        selectedCount: Int = 0,
        batchActions: [LopanToolbarAction] = [],
        onToggleBatchMode: @escaping () -> Void = {}
    ) {
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.batchModeEnabled = batchModeEnabled
        self.selectedCount = selectedCount
        self.batchActions = batchActions
        self.onToggleBatchMode = onToggleBatchMode
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main toolbar
            HStack {
                if let primaryAction = primaryAction {
                    Button(action: primaryAction.action) {
                        Label(primaryAction.title, systemImage: primaryAction.systemImage)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                Button(batchModeEnabled ? "取消" : "批量操作") {
                    onToggleBatchMode()
                }
                .foregroundColor(batchModeEnabled ? .red : .blue)
                
                if !secondaryActions.isEmpty {
                    Menu {
                        ForEach(secondaryActions, id: \.title) { action in
                            Button(action.title, action: action.action)
                        }
                    } label: {
                        Label("更多", systemImage: "ellipsis.circle")
                    }
                }
            }
            
            // Batch operations toolbar
            if batchModeEnabled {
                HStack {
                    Text("已选择 \(selectedCount) 项")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if selectedCount > 0 {
                        ForEach(batchActions, id: \.title) { action in
                            Button(action.title, action: action.action)
                                .foregroundColor(action.isDestructive ? .red : .blue)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct LopanToolbarAction {
    let title: String
    let systemImage: String
    let action: () -> Void
    let isDestructive: Bool
    
    init(
        title: String,
        systemImage: String = "",
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.action = action
    }
}

#Preview {
    VStack(spacing: 20) {
        // Normal state
        LopanToolbar(
            primaryAction: LopanToolbarAction(title: "添加客户", systemImage: "plus") {},
            secondaryActions: [
                LopanToolbarAction(title: "导入Excel") {},
                LopanToolbarAction(title: "导出Excel") {}
            ]
        )
        
        // Batch mode with selections
        LopanToolbar(
            batchModeEnabled: true,
            selectedCount: 3,
            batchActions: [
                LopanToolbarAction(title: "删除选中", isDestructive: true) {}
            ]
        )
    }
    .padding()
}