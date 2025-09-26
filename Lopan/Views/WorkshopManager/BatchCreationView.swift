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
    let serviceProvider: WorkshopManagerServiceProvider
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    // Pre-selected values from parent view
    let selectedDate: Date
    let selectedShift: Shift
    let selectedMachineIds: Set<String>
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @ObservedObject private var productionBatchService: ProductionBatchService
    @ObservedObject private var machineService: MachineService
    @ObservedObject private var batchEditPermissionService: StandardBatchEditPermissionService
    @ObservedObject private var colorService: ColorService
    @ObservedObject private var batchMachineCoordinator: StandardBatchMachineCoordinator
    @ObservedObject private var cacheWarmingService: CacheWarmingService
    @ObservedObject private var synchronizationService: MachineStateSynchronizationService
    @ObservedObject private var systemMonitoringService: SystemConsistencyMonitoringService
    @ObservedObject private var enhancedSecurityService: EnhancedSecurityAuditService
    
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
        serviceProvider: WorkshopManagerServiceProvider,
        authService: AuthenticationService,
        auditService: NewAuditingService,
        selectedDate: Date,
        selectedShift: Shift,
        selectedMachineIds: Set<String>
    ) {
        self.serviceProvider = serviceProvider
        self.authService = authService
        self.auditService = auditService
        self.selectedDate = selectedDate
        self.selectedShift = selectedShift
        self.selectedMachineIds = selectedMachineIds
        
        // Initialize shared services via provider
        self._productionBatchService = ObservedObject(wrappedValue: serviceProvider.batchService)
        self._machineService = ObservedObject(wrappedValue: serviceProvider.machineService)
        self._batchEditPermissionService = ObservedObject(wrappedValue: serviceProvider.batchEditPermissionService)
        self._colorService = ObservedObject(wrappedValue: serviceProvider.colorService)
        self._batchMachineCoordinator = ObservedObject(wrappedValue: serviceProvider.batchMachineCoordinator)
        self._cacheWarmingService = ObservedObject(wrappedValue: serviceProvider.cacheWarmingService)
        self._synchronizationService = ObservedObject(wrappedValue: serviceProvider.synchronizationService)
        self._systemMonitoringService = ObservedObject(wrappedValue: serviceProvider.systemMonitoringService)
        self._enhancedSecurityService = ObservedObject(wrappedValue: serviceProvider.enhancedSecurityService)
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("batch_creation_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("batch_creation_primary_cta".localized) {
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
                    description: "batch_creation_event_start_description".localized,
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
                        description: "batch_creation_event_end_description".localized
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
            .alert("batch_creation_error_title".localized, isPresented: $showingError, presenting: errorMessage) { _ in
                Button("common_ok".localized, role: .cancel) { }
            } message: { message in
                Text(message)
            }
            .alert("batch_creation_conflict_title".localized, isPresented: $showingConflictWarning, presenting: conflictingBatch) { batch in
                Button("common_cancel".localized, role: .cancel) { }
                Button("batch_creation_force_create".localized, role: .destructive) {
                    Task {
                        await createBatch(forceCreate: true)
                    }
                }
            } message: { batch in
                Text(String(format: "batch_creation_conflict_message".localized, batch.batchNumber))
            }
        }
    }
    
    // MARK: - Header Section (头部信息)
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.stack.3d.down.right.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(LopanColors.info)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("batch_creation_header_title".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("batch_creation_header_subtitle".localized)
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
            sectionHeader(title: "batch_creation_section_timeslot", icon: "calendar.badge.clock")
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("batch_creation_field_date".localized)
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
                    Text("batch_creation_field_shift".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedShift == .morning ? "sun.min" : "moon")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(shiftHighlightColor)
                            
                            Text(selectedShift.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text(selectedShift.timeRangeDisplay)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(shiftHighlightColor)
                    }
                }
                
                Spacer()
                
                timeRestrictionIndicator
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.backgroundSecondary)
            )
        }
    }
    
    private var timeRestrictionIndicator: some View {
        let cutoffInfo = dateShiftPolicy.getCutoffInfo(for: selectedDate, currentTime: timeProvider.now)
        
        return VStack(spacing: 4) {
            if cutoffInfo.hasRestriction {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(LopanColors.warning)
                
                Text("batch_creation_mode_restricted".localized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.warning)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(LopanColors.success)
                
                Text("batch_creation_mode_normal".localized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.success)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((cutoffInfo.hasRestriction ? LopanColors.warning : LopanColors.success).opacity(0.1))
        )
    }
    
    // MARK: - Machine Info Section (设备信息)
    
    private var machineInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "batch_creation_section_machines", icon: "gearshape.2")
                
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
                    .foregroundColor(currentMachineIndex > 0 ? LopanColors.info : LopanColors.secondary)
            }
            .disabled(currentMachineIndex <= 0)
            
            Text(String(format: "batch_creation_machine_selector_progress".localized, currentMachineIndex + 1, availableMachines.count))
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
                    .foregroundColor(currentMachineIndex < availableMachines.count - 1 ? LopanColors.info : LopanColors.secondary)
            }
            .disabled(currentMachineIndex >= availableMachines.count - 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(LopanColors.backgroundTertiary)
        )
    }
    
    private func machineInfoCard(machine: WorkshopMachine) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: machine.isActive ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(machine.isActive ? LopanColors.success : LopanColors.warning)

                Circle()
                    .fill(machine.isActive ? LopanColors.success : LopanColors.warning)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: "batch_creation_machine_title".localized, machine.machineNumber))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(String(format: "batch_creation_machine_number".localized, machine.machineNumber))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(machine.isActive ? "batch_creation_machine_status_ok".localized : "batch_creation_machine_status_warning".localized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(machine.isActive ? LopanColors.success : LopanColors.warning)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "batch_creation_machine_station_count".localized, machine.stations.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "batch_creation_machine_gun_count".localized, machine.totalGuns))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    private var machineLoadingState: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("batch_creation_loading_machines".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    // MARK: - Product Configuration Section (产品配置)
    
    private var productConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "batch_creation_section_products", icon: "cube.box")
                
                Spacer()
                
                Text("batch_creation_mode_color_only".localized)
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
            
            Text("batch_creation_products_empty_title".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("batch_creation_products_empty_subtitle".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("batch_creation_add_product".localized) {
                showingProductSelection = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    private var productEmptyStateRestricted: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("batch_creation_current_product_empty".localized)
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
                .fill(LopanColors.backgroundSecondary)
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
                
                Text("batch_creation_flag_color_only".localized)
                    .font(.caption2)
                    .foregroundColor(LopanColors.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LopanColors.warning.opacity(0.1))
                    )
            }
            
            // Color selection interface
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.caption)
                    .foregroundColor(LopanColors.info)
                
                Text("batch_creation_color_label".localized)
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
                            .fill(LopanColors.backgroundTertiary)
                    )
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LopanColors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LopanColors.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    // MARK: - Validation Section (验证信息)
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "batch_creation_section_validation", icon: "checkmark.shield")
            
            validationChecklist
        }
    }
    
    private var validationChecklist: some View {
        VStack(spacing: 8) {
            validationRow(
                title: "batch_creation_validation_slot_title".localized,
                isValid: dateTimeValid,
                message: dateTimeValid ? "batch_creation_validation_slot_ok".localized : "batch_creation_validation_slot_warning".localized
            )
            
            validationRow(
                title: "batch_creation_validation_machine_title".localized,
                isValid: availableMachines[safe: currentMachineIndex]?.canReceiveNewTasks == true,
                message: (availableMachines[safe: currentMachineIndex]?.canReceiveNewTasks == true) ? "batch_creation_validation_machine_ok".localized : "batch_creation_validation_machine_warning".localized
            )
            
            validationRow(
                title: "batch_creation_section_products".localized,
                isValid: !productConfigs.isEmpty,
                message: !productConfigs.isEmpty ? String(format: "batch_creation_validation_products_loaded".localized, productConfigs.count) : productConfigErrorMessage
            )
            
            validationRow(
                title: "batch_creation_validation_conflict_title".localized,
                isValid: conflictingBatch == nil,
                message: conflictingBatch == nil ? "batch_creation_validation_conflict_ok".localized : "batch_creation_validation_conflict_warning".localized
            )
            
            // State consistency validation
            let highSeverityIssues = synchronizationService.detectedInconsistencies.filter { $0.severity == .high }
            validationRow(
                title: "batch_creation_validation_consistency_title".localized,
                isValid: highSeverityIssues.isEmpty,
                message: highSeverityIssues.isEmpty ? "batch_creation_validation_consistency_ok".localized : String(format: "batch_creation_validation_consistency_warning".localized, highSeverityIssues.count)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    private func validationRow(title: String, isValid: Bool, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isValid ? LopanColors.success : LopanColors.error)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.caption2)
                    .foregroundColor(isValid ? LopanColors.success : LopanColors.error)
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
                    
                    Text("batch_creation_creating".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LopanColors.backgroundSecondary)
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
                        
                        Text("batch_creation_primary_cta".localized)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(LopanColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canCreateBatch ? LopanColors.info : LopanColors.secondary)
                    )
                }
                .disabled(!canCreateBatch)
            }
            
            if !canCreateBatch {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Product Selection Sheet (产品选择弹出框)
    
    private var productSelectionSheet: some View {
        NavigationStack {
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
                                
                                Text(String(format: "batch_creation_product_identifier".localized, product.id))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                        Image(systemName: "plus.circle")
                                .foregroundColor(LopanColors.info)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("batch_creation_product_picker_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel".localized) {
                        showingProductSelection = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func sectionHeader(title key: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.info)
            
            Text(key)
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)
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
    
    private var repositoryFactory: RepositoryFactory { serviceProvider.repositoryFactory }
    
    private var shiftHighlightColor: Color {
        selectedShift == .morning ? LopanColors.warning : LopanColors.info
    }
    
    private var dateTimeValid: Bool {
        let allowedShifts = dateShiftPolicy.allowedShifts(for: selectedDate, currentTime: timeProvider.now)
        return allowedShifts.contains(selectedShift)
    }
    
    private var validationMessage: String {
        if !dateTimeValid {
            return "batch_creation_validation_slot_error".localized
        } else if availableMachines.isEmpty {
            return "batch_creation_error_no_machines".localized
        } else if availableMachines[safe: currentMachineIndex]?.canReceiveNewTasks != true {
            return "batch_creation_error_machine_invalid".localized
        } else if productConfigs.isEmpty {
            return productConfigErrorMessage
        }
        return ""
    }
    
    private var productConfigErrorMessage: String {
        guard let currentMachine = availableMachines[safe: currentMachineIndex] else {
            return "batch_creation_error_no_machines".localized
        }
        
        // Check if machine is currently running
        let isMachineCurrentlyRunning = currentMachine.status == .running && currentMachine.isActive
        
        if !isMachineCurrentlyRunning {
            return String(format: "batch_creation_error_machine_not_running".localized, currentMachine.machineNumber)
        }
        
        // Check if this is a next day evening shift
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: selectedDate)
        
        if selectedShift == .evening && targetDate > today {
            // This is a next day evening shift
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd"
            return String(format: "batch_creation_error_night_shift".localized, dateFormatter.string(from: selectedDate))
        }
        
        // Get the previous shift info to provide context
        let previousShiftInfo = getPreviousShiftInfo(for: selectedDate, shift: selectedShift)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd"
        
        // Provide more specific error message with shift context
        return String(format: "batch_creation_error_no_previous_batch".localized, currentMachine.machineNumber, dateFormatter.string(from: previousShiftInfo.date), previousShiftInfo.shift.displayName)
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
            await showError(String(format: "batch_creation_error_load_machines".localized, error.localizedDescription))
        }
    }
    
    private func loadAvailableProducts() async {
        let context = await MainActor.run { () -> (machine: WorkshopMachine?, date: Date, shift: Shift) in
            let machine = availableMachines[safe: currentMachineIndex]
            return (machine, selectedDate, selectedShift)
        }
        
        guard let currentMachine = context.machine else {
            return
        }

        do {
            // Use the unified BatchMachineCoordinator for optimized and consistent logic
            let inheritableProducts = try await batchMachineCoordinator.getInheritableProducts(
                machineId: currentMachine.id,
                date: context.date,
                shift: context.shift
            )
            
            await MainActor.run {
                self.productConfigs = inheritableProducts
                // No need to set availableProducts since we're not allowing new product additions
                self.availableProducts = []
            }
        } catch {
            await showError(String(format: "batch_creation_error_load_products".localized, error.localizedDescription))
        }
    }
    
    private func checkForConflictingBatches() async {
        let machineContext = await MainActor.run { () -> (id: String?, date: Date, shift: Shift) in
            let machineId = availableMachines[safe: currentMachineIndex]?.id
            return (machineId, selectedDate, selectedShift)
        }
        
        guard let machineId = machineContext.id else { return }
        
        do {
            let hasConflict = try await repositoryFactory.productionBatchRepository.hasConflictingBatches(
                forDate: machineContext.date,
                shift: machineContext.shift,
                machineId: machineId,
                excludingBatchId: nil
            )
            
            if hasConflict {
                let existingBatches = try await repositoryFactory.productionBatchRepository.fetchBatches(
                    forDate: machineContext.date,
                    shift: machineContext.shift
                )
                let conflicting = existingBatches.first { $0.machineId == machineId }
                
                await MainActor.run {
                    self.conflictingBatch = conflicting
                }
            } else {
                await MainActor.run {
                    self.conflictingBatch = nil
                }
            }
        } catch {
            await showError(String(format: "batch_creation_error_conflict_check".localized, error.localizedDescription))
        }
    }
    
    private func createBatch(forceCreate: Bool = false) async {
        let state = await MainActor.run { () -> (canCreate: Bool, machine: WorkshopMachine?, hasConflict: Bool, configs: [ProductConfig]) in
            let machine = availableMachines[safe: currentMachineIndex]
            let canCreate = dateTimeValid &&
                            machine?.canReceiveNewTasks == true &&
                            !productConfigs.isEmpty &&
                            !isCreating
            return (canCreate, machine, conflictingBatch != nil, productConfigs)
        }

        if !forceCreate && state.hasConflict {
            await MainActor.run {
                showingConflictWarning = true
            }
            return
        }

        guard forceCreate || state.canCreate else { return }
        
        guard let currentMachine = state.machine else {
            await showError("batch_creation_error_no_machines".localized)
            return
        }

        await MainActor.run {
            isCreating = true
        }

        do {
            // Infer production mode from existing product configurations
            let inferredMode = inferProductionMode(from: state.configs)
            
            // Create batch using ProductionBatchService
            if let batch = await productionBatchService.createShiftBatch(
                machineId: currentMachine.id,
                mode: inferredMode,
                targetDate: selectedDate,
                shift: selectedShift
            ) {
                // Add product configurations to batch
                for var config in state.configs {
                    config.batchId = batch.id
                    try await repositoryFactory.productionBatchRepository.addProductConfig(config, toBatch: batch.id)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } else {
                await showError("batch_creation_error_create_failed".localized)
            }
        } catch {
            await showError(String(format: "batch_creation_error_create_generic".localized, error.localizedDescription))
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
                Text("batch_creation_debug_title".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
                
                Spacer()
                
                Button("×") {
                    showingCacheDebug = false
                }
                .foregroundColor(LopanColors.textPrimary)
                .font(.caption)
            }
            
            let metrics = batchMachineCoordinator.getCacheMetrics()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "batch_creation_debug_hit_rate".localized, metrics.hitRate * 100))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(String(format: "batch_creation_debug_entries".localized, metrics.entries))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(String(format: "batch_creation_debug_hits_misses".localized, metrics.hits, metrics.misses))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(String(format: "batch_creation_debug_evictions".localized, metrics.evictions))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                if let warmingResults = cacheWarmingService.warmingResults {
                    Text(String(format: "batch_creation_debug_last_warming".localized, warmingResults.duration))
                        .font(.caption2)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text(String(format: "batch_creation_debug_warmed_summary".localized, warmingResults.machinesWarmed, warmingResults.successCount, warmingResults.machinesWarmed))
                        .font(.caption2)
                        .foregroundColor(LopanColors.textPrimary)
                }
                
                Divider()
                    .background(LopanColors.textPrimary)
                
                Text("batch_creation_debug_state_sync_title".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
                
                let inconsistencies = synchronizationService.detectedInconsistencies
                let highCount = inconsistencies.filter { $0.severity == .high }.count
                let mediumCount = inconsistencies.filter { $0.severity == .medium }.count
                let lowCount = inconsistencies.filter { $0.severity == .low }.count
                
                Text(String(format: "batch_creation_debug_state_sync_issues".localized, highCount, mediumCount, lowCount))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                if let lastScan = synchronizationService.lastScanTime {
                    let timeAgo = Date().timeIntervalSince(lastScan)
                    Text(String(format: "batch_creation_debug_last_scan".localized, timeAgo))
                        .font(.caption2)
                        .foregroundColor(LopanColors.textPrimary)
                }
                
                Divider()
                    .background(LopanColors.textPrimary)
                
                Text("batch_creation_debug_system_health_title".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)

                if let healthReport = systemMonitoringService.currentHealthReport {
                    Text(String(format: "batch_creation_debug_system_status".localized, healthReport.overallStatus.displayName))
                        .font(.caption2)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text(String(format: "batch_creation_debug_system_score".localized, healthReport.overallScore * 100))
                        .font(.caption2)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text(String(format: "batch_creation_debug_system_critical".localized, healthReport.criticalIssues.count))
                        .font(.caption2)
                        .foregroundColor(LopanColors.textPrimary)
                }

                let securityAnalytics = enhancedSecurityService.getSecurityAnalytics()
                Text(String(format: "batch_creation_debug_security_status".localized, securityAnalytics.riskLevel.displayName))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(String(format: "batch_creation_debug_security_alerts".localized, securityAnalytics.activeAlerts))
                    .font(.caption2)
                    .foregroundColor(LopanColors.textPrimary)
                
                HStack(spacing: 8) {
                    Button("batch_creation_debug_action_warm_cache".localized) {
                        Task {
                            await cacheWarmingService.warmCacheManually()
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.info)
                    .foregroundColor(LopanColors.textPrimary)
                    .cornerRadius(4)
                    
                    Button("batch_creation_debug_action_clear_cache".localized) {
                        batchMachineCoordinator.invalidateCache(reason: "debug_manual_clear")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.error)
                    .foregroundColor(LopanColors.textPrimary)
                    .cornerRadius(4)
                    
                    Button("batch_creation_debug_action_sync_scan".localized) {
                        Task {
                            await synchronizationService.triggerManualScan()
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.warning)
                    .foregroundColor(LopanColors.textPrimary)
                    .cornerRadius(4)
                }
                
                HStack(spacing: 8) {
                    Button("batch_creation_debug_action_health_check".localized) {
                        Task {
                            await systemMonitoringService.triggerManualHealthCheck()
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.premium)
                    .foregroundColor(LopanColors.textPrimary)
                    .cornerRadius(4)
                    
                    Button("batch_processing_action_view_all".localized) {
                        showingSystemHealthDashboard = true
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LopanColors.success)
                    .foregroundColor(LopanColors.textPrimary)
                    .cornerRadius(4)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LopanColors.shadow.opacity(16))
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
        let provider = WorkshopManagerServiceProvider(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
        
        BatchCreationView(
            serviceProvider: provider,
            authService: authService,
            auditService: auditService,
            selectedDate: Date(),
            selectedShift: .morning,
            selectedMachineIds: ["machine1"]
        )
        .environmentObject(authService)
    }
}
