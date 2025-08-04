import Foundation
import SwiftData

// MARK: - Batch Template Model

@Model
final class BatchTemplate {
    var id: String
    var name: String
    var templateDescription: String
    var createdBy: String
    var createdAt: Date
    var lastModifiedAt: Date
    var isActive: Bool
    var applicableMachines: [String] // Machine IDs that can use this template
    var productTemplates: [ProductTemplate]
    var recurrencePattern: RecurrencePattern?
    var defaultStationCount: Int
    var estimatedDuration: TimeInterval // In seconds
    var priority: TemplatePriority
    var tags: [String] // For categorization and search
    
    // Computed properties
    var displayName: String {
        return name.isEmpty ? "未命名模板" : name
    }
    
    var isExpired: Bool {
        guard let recurrence = recurrencePattern else { return false }
        return recurrence.endDate != nil && Date() > recurrence.endDate!
    }
    
    var formattedDuration: String {
        let hours = Int(estimatedDuration) / 3600
        let minutes = (Int(estimatedDuration) % 3600) / 60
        return hours > 0 ? "\(hours)小时\(minutes)分钟" : "\(minutes)分钟"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        createdBy: String,
        applicableMachines: [String] = [],
        productTemplates: [ProductTemplate] = [],
        defaultStationCount: Int = 1,
        estimatedDuration: TimeInterval = 3600,
        priority: TemplatePriority = .medium
    ) {
        self.id = id
        self.name = name
        self.templateDescription = description
        self.createdBy = createdBy
        self.createdAt = Date()
        self.lastModifiedAt = Date()
        self.isActive = true
        self.applicableMachines = applicableMachines
        self.productTemplates = productTemplates
        self.recurrencePattern = nil
        self.defaultStationCount = defaultStationCount
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.tags = []
    }
}

// MARK: - Product Template

@Model
final class ProductTemplate {
    var id: String
    var productId: String
    var productName: String
    var defaultColorId: String
    var defaultGunId: String
    var defaultStationNumbers: [Int]
    var isRequired: Bool // Must be included when using template
    var order: Int // Display order in template
    
    init(
        id: String = UUID().uuidString,
        productId: String,
        productName: String,
        defaultColorId: String,
        defaultGunId: String,
        defaultStationNumbers: [Int] = [],
        isRequired: Bool = true,
        order: Int = 0
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.defaultColorId = defaultColorId
        self.defaultGunId = defaultGunId
        self.defaultStationNumbers = defaultStationNumbers
        self.isRequired = isRequired
        self.order = order
    }
}

// MARK: - Approval Group Model

@Model
final class ApprovalGroup {
    var id: String
    var groupName: String
    var targetDate: Date
    var batchIds: [String] // Associated production batch IDs
    var groupStatus: GroupApprovalStatus
    var coordinatorUserId: String
    var submittedAt: Date?
    var approvedAt: Date?
    var approvedBy: String?
    var rejectedAt: Date?
    var rejectedBy: String?
    var rejectionReason: String?
    var notes: String
    var priority: ApprovalPriority
    var estimatedCompletionTime: Date?
    var actualCompletionTime: Date?
    var conflictResolutions: [ConflictResolution]
    
    // Computed properties
    var displayName: String {
        return groupName.isEmpty ? "批次组-\(targetDate.formatted(date: .abbreviated, time: .omitted))" : groupName
    }
    
    var isOverdue: Bool {
        guard let estimatedTime = estimatedCompletionTime else { return false }
        return Date() > estimatedTime && groupStatus != .fullyApproved && groupStatus != .applied
    }
    
    var processingDuration: TimeInterval? {
        guard let submitted = submittedAt else { return nil }
        let endTime = approvedAt ?? rejectedAt ?? Date()
        return endTime.timeIntervalSince(submitted)
    }
    
    var statusDisplayText: String {
        return groupStatus.displayName
    }
    
    var statusColor: String {
        return groupStatus.color
    }
    
