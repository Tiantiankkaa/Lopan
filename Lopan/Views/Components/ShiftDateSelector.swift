//
//  ShiftDateSelector.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI

// MARK: - Shift Date Selector Component (班次日期选择器组件)
struct ShiftDateSelector: View {
    @Binding var selectedDate: Date
    @Binding var selectedShift: Shift
    
    let dateShiftPolicy: DateShiftPolicy
    let timeProvider: TimeProvider
    let isDisabled: Bool
    
    @State private var availableShifts: Set<Shift> = []
    @State private var cutoffInfo: ShiftCutoffInfo = ShiftCutoffInfo(isAfterCutoff: false, cutoffTime: Date(), restrictionMessage: nil, englishRestrictionMessage: nil)
    
    init(
        selectedDate: Binding<Date>,
        selectedShift: Binding<Shift>,
        dateShiftPolicy: DateShiftPolicy = StandardDateShiftPolicy(),
        timeProvider: TimeProvider = SystemTimeProvider(),
        isDisabled: Bool = false
    ) {
        self._selectedDate = selectedDate
        self._selectedShift = selectedShift
        self.dateShiftPolicy = dateShiftPolicy
        self.timeProvider = timeProvider
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        VStack(spacing: 16) {
            dateSelector
            shiftSelector
            if cutoffInfo.hasRestriction {
                timeRestrictionBanner
            }
        }
        .onAppear {
            updateAvailableShifts()
        }
        .onChange(of: selectedDate) {
            updateAvailableShifts()
        }
    }
    
    // MARK: - Date Selector (日期选择器)
    
