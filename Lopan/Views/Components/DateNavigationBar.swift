//
//  DateNavigationBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/1/20.
//

import SwiftUI
import Foundation

struct DateNavigationBar: View {
    @Binding var selectedDate: Date
    @Binding var dateFilterMode: DateFilterOption?
    let onDateChanged: (Date) -> Void
    
    @State private var isAnimating = false
    
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
        case .today:
            return "今天 (\(formattedDate))"
        case .thisWeek:
            let dateRange = DateFilterOption.thisWeek.dateRange
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            return "本周 (\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end)))"
        case .thisMonth:
            let dateRange = DateFilterOption.thisMonth.dateRange
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            return "本月 (\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end)))"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            return "自定义 (\(formatter.string(from: start)) - \(formatter.string(from: end)))"
        case nil:
            return formattedDate
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Previous Day Button - only show when not in filter mode
            if dateFilterMode == nil {
                Button(action: navigateToPreviousDay) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.info)
                        .frame(width: 44, height: 44)
                        .background(LopanColors.backgroundTertiary)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isAnimating ? 0.95 : 1.0)
                .accessibilityLabel("前一天")
                .accessibilityHint("切换到前一天的记录")
            }
            
            Spacer()
            
            // Date Display
            Text(displayText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .accessibilityLabel("当前日期")
                .accessibilityValue(displayText)
            
            Spacer()
            
            // Next Day Button - only show when not in filter mode
            if dateFilterMode == nil {
                Button(action: navigateToNextDay) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(canNavigateNext ? LopanColors.info : LopanColors.secondary)
                        .frame(width: 44, height: 44)
                        .background(LopanColors.backgroundTertiary)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canNavigateNext)
                .scaleEffect(isAnimating ? 0.95 : 1.0)
                .accessibilityLabel("后一天")
                .accessibilityHint(canNavigateNext ? "切换到后一天的记录" : "无法查看未来日期")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(LopanColors.backgroundTertiary.opacity(0.7))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.secondary),
            alignment: .bottom
        )
    }
    
    private func navigateToPreviousDay() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnimating = true
        }
        
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        selectedDate = previousDay
        onDateChanged(previousDay)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isAnimating = false
            }
        }
    }
    
    private func navigateToNextDay() {
        guard canNavigateNext else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnimating = true
        }
        
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        selectedDate = nextDay
        onDateChanged(nextDay)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isAnimating = false
            }
        }
    }
}

// MARK: - Date Navigation Bar Modifier
extension View {
    func dateNavigationBar(
        selectedDate: Binding<Date>,
        dateFilterMode: Binding<DateFilterOption?> = .constant(nil),
        onDateChanged: @escaping (Date) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            self
            DateNavigationBar(
                selectedDate: selectedDate,
                dateFilterMode: dateFilterMode,
                onDateChanged: onDateChanged
            )
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Sample Content")
            .font(.title)
            .padding()
        
        Spacer()
        
        DateNavigationBar(
            selectedDate: .constant(Date()),
            dateFilterMode: .constant(nil),
            onDateChanged: { date in
                print("Date changed to: \(date)")
            }
        )
    }
    .background(LopanColors.backgroundSecondary)
}