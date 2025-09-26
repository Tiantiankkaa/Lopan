//
//  AdaptiveProductCard.swift
//  Lopan
//
//  Created by Claude Code for Product Management Redesign
//

import SwiftUI

struct AdaptiveProductCard: View {
    let product: Product
    let displayMode: CardDisplayMode
    let selectionState: SelectionState
    let onSelect: () -> Void
    let onSecondaryAction: (() -> Void)?
    
    @State private var isPressed = false
    @State private var imageLoadError = false
    
    enum CardDisplayMode {
        case compact    // List view with essential info only
        case standard   // Balanced information display
        case detailed   // Full information with preview
        
        var cardHeight: CGFloat {
            switch self {
            case .compact: return 64
            case .standard: return 100
            case .detailed: return 140
            }
        }
        
        var imageSize: CGFloat {
            switch self {
            case .compact: return 48
            case .standard: return 68
            case .detailed: return 100
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 8
            case .standard: return 12
            case .detailed: return 16
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .compact: return 12
            case .standard: return 16
            case .detailed: return 20
            }
        }
    }
    
    enum SelectionState {
        case none
        case selectable(isSelected: Bool)
        case disabled
        
        var isInBatchMode: Bool {
            switch self {
            case .selectable: return true
            default: return false
            }
        }
        
        var isSelected: Bool {
            switch self {
            case .selectable(let selected): return selected
            default: return false
            }
        }
    }
    
