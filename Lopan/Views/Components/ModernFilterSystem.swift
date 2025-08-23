//
//  ModernFilterSystem.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/21.
//

import SwiftUI

// MARK: - Modern Filter Chip

struct ModernFilterChip: View {
    let title: String
    let icon: String?
    let isActive: Bool
    let count: Int?
    let action: () -> Void
    let onRemove: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        title: String,
        icon: String? = nil,
        isActive: Bool = false,
        count: Int? = nil,
        action: @escaping () -> Void,
        onRemove: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.isActive = isActive
        self.count = count
        self.action = action
        self.onRemove = onRemove
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isActive ? .white : LopanColors.primary)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isActive ? .white : LopanColors.textPrimary)
                    .lineLimit(1)
                
                // Count badge
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isActive ? LopanColors.primary : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isActive ? .white : LopanColors.primary)
                        )
                }
                
                // Remove button
                if let onRemove = onRemove, isActive {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(filterChipBackground)
            .cornerRadius(20)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .shadow(
                color: isActive ? LopanColors.primary.opacity(0.3) : .black.opacity(0.08),
                radius: isPressed ? 4 : 8,
                x: 0,
                y: isPressed ? 2 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity) { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        } perform: {
            action()
        }
        .sensoryFeedback(.selection, trigger: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityAction(named: "选择") {
            action()
        }
        .accessibilityAction(.default) {
            action()
        }
    }
    
    private var accessibilityLabel: String {
        var label = title
        
        if let count = count, count > 0 {
            label += ", \(count) 项"
        }
        
        if isActive {
            label += ", 已选中"
        }
        
        return label
    }
    
    private var accessibilityHint: String {
        if isActive {
            return onRemove != nil ? "双击可移除此筛选条件" : "已选中的筛选条件"
        } else {
            return "双击可选择此筛选条件"
        }
    }
    
    private var filterChipBackground: some View {
        Group {
            if isActive {
                // Active state with gradient
                LinearGradient(
                    colors: [LopanColors.primary, LopanColors.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Inactive state with glass morphism
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        }
    }
}

// MARK: - Modern Date Range Selector

struct ModernDateRangeSelector: View {
    @Binding var selectedOption: DateFilterOption?
    @Binding var customRange: (start: Date, end: Date)?
    @State private var showingCustomPicker = false
    
    let onSelectionChange: (DateFilterOption?) -> Void
    
    private let quickOptions: [DateFilterOption] = [
        .thisWeek,
        .thisMonth
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LopanColors.primary)
                
                Text("日期范围筛选")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LopanColors.textPrimary)
                
                Spacer()
                
                if selectedOption != nil {
                    Button("清除") {
                        selectedOption = Optional<DateFilterOption>.none
                        customRange = Optional<(start: Date, end: Date)>.none
                        onSelectionChange(Optional<DateFilterOption>.none)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LopanColors.error)
                }
            }
            
            // Quick selection options
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 12) {
                ForEach(quickOptions, id: \.self) { option in
                    dateOptionButton(option)
                }
                
                customDateButton
            }
            
            // Custom range picker
            if showingCustomPicker {
                customRangePicker
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .padding(20)
        .background(modernCardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    private func dateOptionButton(_ option: DateFilterOption) -> some View {
        Button(action: {
            selectedOption = option
            showingCustomPicker = false
            onSelectionChange(option)
        }) {
            VStack(spacing: 8) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedOption == option ? .white : LopanColors.primary)
                
                Text(option.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(selectedOption == option ? .white : LopanColors.textPrimary)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedOption == option ? LopanColors.primary : LopanColors.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        selectedOption == option ? Color.clear : LopanColors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var customDateButton: some View {
        Button(action: {
            showingCustomPicker.toggle()
            if !showingCustomPicker && selectedOption?.isCustom == true {
                selectedOption = Optional<DateFilterOption>.none
                onSelectionChange(Optional<DateFilterOption>.none)
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(showingCustomPicker ? .white : LopanColors.primary)
                
                Text("自定义")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showingCustomPicker ? .white : LopanColors.textPrimary)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(showingCustomPicker ? LopanColors.primary : LopanColors.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        showingCustomPicker ? Color.clear : LopanColors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var customRangePicker: some View {
        VStack(spacing: 16) {
            Text("选择日期范围 (最多3个月)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(LopanColors.textSecondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("开始日期")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LopanColors.textSecondary)
                    
                    DatePicker("", selection: Binding(
                        get: { customRange?.start ?? Date() },
                        set: { newValue in
                            updateCustomRange(start: newValue)
                        }
                    ), displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(0.9)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("结束日期")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LopanColors.textSecondary)
                    
                    DatePicker("", selection: Binding(
                        get: { customRange?.end ?? Date() },
                        set: { newValue in
                            updateCustomRange(end: newValue)
                        }
                    ), displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(0.9)
                }
            }
            
            HStack(spacing: 12) {
                Button("取消") {
                    showingCustomPicker = false
                    selectedOption = Optional<DateFilterOption>.none
                    customRange = Optional<(start: Date, end: Date)>.none
                    onSelectionChange(Optional<DateFilterOption>.none)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(LopanColors.error)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LopanColors.backgroundSecondary)
                )
                
                Spacer()
                
                Button("应用") {
                    if let range = customRange {
                        let customOption = DateFilterOption.custom(start: range.start, end: range.end)
                        selectedOption = customOption
                        onSelectionChange(customOption)
                        showingCustomPicker = false
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LopanColors.primary)
                )
                .disabled(customRange == nil)
            }
        }
        .padding(16)
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private func updateCustomRange(start: Date? = nil, end: Date? = nil) {
        let currentRange = customRange ?? (start: Date(), end: Date())
        
        let newStart = start ?? currentRange.start
        let newEnd = end ?? currentRange.end
        
        // Validate 3-month maximum range
        let calendar = Calendar.current
        let maxEndDate = calendar.date(byAdding: .month, value: 3, to: newStart) ?? newEnd
        let validEndDate = min(newEnd, maxEndDate)
        
        customRange = (start: newStart, end: validEndDate)
    }
    
    private var modernCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LopanColors.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LopanColors.borderLight, lineWidth: 1)
            )
    }
}

// MARK: - Modern Filter Section

struct ModernFilterSection: View {
    let title: String
    let icon: String
    let content: () -> AnyView
    
    @State private var isExpanded = false
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.icon = icon
        self.content = { AnyView(content()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LopanColors.primary)
                        .frame(width: 20, height: 20)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LopanColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(LopanColors.backgroundPrimary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            if isExpanded {
                content()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(LopanColors.backgroundPrimary)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .background(LopanColors.backgroundPrimary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(LopanColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Active Filters Summary

struct ActiveFiltersSummary: View {
    let filters: [FilterItem]
    let onRemoveAll: () -> Void
    
    struct FilterItem {
        let title: String
        let value: String
        let color: Color
        let onRemove: () -> Void
    }
    
    var body: some View {
        if !filters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("已选筛选条件")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Spacer()
                    
                    Button("清除全部") {
                        onRemoveAll()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LopanColors.error)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters.indices, id: \.self) { index in
                            let filter = filters[index]
                            ModernFilterChip(
                                title: "\(filter.title): \(filter.value)",
                                isActive: true,
                                action: {},
                                onRemove: filter.onRemove
                            )
                        }
                    }
                    .padding(.horizontal, 1) // For shadow
                }
            }
            .padding(20)
            .background(modernCardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
    }
    
    private var modernCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LopanColors.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LopanColors.borderLight, lineWidth: 1)
            )
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ActiveFiltersSummary(
                filters: [
                    ActiveFiltersSummary.FilterItem(
                        title: "客户",
                        value: "重要客户 039",
                        color: .blue,
                        onRemove: {}
                    ),
                    ActiveFiltersSummary.FilterItem(
                        title: "产品",
                        value: "限量商务毛衣-M",
                        color: .green,
                        onRemove: {}
                    )
                ],
                onRemoveAll: {}
            )
            
            ModernDateRangeSelector(
                selectedOption: .constant(nil),
                customRange: .constant(nil),
                onSelectionChange: { _ in }
            )
            
            ModernFilterSection(title: "快速筛选", icon: "line.3.horizontal.decrease") {
                VStack(spacing: 12) {
                    ModernFilterChip(title: "全部客户", icon: "person.circle", action: {})
                    ModernFilterChip(title: "全部产品", icon: "cube.box", action: {})
                    ModernFilterChip(title: "待处理", icon: "clock", isActive: true, count: 20, action: {}, onRemove: {})
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
#endif