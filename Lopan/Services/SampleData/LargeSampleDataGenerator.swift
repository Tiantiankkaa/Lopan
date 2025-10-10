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

    /// 生成客户名称 (Location-appropriate names based on country/city)
    /// - Parameters:
    ///   - index: 客户编号
    ///   - city: City name to determine name style
    /// - Returns: 客户名称
    static func generateCustomerName(index: Int, for city: String) -> String {
        // Determine country/region based on city
        switch city {
        case "Lagos Island", "Ibadan", "Onitsha", "Aba", "Kano":
            return generateNigerianName(index: index)
        case "Shanghai", "Beijing":
            return generateChineseName(index: index)
        case "Los Angeles", "New York City":
            return generateAmericanName(index: index)
        case "Mumbai":
            return generateIndianName(index: index)
        default:
            return generateAmericanName(index: index)
        }
    }

    /// Generate Nigerian name
    private static func generateNigerianName(index: Int) -> String {
        let firstNames = ["Oluwaseun", "Chioma", "Ibrahim", "Ngozi", "Emeka", "Aisha", "Chukwudi", "Fatima", "Adeola", "Bisi",
                          "Obinna", "Zainab", "Kunle", "Halima", "Chinedu", "Amina", "Tunde", "Kemi", "Uche", "Yetunde",
                          "Adewale", "Blessing", "Musa", "Nneka", "Ahmed", "Ifeoma", "Babatunde", "Chidinma", "Yusuf", "Nkechi"]
        let lastNames = ["Adeyemi", "Okafor", "Musa", "Eze", "Ibrahim", "Nwosu", "Aliyu", "Chukwu", "Mohammed", "Onyeka",
                         "Bello", "Okeke", "Adebayo", "Chibueze", "Hassan", "Okonkwo", "Suleiman", "Nnamdi", "Usman", "Chidi"]

        let firstName = firstNames[index % firstNames.count]
        let lastName = lastNames[(index / firstNames.count) % lastNames.count]

        if index >= (firstNames.count * lastNames.count) {
            let suffix = index / (firstNames.count * lastNames.count) + 1
            return "\(firstName) \(lastName) \(suffix)"
        }

        return "\(firstName) \(lastName)"
    }

    /// Generate Chinese name (with English transliteration)
    private static func generateChineseName(index: Int) -> String {
        let firstNames = ["Wei", "Ming", "Fang", "Jing", "Lei", "Li", "Xiaoming", "Yan", "Hong", "Qiang",
                          "Xiu", "Ying", "Jun", "Hui", "Mei", "Peng", "Ling", "Bo", "Xiaohua", "Jie",
                          "Rui", "Dan", "Tao", "Xin", "Feng", "Lan", "Hao", "Yun", "Xiang", "Na"]
        let lastNames = ["Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou",
                         "Xu", "Sun", "Ma", "Zhu", "Hu", "Guo", "He", "Lin", "Gao", "Luo"]

        let firstName = firstNames[index % firstNames.count]
        let lastName = lastNames[(index / firstNames.count) % lastNames.count]

        // Chinese names: Last name first
        if index >= (firstNames.count * lastNames.count) {
            let suffix = index / (firstNames.count * lastNames.count) + 1
            return "\(lastName) \(firstName) \(suffix)"
        }

        return "\(lastName) \(firstName)"
    }

    /// Generate American name
    private static func generateAmericanName(index: Int) -> String {
        let firstNames = ["John", "Mary", "David", "Sarah", "Michael", "Lisa", "Robert", "Jennifer", "William", "Linda",
                          "James", "Patricia", "Richard", "Elizabeth", "Charles", "Susan", "Joseph", "Jessica", "Thomas", "Karen",
                          "Christopher", "Nancy", "Daniel", "Barbara", "Matthew", "Margaret", "Anthony", "Sandra", "Mark", "Ashley"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
                         "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin"]

        let firstName = firstNames[index % firstNames.count]
        let lastName = lastNames[(index / firstNames.count) % lastNames.count]

        if index >= (firstNames.count * lastNames.count) {
            let suffix = index / (firstNames.count * lastNames.count) + 1
            return "\(firstName) \(lastName) \(suffix)"
        }

        return "\(firstName) \(lastName)"
    }

    /// Generate Indian name
    private static func generateIndianName(index: Int) -> String {
        let firstNames = ["Rajesh", "Priya", "Amit", "Anjali", "Rahul", "Neha", "Vikram", "Pooja", "Arjun", "Divya",
                          "Ravi", "Kavya", "Arun", "Sneha", "Suresh", "Deepika", "Karan", "Meera", "Vivek", "Ritu",
                          "Sandeep", "Sonia", "Manoj", "Preeti", "Anil", "Simran", "Nitin", "Anita", "Rakesh", "Swati"]
        let lastNames = ["Kumar", "Sharma", "Patel", "Singh", "Mehta", "Gupta", "Reddy", "Joshi", "Kapoor", "Nair",
                         "Rao", "Desai", "Verma", "Iyer", "Bhatt", "Shah", "Chopra", "Malhotra", "Agarwal", "Kulkarni"]

        let firstName = firstNames[index % firstNames.count]
        let lastName = lastNames[(index / firstNames.count) % lastNames.count]

        if index >= (firstNames.count * lastNames.count) {
            let suffix = index / (firstNames.count * lastNames.count) + 1
            return "\(firstName) \(lastName) \(suffix)"
        }

        return "\(firstName) \(lastName)"
    }

    /// 生成电话号码 (with proper dial code)
    /// - Parameter countryCode: Country code (e.g., "NG", "CN", "US", "IN")
    /// - Returns: Phone number with dial code
    static func generatePhoneNumber(for countryCode: String) -> String {
        switch countryCode {
        case "NG": // Nigeria +234
            let prefix = ["803", "806", "807", "810", "813", "814", "816", "903", "906"].randomElement()!
            let suffix = String(format: "%07d", Int.random(in: 1000000...9999999))
            return "+234\(prefix)\(suffix)"
        case "CN": // China +86
            let prefixes = ["138", "139", "150", "151", "188", "189"]
            let prefix = prefixes.randomElement()!
            let suffix = String(format: "%08d", Int.random(in: 10000000...99999999))
            return "+86\(prefix)\(suffix)"
        case "US": // USA +1
            let areaCode = Int.random(in: 200...999)
            let prefix = Int.random(in: 200...999)
            let line = Int.random(in: 1000...9999)
            return "+1\(areaCode)\(prefix)\(line)"
        case "IN": // India +91
            let prefixes = ["98", "99", "97", "96", "95"]
            let prefix = prefixes.randomElement()!
            let suffix = String(format: "%08d", Int.random(in: 10000000...99999999))
            return "+91\(prefix)\(suffix)"
        default:
            let prefix = ["803", "806", "807", "810"].randomElement()!
            let suffix = String(format: "%07d", Int.random(in: 1000000...9999999))
            return "+234\(prefix)\(suffix)" // Default to Nigeria
        }
    }

    /// 生成固定价格 (基于产品名称)
    /// - Parameter productName: Product name
    /// - Returns: Fixed price for consistency
    static func generateFixedPrice(for productName: String) -> Double {
        // Generate consistent price based on product name hash
        let hash = abs(productName.hashValue)
        let priceRanges = [
            (29.99...49.99),   // Low range
            (50.00...99.99),   // Mid range
            (100.00...199.99), // High range
            (200.00...499.99)  // Premium range
        ]

        let rangeIndex = hash % priceRanges.count
        let range = priceRanges[rangeIndex]
        let price = Double.random(in: range)

        // Round to .99 ending
        return floor(price) + 0.99
    }

    /// 生成销售行项目
    /// - Parameter products: Available products
    /// - Returns: Array of sales line items
    static func generateSalesLineItems(from products: [Product]) -> [SalesLineItem] {
        let itemCount = Int.random(in: 1...8) // 1-8 products per sale
        var items: [SalesLineItem] = []

        for _ in 0..<itemCount {
            guard let product = products.randomElement() else { continue }

            let quantity = Int.random(in: 1...20)
            let unitPrice = Decimal(product.price)

            let item = SalesLineItem(
                productId: product.id,
                productName: product.name,
                quantity: quantity,
                unitPrice: unitPrice
            )
            items.append(item)
        }

        return items
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

    /// 生成唯一SKU编号
    /// - Parameter index: 产品索引 (0-999)
    /// - Returns: 唯一SKU (e.g., "PRD-000001")
    static func generateUniqueSKU(index: Int) -> String {
        return String(format: "PRD-%06d", index + 1)
    }

    /// 生成真实的英文产品名称
    /// - Parameter index: 产品索引
    /// - Returns: 英文产品名称
    static func generateProductName(index: Int) -> String {
        // Real-world English product names
        let productNames = [
            // Apparel - Tops
            "Classic White T-Shirt", "Black Cotton Tee", "V-Neck Basic Shirt", "Crew Neck T-Shirt",
            "Long Sleeve Henley", "Polo Shirt", "Button-Down Oxford Shirt", "Flannel Plaid Shirt",
            "Hooded Sweatshirt", "Pullover Hoodie", "Zip-Up Hoodie", "Crewneck Sweatshirt",
            "Cardigan Sweater", "Cable Knit Sweater", "Turtleneck Sweater", "V-Neck Pullover",
            "Denim Jacket", "Bomber Jacket", "Leather Jacket", "Windbreaker",
            "Puffer Jacket", "Down Vest", "Track Jacket", "Varsity Jacket",

            // Apparel - Bottoms
            "Slim Fit Jeans", "Straight Leg Denim", "Bootcut Jeans", "Skinny Jeans",
            "Relaxed Fit Jeans", "Dark Wash Jeans", "Light Wash Jeans", "Distressed Denim",
            "Chino Pants", "Cargo Pants", "Khaki Trousers", "Dress Pants",
            "Joggers", "Sweatpants", "Track Pants", "Athletic Shorts",
            "Cargo Shorts", "Denim Shorts", "Board Shorts", "Basketball Shorts",

            // Apparel - Dresses & Skirts
            "Little Black Dress", "Maxi Dress", "Midi Dress", "Wrap Dress",
            "Shift Dress", "A-Line Dress", "Sundress", "Cocktail Dress",
            "Pencil Skirt", "A-Line Skirt", "Pleated Skirt", "Denim Skirt",
            "Maxi Skirt", "Mini Skirt", "Midi Skirt", "Wrap Skirt",

            // Footwear
            "Running Shoes", "Cross Training Sneakers", "Walking Shoes", "Trail Running Shoes",
            "Basketball Sneakers", "Tennis Shoes", "Skate Shoes", "Canvas Sneakers",
            "Leather Oxfords", "Derby Shoes", "Loafers", "Monk Strap Shoes",
            "Chelsea Boots", "Combat Boots", "Chukka Boots", "Work Boots",
            "Ankle Boots", "Knee High Boots", "Riding Boots", "Rain Boots",
            "Flip Flops", "Slide Sandals", "Sport Sandals", "Gladiator Sandals",

            // Accessories
            "Leather Belt", "Canvas Belt", "Braided Belt", "Reversible Belt",
            "Baseball Cap", "Snapback Hat", "Beanie", "Trucker Hat",
            "Bucket Hat", "Wide Brim Hat", "Fedora", "Panama Hat",
            "Wool Scarf", "Infinity Scarf", "Silk Scarf", "Cashmere Scarf",
            "Leather Gloves", "Wool Gloves", "Touchscreen Gloves", "Mittens",
            "Backpack", "Messenger Bag", "Tote Bag", "Duffel Bag",
            "Crossbody Bag", "Clutch", "Wallet", "Card Holder",
            "Sport Watch", "Digital Watch", "Analog Watch", "Smartwatch",
            "Sunglasses", "Reading Glasses", "Blue Light Glasses", "Safety Glasses",

            // Activewear
            "Compression Shirt", "Athletic Tank Top", "Sports Bra", "Performance Tee",
            "Yoga Pants", "Leggings", "Running Tights", "Training Shorts",
            "Windbreaker Jacket", "Rain Jacket", "Fleece Pullover", "Softshell Jacket"
        ]

        let baseName = productNames[index % productNames.count]

        // Add variations for products beyond the base list
        if index >= productNames.count {
            let variations = ["Pro", "Elite", "Premium", "Sport", "Classic", "Essential", "Advanced"]
            let variation = variations[(index / productNames.count) % variations.count]
            return "\(variation) \(baseName)"
        }

        return baseName
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
    /// - Parameter salespersonIds: 可选的业务员ID数组，用于在demo模式下生成数据
    /// - Returns: 创建者ID
    static func generateCreatorId(from salespersonIds: [String]? = nil) -> String {
        // 如果提供了真实的业务员ID列表，优先使用
        if let ids = salespersonIds, !ids.isEmpty {
            return ids.randomElement()!
        }
        // 否则回退到硬编码ID（向后兼容）
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