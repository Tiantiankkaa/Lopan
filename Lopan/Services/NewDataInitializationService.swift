//
//  NewDataInitializationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
public class NewDataInitializationService {
    private let repositoryFactory: RepositoryFactory
    
    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
    
    func initializeSampleData() async {
        do {
            // Check if data already exists
            let existingCustomers = try await repositoryFactory.customerRepository.fetchCustomers()
            let existingProducts = try await repositoryFactory.productRepository.fetchProducts()
            let existingOutOfStock = try await repositoryFactory.customerOutOfStockRepository.fetchOutOfStockRecords()
            
            // Only initialize if no data exists
            if existingCustomers.isEmpty && existingProducts.isEmpty && existingOutOfStock.isEmpty {
                print("🔄 Initializing sample data...")
                
                // Initialize sample customers
                await initializeSampleCustomers()
                
                // Initialize sample products with multiple sizes
                await initializeSampleProducts()
                
                // Initialize sample out-of-stock records
                await initializeSampleOutOfStockRecords()
                
                // Initialize sample users with multiple roles
                await initializeSampleUsers()
                
                // Initialize sample production styles
                await initializeSampleProductionStyles()
                
                // Initialize sample packaging teams
                await initializeSamplePackagingTeams()
                
                // Initialize sample packaging records
                await initializeSamplePackagingRecords()
                
                // Initialize sample production batches
                await initializeSampleProductionBatches()
                
                print("✅ Sample data initialized successfully")
            } else {
                print("ℹ️ Sample data already exists, skipping initialization")
            }
        } catch {
            print("❌ Error checking existing data: \(error)")
        }
    }
    
    private func initializeSampleCustomers() async {
        let customers = [
            Customer(name: "张三", address: "北京市朝阳区建国路88号", phone: "13800138001"),
            Customer(name: "李四", address: "上海市浦东新区陆家嘴金融中心", phone: "13900139001"),
            Customer(name: "王五", address: "广州市天河区珠江新城", phone: "13700137001"),
            Customer(name: "赵六", address: "深圳市南山区科技园", phone: "13600136001"),
            Customer(name: "孙七", address: "杭州市西湖区文三路", phone: "13500135001")
        ]
        
        do {
            for customer in customers {
                try await repositoryFactory.customerRepository.addCustomer(customer)
            }
            print("✅ Initialized \(customers.count) sample customers")
        } catch {
            print("❌ Error creating customers: \(error)")
        }
    }
    
