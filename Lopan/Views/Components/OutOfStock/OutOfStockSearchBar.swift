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
    
    @State private var isTextFieldFocused: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                CustomTextField(
                    placeholder,
                    text: $searchText,
                    onEditingChanged: { editing in
                        isTextFieldFocused = editing
                    },
                    onCommit: {
                        onSearch(searchText)
                    }
                )
                .onChange(of: searchText) { _, newValue in
                    onSearch(newValue)
                }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onSearch("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter button
            Button(action: onFilterTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
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