//
//  DataInitializationService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

class DataInitializationService {
    static func initializeSampleData(modelContext: ModelContext) {
        // Check if data already exists
        do {
            let customerDescriptor = FetchDescriptor<Customer>()
            let productDescriptor = FetchDescriptor<Product>()
            let outOfStockDescriptor = FetchDescriptor<CustomerOutOfStock>()
            
            let existingCustomers = try modelContext.fetch(customerDescriptor)
            let existingProducts = try modelContext.fetch(productDescriptor)
            let existingOutOfStock = try modelContext.fetch(outOfStockDescriptor)
            
            // Only initialize if no data exists
            if existingCustomers.isEmpty && existingProducts.isEmpty && existingOutOfStock.isEmpty {
                print("🔄 Initializing sample data...")
                
                // Initialize sample customers
                initializeSampleCustomers(modelContext: modelContext)
                
                // Initialize sample products with multiple sizes
                initializeSampleProducts(modelContext: modelContext)
                
                // Initialize sample out-of-stock records
                initializeSampleOutOfStockRecords(modelContext: modelContext)
                
                // Initialize sample users with multiple roles
                initializeSampleUsers(modelContext: modelContext)
                
                // Initialize sample production styles
                initializeSampleProductionStyles(modelContext: modelContext)
                
                // Initialize sample packaging teams
                initializeSamplePackagingTeams(modelContext: modelContext)
                
                // Initialize sample packaging records
                initializeSamplePackagingRecords(modelContext: modelContext)
                
                try modelContext.save()
                print("✅ Sample data initialized successfully")
            } else {
                print("ℹ️ Sample data already exists, skipping initialization")
            }
        } catch {
            print("❌ Error checking existing data: \(error)")
            // If there's an error, try to clear and reinitialize
            print("🔄 Attempting to clear and reinitialize data...")
            clearAllData(modelContext: modelContext)
            initializeSampleData(modelContext: modelContext)
        }
    }
    
    static func clearAllData(modelContext: ModelContext) {
        do {
            // Clear all data
            try modelContext.delete(model: PackagingRecord.self)
            try modelContext.delete(model: PackagingTeam.self)
            try modelContext.delete(model: ProductionStyle.self)
            try modelContext.delete(model: CustomerOutOfStock.self)
            try modelContext.delete(model: ProductSize.self)
            try modelContext.delete(model: Product.self)
            try modelContext.delete(model: Customer.self)
            try modelContext.delete(model: User.self)
            try modelContext.save()
            print("✅ All data cleared successfully")
        } catch {
            print("❌ Error clearing data: \(error)")
        }
    }
    
    private static func initializeSampleCustomers(modelContext: ModelContext) {
        let customers = [
            Customer(name: "张三", address: "北京市朝阳区建国路88号", phone: "13800138001"),
            Customer(name: "李四", address: "上海市浦东新区陆家嘴金融中心", phone: "13900139001"),
            Customer(name: "王五", address: "广州市天河区珠江新城", phone: "13700137001"),
            Customer(name: "赵六", address: "深圳市南山区科技园", phone: "13600136001"),
            Customer(name: "孙七", address: "杭州市西湖区文三路", phone: "13500135001")
        ]
        
        for customer in customers {
            modelContext.insert(customer)
        }
        
        print("✅ Initialized \(customers.count) sample customers")
    }
    
