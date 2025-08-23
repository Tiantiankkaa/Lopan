//
//  LocalColorRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalColorRepository: ColorRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAllColors() async throws -> [ColorCard] {
        let descriptor = FetchDescriptor<ColorCard>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchActiveColors() async throws -> [ColorCard] {
        let descriptor = FetchDescriptor<ColorCard>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchColorById(_ id: String) async throws -> ColorCard? {
        let descriptor = FetchDescriptor<ColorCard>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func addColor(_ color: ColorCard) async throws {
        modelContext.insert(color)
        try modelContext.save()
    }
    
    func updateColor(_ color: ColorCard) async throws {
        color.updatedAt = Date()
        try modelContext.save()
    }
    
    func deleteColor(_ color: ColorCard) async throws {
        modelContext.delete(color)
        try modelContext.save()
    }
    
    func deactivateColor(_ color: ColorCard) async throws {
        color.isActive = false
        color.updatedAt = Date()
        try modelContext.save()
    }
    
    func searchColors(by name: String) async throws -> [ColorCard] {
        let descriptor = FetchDescriptor<ColorCard>(
            predicate: #Predicate { color in
                color.name.localizedStandardContains(name) && color.isActive == true
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
}