//
//  TimeProvider.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation

// MARK: - Time Provider Protocol (时间提供者协议)
protocol TimeProvider {
    var now: Date { get }
    var timeZone: TimeZone { get }
    var calendar: Calendar { get }
}

// MARK: - System Time Provider (系统时间提供者)
struct SystemTimeProvider: TimeProvider {
    var now: Date {
        return Date()
    }
    
    var timeZone: TimeZone {
        return TimeZone.current
    }
    
    var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }
}

// MARK: - Mock Time Provider (for testing) (测试用模拟时间提供者)
class MockTimeProvider: TimeProvider, ObservableObject {
    @Published private var mockTime: Date
    private let mockTimeZone: TimeZone
    private let mockCalendar: Calendar
    
    init(initialTime: Date = Date(), timeZone: TimeZone = .current) {
        self.mockTime = initialTime
        self.mockTimeZone = timeZone
        var cal = Calendar.current
        cal.timeZone = timeZone
        self.mockCalendar = cal
    }
    
    var now: Date {
        return mockTime
    }
    
    var timeZone: TimeZone {
        return mockTimeZone
    }
    
    var calendar: Calendar {
        return mockCalendar
    }
    
    // MARK: - Mock Control Methods (模拟控制方法)
    
    func setTime(_ time: Date) {
        mockTime = time
    }
    
    func advanceTime(by seconds: TimeInterval) {
        mockTime = mockTime.addingTimeInterval(seconds)
    }
    
    func setTimeOfDay(hour: Int, minute: Int = 0, second: Int = 0) {
        let components = calendar.dateComponents([.year, .month, .day], from: mockTime)
        var newComponents = components
        newComponents.hour = hour
        newComponents.minute = minute
        newComponents.second = second
        
        if let newTime = calendar.date(from: newComponents) {
            mockTime = newTime
        }
    }
    
    func setDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = timeZone
        
        if let newTime = calendar.date(from: components) {
            mockTime = newTime
        }
    }
    
    // Convenience methods for testing time boundaries
    func setTimeTo1159Today() {
        setTimeOfDay(hour: 11, minute: 59, second: 0)
    }
    
    func setTimeTo1200Today() {
        setTimeOfDay(hour: 12, minute: 0, second: 0)
    }
    
    func setTimeTo1201Today() {
        setTimeOfDay(hour: 12, minute: 1, second: 0)
    }
}

// MARK: - Time Provider Extensions (时间提供者扩展)
extension TimeProvider {
    
    /// Check if current time is before the 12:00 cutoff for shift selection
    /// 检查当前时间是否在12:00班次选择截止时间之前
    var isBeforeCutoff: Bool {
        let currentHour = calendar.component(.hour, from: now)
        return currentHour < 12
    }
    
    /// Check if current time is at or after the 12:00 cutoff
    /// 检查当前时间是否在12:00截止时间或之后
    var isAtOrAfterCutoff: Bool {
        return !isBeforeCutoff
    }
    
    /// Get the current hour in 24-hour format
    /// 获取当前小时（24小时格式）
    var currentHour: Int {
        return calendar.component(.hour, from: now)
    }
    
    /// Get the current minute
    /// 获取当前分钟
    var currentMinute: Int {
        return calendar.component(.minute, from: now)
    }
    
    /// Check if a given date is today
    /// 检查给定日期是否为今天
    func isToday(_ date: Date) -> Bool {
        return calendar.isDate(date, inSameDayAs: now)
    }
    
    /// Check if a given date is tomorrow
    /// 检查给定日期是否为明天
    func isTomorrow(_ date: Date) -> Bool {
        return calendar.isDateInTomorrow(date)
    }
    
    /// Get start of day for a given date
    /// 获取给定日期的开始时间
    func startOfDay(for date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    /// Get today's date (start of day)
    /// 获取今日日期（一天的开始）
    var today: Date {
        return startOfDay(for: now)
    }
    
    /// Get tomorrow's date (start of day)
    /// 获取明日日期（一天的开始）
    var tomorrow: Date {
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
    
    /// Format time for display
    /// 格式化时间用于显示
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    /// Format date for display
    /// 格式化日期用于显示
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}