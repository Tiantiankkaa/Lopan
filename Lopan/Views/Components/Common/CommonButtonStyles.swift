//
//  CommonButtonStyles.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

// MARK: - Common Circular Button

struct CommonCircularButton: View {
    let icon: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    
    init(
        icon: String,
        size: CGFloat = 36,
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundColor(foregroundColor)
                )
        }
    }
}

// MARK: - Common Filter Button with Badge

struct CommonFilterButton: View {
    let hasActiveFilters: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(hasActiveFilters ? Color.blue : Color(.systemGray5))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(hasActiveFilters ? .white : .primary)
                
                if hasActiveFilters {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 12, y: -12)
                }
            }
        }
    }
}

// MARK: - Common Text Button

struct CommonTextButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    init(
        title: String,
        color: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// MARK: - Common Icon Button

struct CommonIconButton: View {
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        icon: String,
        color: Color = .blue,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isDisabled ? .gray : color)
        }
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            CommonCircularButton(icon: "plus", action: {})
            CommonCircularButton(
                icon: "trash",
                backgroundColor: .red,
                action: {}
            )
            CommonFilterButton(hasActiveFilters: true, action: {})
        }
        
        HStack(spacing: 15) {
            CommonTextButton(title: "取消", color: .orange, action: {})
            CommonIconButton(icon: "checkmark.circle", action: {})
            CommonIconButton(
                icon: "trash",
                color: .red,
                isDisabled: true,
                action: {}
            )
        }
    }
    .padding()
}