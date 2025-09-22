//
//  MachineDetailView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/1.
//

import SwiftUI
import SwiftData

struct MachineDetailView: View {
    let machine: WorkshopMachine
    @StateObject private var machineService: MachineService
    @StateObject private var batchService: ProductionBatchService
    @ObservedObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var showingStatusChange = false
    @State private var showingBatchOperations = false
    @State private var showingResetConfirmation = false
    @State private var selectedStations: Set<String> = []
    @State private var isSelectionMode = false
    
    init(machine: WorkshopMachine, repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.machine = machine
        self.authService = authService
        self._machineService = StateObject(wrappedValue: MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
        self._batchService = StateObject(wrappedValue: ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if machineService.isLoading || batchService.isLoading {
                    ProgressView("加载数据...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Machine #\(machine.machineNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 1 && canManageMachine { // Stations tab
                        HStack {
                            if isSelectionMode {
                                Button("取消") {
                                    isSelectionMode = false
                                    selectedStations.removeAll()
                                }
                            } else {
                                Menu {
                                    Button("批量操作") {
                                        isSelectionMode = true
                                    }
                                    
                                    Button("一键重置", role: .destructive) {
                                        showingResetConfirmation = true
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }
                }
            }
            .refreshable {
                await loadData()
            }
            .confirmationDialog("更改设备状态", isPresented: $showingStatusChange) {
                ForEach(MachineStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        Task {
                            await machineService.updateMachineStatus(machine, newStatus: status)
                        }
                    }
                }
                Button("取消", role: .cancel) { }
            }
            .alert("Error", isPresented: .constant(hasError)) {
                Button("确定") {
                    clearErrors()
                }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadData()
            }
            .confirmationDialog("一键重置", isPresented: $showingResetConfirmation) {
                Button("确认重置", role: .destructive) {
                    Task {
                        await machineService.resetMachineToIdle(machine)
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("将设备状态重置为停止，所有工位重置为空闲状态。此操作不可撤销。")
            }
            .confirmationDialog("批量操作", isPresented: $showingBatchOperations) {
                Button("全部设为运行中") {
                    Task {
                        let selectedStationObjects = machine.stations.filter { selectedStations.contains($0.id) }
                        await machineService.batchUpdateStationStatus(selectedStationObjects, newStatus: .running)
                        isSelectionMode = false
                        selectedStations.removeAll()
                    }
                }
                Button("全部设为空闲") {
                    Task {
                        let selectedStationObjects = machine.stations.filter { selectedStations.contains($0.id) }
                        await machineService.batchUpdateStationStatus(selectedStationObjects, newStatus: .idle)
                        isSelectionMode = false
                        selectedStations.removeAll()
                    }
                }
                Button("全部设为维护") {
                    Task {
                        let selectedStationObjects = machine.stations.filter { selectedStations.contains($0.id) }
                        await machineService.batchUpdateStationStatus(selectedStationObjects, newStatus: .maintenance)
                        isSelectionMode = false
                        selectedStations.removeAll()
                    }
                }
                Button("全部设为阻塞") {
                    Task {
                        let selectedStationObjects = machine.stations.filter { selectedStations.contains($0.id) }
                        await machineService.batchUpdateStationStatus(selectedStationObjects, newStatus: .blocked)
                        isSelectionMode = false
                        selectedStations.removeAll()
                    }
                }
                Button("取消", role: .cancel) {
                    isSelectionMode = false
                    selectedStations.removeAll()
                }
            } message: {
                Text("对选中的 \(selectedStations.count) 个工位执行批量操作")
            }
        }
    }
    
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            // Overview Tab
            machineOverviewTab
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("概览")
                }
                .tag(0)
            
            // Stations Tab
            stationsTab
                .tabItem {
                    Image(systemName: "square.grid.3x3")
                    Text("工位")
                }
                .tag(1)
            
            // Production Tab
            productionTab
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("生产")
                }
                .tag(2)
            
            // Guns Tab
            gunsTab
                .tabItem {
                    Image(systemName: "paintbrush")
                    Text("喷枪")
                }
                .tag(3)
        }
    }
    
    // MARK: - Overview Tab
    private var machineOverviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                statusCard
                
                // Basic Info Card
                basicInfoCard
                
                // Performance Metrics Card
                performanceCard
                
                // Machine Status Modification Button
                if canManageMachine {
                    machineStatusModificationButton
                }
                
                // Current Production Card
                if machine.hasActiveProductionBatch {
                    currentProductionCard
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("设备状态")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: machine.status.iconName)
                                .foregroundColor(.white)
                                .font(.title3)
                        )
                    