    private static func initializeSampleProducts(modelContext: ModelContext) {
        let products = [
            // T-Shirt with multiple colors
            Product(name: "经典圆领T恤", colors: ["白色", "黑色", "蓝色"], imageData: nil),
            
            // Jeans with multiple colors
            Product(name: "直筒牛仔裤", colors: ["深蓝色", "浅蓝色", "黑色"], imageData: nil),
            
            // Hoodie with multiple colors
            Product(name: "连帽卫衣", colors: ["灰色", "黑色", "深蓝色"], imageData: nil),
            
            // Dress with multiple colors
            Product(name: "连衣裙", colors: ["红色", "粉色", "白色"], imageData: nil),
            
            // Shoes with multiple colors
            Product(name: "运动鞋", colors: ["白色", "黑色", "灰色"], imageData: nil),
            
            // Polo shirt with multiple colors
            Product(name: "Polo衫", colors: ["白色", "蓝色", "红色"], imageData: nil),
            
            // Sweater with multiple colors
            Product(name: "毛衣", colors: ["米色", "棕色", "黑色"], imageData: nil),
            
            // Jacket with multiple colors
            Product(name: "夹克", colors: ["黑色", "深蓝色", "军绿色"], imageData: nil),
            
            // Shorts with multiple colors
            Product(name: "短裤", colors: ["黑色", "灰色", "深蓝色"], imageData: nil),
            
            // Skirt with multiple colors
            Product(name: "半身裙", colors: ["黑色", "白色", "格子"], imageData: nil)
        ]
        
        // Add sizes to each product
        let sizes = ["XS", "S", "M", "L", "XL", "XXL"]
        let shoeSizes = ["36", "37", "38", "39", "40", "41", "42", "43", "44"]
        
        for product in products {
            modelContext.insert(product)
            
            // Add appropriate sizes based on product type
            let productSizes: [String]
            if product.name.contains("鞋") {
                productSizes = shoeSizes
            } else {
                productSizes = sizes
            }
            
            for sizeName in productSizes {
                let size = ProductSize(size: sizeName, product: product)
                modelContext.insert(size)
                
                if product.sizes == nil {
                    product.sizes = []
                }
                product.sizes?.append(size)
            }
        }
        
        print("✅ Initialized \(products.count) sample products with sizes")
    }
    
    private static func initializeSampleOutOfStockRecords(modelContext: ModelContext) {
        // Get sample customers and products
        do {
            let customerDescriptor = FetchDescriptor<Customer>()
            let productDescriptor = FetchDescriptor<Product>()
            
            let customers = try modelContext.fetch(customerDescriptor)
            let products = try modelContext.fetch(productDescriptor)
            
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
                    priority: .high,
                    notes: "客户急需，请优先处理",
                    createdBy: "demo_user"
                ),
                CustomerOutOfStock(
                    customer: customers[1],
                    product: products[1],
                    productSize: products[1].sizes?.first,
                    quantity: 30,
                    priority: .medium,
                    notes: "常规补货",
                    createdBy: "demo_user"
                ),
                CustomerOutOfStock(
                    customer: customers[2],
                    product: products[2],
                    productSize: products[2].sizes?.first,
                    quantity: 20,
                    priority: .low,
                    notes: "季节性需求",
                    createdBy: "demo_user"
                )
            ]
            
            for record in outOfStockRecords {
                modelContext.insert(record)
            }
            
