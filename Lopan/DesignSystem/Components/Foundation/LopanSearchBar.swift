//
//  LopanSearchBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI

struct LopanSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let onClear: (() -> Void)?
    
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索...",
        onClear: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.onClear = onClear
    }
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("清除") {
                    searchText = ""
                    onClear?()
                }
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
    }
}

#Preview {
    @State var searchText = "示例搜索"
    
    return VStack {
        LopanSearchBar(
            searchText: $searchText,
            placeholder: "搜索客户姓名、地址或电话..."
        )
        
        LopanSearchBar(
            searchText: .constant(""),
            placeholder: "空状态示例"
        )
    }
    .padding()
}