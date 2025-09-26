//
//  AdaptiveDateNavigationBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/25.
//  Adaptive date navigation bar supporting dual-mode display
//

import SwiftUI

// MARK: - View Mode Definition

enum DateNavigationMode: Equatable {
    case dateNavigation(date: Date, isEnabled: Bool = true)
    case filtered(summary: String, dateRange: String?, filterCount: Int)
    
    var isDateMode: Bool {
        if case .dateNavigation = self { return true }
        return false
    }
    
    var isFilterMode: Bool {
        if case .filtered = self { return true }
        return false
    }
}

// MARK: - Adaptive Date Navigation Bar

struct AdaptiveDateNavigationBar: View {
    let mode: DateNavigationMode
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onDateTapped: () -> Void
    let onClearFilters: () -> Void
    let onFilterSummaryTapped: (() -> Void)?
    let sortOrder: CustomerOutOfStockNavigationState.SortOrder?
    let onToggleSort: (() -> Void)?
    let isEnabled: Bool // New parameter to control if navigation is enabled
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if mode.isDateMode {
                    // Date navigation mode: previous button - date - next button
                    navigationButton(
                        direction: .previous,
                        enabled: isEnabled,
                        action: onPreviousDay
                    )
                    
                    Spacer()
                    
                    centerContent
                        .animation(.easeInOut(duration: 0.3), value: mode)
                        .disabled(!isEnabled) // Disable date picker when not enabled
                    
                    Spacer()
                    
                    navigationButton(
                        direction: .next,
                        enabled: isEnabled,
                        action: onNextDay
                    )
                } else {
                    // Filter mode: sort button - date range - clear button
                    HStack(spacing: 8) {
                        // Sort button on the left
                        if let sortOrder = sortOrder, let onToggleSort = onToggleSort {
                            Button(action: onToggleSort) {
                                HStack(spacing: 4) {
                                    Image(systemName: sortOrder == .newestFirst ? "arrow.down" : "arrow.up")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(sortOrder == .newestFirst ? "倒序" : "正序")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(LopanColors.info)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(LopanColors.primary.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(LopanColors.primary.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("切换排序方式")
                            .accessibilityHint("点击在正序和倒序之间切换")
                        }
                        
                        Spacer()
                        
                        // Date range centered
                        centerContent
                            .animation(.easeInOut(duration: 0.3), value: mode)
                        
                        Spacer()
                        
                        // Clear filters button on the right
                        Button(action: onClearFilters) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                
                                Text("清除筛选")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(LopanColors.error)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LopanColors.error.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(LopanColors.error.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清除筛选条件")
                        .accessibilityHint("点击返回日期导航模式")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Center Content
    
    @ViewBuilder
    private var centerContent: some View {
        switch mode {
        case .dateNavigation(let date, _):
            DateDisplayView(
                date: date,
                onTapped: onDateTapped
            )
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
            
        case .filtered(let summary, let dateRange, let filterCount):
            FilterSummaryDisplayView(
                summary: summary,
                dateRange: dateRange,
                filterCount: filterCount,
                onTapped: onFilterSummaryTapped
            )
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Navigation Button
    
    private func navigationButton(
        direction: NavigationDirection,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: direction.iconName)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundColor(enabled ? LopanColors.info : LopanColors.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(enabled ? LopanColors.primary.opacity(0.12) : LopanColors.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .accessibilityLabel(direction.accessibilityLabel)
        .accessibilityHint(enabled ? direction.accessibilityHint : "当前筛选模式下不可用")
    }
}

// MARK: - Date Display View

private struct DateDisplayView: View {
    let date: Date
    let onTapped: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Button(action: onTapped) {
            VStack(spacing: 1) {
                Text(date, style: .date)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Text(dayOfWeekText(date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LopanColors.primary.opacity(isEnabled ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LopanColors.primary.opacity(isEnabled ? 0.2 : 0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .accessibilityLabel("选择日期")
        .accessibilityValue(DateFormatter.accessibilityDate.string(from: date))
        .accessibilityHint(isEnabled ? "点击打开日期选择器" : "数据加载中，日期选择暂时不可用")
    }
    
    private func dayOfWeekText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Filter Summary Display View

private struct FilterSummaryDisplayView: View {
    let summary: String
    let dateRange: String?
    let filterCount: Int
    let onTapped: (() -> Void)?
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { onTapped?() }) {
            HStack(spacing: 4) {
                // Use calendar icon for date ranges, filter icon for other filters
                Image(systemName: dateRange != nil ? "calendar.circle.fill" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LopanColors.info)
                
                // Display date range or summary directly
                if let dateRange = dateRange {
                    Text(dateRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LopanColors.info)
                        .lineLimit(1)
                } else {
                    Text(summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LopanColors.info)
                        .lineLimit(1)
                }
                
                // Badge for multiple filters
                if filterCount > 1 {
                    Text("\(filterCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(LopanColors.textPrimary)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(
                            Circle()
                                .fill(LopanColors.primary)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LopanColors.primary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LopanColors.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .buttonStyle(.plain)
        .onTapGesture {
            // Add haptic feedback and press animation
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                onTapped?()
            }
        }
        .accessibilityLabel("当前筛选条件")
        .accessibilityValue(dateRange ?? summary)
        .accessibilityHint(onTapped != nil ? "点击查看详细筛选条件" : "")
    }
}

// MARK: - Supporting Types

private enum NavigationDirection {
    case previous, next

    var iconName: String {
        switch self {
        case .previous: return "chevron.left"
        case .next: return "chevron.right"
        }
    }

    var title: String {
        switch self {
        case .previous: return "上一天"
        case .next: return "下一天"
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .previous: return "前一天"
        case .next: return "后一天"
        }
    }
    
    var accessibilityHint: String {
        switch self {
        case .previous: return "查看前一天的数据"
        case .next: return "查看后一天的数据"
        }
    }
}

// MARK: - DateFormatter Extensions

private extension DateFormatter {
    static let accessibilityDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

// MARK: - Dynamic Type Previews

#Preview("Default Size") {
    VStack(spacing: 16) {
        Text("Adaptive Date Navigation - Default Size")
            .font(.headline)
            .padding(.bottom)

        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: true),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: true
        )

        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "客户生产订单筛选", dateRange: "8/1-8/31", filterCount: 2),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: { print("Filter summary tapped") },
            sortOrder: .newestFirst,
            onToggleSort: { print("Toggle sort") },
            isEnabled: true
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    VStack(spacing: 20) {
        Text("Navigation Bar - Extra Large Text")
            .font(.title2)
            .padding(.bottom)

        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: true),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: true
        )

        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "制造车间质量管控筛选条件", dateRange: "2024年8月1日-31日", filterCount: 4),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: { print("Filter summary tapped") },
            sortOrder: .oldestFirst,
            onToggleSort: { print("Toggle sort") },
            isEnabled: true
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Accessibility 3") {
    VStack(spacing: 24) {
        Text("Navigation Bar - Accessibility 3 Size")
            .font(.title2)
            .padding(.bottom)

        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: true),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: true
        )

        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "生产管理：按客户和时间筛选的制造订单", dateRange: "2024年8月全月生产数据", filterCount: 3),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: { print("Filter summary tapped") },
            sortOrder: .newestFirst,
            onToggleSort: { print("Toggle sort") },
            isEnabled: true
        )

        // Disabled state for testing
        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: false),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: false
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    VStack(spacing: 30) {
        Text("Maximum Accessibility Size")
            .font(.largeTitle)
            .padding(.bottom)

        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: true),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: true
        )

        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "生产筛选", dateRange: "本月数据", filterCount: 2),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: { print("Filter summary tapped") },
            sortOrder: .oldestFirst,
            onToggleSort: { print("Toggle sort") },
            isEnabled: true
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX3") {
    VStack(spacing: 24) {
        Text("Dark Mode Navigation Bar")
            .font(.title2)
            .padding(.bottom)

        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: true),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: true
        )

        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "夜班生产管理筛选", dateRange: "夜间生产数据", filterCount: 5),
            onPreviousDay: { print("Previous day") },
            onNextDay: { print("Next day") },
            onDateTapped: { print("Date tapped") },
            onClearFilters: { print("Clear filters") },
            onFilterSummaryTapped: { print("Filter summary tapped") },
            sortOrder: .newestFirst,
            onToggleSort: { print("Toggle sort") },
            isEnabled: true
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Manufacturing Context") {
    VStack(spacing: 20) {
        Text("Manufacturing Workflow Navigation")
            .font(.title3)
            .padding(.bottom)

        // Production batch navigation
        AdaptiveDateNavigationBar(
            mode: .dateNavigation(date: Date(), isEnabled: true),
            onPreviousDay: { print("Previous production day") },
            onNextDay: { print("Next production day") },
            onDateTapped: { print("Select production date") },
            onClearFilters: { print("Clear production filters") },
            onFilterSummaryTapped: nil,
            sortOrder: nil,
            onToggleSort: nil,
            isEnabled: true
        )

        // Quality control filter
        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "质检不合格产品", dateRange: "本周质检数据", filterCount: 3),
            onPreviousDay: { print("Previous QC day") },
            onNextDay: { print("Next QC day") },
            onDateTapped: { print("Select QC date") },
            onClearFilters: { print("Clear QC filters") },
            onFilterSummaryTapped: { print("QC filter details") },
            sortOrder: .newestFirst,
            onToggleSort: { print("Toggle QC sort") },
            isEnabled: true
        )

        // Inventory management filter
        AdaptiveDateNavigationBar(
            mode: .filtered(summary: "库存告急物料", dateRange: "实时库存状态", filterCount: 7),
            onPreviousDay: { print("Previous inventory day") },
            onNextDay: { print("Next inventory day") },
            onDateTapped: { print("Select inventory date") },
            onClearFilters: { print("Clear inventory filters") },
            onFilterSummaryTapped: { print("Inventory filter details") },
            sortOrder: .oldestFirst,
            onToggleSort: { print("Toggle inventory sort") },
            isEnabled: true
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
    .environment(\.dynamicTypeSize, .large)
}
