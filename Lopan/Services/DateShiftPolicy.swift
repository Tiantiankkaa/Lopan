//
//  DateShiftPolicy.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import Foundation
import SwiftUI

// MARK: - Date Shift Policy Protocol (日期班次策略协议)
protocol DateShiftPolicy {
    func allowedShifts(for targetDate: Date, currentTime: Date) -> Set<Shift>
    func defaultShift(for targetDate: Date, currentTime: Date) -> Shift
    func validateShiftSelection(_ shift: Shift, for targetDate: Date, currentTime: Date) throws
    func getCutoffInfo(for targetDate: Date, currentTime: Date) -> ShiftCutoffInfo
}

// MARK: - Shift Cutoff Information (班次截止信息)
struct ShiftCutoffInfo {
    let isAfterCutoff: Bool
    let cutoffTime: Date
    let restrictionMessage: String?
    let englishRestrictionMessage: String?
    
    var hasRestriction: Bool {
        return restrictionMessage != nil
    }
}

// MARK: - Standard Date Shift Policy (标准日期班次策略)
class StandardDateShiftPolicy: ObservableObject, DateShiftPolicy {
    private let timeProvider: TimeProvider
    private let cutoffHour: Int
    
    init(timeProvider: TimeProvider = SystemTimeProvider(), cutoffHour: Int = 12) {
        self.timeProvider = timeProvider
        self.cutoffHour = cutoffHour
    }
    
    // MARK: - Policy Implementation (策略实现)
    
    func allowedShifts(for targetDate: Date, currentTime: Date = Date()) -> Set<Shift> {
        // Use provided currentTime for testing, fallback to timeProvider
        let effectiveTime = currentTime == Date() ? timeProvider.now : currentTime
        let calendar = timeProvider.calendar
        
        // For tomorrow or future dates, both shifts are available
        if !calendar.isDate(targetDate, inSameDayAs: effectiveTime) {
            return Set(Shift.allCases)
        }
        
        // For today, check cutoff time
        let currentHour = calendar.component(.hour, from: effectiveTime)
        
        if currentHour < cutoffHour {
            // Before 12:00 - both shifts available
            return Set(Shift.allCases)
        } else {
            // At or after 12:00 - only evening shift available
            return Set([.evening])
        }
    }
    
    func defaultShift(for targetDate: Date, currentTime: Date = Date()) -> Shift {
        let effectiveTime = currentTime == Date() ? timeProvider.now : currentTime
        let calendar = timeProvider.calendar
        
        // For tomorrow or future dates, default to morning
        if !calendar.isDate(targetDate, inSameDayAs: effectiveTime) {
            return .morning
        }
        
        // For today, check cutoff
        let currentHour = calendar.component(.hour, from: effectiveTime)
        
        return currentHour < cutoffHour ? .morning : .evening
    }
    
    func validateShiftSelection(_ shift: Shift, for targetDate: Date, currentTime: Date = Date()) throws {
        let allowedShifts = allowedShifts(for: targetDate, currentTime: currentTime)
        
        guard allowedShifts.contains(shift) else {
            throw ShiftSelectionError.shiftNotAllowed
        }
        
        // Additional validation for today's cutoff
        let effectiveTime = currentTime == Date() ? timeProvider.now : currentTime
        let calendar = timeProvider.calendar
        
        if calendar.isDate(targetDate, inSameDayAs: effectiveTime) {
            let currentHour = calendar.component(.hour, from: effectiveTime)
            
            if shift == .morning && currentHour >= cutoffHour {
                throw ShiftSelectionError.cutoffTimePassed
            }
        }
    }
    
