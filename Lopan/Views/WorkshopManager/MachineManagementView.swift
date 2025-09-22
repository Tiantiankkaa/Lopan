//
//  MachineManagementView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct MachineManagementView: View {
    @StateObject private var machineService: MachineService
    @ObservedObject private var authService: AuthenticationService
    
    @Binding var showingAddMachine: Bool
    @State private var selectedMachineForDetail: WorkshopMachine?
    
    // Keep these for MachineDetailView dependency
    let repositoryFactory: RepositoryFactory
    let auditService: NewAuditingService
    
    init(authService: AuthenticationService, repositoryFactory: RepositoryFactory, auditService: NewAuditingService, showingAddMachine: Binding<Bool>) {
        self.authService = authService
        self.repositoryFactory = repositoryFactory
        self.auditService = auditService
        self._showingAddMachine = showingAddMachine
        
        // Create MachineService in a safer way
        self._machineService = StateObject(wrappedValue: MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if machineService.isLoading {
                    ProgressView("Loading machines...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if machineService.machines.isEmpty {
                    emptyStateView
                } else {
                    machineListView
                }
            }
            .navigationTitle("设备管理")
            .navigationBarBackButtonHidden(true)
            .refreshable {
                await machineService.loadMachines()
            }
        .alert("Error", isPresented: .constant(machineService.errorMessage != nil)) {
            Button("OK") {
                machineService.clearError()
            }
        } message: {
            if let errorMessage = machineService.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(item: $selectedMachineForDetail, onDismiss: {
            selectedMachineForDetail = nil
        }) { machine in
            MachineDetailView(
                machine: machine,
                repositoryFactory: repositoryFactory,
                authService: authService,
                auditService: auditService
            )
        }
        .task {
            await machineService.loadMachines()
        }
        .safeAreaInset(edge: .bottom) {
            // Floating Action Button
            if authService.currentUser?.hasRole(.administrator) == true {
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddMachine = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("添加设备")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无设备")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("点击右上角添加按钮创建第一台设备")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if authService.currentUser?.hasRole(.administrator) == true {
                Button("添加设备") {
                    showingAddMachine = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Machine List View
    private var machineListView: some View {
        List {
            ForEach(machineService.machines, id: \.id) { machine in
                MachineRow(
                    machine: machine,
                    onTap: {
                        selectedMachineForDetail = machine
                    },
                    onStatusChange: { newStatus in
                        Task {
                            await machineService.updateMachineStatus(machine, newStatus: newStatus)
                        }
                    },
                    onDelete: authService.currentUser?.hasRole(.administrator) == true ? {
                        Task {
                            await machineService.deleteMachine(machine)
                        }
                    } : nil
                )
            }
            .onDelete(perform: authService.currentUser?.hasRole(.administrator) == true ? deleteMachines : nil)
        }
    }
    
    // MARK: - Helper Methods
    private func deleteMachines(at indexSet: IndexSet) {
        for index in indexSet {
            let machine = machineService.machines[index]
            Task {
                await machineService.deleteMachine(machine)
            }
        }
    }
}

// MARK: - Machine Row
struct MachineRow: View {
    let machine: WorkshopMachine
    let onTap: () -> Void
    let onStatusChange: (MachineStatus) -> Void
    let onDelete: (() -> Void)?
    
    @State private var showingStatusMenu = false
    
    init(machine: WorkshopMachine, onTap: @escaping () -> Void, onStatusChange: @escaping (MachineStatus) -> Void, onDelete: (() -> Void)? = nil) {
        self.machine = machine
        self.onTap = onTap
        self.onStatusChange = onStatusChange
        self.onDelete = onDelete
    }
    
    var statusColor: Color {
        switch machine.status {
        case .running: return .green
        case .stopped: return .gray
        case .maintenance: return .orange
        case .error: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Machine #\(machine.machineNumber)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if !machine.isActive {
                            Text("停用")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(machine.statusSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Current batch information
                    HStack(spacing: 4) {
                        if machine.hasActiveProductionBatch {
                            Image(systemName: "gear.badge.checkmark")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(machine.currentBatchDisplayName)
                                .font(.caption2)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        } else {
                            Image(systemName: "gear")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("无活跃批次")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(machine.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text("\(String(format: "%.1f", machine.utilizationRate))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Station utilization bar
            HStack(spacing: 2) {
                ForEach(machine.stations.sorted(by: { $0.stationNumber < $1.stationNumber }), id: \.id) { station in
                    Rectangle()
                        .fill(stationColor(for: station.status))
                        .frame(height: 6)
                        .cornerRadius(1)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            // Change machine status action (left swipe)
            Button {
                showingStatusMenu = true
            } label: {
                Label("状态", systemImage: machine.status.iconName)
            }
            .tint(.blue)
            
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete action (right swipe)
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            Button("更改状态") {
                showingStatusMenu = true
            }
        }
        .confirmationDialog("Change Machine Status", isPresented: $showingStatusMenu) {
            ForEach(MachineStatus.allCases, id: \.self) { status in
                Button(status.displayName) {
                    onStatusChange(status)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func stationColor(for status: StationStatus) -> Color {
        switch status {
        case .running: return .green
        case .idle: return .gray.opacity(0.3)
        case .blocked: return .orange
        case .maintenance: return .red
        }
    }
}

// MARK: - Add Machine Sheet
struct AddMachineSheet: View {
    @ObservedObject var machineService: MachineService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAdding = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("新增生产设备")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("系统将自动配置设备编号和工位")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    MachineInfoRow(label: "设备编号", value: "Machine #\((machineService.machines.map(\.machineNumber).max() ?? 0) + 1)")
                    MachineInfoRow(label: "工位数量", value: "12 工位")
                    MachineInfoRow(label: "喷枪配置", value: "Gun A (1-6), Gun B (7-12)")
                    MachineInfoRow(label: "初始状态", value: "已停止")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("确认添加") {
                        Task {
                            isAdding = true
                            let success = await machineService.addMachine()
                            isAdding = false
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAdding)
                    
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAdding)
                }
            }
            .padding()
            .navigationTitle("添加设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Machine Info Row
struct MachineInfoRow: View {
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


// MARK: - Preview
struct MachineManagementView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self, User.self, AuditLog.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        MachineManagementView(
            authService: authService,
            repositoryFactory: repositoryFactory,
            auditService: auditService,
            showingAddMachine: .constant(false)
        )
    }
}