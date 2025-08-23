//
//  DateFilterOptions.swift
//  Lopan
//
//  Created by Claude Code on 2025/1/20.
//

import Foundation

enum DateFilterOption: CaseIterable, Hashable {
    case thisWeek
    case thisMonth
    case custom(start: Date, end: Date)
    
    static var allCases: [DateFilterOption] {
        [.thisWeek, .thisMonth, .custom(start: Date(), end: Date())]
    }
    
    var displayName: String {
        switch self {
        case .thisWeek:
            return "本周"
        case .thisMonth:
            return "本月"
        case .custom:
            return "自定义"
        }
    }
    
    var systemImage: String {
        switch self {
        case .thisWeek:
            return "calendar.badge.plus"
        case .thisMonth:
            return "calendar"
        case .custom:
            return "calendar.badge.clock"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return (start: startOfWeek, end: endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (start: startOfMonth, end: endOfMonth)
            
        case .custom(let start, let end):
            return (start: start, end: end)
        }
    }
    
    func withCustomRange(start: Date, end: Date) -> DateFilterOption {
        // Validate 3-month maximum range
        let calendar = Calendar.current
        let maxEndDate = calendar.date(byAdding: .month, value: 3, to: start) ?? end
        let validEndDate = min(end, maxEndDate)
        
        return .custom(start: start, end: validEndDate)
    }
    
    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

// MARK: - Equatable for static cases
extension DateFilterOption {
    static func == (lhs: DateFilterOption, rhs: DateFilterOption) -> Bool {
        switch (lhs, rhs) {
        case (.thisWeek, .thisWeek), (.thisMonth, .thisMonth):
            return true
        case (.custom(let start1, let end1), .custom(let start2, let end2)):
            return start1 == start2 && end1 == end2
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .thisWeek:
            hasher.combine("thisWeek")
        case .thisMonth:
            hasher.combine("thisMonth")
        case .custom(let start, let end):
            hasher.combine("custom")
            hasher.combine(start)
            hasher.combine(end)
        }
    }
}