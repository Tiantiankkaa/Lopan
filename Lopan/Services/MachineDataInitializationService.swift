//
//  MachineDataInitializationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
public class MachineDataInitializationService {
    private let repositoryFactory: RepositoryFactory
    
    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
    
    func initializeAllSampleData() async {
        await initializeSampleColors()
        await initializeSampleMachines()
        await initializeSampleBatches()
    }
    
    func initializeSampleMachines() async {
        do {
            // Check if machines already exist
            let existingMachines = try await repositoryFactory.machineRepository.fetchAllMachines()
            if !existingMachines.isEmpty {
                print("Machines already exist, skipping initialization")
                return
            }
            
            print("Initializing sample machines...")
            
            // Create sample machines
            let machines = createSampleMachines()
            
            // Add machines to repository
            for machine in machines {
                try await repositoryFactory.machineRepository.addMachine(machine)
            }
            
            print("Successfully initialized \(machines.count) sample machines")
            
            // Now update gun properties after machines and guns are created
            await updateGunProperties()
            
        } catch {
            print("Failed to initialize sample machines: \(error)")
        }
    }
    
    private func createSampleMachines() -> [WorkshopMachine] {
        var machines: [WorkshopMachine] = []
        
        // Machine 1 - Running smoothly
        let machine1 = WorkshopMachine(machineNumber: 1, createdBy: "system")
        machine1.status = .running
        machine1.dailyTarget = 1200
        machine1.currentProductionCount = 856
        machine1.utilizationRate = 0.92
        machine1.totalRunHours = 2840.5
        machine1.errorCount = 0
        machine1.notes = "主力生产设备，运行状态良好"
        machine1.lastMaintenanceDate = Calendar.current.date(byAdding: .day, value: -15, to: Date())
        machine1.nextMaintenanceDate = Calendar.current.date(byAdding: .day, value: 15, to: Date())
        
        // Set some stations to running
        let runningStations1 = [1, 2, 3, 7, 8, 9, 10]
        for station in machine1.stations {
            if runningStations1.contains(station.stationNumber) {
                station.status = .running
                station.currentProductId = "product_a"
                station.lastProductionTime = Date()
                station.totalProductionCount = Int.random(in: 200...500)
            }
        }
        
        // Gun properties will be set after machine is created in repository
        // (guns are created in LocalMachineRepository.addMachine)
        
        machines.append(machine1)
        
        // Machine 2 - Recently stopped
        let machine2 = WorkshopMachine(machineNumber: 2, createdBy: "system")
        machine2.status = .stopped
        machine2.dailyTarget = 1000
        machine2.currentProductionCount = 0
        machine2.utilizationRate = 0.0
        machine2.totalRunHours = 1920.2
        machine2.errorCount = 0
        machine2.notes = "等待新订单"
        machine2.lastMaintenanceDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())
        machine2.nextMaintenanceDate = Calendar.current.date(byAdding: .day, value: 22, to: Date())
        
        // All stations idle
        for station in machine2.stations {
            station.status = .idle
            station.totalProductionCount = Int.random(in: 150...350)
        }
        
        // Gun properties will be set after machine is created in repository
        
        machines.append(machine2)
        
        // Machine 3 - Under maintenance
        let machine3 = WorkshopMachine(machineNumber: 3, createdBy: "system")
        machine3.status = .maintenance
        machine3.dailyTarget = 1100
        machine3.currentProductionCount = 0
        machine3.utilizationRate = 0.0
        machine3.totalRunHours = 3150.8
        machine3.errorCount = 2
        machine3.notes = "例行维护检查中"
        machine3.lastMaintenanceDate = Date() // Currently under maintenance
        machine3.nextMaintenanceDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        
        // Some stations under maintenance
        let maintenanceStations = [4, 5, 6, 11, 12]
        for station in machine3.stations {
            if maintenanceStations.contains(station.stationNumber) {
                station.status = .maintenance
            } else {
                station.status = .idle
            }
            station.totalProductionCount = Int.random(in: 300...600)
        }
        
