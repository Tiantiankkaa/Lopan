//
//  DateTimeUtilities.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/15.
//

import Foundation

/// 统一的日期时间处理工具类
/// Unified date and time utility class
public struct DateTimeUtilities {
    
    // MARK: - Date Formatting
    
    /// 格式化日期
    /// Format date with specified format
    static func formatDate(_ date: Date, format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    /// 格式化日期时间
    /// Format date and time
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    /// 格式化审批日期（MM/dd格式）
    /// Format approval date in MM/dd format
    static func formatApprovalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    /// 格式化中等样式日期
    /// Format date in medium style
    static func formatMediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // MARK: - Date Combination
    
    /// 合并日期和时间
    /// Combine date and time into a single Date object
    static func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents) ?? date
    }
    
    /// 创建班次开始时间
    /// Create shift start time for a given date and shift
    static func createShiftStartTime(for date: Date, shift: Shift) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let shiftTime = shift.standardStartTime
        components.hour = shiftTime.hour
        components.minute = shiftTime.minute
        return calendar.date(from: components) ?? date
    }
    
    // MARK: - Relative Time
    
    /// 显示时间差（多久前）
    /// Display time difference (time ago)
    static func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if days > 0 {
            return "\(days)天前"
        } else if hours > 0 {
            return "\(hours)小时前"
        } else if minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
    
    // MARK: - Validation Helpers
    
    /// 检查日期是否为今天
    /// Check if date is today
    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    /// 检查日期是否为明天
    /// Check if date is tomorrow
    static func isTomorrow(_ date: Date) -> Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            return false
        }
        return Calendar.current.isDate(date, inSameDayAs: tomorrow)
    }
    
    /// 检查日期是否在将来
    /// Check if date is in the future
    static func isFuture(_ date: Date) -> Bool {
        return date > Date()
    }
    
    /// 检查日期是否在过去
    /// Check if date is in the past
    static func isPast(_ date: Date) -> Bool {
        return date < Date()
    }
}

// MARK: - Date Extension for Convenience

extension Date {
    /// 使用DateTimeUtilities格式化为字符串
    /// Format using DateTimeUtilities
    func formatted(with format: String = "yyyy-MM-dd") -> String {
        return DateTimeUtilities.formatDate(self, format: format)
    }
    
    /// 格式化为日期时间字符串
    /// Format as date time string
    func formattedDateTime() -> String {
        return DateTimeUtilities.formatDateTime(self)
    }
    
    /// 格式化为审批日期字符串
    /// Format as approval date string
    func formattedApprovalDate() -> String {
        return DateTimeUtilities.formatApprovalDate(self)
    }
    
    /// 显示相对时间
    /// Display relative time
    func timeAgo() -> String {
        return DateTimeUtilities.timeAgoString(from: self)
    }
}