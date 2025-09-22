//
//  SmartLoadingController.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//  Unified loading and error state management controller
//

import SwiftUI

// MARK: - Smart Loading Controller

@MainActor
class SmartLoadingController: ObservableObject {
    // Loading States
    @Published var isInitialLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var isSyncing = false
    
    // Error States
    @Published var currentError: SmartLoadingError?
    @Published var shouldShowErrorModal = false
    @Published var shouldShowErrorBanner = false
    
    // Progress States
    @Published var batchProgress: BatchProgress?
    @Published var syncState: DataSyncIndicator.SyncState = .idle
    @Published var lastSyncTime: Date?
    
    // Data States
    @Published var hasData = false
    @Published var hasMoreData = true
    @Published var isEmpty = false
    
    private var retryAction: (() -> Void)?
    
    // MARK: - Loading Management
    
    func startInitialLoading() {
        isInitialLoading = true
        currentError = nil
        isEmpty = false
    }
    
    func startRefreshing() {
        isRefreshing = true
        currentError = nil
    }
    
    func startLoadingMore() {
        guard !isLoadingMore && hasMoreData else { return }
        isLoadingMore = true
        currentError = nil
    }
    
    func startSyncing() {
        isSyncing = true
        syncState = .syncing
    }
    
    func completeLoading(hasData: Bool, hasMore: Bool = true) {
        isInitialLoading = false
        isRefreshing = false
        isLoadingMore = false
        
        self.hasData = hasData
        self.hasMoreData = hasMore
        self.isEmpty = !hasData
        
        currentError = nil
    }
    
    func completeSyncing(success: Bool, error: String? = nil) {
        isSyncing = false
        
        if success {
            syncState = .success
            lastSyncTime = Date()
        } else {
            syncState = .failed(error ?? "同步失败")
        }
        
        // Auto-reset to idle after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if case .success = self.syncState {
                self.syncState = .idle
            }
        }
    }
    
    // MARK: - Error Management
    
    func handleError(
        _ error: Error,
        presentation: ErrorPresentationStyle = .automatic,
        retryAction: @escaping () -> Void
    ) {
        // Convert to SmartLoadingError
        let loadingError: SmartLoadingError
        if let customError = error as? SmartLoadingError {
            loadingError = customError
        } else {
            loadingError = .unknownError(error)
        }
        
        // Clear loading states
        isInitialLoading = false
        isRefreshing = false
        isLoadingMore = false
        isSyncing = false
        
        // Set error
        currentError = loadingError
        self.retryAction = retryAction
        
        // Determine presentation style
        let finalPresentation = presentation == .automatic ? 
            (loadingError.isCritical ? .modal : .banner) : presentation
        
        switch finalPresentation {
        case .modal, .automatic:
            shouldShowErrorModal = true
        case .banner:
            shouldShowErrorBanner = true
            
            // Auto-dismiss non-critical errors
            if !loadingError.isCritical {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.dismissError()
                }
            }
        }
    }
    
    func retry() {
        dismissError()
        retryAction?()
    }
    
    func dismissError() {
        shouldShowErrorModal = false
        shouldShowErrorBanner = false
        currentError = nil
        retryAction = nil
    }
    
    // MARK: - Batch Progress Management
    
    func startBatchOperation(total: Int, title: String = "批量操作") {
        batchProgress = BatchProgress(
            completed: 0,
            total: total,
            title: title,
            currentOperation: nil,
            isCompleted: false
        )
    }
    
    func updateBatchProgress(completed: Int, currentOperation: String?) {
        batchProgress?.completed = completed
        batchProgress?.currentOperation = currentOperation
        
        if completed >= batchProgress?.total ?? 0 {
            completeBatchOperation()
        }
    }
    
    func completeBatchOperation() {
        batchProgress?.isCompleted = true
        
        // Auto-clear after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.batchProgress = nil
        }
    }
    
    // MARK: - State Queries
    
    var isAnyLoading: Bool {
        isInitialLoading || isRefreshing || isLoadingMore || isSyncing
    }
    
    var hasError: Bool {
        currentError != nil
    }
    
    var shouldShowSkeleton: Bool {
        isInitialLoading && !hasData
    }
    
    var shouldShowEmptyState: Bool {
        !isAnyLoading && !hasError && isEmpty
    }
    
    var shouldShowContent: Bool {
        hasData && !shouldShowSkeleton
    }
}

// MARK: - Supporting Types