            print("✅ Initialized \(outOfStockRecords.count) sample out-of-stock records")
        } catch {
            print("❌ Error creating out-of-stock records: \(error)")
        }
    }
    
    private static func initializeSampleUsers(modelContext: ModelContext) {
        do {
            // Check if users already exist
            let userDescriptor = FetchDescriptor<User>()
            let existingUsers = try modelContext.fetch(userDescriptor)
            
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
                    modelContext.insert(user)
                }
                
                print("✅ Initialized \(sampleUsers.count) sample users with role assignments")
            }
        } catch {
            print("❌ Error creating sample users: \(error)")
        }
    }
    
    private static func initializeSampleProductionStyles(modelContext: ModelContext) {
        do {
            let productDescriptor = FetchDescriptor<Product>()
            let products = try modelContext.fetch(productDescriptor)
            
            guard !products.isEmpty else {
                print("⚠️ No products available for production styles")
                return
            }
            
            var productionStyles: [ProductionStyle] = []
            
            // Create production styles from existing products
            for product in products.prefix(5) { // Use first 5 products
                guard let sizes = product.sizes, !sizes.isEmpty,
                      !product.colors.isEmpty else { continue }
                
                // Create 1-2 styles per product with different colors and sizes
                let numStyles = Int.random(in: 1...2)
                
                for i in 0..<numStyles {
                    let randomColor = product.colors.randomElement() ?? "默认色"
                    let randomSize = sizes.randomElement()!
                    let quantity = Int.random(in: 50...200)
                    
                    let style = ProductionStyle.fromProduct(
                        product,
                        size: randomSize,
                        color: randomColor,
                        quantity: quantity,
                        productionDate: Date(),
                        createdBy: "admin_001"
                    )
                    
                    // Set random status for variety
                    switch i {
                    case 0:
                        style.status = .inProduction
                    case 1:
                        style.status = .completed
                    default:
                        style.status = .planning
                    }
                    
                    productionStyles.append(style)
                }
            }
            
            // Add some manual styles for consistency with packaging records
            let manualStyles = [
                ProductionStyle(styleCode: "TS001", styleName: "经典圆领T恤", color: "白色", size: "M", quantity: 100, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "TS002", styleName: "经典圆领T恤", color: "黑色", size: "L", quantity: 150, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "JS001", styleName: "直筒牛仔裤", color: "深蓝色", size: "32", quantity: 80, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "JS002", styleName: "直筒牛仔裤", color: "浅蓝色", size: "34", quantity: 90, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "HD001", styleName: "连帽卫衣", color: "灰色", size: "XL", quantity: 60, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "HD002", styleName: "连帽卫衣", color: "黑色", size: "L", quantity: 70, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "DR001", styleName: "连衣裙", color: "红色", size: "S", quantity: 40, productionDate: Date(), createdBy: "admin_001"),
                ProductionStyle(styleCode: "SH001", styleName: "运动鞋", color: "白色", size: "40", quantity: 50, productionDate: Date(), createdBy: "admin_001")
            ]
            
            productionStyles.append(contentsOf: manualStyles)
            
            for style in productionStyles {
                modelContext.insert(style)
            }
            
            print("✅ Initialized \(productionStyles.count) sample production styles")
        } catch {
            print("❌ Error creating production styles: \(error)")
        }
    }
    
    private static func initializeSamplePackagingTeams(modelContext: ModelContext) {
        do {
            let productDescriptor = FetchDescriptor<Product>()
            let products = try modelContext.fetch(productDescriptor)
            
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
                modelContext.insert(team)
            }
            
            print("✅ Initialized \(packagingTeams.count) sample packaging teams with actual product IDs")
        } catch {
            print("❌ Error creating packaging teams: \(error)")
            // Fallback to teams without specializations
            let fallbackTeams = [
                PackagingTeam(
                    teamName: "A组包装团队",
                    teamLeader: "张队长",
                    members: ["小王", "小李", "小陈"],
                    specializedStyles: []
                ),
                PackagingTeam(
                    teamName: "B组包装团队",
                    teamLeader: "刘队长",
                    members: ["小赵", "小孙", "小周", "小吴"],
                    specializedStyles: []
                ),
                PackagingTeam(
                    teamName: "C组包装团队",
                    teamLeader: "王队长",
                    members: ["小徐", "小马"],
                    specializedStyles: []
                )
            ]
            
            for team in fallbackTeams {
                modelContext.insert(team)
            }
            
            print("✅ Initialized \(fallbackTeams.count) fallback packaging teams")
        }
    }
    
    private static func initializeSamplePackagingRecords(modelContext: ModelContext) {
        do {
            let teamDescriptor = FetchDescriptor<PackagingTeam>()
            let productDescriptor = FetchDescriptor<Product>()
            let teams = try modelContext.fetch(teamDescriptor)
            let products = try modelContext.fetch(productDescriptor)
            
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
                modelContext.insert(record)
            }
            
            print("✅ Initialized \(packagingRecords.count) sample packaging records with actual product IDs")
        } catch {
            print("❌ Error creating packaging records: \(error)")
        }
    }
} 