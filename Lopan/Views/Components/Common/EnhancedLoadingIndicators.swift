//
//  EnhancedLoadingIndicators.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/26.
//  Comprehensive loading indicators for all app states
//

import SwiftUI

// MARK: - Pull-to-Refresh Indicator

struct PullToRefreshIndicator: View {
    let isRefreshing: Bool
    let progress: Double // 0.0 to 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                // Progress circle
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: progress)
                
                // Loading spinner (when refreshing)
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.6)
                }
            }
            
            Text(refreshMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.2), value: isRefreshing)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRefreshing ? "正在刷新" : "下拉刷新")
        .accessibilityValue(isRefreshing ? "刷新进行中" : "进度 \(Int(progress * 100))%")
    }
    
    private var refreshMessage: String {
        if isRefreshing {
            return "正在刷新..."
        } else if progress >= 1.0 {
            return "松开刷新"
        } else if progress > 0.3 {
            return "继续下拉"
        } else {
            return "下拉刷新"
        }
    }
}

// MARK: - Infinite Scroll Loading

struct InfiniteScrollLoader: View {
    let isLoading: Bool
    let hasMoreData: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
                
                Text("正在加载更多...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else if hasMoreData {
                Text("点击加载更多")
                    .font(.callout)
                    .foregroundColor(.blue)
                    .onTapGesture(perform: onLoadMore)
            } else {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                    
                    Text("没有更多数据了")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                }
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityMessage)
        .accessibilityHint(hasMoreData && !isLoading ? "点击加载更多内容" : "")
        .accessibilityAddTraits(hasMoreData && !isLoading ? .isButton : [])
    }
    
    private var accessibilityMessage: String {
        if isLoading {
            return "正在加载更多数据"
        } else if hasMoreData {
            return "点击加载更多"
        } else {
            return "已到达列表底部"
        }
    }
}

// MARK: - Smart Loading Button

struct SmartLoadingButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled && !isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: isEnabled ? action : {}) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 16, weight: .medium))
                        .accessibilityHidden(true)
                }
                
                Text(isLoading ? "处理中..." : title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .disabled(!isEnabled)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isLoading ? "正在处理" : title)
        .accessibilityValue(isLoading ? "请稍候" : "")
        .accessibilityAddTraits(.isButton)
    }
    
    private var backgroundColors: [Color] {
        if isEnabled {
            return [.blue, .blue.opacity(0.8)]
        } else {
            return [.gray, .gray.opacity(0.8)]
        }
    }
    
    private var buttonIcon: String {
        // Could be customized based on button type
        return "checkmark.circle"
    }
}

// MARK: - Data Sync Indicator

struct DataSyncIndicator: View {
    let syncState: SyncState
    let lastSyncTime: Date?
    
    enum SyncState {
        case idle
        case syncing
        case success
        case failed(String)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            syncIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(syncMessage)
                    .font(.caption)
                    .foregroundColor(syncColor)
                
                if let lastSync = lastSyncTime, syncState == .idle || syncState == .success {
                    Text("上次同步: \(formattedSyncTime(lastSync))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(syncBackgroundColor)
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.3), value: syncState.hashableValue)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("数据同步状态")
        .accessibilityValue(syncMessage)
    }
    
    private var syncIcon: some View {
        Group {
            switch syncState {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
            case .syncing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: syncColor))
                    .scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark.circle.fill")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .font(.caption)
        .foregroundColor(syncColor)
        .accessibilityHidden(true)
    }
    
    private var syncMessage: String {
        switch syncState {
        case .idle:
            return "数据已同步"
        case .syncing:
            return "正在同步数据..."
        case .success:
            return "同步完成"
        case .failed(let error):
            return "同步失败: \(error)"
        }
    }
    
    private var syncColor: Color {
        switch syncState {
        case .idle, .success:
            return .green
        case .syncing:
            return .blue
        case .failed:
            return .red
        }
    }
    
    private var syncBackgroundColor: Color {
        switch syncState {
        case .idle, .success:
            return .green.opacity(0.1)
        case .syncing:
            return .blue.opacity(0.1)
        case .failed:
            return .red.opacity(0.1)
        }
    }
    
    private func formattedSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Progress Indicators

struct LinearProgressIndicator: View {
    let progress: Double // 0.0 to 1.0
    let label: String
    let showPercentage: Bool
    
    init(progress: Double, label: String = "", showPercentage: Bool = true) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.label = label
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !label.isEmpty {
                    Text(label)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if showPercentage {
                    Text("\(Int(progress * 100))%")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.isEmpty ? "进度指示器" : label)
        .accessibilityValue("进度 \(Int(progress * 100)) 百分比")
    }
    
    private var progressWidth: CGFloat? {
        // Will be calculated by GeometryReader in actual implementation
        nil
    }
}

// MARK: - Batch Operation Progress

struct BatchOperationProgress: View {
    let completed: Int
    let total: Int
    let currentOperation: String?
    let isCompleted: Bool
    
    private var progress: Double {
        guard total > 0 else { return 0.0 }
        return Double(completed) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress header
            HStack {
                Text("批量操作进度")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("\(completed)/\(total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            LinearProgressIndicator(
                progress: progress,
                label: "",
                showPercentage: false
            )
            
            // Current operation
            if let operation = currentOperation, !isCompleted {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.7)
                    
                    Text("正在处理: \(operation)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("批量操作进度")
        .accessibilityValue("已完成 \(completed) 项，共 \(total) 项")
    }
}

// MARK: - Extensions

extension DataSyncIndicator.SyncState {
    var hashableValue: Int {
        switch self {
        case .idle: return 0
        case .syncing: return 1
        case .success: return 2
        case .failed: return 3
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Loading Indicators") {
    ScrollView {
        VStack(spacing: 30) {
            PullToRefreshIndicator(isRefreshing: false, progress: 0.7)
            
            InfiniteScrollLoader(
                isLoading: false,
                hasMoreData: true,
                onLoadMore: {}
            )
            
            SmartLoadingButton(
                title: "保存数据",
                isLoading: true,
                action: {}
            )
            
            DataSyncIndicator(
                syncState: .syncing,
                lastSyncTime: Date().addingTimeInterval(-300)
            )
            
            BatchOperationProgress(
                completed: 7,
                total: 10,
                currentOperation: "更新客户信息",
                isCompleted: false
            )
        }
        .padding()
    }
}