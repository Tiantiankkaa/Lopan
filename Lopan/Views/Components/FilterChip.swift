//
//  FilterChip.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let color: Color
    let onRemove: () -> Void
    
    @State private var isPressed = false
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    init(title: String, color: Color = .blue, onRemove: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(color)
            
            Button(action: handleRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(color)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("移除筛选条件：\(title)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            handleRemove()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("筛选条件：\(title)")
        .accessibilityHint("点击移除此筛选条件")
    }
    
    private func handleRemove() {
        hapticFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
            onRemove()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            FilterChip(title: "客户: 张三", color: .blue) { }
            FilterChip(title: "产品: 西装", color: .green) { }
            FilterChip(title: "状态: 待处理", color: .orange) { }
        }
        
        HStack {
            FilterChip(title: "地址: 上海", color: .purple) { }
            FilterChip(title: "搜索: 关键词", color: .red) { }
        }
    }
    .padding()
}