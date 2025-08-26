//
//  ConfigurationSecurityService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import CryptoKit
import SwiftUI
import os

// MARK: - Configuration Security Service (配置安全服务)

/// Service responsible for securing configuration data and managing access
/// 负责保护配置数据和管理访问的服务
@MainActor
class ConfigurationSecurityService: ObservableObject {
    
    // MARK: - Dependencies
    private let configurationService: SystemConfigurationService
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private let permissionService: AdvancedPermissionService
    
    // MARK: - State
    @Published var encryptionStatus: EncryptionStatus = .disabled
    @Published var securityPolicies: [SecurityPolicy] = []
    @Published var activeSecurityEvents: [SecurityEvent] = []
    @Published var configurationBackups: [SecureBackup] = []
    @Published var isEncryptionEnabled = false
    @Published var lastSecurityScan: Date?
    
    // MARK: - Security Configuration
    private let securityDirectory: URL
    private let keychain = SecureKeychain(serviceName: "com.lopan.app.security")
    private let encryptionKeyIdentifier = "lopan.configuration.encryption"
    private let maxFailedAttempts = 3
    private var failedDecryptionAttempts: [String: Int] = [:]
    private let logger = Logger(subsystem: "com.lopan.app", category: "ConfigurationSecurity")
    
    init(
        configurationService: SystemConfigurationService,
        auditService: NewAuditingService,
        authService: AuthenticationService,
        permissionService: AdvancedPermissionService
    ) {
        self.configurationService = configurationService
        self.auditService = auditService
        self.authService = authService
        self.permissionService = permissionService
        
        // Setup security directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.securityDirectory = documentsURL.appendingPathComponent("ConfigurationSecurity")
        
        setupSecurityEnvironment()
        loadSecurityPolicies()
        loadEncryptionStatus()
    }
    
    // MARK: - Encryption Management (加密管理)
    
    /// Enable configuration encryption
    /// 启用配置加密
    func enableEncryption(masterPassword: String) async throws {
        let permissionResult = await permissionService.hasPermission(.manageSystemSecurity)
        guard permissionResult.isGranted else {
            throw SecurityError.insufficientPermissions
        }
        
        // Validate master password strength
        try validateMasterPassword(masterPassword)
        
        // Generate encryption key
        let encryptionKey = try generateEncryptionKey(from: masterPassword)
        
        // Store key securely
        try storeEncryptionKey(encryptionKey)
        
        // Encrypt existing sensitive configurations
        try await encryptSensitiveConfigurations(using: encryptionKey)
        
        encryptionStatus = .enabled(algorithm: "AES-GCM-256")
        isEncryptionEnabled = true
        
        // Create security event
        let event = SecurityEvent(
            type: .encryptionEnabled,
            severity: .high,
            message: "配置加密已启用",
            details: ["algorithm": "AES-GCM-256"]
        )
        activeSecurityEvents.append(event)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_encryption_enabled",
            userId: authService.currentUser?.id ?? "unknown",
            details: ["algorithm": "AES-GCM-256"]
        )
        