    init(
        id: String = UUID().uuidString,
        groupName: String,
        targetDate: Date,
        batchIds: [String] = [],
        coordinatorUserId: String,
        priority: ApprovalPriority = .medium
    ) {
        self.id = id
        self.groupName = groupName
        self.targetDate = targetDate
        self.batchIds = batchIds
        self.groupStatus = .draft
        self.coordinatorUserId = coordinatorUserId
        self.submittedAt = nil
        self.approvedAt = nil
        self.approvedBy = nil
        self.rejectedAt = nil
        self.rejectedBy = nil
        self.rejectionReason = nil
        self.notes = ""
        self.priority = priority
        self.estimatedCompletionTime = nil
        self.actualCompletionTime = nil
        self.conflictResolutions = []
    }
}

// MARK: - Machine Readiness State Model

@Model
final class MachineReadinessState {
    var id: String
    var machineId: String
    var targetDate: Date
    var readinessStatus: MachineReadiness
    var lastApprovedBatchId: String?
    var pendingBatchId: String?
    var conflicts: [ConfigurationConflict]
    var lastStatusUpdate: Date
    var statusUpdatedBy: String
    var estimatedReadyTime: Date?
    var actualReadyTime: Date?
    var maintenanceWindow: DateInterval?
    var notes: String
    var healthScore: Double // 0.0 to 1.0, machine health indicator
    
    // Computed properties
    var isReady: Bool {
        return readinessStatus == .ready
    }
    
    var hasConflicts: Bool {
        return !conflicts.isEmpty
    }
    
    var isInMaintenance: Bool {
        guard let maintenance = maintenanceWindow else { return false }
        return maintenance.contains(Date())
    }
    
    var isAvailable: Bool {
        return readinessStatus.isAvailable && !isInMaintenance
    }
    
    var statusDisplayText: String {
        return readinessStatus.displayName
    }
    
    var healthDisplayText: String {
        switch healthScore {
        case 0.8...1.0: return "优秀"
        case 0.6..<0.8: return "良好"
        case 0.4..<0.6: return "一般"
        case 0.2..<0.4: return "较差"
        default: return "故障"
        }
    }
    
    init(
        id: String = UUID().uuidString,
        machineId: String,
        targetDate: Date,
        readinessStatus: MachineReadiness = .notReady,
        statusUpdatedBy: String
    ) {
        self.id = id
        self.machineId = machineId
        self.targetDate = targetDate
        self.readinessStatus = readinessStatus
        self.lastApprovedBatchId = nil
        self.pendingBatchId = nil
        self.conflicts = []
        self.lastStatusUpdate = Date()
        self.statusUpdatedBy = statusUpdatedBy
        self.estimatedReadyTime = nil
        self.actualReadyTime = nil
        self.maintenanceWindow = nil
        self.notes = ""
        self.healthScore = 1.0
    }
}

// MARK: - Conflict Resolution Model

@Model
final class ConflictResolution {
    var id: String
    var conflictType: ConflictType
    var conflictDescription: String
    var resolutionStrategy: ResolutionStrategy
    var resolutionDetails: String
    var resolvedBy: String
    var resolvedAt: Date
    var impactedMachineIds: [String]
    var originalConfiguration: String // JSON representation
    var resolvedConfiguration: String // JSON representation
    
    init(
        id: String = UUID().uuidString,
        conflictType: ConflictType,
        conflictDescription: String,
        resolutionStrategy: ResolutionStrategy,
        resolutionDetails: String,
        resolvedBy: String,
        impactedMachineIds: [String] = []
    ) {
        self.id = id
        self.conflictType = conflictType
        self.conflictDescription = conflictDescription
        self.resolutionStrategy = resolutionStrategy
        self.resolutionDetails = resolutionDetails
        self.resolvedBy = resolvedBy
        self.resolvedAt = Date()
        self.impactedMachineIds = impactedMachineIds
        self.originalConfiguration = ""
        self.resolvedConfiguration = ""
    }
}

// MARK: - Supporting Enumerations

enum TemplatePriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "紧急"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var order: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

enum GroupApprovalStatus: String, CaseIterable, Codable {
    case draft = "draft"
    case validating = "validating"
    case pendingReview = "pending_review"
    case partiallyApproved = "partially_approved"
    case fullyApproved = "fully_approved"
    case rejected = "rejected"
    case applied = "applied"
    
    var displayName: String {
        switch self {
        case .draft: return "草稿"
        case .validating: return "验证中"
        case .pendingReview: return "待审核"
        case .partiallyApproved: return "部分批准"
        case .fullyApproved: return "已批准"
        case .rejected: return "已拒绝"
        case .applied: return "已应用"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .validating: return "blue"
        case .pendingReview: return "orange"
        case .partiallyApproved: return "yellow"
        case .fullyApproved: return "green"
        case .rejected: return "red"
        case .applied: return "purple"
        }
    }
    
