//
//  SecureKeychain.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//

import Foundation
import Security
import CryptoKit
import os

/// 安全的Keychain包装器，用于存储敏感信息
public final class SecureKeychain {
    
    private let logger = Logger(subsystem: "com.lopan.app", category: "SecureKeychain")
    private let serviceName: String
    
    public init(serviceName: String = "com.lopan.app") {
        self.serviceName = serviceName
    }
    
    // MARK: - Public API
    
    /// 存储数据到Keychain
    public func store(_ data: Data, account: String, accessGroup: String? = nil) throws {
        // 先删除可能存在的旧数据
        try? delete(account: account, accessGroup: accessGroup)
        
        var attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        if let accessGroup = accessGroup {
            attributes[kSecAttrAccessGroup] = accessGroup
        }
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.safeError("Failed to store item in Keychain", error: KeychainError.storeFailed(status))
            throw KeychainError.storeFailed(status)
        }
        
        logger.info("Successfully stored item in Keychain")
    }
    
    /// 从Keychain加载数据
    public func load(account: String, accessGroup: String? = nil) throws -> Data {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            } else {
                logger.safeError("Failed to load item from Keychain", error: KeychainError.loadFailed(status))
                throw KeychainError.loadFailed(status)
            }
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        logger.info("Successfully loaded item from Keychain")
        return data
    }
    
    /// 更新Keychain中的数据
    public func update(_ data: Data, account: String, accessGroup: String? = nil) throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // 如果项目不存在，则创建它
                try store(data, account: account, accessGroup: accessGroup)
                return
            } else {
                logger.safeError("Failed to update item in Keychain", error: KeychainError.updateFailed(status))
                throw KeychainError.updateFailed(status)
            }
        }
        
        logger.info("Successfully updated item in Keychain")
    }
    
    /// 删除Keychain中的数据
    public func delete(account: String, accessGroup: String? = nil) throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.safeError("Failed to delete item from Keychain", error: KeychainError.deleteFailed(status))
            throw KeychainError.deleteFailed(status)
        }
        
        logger.info("Successfully deleted item from Keychain")
    }
    
    /// 检查项目是否存在
    public func exists(account: String, accessGroup: String? = nil) -> Bool {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: account,
            kSecReturnData: false,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// 列出所有账户（用于调试和管理）
    public func listAllAccounts(accessGroup: String? = nil) throws -> [String] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            } else {
                throw KeychainError.queryFailed(status)
            }
        }
        
        guard let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }
    
    // MARK: - Convenience Methods for Common Data Types
    
    /// 存储字符串到Keychain
    public func store(_ string: String, account: String, accessGroup: String? = nil) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try store(data, account: account, accessGroup: accessGroup)
    }
    
    /// 从Keychain加载字符串
    public func loadString(account: String, accessGroup: String? = nil) throws -> String {
        let data = try load(account: account, accessGroup: accessGroup)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    /// 存储SymmetricKey到Keychain
    public func store(_ key: SymmetricKey, account: String, accessGroup: String? = nil) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try store(keyData, account: account, accessGroup: accessGroup)
    }
    
    /// 从Keychain加载SymmetricKey
    public func loadSymmetricKey(account: String, accessGroup: String? = nil) throws -> SymmetricKey {
        let data = try load(account: account, accessGroup: accessGroup)
        return SymmetricKey(data: data)
    }
    
    /// 清除所有Keychain项目（谨慎使用）
    public func clearAll(accessGroup: String? = nil) throws {
        let accounts = try listAllAccounts(accessGroup: accessGroup)
        for account in accounts {
            try delete(account: account, accessGroup: accessGroup)
        }
        logger.warning("Cleared all Keychain items")
    }
}

// MARK: - Keychain Errors

public enum KeychainError: Error, LocalizedError {
    case storeFailed(OSStatus)
    case loadFailed(OSStatus)
    case updateFailed(OSStatus)
    case deleteFailed(OSStatus)
    case queryFailed(OSStatus)
    case itemNotFound
    case invalidData
    case duplicateItem
    
    public var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "无法存储到Keychain，错误代码：\(status)"
        case .loadFailed(let status):
            return "无法从Keychain加载，错误代码：\(status)"
        case .updateFailed(let status):
            return "无法更新Keychain项目，错误代码：\(status)"
        case .deleteFailed(let status):
            return "无法删除Keychain项目，错误代码：\(status)"
        case .queryFailed(let status):
            return "Keychain查询失败，错误代码：\(status)"
        case .itemNotFound:
            return "Keychain中未找到指定项目"
        case .invalidData:
            return "无效的数据格式"
        case .duplicateItem:
            return "重复的Keychain项目"
        }
    }
}

// MARK: - Security Utilities

public extension SecureKeychain {
    
    /// 生成安全的随机密钥
    static func generateRandomKey(bitCount: Int = 256) -> SymmetricKey {
        return SymmetricKey(size: .init(bitCount: bitCount))
    }
    
    /// 验证Keychain可用性
    func validateKeychainAccess() throws {
        let testAccount = "keychain_test_\(UUID().uuidString)"
        let testData = Data("test".utf8)
        
        // 测试存储
        try store(testData, account: testAccount)
        
        // 测试加载
        let loadedData = try load(account: testAccount)
        guard loadedData == testData else {
            throw KeychainError.invalidData
        }
        
        // 清理测试数据
        try delete(account: testAccount)
        
        logger.info("Keychain access validation successful")
    }
}

// MARK: - Thread Safety

extension SecureKeychain {
    
    private static let queue = DispatchQueue(label: "com.lopan.keychain", qos: .userInitiated, attributes: .concurrent)
    
    /// 线程安全的存储操作
    public func storeAsync(_ data: Data, account: String, accessGroup: String? = nil) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                do {
                    try self.store(data, account: account, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 线程安全的加载操作
    public func loadAsync(account: String, accessGroup: String? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                do {
                    let data = try self.load(account: account, accessGroup: accessGroup)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}