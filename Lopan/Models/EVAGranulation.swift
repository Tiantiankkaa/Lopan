//
//  EVAGranulation.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

@Model
public final class EVAGranulation {
    public var id: String
    var batchNumber: String
    var rawMaterialType: String
    var rawMaterialQuantity: Double
    var rawMaterialUnit: String
    var color: String
    var output: Double
    var outputUnit: String
    var productionDate: Date
    var startTime: Date?
    var endTime: Date?
    var temperature: Double?
    var pressure: Double?
    var notes: String?
    var createdBy: String // User ID
    var createdAt: Date
    var updatedAt: Date
    
    init(batchNumber: String, rawMaterialType: String, rawMaterialQuantity: Double, rawMaterialUnit: String, color: String, output: Double, outputUnit: String, productionDate: Date, temperature: Double? = nil, pressure: Double? = nil, notes: String? = nil, createdBy: String) {
        self.id = UUID().uuidString
        self.batchNumber = batchNumber
        self.rawMaterialType = rawMaterialType
        self.rawMaterialQuantity = rawMaterialQuantity
        self.rawMaterialUnit = rawMaterialUnit
        self.color = color
        self.output = output
        self.outputUnit = outputUnit
        self.productionDate = productionDate
        self.temperature = temperature
        self.pressure = pressure
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 