        // Gun properties will be set after machine is created in repository
        
        machines.append(machine3)
        
        return machines
    }
    
    private func updateGunProperties() async {
        do {
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            
            for machine in machines {
                guard machine.guns.count >= 2 else { continue }
                
                switch machine.machineNumber {
                case 1:
                    if let gunA = machine.guns.first(where: { $0.name == "Gun A" }) {
                        gunA.totalShotCount = 15420
                    }
                    if let gunB = machine.guns.first(where: { $0.name == "Gun B" }) {
                        gunB.totalShotCount = 12890
                    }
                case 2:
                    if let gunA = machine.guns.first(where: { $0.name == "Gun A" }) {
                        gunA.totalShotCount = 8950
                    }
                    if let gunB = machine.guns.first(where: { $0.name == "Gun B" }) {
                        gunB.totalShotCount = 9240
                    }
                case 3:
                    if let gunA = machine.guns.first(where: { $0.name == "Gun A" }) {
                        gunA.totalShotCount = 22100
                    }
                    if let gunB = machine.guns.first(where: { $0.name == "Gun B" }) {
                        gunB.totalShotCount = 19850
                    }
                default:
                    break
                }
                
                try await repositoryFactory.machineRepository.updateMachine(machine)
            }
            
            print("Successfully updated gun properties")
        } catch {
            print("Failed to update gun properties: \(error)")
        }
    }
    
    // MARK: - Color Cards Initialization
    func initializeSampleColors() async {
        do {
            let existingColors = try await repositoryFactory.colorRepository.fetchAllColors()
            if !existingColors.isEmpty {
                print("Colors already exist, skipping initialization")
                return
            }
            
            print("Initializing sample color cards...")
            
            let colors = createSampleColors()
            
            for color in colors {
                try await repositoryFactory.colorRepository.addColor(color)
            }
            
            print("Successfully initialized \(colors.count) sample color cards")
            
        } catch {
            print("Failed to initialize sample colors: \(error)")
        }
    }
    
    private func createSampleColors() -> [ColorCard] {
        let colorData = [
            ("红色", "FF0000"),      // Red
            ("蓝色", "0066FF"),      // Blue
            ("绿色", "00CC66"),      // Green
            ("黄色", "FFCC00"),      // Yellow
            ("紫色", "9966CC"),      // Purple
            ("橙色", "FF6600"),      // Orange
            ("粉色", "FF66CC"),      // Pink
            ("青色", "00CCCC"),      // Cyan
            ("深灰", "666666"),      // Dark Gray
            ("浅灰", "CCCCCC"),      // Light Gray
            ("棕色", "996633"),      // Brown
            ("深蓝", "003366")       // Dark Blue
        ]
        
        return colorData.map { name, hex in
            ColorCard(name: name, hexCode: hex, createdBy: "system")
        }
    }
    
    // MARK: - Production Batches Initialization
    func initializeSampleBatches() async {
        do {
            let existingBatches = try await repositoryFactory.productionBatchRepository.fetchAllBatches()
            if !existingBatches.isEmpty {
                print("Batches already exist, skipping initialization")
                return
            }
            
            print("Initializing sample production batches...")
            
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            let colors = try await repositoryFactory.colorRepository.fetchActiveColors()
            
            guard !machines.isEmpty, !colors.isEmpty else {
                print("Cannot create sample batches without machines and colors")
                return
            }
            
            let batches = createSampleBatches(machines: machines, colors: colors)
            
            for batch in batches {
                try await repositoryFactory.productionBatchRepository.addBatch(batch)
            }
            
            print("Successfully initialized \(batches.count) sample production batches (1 pending execution, 1 pending review, 1 rejected, 1 manually completed)")
            
        } catch {
            print("Failed to initialize sample batches: \(error)")
        }
    }
    
    private func createSampleBatches(machines: [WorkshopMachine], colors: [ColorCard]) -> [ProductionBatch] {
        var batches: [ProductionBatch] = []
        
        guard let machine1 = machines.first(where: { $0.machineNumber == 1 }),
              let machine2 = machines.first(where: { $0.machineNumber == 2 }),
              colors.count >= 4 else {
            return []
        }
        
        // Get current date and create batch numbers with today's date
        let today = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let todayString = formatter.string(from: today)
        
        // Get yesterday for varied sample data
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayString = formatter.string(from: yesterday)
        
        // Batch 1 - Today's morning shift, Pending Execution
        let batch1 = ProductionBatch(
            machineId: machine1.id,
            mode: .singleColor,
            submittedBy: "manager1",
            submittedByName: "张经理",
            batchNumber: "PC-\(todayString)-0001",
            targetDate: today,
            shift: .morning
        )
        batch1.status = BatchStatus.pendingExecution
        batch1.reviewedAt = Calendar.current.date(byAdding: .hour, value: -2, to: Date())
        batch1.reviewedBy = "admin1"
        batch1.reviewedByName = "李管理员"
        batch1.appliedAt = Calendar.current.date(byAdding: .hour, value: -1, to: Date())
        
        let product1 = ProductConfig(
            batchId: batch1.id,
            productName: "运动鞋 A款",
            primaryColorId: colors[0].id, // Red
            occupiedStations: [1, 2, 3]
        )
        
        let product2 = ProductConfig(
            batchId: batch1.id,
            productName: "运动鞋 B款",
            primaryColorId: colors[1].id, // Blue
            occupiedStations: [7, 8, 9]
        )
        
        batch1.products = [product1, product2]
        batches.append(batch1)
        
        // Batch 2 - Today's evening shift, Pending review (dual color)
        let batch2 = ProductionBatch(
            machineId: machine2.id,
            mode: .dualColor,
            submittedBy: "manager2",
            submittedByName: "王经理",
            batchNumber: "PC-\(todayString)-0002",
            targetDate: today,
            shift: .morning
        )
        batch2.status = BatchStatus.completed
        
        let product3 = ProductConfig(
            batchId: batch2.id,
            productName: "篮球鞋限量版",
            primaryColorId: colors[0].id, // Red
            occupiedStations: [1, 2, 3, 7, 8, 9],
            secondaryColorId: colors[3].id // Yellow
        )
        
        batch2.products = [product3]
        batches.append(batch2)
        
        // Batch 3 - Yesterday's morning shift, Rejected
        let batch3 = ProductionBatch(
            machineId: machine2.id,
            mode: .singleColor,
            submittedBy: "manager1",
            submittedByName: "张经理",
            batchNumber: "PC-\(yesterdayString)-0001",
            targetDate: yesterday,
            shift: .morning
        )
        batch3.status = BatchStatus.rejected
        batch3.reviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        batch3.reviewedBy = "admin1"
        batch3.reviewedByName = "李管理员"
        batch3.reviewNotes = "工位分配不合理，请重新配置"
        
        let product4 = ProductConfig(
            batchId: batch3.id,
            productName: "跑步鞋",
            primaryColorId: colors[2].id, // Green
            occupiedStations: [1, 2, 3] // Too few stations - reason for rejection
        )
        
        batch3.products = [product4]
        batches.append(batch3)
        
        // Batch 4 - Yesterday's evening shift, Manually completed
        let batch4 = ProductionBatch(
            machineId: machine1.id,
            mode: .singleColor,
            submittedBy: "manager2",
            submittedByName: "王经理",
            batchNumber: "PC-\(yesterdayString)-0002",
            targetDate: yesterday,
            shift: .evening
        )
        batch4.status = BatchStatus.completed
        batch4.reviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        batch4.reviewedBy = "admin1"
        batch4.reviewedByName = "李管理员"
        batch4.appliedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        
        // Set manual execution times (user manually started and completed)
        var components = calendar.dateComponents([.year, .month, .day], from: yesterday)
        components.hour = 19
        components.minute = 0
        components.second = 0
        let yesterdayEvening = calendar.date(from: components) ?? yesterday
        
        // Evening shift ends at 07:00 next day
        let nextDay = calendar.date(byAdding: .day, value: 1, to: yesterday) ?? yesterday
        var nextDayComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
        nextDayComponents.hour = 7
        nextDayComponents.minute = 0
        nextDayComponents.second = 0
        let completionTime = calendar.date(from: nextDayComponents) ?? nextDay
        batch4.executionTime = yesterdayEvening
        batch4.completedAt = completionTime
        batch4.isSystemAutoCompleted = false // Mark as manually completed
        
        let product5 = ProductConfig(
            batchId: batch4.id,
            productName: "限量版跑鞋",
            primaryColorId: colors[0].id, // Red
            occupiedStations: [4, 5, 6, 10, 11, 12]
        )
        
        batch4.products = [product5]
        batches.append(batch4)
        
        // Create an active batch for current testing (to ensure machine has running configuration)
        let activeBatch = ProductionBatch(
            machineId: machines[0].id,
            mode: .singleColor,
            submittedBy: "manager1",
            submittedByName: "张经理",
            batchNumber: "PC-\(todayString)-0003",
            targetDate: today,
            shift: getCurrentShift()
        )
        activeBatch.status = .active
        activeBatch.reviewedAt = Date()
        activeBatch.reviewedBy = "admin1"
        activeBatch.reviewedByName = "李管理员"
        activeBatch.appliedAt = Date()
        activeBatch.executionTime = Date()
        
        let activeProduct = ProductConfig(
            batchId: activeBatch.id,
            productName: "夹克",
            primaryColorId: colors[0].id,
            occupiedStations: [1, 2, 3, 4, 5, 6]
        )
        
        activeBatch.products = [activeProduct]
        batches.append(activeBatch)
        
        return batches
    }
    
    // MARK: - Gun Color Assignment
    func assignColorsToGuns() async {
        do {
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            let colors = try await repositoryFactory.colorRepository.fetchActiveColors()
            
            guard let redColor = colors.first(where: { $0.name.contains("红") }),
                  let blueColor = colors.first(where: { $0.name.contains("蓝") }) else {
                print("Required colors not found for gun assignment")
                return
            }
            
            for machine in machines {
                if machine.machineNumber == 1 && machine.guns.count >= 2 {
                    // Assign colors to Machine 1 guns (check array bounds first)
                    if let gunA = machine.guns.first(where: { $0.name == "Gun A" }) {
                        gunA.assignColor(redColor)
                    }
                    if let gunB = machine.guns.first(where: { $0.name == "Gun B" }) {
                        gunB.assignColor(blueColor)
                    }
                    
                    try await repositoryFactory.machineRepository.updateMachine(machine)
                }
            }
            
            print("Successfully assigned colors to guns")
            
        } catch {
            print("Failed to assign colors to guns: \(error)")
        }
    }
    
    // Helper method to reset all data (for development only)
    func resetAllData() async {
        do {
            // Reset batches first (due to relationships)
            let batches = try await repositoryFactory.productionBatchRepository.fetchAllBatches()
            for batch in batches {
                try await repositoryFactory.productionBatchRepository.deleteBatch(batch)
            }
            
            // Reset machines
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            for machine in machines {
                try await repositoryFactory.machineRepository.deleteMachine(machine)
            }
            
            // Reset colors
            let colors = try await repositoryFactory.colorRepository.fetchAllColors()
            for color in colors {
                try await repositoryFactory.colorRepository.deleteColor(color)
            }
            
            print("All workshop data has been reset")
        } catch {
            print("Failed to reset workshop data: \(error)")
        }
    }
    
    // Helper method to reset machine data only (for development only)
    func resetMachineData() async {
        do {
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            for machine in machines {
                try await repositoryFactory.machineRepository.deleteMachine(machine)
            }
            print("All machine data has been reset")
        } catch {
            print("Failed to reset machine data: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentShift() -> Shift {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? .morning : .evening
    }
}
