//
//  SmartFilterBar.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  智能筛选栏 - 完美主义设计师的交互艺术品
//

import SwiftUI

// MARK: - 智能筛选栏主组件
/// 动态筛选栏，每一个滤镜都经过精心设计的微交互
struct SmartFilterBar: View {
    // MARK: - Properties
    @StateObject private var filterEngine = FilterEngine()
    @StateObject private var filterAnalytics = FilterAnalytics()
    
    @Binding var activeFilters: Set<FilterOption>
    @Binding var isFilterBarVisible: Bool
    
    let availableFilters: [FilterCategory]
    let filterScope: FilterScope
    let onFiltersChanged: ([FilterOption]) -> Void
    let onFilterSaved: (SavedFilter) -> Void
    
    // MARK: - State Management
    @State private var showingSavedFilters = false
    @State private var showingFilterPreview = false
    @State private var showingCustomFilterSheet = false
    @State private var selectedCategory: FilterCategory?
    @State private var filterPillOffset: CGFloat = 0
    @State private var filterBarHeight: CGFloat = 0
    @State private var previewResults: FilterPreviewResults?
    
    // MARK: - Animation States
    @State private var filterBarScale: CGFloat = 1.0
    @State private var pillAnimationPhase: Double = 0
    @State private var clearButtonRotation: Double = 0
    
    enum FilterScope {
        case customers
        case products
        case orders
        case analytics
        
        var title: String {
            switch self {
            case .customers: return "客户筛选"
            case .products: return "产品筛选"
            case .orders: return "订单筛选"
            case .analytics: return "分析筛选"
            }
        }
    }
    
    init(
        activeFilters: Binding<Set<FilterOption>>,
        isVisible: Binding<Bool>,
        availableFilters: [FilterCategory],
        scope: FilterScope,
        onFiltersChanged: @escaping ([FilterOption]) -> Void,
        onFilterSaved: @escaping (SavedFilter) -> Void = { _ in }
    ) {
        self._activeFilters = activeFilters
        self._isFilterBarVisible = isVisible
        self.availableFilters = availableFilters
        self.filterScope = scope
        self.onFiltersChanged = onFiltersChanged
        self.onFilterSaved = onFilterSaved
    }
    