enum ErrorPresentationStyle {
    case automatic
    case modal
    case banner
}

class BatchProgress: ObservableObject {
    @Published var completed: Int
    @Published var total: Int
    @Published var title: String
    @Published var currentOperation: String?
    @Published var isCompleted: Bool
    
    init(completed: Int, total: Int, title: String, currentOperation: String?, isCompleted: Bool) {
        self.completed = completed
        self.total = total
        self.title = title
        self.currentOperation = currentOperation
        self.isCompleted = isCompleted
    }
    
    var progress: Double {
        guard total > 0 else { return 0.0 }
        return Double(completed) / Double(total)
    }
}

// MARK: - Smart Loading View Modifier

struct SmartLoadingModifier: ViewModifier {
    @ObservedObject var controller: SmartLoadingController
    let onRefresh: (() -> Void)?
    let onLoadMore: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(controller.shouldShowSkeleton ? 0 : 1)
            
            // Skeleton loading
            if controller.shouldShowSkeleton {
                SkeletonListView()
                    .transition(.opacity)
            }
            
            // Loading overlay for specific operations
            if controller.isSyncing {
                LoadingOverlayView(
                    message: "正在同步数据...",
                    style: .overlay
                )
                .transition(.opacity)
            }
        }
        .refreshable {
            if let onRefresh = onRefresh {
                controller.startRefreshing()
                onRefresh()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Error banner
            if controller.shouldShowErrorBanner, let error = controller.currentError {
                InlineErrorBanner(
                    error: error,
                    onRetry: controller.retry,
                    onDismiss: controller.dismissError
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                // Sync indicator
                if case .syncing = controller.syncState, controller.isSyncing {
                    DataSyncIndicator(
                        syncState: controller.syncState,
                        lastSyncTime: controller.lastSyncTime
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Batch progress
                if let progress = controller.batchProgress {
                    BatchOperationProgress(
                        completed: progress.completed,
                        total: progress.total,
                        currentOperation: progress.currentOperation,
                        isCompleted: progress.isCompleted
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Load more indicator
                if controller.shouldShowContent && onLoadMore != nil {
                    InfiniteScrollLoader(
                        isLoading: controller.isLoadingMore,
                        hasMoreData: controller.hasMoreData,
                        onLoadMore: {
                            controller.startLoadingMore()
                            onLoadMore?()
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $controller.shouldShowErrorModal) {
            if let error = controller.currentError {
                NavigationStack {
                    ErrorRecoveryView(
                        error: error,
                        onRetry: controller.retry,
                        onDismiss: controller.dismissError
                    )
                    .padding()
                    .navigationTitle("出现问题")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarCloseButton {
                        controller.dismissError()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: controller.shouldShowSkeleton)
        .animation(.easeInOut(duration: 0.3), value: controller.shouldShowErrorBanner)
        .animation(.easeInOut(duration: 0.3), value: controller.isSyncing)
        .animation(.easeInOut(duration: 0.3), value: controller.batchProgress != nil)
    }
}

// MARK: - View Extension

extension View {
    func smartLoading(
        controller: SmartLoadingController,
        onRefresh: (() -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil
    ) -> some View {
        modifier(SmartLoadingModifier(
            controller: controller,
            onRefresh: onRefresh,
            onLoadMore: onLoadMore
        ))
    }
}

// MARK: - Navigation Bar Extension

extension View {
    func navigationBarCloseButton(action: @escaping () -> Void) -> some View {
        navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        action()
                    }
                    .accessibilityLabel("关闭")
                }
            }
    }
}

// MARK: - Error Extension

// MARK: - Smart Loading Error

enum SmartLoadingError: LocalizedError {
    case networkUnavailable
    case dataCorrupted
    case permissionDenied
    case serverError(String)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络连接不可用"
        case .dataCorrupted:
            return "数据格式错误"
        case .permissionDenied:
            return "没有访问权限"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .unknownError(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "请检查网络连接后重试"
        case .dataCorrupted:
            return "请清除缓存后重新加载"
        case .permissionDenied:
            return "请联系管理员获取访问权限"
        case .serverError:
            return "服务器暂时不可用，请稍后重试"
        case .unknownError:
            return "请重试，如问题持续请联系技术支持"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .networkUnavailable, .serverError:
            return "重试"
        case .dataCorrupted:
            return "清除缓存"
        case .permissionDenied:
            return "联系管理员"
        case .unknownError:
            return "重试"
        }
    }
}

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