    private var dateSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择日期")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                dateOption(
                    title: "今日",
                    subtitle: formatDate(timeProvider.today),
                    date: timeProvider.today,
                    isSelected: Calendar.current.isDate(selectedDate, inSameDayAs: timeProvider.today)
                )
                
                dateOption(
                    title: "次日",
                    subtitle: formatDate(timeProvider.tomorrow),
                    date: timeProvider.tomorrow,
                    isSelected: Calendar.current.isDate(selectedDate, inSameDayAs: timeProvider.tomorrow)
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("日期选择")
    }
    
    private func dateOption(title: String, subtitle: String, date: Date, isSelected: Bool) -> some View {
        Button(action: {
            if !isDisabled {
                selectedDate = date
            }
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("选择\(title)进行批次排班")
    }
    
    // MARK: - Shift Selector (班次选择器)
    
    private var shiftSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择班次")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(Shift.allCases, id: \.self) { shift in
                    shiftOption(shift: shift)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("班次选择")
    }
    
    private func shiftOption(shift: Shift) -> some View {
        let isAvailable = availableShifts.contains(shift)
        let isSelected = selectedShift == shift
        
        return Button(action: {
            if !isDisabled && isAvailable {
                selectedShift = shift
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: getShiftIcon(for: shift))
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(shift.displayName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                }
                
                if !isAvailable {
                    Text("不可用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColorForShift(shift: shift, isSelected: isSelected, isAvailable: isAvailable))
            )
            .foregroundColor(foregroundColorForShift(isSelected: isSelected, isAvailable: isAvailable))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColorForShift(isSelected: isSelected, isAvailable: isAvailable), lineWidth: 2)
            )
        }
        .disabled(isDisabled || !isAvailable)
        .accessibilityLabel(accessibilityLabelForShift(shift: shift, isAvailable: isAvailable))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isAvailable ? "选择\(shift.displayName)" : "当前时间不可选择\(shift.displayName)")
    }
    
    // MARK: - Time Restriction Banner (时间限制横幅)
    
    private var timeRestrictionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)
                .font(.system(size: 20, weight: .medium))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("时间限制提醒")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(cutoffInfo.restrictionMessage ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("时间限制提醒: \(cutoffInfo.restrictionMessage ?? "")")
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func updateAvailableShifts() {
        availableShifts = dateShiftPolicy.allowedShifts(for: selectedDate, currentTime: timeProvider.now)
        cutoffInfo = dateShiftPolicy.getCutoffInfo(for: selectedDate, currentTime: timeProvider.now)
        
        // Auto-select valid shift if current selection is not available
        if !availableShifts.contains(selectedShift) {
            selectedShift = dateShiftPolicy.defaultShift(for: selectedDate, currentTime: timeProvider.now)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
    
    private func getShiftIcon(for shift: Shift) -> String {
        switch shift {
        case .morning:
            return "sun.min"
        case .evening:
            return "moon"
        }
    }
    
    private func backgroundColorForShift(shift: Shift, isSelected: Bool, isAvailable: Bool) -> Color {
        if !isAvailable {
            return Color(.systemGray6).opacity(0.5)
        } else if isSelected {
            return shift == .morning ? Color.orange : Color.indigo
        } else {
            return Color(.systemGray6)
        }
    }
    
    private func foregroundColorForShift(isSelected: Bool, isAvailable: Bool) -> Color {
        if !isAvailable {
            return .secondary
        } else if isSelected {
            return .white
        } else {
            return .primary
        }
    }
    
    private func borderColorForShift(isSelected: Bool, isAvailable: Bool) -> Color {
        if isSelected && isAvailable {
            return Color.blue
        } else {
            return Color.clear
        }
    }
    
    private func accessibilityLabelForShift(shift: Shift, isAvailable: Bool) -> String {
        let baseLabel = shift.displayName
        if isAvailable {
            return "\(baseLabel)班次可用"
        } else {
            return "\(baseLabel)班次不可用，\(cutoffInfo.restrictionMessage ?? "当前时间不可选择")"
        }
    }
}

// MARK: - Preview Support (预览支持)
struct ShiftDateSelector_Previews: PreviewProvider {
    static var previews: some View {
        StatefulPreviewWrapper(Date(), Shift.morning) { date, shift in
            VStack(spacing: 24) {
                // Before cutoff scenario
                Text("12:00前场景")
                    .font(.headline)
                ShiftDateSelector(
                    selectedDate: date,
                    selectedShift: shift,
                    dateShiftPolicy: createMockPolicy(isAfterCutoff: false),
                    timeProvider: createMockTimeProvider(hour: 11, minute: 30)
                )
                
                Divider()
                
                // After cutoff scenario
                Text("12:00后场景")
                    .font(.headline)
                ShiftDateSelector(
                    selectedDate: date,
                    selectedShift: shift,
                    dateShiftPolicy: createMockPolicy(isAfterCutoff: true),
                    timeProvider: createMockTimeProvider(hour: 12, minute: 30)
                )
            }
            .padding()
        }
    }
    
    private static func createMockPolicy(isAfterCutoff: Bool) -> StandardDateShiftPolicy {
        let mockTime = createMockTimeProvider(hour: isAfterCutoff ? 13 : 11, minute: 0)
        return StandardDateShiftPolicy(timeProvider: mockTime)
    }
    
    private static func createMockTimeProvider(hour: Int, minute: Int) -> MockTimeProvider {
        let mockProvider = MockTimeProvider()
        mockProvider.setTimeOfDay(hour: hour, minute: minute)
        return mockProvider
    }
}

// MARK: - Stateful Preview Wrapper (状态预览包装器)
struct StatefulPreviewWrapper<T: Hashable, U: Hashable, Content: View>: View {
    @State var value1: T
    @State var value2: U
    var content: (Binding<T>, Binding<U>) -> Content
    
    init(_ initialValue1: T, _ initialValue2: U, @ViewBuilder content: @escaping (Binding<T>, Binding<U>) -> Content) {
        self._value1 = State(wrappedValue: initialValue1)
        self._value2 = State(wrappedValue: initialValue2)
        self.content = content
    }
    
    var body: some View {
        content($value1, $value2)
    }
}