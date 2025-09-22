//
//  SystemHealthDashboard.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - System Health Dashboard (系统健康仪表板)

/// Comprehensive system health monitoring dashboard
/// 综合系统健康监控仪表板
struct SystemHealthDashboard: View {
    @ObservedObject var monitoringService: SystemConsistencyMonitoringService
    @State private var selectedCategory: SystemHealthCategory? = nil
    @State private var showingDetailSheet = false
    @State private var selectedHealthCheck: SystemHealthCheckResult? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    headerSection
                    overallHealthSection
                    categoriesSection
                    systemMetricsSection
                    recentHistorySection
                }
                .padding()
            }
            .navigationTitle("系统健康监控")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("刷新") {
                        Task {
                            await monitoringService.triggerManualHealthCheck()
                        }
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(monitoringService.autoRepairEnabled ? "禁用自动修复" : "启用自动修复") {
                        monitoringService.toggleAutoRepair()
                    }
                }
            }
            .sheet(isPresented: $showingDetailSheet) {
                if let healthCheck = selectedHealthCheck {
                    HealthCheckDetailView(healthCheck: healthCheck)
                }
            }
        }
    }
    
    // MARK: - Header Section (头部信息)
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统健康状态")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let lastUpdate = monitoringService.lastMonitoringTime {
                        Text("最后更新: \(formatTime(lastUpdate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(monitoringService.isMonitoring ? "监控中" : "已停止")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(monitoringService.isMonitoring ? .green : .red)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(monitoringService.isMonitoring ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(monitoringService.autoRepairEnabled ? "自动修复" : "手动模式")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Overall Health Section (整体健康状态)
    
    private var overallHealthSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("整体健康状态")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if let report = monitoringService.currentHealthReport {
                VStack(spacing: 12) {
                    // Overall status display
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(report.overallStatus.color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(format: "%.0f", report.overallScore * 100))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Text(report.overallStatus.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(report.overallStatus.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                
                                Text("严重问题: \(report.criticalIssues.count)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            
                           HStack {
                               Image(systemName: "wrench.and.screwdriver.fill")
                                    .foregroundColor(LopanColors.info)
                                    .font(.caption)
                                
                                Text("可自动修复: \(report.autoFixableIssues.count)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                
                                Text("检查时间: \(formatTime(report.timestamp))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Quick metrics
                    HStack(spacing: 16) {
                        systemMetricCard(
                            title: "机台利用率",
                            value: "\(String(format: "%.1f", report.systemMetrics.machineUtilization * 100))%",
                            icon: "gearshape.2",
                            color: report.systemMetrics.machineUtilization >= 0.7 ? .green : .orange
                        )
                        
                        systemMetricCard(
                            title: "缓存命中率",
                            value: "\(String(format: "%.1f", report.systemMetrics.cacheHitRate * 100))%",
                            icon: "memorychip",
                            color: report.systemMetrics.cacheHitRate >= 0.8 ? .green : .orange
                        )
                        
                        systemMetricCard(
                            title: "状态不一致",
                            value: "\(report.systemMetrics.inconsistencyCount)",
                            icon: "exclamationmark.triangle",
                            color: report.systemMetrics.inconsistencyCount == 0 ? .green : .red
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("暂无健康数据")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("点击刷新按钮开始健康检查")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Categories Section (分类检查)
    
    private var categoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("分类健康检查")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if let report = monitoringService.currentHealthReport {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(SystemHealthCategory.allCases, id: \.self) { category in
                        categoryCard(category: category, results: report.categoryResults[category] ?? [])
                    }
                }
            } else {
                Text("暂无分类数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - System Metrics Section (系统指标)
    
    private var systemMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("系统指标详情")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if let metrics = monitoringService.currentHealthReport?.systemMetrics {
                VStack(spacing: 8) {
                    metricsRow(label: "总机台数", value: "\(metrics.totalMachines)", icon: "rectangle.3.group")
                    metricsRow(label: "活跃机台", value: "\(metrics.activeMachines)", icon: "circle.fill", color: .green)
                    metricsRow(label: "运行中机台", value: "\(metrics.runningMachines)", icon: "play.circle.fill", color: .blue)
                    metricsRow(label: "总批次数", value: "\(metrics.totalBatches)", icon: "square.stack.3d.down.right")
                    metricsRow(label: "活跃批次", value: "\(metrics.activeBatches)", icon: "square.fill", color: .orange)
                    metricsRow(label: "已完成批次", value: "\(metrics.completedBatches)", icon: "checkmark.square.fill", color: .green)
                    
                    if metrics.averageProcessingTime > 0 {
                        metricsRow(
                            label: "平均处理时间",
                            value: formatDuration(metrics.averageProcessingTime),
                            icon: "clock.fill",
                            color: .purple
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Recent History Section (最近历史)
    
    private var recentHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("健康历史")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("最近 \(monitoringService.monitoringHistory.count) 次检查")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !monitoringService.monitoringHistory.isEmpty {
                VStack(spacing: 8) {
                    ForEach(monitoringService.monitoringHistory.suffix(5).reversed(), id: \.timestamp) { report in
                        historyRow(report: report)
                    }
                }
            } else {
                Text("暂无历史数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Helper Views
    
    private func systemMetricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private func categoryCard(category: SystemHealthCategory, results: [SystemHealthCheckResult]) -> some View {
        VStack(spacing: 8) {
           Image(systemName: category.icon)
               .font(.system(size: 20, weight: .medium))
                .foregroundColor(LopanColors.info)
            
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            if !results.isEmpty {
                let overallStatus = results.min(by: { $0.status.score < $1.status.score })?.status ?? .unknown
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(overallStatus.color)
                        .frame(width: 8, height: 8)
                    
                    Text(overallStatus.displayName)
                        .font(.caption2)
                        .foregroundColor(overallStatus.color)
                }
                
                Text("\(results.count) 项检查")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("无数据")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
        .onTapGesture {
            if !results.isEmpty {
                selectedCategory = category
                // Could show category detail view
            }
        }
    }
    
    private func metricsRow(label: String, value: String, icon: String, color: Color = .primary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
    
    private func historyRow(report: SystemHealthReport) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(report.overallStatus.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(report.timestamp))
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text("\(report.overallStatus.displayName) - \(String(format: "%.0f", report.overallScore * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !report.criticalIssues.isEmpty {
                Text("\(report.criticalIssues.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                    )
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Health Check Detail View (健康检查详情视图)

struct HealthCheckDetailView: View {
    let healthCheck: SystemHealthCheckResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status header
                    VStack(alignment: .leading, spacing: 12) {
                       HStack {
                           Image(systemName: healthCheck.category.icon)
                               .font(.system(size: 24, weight: .medium))
                                .foregroundColor(LopanColors.info)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(healthCheck.checkName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(healthCheck.category.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Circle()
                                    .fill(healthCheck.status.color)
                                    .frame(width: 24, height: 24)
                                
                                Text(healthCheck.status.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(healthCheck.status.color)
                            }
                        }
                        
                        Text(healthCheck.message)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    // Details section
                    if !healthCheck.details.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("详细信息")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ForEach(healthCheck.details, id: \.self) { detail in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    
                                    Text(detail)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    
                    // Recommendations section
                    if !healthCheck.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("建议操作")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ForEach(healthCheck.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.top, 2)
                                    
                                    Text(recommendation)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    
                    // Auto-fix indicator
                   if healthCheck.canAutoFix {
                       HStack(spacing: 8) {
                           Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(LopanColors.info)
                           
                            Text("此问题可以自动修复")
                                .font(.caption)
                                .foregroundColor(LopanColors.info)
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LopanColors.info.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("检查详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}
