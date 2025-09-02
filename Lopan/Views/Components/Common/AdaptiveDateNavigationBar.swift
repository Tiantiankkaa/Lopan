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
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.blue.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
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
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
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
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(enabled ? .blue : .gray)
                .opacity(enabled ? 1.0 : 0.4)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .scaleEffect(isAnimating ? 1.1 : 1.0)
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
                    .fill(Color.blue.opacity(isEnabled ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(isEnabled ? 0.2 : 0.1), lineWidth: 1)
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
                    .foregroundColor(.blue)
                
                // Display date range or summary directly
                if let dateRange = dateRange {
                    Text(dateRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                } else {
                    Text(summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Badge for multiple filters
                if filterCount > 1 {
                    Text("\(filterCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(
                            Circle()
                                .fill(Color.blue)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
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

// MARK: - Preview

#Preview("Date Navigation Mode") {
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
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Filter Mode") {
    AdaptiveDateNavigationBar(
        mode: .filtered(summary: "客户张三 + 本周", dateRange: "8/1-8/31", filterCount: 3),
        onPreviousDay: { print("Previous day") },
        onNextDay: { print("Next day") },
        onDateTapped: { print("Date tapped") },
        onClearFilters: { print("Clear filters") },
        onFilterSummaryTapped: { print("Filter summary tapped") },
        sortOrder: .newestFirst,
        onToggleSort: { print("Toggle sort") },
        isEnabled: true
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}