    func getCutoffInfo(for targetDate: Date, currentTime: Date = Date()) -> ShiftCutoffInfo {
        let effectiveTime = currentTime == Date() ? timeProvider.now : currentTime
        let calendar = timeProvider.calendar
        
        // Create cutoff time for the target date
        var cutoffComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
        cutoffComponents.hour = cutoffHour
        cutoffComponents.minute = 0
        cutoffComponents.second = 0
        
        let cutoffTime = calendar.date(from: cutoffComponents) ?? targetDate
        
        // Check if target date is today and we're past cutoff
        if calendar.isDate(targetDate, inSameDayAs: effectiveTime) {
            let currentHour = calendar.component(.hour, from: effectiveTime)
            let isAfterCutoff = currentHour >= cutoffHour
            
            if isAfterCutoff {
                return ShiftCutoffInfo(
                    isAfterCutoff: true,
                    cutoffTime: cutoffTime,
                    restrictionMessage: "已过 12:00，今日仅可创建晚班",
                    englishRestrictionMessage: "It's after 12:00 — only the evening shift is available for today"
                )
            }
        }
        
        return ShiftCutoffInfo(
            isAfterCutoff: false,
            cutoffTime: cutoffTime,
            restrictionMessage: nil,
            englishRestrictionMessage: nil
        )
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    func getShiftScheduleSummary(for shiftDate: ShiftDate, currentTime: Date = Date()) -> String {
        let effectiveTime = currentTime == Date() ? timeProvider.now : currentTime
        let calendar = timeProvider.calendar
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = timeProvider.timeZone
        
        let dateString = dateFormatter.string(from: shiftDate.date)
        let shiftName = shiftDate.shift.displayName
        
        if calendar.isDate(shiftDate.date, inSameDayAs: effectiveTime) {
            return "今日\(shiftName) (\(dateString))"
        } else if calendar.isDateInTomorrow(shiftDate.date) {
            return "明日\(shiftName) (\(dateString))"
        } else {
            return "\(dateString) \(shiftName)"
        }
    }
    
    func canModifyShift(for batch: ProductionBatch, currentTime: Date = Date()) -> Bool {
        // Cannot modify shift for legacy batches
        guard batch.isShiftBatch else { return false }
        
        // Cannot modify if shift selection is locked
        guard !batch.isShiftSelectionLocked else { return false }
        
        // Cannot modify if batch has been submitted
        guard batch.status == .unsubmitted else { return false }
        
        return true
    }
    
    func getRemainingTimeBeforeCutoff(for date: Date, currentTime: Date = Date()) -> TimeInterval? {
        let effectiveTime = currentTime == Date() ? timeProvider.now : currentTime
        let calendar = timeProvider.calendar
        
        // Only relevant for today
        guard calendar.isDate(date, inSameDayAs: effectiveTime) else { return nil }
        
        // Create cutoff time
        var cutoffComponents = calendar.dateComponents([.year, .month, .day], from: date)
        cutoffComponents.hour = cutoffHour
        cutoffComponents.minute = 0
        cutoffComponents.second = 0
        
        guard let cutoffTime = calendar.date(from: cutoffComponents) else { return nil }
        
        // Return remaining time if before cutoff
        if effectiveTime < cutoffTime {
            return cutoffTime.timeIntervalSince(effectiveTime)
        }
        
        return nil
    }
    
    func formatRemainingTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - Shift Policy Extensions (班次策略扩展)
extension DateShiftPolicy {
    
    func isShiftAvailable(_ shift: Shift, for targetDate: Date, currentTime: Date = Date()) -> Bool {
        return allowedShifts(for: targetDate, currentTime: currentTime).contains(shift)
    }
    
    func getUnavailableShifts(for targetDate: Date, currentTime: Date = Date()) -> Set<Shift> {
        let allShifts = Set(Shift.allCases)
        let availableShifts = allowedShifts(for: targetDate, currentTime: currentTime)
        return allShifts.subtracting(availableShifts)
    }
    
    func getShiftAvailabilityInfo(for targetDate: Date, currentTime: Date = Date()) -> [ShiftAvailabilityInfo] {
        return Shift.allCases.map { shift in
            let isAvailable = isShiftAvailable(shift, for: targetDate, currentTime: currentTime)
            let cutoffInfo = getCutoffInfo(for: targetDate, currentTime: currentTime)
            
            return ShiftAvailabilityInfo(
                shift: shift,
                isAvailable: isAvailable,
                reason: isAvailable ? nil : cutoffInfo.restrictionMessage
            )
        }
    }
}

// MARK: - Shift Availability Information (班次可用性信息)
struct ShiftAvailabilityInfo {
    let shift: Shift
    let isAvailable: Bool
    let reason: String?
    
    var displayText: String {
        if isAvailable {
            return shift.displayName
        } else {
            return "\(shift.displayName) (不可用)"
        }
    }
    
    var accessibilityLabel: String {
        if isAvailable {
            return "\(shift.displayName)班次可用"
        } else {
            let reasonText = reason ?? "当前时间不可用"
            return "\(shift.displayName)班次不可用，原因：\(reasonText)"
        }
    }
}