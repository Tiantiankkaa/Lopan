//
//  BatchCreationView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI
import SwiftData

// MARK: - Batch Creation View (批次创建视图)
struct BatchCreationView: View {
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    // Pre-selected values from parent view
    let selectedDate: Date
    let selectedShift: Shift
    let selectedMachineIds: Set<String>
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var productionBatchService: ProductionBatchService
    @StateObject private var machineService: MachineService
    @StateObject private var batchEditPermissionService: StandardBatchEditPermissionService
    @StateObject private var colorService: ColorService
    @StateObject private var batchMachineCoordinator: StandardBatchMachineCoordinator
    @StateObject private var cacheWarmingService: CacheWarmingService
    @StateObject private var synchronizationService: MachineStateSynchronizationService
    @StateObject private var systemMonitoringService: SystemConsistencyMonitoringService
    @StateObject private var enhancedSecurityService: EnhancedSecurityAuditService
    
    @State private var availableMachines: [WorkshopMachine] = []
    @State private var currentMachineIndex: Int = 0
    @State private var productConfigs: [ProductConfig] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingProductSelection = false
    @State private var availableProducts: [Product] = []
    @State private var showingConflictWarning = false
    @State private var conflictingBatch: ProductionBatch?
    @State private var showingCacheDebug = false
    @State private var showingSystemHealthDashboard = false
    
    @StateObject private var dateShiftPolicy = StandardDateShiftPolicy()
    private let timeProvider = SystemTimeProvider()
    
    init(
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        auditService: NewAuditingService,
        selectedDate: Date,
        selectedShift: Shift,
        selectedMachineIds: Set<String>
    ) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        self.selectedDate = selectedDate
        self.selectedShift = selectedShift
        self.selectedMachineIds = selectedMachineIds
        
        // Initialize services
        let productionService = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        self._productionBatchService = StateObject(wrappedValue: productionService)
        
        let machineServiceInstance = MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        self._machineService = StateObject(wrappedValue: machineServiceInstance)
        
        let permissionService = StandardBatchEditPermissionService(authService: authService)
        self._batchEditPermissionService = StateObject(wrappedValue: permissionService)
        
        let colorServiceInstance = ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        self._colorService = StateObject(wrappedValue: colorServiceInstance)
        
        let batchMachineCoordinatorInstance = StandardBatchMachineCoordinator(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: authService
        )
        self._batchMachineCoordinator = StateObject(wrappedValue: batchMachineCoordinatorInstance)
        
        let cacheWarmingServiceInstance = CacheWarmingServiceFactory.createService(
            batchMachineCoordinator: batchMachineCoordinatorInstance,
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            auditService: auditService,
            authService: authService,
            strategy: .combined
        )
        self._cacheWarmingService = StateObject(wrappedValue: cacheWarmingServiceInstance)
        
        let synchronizationServiceInstance = MachineStateSynchronizationService(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            batchMachineCoordinator: batchMachineCoordinatorInstance,
            auditService: auditService,
            authService: authService
        )
        self._synchronizationService = StateObject(wrappedValue: synchronizationServiceInstance)
        
        let systemMonitoringServiceInstance = SystemConsistencyMonitoringService(
            machineRepository: repositoryFactory.machineRepository,
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            batchMachineCoordinator: batchMachineCoordinatorInstance,
            synchronizationService: synchronizationServiceInstance,
            cacheWarmingService: cacheWarmingServiceInstance,
            auditService: auditService,
            authService: authService
        )
        self._systemMonitoringService = StateObject(wrappedValue: systemMonitoringServiceInstance)
        
