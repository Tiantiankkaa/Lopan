//
//  SmartErrorRecoveryView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import SwiftUI

// MARK: - Error Types

enum RecoverableError: Error, Identifiable {
    case networkTimeout
    case serverError(code: Int)
    case authenticationExpired
    case dataCorrupted
    case insufficientStorage
    case serviceUnavailable
    case rateLimitExceeded
    case unknown(Error)
    
    var id: String {
        switch self {
        case .networkTimeout:
            return "networkTimeout"
        case .serverError(let code):
            return "serverError_\(code)"
        case .authenticationExpired:
            return "authenticationExpired"
        case .dataCorrupted:
            return "dataCorrupted"
        case .insufficientStorage:
            return "insufficientStorage"
        case .serviceUnavailable:
            return "serviceUnavailable"
        case .rateLimitExceeded:
            return "rateLimitExceeded"
        case .unknown:
            return "unknown"
        }
    }
    
    var title: String {
        switch self {
        case .networkTimeout:
            return "网络超时"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        case .authenticationExpired:
            return "登录已过期"
        case .dataCorrupted:
            return "数据损坏"
        case .insufficientStorage:
            return "存储空间不足"
        case .serviceUnavailable:
            return "服务暂时不可用"
        case .rateLimitExceeded:
            return "请求过于频繁"
        case .unknown:
            return "未知错误"
        }
    }
    
    var description: String {
        switch self {
        case .networkTimeout:
            return "网络连接超时，请检查网络设置后重试"
        case .serverError(let code):
            return "服务器返回错误代码 \(code)，请稍后重试"
        case .authenticationExpired:
            return "您的登录状态已过期，请重新登录"
        case .dataCorrupted:
            return "数据可能已损坏，建议清除缓存后重试"
        case .insufficientStorage:
            return "设备存储空间不足，请清理存储空间后重试"
        case .serviceUnavailable:
            return "服务暂时不可用，请稍后重试"
        case .rateLimitExceeded:
            return "请求过于频繁，请稍后再试"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var icon: String {
        switch self {
        case .networkTimeout:
            return "wifi.slash"
        case .serverError:
            return "server.rack"
        case .authenticationExpired:
            return "person.crop.circle.badge.exclamationmark"
        case .dataCorrupted:
            return "externaldrive.badge.exclamationmark"
        case .insufficientStorage:
            return "internaldrive"
        case .serviceUnavailable:
            return "exclamationmark.triangle"
        case .rateLimitExceeded:
            return "clock.badge.exclamationmark"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .networkTimeout, .serverError, .serviceUnavailable:
            return true
        case .authenticationExpired, .dataCorrupted, .insufficientStorage, .rateLimitExceeded, .unknown:
            return false
        }
    }
    
    var suggestedActions: [ErrorAction] {
        switch self {
        case .networkTimeout:
            return [
                ErrorAction(title: "重试", style: .primary, action: .retry),
                ErrorAction(title: "检查网络", style: .secondary, action: .checkNetwork)
            ]
        case .serverError:
            return [
                ErrorAction(title: "重试", style: .primary, action: .retry),
                ErrorAction(title: "稍后重试", style: .secondary, action: .retryLater)
            ]
        case .authenticationExpired:
            return [
                ErrorAction(title: "重新登录", style: .primary, action: .reAuthenticate)
            ]
        case .dataCorrupted:
            return [
                ErrorAction(title: "清除缓存", style: .primary, action: .clearCache),
                ErrorAction(title: "重新加载", style: .secondary, action: .reload)
            ]
        case .insufficientStorage:
            return [
                ErrorAction(title: "清理存储", style: .primary, action: .manageStorage)
            ]
        case .serviceUnavailable:
            return [
                ErrorAction(title: "稍后重试", style: .primary, action: .retryLater)
            ]
        case .rateLimitExceeded:
            return [
                ErrorAction(title: "稍后重试", style: .primary, action: .retryLater)
            ]
        case .unknown:
            return [
                ErrorAction(title: "重试", style: .primary, action: .retry),
                ErrorAction(title: "报告问题", style: .secondary, action: .reportError)
            ]
        }
    }
}

// MARK: - Error Actions

struct ErrorAction: Equatable {
    let title: String
    let style: ActionStyle
    let action: ActionType
    let accessibilityHint: String?
    
    enum ActionStyle {
        case primary
        case secondary
        case destructive
    }
    
    enum ActionType: Equatable {
        case retry
        case retryLater
        case reAuthenticate
        case clearCache
        case reload
        case manageStorage
        case checkNetwork
        case reportError
        case dismiss
        case custom(() -> Void)
        
        static func == (lhs: ActionType, rhs: ActionType) -> Bool {
            switch (lhs, rhs) {
            case (.retry, .retry),
                 (.retryLater, .retryLater),
                 (.reAuthenticate, .reAuthenticate),
                 (.clearCache, .clearCache),
                 (.reload, .reload),
                 (.manageStorage, .manageStorage),
                 (.checkNetwork, .checkNetwork),
                 (.reportError, .reportError),
                 (.dismiss, .dismiss):
                return true
            case (.custom, .custom):
                return false // Functions are never equal
            default:
                return false
            }
        }
    }
    
    // Custom Equatable implementation for ErrorAction
    static func == (lhs: ErrorAction, rhs: ErrorAction) -> Bool {
        return lhs.title == rhs.title && 
               lhs.style == rhs.style && 
               lhs.accessibilityHint == rhs.accessibilityHint &&
               actionTypesEqual(lhs.action, rhs.action)
    }
    
    private static func actionTypesEqual(_ lhs: ActionType, _ rhs: ActionType) -> Bool {
        switch (lhs, rhs) {
        case (.retry, .retry),
             (.retryLater, .retryLater),
             (.reAuthenticate, .reAuthenticate),
             (.clearCache, .clearCache),
             (.reload, .reload),
             (.manageStorage, .manageStorage),
             (.checkNetwork, .checkNetwork),
             (.reportError, .reportError),
             (.dismiss, .dismiss):
            return true
        case (.custom, .custom):
            return false // Functions are never equal
        default:
            return false
        }
    }
    
    init(
        title: String,
        style: ActionStyle = .primary,
        action: ActionType,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.style = style
        self.action = action
        self.accessibilityHint = accessibilityHint
    }
}

// MARK: - Smart Error Recovery View

struct SmartErrorRecoveryView: View {
    let error: RecoverableError
    let onRetry: () -> Void
    let onDismiss: (() -> Void)?
    let customActions: [ErrorAction]
    
    @State private var isRetrying = false
    @State private var retryCount = 0
    
    init(
        error: RecoverableError,
        onRetry: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        customActions: [ErrorAction] = []
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
        self.customActions = customActions
    }
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            if retryCount > 0 {
                retryInfoSection
            }
            
            actionButtonsSection
        }
        .padding(24)
        .background(LopanColors.backgroundTertiary)
        .cornerRadius(16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("错误信息: \(error.title)")
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: error.icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(LopanColors.error)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                DynamicText(
                    error.title,
                    style: .title2,
                    alignment: .center
                )
                .fontWeight(.semibold)
                
                DynamicText(
                    error.description,
                    style: .body,
                    alignment: .center
                )
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
        }
    }
    
