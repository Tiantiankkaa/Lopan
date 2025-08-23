//
//  AdvancedSelectionManager.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  高级选择管理器 - 完美主义设计师的交互艺术巅峰
//

import SwiftUI
import Combine

// MARK: - 高级选择管理器主组件
/// 智能选择管理系统，每个选择操作都经过精心优化
class AdvancedSelectionManager<ItemType: Identifiable & Hashable>: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedItems: Set<ItemType> = []
    @Published var isSelectionMode: Bool = false
    @Published var selectionStrategy: SelectionStrategy = .manual
    @Published var selectionStats: SelectionStats = SelectionStats()
    
    // MARK: - Private Properties
    private var allItems: [ItemType] = []
    private var filteredItems: [ItemType] = []
    private var selectionHistory: [SelectionHistoryEntry] = []
    private var lastSelectionGesture: Date?
    private var continuousSelectionStartIndex: Int?
    
    // MARK: - Configuration
    private let maxSelectionHistorySize = 50
    private let rapidSelectionThreshold: TimeInterval = 0.5
    private let maxContinuousSelection = 100
    
    // MARK: - Selection Strategies
    enum SelectionStrategy {
        case manual           // 手动选择
        case smart           // 智能选择（基于模式识别）
        case batch           // 批量选择
        case continuous      // 连续选择
        case conditional     // 条件选择
        
        var displayName: String {
            switch self {
            case .manual: return "手动选择"
            case .smart: return "智能选择"
            case .batch: return "批量选择"
            case .continuous: return "连续选择"
            case .conditional: return "条件选择"
            }
        }
        
        var iconName: String {
            switch self {
            case .manual: return "hand.tap"
            case .smart: return "brain"
            case .batch: return "rectangle.3.group"
            case .continuous: return "arrow.down.to.line"
            case .conditional: return "slider.horizontal.3"
            }
        }
    }
    
    // MARK: - Selection Mode Types
    enum SelectionMode {
        case single           // 单选
        case multiple        // 多选
        case range           // 范围选择
        case toggle          // 切换选择
        case exclusive       // 排他选择
    }
    
    // MARK: - Initialization
    init() {
        setupSelectionTracking()
    }
    
    // MARK: - Core Selection Methods
    
    /// 切换项目选择状态
    func toggleSelection(for item: ItemType, with strategy: SelectionStrategy? = nil) {
        let effectiveStrategy = strategy ?? selectionStrategy
        
        recordSelectionGesture(for: item, action: .toggle)
        
        switch effectiveStrategy {
        case .manual:
            performManualToggle(for: item)
        case .smart:
            performSmartToggle(for: item)
        case .batch:
            performBatchToggle(for: item)
        case .continuous:
            performContinuousToggle(for: item)
        case .conditional:
            performConditionalToggle(for: item)
        }
        
        updateSelectionStats()
        generateHapticFeedback(for: .toggle)
    }
    
    /// 选择单个项目
    func selectItem(_ item: ItemType, exclusively: Bool = false) {
        if exclusively {
            selectedItems.removeAll()
        }
        
        selectedItems.insert(item)
        recordSelectionGesture(for: item, action: .select)
        updateSelectionStats()
        generateHapticFeedback(for: .select)
    }
    
    /// 取消选择项目
    func deselectItem(_ item: ItemType) {
        selectedItems.remove(item)
        recordSelectionGesture(for: item, action: .deselect)
        updateSelectionStats()
        generateHapticFeedback(for: .deselect)
    }
    
    /// 选择范围内的项目
    func selectRange(from startItem: ItemType, to endItem: ItemType) {
        guard let startIndex = filteredItems.firstIndex(of: startItem),
              let endIndex = filteredItems.firstIndex(of: endItem) else { return }
        
        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        let rangeItems = Array(filteredItems[range])
        
        for item in rangeItems {
            selectedItems.insert(item)
        }
        
        recordRangeSelection(from: startItem, to: endItem, count: rangeItems.count)
        updateSelectionStats()
        generateHapticFeedback(for: .range)
    }
    
    /// 选择全部项目
    func selectAll() {
        let previousCount = selectedItems.count
        
        for item in filteredItems {
            selectedItems.insert(item)
        }
        
        recordBulkSelection(action: .selectAll, count: selectedItems.count - previousCount)
        updateSelectionStats()
        generateHapticFeedback(for: .selectAll)
    }
    
    /// 取消选择全部项目
    func deselectAll() {
        let deselectedCount = selectedItems.count
        selectedItems.removeAll()
        
        recordBulkSelection(action: .deselectAll, count: deselectedCount)
        updateSelectionStats()
        generateHapticFeedback(for: .deselectAll)
    }
    
    /// 反向选择
    func invertSelection() {
        let newSelection = Set(filteredItems.filter { !selectedItems.contains($0) })
        let changedCount = abs(newSelection.count - selectedItems.count)
        
        selectedItems = newSelection
        
        recordBulkSelection(action: .invert, count: changedCount)
        updateSelectionStats()
        generateHapticFeedback(for: .invert)
    }
    
    // MARK: - Advanced Selection Methods
    
    /// 智能选择相似项目
    func selectSimilarItems(to referenceItem: ItemType, using similarity: any SimilarityMatcher<ItemType>) {
        let similarItems = filteredItems.filter { item in
            item != referenceItem && similarity.isSimilar(item, to: referenceItem)
        }
        
        for item in similarItems {
            selectedItems.insert(item)
        }
        
        recordSmartSelection(referenceItem: referenceItem, selectedCount: similarItems.count)
        updateSelectionStats()
        generateHapticFeedback(for: .smartSelection)
    }
    
    /// 基于条件选择
    func selectItemsWhere(_ predicate: (ItemType) -> Bool) {
        let matchingItems = filteredItems.filter(predicate)
        let newSelections = matchingItems.filter { !selectedItems.contains($0) }
        
        for item in newSelections {
            selectedItems.insert(item)
        }
        
        recordConditionalSelection(count: newSelections.count)
        updateSelectionStats()
        generateHapticFeedback(for: .conditional)
    }
    
    /// 快速多选模式
    func enterBatchSelectionMode(with initialItem: ItemType? = nil) {
        isSelectionMode = true
        selectionStrategy = .batch
        
        if let item = initialItem {
            selectItem(item)
        }
        
        recordModeChange(to: .batch)
        generateHapticFeedback(for: .modeChange)
    }
    
    /// 退出选择模式
    func exitSelectionMode(keepSelection: Bool = true) {
        let wasInSelectionMode = isSelectionMode
        
        isSelectionMode = false
        selectionStrategy = .manual
        
        if !keepSelection {
            deselectAll()
        }
        
        if wasInSelectionMode {
            recordModeChange(to: .manual)
            generateHapticFeedback(for: .modeExit)
        }
    }
    
    // MARK: - Configuration Methods
    
    /// 更新可用项目列表
    func updateItems(_ items: [ItemType]) {
        allItems = items
        filteredItems = items
        
        // 移除不再存在的选择
        selectedItems = selectedItems.intersection(Set(items))
        updateSelectionStats()
    }
    
    /// 更新过滤后的项目列表
    func updateFilteredItems(_ items: [ItemType]) {
        filteredItems = items
        
        // 只保留过滤后还存在的选择
        selectedItems = selectedItems.intersection(Set(items))
        updateSelectionStats()
    }
    
    // MARK: - Query Methods
    
    /// 检查项目是否被选择
    func isSelected(_ item: ItemType) -> Bool {
        return selectedItems.contains(item)
    }
    
    /// 获取选择状态
    func getSelectionState(for item: ItemType) -> SelectionState {
        if isSelected(item) {
            return .selected
        } else if isSelectionMode {
            return .selectable
        } else {
            return .normal
        }
    }
    
    /// 获取选择进度
    func getSelectionProgress() -> SelectionProgress {
        let totalCount = filteredItems.count
        let selectedCount = selectedItems.count
        let progress = totalCount > 0 ? Double(selectedCount) / Double(totalCount) : 0.0
        
        return SelectionProgress(
            selectedCount: selectedCount,
            totalCount: totalCount,
            progress: progress,
            isComplete: selectedCount == totalCount && totalCount > 0,
            isEmpty: selectedCount == 0
        )
    }
    
    // MARK: - Selection Pattern Recognition
    
    /// 分析选择模式并提供智能建议
    func analyzeSelectionPattern() -> SelectionPattern {
        let recentSelections = selectionHistory.suffix(10)
        
        // 分析时间模式
        let timeIntervals: [TimeInterval] = recentSelections.compactMap { entry in
            guard let nextEntry = selectionHistory.first(where: { $0.timestamp > entry.timestamp }) else { return nil }
            return nextEntry.timestamp.timeIntervalSince(entry.timestamp)
        }
        
        let averageInterval = timeIntervals.isEmpty ? 0 : timeIntervals.reduce(0, +) / Double(timeIntervals.count)
        let isRapidSelection = averageInterval < rapidSelectionThreshold
        
        // 分析序列模式
        let selectedIndices = selectedItems.compactMap { filteredItems.firstIndex(of: $0) }.sorted()
        let isSequential = isSequentialPattern(selectedIndices)
        let isScattered = selectedIndices.count > 3 && !isSequential
        
        return SelectionPattern(
            isRapid: isRapidSelection,
            isSequential: isSequential,
            isScattered: isScattered,
            averageSelectionInterval: averageInterval,
            suggestedStrategy: "smart"
        )
    }
    
    // MARK: - Private Implementation
    
    private func performManualToggle(for item: ItemType) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func performSmartToggle(for item: ItemType) {
        let pattern = analyzeSelectionPattern()
        
        if pattern.suggestedStrategy == "continuous" {
            performContinuousToggle(for: item)
        } else if pattern.suggestedStrategy == "batch" {
            performBatchToggle(for: item)
        } else {
            performManualToggle(for: item)
        }
    }
    
    private func performBatchToggle(for item: ItemType) {
        if !isSelectionMode {
            enterBatchSelectionMode(with: item)
        } else {
            performManualToggle(for: item)
        }
    }
    
    private func performContinuousToggle(for item: ItemType) {
        guard let itemIndex = filteredItems.firstIndex(of: item) else {
            performManualToggle(for: item)
            return
        }
        
        if let startIndex = continuousSelectionStartIndex {
            selectRange(
                from: filteredItems[startIndex],
                to: item
            )
            continuousSelectionStartIndex = nil
        } else {
            continuousSelectionStartIndex = itemIndex
            performManualToggle(for: item)
        }
    }
    
    private func performConditionalToggle(for item: ItemType) {
        // 实现条件选择逻辑
        performManualToggle(for: item)
    }
    
    private func setupSelectionTracking() {
        // 设置选择跟踪
        $selectedItems
            .sink { [weak self] _ in
                self?.updateSelectionStats()
            }
            .store(in: &cancellables)
    }
    
    private func recordSelectionGesture(for item: ItemType, action: SelectionAction) {
        let entry = SelectionHistoryEntry(
            itemId: item.id,
            action: action,
            timestamp: Date(),
            strategy: "manual"
        )
        
        selectionHistory.append(entry)
        
        // 限制历史记录大小
        if selectionHistory.count > maxSelectionHistorySize {
            selectionHistory.removeFirst()
        }
        
        lastSelectionGesture = Date()
    }
    
    private func recordRangeSelection(from startItem: ItemType, to endItem: ItemType, count: Int) {
        let entry = SelectionHistoryEntry(
            itemId: startItem.id,
            action: .rangeSelect(endItemId: endItem.id, count: count),
            timestamp: Date(),
            strategy: "manual"
        )
        
        selectionHistory.append(entry)
    }
    
    private func recordBulkSelection(action: BulkAction, count: Int) {
        let entry = SelectionHistoryEntry(
            itemId: AnyHashable("bulk"),
            action: .bulk(action, count: count),
            timestamp: Date(),
            strategy: "manual"
        )
        
        selectionHistory.append(entry)
    }
    
    private func recordSmartSelection(referenceItem: ItemType, selectedCount: Int) {
        let entry = SelectionHistoryEntry(
            itemId: referenceItem.id,
            action: .smartSelection(count: selectedCount),
            timestamp: Date(),
            strategy: "smart"
        )
        
        selectionHistory.append(entry)
    }
    
    private func recordConditionalSelection(count: Int) {
        let entry = SelectionHistoryEntry(
            itemId: AnyHashable("conditional"),
            action: .conditional(count: count),
            timestamp: Date(),
            strategy: "conditional"
        )
        
        selectionHistory.append(entry)
    }
    
    private func recordModeChange(to strategy: SelectionStrategy) {
        let entry = SelectionHistoryEntry(
            itemId: AnyHashable("mode"),
            action: .modeChange,
            timestamp: Date(),
            strategy: "manual"
        )
        
        selectionHistory.append(entry)
    }
    
    private func updateSelectionStats() {
        selectionStats = SelectionStats(
            totalSelections: selectedItems.count,
            selectionRate: calculateSelectionRate(),
            averageSelectionTime: calculateAverageSelectionTime(),
            mostUsedStrategy: findMostUsedStrategyString(),
            selectionEfficiency: calculateSelectionEfficiency()
        )
    }
    
    private func calculateSelectionRate() -> Double {
        let totalItems = filteredItems.count
        return totalItems > 0 ? Double(selectedItems.count) / Double(totalItems) : 0.0
    }
    
    private func calculateAverageSelectionTime() -> TimeInterval {
        let recentSelections = selectionHistory.suffix(20)
        let timeIntervals: [TimeInterval] = recentSelections.compactMap { entry in
            guard let nextEntry = selectionHistory.first(where: { $0.timestamp > entry.timestamp }) else { return nil }
            return nextEntry.timestamp.timeIntervalSince(entry.timestamp)
        }
        
        return timeIntervals.isEmpty ? 0 : timeIntervals.reduce(0, +) / Double(timeIntervals.count)
    }
    
    private func findMostUsedStrategy() -> SelectionStrategy {
        let strategyCounts = Dictionary(grouping: selectionHistory, by: \.strategy)
            .mapValues { $0.count }
        
        let keyString = strategyCounts.max(by: { $0.value < $1.value })?.key ?? "manual"
        return keyString == "smart" ? .smart : .manual
    }
    
    private func findMostUsedStrategyString() -> String {
        let strategyCounts = Dictionary(grouping: selectionHistory, by: \.strategy)
            .mapValues { $0.count }
        
        return strategyCounts.max(by: { $0.value < $1.value })?.key ?? "manual"
    }
    
    private func calculateSelectionEfficiency() -> Double {
        // 计算选择效率：选择数量 / 操作次数
        let operationCount = selectionHistory.count
        return operationCount > 0 ? Double(selectedItems.count) / Double(operationCount) : 0.0
    }
    
    private func isSequentialPattern(_ indices: [Int]) -> Bool {
        guard indices.count > 1 else { return false }
        
        let sortedIndices = indices.sorted()
        for i in 1..<sortedIndices.count {
            if sortedIndices[i] - sortedIndices[i-1] != 1 {
                return false
            }
        }
        return true
    }
    
    private func suggestOptimalStrategy(isRapid: Bool, isSequential: Bool, isScattered: Bool) -> SelectionStrategy {
        if isSequential && isRapid {
            return .continuous
        } else if isScattered && isRapid {
            return .batch
        } else if isRapid {
            return .smart
        } else {
            return .manual
        }
    }
    
    private func generateHapticFeedback(for feedbackType: HapticFeedbackType) {
        switch feedbackType {
        case .toggle, .select, .deselect:
            EnhancedHapticEngine.shared.perform(.selectionToggle)
        case .range:
            EnhancedHapticEngine.shared.perform(.selectionChain)
        case .selectAll, .deselectAll:
            EnhancedHapticEngine.shared.perform(.bulkActionExecute)
        case .invert:
            EnhancedHapticEngine.shared.perform(.batchModeEnter)
        case .smartSelection:
            EnhancedHapticEngine.shared.perform(.customerAdded)
        case .conditional:
            EnhancedHapticEngine.shared.perform(.filterApply)
        case .modeChange:
            EnhancedHapticEngine.shared.perform(.batchModeEnter)
        case .modeExit:
            EnhancedHapticEngine.shared.perform(.batchModeExit)
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
}

// MARK: - Supporting Models

/// 选择状态
enum SelectionState {
    case normal      // 正常状态
    case selectable  // 可选择状态
    case selected    // 已选择状态
    case disabled    // 禁用状态
}

/// 选择操作类型
enum SelectionAction {
    case select
    case deselect
    case toggle
    case rangeSelect(endItemId: AnyHashable, count: Int)
    case bulk(BulkAction, count: Int)
    case smartSelection(count: Int)
    case conditional(count: Int)
    case modeChange
}

/// 批量操作类型
enum BulkAction {
    case selectAll
    case deselectAll
    case invert
}

/// 触觉反馈类型
enum HapticFeedbackType {
    case toggle, select, deselect, range, selectAll, deselectAll, invert
    case smartSelection, conditional, modeChange, modeExit
}

/// 选择历史记录条目
struct SelectionHistoryEntry {
    let itemId: AnyHashable
    let action: SelectionAction
    let timestamp: Date
    let strategy: String
}

/// 选择进度信息
struct SelectionProgress {
    let selectedCount: Int
    let totalCount: Int
    let progress: Double
    let isComplete: Bool
    let isEmpty: Bool
    
    var displayText: String {
        if isEmpty {
            return "未选择任何项目"
        } else if isComplete {
            return "已选择全部 \(totalCount) 项"
        } else {
            return "已选择 \(selectedCount) / \(totalCount) 项"
        }
    }
    
    var progressPercentage: String {
        return String(format: "%.0f%%", progress * 100)
    }
}

/// 选择统计信息
struct SelectionStats {
    let totalSelections: Int
    let selectionRate: Double
    let averageSelectionTime: TimeInterval
    let mostUsedStrategy: String
    let selectionEfficiency: Double
    
    init() {
        self.totalSelections = 0
        self.selectionRate = 0.0
        self.averageSelectionTime = 0.0
        self.mostUsedStrategy = "manual"
        self.selectionEfficiency = 0.0
    }
    
    init(totalSelections: Int, selectionRate: Double, averageSelectionTime: TimeInterval, mostUsedStrategy: String, selectionEfficiency: Double) {
        self.totalSelections = totalSelections
        self.selectionRate = selectionRate
        self.averageSelectionTime = averageSelectionTime
        self.mostUsedStrategy = mostUsedStrategy
        self.selectionEfficiency = selectionEfficiency
    }
}

/// 选择模式分析结果
struct SelectionPattern {
    let isRapid: Bool
    let isSequential: Bool
    let isScattered: Bool
    let averageSelectionInterval: TimeInterval
    let suggestedStrategy: String
    
    var analysisText: String {
        var analysis: [String] = []
        
        if isRapid { analysis.append("快速选择") }
        if isSequential { analysis.append("连续选择") }
        if isScattered { analysis.append("分散选择") }
        
        return analysis.isEmpty ? "常规选择" : analysis.joined(separator: ", ")
    }
    
    var recommendationText: String {
        return "建议使用\(suggestedStrategy)模式以提高效率"
    }
}

/// 相似性匹配器协议
protocol SimilarityMatcher<ItemType> {
    associatedtype ItemType: Identifiable & Hashable
    func isSimilar(_ item1: ItemType, to item2: ItemType) -> Bool
}

// MARK: - SwiftUI Integration

/// 选择管理器视图修饰器
struct SelectionManagerModifier<ItemType: Identifiable & Hashable>: ViewModifier {
    let item: ItemType
    @ObservedObject var selectionManager: AdvancedSelectionManager<ItemType>
    let onSelectionChanged: ((Bool) -> Void)?
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(selectionManager.getSelectionState(for: item) == .selected ? 0.8 : 1.0)
            .overlay(
                selectionOverlay,
                alignment: .topTrailing
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: selectionManager.isSelected(item))
            .onTapGesture {
                handleSelectionTap()
            }
            .onLongPressGesture(
                minimumDuration: 0.0,
                maximumDistance: .infinity,
                perform: {},
                onPressingChanged: { pressing in
                    isPressed = pressing
                }
            )
            .accessibilityAddTraits(selectionManager.isSelectionMode ? .isSelected : [])
            .accessibilityValue(selectionManager.isSelected(item) ? "已选择" : "未选择")
    }
    
    @ViewBuilder
    private var selectionOverlay: some View {
        if selectionManager.isSelectionMode || selectionManager.isSelected(item) {
            SelectionIndicator(
                isSelected: selectionManager.isSelected(item),
                style: .checkbox
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private func handleSelectionTap() {
        let wasSelected = selectionManager.isSelected(item)
        selectionManager.toggleSelection(for: item)
        let isNowSelected = selectionManager.isSelected(item)
        
        if wasSelected != isNowSelected {
            onSelectionChanged?(isNowSelected)
        }
    }
}

/// 选择指示器组件
struct SelectionIndicator: View {
    let isSelected: Bool
    let style: IndicatorStyle
    
    enum IndicatorStyle {
        case checkbox
        case circle
        case checkmark
        case custom(selectedIcon: String, unselectedIcon: String)
        
        var selectedIcon: String {
            switch self {
            case .checkbox: return "checkmark.square.fill"
            case .circle: return "checkmark.circle.fill"
            case .checkmark: return "checkmark"
            case .custom(let selectedIcon, _): return selectedIcon
            }
        }
        
        var unselectedIcon: String {
            switch self {
            case .checkbox: return "square"
            case .circle: return "circle"
            case .checkmark: return "circle"
            case .custom(_, let unselectedIcon): return unselectedIcon
            }
        }
    }
    
    var body: some View {
        Image(systemName: isSelected ? style.selectedIcon : style.unselectedIcon)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textTertiary)
            .background(
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

/// 选择控制栏组件
struct SelectionControlBar<ItemType: Identifiable & Hashable>: View {
    @ObservedObject var selectionManager: AdvancedSelectionManager<ItemType>
    let onBulkAction: ((BulkSelectionAction) -> Void)?
    
    enum BulkSelectionAction {
        case delete
        case export
        case archive
        case share
        case edit
        
        var title: String {
            switch self {
            case .delete: return "删除"
            case .export: return "导出"
            case .archive: return "归档"
            case .share: return "分享"
            case .edit: return "编辑"
            }
        }
        
        var iconName: String {
            switch self {
            case .delete: return "trash"
            case .export: return "square.and.arrow.up"
            case .archive: return "archivebox"
            case .share: return "square.and.arrow.up"
            case .edit: return "pencil"
            }
        }
        
        var color: Color {
            switch self {
            case .delete: return LopanColors.error
            case .export: return LopanColors.info
            case .archive: return LopanColors.warning
            case .share: return LopanColors.primary
            case .edit: return LopanColors.secondary
            }
        }
    }
    
    var body: some View {
        if selectionManager.isSelectionMode {
            HStack {
                // 选择信息
                selectionInfo
                
                Spacer()
                
                // 批量操作按钮
                bulkActionButtons
                
                // 完成按钮
                doneButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var selectionInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            let progress = selectionManager.getSelectionProgress()
            
            Text(progress.displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textPrimary)
            
            if progress.totalCount > 0 {
                Text(progress.progressPercentage)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
    }
    
    private var bulkActionButtons: some View {
        HStack(spacing: 12) {
            ForEach([BulkSelectionAction.delete, .export, .share], id: \.self) { action in
                Button(action: { onBulkAction?(action) }) {
                    Image(systemName: action.iconName)
                        .font(.title3)
                        .foregroundColor(action.color)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectionManager.selectedItems.isEmpty)
            }
        }
    }
    
    private var doneButton: some View {
        Button("完成") {
            selectionManager.exitSelectionMode()
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(LopanColors.primary)
    }
}

// MARK: - View Extensions

extension View {
    /// 添加选择管理功能
    func selectionManaged<ItemType: Identifiable & Hashable>(
        item: ItemType,
        manager: AdvancedSelectionManager<ItemType>,
        onSelectionChanged: ((Bool) -> Void)? = nil
    ) -> some View {
        self.modifier(SelectionManagerModifier(
            item: item,
            selectionManager: manager,
            onSelectionChanged: onSelectionChanged
        ))
    }
}

#Preview {
    // 示例客户数据类型
    struct Customer: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let address: String
    }
    
    // 创建示例数据
    let customers = [
        Customer(name: "张三", address: "北京市"),
        Customer(name: "李四", address: "上海市"),
        Customer(name: "王五", address: "广州市")
    ]
    
    // 创建选择管理器
    let selectionManager = AdvancedSelectionManager<Customer>()
    
    return VStack {
        List(customers, id: \.id) { customer in
            HStack {
                Text(customer.name)
                    .font(.headline)
                
                Spacer()
                
                Text(customer.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .selectionManaged(
                item: customer,
                manager: selectionManager
            )
        }
        
        SelectionControlBar(
            selectionManager: selectionManager,
            onBulkAction: { action in
                print("Bulk action: \(action)")
            }
        )
    }
    .onAppear {
        selectionManager.updateItems(customers)
        selectionManager.enterBatchSelectionMode()
    }
}