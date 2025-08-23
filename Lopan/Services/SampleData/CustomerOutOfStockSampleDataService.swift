//
//  CustomerOutOfStockSampleDataService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/20.
//

import Foundation

/// 大规模客户缺货管理样本数据服务
/// 用于生成500个客户、300个产品、20000条欠货记录
@MainActor
class CustomerOutOfStockSampleDataService {
    
    // MARK: - 私有属性
    private let repositoryFactory: RepositoryFactory
    private let progressMonitor = SampleDataProgressMonitor()
    
    // MARK: - 初始化
    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
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
            if existingCustomers.count >= 400 || existingProducts.count >= 250 || existingRecords.count >= 15000 {
                print("📊 检测到已有大量数据，跳过大规模样本数据初始化")
                progressMonitor.completeGeneration()
                return
            }
            
            progressMonitor.completeStep(phase: .preparing, stepIndex: 0, stepName: "数据检查完成")
            print("🚀 开始生成大规模样本数据...")
            print("📊 目标：500个客户，300个产品，20000条欠货记录")
            
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
            
            // 完成阶段
            progressMonitor.updatePhase(.completing)
            progressMonitor.updateStep(phase: .completing, stepIndex: 0, stepName: "数据生成完成")
            
            print("\n🎉 大规模样本数据生成完成！")
            print("📊 数据统计：")
            print("   - 客户数量：\(customers.count)")
            print("   - 产品数量：\(products.count)")
            print("   - 欠货记录：\(SampleDataConstants.outOfStockRecordCount)")
            
            progressMonitor.completeStep(phase: .completing, stepIndex: 0, stepName: "所有数据生成完成")
            progressMonitor.completeGeneration()
            
        } catch {
            print("❌ 生成大规模样本数据时出错：\(error)")
            progressMonitor.completeGeneration()
        }
    }
    
    // MARK: - 客户数据生成
    
    /// 生成大规模客户数据（500个）
    /// - Returns: 客户数组
    private func generateLargeScaleCustomers() async -> [Customer] {
        var customers: [Customer] = []
        var customerIndex = 0
        var stepIndex = 0
        
        // 按类型分配客户
        for customerType in SampleDataConstants.CustomerType.allCases {
            let count = customerType.count
            progressMonitor.updateStep(
                phase: .customers, 
                stepIndex: stepIndex, 
                stepName: "生成\(customerType.rawValue) \(count) 个..."
            )
            print("  生成\(customerType.rawValue) \(count) 个...")
            
            for i in 0..<count {
                let name = LargeSampleDataGenerator.generateCustomerName(type: customerType, index: i)
                let city = SampleDataConstants.cities[customerIndex % SampleDataConstants.cities.count]
                let address = LargeSampleDataGenerator.generateAddress(city: city)
                let phone = LargeSampleDataGenerator.generatePhoneNumber()
                
                let customer = Customer(name: name, address: address, phone: phone)
                customers.append(customer)
                customerIndex += 1
            }
            
            progressMonitor.completeStep(
                phase: .customers, 
                stepIndex: stepIndex, 
                stepName: "\(customerType.rawValue)生成完成"
            )
            stepIndex += 1
        }
        
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
    
    /// 生成大规模产品数据（300个）
    /// - Returns: 产品数组
    private func generateLargeScaleProducts() async -> [Product] {
        var products: [Product] = []
        var productIndex = 0
        var stepIndex = 0
        
        // 按类别生成产品
        for category in SampleDataConstants.ProductCategory.allCases {
            let count = category.count
            progressMonitor.updateStep(
                phase: .products, 
                stepIndex: stepIndex, 
                stepName: "生成\(category.rawValue) \(count) 个..."
            )
            print("  生成\(category.rawValue) \(count) 个...")
            
            for i in 0..<count {
                let name = LargeSampleDataGenerator.generateProductName(category: category, index: i)
                let colors = LargeSampleDataGenerator.generateProductColors()
                
                let product = Product(name: name, colors: colors, imageData: nil)
                
                // 为产品添加尺码
                let sizeNames = LargeSampleDataGenerator.generateProductSizes()
                for sizeName in sizeNames {
                    let productSize = ProductSize(size: sizeName)
                    product.sizes?.append(productSize)
                }
                
                products.append(product)
                productIndex += 1
            }
            
            progressMonitor.completeStep(
                phase: .products, 
                stepIndex: stepIndex, 
                stepName: "\(category.rawValue)生成完成"
            )
            stepIndex += 1
        }
        
        // 批量保存产品
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
        
        print("  按月份分布生成欠货记录...")
        
        var stepIndex = 0
        for (month, recordCount) in SampleDataConstants.monthlyDistribution.sorted(by: { $0.key < $1.key }) {
            progressMonitor.updateStep(
                phase: .outOfStock, 
                stepIndex: stepIndex, 
                stepName: "生成\(month)月记录：\(recordCount) 条"
            )
            print("    生成\(month)月记录：\(recordCount) 条")
            
            await generateMonthlyRecords(
                year: 2025,
                month: month,
                count: recordCount,
                customers: customers,
                products: products
            )
            
            progressMonitor.completeStep(
                phase: .outOfStock, 
                stepIndex: stepIndex, 
                stepName: "\(month)月记录生成完成"
            )
            stepIndex += 1
        }
    }
    
    /// 生成特定月份的欠货记录
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份
    ///   - count: 记录数量
    ///   - customers: 客户数组
    ///   - products: 产品数组
    private func generateMonthlyRecords(
        year: Int,
        month: Int,
        count: Int,
        customers: [Customer],
        products: [Product]
    ) async {
        let batchSize = 100  // 每批处理100条记录
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
                    products: products
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
    /// - Returns: 欠货记录
    private func generateSingleRecord(
        year: Int,
        month: Int,
        customers: [Customer],
        products: [Product]
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
        let createdBy = LargeSampleDataGenerator.generateCreatorId()
        
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
        case .completed:
            record.actualCompletionDate = LargeSampleDataGenerator.generateCompletionDate(from: requestDate)
            
        case .cancelled:
            let returnDate = LargeSampleDataGenerator.generateReturnDate(from: requestDate)
            let returnQuantity = LargeSampleDataGenerator.generateReturnQuantity(originalQuantity: quantity)
            record.returnDate = returnDate
            record.returnQuantity = returnQuantity
            record.returnNotes = "样本数据：模拟退货记录"
            
        case .pending:
            // 待处理状态不需要额外设置
            break
        }
        
        return record
    }
    
    /// 批量保存欠货记录
    /// - Parameter records: 欠货记录数组
    private func batchSaveOutOfStockRecords(_ records: [CustomerOutOfStock]) async {
        for record in records {
            do {
                try await repositoryFactory.customerOutOfStockRepository.addOutOfStockRecord(record)
            } catch {
                print("⚠️ 保存欠货记录失败：\(error)")
            }
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