    var body: some View {
        if isFilterBarVisible {
            VStack(spacing: 0) {
                // 主筛选栏
                mainFilterBar
                
                // 动态筛选药丸区域
                if !activeFilters.isEmpty {
                    activeFilterPillsSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
                
                // 筛选预览区域
                if showingFilterPreview, let preview = previewResults {
                    filterPreviewSection(preview: preview)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                }
            }
            .background(filterBarBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .scaleEffect(filterBarScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFilterBarVisible)
            .animation(.easeInOut(duration: 0.3), value: activeFilters)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showingFilterPreview)
            .sheet(isPresented: $showingSavedFilters) {
                savedFiltersSheet
            }
            .sheet(isPresented: $showingCustomFilterSheet) {
                customFilterSheet
            }
        }
    }
    
    // MARK: - Main Filter Bar
    private var mainFilterBar: some View {
        HStack(spacing: 16) {
            // 筛选图标和标题
            filterTitleSection
            
            // 筛选类别按钮
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(availableFilters, id: \.id) { category in
                        FilterCategoryButton(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            activeFiltersCount: activeFiltersCount(for: category),
                            onTap: { handleCategoryTap(category) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 44)
            
            // 操作按钮区域
            trailingActionsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Filter Title Section
    private var filterTitleSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
                .foregroundColor(LopanColors.primary)
                .rotationEffect(.degrees(pillAnimationPhase * 360))
                .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: pillAnimationPhase)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(filterScope.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(LopanColors.textPrimary)
                
                if !activeFilters.isEmpty {
                    Text("\(activeFilters.count)个筛选条件")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            pillAnimationPhase = 1
        }
    }
    
    // MARK: - Trailing Actions Section
    private var trailingActionsSection: some View {
        HStack(spacing: 12) {
            // 保存筛选按钮
            if !activeFilters.isEmpty {
                Button(action: handleSaveFilter) {
                    Image(systemName: "bookmark.circle")
                        .font(.title3)
                        .foregroundColor(LopanColors.info)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("保存当前筛选")
            }
            
            // 已保存筛选按钮
            Button(action: { showingSavedFilters.toggle() }) {
                ZStack {
                    Image(systemName: "folder.circle")
                        .font(.title3)
                        .foregroundColor(LopanColors.secondary)
                    
                    if !filterAnalytics.savedFilters.isEmpty {
                        Circle()
                            .fill(LopanColors.error)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("查看已保存的筛选")
            
            // 清除所有筛选按钮
            if !activeFilters.isEmpty {
                Button(action: handleClearAllFilters) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(LopanColors.error)
                        .rotationEffect(.degrees(clearButtonRotation))
                        .scaleEffect(clearButtonRotation != 0 ? 1.1 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("清除所有筛选")
            }
        }
    }
    
    // MARK: - Active Filter Pills Section
    private var activeFilterPillsSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(LopanColors.border)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(activeFilters), id: \.id) { filter in
                        ActiveFilterPill(
                            filter: filter,
                            onRemove: { handleRemoveFilter(filter) },
                            onTap: { handleFilterPillTap(filter) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .offset(x: filterPillOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: activeFilters)
            }
            .frame(height: 36)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Preview Section
    @ViewBuilder
    private func filterPreviewSection(preview: FilterPreviewResults) -> some View {
        VStack(spacing: 12) {
            Divider()
                .background(LopanColors.border)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预览结果")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text("找到 \(preview.totalCount) 条匹配记录")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                Spacer()
                
                if preview.estimatedFilterTime > 0.1 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(LopanColors.warning)
                        
                        Text(String(format: "%.1fs", preview.estimatedFilterTime))
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                }
                
                Button(action: { showingFilterPreview = false }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(LopanColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Filter Bar Background
    private var filterBarBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LopanColors.border.opacity(0.5), lineWidth: 0.5)
            )
    }
    
    // MARK: - Saved Filters Sheet
    private var savedFiltersSheet: some View {
        NavigationStack {
            SavedFiltersView(
                savedFilters: filterAnalytics.savedFilters,
                onApplyFilter: handleApplySavedFilter,
                onDeleteFilter: handleDeleteSavedFilter
            )
            .navigationTitle("已保存的筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingSavedFilters = false
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Filter Sheet
    private var customFilterSheet: some View {
        NavigationStack {
            CustomFilterBuilder(
                availableFilters: availableFilters,
                currentFilters: Array(activeFilters),
                onFiltersChanged: { newFilters in
                    activeFilters = Set(newFilters)
                    showingCustomFilterSheet = false
                }
            )
            .navigationTitle("自定义筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showingCustomFilterSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Action Handlers
    private func handleCategoryTap(_ category: FilterCategory) {
        if selectedCategory?.id == category.id {
            selectedCategory = nil
        } else {
            selectedCategory = category
            // 触觉反馈
            EnhancedHapticEngine.shared.perform(.filterApply)
            
            // 自动展开该类别的常用筛选
            showQuickFiltersForCategory(category)
        }
    }
    
    private func handleRemoveFilter(_ filter: FilterOption) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeFilters.remove(filter)
            onFiltersChanged(Array(activeFilters))
            
            // 记录筛选移除
            filterAnalytics.recordFilterRemoval(filter)
            
            // 触觉反馈
            EnhancedHapticEngine.shared.perform(.filterClear)
        }
    }
    
    private func handleFilterPillTap(_ filter: FilterOption) {
        // 显示筛选详情或编辑选项
        showingFilterPreview = true
        generateFilterPreview()
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.cardTap)
    }
    
    private func handleClearAllFilters() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            clearButtonRotation = 360
            activeFilters.removeAll()
            onFiltersChanged([])
            
            // 记录清除操作
            filterAnalytics.recordFilterClear()
            
            // 触觉反馈
            EnhancedHapticEngine.shared.perform(.customerDeleteFailed)
        }
        
        // 重置旋转角度
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            clearButtonRotation = 0
        }
    }
    
    private func handleSaveFilter() {
        let savedFilter = SavedFilter(
            name: generateFilterName(),
            filters: Array(activeFilters),
            scope: filterScope,
            createdAt: Date()
        )
        
        filterAnalytics.saveFilter(savedFilter)
        onFilterSaved(savedFilter)
        
        // 成功反馈
        EnhancedHapticEngine.shared.perform(.formSaveSuccess)
    }
    
    private func handleApplySavedFilter(_ savedFilter: SavedFilter) {
        activeFilters = Set(savedFilter.filters)
        onFiltersChanged(savedFilter.filters)
        
        // 记录使用
        filterAnalytics.recordSavedFilterUsage(savedFilter)
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.filterApply)
        
        showingSavedFilters = false
    }
    
    private func handleDeleteSavedFilter(_ savedFilter: SavedFilter) {
        filterAnalytics.deleteSavedFilter(savedFilter)
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.customerDeleted)
    }
    
    // MARK: - Helper Methods
    private func activeFiltersCount(for category: FilterCategory) -> Int {
        return activeFilters.filter { $0.categoryId == category.id }.count
    }
    
    private func showQuickFiltersForCategory(_ category: FilterCategory) {
        // 自动应用该类别的智能默认筛选
        let intelligentDefaults = filterEngine.getIntelligentDefaults(for: category, scope: filterScope)
        
        for defaultFilter in intelligentDefaults {
            if !activeFilters.contains(defaultFilter) {
                activeFilters.insert(defaultFilter)
            }
        }
        
        onFiltersChanged(Array(activeFilters))
    }
    
    private func generateFilterPreview() {
        filterEngine.generatePreview(for: Array(activeFilters), scope: filterScope) { preview in
            DispatchQueue.main.async {
                self.previewResults = preview
            }
        }
    }
    
    private func generateFilterName() -> String {
        if activeFilters.count == 1 {
            return activeFilters.first?.displayName ?? "自定义筛选"
        } else {
            return "\(filterScope.title) - \(activeFilters.count)个条件"
        }
    }
}

// MARK: - Supporting Views

/// 筛选类别按钮
struct FilterCategoryButton: View {
    let category: FilterCategory
    let isSelected: Bool
    let activeFiltersCount: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.callout)
                
                Text(category.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                
                if activeFiltersCount > 0 {
                    Text("\(activeFiltersCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(LopanColors.primary)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundColor(isSelected ? .white : LopanColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? LopanColors.primary : Color(.systemGray5))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            perform: {},
            onPressingChanged: { pressing in
                isPressed = pressing
            }
        )
    }
}

/// 活跃筛选药丸
struct ActiveFilterPill: View {
    let filter: FilterOption
    let onRemove: () -> Void
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    if let iconName = filter.iconName {
                        Image(systemName: iconName)
                            .font(.caption)
                    }
                    
                    Text(filter.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(filter.color.gradient)
                .shadow(color: filter.color.opacity(0.3), radius: 2, x: 0, y: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            perform: {},
            onPressingChanged: { pressing in
                isPressed = pressing
            }
        )
    }
}

// MARK: - Supporting Models

/// 筛选类别
struct FilterCategory {
    let id: String
    let displayName: String
    let iconName: String
    let availableOptions: [FilterOption]
}

/// 筛选选项
struct FilterOption: Identifiable, Hashable {
    let id: String
    let categoryId: String
    let displayName: String
    let iconName: String?
    let color: Color
    let filterValue: Any
    let isCustom: Bool
    
    init(id: String, categoryId: String, displayName: String, iconName: String? = nil, color: Color = LopanColors.primary, filterValue: Any, isCustom: Bool = false) {
        self.id = id
        self.categoryId = categoryId
        self.displayName = displayName
        self.iconName = iconName
        self.color = color
        self.filterValue = filterValue
        self.isCustom = isCustom
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FilterOption, rhs: FilterOption) -> Bool {
        lhs.id == rhs.id
    }
}

/// 保存的筛选
struct SavedFilter: Identifiable {
    let id = UUID()
    let name: String
    let filters: [FilterOption]
    let scope: SmartFilterBar.FilterScope
    let createdAt: Date
    var lastUsed: Date?
    var usageCount: Int = 0
}

/// 筛选预览结果
struct FilterPreviewResults {
    let totalCount: Int
    let categoryBreakdown: [String: Int]
    let estimatedFilterTime: TimeInterval
    let suggestedOptimizations: [String]
}

// MARK: - Filter Engine
class FilterEngine: ObservableObject {
    func getIntelligentDefaults(for category: FilterCategory, scope: SmartFilterBar.FilterScope) -> [FilterOption] {
        // 基于使用历史和上下文返回智能默认筛选
        switch (category.id, scope) {
        case ("priority", .customers):
            return [FilterOption(id: "high-value", categoryId: "priority", displayName: "高价值客户", iconName: "star.fill", color: LopanColors.premium, filterValue: "high_value")]
        case ("status", .orders):
            return [FilterOption(id: "pending", categoryId: "status", displayName: "待处理", iconName: "clock.fill", color: LopanColors.warning, filterValue: "pending")]
        default:
            return []
        }
    }
    
    func generatePreview(for filters: [FilterOption], scope: SmartFilterBar.FilterScope, completion: @escaping (FilterPreviewResults) -> Void) {
        // 模拟异步筛选预览生成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let preview = FilterPreviewResults(
                totalCount: Int.random(in: 10...500),
                categoryBreakdown: ["客户": 120, "产品": 45, "订单": 67],
                estimatedFilterTime: Double.random(in: 0.1...2.0),
                suggestedOptimizations: ["建议合并相似筛选条件", "添加地区筛选以提高精确度"]
            )
            completion(preview)
        }
    }
}

// MARK: - Filter Analytics
class FilterAnalytics: ObservableObject {
    @Published var savedFilters: [SavedFilter] = []
    @Published var filterUsageStats: [String: Int] = [:]
    
    func recordFilterRemoval(_ filter: FilterOption) {
        // 记录筛选移除统计
    }
    
    func recordFilterClear() {
        // 记录清除操作统计
    }
    
    func saveFilter(_ filter: SavedFilter) {
        savedFilters.append(filter)
    }
    
    func recordSavedFilterUsage(_ filter: SavedFilter) {
        // 更新使用统计
        if let index = savedFilters.firstIndex(where: { $0.id == filter.id }) {
            savedFilters[index].usageCount += 1
            savedFilters[index].lastUsed = Date()
        }
    }
    
    func deleteSavedFilter(_ filter: SavedFilter) {
        savedFilters.removeAll { $0.id == filter.id }
    }
}

// MARK: - Saved Filters View
struct SavedFiltersView: View {
    let savedFilters: [SavedFilter]
    let onApplyFilter: (SavedFilter) -> Void
    let onDeleteFilter: (SavedFilter) -> Void
    
    var body: some View {
        List {
            if savedFilters.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.slash")
                        .font(.largeTitle)
                        .foregroundColor(LopanColors.textTertiary)
                    
                    Text("暂无保存的筛选")
                        .font(.headline)
                        .foregroundColor(LopanColors.textSecondary)
                    
                    Text("您可以在设置筛选条件后点击保存按钮")
                        .font(.callout)
                        .foregroundColor(LopanColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(savedFilters, id: \.id) { filter in
                    SavedFilterRow(
                        filter: filter,
                        onApply: { onApplyFilter(filter) },
                        onDelete: { onDeleteFilter(filter) }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

/// 保存筛选行
struct SavedFilterRow: View {
    let filter: SavedFilter
    let onApply: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(filter.name)
                    .font(.headline)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text("\(filter.filters.count) 个筛选条件")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
                
                if let lastUsed = filter.lastUsed {
                    Text("上次使用: \(lastUsed.timeAgoDisplay())")
                        .font(.caption2)
                        .foregroundColor(LopanColors.textTertiary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("应用", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(LopanColors.error)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Filter Builder
struct CustomFilterBuilder: View {
    let availableFilters: [FilterCategory]
    let currentFilters: [FilterOption]
    let onFiltersChanged: ([FilterOption]) -> Void
    
    @State private var selectedFilters: [FilterOption] = []
    
    var body: some View {
        List {
            ForEach(availableFilters, id: \.id) { category in
                Section(category.displayName) {
                    ForEach(category.availableOptions, id: \.id) { option in
                        HStack {
                            Image(systemName: option.iconName ?? "circle")
                                .foregroundColor(option.color)
                            
                            Text(option.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedFilters.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(LopanColors.primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleFilter(option)
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedFilters = currentFilters
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("应用") {
                    onFiltersChanged(selectedFilters)
                }
            }
        }
    }
    
    private func toggleFilter(_ filter: FilterOption) {
        if let index = selectedFilters.firstIndex(of: filter) {
            selectedFilters.remove(at: index)
        } else {
            selectedFilters.append(filter)
        }
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.selectionToggle)
    }
}

#Preview {
    let sampleCategories = [
        FilterCategory(
            id: "priority",
            displayName: "优先级",
            iconName: "star.fill",
            availableOptions: [
                FilterOption(id: "vip", categoryId: "priority", displayName: "VIP客户", iconName: "crown.fill", color: LopanColors.premium, filterValue: "vip"),
                FilterOption(id: "high", categoryId: "priority", displayName: "高价值", iconName: "star.fill", color: LopanColors.success, filterValue: "high_value")
            ]
        ),
        FilterCategory(
            id: "region",
            displayName: "地区",
            iconName: "location.fill",
            availableOptions: [
                FilterOption(id: "beijing", categoryId: "region", displayName: "北京", iconName: "location.fill", color: LopanColors.info, filterValue: "beijing"),
                FilterOption(id: "shanghai", categoryId: "region", displayName: "上海", iconName: "location.fill", color: LopanColors.info, filterValue: "shanghai")
            ]
        )
    ]
    
    return SmartFilterBar(
        activeFilters: .constant(Set()),
        isVisible: .constant(true),
        availableFilters: sampleCategories,
        scope: .customers,
        onFiltersChanged: { _ in },
        onFilterSaved: { _ in }
    )
    .padding()
}