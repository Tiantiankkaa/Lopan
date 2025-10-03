//
//  TranslucentSearchBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/03.
//

import SwiftUI

/// Modern translucent search bar with rounded design
/// Implements iOS 26 design patterns with iOS 17+ fallback
struct TranslucentSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(LopanTypography.bodyMedium)
                .foregroundColor(LopanColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(LopanColors.textTertiary)
                }
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, LopanSpacing.md)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6).opacity(0.5))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("搜索客户")
    }
}

#Preview {
    VStack(spacing: LopanSpacing.md) {
        TranslucentSearchBar(
            text: .constant(""),
            placeholder: "搜索客户姓名或地址"
        )

        TranslucentSearchBar(
            text: .constant("张三"),
            placeholder: "搜索客户姓名或地址"
        )
    }
    .padding()
    .background(LopanColors.backgroundPrimary)
}
