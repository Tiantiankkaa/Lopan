//
//  PackagingModels.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import Foundation
import SwiftData
import SwiftUI

enum PackagingStatus: String, CaseIterable, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case shipped = "shipped"
    
    var displayName: String {
        switch self {
        case .inProgress:
            return "进行中"
        case .completed:
            return "已完成"
        case .shipped:
            return "已发货"
        }
    }
}

enum PackagingPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low:
            return "低优先级"
        case .medium:
            return "中优先级"
        case .high:
            return "高优先级"
        case .urgent:
            return "紧急"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
}

@Model
final class PackagingTeam {
    var id: String
    var teamName: String
    var teamLeader: String
    var members: [String] // Array of member names
    var specializedStyles: [String] // Array of style codes they handle
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(teamName: String, teamLeader: String, members: [String] = [], specializedStyles: [String] = []) {
        self.id = UUID().uuidString
        self.teamName = teamName
        self.teamLeader = teamLeader
        self.members = members
        self.specializedStyles = specializedStyles
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class PackagingRecord {
    var id: String
    var packageDate: Date
    var teamId: String // Reference to PackagingTeam
    var teamName: String // Cached team name for easier display
    var styleCode: String
    var styleName: String
    var totalPackages: Int // Total number of packages for this style
    var stylesPerPackage: Int // Number of styles/items in each package
    var totalItems: Int // Calculated field: totalPackages * stylesPerPackage
    var status: PackagingStatus
    var notes: String?
    var dueDate: Date? // Deadline for packaging completion
    var priority: PackagingPriority // Task priority level
    var reminderEnabled: Bool // Whether reminders are enabled
    var reminderSent: Bool // Whether reminder has been sent
    var createdBy: String // User ID who created the record
    var createdAt: Date
    var updatedAt: Date
    
    init(packageDate: Date, teamId: String, teamName: String, styleCode: String, styleName: String, totalPackages: Int, stylesPerPackage: Int, notes: String? = nil, dueDate: Date? = nil, priority: PackagingPriority = .medium, reminderEnabled: Bool = false, createdBy: String) {
        self.id = UUID().uuidString
        self.packageDate = packageDate
        self.teamId = teamId
        self.teamName = teamName
        self.styleCode = styleCode
        self.styleName = styleName
        self.totalPackages = totalPackages
        self.stylesPerPackage = stylesPerPackage
        self.totalItems = totalPackages * stylesPerPackage
        self.status = .inProgress
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.reminderEnabled = reminderEnabled
        self.reminderSent = false
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Update calculated fields when values change
    func updateTotalItems() {
        self.totalItems = totalPackages * stylesPerPackage
        self.updatedAt = Date()
    }
    
    // Check if task is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return Date() > dueDate && status != .completed && status != .shipped
    }
    
    // Check if task needs reminder (within 24 hours of due date)
    var needsReminder: Bool {
        guard let dueDate = dueDate,
              reminderEnabled,
              !reminderSent,
              status == .inProgress else { return false }
        
        let timeInterval = dueDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval <= 24 * 60 * 60 // Within 24 hours
    }
    
    // Mark reminder as sent
    func markReminderSent() {
        self.reminderSent = true
        self.updatedAt = Date()
    }
}

// Helper struct for daily statistics (not a SwiftData model)
struct PackagingDailyStats {
    let date: Date
    let totalPackages: Int
    let totalItems: Int
    let teamStats: [PackagingTeamStats]
    let styleStats: [PackagingStyleStats]
    
    struct PackagingTeamStats {
        let teamName: String
        let packages: Int
        let items: Int
    }
    
    struct PackagingStyleStats {
        let styleCode: String
        let styleName: String
        let packages: Int
        let items: Int
    }
}