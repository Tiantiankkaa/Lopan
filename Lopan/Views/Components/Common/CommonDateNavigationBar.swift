//
//  CommonDateNavigationBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct CommonDateNavigationBar: View {
    @Binding var selectedDate: Date
    @Binding var showingDatePicker: Bool
    let loadedCount: Int
    let totalCount: Int
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    
    // Support future and past date navigation limits
    private var canNavigateToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        return tomorrow <= Date()
    }
    
    private var previousDayDescription: String {
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale.current // Respect user locale
        return formatter.string(from: previousDay)
    }
    
    private var nextDayDescription: String {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale.current
        return formatter.string(from: nextDay)
    }
    
    private var formattedAccessibilityDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.current
        return formatter.string(from: selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Date navigation
            HStack {
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true) // Icon is decorative
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("前一天")
                .accessibilityHint("查看 \(previousDayDescription) 的缺货数据")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
                
                Button(action: { showingDatePicker = true }) {
                    VStack(spacing: 2) {
                        Text(selectedDate, style: .date)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                        
                        Text(dayOfWeek(selectedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LopanColors.backgroundTertiary)
                    )
                }
                .frame(minHeight: 44) // Ensure touch target
                .accessibilityLabel("当前选中日期：\(formattedAccessibilityDate)")
                .accessibilityHint("点击更改日期")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
                
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(canNavigateToNextDay ? .accentColor : .secondary)
                        .accessibilityHidden(true) // Icon is decorative
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(!canNavigateToNextDay)
                .accessibilityLabel("后一天")
                .accessibilityHint(canNavigateToNextDay ? "查看 \(nextDayDescription) 的数据" : "已经是最新日期")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.horizontal, 20)
            
        }
        .padding(.bottom, 10)
    }
    
    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current // Respect user's locale preference
        return formatter.string(from: date)
    }
}

#Preview {
    CommonDateNavigationBar(
        selectedDate: .constant(Date()),
        showingDatePicker: .constant(false),
        loadedCount: 50,
        totalCount: 187,
        onPreviousDay: {},
        onNextDay: {}
    )
}