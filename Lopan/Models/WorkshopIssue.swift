//
//  WorkshopIssue.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

enum IssuePriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        case .critical:
            return "紧急"
        }
    }
}

enum IssueStatus: String, CaseIterable, Codable {
    case reported = "reported"
    case inProgress = "in_progress"
    case resolved = "resolved"
    case closed = "closed"
    
    var displayName: String {
        switch self {
        case .reported:
            return "已报告"
        case .inProgress:
            return "处理中"
        case .resolved:
            return "已解决"
        case .closed:
            return "已关闭"
        }
    }
}

@Model
public final class WorkshopIssue {
    public var id: String
    var machineId: String
    var machineName: String
    var issueType: String
    var issueDescription: String
    var priority: IssuePriority
    var status: IssueStatus
    var reportedDate: Date
    var resolvedDate: Date?
    var solution: String?
    var notes: String?
    var reportedBy: String // User ID
    var assignedTo: String? // User ID
    var createdAt: Date
    var updatedAt: Date
    
    init(machineId: String, machineName: String, issueType: String, issueDescription: String, priority: IssuePriority, reportedBy: String, assignedTo: String? = nil, notes: String? = nil) {
        self.id = UUID().uuidString
        self.machineId = machineId
        self.machineName = machineName
        self.issueType = issueType
        self.issueDescription = issueDescription
        self.priority = priority
        self.status = .reported
        self.reportedDate = Date()
        self.reportedBy = reportedBy
        self.assignedTo = assignedTo
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 