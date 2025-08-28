//
//  UnifiedLoadingView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import SwiftUI

// MARK: - Loading State Types

enum LoadingStateType {
    case initial
    case refreshing
    case loadingMore
    case searching
    case processing
    case uploading
    case downloading
    
    var accessibilityLabel: String {
        switch self {
        case .initial:
            return "正在加载数据"
        case .refreshing:
            return "正在刷新数据"
        case .loadingMore:
            return "正在加载更多数据"
        case .searching:
            return "正在搜索"
        case .processing:
            return "正在处理"
        case .uploading:
            return "正在上传"
        case .downloading:
            return "正在下载"
        }
    }
    
    var message: String {
        switch self {
        case .initial:
            return "加载中..."
        case .refreshing:
            return "刷新中..."
        case .loadingMore:
            return "加载更多..."
        case .searching:
            return "搜索中..."
        case .processing:
            return "处理中..."
        case .uploading:
            return "上传中..."
        case .downloading:
            return "下载中..."
        }
    }
}

// MARK: - Unified Loading View

struct UnifiedLoadingView: View {
    let type: LoadingStateType
    let progress: Double?
    let message: String?
    let showCancel: Bool
    let onCancel: (() -> Void)?
    
    init(
        type: LoadingStateType = .initial,
        progress: Double? = nil,
        message: String? = nil,
        showCancel: Bool = false,
        onCancel: (() -> Void)? = nil
    ) {
        self.type = type
        self.progress = progress
        self.message = message
        self.showCancel = showCancel
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress indicator
            progressIndicator
            
            // Message
            VStack(spacing: 8) {
                DynamicText(
                    message ?? type.message,
                    style: .subheadline,
                    alignment: .center
                )
                .foregroundColor(.secondary)
                
                if let progress = progress {
                    DynamicText(
                        "\(Int(progress * 100))%",
                        style: .caption,
                        alignment: .center
                    )
                    .foregroundColor(.secondary)
                }
            }
            
            // Cancel button
            if showCancel, let onCancel = onCancel {
                AccessibleButton(
                    action: onCancel,
                    accessibilityLabel: "取消操作",
                    accessibilityHint: "取消当前正在进行的操作"
                ) {
                    DynamicText("取消", style: .callout)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(type.accessibilityLabel)
        .accessibilityValue(progressAccessibilityValue)
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        if let progress = progress {
            // Determinate progress
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 120)
                    .accessibilityValue("进度 \(Int(progress * 100))%")
            }
        } else {
            // Indeterminate progress
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .accessibilityLabel(type.accessibilityLabel)
        }
    }
    
    private var progressAccessibilityValue: String {
        if let progress = progress {
            return "进度 \(Int(progress * 100))%"
        } else {
            return "正在进行中"
        }
    }
}

// MARK: - Skeleton Loading View

struct SkeletonLoadingView: View {
    let rows: Int
    let showImage: Bool
    
    init(rows: Int = 3, showImage: Bool = false) {
        self.rows = rows
        self.showImage = showImage
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<rows, id: \.self) { _ in
                SkeletonRow(showImage: showImage)
            }
        }
        .accessibilityLabel("正在加载内容")
        .accessibilityHint("内容加载完成后将显示实际数据")
    }
}

struct SkeletonRow: View {
    let showImage: Bool
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            if showImage {
                // Skeleton image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(skeletonGradient)
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                
                // Subtitle skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 12)
                    .frame(width: 120)
                
                // Detail skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 10)
                    .frame(width: 80)
            }
        }
        .padding()
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
        .accessibilityHidden(true) // Hide skeleton from VoiceOver
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGray5),
                Color(.systemGray4),
                Color(.systemGray5)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Inline Loading Indicator

struct InlineLoadingIndicator: View {
    let isVisible: Bool
    let message: String?
    
    init(isVisible: Bool = true, message: String? = nil) {
        self.isVisible = isVisible
        self.message = message
    }
    
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                
                if let message = message {
                    DynamicText(message, style: .caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message ?? "正在加载")
        }
    }
}

// MARK: - Pull to Refresh Loading

struct PullToRefreshLoadingView: View {
    let progress: CGFloat
    let isTriggered: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if isTriggered {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("正在刷新")
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(progress > 0.8 ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: progress)
                    .accessibilityHidden(true)
            }
            
            DynamicText(
                isTriggered ? "正在刷新..." : (progress > 0.8 ? "松开刷新" : "下拉刷新"),
                style: .caption,
                alignment: .center
            )
            .foregroundColor(.secondary)
        }
        .frame(height: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isTriggered ? "正在刷新数据" : "下拉刷新控件")
        .accessibilityHint(isTriggered ? "" : "向下拖拽以刷新数据")
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay<Content: View>: View {
    let isLoading: Bool
    let type: LoadingStateType
    let content: () -> Content
    
    init(
        isLoading: Bool,
        type: LoadingStateType = .initial,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.type = type
        self.content = content
    }
    
    var body: some View {
        ZStack {
            content()
                .blur(radius: isLoading ? 2 : 0)
                .disabled(isLoading)
            
            if isLoading {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    DynamicText(
                        type.message,
                        style: .subheadline,
                        alignment: .center
                    )
                    .foregroundColor(.white)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(type.accessibilityLabel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}