//
//  MachineStatisticsView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct MachineStatisticsView: View {
    @ObservedObject var machineService: MachineService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading = false
    
    enum TimeRange: String, CaseIterable {
        case day = "day"
        case week = "week"
        case month = "month"
        
        var displayName: String {
            switch self {
            case .day: return "今日"
            case .week: return "本周"
            case .month: return "本月"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if isLoading {
                        ProgressView("正在加载统计数据...")
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    } else {
                        // Overall statistics
                        overallStatisticsSection
                        
                        // Individual machine statistics
                        machineStatisticsGrid
                    }
                }
                .padding()
            }
            .navigationTitle("生产统计")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        loadStatistics()
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                loadStatistics()
            }
        }
    }
    
    // MARK: - Overall Statistics
    private var overallStatisticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("整体概览")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "总设备数", value: "\(machineService.machines.count)", color: .blue)
                StatCard(title: "在线设备", value: "\(machineService.machines.filter { $0.isActive }.count)", color: .green)
                StatCard(title: "运行设备", value: "\(machineService.machines.filter { $0.status == .running }.count)", color: .orange)
                StatCard(title: "维护设备", value: "\(machineService.machines.filter { $0.status == .maintenance }.count)", color: .red)
            }
        }
    }
    
    // MARK: - Machine Statistics Grid
    private var machineStatisticsGrid: some View {
        VStack(spacing: 16) {
            HStack {
                Text("设备详情")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(machineService.machines, id: \.id) { machine in
                    MachineStatCard(machine: machine)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadStatistics() {
        isLoading = true
        
        Task {
            await machineService.loadMachines()
            isLoading = false
        }
    }
}


// MARK: - Machine Stat Card
struct MachineStatCard: View {
    let machine: WorkshopMachine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Machine #\(machine.machineNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(machine.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(machine.status).opacity(0.2))
                    .foregroundColor(statusColor(machine.status))
                    .cornerRadius(4)
            }
            
            // Key metrics
            VStack(spacing: 8) {
                MetricRow(
                    label: "产量",
                    value: "\(machine.currentProductionCount)",
                    icon: "chart.bar.fill"
                )
                
                MetricRow(
                    label: "利用率",
                    value: String(format: "%.1f%%", machine.utilizationRate * 100),
                    icon: "gauge.fill"
                )
                
                MetricRow(
                    label: "运行时长",
                    value: String(format: "%.1fh", machine.totalRunHours),
                    icon: "clock.fill"
                )
                
                if machine.errorCount > 0 {
                    MetricRow(
                        label: "故障次数",
                        value: "\(machine.errorCount)",
                        icon: "exclamationmark.triangle.fill",
                        valueColor: .red
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func statusColor(_ status: MachineStatus) -> Color {
        switch status {
        case .running: return .green
        case .stopped: return .gray
        case .maintenance: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Metric Row
struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct MachineStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self, User.self, AuditLog.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        let machineService = MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        
        MachineStatisticsView(machineService: machineService)
    }
}