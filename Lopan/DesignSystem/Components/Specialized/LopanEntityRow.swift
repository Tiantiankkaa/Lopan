//
//  LopanEntityRow.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI

struct LopanEntityRow<Content: View>: View {
    let isSelected: Bool
    let isBatchMode: Bool
    let onToggleSelection: ((Bool) -> Void)?
    let actions: [LopanEntityRowAction]
    let content: Content
    
    init(
        isSelected: Bool = false,
        isBatchMode: Bool = false,
        onToggleSelection: ((Bool) -> Void)? = nil,
        actions: [LopanEntityRowAction] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isBatchMode = isBatchMode
        self.onToggleSelection = onToggleSelection
        self.actions = actions
        self.content = content()
    }
    
    var body: some View {
        HStack {
            if isBatchMode {
                Button(action: { onToggleSelection?(!isSelected) }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            content
            
            Spacer()
            
            if !isBatchMode && !actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(actions, id: \.title) { action in
                        Button(action.title) {
                            action.action()
                        }
                        .foregroundColor(action.isDestructive ? .red : .blue)
                        .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct LopanEntityRowAction {
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
}

#Preview {
    List {
        LopanEntityRow(
            isSelected: false,
            isBatchMode: false,
            actions: [
                LopanEntityRowAction(title: "编辑") {},
                LopanEntityRowAction(title: "删除", isDestructive: true) {}
            ]
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("张三")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("北京市朝阳区建国路88号")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("13800138001")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        
        LopanEntityRow(
            isSelected: true,
            isBatchMode: true,
            onToggleSelection: { _ in }
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("李四")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("上海市浦东新区陆家嘴金融中心")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("13900139001")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}