        saveEncryptionStatus()
    }
    
    /// Disable configuration encryption
    /// 禁用配置加密
    func disableEncryption(masterPassword: String) async throws {
        let permissionResult = await permissionService.hasPermission(.manageSystemSecurity)
        guard permissionResult.isGranted else {
            throw SecurityError.insufficientPermissions
        }
        
        // Verify master password
        let encryptionKey = try generateEncryptionKey(from: masterPassword)
        try verifyEncryptionKey(encryptionKey)
        
        // Decrypt all encrypted configurations
        try await decryptSensitiveConfigurations(using: encryptionKey)
        
        // Remove encryption key
        try removeEncryptionKey()
        
        encryptionStatus = .disabled
        isEncryptionEnabled = false
        
        // Create security event
        let event = SecurityEvent(
            type: .encryptionDisabled,
            severity: .medium,
            message: "配置加密已禁用",
            details: [:]
        )
        activeSecurityEvents.append(event)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_encryption_disabled",
            userId: authService.currentUser?.id ?? "unknown",
            details: [:]
        )
        
        saveEncryptionStatus()
    }
    
    /// Rotate encryption key
    /// 轮换加密密钥
    func rotateEncryptionKey(currentPassword: String, newPassword: String) async throws {
        let permissionResult = await permissionService.hasPermission(.manageSystemSecurity)
        guard permissionResult.isGranted else {
            throw SecurityError.insufficientPermissions
        }
        
        // Verify current password
        let currentKey = try generateEncryptionKey(from: currentPassword)
        try verifyEncryptionKey(currentKey)
        
        // Generate new key
        let newKey = try generateEncryptionKey(from: newPassword)
        
        // Re-encrypt all sensitive configurations
        try await reencryptSensitiveConfigurations(from: currentKey, to: newKey)
        
        // Update stored key
        try storeEncryptionKey(newKey)
        
        // Create security event
        let event = SecurityEvent(
            type: .keyRotation,
            severity: .high,
            message: "加密密钥已轮换",
            details: ["timestamp": Date().timeIntervalSince1970.description]
        )
        activeSecurityEvents.append(event)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_encryption_key_rotated",
            userId: authService.currentUser?.id ?? "unknown",
            details: [:]
        )
    }
    
    // MARK: - Configuration Access Control (配置访问控制)
    
    /// Check if user has access to specific configuration
    /// 检查用户是否有权访问特定配置
    func hasConfigurationAccess(_ key: String, operation: ConfigurationOperation) async -> Bool {
        // Check basic permissions
        let hasBasicPermission = await permissionService.hasPermission(.viewSystemConfiguration)
        if !hasBasicPermission.isGranted { return false }
        
        // Check operation-specific permissions
        switch operation {
        case .read:
            let readPermission = await permissionService.hasPermission(.viewSystemConfiguration)
            return readPermission.isGranted
        case .write:
            let writePermission = await permissionService.hasPermission(.manageSystemSettings)
            return writePermission.isGranted
        case .delete:
            let deletePermission1 = await permissionService.hasPermission(.manageSystemSettings)
            let deletePermission2 = await permissionService.hasPermission(.manageSystemSecurity)
            return deletePermission1.isGranted && deletePermission2.isGranted
        }
    }
    
    /// Apply security policies to configuration access
    /// 对配置访问应用安全策略
    func applySecurityPolicies(for key: String, operation: ConfigurationOperation) async throws {
        for policy in securityPolicies {
            if policy.appliesTo(configuration: key, operation: operation) {
                try await policy.evaluate(
                    userId: authService.currentUser?.id ?? "unknown",
                    configurationKey: key,
                    operation: operation
                )
            }
        }
    }
    
    /// Log configuration access attempt
    /// 记录配置访问尝试
    func logConfigurationAccess(
        _ key: String,
        operation: ConfigurationOperation,
        success: Bool,
        details: [String: String] = [:]
    ) async {
        var auditDetails = details
        auditDetails["configuration_key"] = key
        auditDetails["operation"] = operation.rawValue
        auditDetails["success"] = success.description
        auditDetails["user_role"] = authService.currentUser?.primaryRole.rawValue ?? "unknown"
        
        let eventType = success ? "configuration_access_granted" : "configuration_access_denied"
        
        try? await auditService.logSecurityEvent(
            event: eventType,
            userId: authService.currentUser?.id ?? "unknown",
            details: auditDetails
        )
        
        // Create security event for failed access attempts
        if !success {
            let event = SecurityEvent(
                type: .unauthorizedAccess,
                severity: .medium,
                message: "未授权的配置访问尝试: \(key)",
                details: auditDetails
            )
            activeSecurityEvents.append(event)
        }
    }
    
    // MARK: - Secure Backup Management (安全备份管理)
    
    /// Create secure backup of configurations
    /// 创建配置的安全备份
    func createSecureBackup(name: String, includeEncryptedData: Bool = false) async throws -> SecureBackup {
        let backupPermission = await permissionService.hasPermission(.backupData)
        guard backupPermission.isGranted else {
            throw SecurityError.insufficientPermissions
        }
        
        let backup = SecureBackup(
            name: name,
            createdBy: authService.currentUser?.id ?? "unknown",
            includesEncryptedData: includeEncryptedData
        )
        
        // Export configuration data
        let configurationData = try await exportConfigurationData(includeEncrypted: includeEncryptedData)
        
        // Encrypt backup if encryption is enabled
        let backupData: Data
        if isEncryptionEnabled {
            let encryptionKey = try getEncryptionKey()
            backupData = try encryptData(configurationData, using: encryptionKey)
        } else {
            backupData = configurationData
        }
        
        // Save backup to secure location
        let backupURL = securityDirectory.appendingPathComponent("backups").appendingPathComponent("\(backup.id).backup")
        try backupData.write(to: backupURL)
        
        // Update backup info
        backup.fileURL = backupURL
        backup.fileSize = Int64(backupData.count)
        backup.checksum = calculateChecksum(backupData)
        
        configurationBackups.append(backup)
        saveBackupManifest()
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "secure_configuration_backup_created",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "backup_id": backup.id,
                "backup_name": name,
                "includes_encrypted": includeEncryptedData.description
            ]
        )
        
        return backup
    }
    
    /// Restore from secure backup
    /// 从安全备份恢复
    func restoreFromSecureBackup(_ backupId: String, masterPassword: String? = nil) async throws {
        let restorePermission = await permissionService.hasPermission(.restoreData)
        guard restorePermission.isGranted else {
            throw SecurityError.insufficientPermissions
        }
        
        guard let backup = configurationBackups.first(where: { $0.id == backupId }) else {
            throw SecurityError.backupNotFound
        }
        
        // Read backup data
        guard let backupURL = backup.fileURL else {
            throw SecurityError.invalidBackup
        }
        
        let backupData = try Data(contentsOf: backupURL)
        
        // Verify checksum
        let calculatedChecksum = calculateChecksum(backupData)
        guard calculatedChecksum == backup.checksum else {
            throw SecurityError.checksumMismatch
        }
        
        // Decrypt backup if needed
        let configurationData: Data
        if backup.isEncrypted {
            guard let password = masterPassword else {
                throw SecurityError.masterPasswordRequired
            }
            
            let encryptionKey = try generateEncryptionKey(from: password)
            configurationData = try decryptData(backupData, using: encryptionKey)
        } else {
            configurationData = backupData
        }
        
        // Import configuration data
        try await importConfigurationData(configurationData)
        
        // Create security event
        let event = SecurityEvent(
            type: .configurationRestored,
            severity: .high,
            message: "配置已从安全备份恢复",
            details: [
                "backup_id": backupId,
                "backup_name": backup.name
            ]
        )
        activeSecurityEvents.append(event)
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_restored_from_backup",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "backup_id": backupId,
                "backup_name": backup.name
            ]
        )
    }
    
    // MARK: - Security Scanning (安全扫描)
    
    /// Perform security scan on configurations
    /// 对配置执行安全扫描
    func performSecurityScan() async throws -> SecurityScanResult {
        let viewPermission = await permissionService.hasPermission(.viewSystemConfiguration)
        guard viewPermission.isGranted else {
            throw SecurityError.insufficientPermissions
        }
        
        var findings: [SecurityFinding] = []
        
        // Check for weak passwords
        findings.append(contentsOf: checkWeakPasswords())
        
        // Check for insecure configurations
        findings.append(contentsOf: checkInsecureConfigurations())
        
        // Check encryption status
        findings.append(contentsOf: checkEncryptionStatus())
        
        // Check access patterns
        findings.append(contentsOf: await checkAccessPatterns())
        
        // Check for default values in production
        findings.append(contentsOf: checkDefaultValues())
        
        let result = SecurityScanResult(
            scanId: UUID().uuidString,
            scannedAt: Date(),
            scannedBy: authService.currentUser?.id ?? "unknown",
            findings: findings,
            score: calculateSecurityScore(findings),
            recommendations: generateRecommendations(findings)
        )
        
        lastSecurityScan = Date()
        
        // Create security event for critical findings
        let criticalFindings = findings.filter { $0.severity == .critical }
        if !criticalFindings.isEmpty {
            let event = SecurityEvent(
                type: .securityViolation,
                severity: .critical,
                message: "安全扫描发现 \(criticalFindings.count) 个严重问题",
                details: ["scan_id": result.scanId]
            )
            activeSecurityEvents.append(event)
        }
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "configuration_security_scan_completed",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "scan_id": result.scanId,
                "findings_count": "\(findings.count)",
                "critical_findings": "\(criticalFindings.count)",
                "security_score": "\(result.score)"
            ]
        )
        
        return result
    }
    
    // MARK: - Private Methods (私有方法)
    
    private func setupSecurityEnvironment() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: securityDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: securityDirectory.appendingPathComponent("backups"), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: securityDirectory.appendingPathComponent("keys"), withIntermediateDirectories: true)
    }
    
    private func loadSecurityPolicies() {
        securityPolicies = [
            SecurityPolicy(
                id: "sensitive_config_access",
                name: "敏感配置访问控制",
                description: "限制对敏感配置的访问",
                configurationPattern: "security\\.*|password\\.*|key\\.*",
                operations: [.read, .write],
                requiredRole: .administrator,
                additionalChecks: { userId, configKey, operation in
                    // Additional security checks could be implemented here
                    return true
                }
            ),
            
            SecurityPolicy(
                id: "production_config_changes",
                name: "生产环境配置变更",
                description: "生产环境配置变更需要审批",
                configurationPattern: ".*",
                operations: [.write],
                requiredRole: .administrator,
                requiresApproval: true,
                additionalChecks: { userId, configKey, operation in
                    // Check if in production environment
                    return true
                }
            )
        ]
    }
    
    private func loadEncryptionStatus() {
        let statusURL = securityDirectory.appendingPathComponent("encryption_status.json")
        
        if FileManager.default.fileExists(atPath: statusURL.path) {
            do {
                let data = try Data(contentsOf: statusURL)
                let status = try JSONDecoder().decode(EncryptionStatus.self, from: data)
                encryptionStatus = status
                isEncryptionEnabled = status.isEnabled
            } catch {
                print("Failed to load encryption status: \(error)")
            }
        }
    }
    
    private func saveEncryptionStatus() {
        let statusURL = securityDirectory.appendingPathComponent("encryption_status.json")
        do {
            let data = try JSONEncoder().encode(encryptionStatus)
            try data.write(to: statusURL)
        } catch {
            print("Failed to save encryption status: \(error)")
        }
    }
    
    private func validateMasterPassword(_ password: String) throws {
        // Minimum length check
        guard password.count >= 12 else {
            throw SecurityError.weakMasterPassword("密码长度至少12个字符")
        }
        
        // Character complexity check
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigits = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil
        
        guard hasUppercase && hasLowercase && hasDigits && hasSpecialChars else {
            throw SecurityError.weakMasterPassword("密码必须包含大小写字母、数字和特殊字符")
        }
    }
    
    private func generateEncryptionKey(from password: String) throws -> SymmetricKey {
        // Use PBKDF2 to derive key from password
        let salt = "lopan.configuration.salt".data(using: .utf8)!
        let passwordData = password.data(using: .utf8)!
        
        let derivedKey = try HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data(),
            outputByteCount: 32
        )
        
        return derivedKey
    }
    
    private func storeEncryptionKey(_ key: SymmetricKey) throws {
        do {
            try keychain.store(key, account: encryptionKeyIdentifier)
            logger.info("Encryption key stored securely in Keychain")
        } catch {
            logger.safeError("Failed to store encryption key in Keychain", error: error)
            throw SecurityError.encryptionKeyStorageFailed
        }
    }
    
    private func getEncryptionKey() throws -> SymmetricKey {
        do {
            let key = try keychain.loadSymmetricKey(account: encryptionKeyIdentifier)
            logger.info("Encryption key loaded from Keychain")
            return key
        } catch KeychainError.itemNotFound {
            logger.warning("Encryption key not found in Keychain")
            throw SecurityError.encryptionKeyNotFound
        } catch {
            logger.safeError("Failed to load encryption key from Keychain", error: error)
            throw SecurityError.encryptionKeyLoadFailed
        }
    }
    
    private func verifyEncryptionKey(_ key: SymmetricKey) throws {
        let storedKey = try getEncryptionKey()
        let providedKeyData = key.withUnsafeBytes { Data($0) }
        let storedKeyData = storedKey.withUnsafeBytes { Data($0) }
        
        guard providedKeyData == storedKeyData else {
            throw SecurityError.invalidMasterPassword
        }
    }
    
    private func removeEncryptionKey() throws {
        do {
            try keychain.delete(account: encryptionKeyIdentifier)
            logger.info("Encryption key removed from Keychain")
        } catch {
            logger.safeError("Failed to remove encryption key from Keychain", error: error)
            throw SecurityError.encryptionKeyRemovalFailed
        }
    }
    
    private func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    private func decryptData(_ encryptedData: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    private func encryptSensitiveConfigurations(using key: SymmetricKey) async throws {
        // Implementation would encrypt sensitive configuration values
        // This is a placeholder for the actual encryption logic
    }
    
    private func decryptSensitiveConfigurations(using key: SymmetricKey) async throws {
        // Implementation would decrypt sensitive configuration values
        // This is a placeholder for the actual decryption logic
    }
    
    private func reencryptSensitiveConfigurations(from oldKey: SymmetricKey, to newKey: SymmetricKey) async throws {
        // Implementation would re-encrypt all sensitive configurations with new key
        // This is a placeholder for the actual re-encryption logic
    }
    
    private func exportConfigurationData(includeEncrypted: Bool) async throws -> Data {
        // Implementation would export configuration data to JSON
        // This is a placeholder
        return Data()
    }
    
    private func importConfigurationData(_ data: Data) async throws {
        // Implementation would import configuration data from JSON
        // This is a placeholder
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func saveBackupManifest() {
        let manifestURL = securityDirectory.appendingPathComponent("backup_manifest.json")
        do {
            let data = try JSONEncoder().encode(configurationBackups)
            try data.write(to: manifestURL)
        } catch {
            print("Failed to save backup manifest: \(error)")
        }
    }
    
    // MARK: - Security Scanning Methods (安全扫描方法)
    
    private func checkWeakPasswords() -> [SecurityFinding] {
        // Implementation would check for weak password configurations
        return []
    }
    
    private func checkInsecureConfigurations() -> [SecurityFinding] {
        // Implementation would check for insecure configuration values
        return []
    }
    
    private func checkEncryptionStatus() -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        
        if !isEncryptionEnabled {
            findings.append(SecurityFinding(
                id: UUID().uuidString,
                type: .encryptionDisabled,
                severity: .medium,
                title: "配置加密未启用",
                description: "敏感配置数据未加密存储",
                affectedConfiguration: nil,
                recommendation: "启用配置加密以保护敏感数据"
            ))
        }
        
        return findings
    }
    
    private func checkAccessPatterns() async -> [SecurityFinding] {
        // Implementation would analyze access patterns for anomalies
        return []
    }
    
    private func checkDefaultValues() -> [SecurityFinding] {
        // Implementation would check for configurations still using default values in production
        return []
    }
    
    private func calculateSecurityScore(_ findings: [SecurityFinding]) -> Int {
        let totalDeductions = findings.reduce(0) { total, finding in
            switch finding.severity {
            case .critical: return total + 25
            case .high: return total + 15
            case .medium: return total + 10
            case .low: return total + 5
            }
        }
        
        return max(0, 100 - totalDeductions)
    }
    
    private func generateRecommendations(_ findings: [SecurityFinding]) -> [String] {
        var recommendations: [String] = []
        
        if !isEncryptionEnabled {
            recommendations.append("启用配置加密以保护敏感数据")
        }
        
        let criticalFindings = findings.filter { $0.severity == .critical }
        if !criticalFindings.isEmpty {
            recommendations.append("立即处理 \(criticalFindings.count) 个严重安全问题")
        }
        
        if findings.count > 10 {
            recommendations.append("定期进行安全扫描以维护系统安全")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types (支持类型)

/// Encryption status for configurations
/// 配置的加密状态
enum EncryptionStatus: Codable {
    case disabled
    case enabled(algorithm: String)
    
    var isEnabled: Bool {
        if case .enabled = self { return true }
        return false
    }
}

/// Configuration operation types
/// 配置操作类型
enum ConfigurationOperation: String, CaseIterable {
    case read = "read"
    case write = "write"
    case delete = "delete"
}

/// Security policy for configuration access
/// 配置访问的安全策略
struct SecurityPolicy {
    let id: String
    let name: String
    let description: String
    let configurationPattern: String
    let operations: [ConfigurationOperation]
    let requiredRole: UserRole
    let requiresApproval: Bool
    let additionalChecks: (String, String, ConfigurationOperation) -> Bool
    
    init(
        id: String,
        name: String,
        description: String,
        configurationPattern: String,
        operations: [ConfigurationOperation],
        requiredRole: UserRole,
        requiresApproval: Bool = false,
        additionalChecks: @escaping (String, String, ConfigurationOperation) -> Bool = { _, _, _ in true }
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.configurationPattern = configurationPattern
        self.operations = operations
        self.requiredRole = requiredRole
        self.requiresApproval = requiresApproval
        self.additionalChecks = additionalChecks
    }
    
    func appliesTo(configuration: String, operation: ConfigurationOperation) -> Bool {
        guard operations.contains(operation) else { return false }
        
        do {
            let regex = try NSRegularExpression(pattern: configurationPattern)
            let range = NSRange(location: 0, length: configuration.utf16.count)
            return regex.firstMatch(in: configuration, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    func evaluate(userId: String, configurationKey: String, operation: ConfigurationOperation) async throws {
        // Policy evaluation logic would go here
        if !additionalChecks(userId, configurationKey, operation) {
            throw SecurityError.policyViolation(name)
        }
    }
}

/// Security event for monitoring
/// 用于监控的安全事件
struct SecurityEvent: Identifiable {
    let id: String
    let type: SecurityEventType
    let severity: SecuritySeverity
    let timestamp: Date
    let message: String
    let details: [String: String]
    
    init(type: SecurityEventType, severity: SecuritySeverity, message: String, details: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.type = type
        self.severity = severity
        self.timestamp = Date()
        self.message = message
        self.details = details
    }
}

enum SecurityEventType: String, CaseIterable {
    case encryptionEnabled = "encryption_enabled"
    case encryptionDisabled = "encryption_disabled"
    case keyRotation = "key_rotation"
    case unauthorizedAccess = "unauthorized_access"
    case configurationRestored = "configuration_restored"
    case securityViolation = "security_violation"
    case weakPassword = "weak_password"
    case suspiciousActivity = "suspicious_activity"
}

enum SecuritySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// Secure backup information
/// 安全备份信息
class SecureBackup: Identifiable, Codable {
    let id: String
    let name: String
    let createdAt: Date
    let createdBy: String
    let includesEncryptedData: Bool
    var fileURL: URL?
    var fileSize: Int64 = 0
    var checksum: String = ""
    var isEncrypted: Bool = false
    
    init(name: String, createdBy: String, includesEncryptedData: Bool) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.createdBy = createdBy
        self.includesEncryptedData = includesEncryptedData
    }
}

/// Security scan result
/// 安全扫描结果
struct SecurityScanResult {
    let scanId: String
    let scannedAt: Date
    let scannedBy: String
    let findings: [SecurityFinding]
    let score: Int
    let recommendations: [String]
    
    var riskLevel: SecurityRiskLevel {
        switch score {
        case 90...100: return .low
        case 70..<90: return .medium
        case 50..<70: return .high
        default: return .critical
        }
    }
}

/// Security finding from scan
/// 扫描中的安全发现
struct SecurityFinding: Identifiable {
    let id: String
    let type: SecurityFindingType
    let severity: SecuritySeverity
    let title: String
    let description: String
    let affectedConfiguration: String?
    let recommendation: String
}

enum SecurityFindingType: String, CaseIterable {
    case encryptionDisabled = "encryption_disabled"
    case weakPassword = "weak_password"
    case defaultCredentials = "default_credentials"
    case insecureConfiguration = "insecure_configuration"
    case unauthorizedAccess = "unauthorized_access"
    case missingValidation = "missing_validation"
}

enum SecurityRiskLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低风险"
        case .medium: return "中等风险"
        case .high: return "高风险"
        case .critical: return "严重风险"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Error Types (错误类型)

enum SecurityError: LocalizedError {
    case insufficientPermissions
    case weakMasterPassword(String)
    case invalidMasterPassword
    case masterPasswordRequired
    case encryptionFailed
    case decryptionFailed
    case policyViolation(String)
    case backupNotFound
    case invalidBackup
    case checksumMismatch
    case keyStorageError
    case encryptionKeyStorageFailed
    case encryptionKeyNotFound
    case encryptionKeyLoadFailed
    case encryptionKeyRemovalFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足，无法执行安全操作"
        case .weakMasterPassword(let reason):
            return "主密码强度不足: \(reason)"
        case .invalidMasterPassword:
            return "主密码不正确"
        case .masterPasswordRequired:
            return "需要提供主密码"
        case .encryptionFailed:
            return "加密失败"
        case .decryptionFailed:
            return "解密失败"
        case .policyViolation(let policy):
            return "违反安全策略: \(policy)"
        case .backupNotFound:
            return "找不到指定的备份"
        case .invalidBackup:
            return "备份文件无效"
        case .checksumMismatch:
            return "校验和不匹配，文件可能已损坏"
        case .keyStorageError:
            return "密钥存储错误"
        case .encryptionKeyStorageFailed:
            return "无法将加密密钥存储到Keychain"
        case .encryptionKeyNotFound:
            return "在Keychain中找不到加密密钥"
        case .encryptionKeyLoadFailed:
            return "无法从Keychain加载加密密钥"
        case .encryptionKeyRemovalFailed:
            return "无法从Keychain删除加密密钥"
        }
    }
}