    private var retryInfoSection: some View {
        VStack(spacing: 4) {
            DynamicText(
                "已重试 \(retryCount) 次",
                style: .caption,
                alignment: .center
            )
            .foregroundColor(.secondary)
            
            if retryCount >= 3 {
                DynamicText(
                    "如果问题持续存在，请稍后再试或联系技术支持",
                    style: .caption2,
                    alignment: .center
                )
                .foregroundColor(LopanColors.warning)
                .padding(.horizontal)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary actions from error type
            ForEach(Array(error.suggestedActions.enumerated()), id: \.offset) { index, action in
                ErrorActionButton(
                    action: action,
                    isLoading: isRetrying && action.action == .retry,
                    onTap: { handleAction(action) }
                )
            }
            
            // Custom actions
            ForEach(Array(customActions.enumerated()), id: \.offset) { index, action in
                ErrorActionButton(
                    action: action,
                    onTap: { handleAction(action) }
                )
            }
            
            // Dismiss button
            if let onDismiss = onDismiss {
                ErrorActionButton(
                    action: ErrorAction(
                        title: "关闭",
                        style: .secondary,
                        action: .dismiss,
                        accessibilityHint: "关闭错误提示"
                    ),
                    onTap: { onDismiss() }
                )
            }
        }
    }
    
    private func handleAction(_ action: ErrorAction) {
        switch action.action {
        case .retry:
            performRetry()
        case .retryLater:
            scheduleRetry()
        case .reAuthenticate:
            handleReAuthentication()
        case .clearCache:
            clearAppCache()
        case .reload:
            reloadData()
        case .manageStorage:
            openStorageSettings()
        case .checkNetwork:
            openNetworkSettings()
        case .reportError:
            reportError()
        case .dismiss:
            onDismiss?()
        case .custom(let customAction):
            customAction()
        }
    }
    
    private func performRetry() {
        guard !isRetrying else { return }
        
        isRetrying = true
        retryCount += 1
        
        // Add delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onRetry()
            isRetrying = false
        }
    }
    
