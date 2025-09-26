//
//  LopanList.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI

struct LopanList<Content: View>: View {
    let content: Content
    let isLoading: Bool
    let isEmpty: Bool
    let emptyStateTitle: String
    let emptyStateSystemImage: String
    let emptyStateDescription: String?
    let onRefresh: (() async -> Void)?
    
    init(
        isLoading: Bool = false,
        isEmpty: Bool = false,
        emptyStateTitle: String = "暂无数据",
        emptyStateSystemImage: String = "tray",
        emptyStateDescription: String? = nil,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateSystemImage = emptyStateSystemImage
        self.emptyStateDescription = emptyStateDescription
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        List {
            content
        }
        .overlay {
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LopanColors.background)
            } else if isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: emptyStateSystemImage,
                    description: emptyStateDescription.map { Text($0) }
                )
            }
        }
        .refreshable {
            if let onRefresh = onRefresh {
                await onRefresh()
            }
        }
    }
}

#Preview {
    LopanList(
        isLoading: false,
        isEmpty: true,
        emptyStateTitle: "暂无客户",
        emptyStateSystemImage: "person.3",
        emptyStateDescription: "添加第一个客户开始管理"
    ) {
        Text("示例内容")
    }
}