                    Text(machine.status.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("利用率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", machine.utilizationRate * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("活跃工位")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(machine.activeStationsCount)/12")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var basicInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("基本信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                MachineDetailInfoRow(label: "设备编号", value: "Machine #\(machine.machineNumber)")
                MachineDetailInfoRow(label: "创建时间", value: DateFormatter.localizedString(from: machine.createdAt, dateStyle: .medium, timeStyle: .short))
                MachineDetailInfoRow(label: "运行时长", value: "\(String(format: "%.1f", machine.totalRunHours)) 小时")
                MachineDetailInfoRow(label: "日产目标", value: "\(machine.dailyTarget) 件")
                MachineDetailInfoRow(label: "当日产量", value: "\(machine.currentProductionCount) 件")
                if let notes = machine.notes, !notes.isEmpty {
                    MachineDetailInfoRow(label: "备注", value: notes)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var performanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("性能指标")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(machine.currentProductionCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("今日产量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("\(machine.errorCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("故障次数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("\(Int(machine.utilizationRate * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("利用率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var machineStatusModificationButton: some View {
        Button(action: {
            showingStatusChange = true
        }) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title3)
                Text("设备状态修改")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var currentProductionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("当前生产")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                MachineDetailInfoRow(label: "生产模式", value: machine.productionModeDisplayName)
                if let batchId = machine.currentBatchId {
                    MachineDetailInfoRow(label: "批次号", value: batchId)
                }
                if let lastUpdate = machine.lastConfigurationUpdate {
                    MachineDetailInfoRow(label: "配置更新", value: DateFormatter.localizedString(from: lastUpdate, dateStyle: .short, timeStyle: .short))
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Stations Tab
    private var stationsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("工位状态")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if isSelectionMode {
                        Button(selectedStations.count == machine.stations.count ? "取消全选" : "全选") {
                            if selectedStations.count == machine.stations.count {
                                selectedStations.removeAll()
                            } else {
                                selectedStations = Set(machine.stations.map(\.id))
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                if isSelectionMode && !selectedStations.isEmpty {
                    HStack {
                        Text("已选择 \(selectedStations.count) 个工位")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("批量操作") {
                            showingBatchOperations = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(LopanColors.primary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(machine.stations.sorted(by: { $0.stationNumber < $1.stationNumber }), id: \.id) { station in
                        SelectableStationCard(
                            station: station,
                            isSelected: selectedStations.contains(station.id),
                            isSelectionMode: isSelectionMode,
                            onTap: {
                                if isSelectionMode {
                                    if selectedStations.contains(station.id) {
                                        selectedStations.remove(station.id)
                                    } else {
                                        selectedStations.insert(station.id)
                                    }
                                }
                                // Removed the else clause that opened station detail
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Production Tab
    private var productionTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("生产历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Production history would go here
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("生产历史功能")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("此功能正在开发中")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
            }
            .padding()
        }
    }
    
    // MARK: - Guns Tab
    private var gunsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("喷枪配置")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    ForEach(machine.guns.sorted(by: { $0.name < $1.name }), id: \.id) { gun in
                        GunCard(gun: gun)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Properties
    private var canManageMachine: Bool {
        authService.currentUser?.hasRole(.workshopManager) == true ||
        authService.currentUser?.hasRole(.administrator) == true
    }
    
    private var statusColor: Color {
        switch machine.status {
        case .running: return .green
        case .stopped: return .gray
        case .maintenance: return .orange
        case .error: return .red
        }
    }
    
    private var hasError: Bool {
        machineService.errorMessage != nil || batchService.errorMessage != nil
    }
    
    private var errorMessage: String {
        machineService.errorMessage ?? batchService.errorMessage ?? ""
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        await machineService.loadMachines()
        // Load production batches if needed
    }
    
    private func clearErrors() {
        machineService.clearError()
        batchService.clearError()
    }
}

// MARK: - Supporting Views
struct MachineDetailInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct StationCard: View {
    let station: WorkshopStation
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("工位 \(station.stationNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("产量: \(station.totalProductionCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
    
    private var statusColor: Color {
        switch station.status {
        case .running: return .green
        case .idle: return .gray
        case .blocked: return .orange
        case .maintenance: return .red
        }
    }
}

struct SelectableStationCard: View {
    let station: WorkshopStation
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("工位 \(station.stationNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("产量: \(station.totalProductionCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? LopanColors.primary.opacity(0.1) : Color(UIColor.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? LopanColors.primary : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private var statusColor: Color {
        switch station.status {
        case .running: return .green
        case .idle: return .gray
        case .blocked: return .orange
        case .maintenance: return .red
        }
    }
}

struct GunCard: View {
    let gun: WorkshopGun
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gun.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("工位 \(gun.stationRangeStart)-\(gun.stationRangeEnd)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let hexCode = gun.currentColorHex {
                    Circle()
                        .fill(Color(hex: hexCode) ?? .gray)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(LopanColors.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(gun.displayColorInfo)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let hexCode = gun.currentColorHex {
                        Text(hexCode)
                            .font(.caption2)
                            .monospaced()
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}


// MARK: - Preview
struct MachineDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self,
            ColorCard.self, ProductionBatch.self, ProductConfig.self,
            User.self, AuditLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        let sampleMachine = WorkshopMachine(machineNumber: 1, createdBy: "admin")
        
        MachineDetailView(
            machine: sampleMachine,
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}