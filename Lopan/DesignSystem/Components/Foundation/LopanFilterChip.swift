//
//  LopanFilterChip.swift
//  Lopan
//
//  Created by Factory on 2025/12/31.
//

import SwiftUI

/// Reusable filter chip component for consistent filtering UI across the app
/// Supports active/inactive states, counts, and customization
public struct LopanFilterChip: View {
    // MARK: - Properties
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    // Customization
    let showCount: Bool
    let hapticFeedback: Bool
    
    // MARK: - Initializers
    public init(
        title: String,
        count: Int? = nil,
        isSelected: Bool,
        showCount: Bool = true,
        hapticFeedback: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.showCount = showCount
        self.hapticFeedback = hapticFeedback
        self.action = action
    }
    
    // MARK: - Body
    public var body: some View {
        Button(action: {
            if hapticFeedback {
                LopanHapticEngine.shared.light()
            }
            action()
        }) {
            HStack(spacing: 6) {
                Text(title)
                if showCount, let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .lopanLabelMedium()
            .foregroundColor(
                isSelected ? LopanColors.chipActiveText : LopanColors.chipInactiveText
            )
            .padding(.horizontal, LopanSpacing.filterChipHorizontalPadding)
            .padding(.vertical, LopanSpacing.filterChipVerticalPadding)
            .background(
                isSelected ? LopanColors.chipActiveBackground : LopanColors.chipBackground
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : LopanColors.chipBorder,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Chip Group

/// Container for organizing multiple filter chips
public struct LopanFilterChipGroup<Content: View>: View {
    let scrollable: Bool
    let spacing: CGFloat
    let content: () -> Content
    
    public init(
        scrollable: Bool = true,
        spacing: CGFloat = LopanSpacing.filterChipSpacing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.scrollable = scrollable
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        if scrollable {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    content()
                }
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LopanFilterChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Single chips
            HStack(spacing: 12) {
                LopanFilterChip(
                    title: "All",
                    count: 42,
                    isSelected: true,
                    action: {}
                )
                
                LopanFilterChip(
                    title: "Active",
                    count: 15,
                    isSelected: false,
                    action: {}
                )
                
                LopanFilterChip(
                    title: "Low Stock",
                    count: 3,
                    isSelected: false,
                    action: {}
                )
            }
            
            // Chip group
            LopanFilterChipGroup {
                ForEach(["All", "Active", "Low Stock", "Inactive"], id: \.self) { filter in
                    LopanFilterChip(
                        title: filter,
                        count: Int.random(in: 0...50),
                        isSelected: filter == "All",
                        action: {}
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
