//
//  EnhancedDateNavigationBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/21.
//

import SwiftUI

struct EnhancedDateNavigationBar: View {
    @Binding var selectedDate: Date
    @Binding var dateFilterMode: DateFilterOption?
    @Binding var sortOrder: CustomerOutOfStockNavigationState.SortOrder
    let onDateChanged: (Date) -> Void
    let onSortOrderChanged: (() -> Void)?
    
    @State private var isAnimating = false
    @State private var buttonPressedState: ButtonPressState = .none
    
    private enum ButtonPressState {
        case none, previous, next
    }
    
    private var canNavigateNext: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        return tomorrow <= Date()
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: selectedDate)
    }
    
    private var displayText: String {
        switch dateFilterMode {
        case .thisWeek:
            let dateRange = DateFilterOption.thisWeek.dateRange
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M/d"
            return "本周(\(formatter.string(from: dateRange.start))-\(formatter.string(from: dateRange.end)))"
        case .thisMonth:
            let dateRange = DateFilterOption.thisMonth.dateRange
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M/d"
            return "本月(\(formatter.string(from: dateRange.start))-\(formatter.string(from: dateRange.end)))"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M/d"
            return "自定义(\(formatter.string(from: start))-\(formatter.string(from: end)))"
        case nil:
            return formattedDate
        }
    }
    
    private var displayTextColor: LinearGradient {
        switch dateFilterMode {
        case .thisWeek, .thisMonth, .custom:
            return LinearGradient(
                colors: [LopanColors.primary, LopanColors.primary.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case nil:
            return LinearGradient(
                colors: [LopanColors.textPrimary, LopanColors.textPrimary.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Previous Day Button - only show when not in filter mode
            if dateFilterMode == nil {
                navigationButton(direction: .previous)
                    .accessibilityLabel("前一天")
                    .accessibilityHint("切换到前一天的记录")
            }
            
            Spacer()
            
            // Enhanced Date Display
            dateDisplayView
                .accessibilityLabel("当前日期")
                .accessibilityValue(displayText)
            
            Spacer()
            
            // Sort Button - show when in filter mode
            if dateFilterMode != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sortOrder = sortOrder == .newestFirst ? .oldestFirst : .newestFirst
                        onSortOrderChanged?()
                    }
                }) {
                    Image(systemName: sortOrder.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(LopanColors.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .accessibilityLabel("排序")
                .accessibilityValue(sortOrder.displayName)
                .accessibilityHint("切换排序方式")
            }
            
            // Next Day Button - only show when not in filter mode
            if dateFilterMode == nil {
                navigationButton(direction: .next)
                    .disabled(!canNavigateNext)
                    .accessibilityLabel("后一天")
                    .accessibilityHint(canNavigateNext ? "切换到后一天的记录" : "无法查看未来日期")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray5)),
            alignment: .bottom
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dateFilterMode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("日期导航栏")
        .accessibilityValue(accessibilityDateDescription)
    }
    
    // MARK: - Date Display View
    
    private var dateDisplayView: some View {
        VStack(spacing: 4) {
            Text(displayText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(nil)
                .foregroundStyle(displayTextColor)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: displayText)
                .accessibilityAddTraits([.isHeader])
            
        }
    }
    
    // MARK: - Navigation Button
    
    private func navigationButton(direction: NavigationDirection) -> some View {
        Button(action: {
            handleNavigation(direction: direction)
        }) {
            Image(systemName: direction.iconName)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(direction == .next && !canNavigateNext ? LopanColors.textTertiary : LopanColors.primary)
                .frame(width: 32, height: 32)
                .scaleEffect(
                    buttonPressedState == direction.pressState ? 0.95 : 
                    (isAnimating ? 0.98 : 1.0)
                )
                .opacity(direction == .next && !canNavigateNext ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .sensoryFeedback(.impact(flexibility: .soft), trigger: buttonPressedState)
    }
    
    // Removed navigationButtonBackground - no longer needed for simplified design
    
    // MARK: - Glass Morphism Background
    
    private var glassMorphismBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .background(
                // Subtle gradient backdrop for depth
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        RadialGradient(
                            colors: [
                                LopanColors.glassMorphism,
                                LopanColors.glassMorphism.opacity(0.3)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .opacity(0.6)
            )
    }
    
    // MARK: - Navigation Logic
    
    private func handleNavigation(direction: NavigationDirection) {
        // Haptic feedback
        buttonPressedState = direction.pressState
        
        withAnimation(.easeInOut(duration: 0.15)) {
            isAnimating = true
        }
        
        let targetDate: Date
        switch direction {
        case .previous:
            targetDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        case .next:
            guard canNavigateNext else { return }
            targetDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        }
        
        selectedDate = targetDate
        onDateChanged(targetDate)
        
        // Reset animation states
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isAnimating = false
                buttonPressedState = .none
            }
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var accessibilityDateDescription: String {
        let dateText = displayText
        
        switch dateFilterMode {
        case .thisWeek:
            return "当前选择本周筛选模式"
        case .thisMonth:
            return "当前选择本月筛选模式"
        case .custom:
            return "当前选择自定义日期范围: \(dateText)"
        case nil:
            return "当前日期: \(dateText)"
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
        
        var pressState: ButtonPressState {
            switch self {
            case .previous: return .previous
            case .next: return .next
            }
        }
    }
}

// MARK: - Enhanced Date Navigation Bar Modifier

extension View {
    func enhancedDateNavigationBar(
        selectedDate: Binding<Date>,
        dateFilterMode: Binding<DateFilterOption?> = .constant(nil),
        onDateChanged: @escaping (Date) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            self
            
            EnhancedDateNavigationBar(
                selectedDate: selectedDate,
                dateFilterMode: dateFilterMode,
                sortOrder: .constant(.newestFirst),
                onDateChanged: onDateChanged,
                onSortOrderChanged: nil
            )
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        EnhancedDateNavigationBar(
            selectedDate: .constant(Date()),
            dateFilterMode: .constant(nil),
            sortOrder: .constant(.newestFirst),
            onDateChanged: { _ in },
            onSortOrderChanged: nil
        )
        
        EnhancedDateNavigationBar(
            selectedDate: .constant(Date()),
            dateFilterMode: .constant(.thisWeek),
            sortOrder: .constant(.newestFirst),
            onDateChanged: { _ in },
            onSortOrderChanged: nil
        )
        
        EnhancedDateNavigationBar(
            selectedDate: .constant(Date()),
            dateFilterMode: .constant(.custom(start: Date(), end: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)),
            sortOrder: .constant(.oldestFirst),
            onDateChanged: { _ in },
            onSortOrderChanged: nil
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif