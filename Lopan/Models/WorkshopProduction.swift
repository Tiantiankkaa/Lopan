//
//  WorkshopProduction.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

enum MachineStatus: String, CaseIterable, Codable {
    case running = "running"
    case stopped = "stopped"
    case maintenance = "maintenance"
    case idle = "idle"
    
    var displayName: String {
        switch self {
        case .running:
            return "运行中"
        case .stopped:
            return "已停止"
        case .maintenance:
            return "维护中"
        case .idle:
            return "空闲"
        }
    }
}

@Model
final class WorkshopProduction {
    var id: String
    var machineId: String
    var machineName: String
    var styleCode: String
    var styleName: String
    var color: String
    var output: Int
    var targetOutput: Int
    var status: MachineStatus
    var productionDate: Date
    var startTime: Date?
    var endTime: Date?
    var notes: String?
    var createdBy: String // User ID
    var createdAt: Date
    var updatedAt: Date
    
    init(machineId: String, machineName: String, styleCode: String, styleName: String, color: String, targetOutput: Int, productionDate: Date, notes: String? = nil, createdBy: String) {
        self.id = UUID().uuidString
        self.machineId = machineId
        self.machineName = machineName
        self.styleCode = styleCode
        self.styleName = styleName
        self.color = color
        self.output = 0
        self.targetOutput = targetOutput
        self.status = .idle
        self.productionDate = productionDate
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 