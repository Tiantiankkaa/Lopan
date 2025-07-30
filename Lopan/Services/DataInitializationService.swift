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
} 