    var body: some View {
        HStack(spacing: displayMode.padding) {
            selectionIndicator
            productImageView
            productInfoView
            Spacer()
            accessoryView
        }
        .padding(displayMode.padding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: displayMode.cornerRadius))
        .overlay(cardBorder)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffsetY)
        .scaleEffect(scaleEffect)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectionState.isInBatchMode {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                onSelect()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(selectionState.isInBatchMode ? .isButton : [])
        .accessibilityValue(accessibilityValue)
    }
    
    // MARK: - Selection Indicator
    
    @ViewBuilder
    private var selectionIndicator: some View {
        switch selectionState {
        case .selectable(let isSelected):
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: selectionIconSize, weight: .medium))
                    .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isSelected ? "取消选择" : "选择此产品")
            
        case .none, .disabled:
            EmptyView()
        }
    }
    
    private var selectionIconSize: CGFloat {
        switch displayMode {
        case .compact: return 18
        case .standard: return 20
        case .detailed: return 22
        }
    }
    
    // MARK: - Product Image
    
    private var productImageView: some View {
        Group {
            if let imageData = product.imageData,
               let uiImage = UIImage(data: imageData),
               !imageLoadError {
                AsyncImageView(uiImage: uiImage, size: displayMode.imageSize)
                    .onTapGesture {
                        if displayMode == .detailed {
                            // Could trigger image preview
                        }
                    }
            } else {
                placeholderImageView
            }
        }
    }
    
    private var placeholderImageView: some View {
        RoundedRectangle(cornerRadius: displayMode.cornerRadius * 0.75)
            .fill(LopanColors.backgroundTertiary)
            .frame(width: displayMode.imageSize, height: displayMode.imageSize)
            .overlay(
                Group {
                    if displayMode == .compact {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LopanColors.textTertiary)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.system(size: displayMode == .detailed ? 20 : 16, weight: .medium))
                                .foregroundColor(LopanColors.textTertiary)
                            
                            if displayMode != .compact {
                                Text("暂无图片")
                                    .font(.caption2)
                                    .foregroundColor(LopanColors.textTertiary)
                            }
                        }
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: displayMode.cornerRadius * 0.75)
                    .stroke(LopanColors.border, lineWidth: 0.5)
            )
    }
    
    // MARK: - Product Information
    
    private var productInfoView: some View {
        VStack(alignment: .leading, spacing: infoSpacing) {
            productNameView
            
            if displayMode != .compact {
                productAttributesView
            }
            
            if displayMode == .detailed {
                productMetadataView
            }
        }
    }
    
    private var infoSpacing: CGFloat {
        switch displayMode {
        case .compact: return 4
        case .standard: return 8
        case .detailed: return 10
        }
    }
    
    private var productNameView: some View {
        Text(product.name)
            .font(nameFont)
            .fontWeight(.semibold)
            .foregroundColor(LopanColors.textPrimary)
            .lineLimit(displayMode == .compact ? 1 : 2)
            .multilineTextAlignment(.leading)
    }
    
    private var nameFont: Font {
        switch displayMode {
        case .compact: return .callout
        case .standard: return .body
        case .detailed: return .headline
        }
    }
    
    @ViewBuilder
    private var productAttributesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !product.colors.isEmpty {
                productColorsView
            }
            
            if let sizes = product.sizes, !sizes.isEmpty {
                productSizesView(sizes)
            }
        }
    }
    
    private var productColorsView: some View {
        HStack(spacing: 6) {
            ForEach(product.colors.prefix(maxVisibleColors), id: \.self) { color in
                if displayMode == .detailed {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForName(color))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(LopanColors.border, lineWidth: 0.5))
                        
                        LopanBadge(color, style: .neutral, size: .small)
                    }
                } else {
                    Circle()
                        .fill(colorForName(color))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(LopanColors.border, lineWidth: 0.5))
                }
            }
            
            if product.colors.count > maxVisibleColors {
                Text("+\(product.colors.count - maxVisibleColors)")
                    .font(.caption2)
                    .foregroundColor(LopanColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.backgroundSecondary)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var maxVisibleColors: Int {
        switch displayMode {
        case .compact: return 3
        case .standard: return 4
        case .detailed: return 5
        }
    }
    
    private func productSizesView(_ sizes: [ProductSize]) -> some View {
        HStack(spacing: 4) {
            ForEach(sizes.prefix(maxVisibleSizes), id: \.id) { size in
                LopanBadge(size.size, style: .secondary, size: .small)
            }
            
            if sizes.count > maxVisibleSizes {
                LopanBadge("+\(sizes.count - maxVisibleSizes)", style: .outline, size: .small)
            }
        }
    }
    
    private var maxVisibleSizes: Int {
        switch displayMode {
        case .compact: return 2
        case .standard: return 3
        case .detailed: return 4
        }
    }
    
    @ViewBuilder
    private var productMetadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(LopanColors.textTertiary)
                
                Text("创建于 \(product.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
            
            if product.updatedAt != product.createdAt {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(LopanColors.textTertiary)
                    
                    Text("更新于 \(product.updatedAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Accessory View
    
    @ViewBuilder
    private var accessoryView: some View {
        if !selectionState.isInBatchMode {
            VStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LopanColors.textTertiary)
                
                if displayMode == .detailed, let action = onSecondaryAction {
                    Button(action: action) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LopanColors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Visual Properties
    
    private var cardBackground: some View {
        Group {
            if selectionState.isSelected {
                LopanColors.primary.opacity(0.05)
            } else if isPressed {
                LopanColors.backgroundSecondary
            } else {
                LopanColors.backgroundSecondary
            }
        }
    }
    
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: displayMode.cornerRadius)
            .stroke(
                selectionState.isSelected ? LopanColors.primary.opacity(0.3) : LopanColors.border,
                lineWidth: selectionState.isSelected ? 1.5 : 0.5
            )
    }
    
    private var shadowColor: Color {
        if selectionState.isSelected {
            return LopanColors.primary.opacity(0.15)
        } else if isPressed {
            return LopanColors.shadow.opacity(2)
        } else {
            return LopanColors.shadow
        }
    }
    
    private var shadowRadius: CGFloat {
        if selectionState.isSelected {
            return 6
        } else if isPressed {
            return 1
        } else {
            return displayMode == .detailed ? 3 : 2
        }
    }
    
    private var shadowOffsetY: CGFloat {
        if selectionState.isSelected {
            return 3
        } else if isPressed {
            return 0.5
        } else {
            return displayMode == .detailed ? 2 : 1
        }
    }
    
    private var scaleEffect: CGFloat {
        if selectionState.isSelected {
            return 1.02
        } else if isPressed {
            return 0.98
        } else {
            return 1.0
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        var label = product.name
        
        if !product.colors.isEmpty {
            label += ", 颜色: \(product.colors.joined(separator: ", "))"
        }
        
        if let sizes = product.sizes, !sizes.isEmpty {
            let sizeNames = sizes.map { $0.size }
            label += ", 尺寸: \(sizeNames.joined(separator: ", "))"
        }
        
        if selectionState.isSelected {
            label += ", 已选择"
        }
        
        return label
    }
    
    private var accessibilityValue: String {
        var components: [String] = []
        
        if selectionState.isSelected {
            components.append("已选择")
        }
        
        if !product.colors.isEmpty {
            components.append("颜色数量: \(product.colors.count)")
        }
        
        if let sizes = product.sizes, !sizes.isEmpty {
            components.append("尺寸数量: \(sizes.count)")
        }
        
        return components.joined(separator: ", ")
    }
    
    private var accessibilityHint: String {
        if selectionState.isInBatchMode {
            return selectionState.isSelected ? "双击取消选择" : "双击选择此产品"
        } else {
            return "双击查看产品详情"
        }
    }
    
    // MARK: - Color Helper
    
    private func colorForName(_ colorName: String) -> Color {
        let lowercased = colorName.lowercased()
        switch lowercased {
        case "红色", "红", "red": return LopanColors.error
        case "蓝色", "蓝", "blue": return LopanColors.primary
        case "绿色", "绿", "green": return LopanColors.success
        case "黄色", "黄", "yellow": return LopanColors.warning
        case "橙色", "橙", "orange": return LopanColors.accent
        case "紫色", "紫", "purple": return LopanColors.premium
        case "粉色", "粉", "pink": return LopanColors.accent.opacity(0.7)
        case "黑色", "黑", "black": return LopanColors.textPrimary
        case "白色", "白", "white": return LopanColors.textOnPrimary
        case "灰色", "灰", "gray", "grey": return LopanColors.secondary
        case "棕色", "棕", "brown": return LopanColors.secondary
        case "深蓝色", "深蓝", "navy", "dark blue": return LopanColors.primary.opacity(0.7)
        case "浅蓝色", "浅蓝", "light blue": return LopanColors.primary.opacity(0.3)
        case "军绿色", "军绿", "olive": return LopanColors.success.opacity(0.6)
        case "米色", "米", "beige": return LopanColors.secondary.opacity(0.3)
        case "格子": return LopanColors.secondary
        default: return LopanColors.secondary
        }
    }
}

// MARK: - Async Image View

struct AsyncImageView: View {
    let uiImage: UIImage
    let size: CGFloat
    
    @State private var isLoaded = false
    
    var body: some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.15)
                    .stroke(LopanColors.border, lineWidth: 0.5)
            )
            .opacity(isLoaded ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isLoaded)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    isLoaded = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let sampleProduct = Product(
        name: "iPhone 15 Pro Max",
        colors: ["深空黑", "原色钛金属", "白色钛金属", "蓝色钛金属"],
        imageData: nil
    )
    
    let sampleSizes = [
        ProductSize(size: "128GB", product: sampleProduct),
        ProductSize(size: "256GB", product: sampleProduct),
        ProductSize(size: "512GB", product: sampleProduct),
        ProductSize(size: "1TB", product: sampleProduct)
    ]
    sampleProduct.sizes = sampleSizes
    
    return VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Mode")
                .font(.headline)
                .foregroundColor(.primary)
            
            AdaptiveProductCard(
                product: sampleProduct,
                displayMode: .detailed,
                selectionState: .none,
                onSelect: {},
                onSecondaryAction: {}
            )
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Standard Mode")
                .font(.headline)
                .foregroundColor(.primary)
            
            AdaptiveProductCard(
                product: sampleProduct,
                displayMode: .standard,
                selectionState: .selectable(isSelected: false),
                onSelect: {},
                onSecondaryAction: nil
            )
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Compact Mode")
                .font(.headline)
                .foregroundColor(.primary)
            
            AdaptiveProductCard(
                product: sampleProduct,
                displayMode: .compact,
                selectionState: .selectable(isSelected: true),
                onSelect: {},
                onSecondaryAction: nil
            )
        }
        
        Spacer()
    }
    .padding()
    .background(LopanColors.backgroundTertiary)
}

