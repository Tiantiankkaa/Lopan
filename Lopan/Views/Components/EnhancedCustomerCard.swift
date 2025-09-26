//
//  EnhancedCustomerCard.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  完美主义设计师精心打造的客户卡片组件
//

import SwiftUI

/// 增强型客户卡片 - 追求完美的UI设计
/// 采用三层信息架构，渐进式信息展示
struct EnhancedCustomerCard: View {
    // MARK: - Properties
    let customer: Customer
    let displayMode: CardDisplayMode
    let selectionState: SelectionState
    let interactionHistory: CustomerInteractionHistory?
    let onSelect: () -> Void
    let onSecondaryAction: (() -> Void)?
    
    // MARK: - State Management
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var showingExpandedInfo = false
    @State private var cardScale: CGFloat = 1.0
    @State private var shadowIntensity: Double = 0.1
    
    // MARK: - Card Display Modes
    enum CardDisplayMode {
        case compact    // 紧凑模式：基本信息
        case standard   // 标准模式：平衡的信息展示
        case detailed   // 详细模式：完整信息预览
        case featured   // 特色模式：重要客户突出显示
        
        var cardHeight: CGFloat {
            switch self {
            case .compact: return 80
            case .standard: return 120
            case .detailed: return 160
            case .featured: return 200
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 12
            case .standard: return 16
            case .detailed: return 20
            case .featured: return 24
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .compact: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            case .standard: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            case .detailed: return EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
            case .featured: return EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)
            }
        }
    }
    
    // MARK: - Selection States
    enum SelectionState: Equatable {
        case none
        case selectable(isSelected: Bool)
        case disabled
        case highlighted
        
        var isSelected: Bool {
            if case .selectable(let selected) = self { return selected }
            return false
        }
        
        var isInteractive: Bool {
            switch self {
            case .selectable, .highlighted: return true
            case .none, .disabled: return false
            }
        }
        
        var isSelectableMode: Bool {
            if case .selectable = self { return true }
            return false
        }
    }
    
    // MARK: - Main Body
    var body: some View {
        cardContent
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: displayMode.cornerRadius))
            .overlay(cardBorder)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffsetY
            )
            .scaleEffect(cardScale)
            .opacity(selectionState == .disabled ? 0.6 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectionState.isSelected)
            .animation(.easeInOut(duration: 0.3), value: showingExpandedInfo)
            .contentShape(Rectangle())
            .onTapGesture(perform: handleTapGesture)
            .onLongPressGesture(
                minimumDuration: 0.0,
                maximumDistance: .infinity,
                perform: {},
                onPressingChanged: handlePressStateChange
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(selectionState.isInteractive ? .isButton : [])
    }
    
    // MARK: - Card Content
    private var cardContent: some View {
        HStack(spacing: displayMode.padding.leading) {
            // 选择指示器
            selectionIndicator
            
            // 客户头像区域
            customerAvatarSection
            
            // 主要信息区域
            VStack(alignment: .leading, spacing: 8) {
                primaryInfoSection
                
                if displayMode != .compact {
                    secondaryInfoSection
                }
                
                if displayMode == .detailed || displayMode == .featured {
                    tertiaryInfoSection
                }
                
                if showingExpandedInfo && displayMode == .featured {
                    expandedInfoSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                        ))
                }
            }
            
            Spacer()
            
            // 右侧指示器和操作
            trailingSection
        }
        .padding(displayMode.padding)
        .frame(minHeight: displayMode.cardHeight, alignment: .center)
    }
    
    // MARK: - Selection Indicator
    @ViewBuilder
    private var selectionIndicator: some View {
        if case .selectable(let isSelected) = selectionState {
            Button(action: onSelect) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? LopanColors.primary : LopanColors.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(LopanColors.primary)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(LopanColors.textPrimary)
                            )
                            .scaleEffect(isSelected ? 1.0 : 0.1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isSelected ? "取消选择客户" : "选择客户")
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Customer Avatar Section
    private var customerAvatarSection: some View {
        ZStack {
            // 背景渐变圆圈
            Circle()
                .fill(avatarGradient)
                .frame(width: avatarSize, height: avatarSize)
                .shadow(color: avatarShadowColor, radius: 4, x: 0, y: 2)
            
            // 客户头像或初始字母
            // Note: Customer model doesn't have imageData property yet
            if false { // Placeholder for future image support
                EmptyView()
            } else {
                Text(String(customer.name.prefix(1)).uppercased())
                    .font(.system(size: avatarFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(LopanColors.textPrimary)
            }
            
            // 活跃状态指示器
            if let history = interactionHistory, history.isRecentlyActive {
                Circle()
                    .fill(LopanColors.success)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(cardBackgroundColor, lineWidth: 2)
                    )
                    .offset(x: avatarSize/3, y: -avatarSize/3)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    // MARK: - Primary Info Section (Name + Priority)
    private var primaryInfoSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(customer.name)
                .font(primaryNameFont)
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.textPrimary)
                .lineLimit(1)
            
            // 优先级徽章
            if let priority = customerPriority, priority != .normal {
                PriorityBadge(priority: priority, size: .small)
                    .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // 客户编号（仅在详细模式显示）
            if displayMode == .detailed || displayMode == .featured {
                Text(customer.customerNumber)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.backgroundTertiary)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Secondary Info Section (Address + Phone)
    private var secondaryInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !customer.address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(LopanColors.info)
                    
                    Text(customer.address)
                        .font(.callout)
                        .foregroundColor(LopanColors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            if !customer.phone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(LopanColors.success)
                    
                    Text(customer.phone)
                        .font(.callout)
                        .foregroundColor(LopanColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Tertiary Info Section (Stats + Last Contact)
    private var tertiaryInfoSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // 客户统计信息
            if let history = interactionHistory {
                HStack(spacing: 8) {
                    StatChip(
                        icon: "bag.fill",
                        value: "\(history.orderCount)",
                        color: LopanColors.primary
                    )
                    
                    if history.outOfStockCount > 0 {
                        StatChip(
                            icon: "exclamationmark.triangle.fill",
                            value: "\(history.outOfStockCount)",
                            color: LopanColors.error
                        )
                    }
                }
            }
            
            Spacer()
            
            // 最后联系时间
            Text(customer.updatedAt.timeAgoDisplay())
                .font(.caption2)
                .foregroundColor(LopanColors.textTertiary)
        }
    }
    
    // MARK: - Expanded Info Section (Featured mode only)
    @ViewBuilder
    private var expandedInfoSection: some View {
        if displayMode == .featured {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                    .background(LopanColors.border)
                
                HStack {
                    Text("最近订单")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textSecondary)
                    
                    Spacer()
                    
                    if let history = interactionHistory, let lastOrderDate = history.lastOrderDate {
                        Text(lastOrderDate.timeAgoDisplay())
                            .font(.caption2)
                            .foregroundColor(LopanColors.textTertiary)
                    } else {
                        Text("无订单记录")
                            .font(.caption2)
                            .foregroundColor(LopanColors.textTertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - Trailing Section
    private var trailingSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !selectionState.isSelectableMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(LopanColors.textTertiary)
                    .opacity(isPressed ? 0.5 : 1.0)
            }
            
            if displayMode == .featured, let onSecondaryAction = onSecondaryAction {
                Button(action: onSecondaryAction) {
                    Image(systemName: "ellipsis")
                        .font(.callout)
                        .foregroundColor(LopanColors.textSecondary)
                        .padding(8)
                        .background(LopanColors.backgroundSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Visual Properties
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: displayMode.cornerRadius)
            .fill(cardBackgroundColor)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: displayMode.cornerRadius)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    // MARK: - Computed Properties
    private var avatarSize: CGFloat {
        switch displayMode {
        case .compact: return 44
        case .standard: return 52
        case .detailed: return 60
        case .featured: return 68
        }
    }
    
    private var avatarFontSize: CGFloat {
        switch displayMode {
        case .compact: return 18
        case .standard: return 20
        case .detailed: return 24
        case .featured: return 28
        }
    }
    
    private var primaryNameFont: Font {
        switch displayMode {
        case .compact: return .callout
        case .standard: return .body
        case .detailed: return .headline
        case .featured: return .title3
        }
    }
    
    private var avatarGradient: LinearGradient {
        let baseColor = customerPriority?.color ?? LopanColors.warning
        return LinearGradient(
            colors: [baseColor, baseColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackgroundColor: Color {
        if selectionState.isSelected {
            return LopanColors.primary.opacity(0.08)
        } else if isPressed {
            return LopanColors.backgroundSecondary
        } else {
            return LopanColors.background
        }
    }
    
    private var borderColor: Color {
        if selectionState.isSelected {
            return LopanColors.primary.opacity(0.4)
        } else {
            return LopanColors.border
        }
    }
    
    private var borderWidth: CGFloat {
        selectionState.isSelected ? 1.5 : 0.5
    }
    
    private var shadowColor: Color {
        if selectionState.isSelected {
            return LopanColors.primary.opacity(0.2)
        } else if isPressed {
            return LopanColors.shadow.opacity(2)
        } else {
            return LopanColors.shadow
        }
    }
    
    private var shadowRadius: CGFloat {
        if selectionState.isSelected {
            return 8
        } else if isPressed {
            return 2
        } else {
            switch displayMode {
            case .compact: return 3
            case .standard: return 4
            case .detailed: return 6
            case .featured: return 8
            }
        }
    }
    
    private var shadowOffsetY: CGFloat {
        if selectionState.isSelected {
            return 4
        } else if isPressed {
            return 1
        } else {
            switch displayMode {
            case .compact: return 1
            case .standard: return 2
            case .detailed: return 3
            case .featured: return 4
            }
        }
    }
    
    private var avatarShadowColor: Color {
        (customerPriority?.color ?? LopanColors.warning).opacity(0.3)
    }
    
    private var customerPriority: CustomerPriority? {
        // 基于交互历史确定客户优先级
        guard let history = interactionHistory else { return .normal }
        
        if history.isVIPCustomer {
            return .vip
        } else if history.isPotentialCustomer {
            return .potential
        } else if history.isHighValue {
            return .high
        } else {
            return .normal
        }
    }
    
    // MARK: - Interaction Handling
    private func handleTapGesture() {
        if selectionState.isInteractive {
            // 触觉反馈
            LopanHapticEngine.shared.light()
            onSelect()
        }
    }
    
    private func handlePressStateChange(_ pressing: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPressed = pressing
            cardScale = pressing ? 0.98 : 1.0
            shadowIntensity = pressing ? 0.05 : 0.1
        }
    }
    
    // MARK: - Accessibility
    private var accessibilityLabel: String {
        var label = "客户 \(customer.name)"
        
        if !customer.address.isEmpty {
            label += ", 地址 \(customer.address)"
        }
        
        if !customer.phone.isEmpty {
            label += ", 电话 \(customer.phone)"
        }
        
        if selectionState.isSelected {
            label += ", 已选择"
        }
        
        if let priority = customerPriority, priority != .normal {
            label += ", \(priority.displayName)客户"
        }
        
        return label
    }
    
    private var accessibilityHint: String {
        if case .selectable = selectionState {
            return selectionState.isSelected ? "双击取消选择" : "双击选择此客户"
        } else {
            return "双击查看客户详情"
        }
    }
}

// MARK: - Supporting Models and Views

/// 客户优先级枚举
enum CustomerPriority: String, CaseIterable {
    case vip = "VIP"
    case high = "高价值"
    case potential = "潜在"
    case normal = "普通"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .vip: return LopanColors.premium
        case .high: return LopanColors.success
        case .potential: return LopanColors.info
        case .normal: return LopanColors.secondary
        }
    }
}

/// 客户交互历史数据模型
struct CustomerInteractionHistory {
    let orderCount: Int
    let outOfStockCount: Int
    let lastOrderDate: Date?
    let lastContactDate: Date?
    let totalValue: Double
    let isRecentlyActive: Bool
    
    var isVIPCustomer: Bool {
        return totalValue > 50000 && orderCount > 20
    }
    
    var isHighValue: Bool {
        return totalValue > 20000 || orderCount > 10
    }
    
    var isPotentialCustomer: Bool {
        return orderCount < 3 && lastContactDate != nil && 
               Calendar.current.dateComponents([.day], from: lastContactDate!, to: Date()).day ?? 0 < 30
    }
}

/// 优先级徽章组件
struct PriorityBadge: View {
    let priority: CustomerPriority
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .callout
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .large: return EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
            }
        }
    }
    
    var body: some View {
        Text(priority.displayName)
            .font(size.font)
            .fontWeight(.medium)
            .foregroundColor(LopanColors.textPrimary)
            .padding(size.padding)
            .background(priority.color.gradient)
            .clipShape(Capsule())
    }
}

/// 统计芯片组件
struct StatChip: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Date Extension
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview
#Preview {
    let sampleCustomer = Customer(
        name: "张三",
        address: "北京市朝阳区建国门外大街1号",
        phone: "138-0013-8000"
    )
    
    let sampleHistory = CustomerInteractionHistory(
        orderCount: 15,
        outOfStockCount: 2,
        lastOrderDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
        lastContactDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
        totalValue: 25000.0,
        isRecentlyActive: true
    )
    
    return VStack(spacing: 20) {
        EnhancedCustomerCard(
            customer: sampleCustomer,
            displayMode: .compact,
            selectionState: .none,
            interactionHistory: nil,
            onSelect: {},
            onSecondaryAction: nil
        )
        
        EnhancedCustomerCard(
            customer: sampleCustomer,
            displayMode: .standard,
            selectionState: .selectable(isSelected: false),
            interactionHistory: sampleHistory,
            onSelect: {},
            onSecondaryAction: nil
        )
        
        EnhancedCustomerCard(
            customer: sampleCustomer,
            displayMode: .detailed,
            selectionState: .selectable(isSelected: true),
            interactionHistory: sampleHistory,
            onSelect: {},
            onSecondaryAction: {}
        )
        
        EnhancedCustomerCard(
            customer: sampleCustomer,
            displayMode: .featured,
            selectionState: .highlighted,
            interactionHistory: sampleHistory,
            onSelect: {},
            onSecondaryAction: {}
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
}