    private func initializeSampleProducts() async {
        print("🔄 Starting large-scale product generation (1000 products)...")

        let totalProducts = 1000
        let batchSize = 100

        // Define inventory status distribution
        // Active: 40% (400 products) - 10-100 units
        // Low Stock: 35% (350 products) - 1-9 units
        // Inactive: 25% (250 products) - 0 units
        let activeCount = 400
        let lowStockCount = 350
        let inactiveCount = 250

        // Create status array with proper distribution
        var statusDistribution: [String] = []
        statusDistribution.append(contentsOf: Array(repeating: "active", count: activeCount))
        statusDistribution.append(contentsOf: Array(repeating: "lowStock", count: lowStockCount))
        statusDistribution.append(contentsOf: Array(repeating: "inactive", count: inactiveCount))
        statusDistribution.shuffle()

        let sizes = ["S", "M", "L", "XL", "XXL", "XXXL"]

        do {
            for batchNumber in 0..<(totalProducts / batchSize) {
                let batchStart = batchNumber * batchSize
                let batchEnd = min(batchStart + batchSize, totalProducts)

                print("  📦 Generating batch \(batchNumber + 1)/\(totalProducts / batchSize) (Products \(batchStart + 1)-\(batchEnd))...")

                for index in batchStart..<batchEnd {
                    // Generate unique SKU and product name
                    let sku = LargeSampleDataGenerator.generateUniqueSKU(index: index)
                    let name = LargeSampleDataGenerator.generateProductName(index: index)
                    let price = LargeSampleDataGenerator.generateFixedPrice(for: name)

                    // Create product
                    let product = Product(sku: sku, name: name, imageData: nil, price: price)

                    // Add product to database
                    try await repositoryFactory.productRepository.addProduct(product)

                    // Determine inventory status for this product
                    let status = statusDistribution[index]

                    // Generate total inventory based on status
                    let totalInventory: Int
                    switch status {
                    case "active":
                        totalInventory = Int.random(in: 10...100)
                    case "lowStock":
                        totalInventory = Int.random(in: 1...9)
                    default: // inactive
                        totalInventory = 0
                    }

                    // Add sizes with distributed inventory
                    let sizeCount = Int.random(in: 3...6)
                    let productSizes = Array(sizes.prefix(sizeCount))

                    if totalInventory > 0 {
                        // Distribute inventory across sizes
                        var remainingInventory = totalInventory
                        for (i, sizeName) in productSizes.enumerated() {
                            let isLastSize = (i == productSizes.count - 1)
                            let quantity: Int

                            if isLastSize {
                                // Last size gets all remaining inventory
                                quantity = remainingInventory
                            } else {
                                // Distribute evenly with slight variation
                                let avgPerSize = remainingInventory / (productSizes.count - i)
                                let variation = max(1, avgPerSize / 3)
                                quantity = max(0, Int.random(in: (avgPerSize - variation)...(avgPerSize + variation)))
                            }

                            let size = ProductSize(size: sizeName, quantity: quantity, product: product)
                            if product.sizes == nil {
                                product.sizes = []
                            }
                            product.sizes?.append(size)
                            remainingInventory -= quantity

                            if remainingInventory <= 0 { break }
                        }
                    } else {
                        // Inactive product - all sizes have 0 inventory
                        for sizeName in productSizes {
                            let size = ProductSize(size: sizeName, quantity: 0, product: product)
                            if product.sizes == nil {
                                product.sizes = []
                            }
                            product.sizes?.append(size)
                        }
                    }

                    // Update cached inventory status based on sizes
                    product.updateCachedInventoryStatus()

                    // Update product with sizes
                    try await repositoryFactory.productRepository.updateProduct(product)
                }

                print("  ✅ Batch \(batchNumber + 1) complete (\(batchEnd - batchStart) products)")
            }

            print("✅ Successfully initialized \(totalProducts) products")
            print("  └─ Active: \(activeCount) products (10-100 units)")
            print("  └─ Low Stock: \(lowStockCount) products (1-9 units)")
            print("  └─ Inactive: \(inactiveCount) products (0 units)")
        } catch {
            print("❌ Error creating products: \(error)")
        }
    }
    
    private func initializeSampleOutOfStockRecords() async {
        do {
            // Get sample customers and products
            let customers = try await repositoryFactory.customerRepository.fetchCustomers()
            let products = try await repositoryFactory.productRepository.fetchProducts()
            
            guard !customers.isEmpty && !products.isEmpty else {
                print("⚠️ No customers or products available for out-of-stock records")
                return
            }
            
            let outOfStockRecords = [
                CustomerOutOfStock(
                    customer: customers[0],
                    product: products[0],
                    productSize: products[0].sizes?.first,
                    quantity: 50,
                    notes: "客户急需，请优先处理",
                    createdBy: "demo_user"
                ),
                CustomerOutOfStock(
                    customer: customers[1],
                    product: products[1],
                    productSize: products[1].sizes?.first,
                    quantity: 30,
                    notes: "常规补货",
                    createdBy: "demo_user"
                ),
                CustomerOutOfStock(
                    customer: customers[2],
                    product: products[2],
                    productSize: products[2].sizes?.first,
                    quantity: 20,
                    notes: "季节性需求",
                    createdBy: "demo_user"
                )
            ]
            
            for record in outOfStockRecords {
                try await repositoryFactory.customerOutOfStockRepository.addOutOfStockRecord(record)
            }
            
            print("✅ Initialized \(outOfStockRecords.count) sample out-of-stock records")
        } catch {
            print("❌ Error creating out-of-stock records: \(error)")
        }
    }
    
