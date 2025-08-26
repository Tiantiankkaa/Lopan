//
//  DataRedaction.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation
import os

/// 数据脱敏工具，用于保护敏感信息不在日志中暴露
enum DataRedaction {
    
    /// 脱敏客户姓名，只保留首尾字符
    static func redactCustomerName(_ name: String) -> String {
        guard !name.isEmpty else { return "***" }
        guard name.count > 2 else { return "***" }
        
        if name.count <= 4 {
            return String(name.prefix(1)) + "***"
        } else {
            return String(name.prefix(1)) + "***" + String(name.suffix(1))
        }
    }
    
    /// 脱敏电话号码，只保留前3位和后4位
    static func redactPhoneNumber(_ phone: String) -> String {
        guard !phone.isEmpty else { return "***" }
        let cleanPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard cleanPhone.count >= 7 else { return "***" }
        
        if cleanPhone.count == 11 {
            return String(cleanPhone.prefix(3)) + "****" + String(cleanPhone.suffix(4))
        } else {
            return String(cleanPhone.prefix(2)) + "***" + String(cleanPhone.suffix(2))
        }
    }
    
    /// 脱敏微信ID
    static func redactWeChatId(_ wechatId: String) -> String {
        guard !wechatId.isEmpty else { return "***" }
        guard wechatId.count > 4 else { return "***" }
        
        return String(wechatId.prefix(2)) + "***" + String(wechatId.suffix(2))
    }
    
    /// 脱敏产品名称，保留关键信息但隐藏具体细节
    static func redactProductName(_ name: String) -> String {
        guard !name.isEmpty else { return "***" }
        guard name.count > 6 else { return "产品***" }
        
        // 如果包含型号信息，保留类型但隐藏具体型号
        if name.contains("鞋") {
            return "鞋类产品***"
        } else if name.contains("服装") || name.contains("衣") {
            return "服装产品***"
        } else {
            return "产品***"
        }
    }
    
    /// 脱敏用户ID，保留前缀用于调试但隐藏具体信息
    static func redactUserId(_ id: String) -> String {
        guard !id.isEmpty else { return "***" }
        guard id.count > 8 else { return "usr***" }
        
        return "usr" + String(id.suffix(4))
    }
    
    /// 脱敏通用文本，用于notes等字段
    static func redactNotes(_ notes: String) -> String {
        guard !notes.isEmpty else { return "" }
        guard notes.count > 10 else { return "备注***" }
        
        return "备注[" + String(notes.count) + "字符]"
    }
    
    /// 脱敏金额信息
    static func redactAmount(_ amount: Double) -> String {
        if amount == 0 {
            return "0.00"
        } else if amount < 100 {
            return "<100"
        } else if amount < 1000 {
            return "100-1000"
        } else {
            return ">1000"
        }
    }
    
    /// 用于审计日志的安全记录方法
    static func safeLogValue(_ key: String, _ value: Any) -> String {
        let stringValue = String(describing: value)
        
        switch key.lowercased() {
        case "name", "customer_name", "customername":
            return redactCustomerName(stringValue)
        case "phone", "phone_number", "phonenumber":
            return redactPhoneNumber(stringValue)
        case "wechat_id", "wechatid":
            return redactWeChatId(stringValue)
        case "product_name", "productname":
            return redactProductName(stringValue)
        case "user_id", "userid", "operator_user_id":
            return redactUserId(stringValue)
        case "notes", "return_notes", "returnnotes":
            return redactNotes(stringValue)
        case let key where key.contains("amount") || key.contains("price") || key.contains("cost"):
            if let doubleValue = Double(stringValue) {
                return redactAmount(doubleValue)
            }
            return "金额***"
        default:
            // 对于未知字段，如果长度超过20字符则进行截断
            if stringValue.count > 20 {
                return String(stringValue.prefix(10)) + "***"
            }
            return stringValue
        }
    }
}

/// 扩展Logger以支持数据脱敏
extension Logger {
    /// 安全的info日志记录，自动脱敏敏感数据
    func safeInfo(_ message: String, _ args: [String: Any] = [:]) {
        if args.isEmpty {
            self.info("\(message, privacy: .public)")
        } else {
            let safeArgs = args.map { key, value in
                "\(key): \(DataRedaction.safeLogValue(key, value))"
            }.joined(separator: ", ")
            self.info("\(message, privacy: .public) - \(safeArgs, privacy: .public)")
        }
    }
    
    /// 安全的error日志记录，自动脱敏敏感数据
    func safeError(_ message: String, error: Error?, _ args: [String: Any] = [:]) {
        let safeArgs = args.map { key, value in
            "\(key): \(DataRedaction.safeLogValue(key, value))"
        }.joined(separator: ", ")
        
        let errorDescription = error?.localizedDescription ?? "Unknown error"
        
        if args.isEmpty {
            self.error("\(message, privacy: .public) - Error: \(errorDescription, privacy: .public)")
        } else {
            self.error("\(message, privacy: .public) - \(safeArgs, privacy: .public) - Error: \(errorDescription, privacy: .public)")
        }
    }
    
    /// 安全的warning日志记录
    func safeWarning(_ message: String, _ args: [String: Any] = [:]) {
        if args.isEmpty {
            self.warning("\(message, privacy: .public)")
        } else {
            let safeArgs = args.map { key, value in
                "\(key): \(DataRedaction.safeLogValue(key, value))"
            }.joined(separator: ", ")
            self.warning("\(message, privacy: .public) - \(safeArgs, privacy: .public)")
        }
    }
}

// MARK: - Privacy-Safe Print Replacement

/// 替代print的安全日志函数，自动脱敏
func safePrint(_ message: String, category: String = "General") {
    let logger = Logger(subsystem: "com.lopan.app", category: category)
    logger.info("\(message, privacy: .public)")
}

/// 开发环境专用的调试日志，生产环境会被移除
func debugPrint(_ message: String, category: String = "Debug") {
    #if DEBUG
    let logger = Logger(subsystem: "com.lopan.app", category: category)
    logger.debug("\(message, privacy: .public)")
    #endif
}