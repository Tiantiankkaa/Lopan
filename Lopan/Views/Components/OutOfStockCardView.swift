//
//  OutOfStockCardView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockCardView: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingDetail = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        AnyView(
            makeInteractiveCard()
                .modifier(accessibilityModifier)
        )
    }

    @ViewBuilder
    private func makeInteractiveCard() -> some View {
        ZStack {
            cardBackground
            cardContent
            selectionOverlay
        }
        .scaleEffect(cardScale)
        .offset(x: cardOffset)
        .rotationEffect(.degrees(rotationAngle))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: cardScale)
        .gesture(
            DragGesture()
                .onChanged(handleDragChanged)
                .onEnded(handleDragEnded)
        )
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            handleLongPress()
        }
    }

    // MARK: - Card Background
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: isSelected ? [
                        LopanColors.primary.opacity(0.1),
                        LopanColors.primary.opacity(0.05)
                    ] : [
                        LopanColors.backgroundPrimary,
                        LopanColors.backgroundSecondary.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? LopanColors.primary.opacity(0.6) : LopanColors.secondary.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? LopanColors.primary.opacity(0.2) : LopanColors.shadow.opacity(1.6),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
                .opacity(0.5)
                .padding(.horizontal, 16)
            detailSection
            
            if item.needsDelivery || item.hasPartialDelivery {
                returnSection
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Customer Avatar
            customerAvatar
            
            // Customer Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.customerDisplayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.customerAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(item.requestDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var customerAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [customerAvatarColor, customerAvatarColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
            
            Text(String(item.customerDisplayName.prefix(1)))
                .font(.title3.weight(.bold))
                .foregroundColor(LopanColors.textPrimary)
        }
        .overlay(
            Circle()
                .stroke(LopanColors.textPrimary, lineWidth: 2)
                .shadow(color: LopanColors.textPrimary.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var customerAvatarColor: Color {
        let colors: [Color] = [LopanColors.primary, LopanColors.success, LopanColors.warning, LopanColors.primary, LopanColors.error, LopanColors.primary]
        let hash = abs(item.customerDisplayName.hashValue)
        return colors[hash % colors.count]
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(item.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.12))
        )
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return LopanColors.warning
        case .completed: return LopanColors.success
        case .refunded: return LopanColors.success
        }
    }
    
    // MARK: - Detail Section
    
    private var detailSection: some View {
        VStack(spacing: 12) {
            // Product Info
            productInfoRow
            
            // Quantity Info
            quantityInfoRow
            
            // Notes (if available)
            if let notes = item.notes, !notes.isEmpty {
                notesRow(notes)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var productInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.box")
                .symbolRenderingMode(.palette)
                .foregroundStyle(LopanColors.primary)
                .imageScale(.medium)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("产品信息")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.productDisplayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    private var quantityInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "number.circle")
                .imageScale(.medium)
                .foregroundColor(LopanColors.success)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("数量信息")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    quantityChip("缺货", "\(item.quantity)", LopanColors.warning)
                    
                    if item.deliveryQuantity > 0 {
                        quantityChip("已退", "\(item.deliveryQuantity)", LopanColors.primary)
                    }
                    
                    if item.remainingQuantity > 0 && item.deliveryQuantity > 0 {
                        quantityChip("剩余", "\(item.remainingQuantity)", LopanColors.error)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func quantityChip(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.1))
        )
    }
    
    private func notesRow(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "note.text")
                .imageScale(.medium)
                .foregroundColor(LopanColors.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("备注")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(notes)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Return Section
    
    private var returnSection: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)
                .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .imageScale(.small)
                    .foregroundColor(returnStatusColor)
                
                Text(returnStatusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(returnStatusColor)
                
                Spacer()
                
                if let returnDate = item.deliveryDate {
                    Text(returnDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(returnStatusColor.opacity(0.05))
        }
    }
    
    private var returnStatusColor: Color {
        if item.isFullyDelivered {
            return LopanColors.success
        } else if item.hasPartialDelivery {
            return LopanColors.primary
        } else if item.needsDelivery {
            return LopanColors.warning
        } else {
            return LopanColors.textSecondary
        }
    }
    
    private var returnStatusText: String {
        if item.isFullyDelivered {
            return "完全退货"
        } else if item.hasPartialDelivery {
            return "部分退货"
        } else if item.needsDelivery {
            return "需要退货"
        } else {
            return ""
        }
    }
    
    // MARK: - Selection Overlay
    
    private var selectionOverlay: some View {
        Group {
            if isInSelectionMode {
                VStack {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(isSelected ? LopanColors.primary : LopanColors.backgroundTertiary)
                                .frame(width: 24, height: 24)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(LopanColors.textPrimary)
                            }
                        }
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if isInSelectionMode { return }
        
        isDragging = true
        cardOffset = value.translation.width * 0.3
        
        // Add slight rotation based on drag
        rotationAngle = Double(value.translation.width) * 0.02
        
        // Scale down slightly when dragging
        cardScale = 0.98
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        if isInSelectionMode { return }
        
        isDragging = false
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cardOffset = 0
            cardScale = 1.0
            rotationAngle = 0
        }
        
        // Handle swipe actions
        if abs(value.translation.width) > 100 {
            if value.translation.width > 0 {
                // Swipe right - Mark as completed or edit
                handleSwipeRight()
            } else {
                // Swipe left - Delete or archive
                handleSwipeLeft()
            }
        }
    }
    
    private func handleTap() {
        LopanHapticEngine.shared.light()
        
        withAnimation(.easeInOut(duration: 0.1)) {
            cardScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                cardScale = 1.0
            }
            onTap()
        }
    }
    
    private func handleLongPress() {
        LopanHapticEngine.shared.heavy()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cardScale = 1.05
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                cardScale = 1.0
            }
        }
        
        onLongPress()
    }
    
    private func handleSwipeRight() {
        // Swipe right - Quick mark as completed or edit
        LopanHapticEngine.shared.medium()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cardOffset = 100
            cardScale = 1.05
        }
        
        // Show quick action feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cardOffset = 0
                cardScale = 1.0
            }
        }
        
        // Implement actual action based on current status
        if item.status == .pending {
            // Mark as completed
            print("Quick action: Mark as completed - \(item.id)")
        } else {
            // Edit item
            print("Quick action: Edit item - \(item.id)")
        }
    }
    
    private func handleSwipeLeft() {
        // Swipe left - Quick delete or archive
        LopanHapticEngine.shared.heavy()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cardOffset = -100
            cardScale = 0.95
            rotationAngle = -5
        }
        
        // Show delete action feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cardOffset = 0
                cardScale = 1.0
                rotationAngle = 0
            }
        }
        
        print("Quick action: Delete item - \(item.id)")
    }


    private var accessibilityLabel: Text {
        Text("客户 \(item.customerDisplayName)，状态 \(item.status.displayName)")
    }

    private var accessibilityValue: Text {
        if item.deliveryQuantity > 0 {
            return Text("缺货 \(item.quantity) 件，已退 \(item.deliveryQuantity) 件")
        } else {
            return Text("缺货 \(item.quantity) 件")
        }
    }

    private var accessibilityModifier: OutOfStockCardAccessibilityModifier {
        OutOfStockCardAccessibilityModifier(
            item: item,
            onActivate: { handleTap() },
            onToggleSelection: { handleLongPress() }
        )
    }
}