    var isActionable: Bool {
        return [.draft, .pendingReview, .partiallyApproved].contains(self)
    }
}

enum MachineReadiness: String, CaseIterable, Codable {
    case notReady = "not_ready"
    case preparing = "preparing"
    case ready = "ready"
    case inUse = "in_use"
    case maintenance = "maintenance"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .notReady: return "未就绪"
        case .preparing: return "准备中"
        case .ready: return "就绪"
        case .inUse: return "使用中"
        case .maintenance: return "维护中"
        case .error: return "故障"
        }
    }
    
    var color: String {
        switch self {
        case .notReady: return "gray"
        case .preparing: return "blue"
        case .ready: return "green"
        case .inUse: return "orange"
        case .maintenance: return "yellow"
        case .error: return "red"
        }
    }
    
    var isAvailable: Bool {
        return [.ready, .preparing].contains(self)
    }
}

enum ApprovalPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}

enum ConflictType: String, CaseIterable, Codable {
    case stationOverlap = "station_overlap"
    case machineUnavailable = "machine_unavailable"
    case resourceConstraint = "resource_constraint"
    case timeConflict = "time_conflict"
    case dependencyMissing = "dependency_missing"
    case configurationInvalid = "configuration_invalid"
    
    var displayName: String {
        switch self {
        case .stationOverlap: return "工位冲突"
        case .machineUnavailable: return "设备不可用"
        case .resourceConstraint: return "资源限制"
        case .timeConflict: return "时间冲突"
        case .dependencyMissing: return "依赖缺失"
        case .configurationInvalid: return "配置无效"
        }
    }
    
    var severity: ConflictSeverity {
        switch self {
        case .stationOverlap, .machineUnavailable: return .high
        case .resourceConstraint, .timeConflict: return .medium
        case .dependencyMissing, .configurationInvalid: return .low
        }
    }
}

enum ConflictSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum ResolutionStrategy: String, CaseIterable, Codable {
    case automatic = "automatic"
    case manual = "manual"
    case escalated = "escalated"
    case postponed = "postponed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .automatic: return "自动解决"
        case .manual: return "手动解决"
        case .escalated: return "升级处理"
        case .postponed: return "延期处理"
        case .cancelled: return "取消处理"
        }
    }
}

// MARK: - Supporting Structures

struct RecurrencePattern: Codable {
    var frequency: RecurrenceFrequency
    var interval: Int // Every N days/weeks/months
    var daysOfWeek: [Int]? // For weekly recurrence (1=Sunday, 7=Saturday)
    var dayOfMonth: Int? // For monthly recurrence
    var endDate: Date?
    var maxOccurrences: Int?
    
    var description: String {
        switch frequency {
        case .daily:
            return interval == 1 ? "每天" : "每\(interval)天"
        case .weekly:
            if let days = daysOfWeek, !days.isEmpty {
                let dayNames = days.map { weekdayName($0) }.joined(separator: "、")
                return "每周\(dayNames)"
            }
            return interval == 1 ? "每周" : "每\(interval)周"
        case .monthly:
            if let day = dayOfMonth {
                return "每月\(day)号"
            }
            return interval == 1 ? "每月" : "每\(interval)个月"
        }
    }
    
    private func weekdayName(_ day: Int) -> String {
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[day] ?? ""
    }
}

enum RecurrenceFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "每日"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }
}

struct ConfigurationConflict: Codable {
    let id: String
    let type: ConflictType
    let severity: ConflictSeverity
    let description: String
    let affectedMachineIds: [String]
    let suggestedResolution: String?
    let detectedAt: Date
    let canAutoResolve: Bool
    
    init(
        id: String = UUID().uuidString,
        type: ConflictType,
        severity: ConflictSeverity,
        description: String,
        affectedMachineIds: [String] = [],
        suggestedResolution: String? = nil,
        canAutoResolve: Bool = false
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = description
        self.affectedMachineIds = affectedMachineIds
        self.suggestedResolution = suggestedResolution
        self.detectedAt = Date()
        self.canAutoResolve = canAutoResolve
    }
}