    private func initializeSampleUsers() async {
        do {
            // Check if users already exist
            let existingUsers = try await repositoryFactory.userRepository.fetchUsers()
            
            if existingUsers.isEmpty {
                // Create sample users with different role combinations
                let sampleUsers: [(wechatId: String, name: String, roles: [UserRole], primaryRole: UserRole)] = [
                    // Administrator - has default access to all workbenches
                    (wechatId: "admin_001", name: "系统管理员", roles: [.administrator], primaryRole: .administrator),
                    
                    // Sales manager with multiple roles
                    (wechatId: "sales_manager_001", name: "销售经理", roles: [.salesperson, .warehouseKeeper], primaryRole: .salesperson),
                    
                    // Workshop supervisor with multiple roles
                    (wechatId: "workshop_supervisor_001", name: "车间主管", roles: [.workshopManager, .workshopTechnician], primaryRole: .workshopManager),
                    
                    // Warehouse manager with EVA access
                    (wechatId: "warehouse_manager_001", name: "仓库主管", roles: [.warehouseKeeper, .evaGranulationTechnician], primaryRole: .warehouseKeeper),
                    
                    // Single role specialist
                    (wechatId: "eva_specialist_001", name: "EVA技术员", roles: [.evaGranulationTechnician], primaryRole: .evaGranulationTechnician),
                    
                    // Multi-skilled technician
                    (wechatId: "technician_001", name: "多技能技术员", roles: [.workshopTechnician, .evaGranulationTechnician, .warehouseKeeper], primaryRole: .workshopTechnician),
                    
                    // Another administrator for testing
                    (wechatId: "admin_002", name: "副管理员", roles: [.administrator], primaryRole: .administrator)
                ]
                
                for userData in sampleUsers {
                    let user = User(wechatId: userData.wechatId, name: userData.name)
                    user.roles = userData.roles
                    user.primaryRole = userData.primaryRole
                    try await repositoryFactory.userRepository.addUser(user)
                }
                
                print("✅ Initialized \(sampleUsers.count) sample users with role assignments")
            }
        } catch {
            print("❌ Error creating sample users: \(error)")
        }
    }
    
    private func initializeSampleProductionStyles() async {
        do {
            // Create sample production styles with predefined colors
            // Note: ProductionStyle still uses colors for manufacturing tracking
            let productionStyles = [
                ProductionStyle(styleCode: "PRD-000001-W", styleName: "Classic White T-Shirt", color: "White", size: "M", quantity: 100, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000001-B", styleName: "Classic White T-Shirt", color: "Black", size: "L", quantity: 150, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000025-DB", styleName: "Slim Fit Jeans", color: "Dark Blue", size: "32", quantity: 80, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000025-LB", styleName: "Slim Fit Jeans", color: "Light Blue", size: "34", quantity: 90, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000029-G", styleName: "Hooded Sweatshirt", color: "Gray", size: "XL", quantity: 60, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000029-B", styleName: "Hooded Sweatshirt", color: "Black", size: "L", quantity: 70, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000041-R", styleName: "Little Black Dress", color: "Red", size: "S", quantity: 40, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "PRD-000057-W", styleName: "Running Shoes", color: "White", size: "40", quantity: 50, productionDate: Date(), createdBy: "admin_001")
            ]

            for style in productionStyles {
                try await repositoryFactory.productionRepository.addProductionStyle(style)
            }

            print("✅ Initialized \(productionStyles.count) sample production styles")
        } catch {
            print("❌ Error creating production styles: \(error)")
        }
    }
    
