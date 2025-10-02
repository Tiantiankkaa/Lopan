//
//  LargeSampleDataGenerator.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/20.
//

import Foundation

/// 大规模样本数据生成器
/// 用于生成真实但随机的测试数据
class LargeSampleDataGenerator {
    
    // MARK: - 私有属性
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // MARK: - 客户数据生成
    
    /// 生成客户名称
    /// - Parameters:
    ///   - type: 客户类型
    ///   - index: 客户编号
    /// - Returns: 客户名称
    static func generateCustomerName(type: SampleDataConstants.CustomerType, index: Int) -> String {
        return "\(type.rawValue)\(String(format: "%03d", index + 1))"
    }
    
    /// 生成随机地址
    /// - Parameter city: 城市名称
    /// - Returns: 完整地址
    static func generateAddress(city: String) -> String {
        let districts = ["中心区", "新区", "开发区", "高新区", "经济区", "工业区", "商务区", "文化区"]
        let streets = ["建国路", "解放大道", "中山路", "人民大街", "友谊路", "和平街", "胜利路", "文化街", "科技路", "商业街"]
        let buildings = ["写字楼", "商务中心", "大厦", "广场", "中心", "大楼", "园区", "城"]
        
        let district = districts.randomElement()!
        let street = streets.randomElement()!
        let building = buildings.randomElement()!
        let number = Int.random(in: 1...999)
        
        return "\(city)\(district)\(street)\(number)号\(building)"
    }
    
    /// 生成随机电话号码
    /// - Returns: 手机号码
    static func generatePhoneNumber() -> String {
        let prefixes = ["138", "139", "150", "151", "152", "158", "159", "186", "187", "188"]
        let prefix = prefixes.randomElement()!
        let suffix = String(format: "%08d", Int.random(in: 10000000...99999999))
        return prefix + suffix
    }
    
    // MARK: - 产品数据生成
    
    /// 生成产品名称
    /// - Parameters:
    ///   - category: 产品类别
    ///   - index: 产品在该类别中的编号
    /// - Returns: 产品名称
    static func generateProductName(category: SampleDataConstants.ProductCategory, index: Int) -> String {
        let baseNames = category.baseNames
        let baseName = baseNames[index % baseNames.count]
        
        // 添加一些变化词汇使产品名称更丰富
        let variations = generateProductVariations(for: category)
        let variation = variations.randomElement() ?? ""
        
        // 根据产品编号添加不同的修饰
        let modifier = generateProductModifier(index: index)
        
        if variation.isEmpty && modifier.isEmpty {
            return baseName
        } else if variation.isEmpty {
            return "\(modifier)\(baseName)"
        } else if modifier.isEmpty {
            return "\(variation)\(baseName)"
        } else {
            return "\(modifier)\(variation)\(baseName)"
        }
    }
    
    /// 生成产品变化词汇
    /// - Parameter category: 产品类别
    /// - Returns: 变化词汇数组
    private static func generateProductVariations(for category: SampleDataConstants.ProductCategory) -> [String] {
        switch category {
        case .tops:
            return ["经典", "时尚", "修身", "宽松", "简约", "复古", "商务", "休闲", "运动", ""]
        case .pants:
            return ["直筒", "修身", "宽松", "高腰", "低腰", "弹力", "磨破", "复古", "时尚", ""]
        case .dresses:
            return ["优雅", "甜美", "性感", "简约", "复古", "波西米亚", "韩版", "欧美", "淑女", ""]
        case .shoes:
            return ["时尚", "经典", "舒适", "防滑", "透气", "轻便", "耐磨", "潮流", "商务", ""]
        case .accessories:
            return ["时尚", "精致", "简约", "复古", "潮流", "经典", "可爱", "优雅", "个性", ""]
        }
    }
    
    /// 生成产品修饰词
    /// - Parameter index: 产品编号
    /// - Returns: 修饰词
    private static func generateProductModifier(index: Int) -> String {
        let modifiers = ["新款", "热销", "推荐", "特色", "限量", ""]
        // 根据编号选择，保证一定的随机性但又有规律
        return modifiers[index % modifiers.count]
    }
    
    /// 生成产品颜色组合
    /// - Returns: 颜色数组（3-5种颜色）
    static func generateProductColors() -> [String] {
        let colorCount = Int.random(in: 3...5)
        return Array(SampleDataConstants.colors.shuffled().prefix(colorCount))
    }
    
    /// 生成产品尺码组合
    /// - Returns: 尺码数组（3-6个尺码）
    static func generateProductSizes() -> [String] {
        let sizeCount = Int.random(in: 3...6)
        return Array(SampleDataConstants.sizes.prefix(sizeCount))
    }
    
    // MARK: - 欠货记录数据生成
    
    /// 生成随机备注
    /// - Parameter urgency: 紧急程度
    /// - Returns: 备注内容
    static func generateNotes(urgency: SampleDataConstants.UrgencyLevel) -> String {
        let templates = urgency.noteTemplates
        var note = templates.randomElement()!
        
        // 随机添加一些额外信息
        if Bool.random() {
            let additionalInfo = generateAdditionalInfo()
            note += "，\(additionalInfo)"
        }
        
        return note
    }
    
    /// 生成额外信息
    /// - Returns: 额外信息字符串
    private static func generateAdditionalInfo() -> String {
        let infos = [
            "预计需求量较大",
            "请确保质量",
            "客户对时间要求较严",
            "可能会追加订单",
            "需要特殊包装",
            "客户指定发货时间",
            "质量要求较高",
            "请优先安排"
        ]
        return infos.randomElement()!
    }
    
