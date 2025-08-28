//
//  ProductionRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

public protocol ProductionRepository {
    // ProductionStyle operations
    func fetchProductionStyles() async throws -> [ProductionStyle]
    func fetchProductionStyle(by id: String) async throws -> ProductionStyle?
    func fetchProductionStyles(by status: StyleStatus) async throws -> [ProductionStyle]
    func addProductionStyle(_ style: ProductionStyle) async throws
    func updateProductionStyle(_ style: ProductionStyle) async throws
    func deleteProductionStyle(_ style: ProductionStyle) async throws
    
    // WorkshopProduction operations
    func fetchWorkshopProductions() async throws -> [WorkshopProduction]
    func fetchWorkshopProduction(by id: String) async throws -> WorkshopProduction?
    func addWorkshopProduction(_ production: WorkshopProduction) async throws
    func updateWorkshopProduction(_ production: WorkshopProduction) async throws
    func deleteWorkshopProduction(_ production: WorkshopProduction) async throws
    
    // EVAGranulation operations
    func fetchEVAGranulations() async throws -> [EVAGranulation]
    func fetchEVAGranulation(by id: String) async throws -> EVAGranulation?
    func addEVAGranulation(_ granulation: EVAGranulation) async throws
    func updateEVAGranulation(_ granulation: EVAGranulation) async throws
    func deleteEVAGranulation(_ granulation: EVAGranulation) async throws
    
    // WorkshopIssue operations
    func fetchWorkshopIssues() async throws -> [WorkshopIssue]
    func fetchWorkshopIssue(by id: String) async throws -> WorkshopIssue?
    func addWorkshopIssue(_ issue: WorkshopIssue) async throws
    func updateWorkshopIssue(_ issue: WorkshopIssue) async throws
    func deleteWorkshopIssue(_ issue: WorkshopIssue) async throws
}