        let enhancedSecurityServiceInstance = EnhancedSecurityAuditService(
            baseAuditService: auditService,
            authService: authService
        )
        self._enhancedSecurityService = StateObject(wrappedValue: enhancedSecurityServiceInstance)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    headerSection
                    dateTimeInfoSection
                    machineInfoSection
                    productConfigurationSection
                    validationSection
                    createButtonSection
                }
                .padding()
            }
            .navigationTitle("创建批次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("创建") {
                        Task {
                            await createBatch()
                        }
                    }
                    .disabled(!canCreateBatch)
                }
            }
            .task {
                await loadInitialData()
                // Start cache warming for better performance
                cacheWarmingService.startAutomaticWarming()
                // Start state synchronization monitoring
                synchronizationService.startAutomaticScanning()
                // Start comprehensive system monitoring
                systemMonitoringService.startMonitoring()
                // Log session start
                try? await enhancedSecurityService.logSecurityEvent(
                    category: .systemOperation,
                    severity: .info,
                    eventName: "batch_creation_session_started",
                    description: "用户开始批次创建会话",
                    details: [
                        "selected_date": DateTimeUtilities.formatDate(selectedDate),
                        "selected_shift": selectedShift.displayName,
                        "machine_count": "\(selectedMachineIds.count)"
                    ],
                    sensitivityLevel: .internal
                )
            }
            .onDisappear {
                // Stop services when view disappears
                cacheWarmingService.stopAutomaticWarming()
                synchronizationService.stopAutomaticScanning()
                systemMonitoringService.stopMonitoring()
                // Log session end
                Task {
                    try? await enhancedSecurityService.logSecurityEvent(
                        category: .systemOperation,
                        severity: .info,
                        eventName: "batch_creation_session_ended",
                        description: "用户结束批次创建会话"
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if showingCacheDebug {
                    cacheDebugOverlay
                }
            }
            .onLongPressGesture(minimumDuration: 2.0) {
                showingCacheDebug.toggle()
            }
            .alert("错误", isPresented: $showingError, presenting: errorMessage) { _ in
                Button("确定", role: .cancel) { }
            } message: { message in
                Text(message)
            }
            .alert("批次冲突", isPresented: $showingConflictWarning, presenting: conflictingBatch) { batch in
                Button("取消", role: .cancel) { }
                Button("强制创建", role: .destructive) {
                    Task {
                        await createBatch(forceCreate: true)
                    }
                }
            } message: { batch in
                Text("该时段和设备已存在批次 \(batch.batchNumber)。是否要强制创建？")
            }
        }
    }
    
    // MARK: - Header Section (头部信息)
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.stack.3d.down.right.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("新建生产批次")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("为指定时段和设备创建生产批次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
        }
    }
    
    // MARK: - Date Time Info Section (日期时间信息)
    
    private var dateTimeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "生产时段", icon: "calendar.badge.clock")
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("日期")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(DateTimeUtilities.formatDate(selectedDate))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("班次")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedShift == .morning ? "sun.min" : "moon")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedShift == .morning ? .orange : .indigo)
                            
                            Text(selectedShift.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text(selectedShift.timeRangeDisplay)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                timeRestrictionIndicator
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    private var timeRestrictionIndicator: some View {
        let cutoffInfo = dateShiftPolicy.getCutoffInfo(for: selectedDate, currentTime: timeProvider.now)
        
        return VStack(spacing: 4) {
            if cutoffInfo.hasRestriction {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("限制模式")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.green)
                
                Text("正常模式")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((cutoffInfo.hasRestriction ? Color.orange : Color.green).opacity(0.1))
        )
    }
    
    // MARK: - Machine Info Section (设备信息)
    
    private var machineInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "生产设备", icon: "gearshape.2")
                
                Spacer()
                
                if availableMachines.count > 1 {
                    machineSelector
                }
            }
            
            if availableMachines.isEmpty {
                machineLoadingState
            } else {
                let currentMachine = availableMachines[safe: currentMachineIndex]
                if let machine = currentMachine {
                    machineInfoCard(machine: machine)
                } else {
                    machineLoadingState
                }
            }
        }
    }
    
    private var machineSelector: some View {
        HStack(spacing: 8) {
            Button(action: {
                if currentMachineIndex > 0 {
                    currentMachineIndex -= 1
                    Task {
                        await loadAvailableProducts()
                        await checkForConflictingBatches()
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(currentMachineIndex > 0 ? .blue : .gray)
            }
            .disabled(currentMachineIndex <= 0)
            
            Text("\(currentMachineIndex + 1)/\(availableMachines.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                if currentMachineIndex < availableMachines.count - 1 {
                    currentMachineIndex += 1
                    Task {
                        await loadAvailableProducts()
                        await checkForConflictingBatches()
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(currentMachineIndex < availableMachines.count - 1 ? .blue : .gray)
            }
            .disabled(currentMachineIndex >= availableMachines.count - 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private func machineInfoCard(machine: WorkshopMachine) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: machine.isActive ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(machine.isActive ? .green : .orange)
                
                Circle()
                    .fill(machine.isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("机器 \(machine.machineNumber)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("编号: \(machine.machineNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(machine.isActive ? "设备状态正常" : "设备需要维护")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(machine.isActive ? .green : .orange)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(machine.stations.count)个工位")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(machine.totalGuns)支喷枪")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var machineLoadingState: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("正在加载设备信息...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Product Configuration Section (产品配置)
    
    private var productConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "产品配置", icon: "cube.box")
                
                Spacer()
                
                Text("仅支持颜色修改")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if productConfigs.isEmpty {
                productEmptyStateRestricted
            } else {
                productConfigList
            }
        }
    }
    
    private var productEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无产品配置")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("点击\"添加产品\"开始配置生产产品")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("添加产品") {
                showingProductSelection = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var productEmptyStateRestricted: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无当前运行产品")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(productConfigErrorMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var productConfigList: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(productConfigs.enumerated()), id: \.offset) { index, config in
                productConfigCard(config: config, index: index)
            }
        }
    }
    
    private func productConfigCard(config: ProductConfig, index: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.productName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                }
                
                Spacer()
                
                Text("仅限颜色修改")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.1))
                    )
            }
            
            // Color selection interface
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("颜色:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(colorService.colors.filter { $0.isActive }, id: \.id) { color in
                        Button(action: {
                            updateProductColor(at: index, colorId: color.id, colorName: color.name)
                        }) {
                            HStack {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 16, height: 16)
                                Text(color.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(getColorName(for: config.primaryColorId))
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
    
    // MARK: - Validation Section (验证信息)
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "创建验证", icon: "checkmark.shield")
            
            validationChecklist
        }
    }
    
    private var validationChecklist: some View {
        VStack(spacing: 8) {
            validationRow(
                title: "时段可用性",
                isValid: dateTimeValid,
                message: dateTimeValid ? "所选时段可用" : "所选时段存在限制"
            )
            
            validationRow(
                title: "设备状态",
                isValid: availableMachines[safe: currentMachineIndex]?.canReceiveNewTasks == true,
                message: (availableMachines[safe: currentMachineIndex]?.canReceiveNewTasks == true) ? "当前设备运行正常" : "当前设备需要维护"
            )
            
            validationRow(
                title: "产品配置",
                isValid: !productConfigs.isEmpty,
                message: !productConfigs.isEmpty ? "\(productConfigs.count)个运行产品已加载" : productConfigErrorMessage
            )
            
            validationRow(
                title: "冲突检查",
                isValid: conflictingBatch == nil,
                message: conflictingBatch == nil ? "无批次冲突" : "存在时段冲突"
            )
            
            // State consistency validation
            let highSeverityIssues = synchronizationService.detectedInconsistencies.filter { $0.severity == .high }
            validationRow(
                title: "状态一致性",
                isValid: highSeverityIssues.isEmpty,
                message: highSeverityIssues.isEmpty ? "状态一致" : "检测到 \(highSeverityIssues.count) 个高优先级状态问题"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func validationRow(title: String, isValid: Bool, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isValid ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.caption2)
                    .foregroundColor(isValid ? .green : .red)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Create Button Section (创建按钮)
    
    private var createButtonSection: some View {
        VStack(spacing: 12) {
            if isCreating {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("正在创建批次...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            } else {
                Button(action: {
                    Task {
                        await createBatch()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                        
                        Text("创建生产批次")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canCreateBatch ? Color.blue : Color.gray)
                    )
                }
                .disabled(!canCreateBatch)
            }
            
            if !canCreateBatch {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Product Selection Sheet (产品选择弹出框)
    
    private var productSelectionSheet: some View {
        NavigationView {
            List {
                ForEach(availableProducts, id: \.id) { product in
                    Button(action: {
                        addProductConfig(from: product)
                        showingProductSelection = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("ID: \(product.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("选择产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingProductSelection = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    // Date formatting function replaced with DateTimeUtilities
    
    private func addProductConfig(from product: Product) {
        let config = ProductConfig(
            batchId: "", // Will be set when batch is created
            productName: product.name,
            primaryColorId: "default",
            occupiedStations: [],
            productId: product.id
        )
        productConfigs.append(config)
    }
    
    private func updateProductColor(at index: Int, colorId: String, colorName: String) {
        guard index < productConfigs.count else { return }
        productConfigs[index].primaryColorId = colorId
        // Update the display name for better UI experience  
        if let colorCard = colorService.colors.first(where: { $0.id == colorId }) {
            productConfigs[index].primaryColorId = colorCard.name
        }
    }
    
    // MARK: - Computed Properties (计算属性)
    
    private var canCreateBatch: Bool {
        guard let currentMachine = availableMachines[safe: currentMachineIndex] else { return false }
        return dateTimeValid && 
               currentMachine.canReceiveNewTasks && 
               !productConfigs.isEmpty && 
               !isCreating
    }
    
    private var dateTimeValid: Bool {
        let allowedShifts = dateShiftPolicy.allowedShifts(for: selectedDate, currentTime: timeProvider.now)
        return allowedShifts.contains(selectedShift)
    }
    
    private var validationMessage: String {
        if !dateTimeValid {
            return "所选时段不可用"
        } else if availableMachines.isEmpty {
            return "没有可用设备"
        } else if availableMachines[safe: currentMachineIndex]?.canReceiveNewTasks != true {
            return "当前设备状态异常"
        } else if productConfigs.isEmpty {
            return productConfigErrorMessage
        }
        return ""
    }
    
    private var productConfigErrorMessage: String {
        guard let currentMachine = availableMachines[safe: currentMachineIndex] else {
            return "没有可用设备"
        }
        
        // Check if machine is currently running
        let isMachineCurrentlyRunning = currentMachine.status == .running && currentMachine.isActive
        
        if !isMachineCurrentlyRunning {
            return "机器 \(currentMachine.machineNumber) 当前未运行。只有正在运行的机器才能创建批次进行颜色修改。"
        }
        
        // Check if this is a next day evening shift
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: selectedDate)
        
        if selectedShift == .evening && targetDate > today {
            // This is a next day evening shift
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd"
            return "无法创建 \(dateFormatter.string(from: selectedDate)) 晚班批次。次日晚班只能基于次日早班的生产内容进行颜色修改，但次日早班还未开始生产。请先等待次日早班批次创建并执行后，再创建晚班批次。"
        }
        
        // Get the previous shift info to provide context
        let previousShiftInfo = getPreviousShiftInfo(for: selectedDate, shift: selectedShift)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd"
        
        // Provide more specific error message with shift context
        return "机器 \(currentMachine.machineNumber) 正在运行，但在 \(dateFormatter.string(from: previousShiftInfo.date)) \(previousShiftInfo.shift.displayName)班次 没有找到可供颜色修改的产品批次。请检查该设备的当前生产状态或前一班次的批次配置。"
    }
    
    // MARK: - Shift Logic Helpers (班次逻辑辅助方法)
    
    private func getPreviousShiftInfo(for date: Date, shift: Shift) -> (date: Date, shift: Shift) {
        if shift == .evening {
            // Evening shift copies from same day morning shift
            return (date: date, shift: .morning)
        } else {
            // Morning shift copies from previous day evening shift
            let calendar = Calendar.current
            let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            return (date: previousDay, shift: .evening)
        }
    }
    
    // MARK: - Data Loading and Actions (数据加载和操作)
    
    private func loadInitialData() async {
        // 首先加载机器（必须先完成）
        await loadAvailableMachines()
        
        // 然后加载依赖于机器的产品配置
        await loadAvailableProducts()
        
        // 其他可以并发执行的任务
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.checkForConflictingBatches()
            }
            group.addTask {
                await self.colorService.loadColors()
            }
        }
    }
    
    private func loadAvailableMachines() async {
        do {
            var machines: [WorkshopMachine] = []
            for machineId in selectedMachineIds {
                if let machine = try await repositoryFactory.machineRepository.fetchMachine(byId: machineId) {
                    machines.append(machine)
                }
            }
            await MainActor.run {
                self.availableMachines = machines.sorted { $0.machineNumber < $1.machineNumber }
            }
        } catch {
            await showError("加载设备信息失败: \(error.localizedDescription)")
        }
    }
    
    private func loadAvailableProducts() async {
        do {
            guard let currentMachine = availableMachines[safe: currentMachineIndex] else { 
                return 
            }
            
            // Use the unified BatchMachineCoordinator for optimized and consistent logic
            let inheritableProducts = try await batchMachineCoordinator.getInheritableProducts(
                machineId: currentMachine.id,
                date: selectedDate,
                shift: selectedShift
            )
            
            await MainActor.run {
                self.productConfigs = inheritableProducts
                // No need to set availableProducts since we're not allowing new product additions
                self.availableProducts = []
            }
        } catch {
            await showError("加载当前运行产品失败: \(error.localizedDescription)")
        }
    }
    
    private func checkForConflictingBatches() async {
        do {
            guard let currentMachine = availableMachines[safe: currentMachineIndex] else { return }
            
            let hasConflict = try await repositoryFactory.productionBatchRepository.hasConflictingBatches(
                forDate: selectedDate,
                shift: selectedShift,
                machineId: currentMachine.id,
                excludingBatchId: nil
            )
            
            if hasConflict {
                let existingBatches = try await repositoryFactory.productionBatchRepository.fetchBatches(
                    forDate: selectedDate,
                    shift: selectedShift
                )
                let conflicting = existingBatches.first { $0.machineId == currentMachine.id }
                
                await MainActor.run {
                    self.conflictingBatch = conflicting
                }
            }
        } catch {
            await showError("检查批次冲突失败: \(error.localizedDescription)")
        }
    }
    
    private func createBatch(forceCreate: Bool = false) async {
        guard canCreateBatch else { return }
        
        // Check for conflicts unless forcing
        if !forceCreate && conflictingBatch != nil {
            await MainActor.run {
                showingConflictWarning = true
            }
            return
        }
        
        await MainActor.run {
            isCreating = true
        }
        
        do {
            guard let currentMachine = availableMachines[safe: currentMachineIndex] else {
                await showError("没有可用的设备")
                return
            }
            
            // Infer production mode from existing product configurations
            let inferredMode = inferProductionMode(from: productConfigs)
            
            // Create batch using ProductionBatchService
            if let batch = await productionBatchService.createShiftBatch(
                machineId: currentMachine.id,
                mode: inferredMode,
                targetDate: selectedDate,
                shift: selectedShift
            ) {
                // Add product configurations to batch
                for var config in productConfigs {
                    config.batchId = batch.id
                    try await repositoryFactory.productionBatchRepository.addProductConfig(config, toBatch: batch.id)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } else {
                await showError("创建批次失败")
            }
        } catch {
            await showError("创建批次时发生错误: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isCreating = false
        }
    }
    
    /// Infer production mode from existing product configurations
    private func inferProductionMode(from configs: [ProductConfig]) -> ProductionMode {
        // Check if any product has dual colors (secondary color is not nil)
        let hasDualColorProducts = configs.contains { config in
            config.secondaryColorId != nil && !config.secondaryColorId!.isEmpty
        }
        
        // Also check the minimum stations per product to determine mode
        let hasHighStationCount = configs.contains { config in
            config.occupiedStations.count >= ProductionMode.dualColor.minStationsPerProduct
        }
        
        // If we have dual color products or high station counts, assume dual color mode
        if hasDualColorProducts || hasHighStationCount {
            return .dualColor
        }
        
        // Default to single color mode
        return .singleColor
    }
    
    private func showError(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.showingError = true
        }
    }
    
    // MARK: - Cache Debug Overlay (缓存调试覆层)
    
    private var cacheDebugOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cache Debug")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("×") {
                    showingCacheDebug = false
                }
                .foregroundColor(.white)
                .font(.caption)
            }
            
            let metrics = batchMachineCoordinator.getCacheMetrics()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hit Rate: \(String(format: "%.1f", metrics.hitRate * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("Entries: \(metrics.entries)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("Hits: \(metrics.hits) | Misses: \(metrics.misses)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("Evictions: \(metrics.evictions)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                if let warmingResults = cacheWarmingService.warmingResults {
                    Text("Last Warming: \(String(format: "%.1f", warmingResults.duration))s")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Text("Warmed: \(warmingResults.machinesWarmed) (\(warmingResults.successCount)/\(warmingResults.machinesWarmed))")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white)
                
                Text("State Sync")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                let inconsistencies = synchronizationService.detectedInconsistencies
                let highCount = inconsistencies.filter { $0.severity == .high }.count
                let mediumCount = inconsistencies.filter { $0.severity == .medium }.count
                let lowCount = inconsistencies.filter { $0.severity == .low }.count
                
                Text("Issues: H:\(highCount) M:\(mediumCount) L:\(lowCount)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                if let lastScan = synchronizationService.lastScanTime {
                    let timeAgo = Date().timeIntervalSince(lastScan)
                    Text("Last Scan: \(String(format: "%.0f", timeAgo))s ago")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white)
                
                Text("System Health")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let healthReport = systemMonitoringService.currentHealthReport {
                    Text("Status: \(healthReport.overallStatus.displayName)")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Text("Score: \(String(format: "%.0f", healthReport.overallScore * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Text("Critical: \(healthReport.criticalIssues.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                let securityAnalytics = enhancedSecurityService.getSecurityAnalytics()
                Text("Security: \(securityAnalytics.riskLevel.displayName)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("Alerts: \(securityAnalytics.activeAlerts)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Button("Warm Cache") {
                        Task {
                            await cacheWarmingService.warmCacheManually()
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    
                    Button("Clear Cache") {
                        batchMachineCoordinator.invalidateCache(reason: "debug_manual_clear")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    
                    Button("Sync Scan") {
                        Task {
                            await synchronizationService.triggerManualScan()
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
                
                HStack(spacing: 8) {
                    Button("Health Check") {
                        Task {
                            await systemMonitoringService.triggerManualHealthCheck()
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    
                    Button("Dashboard") {
                        showingSystemHealthDashboard = true
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
        )
        .frame(maxWidth: 200)
        .padding(.trailing, 16)
        .padding(.top, 100)
        .sheet(isPresented: $showingSystemHealthDashboard) {
            SystemHealthDashboard(monitoringService: systemMonitoringService)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getColorName(for colorId: String) -> String {
        return colorService.colors.first { $0.id == colorId }?.name ?? colorId
    }
}

// MARK: - Supporting Types (支持类型)

// Array safe subscript extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview Support (预览支持)
struct BatchCreationView_Previews: PreviewProvider {
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
        
        BatchCreationView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService,
            selectedDate: Date(),
            selectedShift: .morning,
            selectedMachineIds: ["machine1"]
        )
        .environmentObject(authService)
    }
}