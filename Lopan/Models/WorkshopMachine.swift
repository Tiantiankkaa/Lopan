//
//  WorkshopMachine.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

// MARK: - Machine Status & States
enum MachineStatus: String, CaseIterable, Codable {
    case running = "running"
    case stopped = "stopped"
    case maintenance = "maintenance"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .running: return "运行中"
        case .stopped: return "已停止"
        case .maintenance: return "维护中"
        case .error: return "故障"
        }
    }
    
    var iconName: String {
        switch self {
        case .running: return "play.circle.fill"
        case .stopped: return "stop.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .running: return "green"
        case .stopped: return "gray"
        case .maintenance: return "orange"
        case .error: return "red"
        }
    }
}

enum StationStatus: String, CaseIterable, Codable {
    case idle = "idle"
    case running = "running"
    case blocked = "blocked"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .running: return "运行中"
        case .blocked: return "阻塞"
        case .maintenance: return "维护"
        }
    }
}

// MARK: - SwiftData Models
@Model
final class WorkshopMachine: Codable, Identifiable {
    var id: String
    var machineNumber: Int
    var status: MachineStatus
    var isActive: Bool
    var lastMaintenanceDate: Date?
    var nextMaintenanceDate: Date?
    var totalRunHours: Double
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var notes: String?
    
    // Production metrics
    var dailyTarget: Int
    var currentProductionCount: Int
    var utilizationRate: Double
    var errorCount: Int
    
    // Production configuration
    var currentBatchId: String?
    var currentProductionMode: ProductionMode?
    var lastConfigurationUpdate: Date?
    
    // Machine basic settings
    var curingTime: Int // in seconds
    var moldOpeningTimes: Int // number of times
    
    // Relationships
    @Relationship(deleteRule: .cascade) var stations: [WorkshopStation] = []
    @Relationship(deleteRule: .cascade) var guns: [WorkshopGun] = []
    
    init(machineNumber: Int, createdBy: String) {
        self.id = UUID().uuidString
        self.machineNumber = machineNumber
        self.status = .stopped
        self.isActive = true
        self.totalRunHours = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.createdBy = createdBy
        self.dailyTarget = 1000
        self.currentProductionCount = 0
        self.utilizationRate = 0.0
        self.errorCount = 0
        self.curingTime = 30 // Default 30 seconds
        self.moldOpeningTimes = 1 // Default 1 time
        
        // Don't create related objects here - SwiftData relationships will be empty initially
        // Related objects should be created after the machine is inserted into the context
    }
    
    // MARK: - Computed Properties
    var canBeDeleted: Bool {
        return status != .running && !hasActiveProductionBatch
    }
    
    var canReceiveNewTasks: Bool {
        return isActive && status != .maintenance && status != .error
    }
    
    var activeStationsCount: Int {
        return stations.filter { $0.status == .running }.count
    }
    
    var idleStationsCount: Int {
        return stations.filter { $0.status == .idle }.count
    }
    
    var statusSummary: String {
        return "\(activeStationsCount)运行 / \(idleStationsCount)空闲"
    }
    
    var hasActiveProductionBatch: Bool {
        return currentBatchId != nil
    }
    
    var productionModeDisplayName: String {
        return currentProductionMode?.displayName ?? "未配置"
    }
    
    var gunsWithColors: [WorkshopGun] {
        return guns.filter { $0.hasColorAssigned }
    }
    
    var availableStations: [WorkshopStation] {
        return stations.filter { $0.isAvailable }
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case id, machineNumber, status, isActive
        case lastMaintenanceDate, nextMaintenanceDate, totalRunHours
        case createdAt, updatedAt, createdBy, notes
        case dailyTarget, currentProductionCount, utilizationRate, errorCount
        case currentBatchId, currentProductionMode, lastConfigurationUpdate
        case curingTime, moldOpeningTimes
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(machineNumber, forKey: .machineNumber)
        try container.encode(status, forKey: .status)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(lastMaintenanceDate, forKey: .lastMaintenanceDate)
        try container.encodeIfPresent(nextMaintenanceDate, forKey: .nextMaintenanceDate)
        try container.encode(totalRunHours, forKey: .totalRunHours)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(dailyTarget, forKey: .dailyTarget)
        try container.encode(currentProductionCount, forKey: .currentProductionCount)
        try container.encode(utilizationRate, forKey: .utilizationRate)
        try container.encode(errorCount, forKey: .errorCount)
        try container.encodeIfPresent(currentBatchId, forKey: .currentBatchId)
        try container.encodeIfPresent(currentProductionMode, forKey: .currentProductionMode)
        try container.encodeIfPresent(lastConfigurationUpdate, forKey: .lastConfigurationUpdate)
        try container.encode(curingTime, forKey: .curingTime)
        try container.encode(moldOpeningTimes, forKey: .moldOpeningTimes)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        machineNumber = try container.decode(Int.self, forKey: .machineNumber)
        status = try container.decode(MachineStatus.self, forKey: .status)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        lastMaintenanceDate = try container.decodeIfPresent(Date.self, forKey: .lastMaintenanceDate)
        nextMaintenanceDate = try container.decodeIfPresent(Date.self, forKey: .nextMaintenanceDate)
        totalRunHours = try container.decode(Double.self, forKey: .totalRunHours)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        dailyTarget = try container.decode(Int.self, forKey: .dailyTarget)
        currentProductionCount = try container.decode(Int.self, forKey: .currentProductionCount)
        utilizationRate = try container.decode(Double.self, forKey: .utilizationRate)
        errorCount = try container.decode(Int.self, forKey: .errorCount)
        currentBatchId = try container.decodeIfPresent(String.self, forKey: .currentBatchId)
        currentProductionMode = try container.decodeIfPresent(ProductionMode.self, forKey: .currentProductionMode)
        lastConfigurationUpdate = try container.decodeIfPresent(Date.self, forKey: .lastConfigurationUpdate)
        curingTime = try container.decode(Int.self, forKey: .curingTime)
        moldOpeningTimes = try container.decode(Int.self, forKey: .moldOpeningTimes)
        
        // Initialize empty relationships - these would be loaded separately
        stations = []
        guns = []
    }
}

