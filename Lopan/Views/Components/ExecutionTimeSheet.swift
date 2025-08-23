//
//  ExecutionTimeSheet.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI

// MARK: - Execution Time Sheet (执行时间选择表单)
struct ExecutionTimeSheet: View {
    let batch: ProductionBatch
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void
    
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @StateObject private var dateShiftPolicy = StandardDateShiftPolicy()
    private let timeProvider = SystemTimeProvider()
    
    init(batch: ProductionBatch, onConfirm: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.batch = batch
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        // Initialize with current time or batch target date
        let initialDate = batch.targetDate ?? Date()
        self._selectedDate = State(initialValue: initialDate)
        self._selectedTime = State(initialValue: Date())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                Divider()
                
                batchInfoSection
                
                dateTimeSelectionSection
                
                validationSection
                
                Spacer()
                
                actionButtons
            }
            .padding()
            .navigationTitle("设置执行时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("执行批次")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("设置批次的实际执行时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Batch Info Section
    
    private var batchInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("批次号")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(batch.batchNumber + " (" + batch.batchType.displayName + ")")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if let targetDate = batch.targetDate, let shift = batch.shift {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("计划班次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: shift == .morning ? "sun.min" : "moon")
                                .font(.caption)
                                .foregroundColor(shift == .morning ? .orange : .indigo)
                            
                            Text("\(formatDate(targetDate)) \(shift.displayName)")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text(shift.timeRangeDisplay)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Date Time Selection Section
    
    private var dateTimeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择执行时间")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Fixed Date Display (no picker - locked to batch target date)
                HStack {
                    Label("日期", systemImage: "calendar")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(selectedDate.formatted(.dateTime.year().month().day()))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Date restriction explanation
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("执行日期已锁定为批次提交日期，仅可修改执行时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Divider()
                
                // Time Picker
                HStack {
                    Label("时间", systemImage: "clock")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
    }
    
    // MARK: - Validation Section
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("验证条件", systemImage: "checkmark.shield")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                validationItem(
                    title: "时间限制",
                    isValid: combinedDateTime <= Date(),
                    message: combinedDateTime <= Date() ? "执行时间有效" : "执行时间不能晚于当前时间"
                )
                
                if let shift = batch.shift {
                    validationItem(
                        title: "班次时间",
                        isValid: isWithinShiftHours,
                        message: isWithinShiftHours ? "在班次时间范围内" : "不在 \(shift.timeRangeDisplay) 范围内"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func validationItem(title: String, isValid: Bool, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isValid ? .green : .red)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(message)
                .font(.caption2)
                .foregroundColor(isValid ? .green : .red)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                onCancel()
            }) {
                Text("取消")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
            }
            
            Button(action: {
                confirmExecution()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("确认执行")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canConfirm ? Color.blue : Color.gray)
                )
            }
            .disabled(!canConfirm)
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? Date()
    }
    
    private var isWithinShiftHours: Bool {
        guard let shift = batch.shift else { return true }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: combinedDateTime)
        
        switch shift {
        case .morning:
            // Morning shift: 07:00 - 19:00
            return hour >= 7 && hour < 19
        case .evening:
            // Evening shift: 19:00 - 07:00 (next day)
            return hour >= 19 || hour < 7
        }
    }
    
    private var canConfirm: Bool {
        return combinedDateTime <= Date() && isWithinShiftHours
    }
    
    private func confirmExecution() {
        if !canConfirm {
            errorMessage = "请选择有效的执行时间"
            showingError = true
            return
        }
        
        onConfirm(combinedDateTime)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ExecutionTimeSheet_Previews: PreviewProvider {
    static var previews: some View {
        let mockBatch = ProductionBatch(
            machineId: "machine1",
            mode: .singleColor,
            submittedBy: "user1",
            submittedByName: "张三",
            batchNumber: "PC-20250814-0001",
            targetDate: Date(),
            shift: .morning
        )
        mockBatch.status = BatchStatus.pendingExecution
        
        return ExecutionTimeSheet(
            batch: mockBatch,
            onConfirm: { _ in },
            onCancel: { }
        )
    }
}