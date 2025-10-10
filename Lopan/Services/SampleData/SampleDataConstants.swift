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
    static let salesEntryCount = 60000     // 60,000 sales entries
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
    // 2025: First 10 months = ~49,500 records
    // Total: ~111,500 records
    static let yearlyDistribution: [(year: Int, months: [Int])] = [
        (2024, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),  // 2024: All 12 months
        (2025, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])           // 2025: Jan-Oct (10 months)
    ]
    
    // MARK: - 城市列表 (Global Cities with Weighted Distribution)
    static let cities = [
        "Lagos Island",        // 50% of data (Nigeria - Lagos State)
        "Shanghai",            // 8% of data (China - Shanghai)
        "Beijing",             // 7% of data (China - Beijing)
        "Los Angeles",         // 6% of data (USA - California)
        "New York City",       // 6% of data (USA - New York)
        "Ibadan",              // 8% of data (Nigeria - Oyo State)
        "Onitsha",             // 6% of data (Nigeria - Anambra State)
        "Aba",                 // 5% of data (Nigeria - Abia State)
        "Kano",                // 3% of data (Nigeria - Kano State)
        "Mumbai"               // 1% of data (India - Maharashtra)
    ]

    // City weights for distribution (must sum to 1.0)
    static let cityWeights: [String: Double] = [
        "Lagos Island": 0.50,
        "Shanghai": 0.08,
        "Beijing": 0.07,
        "Los Angeles": 0.06,
        "New York City": 0.06,
        "Ibadan": 0.08,
        "Onitsha": 0.06,
        "Aba": 0.05,
        "Kano": 0.03,
        "Mumbai": 0.01
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

    // Country code weights (must match location distribution)
    static let countryCodeWeights: [String: Double] = [
        "NG": 0.72,  // Nigeria (Lagos Island 50%, Ibadan 8%, Onitsha 6%, Aba 5%, Kano 3%)
        "CN": 0.15,  // China (Shanghai 8%, Beijing 7%)
        "US": 0.12,  // USA (Los Angeles 6%, New York City 6%)
        "IN": 0.01   // India (Mumbai 1%)
    ]

    /// Get a weighted random country code
    static func getWeightedCountryCode() -> String {
        let random = Double.random(in: 0...1)
        var cumulative = 0.0

        let codes = ["NG", "CN", "US", "IN"]
        for code in codes {
            cumulative += countryCodeWeights[code] ?? 0
            if random <= cumulative {
                return code
            }
        }

        return "NG" // Default to Nigeria
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