private struct OutOfStockCardAccessibilityModifier: ViewModifier {
    let item: CustomerOutOfStock
    let onActivate: () -> Void
    let onToggleSelection: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("客户 \(item.customerDisplayName)，状态 \(item.status.displayName)"))
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(Text("双击查看详情，长按进入多选"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onActivate() }
            .accessibilityAction(named: Text("切换选择")) { onToggleSelection() }
            .accessibilityCustomContent("客户地址", item.customerAddress)
            .accessibilityCustomContent("状态", item.status.displayName)
            .accessibilityCustomContent("缺货数量", "\(item.quantity)")
            .accessibilityCustomContent(
                "退货数量",
                item.deliveryQuantity > 0 ? "\(item.deliveryQuantity)" : "无"
            )
    }

    private var accessibilityValue: Text {
        if item.deliveryQuantity > 0 {
            return Text("缺货 \(item.quantity) 件，已退 \(item.deliveryQuantity) 件")
        } else {
            return Text("缺货 \(item.quantity) 件")
        }
    }
}

// MARK: - Preview

struct OutOfStockCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            OutOfStockCardView(
                item: sampleItem,
                isSelected: false,
                isInSelectionMode: false,
                onTap: {},
                onLongPress: {}
            )
            
            OutOfStockCardView(
                item: sampleItem,
                isSelected: true,
                isInSelectionMode: true,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding()
        .background(LopanColors.backgroundTertiary)
    }
    
    static var sampleItem: CustomerOutOfStock {
        let customer = Customer(name: "张三", address: "上海市浦东新区", phone: "13800138000")
        let product = Product(name: "高级西装", colors: ["黑色", "灰色"])
        return CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: 5,
            notes: "客户急需，优先处理",
            createdBy: "demo_user"
        )
    }
}