@Model
final class WorkshopStation: Codable {
    var id: String
    var stationNumber: Int
    var status: StationStatus
    var machineId: String
    var currentProductId: String?
    var lastProductionTime: Date?
    var totalProductionCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(stationNumber: Int, machineId: String) {
        self.id = UUID().uuidString
        self.stationNumber = stationNumber
        self.status = .idle
        self.machineId = machineId
        self.totalProductionCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var gunType: String {
        return stationNumber <= 6 ? "Gun A" : "Gun B"
    }
    
    var isAvailable: Bool {
        return status == .idle
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case id, stationNumber, status, machineId
        case currentProductId, lastProductionTime, totalProductionCount
        case createdAt, updatedAt
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(stationNumber, forKey: .stationNumber)
        try container.encode(status, forKey: .status)
        try container.encode(machineId, forKey: .machineId)
        try container.encodeIfPresent(currentProductId, forKey: .currentProductId)
        try container.encodeIfPresent(lastProductionTime, forKey: .lastProductionTime)
        try container.encode(totalProductionCount, forKey: .totalProductionCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stationNumber = try container.decode(Int.self, forKey: .stationNumber)
        status = try container.decode(StationStatus.self, forKey: .status)
        machineId = try container.decode(String.self, forKey: .machineId)
        currentProductId = try container.decodeIfPresent(String.self, forKey: .currentProductId)
        lastProductionTime = try container.decodeIfPresent(Date.self, forKey: .lastProductionTime)
        totalProductionCount = try container.decode(Int.self, forKey: .totalProductionCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

@Model
final class WorkshopGun: Codable, Identifiable {
    var id: String
    var name: String // "Gun A" or "Gun B"
    var stationRangeStart: Int
    var stationRangeEnd: Int
    var machineId: String
    var currentColorId: String?
    var currentColorName: String?
    var currentColorHex: String?
    var totalShotCount: Int
    var lastColorChangeDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, stationRangeStart: Int, stationRangeEnd: Int, machineId: String) {
        self.id = UUID().uuidString
        self.name = name
        self.stationRangeStart = stationRangeStart
        self.stationRangeEnd = stationRangeEnd
        self.machineId = machineId
        self.totalShotCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var stationRange: ClosedRange<Int> {
        return stationRangeStart...stationRangeEnd
    }
    
    var hasColorAssigned: Bool {
        return currentColorId != nil
    }
    
    var displayColorInfo: String {
        if let colorName = currentColorName {
            return colorName
        }
        return "未分配颜色"
    }
    
    func assignColor(_ colorCard: ColorCard) {
        self.currentColorId = colorCard.id
        self.currentColorName = colorCard.name
        self.currentColorHex = colorCard.hexCode
        self.lastColorChangeDate = Date()
        self.updatedAt = Date()
    }
    
    func clearColor() {
        self.currentColorId = nil
        self.currentColorName = nil
        self.currentColorHex = nil
        self.lastColorChangeDate = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case id, name, stationRangeStart, stationRangeEnd, machineId
        case currentColorId, currentColorName, currentColorHex
        case totalShotCount, lastColorChangeDate, createdAt, updatedAt
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(stationRangeStart, forKey: .stationRangeStart)
        try container.encode(stationRangeEnd, forKey: .stationRangeEnd)
        try container.encode(machineId, forKey: .machineId)
        try container.encodeIfPresent(currentColorId, forKey: .currentColorId)
        try container.encodeIfPresent(currentColorName, forKey: .currentColorName)
        try container.encodeIfPresent(currentColorHex, forKey: .currentColorHex)
        try container.encode(totalShotCount, forKey: .totalShotCount)
        try container.encodeIfPresent(lastColorChangeDate, forKey: .lastColorChangeDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        stationRangeStart = try container.decode(Int.self, forKey: .stationRangeStart)
        stationRangeEnd = try container.decode(Int.self, forKey: .stationRangeEnd)
        machineId = try container.decode(String.self, forKey: .machineId)
        currentColorId = try container.decodeIfPresent(String.self, forKey: .currentColorId)
        currentColorName = try container.decodeIfPresent(String.self, forKey: .currentColorName)
        currentColorHex = try container.decodeIfPresent(String.self, forKey: .currentColorHex)
        totalShotCount = try container.decode(Int.self, forKey: .totalShotCount)
        lastColorChangeDate = try container.decodeIfPresent(Date.self, forKey: .lastColorChangeDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}