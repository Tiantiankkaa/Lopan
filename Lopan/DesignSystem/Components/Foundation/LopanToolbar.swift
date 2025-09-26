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
                    .lopanAccessibility(
                        role: .button,
                        label: primaryAction.title,
                        hint: "主要操作按钮"
                    )
                    .lopanMinimumTouchTarget()
                }
                
                Spacer()
                
                Button(batchModeEnabled ? "取消" : "批量操作") {
                    onToggleBatchMode()
                }
                .foregroundColor(batchModeEnabled ? LopanColors.error : LopanColors.primary)
                .lopanAccessibility(
                    role: .button,
                    label: batchModeEnabled ? "取消批量操作" : "启用批量操作",
                    hint: batchModeEnabled ? "退出批量选择模式" : "进入批量选择模式",
                    value: batchModeEnabled ? "批量模式已启用" : "批量模式未启用"
                )
                .lopanMinimumTouchTarget()
                
                if !secondaryActions.isEmpty {
                    Menu {
                        ForEach(secondaryActions, id: \.title) { action in
                            Button(action.title, action: action.action)
                        }
                    } label: {
                        Label("更多", systemImage: "ellipsis.circle")
                    }
                    .lopanAccessibility(
                        role: .button,
                        label: "更多操作",
                        hint: "显示更多操作选项，共\(secondaryActions.count)个选项"
                    )
                    .lopanMinimumTouchTarget()
                }
            }
            
            // Batch operations toolbar
            if batchModeEnabled {
                HStack {
                    Text("已选择 \(selectedCount) 项")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("当前选择了\(selectedCount)个项目")

                    Spacer()

                    if selectedCount > 0 {
                        ForEach(batchActions, id: \.title) { action in
                            Button(action.title, action: action.action)
                                .foregroundColor(action.isDestructive ? LopanColors.error : LopanColors.primary)
                                .lopanAccessibility(
                                    role: .button,
                                    label: action.title,
                                    hint: action.isDestructive ? "危险操作，将对选中的\(selectedCount)个项目执行\(action.title)" : "对选中的\(selectedCount)个项目执行\(action.title)"
                                )
                                .lopanMinimumTouchTarget()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(LopanColors.backgroundTertiary)
                .cornerRadius(8)
                .lopanAccessibilityGroup(
                    label: "批量操作工具栏",
                    hint: selectedCount > 0 ? "已选择\(selectedCount)项，可执行批量操作" : "未选择任何项目"
                )
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

// MARK: - Dynamic Type Previews

#Preview("Default Size") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Toolbar Variants")
                .font(.headline)
                .padding(.bottom)

            // Normal state
            LopanToolbar(
                primaryAction: LopanToolbarAction(title: "添加客户", systemImage: "plus") {},
                secondaryActions: [
                    LopanToolbarAction(title: "导入Excel") {},
                    LopanToolbarAction(title: "导出Excel") {}
                ]
            )

            Divider()

            // Batch mode enabled but no selections
            LopanToolbar(
                batchModeEnabled: true,
                selectedCount: 0,
                batchActions: [
                    LopanToolbarAction(title: "删除选中", isDestructive: true) {},
                    LopanToolbarAction(title: "导出选中") {}
                ]
            )

            Divider()

            // Batch mode with selections
            LopanToolbar(
                batchModeEnabled: true,
                selectedCount: 3,
                batchActions: [
                    LopanToolbarAction(title: "删除选中", isDestructive: true) {},
                    LopanToolbarAction(title: "导出选中") {}
                ]
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    ScrollView {
        VStack(spacing: 28) {
            Text("Toolbar Preview at Extra Large Size")
                .font(.title2)
                .padding(.bottom)

            LopanToolbar(
                primaryAction: LopanToolbarAction(title: "Create New Manufacturing Order", systemImage: "plus.circle.fill") {},
                secondaryActions: [
                    LopanToolbarAction(title: "Import Production Data from Excel") {},
                    LopanToolbarAction(title: "Export Manufacturing Report to Excel") {},
                    LopanToolbarAction(title: "Generate Quality Control Summary") {}
                ]
            )

            Divider()

            LopanToolbar(
                batchModeEnabled: true,
                selectedCount: 12,
                batchActions: [
                    LopanToolbarAction(title: "Delete Selected Manufacturing Orders", systemImage: "trash.fill", isDestructive: true) {},
                    LopanToolbarAction(title: "Export Selected Orders to Excel", systemImage: "square.and.arrow.up") {},
                    LopanToolbarAction(title: "Mark Selected Orders as Priority", systemImage: "star.fill") {}
                ]
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Accessibility 3") {
    ScrollView {
        VStack(spacing: 32) {
            Text("Toolbar Preview at AX3 Size")
                .font(.title2)
                .padding(.bottom)

            LopanToolbar(
                primaryAction: LopanToolbarAction(title: "Add New Production Customer for Manufacturing Processing", systemImage: "person.badge.plus") {},
                secondaryActions: [
                    LopanToolbarAction(title: "Import Customer Data from Excel Spreadsheet") {},
                    LopanToolbarAction(title: "Export Complete Customer Database to Excel") {},
                    LopanToolbarAction(title: "Generate Customer Production History Report") {}
                ]
            )

            Divider()

            LopanToolbar(
                batchModeEnabled: true,
                selectedCount: 5,
                batchActions: [
                    LopanToolbarAction(
                        title: "Permanently Delete All Selected Customer Records",
                        systemImage: "trash.circle.fill",
                        isDestructive: true
                    ) {},
                    LopanToolbarAction(
                        title: "Export All Selected Customer Information to Excel",
                        systemImage: "doc.badge.arrow.up"
                    ) {}
                ]
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    ScrollView {
        VStack(spacing: 36) {
            Text("Maximum Accessibility Size")
                .font(.largeTitle)
                .padding(.bottom)

            LopanToolbar(
                primaryAction: LopanToolbarAction(title: "Add Item", systemImage: "plus") {},
                secondaryActions: [
                    LopanToolbarAction(title: "Import") {},
                    LopanToolbarAction(title: "Export") {}
                ]
            )

            Divider()

            LopanToolbar(
                batchModeEnabled: true,
                selectedCount: 8,
                batchActions: [
                    LopanToolbarAction(title: "Delete", isDestructive: true) {},
                    LopanToolbarAction(title: "Export") {}
                ]
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX3") {
    ScrollView {
        VStack(spacing: 32) {
            Text("Dark Mode Toolbar Preview")
                .font(.title2)
                .padding(.bottom)

            LopanToolbar(
                primaryAction: LopanToolbarAction(
                    title: "Create Night Shift Production Order",
                    systemImage: "moon.stars.fill"
                ) {},
                secondaryActions: [
                    LopanToolbarAction(title: "Import Night Shift Data from Excel") {},
                    LopanToolbarAction(title: "Export After-Hours Production Report") {},
                    LopanToolbarAction(title: "Night Operations Quality Control Summary") {}
                ]
            )

            Divider()

            LopanToolbar(
                batchModeEnabled: true,
                selectedCount: 15,
                batchActions: [
                    LopanToolbarAction(
                        title: "Delete Selected Night Shift Records",
                        isDestructive: true
                    ) {},
                    LopanToolbarAction(title: "Export Selected After-Hours Data") {}
                ]
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}