    /// 根据月份调整生成概率
    /// - Parameter month: 月份 (1-12)
    /// - Returns: 调整因子 (0.5-2.0)
    static func adjustProbabilityByMonth(month: Int) -> Double {
        // 根据月份调整不同状态的概率
        switch month {
        case 1: return 1.2  // 1月春节前，紧急订单增多
        case 2: return 0.6  // 2月春节期间，订单减少
        case 3: return 1.3  // 3月春季新品上市
        case 4: return 1.4  // 4月换季高峰
        case 5: return 1.5  // 5月夏季开始
        case 6: return 1.8  // 6月618促销
        case 7: return 1.9  // 7月暑期高峰
        case 8: return 1.9  // 8月持续高峰
        case 9: return 1.4  // 9月开学季
        case 10: return 1.2 // 10月国庆
        case 11: return 1.6 // 11月双11
        case 12: return 1.3 // 12月年底
        default: return 1.0
        }
    }
    
    /// 生成随机数量
    /// - Returns: 根据分布概率生成的数量
    static func generateQuantity() -> Int {
        let random = Double.random(in: 0...1)
        
        if random < SampleDataConstants.Distribution.smallBatchRatio {
            // 小批量 (10-50件)
            return Int.random(in: SampleDataConstants.QuantityRange.small)
        } else if random < SampleDataConstants.Distribution.smallBatchRatio + SampleDataConstants.Distribution.mediumBatchRatio {
            // 中批量 (51-200件)
            return Int.random(in: SampleDataConstants.QuantityRange.medium)
        } else if random < SampleDataConstants.Distribution.smallBatchRatio + SampleDataConstants.Distribution.mediumBatchRatio + SampleDataConstants.Distribution.largeBatchRatio {
            // 大批量 (201-500件)
            return Int.random(in: SampleDataConstants.QuantityRange.large)
        } else {
            // 超大批量 (501-2000件)
            return Int.random(in: SampleDataConstants.QuantityRange.extraLarge)
        }
    }
    
    /// 生成随机状态
    /// - Returns: 根据分布概率生成的状态
    static func generateStatus() -> OutOfStockStatus {
        let random = Double.random(in: 0...1)
        
        if random < SampleDataConstants.Distribution.pendingRatio {
            return .pending
        } else if random < SampleDataConstants.Distribution.pendingRatio + SampleDataConstants.Distribution.completedRatio {
            return .completed
        } else {
            return .refunded
        }
    }
    
    /// 生成紧急程度
    /// - Parameter month: 月份，用于调整紧急程度分布
    /// - Returns: 紧急程度
    static func generateUrgencyLevel(for month: Int) -> SampleDataConstants.UrgencyLevel {
        let monthFactor = adjustProbabilityByMonth(month: month)
        let random = Double.random(in: 0...1)
        
        // 根据月份调整紧急程度的分布
        let urgentThreshold = 0.1 * monthFactor
        let highThreshold = 0.3 * monthFactor
        let normalThreshold = 0.8
        
        if random < urgentThreshold {
            return .urgent
        } else if random < highThreshold {
            return .high
        } else if random < normalThreshold {
            return .normal
        } else {
            return .low
        }
    }
    
    // MARK: - 日期生成
    
    /// 在指定月份生成随机日期
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份
    /// - Returns: 随机日期
    static func generateRandomDate(in year: Int, month: Int) -> Date {
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month))!)!.count
        
        // 对于8月，限制在26号之前
        let maxDay = (month == 8) ? min(26, daysInMonth) : daysInMonth
        let day = Int.random(in: 1...maxDay)
        let hour = Int.random(in: 8...18) // 工作时间
        let minute = Int.random(in: 0...59)
        
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }
    
    /// 生成完成日期（基于请求日期）
    /// - Parameter requestDate: 请求日期
    /// - Returns: 完成日期
    static func generateCompletionDate(from requestDate: Date) -> Date {
        // 完成时间通常在请求后1-30天
        let daysToAdd = Int.random(in: 1...30)
        return Calendar.current.date(byAdding: .day, value: daysToAdd, to: requestDate) ?? requestDate
    }
    
    /// 生成退货日期（基于请求日期）
    /// - Parameter requestDate: 请求日期
    /// - Returns: 退货日期
    static func generateReturnDate(from requestDate: Date) -> Date {
        // 退货时间通常在请求后1-15天
        let daysToAdd = Int.random(in: 1...15)
        return Calendar.current.date(byAdding: .day, value: daysToAdd, to: requestDate) ?? requestDate
    }

    /// 生成部分发货日期（基于请求日期）
    /// - Parameter requestDate: 请求日期
    /// - Returns: 部分发货日期
    static func generatePartialDeliveryDate(from requestDate: Date) -> Date {
        // 部分发货时间通常在请求后1-20天
        let daysToAdd = Int.random(in: 1...20)
        return Calendar.current.date(byAdding: .day, value: daysToAdd, to: requestDate) ?? requestDate
    }

    // MARK: - 辅助方法
    
    /// 生成创建者ID
    /// - Returns: 创建者ID
    static func generateCreatorId() -> String {
        let creators = ["sales_001", "sales_002", "sales_003", "manager_001", "admin_001"]
        return creators.randomElement()!
    }
    
    /// 为退货生成退货数量
    /// - Parameter originalQuantity: 原始数量
    /// - Returns: 退货数量
    static func generateReturnQuantity(originalQuantity: Int) -> Int {
        // 退货数量通常是原数量的20%-100%
        let minReturn = max(1, Int(Double(originalQuantity) * 0.2))
        let maxReturn = originalQuantity
        return Int.random(in: minReturn...maxReturn)
    }
}