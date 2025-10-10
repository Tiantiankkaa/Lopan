//
//  CustomerOutOfStockSampleDataService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/20.
//

import Foundation

/// 大规模客户缺货管理样本数据服务
/// 用于生成2000个客户、1000个产品、100000条欠货记录（2024-2025）
/// 数据覆盖：Lagos (50%), China (15%), USA (12%), Ibadan (8%), Onitsha (6%), Aba (5%), Kano (3%), Other (1%)
@MainActor
class CustomerOutOfStockSampleDataService {
    
    // MARK: - 私有属性
    private let repositoryFactory: RepositoryFactory
    private let authService: AuthenticationService
    private let progressMonitor = SampleDataProgressMonitor()

    // MARK: - 初始化
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
    }
    
    // MARK: - 公开属性
    var monitor: SampleDataProgressMonitor { progressMonitor }
    
    // MARK: - 主要初始化方法
    
    /// 初始化大规模样本数据
    func initializeLargeScaleSampleData() async {
        // 开始进度监控
        progressMonitor.startGeneration()
        
        do {
            // 准备阶段
            progressMonitor.updatePhase(.preparing)
            progressMonitor.updateStep(phase: .preparing, stepIndex: 0, stepName: "检查现有数据...")
            
            // 检查是否已有数据
            let existingCustomers = try await repositoryFactory.customerRepository.fetchCustomers()
            let existingProducts = try await repositoryFactory.productRepository.fetchProducts()
            let existingRecords = try await repositoryFactory.customerOutOfStockRepository.fetchOutOfStockRecords()
            
            // 如果数据量已经很大，则跳过初始化
            if existingCustomers.count >= 1500 || existingProducts.count >= 800 || existingRecords.count >= 80000 {
                print("📊 检测到已有大量数据，跳过大规模样本数据初始化")
                print("   - 现有客户: \(existingCustomers.count)")
                print("   - 现有产品: \(existingProducts.count)")
                print("   - 现有记录: \(existingRecords.count)")
                progressMonitor.completeGeneration()
                return
            }

            progressMonitor.completeStep(phase: .preparing, stepIndex: 0, stepName: "数据检查完成")
            print("🚀 开始生成大规模样本数据 (Global Regions Edition)...")
            print("📊 目标：2000个客户，1000个产品，100000条欠货记录")
            print("🌍 地区分布：Lagos (50%), China (15%), USA (12%), Ibadan (8%), Onitsha (6%), Aba (5%), Kano (3%), Other (1%)")
            print("📅 时间范围：2024-01-01 至今 (21个月)")
            
            // Pre-load location data to ensure country/region info is available
            print("\n🌍 Pre-loading location data...")
            await LocationDataService.shared.loadLocationData()
            print("✅ Location data loaded")

            // 阶段1：生成客户数据
            progressMonitor.updatePhase(.customers)
            print("\n📋 阶段1：生成客户数据...")
            let customers = await generateLargeScaleCustomers()
            print("✅ 成功生成 \(customers.count) 个客户")
            
            // 阶段2：生成产品数据
            progressMonitor.updatePhase(.products)
            print("\n📦 阶段2：生成产品数据...")
            let products = await generateLargeScaleProducts()
            print("✅ 成功生成 \(products.count) 个产品")
            
            // 阶段3：生成欠货记录
            progressMonitor.updatePhase(.outOfStock)
            print("\n📝 阶段3：生成欠货记录...")
            await generateOutOfStockRecords(customers: customers, products: products)

            // 阶段3.5：生成样本用户（销售人员）
            print("\n👥 阶段3.5：生成样本用户...")
            await generateSampleUsers()

            // 阶段4：生成销售数据
            progressMonitor.updatePhase(.completing)
            print("\n💰 阶段4：生成销售数据...")
            await generateDailySalesData(products: products)

            // 完成阶段
            progressMonitor.updateStep(phase: .completing, stepIndex: 0, stepName: "数据生成完成")

            print("\n🎉 大规模样本数据生成完成！")
            print("📊 数据统计：")
            print("   - 客户数量：\(customers.count)")
            print("   - 产品数量：\(products.count)")
            print("   - 欠货记录：\(SampleDataConstants.outOfStockRecordCount)")
            print("   - 销售记录：\(SampleDataConstants.salesEntryCount)")

            progressMonitor.completeStep(phase: .completing, stepIndex: 0, stepName: "所有数据生成完成")
            progressMonitor.completeGeneration()
            
        } catch {
            print("❌ 生成大规模样本数据时出错：\(error)")
            progressMonitor.completeGeneration()
        }
    }
    
    // MARK: - 客户数据生成

    /// Map city name to country code and region
    /// - Parameter city: City name
    /// - Returns: Tuple of (countryCode, regionName)
    private func mapCityToCountryRegion(_ city: String) -> (countryCode: String, regionName: String) {
        switch city {
        // Nigeria
        case "Lagos Island":
            return ("NG", "Lagos State")
        case "Ibadan":
            return ("NG", "Oyo State")
        case "Onitsha":
            return ("NG", "Anambra State")
        case "Aba":
            return ("NG", "Abia State")
        case "Kano":
            return ("NG", "Kano State")

        // China
        case "Shanghai":
            return ("CN", "Shanghai")
        case "Beijing":
            return ("CN", "Beijing")

        // USA
        case "Los Angeles":
            return ("US", "California")
        case "New York City":
            return ("US", "New York")

        // India
        case "Mumbai":
            return ("IN", "Maharashtra")

        // Default
        default:
            return ("NG", "Lagos State")
        }
    }

    /// Generate active salesperson IDs from database
    /// - Returns: Array of salesperson user IDs
    private func getActiveSalespersonIds() async -> [String] {
        // Use current logged-in user for sample data
        if let currentUser = authService.currentUser {
            print("📊 Using logged-in user ID for sample sales: \(currentUser.id)")

            // If this is a demo user, return ALL demo role IDs so sales are visible across all demo logins
            if currentUser.id.hasPrefix("demo-user-") {
                let demoUserIds = [
                    "demo-user-salesperson",
                    "demo-user-administrator",
                    "demo-user-warehouse_keeper",
                    "demo-user-workshop_manager"
                ]
                print("📊 Demo mode detected: Generating sales for all demo users")
                return demoUserIds
            }

            return [currentUser.id]
        }

        // Fallback: fetch from database if no logged-in user
        do {
            let users = try await repositoryFactory.userRepository.fetchUsers()
            let salespeople = users.filter { $0.roles.contains(.salesperson) && $0.isActive }
            let ids = salespeople.map { $0.id }
            print("📊 Found \(ids.count) active salespeople for sample data")
            return ids.isEmpty ? ["demo-user-salesperson"] : ids
        } catch {
            print("⚠️ Failed to fetch users: \(error)")
            // Default to demo salesperson if all else fails
            return ["demo-user-salesperson"]
        }
    }

    // MARK: - 用户数据生成

    /// Generate sample salesperson users for sales data
    private func generateSampleUsers() async {
        do {
            // Check if users already exist
            let existingUsers = try await repositoryFactory.userRepository.fetchUsers()

            if !existingUsers.isEmpty {
                print("ℹ️ Users already exist (\(existingUsers.count)), skipping user generation")
                return
            }

            // Create sample salesperson users
            let sampleUsers: [(wechatId: String, name: String)] = [
                ("sales_manager_001", "Sales Manager"),
                ("sales_rep_001", "Sales Representative"),
                ("sales_rep_002", "Senior Salesperson")
            ]

            for userData in sampleUsers {
                let user = User(wechatId: userData.wechatId, name: userData.name)
                user.roles = [.salesperson]
                user.primaryRole = .salesperson
                user.isActive = true
                try await repositoryFactory.userRepository.addUser(user)
            }

            print("✅ Created \(sampleUsers.count) sample salesperson users")
        } catch {
            print("❌ Error creating sample users: \(error)")
        }
    }

    /// 生成大规模客户数据（2000个）
    /// - Returns: 客户数组
    private func generateLargeScaleCustomers() async -> [Customer] {
        var customers: [Customer] = []
        let totalCount = SampleDataConstants.customerCount

        progressMonitor.updateStep(
            phase: .customers,
            stepIndex: 0,
            stepName: "Generating \(totalCount) customers..."
        )
        print("  Generating \(totalCount) customers with English names and global regions...")

        for i in 0..<totalCount {
            // Get weighted city (determines country/region)
            let cityName = SampleDataConstants.getWeightedCity()

            // Generate location-appropriate name based on city
            let name = LargeSampleDataGenerator.generateCustomerName(index: i, for: cityName)

            // Map city to country code and region
            let (countryCode, regionName) = mapCityToCountryRegion(cityName)

            // Generate phone number with proper dial code for country
            let phone = LargeSampleDataGenerator.generatePhoneNumber(for: countryCode)
            let whatsapp = LargeSampleDataGenerator.generatePhoneNumber(for: countryCode)

            // Get country info from LocationDataService
            let locationService = LocationDataService.shared
            let country = locationService.getCountry(byId: countryCode)

            // Legacy address (for backward compatibility)
            let address = "\(cityName), \(country?.name ?? "")"

            // Create customer with complete location data
            let customer = Customer(
                name: name,
                address: address,
                phone: phone,
                whatsappNumber: whatsapp,
                country: countryCode,
                countryName: country?.name ?? "",
                region: regionName,
                city: cityName
            )
            customers.append(customer)

            // Log progress every 500 customers
            if (i + 1) % 500 == 0 {
                print("    Generated \(i + 1)/\(totalCount) customers...")
            }
        }

        progressMonitor.completeStep(
            phase: .customers,
            stepIndex: 0,
            stepName: "Customer generation complete"
        )

        // 批量保存客户
        return await batchSaveCustomers(customers)
    }
    
    /// 批量保存客户数据
    /// - Parameter customers: 客户数组
    /// - Returns: 保存后的客户数组
    private func batchSaveCustomers(_ customers: [Customer]) async -> [Customer] {
        print("  批量保存客户数据...")
        let batchSize = SampleDataConstants.batchSize
        var savedCustomers: [Customer] = []
        
        for i in stride(from: 0, to: customers.count, by: batchSize) {
            let endIndex = min(i + batchSize, customers.count)
            let batch = Array(customers[i..<endIndex])
            
            for customer in batch {
                do {
                    try await repositoryFactory.customerRepository.addCustomer(customer)
                    savedCustomers.append(customer)
                } catch {
                    print("⚠️ 保存客户失败：\(customer.name) - \(error)")
                }
            }
            print("    已保存第 \(i/batchSize + 1) 批客户（\(batch.count) 个）")
        }
        
        return savedCustomers
    }
    
    // MARK: - 产品数据生成
    
    /// 生成大规模产品数据（1000个）
    /// - Returns: 产品数组
    private func generateLargeScaleProducts() async -> [Product] {
        var products: [Product] = []
        let totalProducts = SampleDataConstants.productCount

        progressMonitor.updateStep(
            phase: .products,
            stepIndex: 0,
            stepName: "Generating \(totalProducts) products with unique SKUs..."
        )
        print("  Generating \(totalProducts) products with English names and unique SKUs...")

        // Define status distribution
        // Active: 40% (400 products) - in production
        // Low Stock: 35% (350 products) - 1-9 units
        // Inactive: 25% (250 products) - not in production
        let activeCount = 400
        let lowStockCount = 350
        let inactiveCount = 250

        var statusDistribution: [String] = []
        statusDistribution.append(contentsOf: Array(repeating: "active", count: activeCount))
        statusDistribution.append(contentsOf: Array(repeating: "lowStock", count: lowStockCount))
        statusDistribution.append(contentsOf: Array(repeating: "inactive", count: inactiveCount))
        statusDistribution.shuffle()

        for i in 0..<totalProducts {
            // Generate unique SKU and name
            let sku = LargeSampleDataGenerator.generateUniqueSKU(index: i)
            let name = LargeSampleDataGenerator.generateProductName(index: i)
            let price = LargeSampleDataGenerator.generateFixedPrice(for: name)

            let product = Product(sku: sku, name: name, imageData: nil, price: price)

            // Determine status for this product
            let status = statusDistribution[i]

            // Generate inventory based on status
            let totalInventory: Int
            switch status {
            case "active":
                // Active: in production, inventory can be anything (random 0-100 for variety)
                totalInventory = Int.random(in: 0...100)
            case "lowStock":
                // Low Stock: requires 1-9 units
                totalInventory = Int.random(in: 1...9)
            default: // inactive
                // Inactive: not in production, must be 0
                totalInventory = 0
            }

            // Add sizes with inventory
            let sizeNames = LargeSampleDataGenerator.generateProductSizes()

            if totalInventory > 0 {
                // Distribute inventory across sizes
                var remainingInventory = totalInventory
                for (idx, sizeName) in sizeNames.enumerated() {
                    let isLastSize = (idx == sizeNames.count - 1)
                    let quantity: Int

                    if isLastSize {
                        quantity = remainingInventory
                    } else {
                        let avgPerSize = remainingInventory / (sizeNames.count - idx)
                        let variation = max(1, avgPerSize / 3)
                        quantity = max(0, Int.random(in: (avgPerSize - variation)...(avgPerSize + variation)))
                    }

                    let productSize = ProductSize(size: sizeName, quantity: quantity, product: product)
                    product.sizes?.append(productSize)
                    remainingInventory -= quantity

                    if remainingInventory <= 0 { break }
                }
            } else {
                // 0 inventory
                for sizeName in sizeNames {
                    let productSize = ProductSize(size: sizeName, quantity: 0, product: product)
                    product.sizes?.append(productSize)
                }
            }

            // Set manual status override for Active/Inactive (Low Stock auto-computed from quantity)
            if status == "active" {
                product.manualInventoryStatus = Product.InventoryStatus.active.rawValue
            } else if status == "inactive" {
                product.manualInventoryStatus = Product.InventoryStatus.inactive.rawValue
            }
            // Low Stock (1-9 units) will be auto-detected by updateCachedInventoryStatus()

            // Update cached inventory status based on sizes
            product.updateCachedInventoryStatus()

            products.append(product)

            // Log progress every 200 products
            if (i + 1) % 200 == 0 {
                print("    Generated \(i + 1)/\(totalProducts) products...")
            }
        }

        progressMonitor.completeStep(
            phase: .products,
            stepIndex: 0,
            stepName: "Product generation complete"
        )

        // Batch save products
        return await batchSaveProducts(products)
    }
    
    /// 批量保存产品数据
    /// - Parameter products: 产品数组
    /// - Returns: 保存后的产品数组
    private func batchSaveProducts(_ products: [Product]) async -> [Product] {
        print("  批量保存产品数据...")
        let batchSize = SampleDataConstants.batchSize
        var savedProducts: [Product] = []
        
        for i in stride(from: 0, to: products.count, by: batchSize) {
            let endIndex = min(i + batchSize, products.count)
            let batch = Array(products[i..<endIndex])
            
            for product in batch {
                do {
                    try await repositoryFactory.productRepository.addProduct(product)
                    savedProducts.append(product)
                } catch {
                    print("⚠️ 保存产品失败：\(product.name) - \(error)")
                }
            }
            print("    已保存第 \(i/batchSize + 1) 批产品（\(batch.count) 个）")
        }
        
        return savedProducts
    }
    
    // MARK: - 欠货记录生成
    
    /// 生成欠货记录（20000条）
    /// - Parameters:
    ///   - customers: 客户数组
    ///   - products: 产品数组
    private func generateOutOfStockRecords(customers: [Customer], products: [Product]) async {
        guard !customers.isEmpty && !products.isEmpty else {
            print("⚠️ 客户或产品数据为空，无法生成欠货记录")
            return
        }

        // Fetch real salesperson IDs from database (just like sales data)
        let salespersonIds = await getActiveSalespersonIds()
        guard !salespersonIds.isEmpty else {
            print("⚠️ 没有找到活跃的销售人员，跳过欠货记录生成")
            return
        }

        print("  按年份和月份分布生成欠货记录...")
        print("  使用 \(salespersonIds.count) 个真实销售人员ID")

        var stepIndex = 0
        var totalRecordsGenerated = 0

        // Iterate over years (2024, 2025)
        for yearData in SampleDataConstants.yearlyDistribution {
            let year = yearData.year
            let months = yearData.months

            print("  生成\(year)年数据（\(months.count)个月）...")

            // Iterate over months for this year
            for month in months {
                let recordCount = SampleDataConstants.monthlyDistribution[month] ?? 0

                progressMonitor.updateStep(
                    phase: .outOfStock,
                    stepIndex: stepIndex,
                    stepName: "生成\(year)年\(month)月记录：\(recordCount) 条"
                )
                print("    生成\(year)年\(month)月记录：\(recordCount) 条")

                await generateMonthlyRecords(
                    year: year,
                    month: month,
                    count: recordCount,
                    customers: customers,
                    products: products,
                    salespersonIds: salespersonIds
                )

                totalRecordsGenerated += recordCount

                progressMonitor.completeStep(
                    phase: .outOfStock,
                    stepIndex: stepIndex,
                    stepName: "\(year)年\(month)月记录生成完成"
                )
                stepIndex += 1
            }
        }

        print("  ✅ 欠货记录生成完成，共 \(totalRecordsGenerated) 条")
    }
    
    /// 生成特定月份的欠货记录
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份
    ///   - count: 记录数量
    ///   - customers: 客户数组
    ///   - products: 产品数组
    ///   - salespersonIds: 销售人员ID数组
    private func generateMonthlyRecords(
        year: Int,
        month: Int,
        count: Int,
        customers: [Customer],
        products: [Product],
        salespersonIds: [String]
    ) async {
        let batchSize = 1000  // Increased from 100 to 1000 for better performance
        let totalBatches = (count + batchSize - 1) / batchSize

        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, count)
            let batchCount = endIndex - startIndex

            var records: [CustomerOutOfStock] = []

            // 生成一批记录
            for _ in 0..<batchCount {
                let record = generateSingleRecord(
                    year: year,
                    month: month,
                    customers: customers,
                    products: products,
                    salespersonIds: salespersonIds
                )
                records.append(record)
            }

            // 批量保存记录
            await batchSaveOutOfStockRecords(records)
            print("      已保存\(month)月第\(batchIndex + 1)/\(totalBatches)批记录（\(batchCount) 条）")
        }
    }
    
    /// 生成单条欠货记录
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份
    ///   - customers: 客户数组
    ///   - products: 产品数组
    ///   - salespersonIds: 销售人员ID数组
    /// - Returns: 欠货记录
    private func generateSingleRecord(
        year: Int,
        month: Int,
        customers: [Customer],
        products: [Product],
        salespersonIds: [String]
    ) -> CustomerOutOfStock {
        // 随机选择客户和产品
        let customer = customers.randomElement()!
        let product = products.randomElement()!
        let productSize = product.sizes?.randomElement()

        // 生成基本信息
        let quantity = LargeSampleDataGenerator.generateQuantity()
        let status = LargeSampleDataGenerator.generateStatus()
        let urgency = LargeSampleDataGenerator.generateUrgencyLevel(for: month)
        let notes = LargeSampleDataGenerator.generateNotes(urgency: urgency)
        // Use real salesperson IDs instead of hardcoded ones
        let createdBy = LargeSampleDataGenerator.generateCreatorId(from: salespersonIds)
        
        // 生成日期
        let requestDate = LargeSampleDataGenerator.generateRandomDate(in: year, month: month)
        
        // 创建记录
        let record = CustomerOutOfStock(
            customer: customer,
            product: product,
            productSize: productSize,
            quantity: quantity,
            notes: notes,
            createdBy: createdBy
        )
        
        // 设置请求日期
        record.requestDate = requestDate
        record.status = status
        
        // 根据状态设置相关日期和数据
        switch status {
        case .pending:
            // Generate realistic mix: 70% waiting delivery, 30% partial delivery
            let deliveryScenario = Int.random(in: 0...100)
            if deliveryScenario < 70 {
                // 70%: Waiting delivery (no delivery yet)
                break
            } else {
                // 30%: Partial delivery
                let partialQty = Int.random(in: 1..<quantity)
                record.deliveryQuantity = partialQty
                record.deliveryDate = LargeSampleDataGenerator.generatePartialDeliveryDate(from: requestDate)
                record.deliveryNotes = "样本数据：部分发货 \(partialQty)/\(quantity)"
            }

        case .completed:
            // Fully delivered to customer
            record.actualCompletionDate = LargeSampleDataGenerator.generateCompletionDate(from: requestDate)
            record.deliveryQuantity = quantity  // Set full delivery quantity
            record.deliveryDate = record.actualCompletionDate
            record.deliveryNotes = "样本数据：完整发货"

        case .refunded:
            let deliveryDate = LargeSampleDataGenerator.generateReturnDate(from: requestDate)
            let deliveryQuantity = LargeSampleDataGenerator.generateReturnQuantity(originalQuantity: quantity)
            record.deliveryDate = deliveryDate
            record.deliveryQuantity = deliveryQuantity
            record.deliveryNotes = "样本数据：模拟发货记录"
        }
        
        return record
    }
    
    /// 批量保存欠货记录
    /// - Parameter records: 欠货记录数组
    private func batchSaveOutOfStockRecords(_ records: [CustomerOutOfStock]) async {
        do {
            // Use bulk insert for much better performance (single save for all records)
            try await repositoryFactory.customerOutOfStockRepository.addOutOfStockRecords(records)
        } catch {
            print("⚠️ 批量保存欠货记录失败：\(error)")
        }
    }
    
    // MARK: - 数据清理
    
    /// 清理所有样本数据
    /// 注意：这会删除所有数据，请谨慎使用
    func clearAllSampleData() async {
        print("🗑️ 开始清理所有样本数据...")
        
        do {
            // 删除所有欠货记录
            let allRecords = try await repositoryFactory.customerOutOfStockRepository.fetchOutOfStockRecords()
            try await repositoryFactory.customerOutOfStockRepository.deleteOutOfStockRecords(allRecords)
            print("✅ 已清理 \(allRecords.count) 条欠货记录")
            
            // 删除所有产品
            let allProducts = try await repositoryFactory.productRepository.fetchProducts()
            for product in allProducts {
                try await repositoryFactory.productRepository.deleteProduct(product)
            }
            print("✅ 已清理 \(allProducts.count) 个产品")
            
            // 删除所有客户
            let allCustomers = try await repositoryFactory.customerRepository.fetchCustomers()
            for customer in allCustomers {
                try await repositoryFactory.customerRepository.deleteCustomer(customer)
            }
            print("✅ 已清理 \(allCustomers.count) 个客户")
            
            print("🎉 所有样本数据清理完成！")
            
        } catch {
            print("❌ 清理样本数据时出错：\(error)")
        }
    }
    
    // MARK: - 销售数据生成

    /// Generate daily sales data (60,000 entries)
    /// - Parameter products: Available products
    private func generateDailySalesData(products: [Product]) async {
        guard !products.isEmpty else {
            print("⚠️ 产品数据为空，无法生成销售记录")
            return
        }

        // Fetch real salesperson IDs from database
        let salespersonIds = await getActiveSalespersonIds()
        guard !salespersonIds.isEmpty else {
            print("⚠️ 没有找到活跃的销售人员，跳过销售数据生成")
            return
        }

        print("  按年份和月份分布生成销售记录...")
        print("  使用 \(salespersonIds.count) 个真实销售人员ID")

        let totalSales = SampleDataConstants.salesEntryCount
        var salesGenerated = 0

        // Calculate sales per month proportionally
        let totalMonths = SampleDataConstants.yearlyDistribution.reduce(0) { $0 + $1.months.count }
        let salesPerMonth = totalSales / totalMonths

        // Iterate over years (2024, 2025)
        for yearData in SampleDataConstants.yearlyDistribution {
            let year = yearData.year
            let months = yearData.months

            print("  生成\(year)年销售数据（\(months.count)个月）...")

            // Iterate over months for this year
            for month in months {
                // Apply monthly adjustment factor
                let monthFactor = LargeSampleDataGenerator.adjustProbabilityByMonth(month: month)
                let adjustedSalesCount = Int(Double(salesPerMonth) * monthFactor)

                print("    生成\(year)年\(month)月销售记录：\(adjustedSalesCount) 条")

                await generateMonthlySales(
                    year: year,
                    month: month,
                    count: adjustedSalesCount,
                    products: products,
                    salespersonIds: salespersonIds
                )

                salesGenerated += adjustedSalesCount
            }
        }

        print("  ✅ 销售记录生成完成，共 \(salesGenerated) 条")
    }

    /// Generate sales for a specific month
    /// - Parameters:
    ///   - year: Year
    ///   - month: Month
    ///   - count: Number of sales entries
    ///   - products: Available products
    ///   - salespersonIds: Real salesperson IDs from database
    private func generateMonthlySales(
        year: Int,
        month: Int,
        count: Int,
        products: [Product],
        salespersonIds: [String]
    ) async {
        let batchSize = 500  // Process 500 sales at a time
        let totalBatches = (count + batchSize - 1) / batchSize

        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, count)
            let batchCount = endIndex - startIndex

            var salesEntries: [DailySalesEntry] = []

            // Generate a batch of sales entries
            for _ in 0..<batchCount {
                let entry = generateSingleSale(
                    year: year,
                    month: month,
                    products: products,
                    salespersonIds: salespersonIds
                )
                salesEntries.append(entry)
            }

            // Batch save sales entries
            await batchSaveSalesEntries(salesEntries)
            print("      已保存\(month)月第\(batchIndex + 1)/\(totalBatches)批销售（\(batchCount) 条）")
        }
    }

    /// Generate a single sales entry
    /// - Parameters:
    ///   - year: Year
    ///   - month: Month
    ///   - products: Available products
    ///   - salespersonIds: Real salesperson IDs from database
    /// - Returns: DailySalesEntry
    private func generateSingleSale(
        year: Int,
        month: Int,
        products: [Product],
        salespersonIds: [String]
    ) -> DailySalesEntry {
        // Generate random date in the month
        let saleDate = LargeSampleDataGenerator.generateRandomDate(in: year, month: month)

        // Select random real salesperson ID
        let salespersonId = salespersonIds.randomElement() ?? salespersonIds[0]

        // Generate line items (1-8 products per sale)
        let lineItems = LargeSampleDataGenerator.generateSalesLineItems(from: products)

        // Create sales entry
        let entry = DailySalesEntry(
            date: saleDate,
            salespersonId: salespersonId,
            items: lineItems
        )

        return entry
    }

    /// Batch save sales entries
    /// - Parameter entries: Sales entries array
    private func batchSaveSalesEntries(_ entries: [DailySalesEntry]) async {
        do {
            // Use optimized batch save method (inserts all entries then saves once)
            try await repositoryFactory.salesRepository.createSalesEntries(entries)
        } catch {
            print("⚠️ 批量保存销售记录失败：\(entries.count) 条 - \(error)")
        }
    }

    // MARK: - 数据统计

    /// 获取当前数据统计
    func getDataStatistics() async {
        do {
            let customerCount = try await repositoryFactory.customerRepository.fetchCustomers().count
            let productCount = try await repositoryFactory.productRepository.fetchProducts().count
            let recordCount = try await repositoryFactory.customerOutOfStockRepository.fetchOutOfStockRecords().count

            print("📊 当前数据统计：")
            print("   - 客户数量：\(customerCount)")
            print("   - 产品数量：\(productCount)")
            print("   - 欠货记录：\(recordCount)")

        } catch {
            print("❌ 获取数据统计时出错：\(error)")
        }
    }
}