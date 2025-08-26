//
//  OutOfStockSearchBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let onSearch: (String) -> Void
    let onFilterTap: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true) // Decorative icon
                
                TextField(placeholder, text: $searchText)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, design: .default))
                    .onSubmit {
                        onSearch(searchText)
                    }
                    .onChange(of: searchText) { _, newValue in
                        onSearch(newValue)
                    }
                    .accessibilityLabel("搜索缺货记录")
                    .accessibilityHint("输入客户姓名、产品名称或备注来搜索")
                    .accessibilityValue(searchText.isEmpty ? "无内容" : searchText)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onSearch("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 44, minHeight: 44) // HIG compliant touch target
                    }
                    .accessibilityLabel("清除搜索内容")
                    .accessibilityHint("清空搜索框并重置搜索结果")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isTextFieldFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
            
            // Filter button - HIG compliant 44pt touch target
            Button(action: onFilterTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(minWidth: 44, minHeight: 44) // HIG compliant touch target
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .accessibilityLabel("筛选条件")
            .accessibilityHint("打开筛选面板设置搜索条件")
            .accessibilityAddTraits(.isButton)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        OutOfStockSearchBar(
            searchText: .constant(""),
            placeholder: "搜索客户、产品、备注...",
            onSearch: { _ in },
            onFilterTap: {}
        )
        
        OutOfStockSearchBar(
            searchText: .constant("测试搜索"),
            placeholder: "搜索客户、产品、备注...",
            onSearch: { _ in },
            onFilterTap: {}
        )
    }
    .padding()
}