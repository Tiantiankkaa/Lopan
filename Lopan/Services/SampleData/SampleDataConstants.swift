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
    static let customerCount = 500
    static let productCount = 300
    static let outOfStockRecordCount = 20000
    static let batchSize = 500
    
    // MARK: - 时间范围
    static let startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
    static let endDate = Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 26))!
    
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
        
        // 客户类型分布
        static let importantCustomers = 100        // 重要客户
        static let standardCustomers = 200         // 标准客户
        static let regularCustomers = 200          // 普通客户
    }
    
    // MARK: - 月份记录分布
    static let monthlyDistribution: [Int: Int] = [
        1: 1500,    // 1月：春节前备货
        2: 800,     // 2月：春节期间较少
        3: 2200,    // 3月：春季新品
        4: 2500,    // 4月：换季高峰
        5: 2800,    // 5月：夏季开始
        6: 3200,    // 6月：618促销
        7: 3500,    // 7月：暑期高峰
        8: 3500     // 8月：持续高峰（截至20日）
    ]
    
    // MARK: - 城市列表
    static let cities = [
        "北京", "上海", "广州", "深圳", "杭州",
        "成都", "武汉", "西安", "南京", "重庆",
        "天津", "苏州", "青岛", "长沙", "郑州",
        "无锡", "宁波", "佛山", "济南", "厦门"
    ]
    
    // MARK: - 产品类别
    enum ProductCategory: String, CaseIterable {
        case tops = "上衣类"           // 100个产品
        case pants = "裤装类"          // 80个产品
        case dresses = "裙装类"        // 60个产品
        case shoes = "鞋类"           // 40个产品
        case accessories = "配饰类"    // 20个产品
        
        var count: Int {
            switch self {
            case .tops: return 100
            case .pants: return 80
            case .dresses: return 60
            case .shoes: return 40
            case .accessories: return 20
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