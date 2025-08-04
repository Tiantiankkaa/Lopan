import Foundation
import CryptoKit

/// Comprehensive security validation utilities for user input sanitization and validation
struct SecurityValidation {
    
    // MARK: - Input Validation
    
    /// Validates and sanitizes user names to prevent injection attacks
    static func validateUserName(_ name: String) -> ValidationResult {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitized.isEmpty else {
            return .failure("用户名不能为空")
        }
        
        guard sanitized.count <= 50 else {
            return .failure("用户名长度不能超过50个字符")
        }
        
        // Prevent XSS and injection attacks
        let dangerousPatterns = [
            #"[<>'"&;]"#,
            #"javascript:"#,
            #"data:"#,
            #"vbscript:"#,
            #"on\w+="#
        ]
        
        for pattern in dangerousPatterns {
            if sanitized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return .failure("用户名包含非法字符")
            }
        }
        
        // Check for control characters
        guard !sanitized.contains(where: { $0.isNewline || $0.isWhitespace && $0 != " " }) else {
            return .failure("用户名包含无效字符")
        }
        
        return .success(sanitized)
    }
    
    /// Validates phone numbers with proper format checking
    static func validatePhoneNumber(_ phone: String) -> ValidationResult {
        let sanitized = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitized.isEmpty else {
            return .failure("手机号不能为空")
        }
        
        // Chinese mobile phone format validation
        let phoneRegex = #"^1[3-9]\d{9}$"#
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        guard phoneTest.evaluate(with: sanitized) else {
            return .failure("请输入有效的手机号码")
        }
        
        return .success(sanitized)
    }
    
    /// Validates WeChat ID with security considerations
    static func validateWeChatId(_ wechatId: String) -> ValidationResult {
        let sanitized = wechatId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitized.isEmpty else {
            return .failure("微信号不能为空")
        }
        
        guard sanitized.count >= 6 && sanitized.count <= 20 else {
            return .failure("微信号长度应为6-20个字符")
        }
        
        // WeChat ID format: letters, numbers, underscores, hyphens
        let wechatRegex = #"^[a-zA-Z0-9_-]+$"#
        let wechatTest = NSPredicate(format: "SELF MATCHES %@", wechatRegex)
        
        guard wechatTest.evaluate(with: sanitized) else {
            return .failure("微信号只能包含字母、数字、下划线和连字符")
        }
        
        return .success(sanitized)
    }
    
    /// Validates SMS verification codes with rate limiting considerations
    static func validateSMSCode(_ code: String, phoneNumber: String) -> ValidationResult {
        let sanitized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitized.isEmpty else {
            return .failure("验证码不能为空")
        }
        
        guard sanitized.count == 6 else {
            return .failure("验证码应为6位数字")
        }
        
        // Numeric verification code only
        guard sanitized.allSatisfy({ $0.isNumber }) else {
            return .failure("验证码只能包含数字")
        }
        
        // Additional security: prevent common test codes in production
        let testCodes = ["123456", "000000", "111111", "888888", "666666"]
        if testCodes.contains(sanitized) {
            return .failure("请输入有效的验证码")
        }
        
        return .success(sanitized)
    }
    
    /// Validates product input with XSS prevention
    static func validateProductInput(_ input: String, maxLength: Int = 100) -> ValidationResult {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitized.isEmpty else {
            return .failure("产品信息不能为空")
        }
        
        guard sanitized.count <= maxLength else {
            return .failure("输入长度不能超过\(maxLength)个字符")
        }
        
        // HTML/Script injection prevention
        let dangerousPatterns = [
            #"<[^>]*>"#,  // HTML tags
            #"javascript:"#,
            #"data:"#,
            #"vbscript:"#,
            #"on\w+\s*="#,  // Event handlers
            #"&[#\w]+;"#   // HTML entities
        ]
        
        for pattern in dangerousPatterns {
            if sanitized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return .failure("输入包含非法字符或格式")
            }
        }
        
        return .success(sanitized)
    }
    
    /// Validates review notes with content sanitization
    static func validateReviewNotes(_ notes: String) -> ValidationResult {
        let sanitized = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Allow empty notes
        if sanitized.isEmpty {
            return .success("")
        }
        
        guard sanitized.count <= 500 else {
            return .failure("备注长度不能超过500个字符")
        }
        
        // Basic content sanitization
        let cleanedNotes = sanitized
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
            .replacingOccurrences(of: "&", with: "&amp;")
        
        return .success(cleanedNotes)
    }
    
    // MARK: - Configuration Data Validation
    
    /// Validates station numbers with range checking
    static func validateStationNumber(_ number: Int, maxStations: Int = 20) -> ValidationResult {
        guard number > 0 else {
            return .failure("工位号必须大于0")
        }
        
        guard number <= maxStations else {
            return .failure("工位号不能超过\(maxStations)")
        }
        
        return .successInt(number)
    }
    
    /// Validates gun color selections
    static func validateGunColor(_ colorId: String, availableColors: [String]) -> ValidationResult {
        let sanitized = colorId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitized.isEmpty else {
            return .failure("请选择喷枪颜色")
        }
        
        guard availableColors.contains(sanitized) else {
            return .failure("选择的颜色不可用")
        }
        
        return .success(sanitized)
    }
}

// MARK: - Supporting Types

enum ValidationResult {
    case success(String)
    case successInt(Int)
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success, .successInt:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success, .successInt:
            return nil
        case .failure(let message):
            return message
        }
    }
    
    var value: String? {
        switch self {
        case .success(let value):
            return value
        case .successInt(let intValue):
            return String(intValue)
        case .failure:
            return nil
        }
    }
    
    var intValue: Int? {
        switch self {
        case .successInt(let value):
            return value
        case .success(let stringValue):
            return Int(stringValue)
        case .failure:
            return nil
        }
    }
}

// MARK: - Rate Limiting Support

class RateLimiter {
    private var attempts: [String: [Date]] = [:]
    private let maxAttempts: Int
    private let timeWindow: TimeInterval
    private let queue = DispatchQueue(label: "rate_limiter", attributes: .concurrent)
    
    init(maxAttempts: Int = 5, timeWindow: TimeInterval = 300) { // 5 attempts per 5 minutes
        self.maxAttempts = maxAttempts
        self.timeWindow = timeWindow
    }
    
    func isAllowed(for identifier: String) -> Bool {
        return queue.sync {
            let now = Date()
            let cutoff = now.addingTimeInterval(-timeWindow)
            
            // Clean old attempts
            attempts[identifier]?.removeAll { $0 < cutoff }
            
            let currentAttempts = attempts[identifier]?.count ?? 0
            
            if currentAttempts >= maxAttempts {
                return false
            }
            
            // Record this attempt
            if attempts[identifier] == nil {
                attempts[identifier] = []
            }
            attempts[identifier]?.append(now)
            
            return true
        }
    }
    
    func reset(for identifier: String) {
        queue.async(flags: .barrier) {
            self.attempts[identifier] = nil
        }
    }
}