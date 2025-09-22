//
//  TimeRestrictionBanner.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI
import SwiftData

// MARK: - Time Restriction Banner Component (时间限制横幅组件)
struct TimeRestrictionBanner: View {
    let cutoffInfo: ShiftCutoffInfo
    let style: BannerStyle
    
    enum BannerStyle {
        case warning
        case info
        case success
        
        var backgroundColor: Color {
            switch self {
            case .warning:
                return LopanColors.warning.opacity(0.1)
            case .info:
                return LopanColors.primary.opacity(0.1)
            case .success:
                return LopanColors.success.opacity(0.1)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .warning:
                return LopanColors.warning.opacity(0.3)
            case .info:
                return LopanColors.primary.opacity(0.3)
            case .success:
                return LopanColors.success.opacity(0.3)
            }
        }
        
        var iconColor: Color {
            switch self {
            case .warning:
                return .orange
            case .info:
                return .blue
            case .success:
                return .green
            }
        }
        
        var iconName: String {
            switch self {
            case .warning:
                return "clock.badge.exclamationmark"
            case .info:
                return "info.circle"
            case .success:
                return "checkmark.circle"
            }
        }
    }
    
    init(cutoffInfo: ShiftCutoffInfo, style: BannerStyle = .warning) {
        self.cutoffInfo = cutoffInfo
        self.style = style
    }
    
    var body: some View {
        if cutoffInfo.hasRestriction {
            bannerContent
                .transition(.slide.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: cutoffInfo.hasRestriction)
        }
    }
    
    private var bannerContent: some View {
        HStack(spacing: 12) {
            iconSection
            textSection
            Spacer()
            dismissButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(style.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style.borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("时间限制提醒")
        .accessibilityValue(cutoffInfo.restrictionMessage ?? "")
    }
    
    private var iconSection: some View {
        VStack {
            Image(systemName: style.iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(style.iconColor)
            
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("时间限制提醒")
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(cutoffInfo.restrictionMessage ?? "")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if cutoffInfo.isAfterCutoff {
                timeRemainingInfo
            }
        }
    }
    
    private var timeRemainingInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("截止时间: \(formatTime(cutoffInfo.cutoffTime))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 2)
    }
    
    private var dismissButton: some View {
        VStack {
            Button(action: {
                // Could add dismiss functionality if needed
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(style.iconColor)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("查看详细信息")
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Machine Status Checker Component (机器状态检查组件)
struct MachineStatusChecker: View {
    @ObservedObject var machineService: MachineService
    let onStatusChange: (Bool) -> Void
    
    @State private var showingMachineDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            statusHeader
            
            if !machineService.isAnyMachineRunning {
                actionSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .onAppear {
            Task {
                await machineService.forceRefreshMachineStatus()
            }
        }
        .onChange(of: machineService.isAnyMachineRunning) {
            onStatusChange(machineService.isAnyMachineRunning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("机器状态检查")
        .accessibilityValue(statusDescription)
    }
    
    private var statusHeader: some View {
        HStack(spacing: 12) {
            statusIcon
            statusText
            Spacer()
            refreshButton
        }
    }
    
    private var statusIcon: some View {
        Image(systemName: machineService.isAnyMachineRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(machineService.isAnyMachineRunning ? .green : .red)
            .accessibilityHidden(true)
    }
    
    private var statusText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("机器状态检查")
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(statusDescription)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(machineService.isAnyMachineRunning ? .green : .red)
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await machineService.forceRefreshMachineStatus()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("刷新机器状态")
    }
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal, -16)
            
            HStack(spacing: 12) {
                Text("建议操作:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("前往设备管理") {
                    showingMachineDetail = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .sheet(isPresented: $showingMachineDetail) {
            // This would navigate to machine management
            // For now, just a placeholder
            NavigationStack {
                Text("设备管理")
                    .navigationTitle("设备管理")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showingMachineDetail = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Computed Properties (计算属性)
    
    private var backgroundColor: Color {
        return machineService.isAnyMachineRunning ? 
               LopanColors.success.opacity(0.1) : 
               Color.red.opacity(0.1)
    }
    
    private var borderColor: Color {
        return machineService.isAnyMachineRunning ? 
               LopanColors.success.opacity(0.3) : 
               Color.red.opacity(0.3)
    }
    
    private var statusDescription: String {
        if machineService.isAnyMachineRunning {
            return "✓ \(machineService.runningMachineCount)台机器正在运行"
        } else {
            return "⚠️ 无活动生产，请先启动机台"
        }
    }
}

// MARK: - Preview Support (预览支持)
struct TimeRestrictionBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // Warning banner
            TimeRestrictionBanner(
                cutoffInfo: ShiftCutoffInfo(
                    isAfterCutoff: true,
                    cutoffTime: Date(),
                    restrictionMessage: "已过 12:00，今日仅可创建晚班",
                    englishRestrictionMessage: "It's after 12:00 — only the evening shift is available for today"
                ),
                style: .warning
            )
            
            // Info banner
            TimeRestrictionBanner(
                cutoffInfo: ShiftCutoffInfo(
                    isAfterCutoff: false,
                    cutoffTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
                    restrictionMessage: "距离班次截止还有1小时",
                    englishRestrictionMessage: "1 hour remaining before shift cutoff"
                ),
                style: .info
            )
            
            // Machine status checker (mock)
            MachineStatusChecker(
                machineService: createMockMachineService(),
                onStatusChange: { _ in }
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private static func createMockMachineService() -> MachineService {
        // This would need to be properly mocked for actual preview
        // For now, returning a placeholder
        let schema = Schema([WorkshopMachine.self, User.self, AuditLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        return MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
    }
}