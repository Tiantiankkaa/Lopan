//
//  Shift.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation

// MARK: - Workshop Shift Enumeration
enum Shift: String, CaseIterable, Codable {
    case morning = "morning"
    case evening = "evening"
    
    var displayName: String {
        switch self {
        case .morning: return "早班"
        case .evening: return "晚班"
        }
    }
    
    var englishDisplayName: String {
        switch self {
        case .morning: return "Morning Shift"
        case .evening: return "Evening Shift"
        }
    }
    
    var cutoffHour: Int {
        return 12 // 12:00 local time cutoff
    }
    
    var sortOrder: Int {
        switch self {
        case .morning: return 1
        case .evening: return 2
        }
    }
    
    // MARK: - Shift Time Ranges
    var standardStartTime: (hour: Int, minute: Int) {
        switch self {
        case .morning: return (8, 0)  // 08:00
        case .evening: return (20, 0) // 20:00
        }
    }
    
    var standardEndTime: (hour: Int, minute: Int) {
        switch self {
        case .morning: return (20, 0)  // 20:00
        case .evening: return (8, 0)   // 08:00 next day
        }
    }
}

// MARK: - Shift Date Combination
struct ShiftDate: Codable, Hashable {
    let date: Date
    let shift: Shift
    
    init(date: Date, shift: Shift) {
        self.date = Calendar.current.startOfDay(for: date)
        self.shift = shift
    }
    
    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)) \(shift.displayName)"
    }
    
    var englishDisplayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)) \(shift.englishDisplayName)"
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(date)
    }
    
    var sortKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date))-\(shift.sortOrder)"
    }
}

// MARK: - Comparable Conformance
extension ShiftDate: Comparable {
    static func < (lhs: ShiftDate, rhs: ShiftDate) -> Bool {
        if lhs.date == rhs.date {
            return lhs.shift.sortOrder < rhs.shift.sortOrder
        }
        return lhs.date < rhs.date
    }
}

// MARK: - Shift Selection Rules
enum ShiftSelectionError: LocalizedError {
    case shiftNotAllowed
    case cutoffTimePassed
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .shiftNotAllowed:
            return "所选班次在当前时间不可用"
        case .cutoffTimePassed:
            return "已过 12:00，今日仅可创建晚班"
        case .invalidDate:
            return "无效的日期选择"
        }
    }
    
    var englishDescription: String {
        switch self {
        case .shiftNotAllowed:
            return "Selected shift is not available at current time"
        case .cutoffTimePassed:
            return "It's after 12:00 — only the evening shift is available for today"
        case .invalidDate:
            return "Invalid date selection"
        }
    }
}

// MARK: - Shift Helper Extensions
extension Shift {
    static func defaultShift(for date: Date, currentTime: Date = Date()) -> Shift {
        let calendar = Calendar.current
        
        // For tomorrow or future dates, default to morning
        if !calendar.isDate(date, inSameDayAs: currentTime) {
            return .morning
        }
        
        // For today, check if before or after cutoff
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        
        // If before 12:00, default to morning; otherwise evening
        if currentHour < 12 || (currentHour == 12 && currentMinute == 0) {
            return .morning
        } else {
            return .evening
        }
    }
    
    static func availableShifts(for date: Date, currentTime: Date = Date()) -> [Shift] {
        let calendar = Calendar.current
        
        // For tomorrow or future dates, both shifts available
        if !calendar.isDate(date, inSameDayAs: currentTime) {
            return [.morning, .evening]
        }
        
        // For today, check cutoff time
        let currentHour = calendar.component(.hour, from: currentTime)
        
        if currentHour < 12 {
            return [.morning, .evening]
        } else {
            return [.evening]
        }
    }
    
    func isAvailable(for date: Date, currentTime: Date = Date()) -> Bool {
        return Self.availableShifts(for: date, currentTime: currentTime).contains(self)
    }
}