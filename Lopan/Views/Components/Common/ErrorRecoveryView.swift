//
//  ErrorRecoveryView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//  User-friendly error recovery mechanisms
//

import SwiftUI

// MARK: - Error Recovery View

struct ErrorRecoveryView: View {
    let error: SmartLoadingError
    let onRetry: () -> Void
    let onDismiss: (() -> Void)?
    
    @State private var isRetrying = false
    
    init(
        error: SmartLoadingError,
        onRetry: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            errorIcon
            
            // Error Content
            errorContent
            
            // Action Buttons
            actionButtons
        }
        .padding(24)
        .background(LopanColors.background)
        .cornerRadius(16)
        .shadow(color: LopanColors.textPrimary.opacity(0.1), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("错误提示")
        .accessibilityValue(error.errorDescription ?? "")
        .accessibilityHint(error.recoverySuggestion ?? "")
    }
    
    // MARK: - Error Icon
    
    private var errorIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            errorColor.opacity(0.1),
                            errorColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
            
            Image(systemName: errorIconName)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(errorColor)
        }
        .accessibilityHidden(true) // Decorative
    }
    
    private var errorColor: Color {
        switch error {
        case .networkUnavailable:
            return LopanColors.warning
        case .permissionDenied:
            return LopanColors.error
        case .dataCorrupted:
            return LopanColors.accent
        case .serverError:
            return LopanColors.info
        case .unknownError:
            return LopanColors.secondary
        }
    }
    
    private var errorIconName: String {
        switch error {
        case .networkUnavailable:
            return "wifi.slash"
        case .permissionDenied:
            return "lock.circle"
        case .dataCorrupted:
            return "exclamationmark.triangle"
        case .serverError:
            return "server.rack"
        case .unknownError:
            return "questionmark.circle"
        }
    }
    
    // MARK: - Error Content
    
    private var errorContent: some View {
        VStack(spacing: 12) {
            Text(errorTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            if let description = error.errorDescription {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.top, 4)
            }
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .networkUnavailable:
            return "网络连接问题"
        case .permissionDenied:
            return "访问权限不足"
        case .dataCorrupted:
            return "数据加载失败"
        case .serverError:
            return "服务暂不可用"
        case .unknownError:
            return "出现了一些问题"
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action button
            Button(action: handleRetry) {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: LopanColors.textOnPrimary))
                    } else {
                        Image(systemName: retryIconName)
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Text(isRetrying ? "正在重试..." : error.actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(LopanColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [errorColor, errorColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(isRetrying)
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(error.actionTitle)
            .accessibilityHint("点击执行恢复操作")
            
            // Secondary dismiss button (if available)
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Text("暂时跳过")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("暂时跳过")
                .accessibilityHint("关闭错误提示，稍后重试")
            }
        }
    }
    
    private var retryIconName: String {
        switch error {
        case .networkUnavailable, .serverError, .unknownError:
            return "arrow.clockwise"
        case .dataCorrupted:
            return "trash"
        case .permissionDenied:
            return "person.crop.circle.badge.exclamationmark"
        }
    }
    
    private func handleRetry() {
        isRetrying = true
        
        // Add a small delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onRetry()
            
            // Reset retry state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isRetrying = false
            }
        }
    }
}

// MARK: - Inline Error Banner

struct InlineErrorBanner: View {
    let error: SmartLoadingError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(LopanColors.warning)
                .accessibilityHidden(true)
            
            // Error content
            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "发生错误")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onRetry) {
                    Text("重试")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.info)
                }
                .accessibilityLabel("重试操作")
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("关闭错误提示")
                .frame(width: 24, height: 24)
            }
        }
        .padding(12)
        .background(LopanColors.warning.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LopanColors.warning.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("错误提示")
        .accessibilityValue(error.errorDescription ?? "")
    }
}

// MARK: - Loading Overlay View

struct LoadingOverlayView: View {
    let message: String
    let style: LoadingStyle
    
    enum LoadingStyle {
        case fullScreen
        case overlay
        case inline
    }
    
    init(message: String = "加载中...", style: LoadingStyle = .overlay) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        ZStack {
            // Background
            if style == .fullScreen {
                LopanColors.background
                    .ignoresSafeArea()
            } else if style == .overlay {
                LopanColors.shadow.opacity(6)
                    .ignoresSafeArea()
            }
            
            // Loading content
            loadingContent
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在加载")
        .accessibilityValue(message)
    }
    
    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: LopanColors.info))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(LopanColors.background)
        .cornerRadius(12)
        .shadow(color: LopanColors.textPrimary.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Smart Error Recovery Coordinator

@MainActor
class ErrorRecoveryCoordinator: ObservableObject {
    @Published var shouldShowErrorModal = false
    @Published var shouldShowErrorBanner = false
    @Published var currentError: SmartLoadingError?
    
    private var retryAction: (() -> Void)?
    
    func presentError(
        _ error: SmartLoadingError,
        style: PresentationStyle = .banner,
        retryAction: @escaping () -> Void
    ) {
        self.currentError = error
        self.retryAction = retryAction
        
        switch style {
        case .modal:
            shouldShowErrorModal = true
        case .banner:
            shouldShowErrorBanner = true
        }
        
        // Auto-dismiss banner after delay for non-critical errors
        if style == .banner && !error.isCritical {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.dismissBanner()
            }
        }
    }
    
    func retry() {
        retryAction?()
        dismiss()
    }
    
    func dismiss() {
        shouldShowErrorModal = false
        shouldShowErrorBanner = false
        currentError = nil
        retryAction = nil
    }
    
    func dismissBanner() {
        shouldShowErrorBanner = false
    }
    
    enum PresentationStyle {
        case modal
        case banner
    }
}

// MARK: - Error Extensions

private extension SmartLoadingError {
    var isCritical: Bool {
        switch self {
        case .permissionDenied, .dataCorrupted:
            return true
        case .networkUnavailable, .serverError, .unknownError:
            return false
        }
    }
}

// MARK: - Preview

#Preview("Error Recovery Views") {
    ScrollView {
        VStack(spacing: 30) {
            ErrorRecoveryView(
                error: .networkUnavailable,
                onRetry: {},
                onDismiss: {}
            )
            
            InlineErrorBanner(
                error: .dataCorrupted,
                onRetry: {},
                onDismiss: {}
            )
            
            LoadingOverlayView(message: "正在加载数据...")
        }
        .padding()
    }
}