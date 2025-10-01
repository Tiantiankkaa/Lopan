//
//  SampleDataConstants.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/20.
//

import Foundation

// MARK: - 样本数据常量配置
struct SampleDataConstants {
    
    // MARK: - 数据规模
    static let customerCount = 2000        // 2000 customers for 100K records
    static let productCount = 1000         // 1000 products for variety
    static let outOfStockRecordCount = 100000  // 100,000 records
    static let batchSize = 1000            // Increased batch size for performance
    
    // MARK: - 时间范围 (2024-01-01 to Present)
    static let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
    static let endDate = Date()  // Current date (dynamic)
    
    // MARK: - 数据分布比例
    struct Distribution {
        // 状态分布
        static let pendingRatio: Double = 0.4      // 40% 待处理
        static let completedRatio: Double = 0.5    // 50% 已完成
        static let cancelledRatio: Double = 0.1    // 10% 已退货
        
        // 数量分布
        static let smallBatchRatio: Double = 0.3   // 30% 小批量 (10-50件)
        static let mediumBatchRatio: Double = 0.4  // 40% 中批量 (51-200件)
        static let largeBatchRatio: Double = 0.2   // 20% 大批量 (201-500件)
        static let extraLargeRatio: Double = 0.1   // 10% 超大批量 (501-2000件)
        
        // 客户类型分布 (Scaled for 2000 customers)
        static let importantCustomers = 400        // 重要客户 (20%)
        static let standardCustomers = 800         // 标准客户 (40%)
        static let regularCustomers = 800          // 普通客户 (40%)
    }
    
    // MARK: - 月份记录分布 (Per Month, distributed across years)
    // Total: ~100,000 records (60K in 2024 + 40K in 2025)
    static let monthlyDistribution: [Int: Int] = [
        1: 4000,    // January
        2: 4200,    // February
        3: 4500,    // March
        4: 4800,    // April
        5: 5000,    // May
        6: 5200,    // June
        7: 5500,    // July
        8: 5800,    // August
        9: 6000,    // September
        10: 5500,   // October
        11: 5200,   // November
        12: 5800    // December
    ]

    // MARK: - 年份分布 (Years to Generate)
    // 2024: All 12 months = ~62,000 records
    // 2025: First 9 months = ~44,000 records
    // Total: ~106,000 records
    static let yearlyDistribution: [(year: Int, months: [Int])] = [
        (2024, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),  // 2024: All 12 months
        (2025, [1, 2, 3, 4, 5, 6, 7, 8, 9])               // 2025: Jan-Sep (9 months)
    ]
    
    // MARK: - 城市列表 (Global Regions with Weighted Distribution)
    static let cities = [
        "Lagos",    // 50% of data
        "China",    // 15% of data
        "USA",      // 12% of data
        "Ibadan",   // 8% of data
        "Onitsha",  // 6% of data
        "Aba",      // 5% of data
        "Kano",     // 3% of data
        "Other"     // 1% of data (combined smaller cities)
    ]

    // City weights for distribution (must sum to 1.0)
    static let cityWeights: [String: Double] = [
        "Lagos": 0.50,
        "China": 0.15,
        "USA": 0.12,
        "Ibadan": 0.08,
        "Onitsha": 0.06,
        "Aba": 0.05,
        "Kano": 0.03,
        "Other": 0.01
    ]

    /// Get a weighted random city
    static func getWeightedCity() -> String {
        let random = Double.random(in: 0...1)
        var cumulative = 0.0

        for city in cities {
            cumulative += cityWeights[city] ?? 0
            if random <= cumulative {
                return city
            }
        }

        return cities.last ?? "Lagos"
    }
    
    // MARK: - 产品类别 (Scaled for 1000 products)
    enum ProductCategory: String, CaseIterable {
        case tops = "上衣类"           // 330个产品
        case pants = "裤装类"          // 270个产品
        case dresses = "裙装类"        // 200个产品
        case shoes = "鞋类"           // 130个产品
        case accessories = "配饰类"    // 70个产品

        var count: Int {
            switch self {
            case .tops: return 330
            case .pants: return 270
            case .dresses: return 200
            case .shoes: return 130
            case .accessories: return 70
            }
        }
        
        var baseNames: [String] {
            switch self {
            case .tops:
                return ["T恤", "衬衫", "外套", "卫衣", "毛衣", "背心", "夹克", "风衣", "开衫", "针织衫"]
            case .pants:
                return ["牛仔裤", "休闲裤", "运动裤", "短裤", "工装裤", "西装裤", "打底裤", "哈伦裤"]
            case .dresses:
                return ["连衣裙", "半身裙", "长裙", "短裙", "A字裙", "包臀裙", "百褶裙", "吊带裙"]
            case .shoes:
                return ["运动鞋", "皮鞋", "休闲鞋", "高跟鞋", "凉鞋", "靴子", "帆布鞋", "豆豆鞋"]
            case .accessories:
                return ["帽子", "围巾", "手套", "腰带", "手表", "项链", "耳环", "手镯"]
            }
        }
    }
    
    // MARK: - 客户类型
    enum CustomerType: String, CaseIterable {
        case important = "重要客户"
        case standard = "标准客户"
        case regular = "普通客户"
        
        var count: Int {
            switch self {
            case .important: return Distribution.importantCustomers
            case .standard: return Distribution.standardCustomers
            case .regular: return Distribution.regularCustomers
            }
        }
    }
    
    // MARK: - 产品颜色
    static let colors = [
        "白色", "黑色", "蓝色", "红色", "灰色",
        "粉色", "黄色", "绿色", "紫色", "橙色",
        "米色", "卡其色", "深蓝色", "浅蓝色", "酒红色"
    ]
    
    // MARK: - 产品尺码
    static let sizes = ["S", "M", "L", "XL", "XXL", "XXXL"]
    
    // MARK: - 紧急程度
    enum UrgencyLevel: String, CaseIterable {
        case urgent = "urgent"
        case high = "high"
        case normal = "normal"
        case low = "low"
        
        var noteTemplates: [String] {
            switch self {
            case .urgent:
                return [
                    "客户急需，请优先处理",
                    "紧急订单，需要加急处理",
                    "VIP客户紧急需求",
                    "客户催单，请尽快安排"
                ]
            case .high:
                return [
                    "重要客户订单",
                    "大批量订单，请重点关注",
                    "季节性热销商品",
                    "市场反响良好，需要补货"
                ]
            case .normal:
                return [
                    "常规补货需求",
                    "正常库存补充",
                    "标准订单处理",
                    "按计划补货"
                ]
            case .low:
                return [
                    "库存预备补充",
                    "季末清理需求",
                    "少量补货",
                    "备用库存"
                ]
            }
        }
    }
    
    // MARK: - 数量范围
    struct QuantityRange {
        static let small = 10...50          // 小批量
        static let medium = 51...200        // 中批量
        static let large = 201...500        // 大批量
        static let extraLarge = 501...2000  // 超大批量
    }
}