    private func initializeSamplePackagingTeams() async {
        do {
            let products = try await repositoryFactory.productRepository.fetchProducts()
            
            // Get product IDs for team specializations
            let tshirtId = products.first { $0.name.contains("T恤") }?.id ?? ""
            let hoodieId = products.first { $0.name.contains("卫衣") }?.id ?? ""
            let jeansId = products.first { $0.name.contains("牛仔裤") }?.id ?? ""
            let dressId = products.first { $0.name.contains("连衣裙") }?.id ?? ""
            let shoesId = products.first { $0.name.contains("运动鞋") }?.id ?? ""
            
            let packagingTeams = [
                PackagingTeam(
                    teamName: "A组包装团队",
                    teamLeader: "张队长",
                    members: ["小王", "小李", "小陈"],
                    specializedStyles: [tshirtId, hoodieId].filter { !$0.isEmpty }
                ),
                PackagingTeam(
                    teamName: "B组包装团队",
                    teamLeader: "刘队长",
                    members: ["小赵", "小孙", "小周", "小吴"],
                    specializedStyles: [jeansId, dressId].filter { !$0.isEmpty }
                ),
                PackagingTeam(
                    teamName: "C组包装团队",
                    teamLeader: "王队长",
                    members: ["小徐", "小马"],
                    specializedStyles: [shoesId].filter { !$0.isEmpty }
                )
            ]
            
            for team in packagingTeams {
                try await repositoryFactory.packagingRepository.addPackagingTeam(team)
            }
            
            print("✅ Initialized \(packagingTeams.count) sample packaging teams with actual product IDs")
        } catch {
            print("❌ Error creating packaging teams: \(error)")
        }
    }
    
    private func initializeSamplePackagingRecords() async {
        do {
            let teams = try await repositoryFactory.packagingRepository.fetchPackagingTeams()
            let products = try await repositoryFactory.productRepository.fetchProducts()
            
            guard !teams.isEmpty && !products.isEmpty else {
                print("⚠️ No packaging teams or products available for packaging records")
                return
            }
            
            let calendar = Calendar.current
            let today = Date()
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today
            
            // Get products by name for consistency
            let tshirtProduct = products.first { $0.name.contains("T恤") }
            let jeansProduct = products.first { $0.name.contains("牛仔裤") }
            let hoodieProduct = products.first { $0.name.contains("卫衣") }
            let dressProduct = products.first { $0.name.contains("连衣裙") }
            let shoesProduct = products.first { $0.name.contains("运动鞋") }
            
            var packagingRecords: [PackagingRecord] = []
            
            // Today's records
            if let tshirt = tshirtProduct {
                packagingRecords.append(PackagingRecord(
                    packageDate: today,
                    teamId: teams[0].id,
                    teamName: teams[0].teamName,
                    styleCode: tshirt.id, // Use product ID
                    styleName: tshirt.name,
                    totalPackages: 10,
                    stylesPerPackage: 5,
                    notes: "今日常规包装",
                    dueDate: tomorrow,
                    priority: .high,
                    reminderEnabled: true,
                    createdBy: "warehouse_manager_001"
                ))
            }
            
            if let jeans = jeansProduct, teams.count > 1 {
                packagingRecords.append(PackagingRecord(
                    packageDate: today,
                    teamId: teams[1].id,
                    teamName: teams[1].teamName,
                    styleCode: jeans.id, // Use product ID
                    styleName: jeans.name,
                    totalPackages: 8,
                    stylesPerPackage: 3,
                    notes: "新款式包装",
                    dueDate: dayAfterTomorrow,
                    priority: .medium,
                    reminderEnabled: true,
                    createdBy: "warehouse_manager_001"
                ))
            }
            
            // Yesterday's records with overdue tasks
            if let hoodie = hoodieProduct {
                packagingRecords.append(PackagingRecord(
                    packageDate: yesterday,
                    teamId: teams[0].id,
                    teamName: teams[0].teamName,
                    styleCode: hoodie.id, // Use product ID
                    styleName: hoodie.name,
                    totalPackages: 12,
                    stylesPerPackage: 4,
                    notes: "昨日生产完成",
                    dueDate: yesterday, // Overdue
                    priority: .urgent,
                    reminderEnabled: true,
                    createdBy: "warehouse_manager_001"
                ))
            }
            
            if let shoes = shoesProduct, teams.count > 2 {
                packagingRecords.append(PackagingRecord(
                    packageDate: yesterday,
                    teamId: teams[2].id,
                    teamName: teams[2].teamName,
                    styleCode: shoes.id, // Use product ID
                    styleName: shoes.name,
                    totalPackages: 6,
                    stylesPerPackage: 2,
                    notes: "精细包装",
                    dueDate: today,
                    priority: .high,
                    reminderEnabled: true,
                    createdBy: "warehouse_manager_001"
                ))
            }
            
            // Two days ago records - completed
            if let dress = dressProduct, teams.count > 1 {
                let completedRecord = PackagingRecord(
                    packageDate: twoDaysAgo,
                    teamId: teams[1].id,
                    teamName: teams[1].teamName,
                    styleCode: dress.id, // Use product ID
                    styleName: dress.name,
                    totalPackages: 15,
                    stylesPerPackage: 1,
                    notes: "高档包装",
                    dueDate: yesterday,
                    priority: .low,
                    reminderEnabled: false,
                    createdBy: "warehouse_manager_001"
                )
                completedRecord.status = .completed
                packagingRecords.append(completedRecord)
            }
            
            for record in packagingRecords {
                try await repositoryFactory.packagingRepository.addPackagingRecord(record)
            }
            
            print("✅ Initialized \(packagingRecords.count) sample packaging records with actual product IDs")
        } catch {
            print("❌ Error creating packaging records: \(error)")
        }
    }
    
