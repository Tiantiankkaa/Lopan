//
//  PackagingReminderView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData

struct PackagingReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var packagingRecords: [PackagingRecord]
    @State private var selectedFilter: ReminderFilter = .all
    
    enum ReminderFilter: String, CaseIterable {
        case all = "all"
        case overdue = "overdue"
        case dueToday = "due_today"
        case dueTomorrow = "due_tomorrow"
        case needsReminder = "needs_reminder"
        
        var displayName: String {
            switch self {
            case .all:
                return "全部任务"
            case .overdue:
                return "已过期"
            case .dueToday:
                return "今日到期"
            case .dueTomorrow:
                return "明日到期"
            case .needsReminder:
                return "需要提醒"
            }
        }
    }
    
    private var filteredRecords: [PackagingRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        return packagingRecords.filter { record in
            guard let dueDate = record.dueDate else {
                return selectedFilter == .all
            }
            
            switch selectedFilter {
            case .all:
                return record.status != .completed && record.status != .shipped
            case .overdue:
                return record.isOverdue
            case .dueToday:
                return calendar.isDate(dueDate, inSameDayAs: today) && record.status == .inProgress
            case .dueTomorrow:
                return calendar.isDate(dueDate, inSameDayAs: tomorrow) && record.status == .inProgress
            case .needsReminder:
                return record.needsReminder
            }
        }.sorted { record1, record2 in
            // Sort by priority first, then by due date
            if record1.priority != record2.priority {
                return record1.priority.rawValue > record2.priority.rawValue
            }
            
            guard let date1 = record1.dueDate, let date2 = record2.dueDate else {
                return record1.dueDate != nil
            }
            
            return date1 < date2
        }
    }
    
    private var reminderStats: ReminderStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        let overdueCount = packagingRecords.filter { $0.isOverdue }.count
        let dueTodayCount = packagingRecords.filter { record in
            guard let dueDate = record.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today) && record.status == .inProgress
        }.count
        let dueTomorrowCount = packagingRecords.filter { record in
            guard let dueDate = record.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: tomorrow) && record.status == .inProgress
        }.count
        let needsReminderCount = packagingRecords.filter { $0.needsReminder }.count
        
        return ReminderStats(
            overdue: overdueCount,
            dueToday: dueTodayCount,
            dueTomorrow: dueTomorrowCount,
            needsReminder: needsReminderCount
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ReminderStatCard(
                            title: "已过期",
                            count: reminderStats.overdue,
                            color: LopanColors.error,
                            icon: "exclamationmark.triangle.fill"
                        ) {
                            selectedFilter = .overdue
                        }
                        
                        ReminderStatCard(
                            title: "今日到期",
                            count: reminderStats.dueToday,
                            color: LopanColors.warning,
                            icon: "calendar.badge.clock"
                        ) {
                            selectedFilter = .dueToday
                        }
                        
                        ReminderStatCard(
                            title: "明日到期",
                            count: reminderStats.dueTomorrow,
                            color: LopanColors.primary,
                            icon: "calendar"
                        ) {
                            selectedFilter = .dueTomorrow
                        }
                        
                        ReminderStatCard(
                            title: "需要提醒",
                            count: reminderStats.needsReminder,
                            color: LopanColors.premium,
                            icon: "bell.fill"
                        ) {
                            selectedFilter = .needsReminder
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(LopanColors.backgroundSecondary)
                
                // Filter picker
                Picker("筛选", selection: $selectedFilter) {
                    ForEach(ReminderFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Task list
                if filteredRecords.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: getEmptyStateIcon())
                            .font(.system(size: 50))
                            .foregroundColor(LopanColors.secondary)
                        Text(getEmptyStateMessage())
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredRecords, id: \.id) { record in
                            PackagingReminderRow(record: record) {
                                sendReminder(for: record)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("包装提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发送所有提醒") {
                        sendAllReminders()
                    }
                    .disabled(reminderStats.needsReminder == 0)
                }
            }
        }
    }
    
    private func getEmptyStateIcon() -> String {
        switch selectedFilter {
        case .all:
            return "checkmark.circle"
        case .overdue:
            return "checkmark.circle"
        case .dueToday:
            return "calendar.badge.checkmark"
        case .dueTomorrow:
            return "calendar.badge.checkmark"
        case .needsReminder:
            return "bell.slash"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch selectedFilter {
        case .all:
            return "所有包装任务都已完成"
        case .overdue:
            return "没有过期的任务"
        case .dueToday:
            return "今日没有到期的任务"
        case .dueTomorrow:
            return "明日没有到期的任务"
        case .needsReminder:
            return "没有需要提醒的任务"
        }
    }
    
    private func sendReminder(for record: PackagingRecord) {
        // In a real app, this would send a push notification or email
        record.markReminderSent()
        
        do {
            try modelContext.save()
        } catch {
            print("Error sending reminder: \(error)")
        }
    }
    
    private func sendAllReminders() {
        let recordsNeedingReminder = packagingRecords.filter { $0.needsReminder }
        
        for record in recordsNeedingReminder {
            record.markReminderSent()
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error sending reminders: \(error)")
        }
    }
}

struct ReminderStatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Spacer()
                }
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 100)
            .background(LopanColors.background)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PackagingReminderRow: View {
    let record: PackagingRecord
    let onSendReminder: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(record.styleName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Priority badge
                    Text(record.priority.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(record.priority.color.opacity(0.2))
                        .foregroundColor(record.priority.color)
                        .cornerRadius(4)
                }
                
                Text(record.styleName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(record.teamName, systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let dueDate = record.dueDate {
                        Label(formatDueDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(record.isOverdue ? LopanColors.error : .secondary)
                    }
                }
                
                if record.isOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(LopanColors.error)
                        Text("已过期")
                            .font(.caption)
                            .foregroundColor(LopanColors.error)
                    }
                }
            }
            
            VStack(spacing: 8) {
               if record.needsReminder {
                   Button(action: onSendReminder) {
                       Image(systemName: "bell.fill")
                           .foregroundColor(LopanColors.textPrimary)
                           .frame(width: 32, height: 32)
                            .background(LopanColors.premium)
                            .cornerRadius(8)
                   }
               } else if record.reminderSent {
                   Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LopanColors.success)
                        .frame(width: 32, height: 32)
               }
               
               Text("\(record.totalPackages)")
                   .font(.title3)
                   .fontWeight(.bold)
                    .foregroundColor(LopanColors.info)
                Text("包装")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }
}

struct ReminderStats {
    let overdue: Int
    let dueToday: Int
    let dueTomorrow: Int
    let needsReminder: Int
}

#Preview {
    let container = try! ModelContainer(for: PackagingRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    PackagingReminderView()
        .modelContainer(container)
}
