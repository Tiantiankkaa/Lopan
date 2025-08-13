//
//  WorkshopIntegrationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class WorkshopIntegrationService {
    private let repositoryFactory: RepositoryFactory
    private let authService: AuthenticationService
    private let auditService: NewAuditingService
    
    // Service instances
    private(set) var machineService: MachineService?
    private(set) var machineDataService: MachineDataInitializationService?
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
    }
    
    func initializeWorkshopServices() async {
        print("🔧 Initializing Workshop Manager services...")
        
        // Initialize machine service
        machineService = MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        
        // Initialize data initialization service
        machineDataService = MachineDataInitializationService(repositoryFactory: repositoryFactory)
        
        // Initialize sample data if needed
        await initializeSampleDataIfNeeded()
        
        print("✅ Workshop Manager services initialized successfully")
    }
    
    private func initializeSampleDataIfNeeded() async {
        guard let dataService = machineDataService else { return }
        
        do {
            let existingMachines = try await repositoryFactory.machineRepository.fetchAllMachines()
            let existingColors = try await repositoryFactory.colorRepository.fetchAllColors()
            
            if existingColors.isEmpty {
                print("🎨 No colors found, initializing sample colors...")
                await dataService.initializeSampleColors()
                print("✅ Sample color data initialized")
            } else {
                print("📋 Found \(existingColors.count) existing colors, skipping color initialization")
            }
            
            if existingMachines.isEmpty {
                print("📦 No machines found, initializing sample data...")
                await dataService.initializeSampleMachines()
                print("✅ Sample machine data initialized")
            } else {
                print("📋 Found \(existingMachines.count) existing machines, skipping machine initialization")
            }
        } catch {
            print("⚠️ Failed to check existing data: \(error)")
        }
    }
    
    // MARK: - Factory Methods
    func createMachineManagementView(showingAddMachine: Binding<Bool>) -> MachineManagementView? {
        return MachineManagementView(
            authService: authService,
            repositoryFactory: repositoryFactory,
            auditService: auditService,
            showingAddMachine: showingAddMachine
        )
    }
    
    func createMachineStatisticsView() -> MachineStatisticsView? {
        guard let machineService = machineService else {
            print("❌ MachineService not initialized")
            return nil
        }
        
        return MachineStatisticsView(machineService: machineService)
    }
    
    // MARK: - Development Utilities
    func resetAllMachineData() async {
        guard let dataService = machineDataService else { return }
        
        print("🗑️ Resetting all machine data...")
        await dataService.resetMachineData()
        
        // Reinitialize sample data
        await dataService.initializeSampleMachines()
        print("🔄 Machine data reset and reinitialized")
    }
    
    func printSystemStatus() async {
        print("\n=== Workshop Manager System Status ===")
        
        do {
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            print("📊 Total Machines: \(machines.count)")
            
            let activeMachines = machines.filter { $0.isActive }
            print("🟢 Active Machines: \(activeMachines.count)")
            
            let runningMachines = machines.filter { $0.status == .running }
            print("▶️ Running Machines: \(runningMachines.count)")
            
            // User permissions
            if let currentUser = authService.currentUser {
                print("👤 Current User: \(currentUser.name) (\(currentUser.effectiveRole.displayName))")
                print("🛡️ Can Manage: Administrator or WorkshopManager role")
            } else {
                print("❌ No user authenticated")
            }
            
        } catch {
            print("❌ Failed to get system status: \(error)")
        }
        
        print("=====================================\n")
    }
}