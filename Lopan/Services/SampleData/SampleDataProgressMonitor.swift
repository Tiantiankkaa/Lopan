//
//  SampleDataProgressMonitor.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/20.
//

import Foundation
import SwiftUI

/// 样本数据生成进度监控器
@MainActor
class SampleDataProgressMonitor: ObservableObject {
    
    // MARK: - 发布属性
    @Published var isGenerating = false
    @Published var currentPhase = ""
    @Published var progress: Double = 0.0
    @Published var detailMessage = ""
    @Published var totalTimeElapsed: TimeInterval = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var completedSteps = 0
    @Published var totalSteps = 0
    
    // MARK: - 私有属性
    private var startTime: Date?
    private var timer: Timer?
    
    // MARK: - 阶段定义
    enum GenerationPhase: String, CaseIterable {
        case preparing = "准备阶段"
        case customers = "生成客户数据"
        case products = "生成产品数据"
        case outOfStock = "生成欠货记录"
        case completing = "完成阶段"
        
        var estimatedDuration: TimeInterval {
            switch self {
            case .preparing: return 2
            case .customers: return 15
            case .products: return 10
            case .outOfStock: return 120  // 最耗时的阶段
            case .completing: return 3
            }
        }
        
        var stepCount: Int {
            switch self {
            case .preparing: return 1
            case .customers: return 3  // 3种客户类型
            case .products: return 5   // 5种产品类别
            case .outOfStock: return 8 // 8个月份
            case .completing: return 1
            }
        }
    }
    
    // MARK: - 生命周期方法
    
    /// 开始监控数据生成
    func startGeneration() {
        isGenerating = true
        startTime = Date()
        progress = 0.0
        completedSteps = 0
        totalSteps = GenerationPhase.allCases.reduce(0) { $0 + $1.stepCount }
        
        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTiming()
        }
        
        updatePhase(.preparing)
    }
    
    /// 结束监控
    func completeGeneration() {
        isGenerating = false
        progress = 1.0
        currentPhase = "生成完成"
        detailMessage = "所有数据生成完成！"
        
        timer?.invalidate()
        timer = nil
        
        // 计算总耗时
        if let startTime = startTime {
            totalTimeElapsed = Date().timeIntervalSince(startTime)
            estimatedTimeRemaining = 0
        }
    }
    
    /// 更新当前阶段
    /// - Parameter phase: 新阶段
    func updatePhase(_ phase: GenerationPhase) {
        currentPhase = phase.rawValue
        detailMessage = "正在\(phase.rawValue)..."
        
        // 重新计算预估时间
        updateEstimatedTime()
    }
    
    /// 更新步骤进度
    /// - Parameters:
    ///   - phase: 当前阶段
    ///   - stepIndex: 当前步骤索引（从0开始）
    ///   - stepName: 步骤名称
    func updateStep(phase: GenerationPhase, stepIndex: Int, stepName: String) {
        // 计算已完成的步骤数
        let previousPhases = GenerationPhase.allCases.prefix(while: { $0 != phase })
        let previousSteps = previousPhases.reduce(0) { $0 + $1.stepCount }
        completedSteps = previousSteps + stepIndex
        
        // 更新进度
        progress = Double(completedSteps) / Double(totalSteps)
        
        // 更新详细信息
        detailMessage = stepName
        
        // 更新预估时间
        updateEstimatedTime()
    }
    
    /// 完成一个步骤
    /// - Parameters:
    ///   - phase: 当前阶段
    ///   - stepIndex: 步骤索引
    ///   - stepName: 步骤名称
    func completeStep(phase: GenerationPhase, stepIndex: Int, stepName: String) {
        // 计算已完成的步骤数
        let previousPhases = GenerationPhase.allCases.prefix(while: { $0 != phase })
        let previousSteps = previousPhases.reduce(0) { $0 + $1.stepCount }
        completedSteps = previousSteps + stepIndex + 1
        
        // 更新进度
        progress = Double(completedSteps) / Double(totalSteps)
        
        // 更新详细信息
        detailMessage = "\(stepName) - 完成"
        
        // 更新预估时间
        updateEstimatedTime()
    }
    
    // MARK: - 私有方法
    
    /// 更新计时信息
    private func updateTiming() {
        guard let startTime = startTime else { return }
        
        totalTimeElapsed = Date().timeIntervalSince(startTime)
        
        // 根据当前进度估算剩余时间
        if progress > 0 {
            let totalEstimatedTime = totalTimeElapsed / progress
            estimatedTimeRemaining = max(0, totalEstimatedTime - totalTimeElapsed)
        }
    }
    
    /// 更新预估时间
    private func updateEstimatedTime() {
        // 基于阶段的预估时间计算
        let totalEstimatedDuration = GenerationPhase.allCases.reduce(0) { $0 + $1.estimatedDuration }
        
        if progress > 0 {
            let estimatedTotalTime = totalEstimatedDuration
            estimatedTimeRemaining = max(0, estimatedTotalTime * (1 - progress))
        }
    }
}

// MARK: - 进度显示视图

/// 样本数据生成进度视图
struct SampleDataProgressView: View {
    @ObservedObject var monitor: SampleDataProgressMonitor
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("正在生成大规模样本数据")
                .font(.title2)
                .fontWeight(.bold)
            
            // 当前阶段
            Text(monitor.currentPhase)
                .font(.headline)
                .foregroundColor(.blue)
            
            // 进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("总体进度")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(monitor.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: monitor.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            
            // 步骤信息
            VStack(alignment: .leading, spacing: 4) {
                Text("当前步骤")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(monitor.detailMessage)
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
            
            // 统计信息
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("已完成步骤")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(monitor.completedSteps)/\(monitor.totalSteps)")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("用时")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(monitor.totalTimeElapsed))
                            .font(.headline)
                    }
                }
                
                if monitor.estimatedTimeRemaining > 0 {
                    HStack {
                        Text("预计剩余时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(monitor.estimatedTimeRemaining))
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    /// 格式化时间显示
    /// - Parameter timeInterval: 时间间隔
    /// - Returns: 格式化的时间字符串
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 预览

#Preview {
    SampleDataProgressView(monitor: {
        let monitor = SampleDataProgressMonitor()
        monitor.isGenerating = true
        monitor.currentPhase = "生成客户数据"
        monitor.progress = 0.35
        monitor.detailMessage = "正在生成标准客户200个..."
        monitor.totalTimeElapsed = 45
        monitor.estimatedTimeRemaining = 85
        monitor.completedSteps = 7
        monitor.totalSteps = 20
        return monitor
    }())
    .padding()
}