    private func initializeSampleProductionBatches() async {
        do {
            // Check if we have machines and colors for creating batches
            let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
            let colors = try await repositoryFactory.colorRepository.fetchActiveColors()
            let users = try await repositoryFactory.userRepository.fetchUsers()
            
            guard !machines.isEmpty && !colors.isEmpty && !users.isEmpty else {
                print("⚠️ Missing machines, colors, or users for production batches")
                return
            }
            
            // Find workshop manager or admin users
            let workshopUsers = users.filter { $0.hasRole(.workshopManager) || $0.hasRole(.administrator) }
            guard !workshopUsers.isEmpty else {
                print("⚠️ No workshop manager or admin users found")
                return
            }
            
            let submittingUser = workshopUsers.first!
            let machine = machines.first!
            let primaryColor = colors.first!
            let secondaryColor = colors.count > 1 ? colors[1] : nil
            
            // Create a completed batch to demonstrate auto-completion features
            let completedBatch = ProductionBatch(
                machineId: machine.id,
                mode: .singleColor,
                submittedBy: submittingUser.id,
                submittedByName: submittingUser.name,
                batchNumber: "PC-20250814-0001"
            )
            
            // Set as system auto-completed
            completedBatch.status = .completed
            completedBatch.completedAt = Date()
            completedBatch.isSystemAutoCompleted = true
            completedBatch.reviewedAt = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
            completedBatch.reviewedBy = submittingUser.id
            completedBatch.reviewedByName = submittingUser.name
            
            // Add some product configurations
            let product1 = ProductConfig(
                batchId: completedBatch.id,
                productName: "运动鞋 A款",
                primaryColorId: primaryColor.id,
                occupiedStations: [1, 2, 3]
            )
            
            let product2 = ProductConfig(
                batchId: completedBatch.id,
                productName: "运动鞋 B款",
                primaryColorId: primaryColor.id,
                occupiedStations: [7, 8, 9]
            )
            
            completedBatch.products = [product1, product2]
            
            // Create an approved PC (Production Config) batch for testing
            let approvedBatch = ProductionBatch(
                machineId: machine.id,
                mode: .dualColor,
                submittedBy: submittingUser.id,
                submittedByName: submittingUser.name,
                batchNumber: "PC-20250814-0002"
            )
            approvedBatch.status = BatchStatus.approved
            approvedBatch.reviewedAt = Date()
            approvedBatch.reviewedBy = submittingUser.id
            approvedBatch.reviewedByName = submittingUser.name
            
            if let secondaryColor = secondaryColor {
                let dualColorProduct = ProductConfig(
                    batchId: approvedBatch.id,
                    productName: "双色测试产品",
                    primaryColorId: primaryColor.id,
                    occupiedStations: [7, 8, 9, 10, 11, 12],
                    secondaryColorId: secondaryColor.id
                )
                approvedBatch.products = [dualColorProduct]
            }
            
            // Add batches to repository
            try await repositoryFactory.productionBatchRepository.addBatch(completedBatch)
            try await repositoryFactory.productionBatchRepository.addBatch(approvedBatch)
            
            print("✅ Initialized 2 sample PC (Production Config) batches (1 completed, 1 approved)")
        } catch {
            print("❌ Error creating production batches: \(error)")
        }
    }
}