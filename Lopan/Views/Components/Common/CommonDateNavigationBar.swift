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
    
    var body: some View {
        VStack(spacing: 12) {
            // Date navigation
            HStack {
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: { showingDatePicker = true }) {
                    VStack(spacing: 2) {
                        Text(selectedDate, style: .date)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(dayOfWeek(selectedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                Spacer()
                
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            
        }
        .padding(.bottom, 10)
    }
    
    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
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