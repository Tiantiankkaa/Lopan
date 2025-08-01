//
//  GunColorSettingsView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct GunColorSettingsView: View {
    @StateObject private var colorService: ColorService
    @StateObject private var machineService: MachineService
    @ObservedObject private var authService: AuthenticationService
    
    @State private var selectedMachine: WorkshopMachine?
    @State private var selectedGun: WorkshopGun?
    @State private var editingCuringTime = ""
    @State private var editingMoldOpeningTimes = ""
    @State private var isEditingBasicSettings = false
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        self._colorService = StateObject(wrappedValue: ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
        self._machineService = StateObject(wrappedValue: MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var body: some View {
        VStack {
            if machineService.isLoading || colorService.isLoading {
                ProgressView("加载数据...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContent
            }
        }
            .refreshable {
                await loadData()
            }
            .alert("Error", isPresented: .constant(colorService.errorMessage != nil || machineService.errorMessage != nil)) {
                Button("确定") {
                    colorService.clearError()
                    machineService.clearError()
                }
            } message: {
                Text(colorService.errorMessage ?? machineService.errorMessage ?? "")
            }
            .sheet(item: $selectedGun, onDismiss: {
                selectedGun = nil
            }) { gun in
                ColorPickerSheet(
                    gun: gun,
                    colors: colorService.colors.filter { $0.isActive },
                    colorService: colorService
                ) {
                    selectedGun = nil
                }
            }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 20) {
            // Machine selector
            machineSelector
            
            if let machine = selectedMachine {
                // Basic machine settings
                basicMachineSettings(for: machine)
                
                // Gun color settings
                gunColorSettings(for: machine)
            } else {
                emptyMachineView
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Machine Selector
    private var machineSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择设备")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(machineService.machines.filter { $0.isActive }, id: \.id) { machine in
                        MachineSelectionCard(
                            machine: machine,
                            isSelected: selectedMachine?.id == machine.id
                        ) {
                            selectedMachine = machine
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Basic Machine Settings
    private func basicMachineSettings(for machine: WorkshopMachine) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("生产效能")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if canManageColors {
                    if isEditingBasicSettings {
                        HStack(spacing: 8) {
                            Button("保存") {
                                saveBasicSettings(for: machine)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("取消") {
                                cancelBasicSettingsEdit(for: machine)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Button("编辑") {
                            startBasicSettingsEdit(for: machine)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            VStack(spacing: 12) {
                // Curing Time
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("硫化时间")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("设置产品硫化所需时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isEditingBasicSettings {
                        HStack(spacing: 4) {
                            TextField("时间", text: $editingCuringTime)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                            
                            Text("秒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("\(machine.curingTime) 秒")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Mold Opening Times
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开模次数")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("设置每个周期的开模次数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isEditingBasicSettings {
                        HStack(spacing: 4) {
                            TextField("次数", text: $editingMoldOpeningTimes)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                            
                            Text("次")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("\(machine.moldOpeningTimes) 次")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Gun Color Settings
    private func gunColorSettings(for machine: WorkshopMachine) -> some View {
        VStack(spacing: 16) {
            Text("料枪颜色配置")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(machine.guns.sorted(by: { $0.name < $1.name }), id: \.id) { gun in
                    GunColorRow(
                        gun: gun,
                        canEdit: canManageColors
                    ) {
                        selectedGun = gun
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Machine View
    private var emptyMachineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("请选择设备来配置基础设置")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Properties
    private var canManageColors: Bool {
        authService.currentUser?.hasRole(.workshopManager) == true ||
        authService.currentUser?.hasRole(.administrator) == true
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        await machineService.loadMachines()
        await colorService.loadActiveColors()
        
        // Select first available machine if none selected
        if selectedMachine == nil {
            selectedMachine = machineService.machines.filter { $0.isActive }.first
        }
    }
    
    private func startBasicSettingsEdit(for machine: WorkshopMachine) {
        editingCuringTime = String(machine.curingTime)
        editingMoldOpeningTimes = String(machine.moldOpeningTimes)
        isEditingBasicSettings = true
    }
    
    private func cancelBasicSettingsEdit(for machine: WorkshopMachine) {
        editingCuringTime = ""
        editingMoldOpeningTimes = ""
        isEditingBasicSettings = false
    }
    
    private func saveBasicSettings(for machine: WorkshopMachine) {
        guard let curingTime = Int(editingCuringTime),
              let moldOpeningTimes = Int(editingMoldOpeningTimes),
              curingTime > 0,
              moldOpeningTimes > 0 else {
            return
        }
        
        Task {
            let success = await machineService.updateMachineBasicSettings(
                machine,
                curingTime: curingTime,
                moldOpeningTimes: moldOpeningTimes
            )
            
            if success {
                isEditingBasicSettings = false
                editingCuringTime = ""
                editingMoldOpeningTimes = ""
                
                // Refresh the selected machine data
                await loadData()
                selectedMachine = machineService.machines.first { $0.id == machine.id }
            }
        }
    }
}

// MARK: - Machine Selection Card
struct MachineSelectionCard: View {
    let machine: WorkshopMachine
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Machine #\(machine.machineNumber)")
                .font(.caption)
                .fontWeight(.semibold)
            
            Image(systemName: "gearshape.2.fill")
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
            
            Text(machine.status.displayName)
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .frame(width: 80, height: 80)
        .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Gun Color Row
struct GunColorRow: View {
    let gun: WorkshopGun
    let canEdit: Bool
    let onEditTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Gun info
            VStack(alignment: .leading, spacing: 4) {
                Text(gun.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("工位 \(gun.stationRangeStart)-\(gun.stationRangeEnd)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Color display
            HStack(spacing: 8) {
                if let hexCode = gun.currentColorHex {
                    Circle()
                        .fill(Color(hex: hexCode) ?? .gray)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
            
            // Edit button
            if canEdit {
                Button("配置") {
                    onEditTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Color Picker Sheet
struct ColorPickerSheet: View {
    let gun: WorkshopGun
    let colors: [ColorCard]
    @ObservedObject var colorService: ColorService
    let onDismiss: () -> Void
    
    @State private var isAssigning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Gun info
                VStack(spacing: 8) {
                    Text("为 \(gun.name) 选择颜色")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("工位 \(gun.stationRangeStart)-\(gun.stationRangeEnd)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Current color
                if let currentColorName = gun.currentColorName,
                   let currentColorHex = gun.currentColorHex {
                    VStack(spacing: 8) {
                        Text("当前颜色")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: currentColorHex) ?? .gray)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentColorName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(currentColorHex)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    Button("清除颜色") {
                        Task {
                            isAssigning = true
                            let success = await colorService.clearGunColor(gun)
                            isAssigning = false
                            if success {
                                onDismiss()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAssigning)
                }
                
                // Available colors
                if colorService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("加载颜色中...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if colors.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("暂无可用颜色")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button("刷新") {
                            Task {
                                await colorService.loadActiveColors()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择新颜色")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(colors, id: \.id) { color in
                                    ColorSelectionCard(color: color) {
                                        Task {
                                            isAssigning = true
                                            let success = await colorService.assignColorToGun(color, gun: gun)
                                            isAssigning = false
                                            if success {
                                                onDismiss()
                                            }
                                        }
                                    }
                                    .disabled(isAssigning)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("选择颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color Selection Card
struct ColorSelectionCard: View {
    let color: ColorCard
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.swiftUIColor)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 2) {
                Text(color.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(color.hexCode)
                    .font(.caption2)
                    .monospaced()
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview
struct GunColorSettingsView_Previews: PreviewProvider {
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
        
        GunColorSettingsView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}
