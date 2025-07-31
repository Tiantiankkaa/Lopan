//
//  LocalProductionRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalProductionRepository: ProductionRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - ProductionStyle operations
    
    func fetchProductionStyles() async throws -> [ProductionStyle] {
        let descriptor = FetchDescriptor<ProductionStyle>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchProductionStyle(by id: String) async throws -> ProductionStyle? {
        let descriptor = FetchDescriptor<ProductionStyle>()
        let styles = try modelContext.fetch(descriptor)
        return styles.first { $0.id == id }
    }
    
    func fetchProductionStyles(by status: StyleStatus) async throws -> [ProductionStyle] {
        let descriptor = FetchDescriptor<ProductionStyle>()
        let styles = try modelContext.fetch(descriptor)
        return styles.filter { $0.status.rawValue == status.rawValue }
    }
    
    func addProductionStyle(_ style: ProductionStyle) async throws {
        modelContext.insert(style)
        try modelContext.save()
    }
    
    func updateProductionStyle(_ style: ProductionStyle) async throws {
        try modelContext.save()
    }
    
    func deleteProductionStyle(_ style: ProductionStyle) async throws {
        modelContext.delete(style)
        try modelContext.save()
    }
    
    // MARK: - WorkshopProduction operations
    
    func fetchWorkshopProductions() async throws -> [WorkshopProduction] {
        let descriptor = FetchDescriptor<WorkshopProduction>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchWorkshopProduction(by id: String) async throws -> WorkshopProduction? {
        let descriptor = FetchDescriptor<WorkshopProduction>()
        let productions = try modelContext.fetch(descriptor)
        return productions.first { $0.id == id }
    }
    
    func addWorkshopProduction(_ production: WorkshopProduction) async throws {
        modelContext.insert(production)
        try modelContext.save()
    }
    
    func updateWorkshopProduction(_ production: WorkshopProduction) async throws {
        try modelContext.save()
    }
    
    func deleteWorkshopProduction(_ production: WorkshopProduction) async throws {
        modelContext.delete(production)
        try modelContext.save()
    }
    
    // MARK: - EVAGranulation operations
    
    func fetchEVAGranulations() async throws -> [EVAGranulation] {
        let descriptor = FetchDescriptor<EVAGranulation>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchEVAGranulation(by id: String) async throws -> EVAGranulation? {
        let descriptor = FetchDescriptor<EVAGranulation>()
        let granulations = try modelContext.fetch(descriptor)
        return granulations.first { $0.id == id }
    }
    
    func addEVAGranulation(_ granulation: EVAGranulation) async throws {
        modelContext.insert(granulation)
        try modelContext.save()
    }
    
    func updateEVAGranulation(_ granulation: EVAGranulation) async throws {
        try modelContext.save()
    }
    
    func deleteEVAGranulation(_ granulation: EVAGranulation) async throws {
        modelContext.delete(granulation)
        try modelContext.save()
    }
    
    // MARK: - WorkshopIssue operations
    
    func fetchWorkshopIssues() async throws -> [WorkshopIssue] {
        let descriptor = FetchDescriptor<WorkshopIssue>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchWorkshopIssue(by id: String) async throws -> WorkshopIssue? {
        let descriptor = FetchDescriptor<WorkshopIssue>()
        let issues = try modelContext.fetch(descriptor)
        return issues.first { $0.id == id }
    }
    
    func addWorkshopIssue(_ issue: WorkshopIssue) async throws {
        modelContext.insert(issue)
        try modelContext.save()
    }
    
    func updateWorkshopIssue(_ issue: WorkshopIssue) async throws {
        try modelContext.save()
    }
    
    func deleteWorkshopIssue(_ issue: WorkshopIssue) async throws {
        modelContext.delete(issue)
        try modelContext.save()
    }
}