    private func scheduleRetry() {
        let delay: TimeInterval = min(30, pow(2, Double(retryCount))) // Exponential backoff, max 30s
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            performRetry()
        }
        
        // Show feedback
        // In a real app, you'd show a toast or similar feedback
        print("将在 \(Int(delay)) 秒后重试...")
    }
    
    private func handleReAuthentication() {
        // In a real app, this would navigate to login screen
        print("导航到登录界面")
    }
    
    private func clearAppCache() {
        // Clear app cache
        // This is a simplified version - in reality you'd clear specific caches
        URLCache.shared.removeAllCachedResponses()
        print("已清除应用缓存")
        
        // Auto-retry after clearing cache
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            performRetry()
        }
    }
    
    private func reloadData() {
        onRetry()
    }
    
    private func openStorageSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func openNetworkSettings() {
        if let settingsURL = URL(string: "App-Prefs:root=WIFI") {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func reportError() {
        // In a real app, this would open bug report flow
        print("打开错误报告界面")
    }
}

// MARK: - Error Action Button

struct ErrorActionButton: View {
    let action: ErrorAction
    let isLoading: Bool
    let onTap: () -> Void
    
    init(
        action: ErrorAction,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.action = action
        self.isLoading = isLoading
        self.onTap = onTap
    }
    
    var body: some View {
        AccessibleButton(
            action: onTap,
            accessibilityLabel: action.title,
            accessibilityHint: action.accessibilityHint,
            accessibilityTraits: isLoading ? [.isButton, .isStaticText] : [.isButton]
        ) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: buttonTextColor))
                }
                
                DynamicText(action.title, style: .callout)
                    .fontWeight(.medium)
                    .foregroundColor(buttonTextColor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(minWidth: 120, minHeight: 44)
            .background(buttonBackgroundColor)
            .cornerRadius(8)
        }
        .disabled(isLoading)
    }
    
    private var buttonTextColor: Color {
        switch action.style {
        case .primary:
            return LopanColors.textOnPrimary
        case .secondary:
            return .accentColor
        case .destructive:
            return LopanColors.textOnPrimary
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch action.style {
        case .primary:
            return .accentColor
        case .secondary:
            return LopanColors.primary.opacity(0.1)
        case .destructive:
            return LopanColors.error
        }
    }
}

// MARK: - Inline Error View

struct InlineErrorView: View {
    let error: RecoverableError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .font(.system(size: 16))
                .foregroundColor(LopanColors.error)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                DynamicText(error.title, style: .caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                DynamicText(error.description, style: .caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let onRetry = onRetry, error.canRetry {
                AccessibleButton(
                    action: onRetry,
                    accessibilityLabel: "重试",
                    accessibilityHint: "重新尝试执行操作"
                ) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            
            if let onDismiss = onDismiss {
                AccessibleButton(
                    action: onDismiss,
                    accessibilityLabel: "关闭",
                    accessibilityHint: "关闭错误提示"
                ) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LopanColors.error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LopanColors.error.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("错误：\(error.title)")
        .accessibilityValue(error.description)
    }
}

// MARK: - Error Helper Extensions

extension Error {
    func asRecoverableError() -> RecoverableError {
        if let recoverableError = self as? RecoverableError {
            return recoverableError
        }
        
        // Convert common errors to recoverable errors
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut:
                return .networkTimeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkTimeout
            default:
                return .unknown(self)
            }
        }
        
        return .unknown(self)
    }
}

// MARK: - Preview

#if DEBUG
struct SmartErrorRecoveryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SmartErrorRecoveryView(
                error: .networkTimeout,
                onRetry: { }
            )
            .previewDisplayName("Network Timeout")
            
            SmartErrorRecoveryView(
                error: .authenticationExpired,
                onRetry: { }
            )
            .previewDisplayName("Auth Expired")
            
            InlineErrorView(
                error: .serverError(code: 500),
                onRetry: { },
                onDismiss: { }
            )
            .previewDisplayName("Inline Error")
            .padding()
        }
    }
}
#endif