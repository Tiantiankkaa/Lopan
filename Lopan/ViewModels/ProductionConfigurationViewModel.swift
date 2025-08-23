//
//  ProductionConfigurationViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/12.
//

import Foundation
import SwiftUI
import SwiftData

struct StationConflictInfo {
    let conflictingStations: Set<Int>
    let machine: WorkshopMachine
    
    var gunAConflicts: [Int] {
        return conflictingStations.filter { $0 <= 6 }.sorted()
    }
    
    var gunBConflicts: [Int] {
        return conflictingStations.filter { $0 > 6 }.sorted()
    }
    
    var conflictDescription: String {
        var description = ""
        
        if !gunAConflicts.isEmpty {
            let gunAStations = gunAConflicts.map { String($0) }.joined(separator: ", ")
            description += "Gun A 工位 \(gunAStations)"
        }
        
        if !gunBConflicts.isEmpty {
            if !description.isEmpty {
                description += " 和 "
            }
            let gunBStations = gunBConflicts.map { String($0) }.joined(separator: ", ")
            description += "Gun B 工位 \(gunBStations)"
        }
        
        return description + " 已被占用"
    }
}

@MainActor
class ProductionConfigurationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var availableMachines: [WorkshopMachine] = []
    @Published var selectedMachine: WorkshopMachine?
    @Published var selectedMode: ProductionMode = .singleColor
    @Published var activeColors: [ColorCard] = []
    @Published var availableProducts: [Product] = []
    @Published var currentBatch: ProductionBatch?
    @Published var showingAddProduct = false
    @Published var selectedPrimaryColor: ColorCard?
    @Published var selectedSecondaryColor: ColorCard?
    @Published var hasError = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    let batchService: ProductionBatchService
    let colorService: ColorService
    let machineService: MachineService
    let productService: ProductService
    let authService: AuthenticationService
    
    // MARK: - Private Properties
    private var pollingTask: Task<Void, Never>?
    
    init(batchService: ProductionBatchService, 
         colorService: ColorService, 
         machineService: MachineService, 
         productService: ProductService, 
         authService: AuthenticationService) {
        self.batchService = batchService
        self.colorService = colorService
        self.machineService = machineService
        self.productService = productService
        self.authService = authService
    }
    
    deinit {
        pollingTask?.cancel()
    }
    
    // MARK: - Data Loading
    func loadData() async {
        isLoading = true
        clearErrors()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMachines() }
            group.addTask { await self.loadColors() }
            group.addTask { await self.loadProducts() }
        }
        
        if let selectedMachine = selectedMachine {
            await loadCurrentBatch(for: selectedMachine)
        }
        
        isLoading = false
    }
    
    private func loadMachines() async {
        await machineService.loadMachines()
        availableMachines = machineService.machines
        
        if let error = machineService.errorMessage {
            setError(error)
        }
    }
    
    private func loadColors() async {
        await colorService.loadActiveColors()
        activeColors = colorService.colors
        
        if let error = colorService.errorMessage {
            setError(error)
        }
    }
    
    private func loadProducts() async {
        await productService.loadProducts()
        availableProducts = productService.products
        
        if let error = productService.error {
            setError("Failed to load products: \(error.localizedDescription)")
        }
    }
    
    private func loadCurrentBatch(for machine: WorkshopMachine) async {
        // Load all batches and find the current one for this machine
        await batchService.loadBatches()
        
        // Find the most recent batch that can be configured for this machine
        // Only include unsubmitted batches in the production configuration area
        // Other statuses (pending, approved, pendingExecution) are shown in approval status area only
        currentBatch = batchService.batches
            .filter { $0.machineId == machine.id }
            .filter { $0.status == .unsubmitted }
            .filter { $0.mode == selectedMode }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
    
    // MARK: - Machine Selection
    func selectMachine(_ machine: WorkshopMachine) {
        selectedMachine = machine
        Task {
            await loadCurrentBatch(for: machine)
            updateSelectedColorsFromGuns(machine)
        }
    }
    
    private func updateSelectedColorsFromGuns(_ machine: WorkshopMachine) {
        if selectedMode == .dualColor {
            // Auto-populate colors from gun configuration
            if let gunA = machine.guns.first(where: { $0.name == "Gun A" }),
               let gunAColorId = gunA.currentColorId {
                selectedPrimaryColor = activeColors.first { $0.id == gunAColorId }
            }
            
            if let gunB = machine.guns.first(where: { $0.name == "Gun B" }),
               let gunBColorId = gunB.currentColorId {
                selectedSecondaryColor = activeColors.first { $0.id == gunBColorId }
            }
        }
    }
    
    // MARK: - Production Mode Selection
    func selectMode(_ mode: ProductionMode) {
        selectedMode = mode
        
        // Clear current batch if it doesn't match the new mode
        if let batch = currentBatch, batch.mode != mode {
            currentBatch = nil
        }
        
        if let machine = selectedMachine {
            updateSelectedColorsFromGuns(machine)
        }
    }
    
    // MARK: - Batch Operations
    func createNewBatch() {
        guard let machine = selectedMachine else { return }
        
        // Enhanced validation using new equipment availability logic
        let (canAccept, reason) = canMachineAcceptNewBatch(machine)
        guard canAccept else {
            let statusMessage = "设备 A-\(String(format: "%03d", machine.machineNumber)) 无法创建新的生产批次：\(reason ?? "未知原因")"
            setError(statusMessage)
            return
        }
        
        Task {
            let batch = await batchService.createBatch(
                machineId: machine.id,
                mode: selectedMode
            )
            
            if let batch = batch {
                currentBatch = batch
            } else if let error = batchService.errorMessage {
                setError(error)
            }
        }
    }
    
    func showAddProduct() {
        showingAddProduct = true
    }
    
    func dismissAddProduct() {
        showingAddProduct = false
        
        // Reload current batch after adding product
        if let machine = selectedMachine {
            Task {
                await loadCurrentBatch(for: machine)
            }
        }
    }
    
    func submitBatch() -> (canSubmit: Bool, conflictInfo: StationConflictInfo?) {
        guard let batch = currentBatch,
              let machine = selectedMachine else { 
            return (false, nil)
        }
        
        // Check for station conflicts before submission
        if hasStationConflictWithPendingBatches(batch: batch, machine: machine) {
            let conflictingStations = getConflictingStations(batch: batch, machine: machine)
            let conflictInfo = StationConflictInfo(
                conflictingStations: conflictingStations,
                machine: machine
            )
            return (false, conflictInfo)
        }
        
        // No conflicts, proceed with submission
        Task {
            let success = await batchService.submitBatch(batch)
            
            if success {
                // Reload data after submission
                await loadData()
            } else if let error = batchService.errorMessage {
                setError(error)
            }
        }
        
        return (true, nil)
    }
    
    func forceSubmitBatch() {
        guard let batch = currentBatch else { return }
        
        Task {
            let success = await batchService.submitBatch(batch)
            
            if success {
                // Reload data after submission
                await loadData()
            } else if let error = batchService.errorMessage {
                setError(error)
            }
        }
    }
    
    func handleExecuteBatch(_ batch: ProductionBatch) {
        Task {
            let success = await batchService.applyBatchConfiguration(batch)
            
            if success {
                await loadData()
            } else if let error = batchService.errorMessage {
                setError(error)
            }
        }
    }
    
    func executeBatch(_ batch: ProductionBatch, at executionTime: Date) async {
        let success = await batchService.executeBatch(batch, at: executionTime)
        
        if success {
            await loadData()
        } else if let error = batchService.errorMessage {
            setError(error)
        }
    }
    
    // MARK: - Status Polling
    func startStatusPolling() {
        stopStatusPolling()
        
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                
                if !Task.isCancelled {
                    await refreshMachineStatusesAndBatches()
                }
            }
        }
    }
    
    func stopStatusPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    /// Enhanced status refresh with batch synchronization and validation
    /// 增强的状态刷新，包含批次同步和验证
    private func refreshMachineStatusesAndBatches() async {
        // Store current batch to preserve user's view
        let previousBatch = currentBatch
        
        // Refresh machine statuses
        await machineService.loadMachines()
        availableMachines = machineService.machines
        
        // Update selected machine reference
        if let selectedMachine = selectedMachine,
           let updatedMachine = machineService.machines.first(where: { $0.id == selectedMachine.id }) {
            self.selectedMachine = updatedMachine
            
            // Only reload current batch if previous batch is no longer valid (e.g., status changed from unsubmitted)
            // This prevents unwanted interface switching during periodic refresh
            if let prevBatch = previousBatch {
                await batchService.loadBatches()
                let updatedBatch = batchService.batches.first { $0.id == prevBatch.id }
                
                // Keep showing the batch only if it's still unsubmitted (editable)
                if let batch = updatedBatch, shouldKeepBatchVisible(batch) {
                    currentBatch = batch
                } else {
                    // Previous batch is no longer editable (submitted/approved/etc), find a new editable one
                    await loadCurrentBatch(for: updatedMachine)
                }
            } else {
                await loadCurrentBatch(for: updatedMachine)
            }
        }
        
        // Synchronize machine statuses with active batches
        let syncCount = await batchService.synchronizeMachineStatuses()
        if syncCount > 0 {
            print("Synchronized \(syncCount) machine(s) with batch statuses")
            // Reload machines after synchronization
            await machineService.loadMachines()
            availableMachines = machineService.machines
        }
        
        // Validate system consistency and auto-fix issues
        await validateAndFixSystemConsistency()
        
        // Update machine utilization rates
        await updateMachineUtilizationRates()
    }
    
    /// Legacy method for backward compatibility
    private func refreshMachineStatuses() async {
        await refreshMachineStatusesAndBatches()
    }
    
    /// Check if a batch should remain visible in configuration view
    /// 检查批次是否应该继续在配置视图中显示
    private func shouldKeepBatchVisible(_ batch: ProductionBatch) -> Bool {
        // Keep batch visible only if it's still configurable
        // Only unsubmitted batches can be edited in production configuration area
        // Other statuses are handled in approval status area only
        return batch.status == .unsubmitted
    }
    
    /// Validate system consistency and auto-fix minor issues
    /// 验证系统一致性并自动修复小问题
    private func validateAndFixSystemConsistency() async {
        let issues = await batchService.validateSystemConsistency()
        
        if !issues.isEmpty {
            print("Found \(issues.count) consistency issue(s)")
            
            // Attempt to auto-fix issues
            let fixedCount = await batchService.fixMachineValidationIssues(issues)
            
            if fixedCount > 0 {
                print("Auto-fixed \(fixedCount) consistency issue(s)")
                
                // Reload data after fixes
                await machineService.loadMachines()
                availableMachines = machineService.machines
                
                if let selectedMachine = selectedMachine,
                   let updatedMachine = machineService.machines.first(where: { $0.id == selectedMachine.id }) {
                    self.selectedMachine = updatedMachine
                    await loadCurrentBatch(for: updatedMachine)
                }
            }
            
            // Report any remaining issues
            let remainingIssues = issues.count - fixedCount
            if remainingIssues > 0 {
                print("Warning: \(remainingIssues) consistency issue(s) require manual attention")
                
                // Set error message for critical issues
                let criticalIssues = issues.filter { issue in
                    issue.type == .batchOrphanedMachine || issue.type == .validationError 
                }
                if !criticalIssues.isEmpty {
                    setError("System consistency issues detected. Please check machine and batch status.")
                }
            }
        }
    }
    
    /// Update machine utilization rates for all machines
    /// 更新所有机器的利用率
    private func updateMachineUtilizationRates() async {
        for machine in availableMachines {
            _ = await machineService.updateMachineUtilizationRate(machine)
        }
    }
    
    /// Force refresh all status and synchronization data
    /// 强制刷新所有状态和同步数据
    func forceRefreshStatus() async {
        isLoading = true
        await refreshMachineStatusesAndBatches()
        isLoading = false
    }
    
    // MARK: - Enhanced Station Management with Active Batch Support
    func getOccupiedStations(for machine: WorkshopMachine) -> Set<Int> {
        var occupiedStations = Set<Int>()
        
        // Only check stations occupied by pending (待审核) batches for conflict validation
        // According to business logic: only pending batches should block new submissions
        // - pending (待审核): should block conflicting submissions
        // - pendingExecution (待执行): should block conflicting submissions  
        // - active (执行中): does not block new submissions (shown in approval status)
        // - completed (已完成): does not block new submissions (shown in approval status)
        let conflictingBatches = batchService.batches.filter { batch in
            guard batch.machineId == machine.id else { return false }
            // Only consider pending and pendingExecution batches for station conflicts
            return batch.status == .pending || batch.status == .pendingExecution
        }
        
        // Collect all occupied stations from conflicting batches
        for batch in conflictingBatches {
            for product in batch.products {
                occupiedStations.formUnion(product.occupiedStations)
            }
        }
        
        return occupiedStations
    }
    
    /// Get stations that would be available if the current active batch is completed
    /// 获取当前活跃批次完成后可用的工位
    func getProjectedAvailableStations(for machine: WorkshopMachine) -> Set<Int> {
        let allStations = Set(1...12)
        
        // Only consider pending batches, exclude current active batch
        let pendingOccupied = batchService.batches
            .filter { $0.machineId == machine.id }
            .filter { $0.status == .pending }
            .flatMap { batch in batch.products.flatMap { $0.occupiedStations } }
        
        return allStations.subtracting(Set(pendingOccupied))
    }
    
    /// Check if machine can accept a new batch based on current execution state
    /// 基于当前执行状态检查机器是否可以接受新批次
    func canMachineAcceptNewBatch(_ machine: WorkshopMachine) -> (canAccept: Bool, reason: String?) {
        // Basic operational checks
        guard machine.isActive else {
            return (false, "Machine is disabled")
        }
        
        guard machine.isOperational else {
            return (false, "Machine is not operational (\(machine.status.displayName))")
        }
        
        // Check if machine already has an active batch and can't accept new ones
        if machine.hasActiveProductionBatch {
            // In production configuration context, we allow creating new batches
            // even when machine has active batch (they will be pending)
            let availableStations = getProjectedAvailableStations(for: machine)
            let minStationsNeeded = selectedMode.minStationsPerProduct
            
            if availableStations.count < minStationsNeeded {
                return (false, "Insufficient stations available for new batch (need \(minStationsNeeded), available \(availableStations.count))")
            }
            
            return (true, "Note: Machine has active batch. New batch will be queued.")
        }
        
        // Check station availability for machines without active batches
        let availableStations = getAvailableStations(for: machine)
        let minStationsNeeded = selectedMode.minStationsPerProduct
        
        if availableStations.count < minStationsNeeded {
            return (false, "Insufficient stations available (need \(minStationsNeeded), available \(availableStations.count))")
        }
        
        return (true, nil)
    }
    
    func getAvailableStations(for machine: WorkshopMachine) -> Set<Int> {
        let allStations = Set(1...12)
        let occupiedStations = getOccupiedStations(for: machine)
        return allStations.subtracting(occupiedStations)
    }
    
    func getAvailableStationCount(for machine: WorkshopMachine) -> Int {
        return getAvailableStations(for: machine).count
    }
    
    func getPendingOccupiedStations(for machine: WorkshopMachine) -> Set<Int> {
        // This method specifically gets stations occupied by pending batches
        // Same logic as getOccupiedStations but more explicit naming
        return getOccupiedStations(for: machine)
    }
    
    func getPendingOccupiedStationCount(for machine: WorkshopMachine) -> Int {
        return getPendingOccupiedStations(for: machine).count
    }
    
    func hasStationConflictWithPendingBatches(batch: ProductionBatch, machine: WorkshopMachine) -> Bool {
        // Use the dedicated method to get pending occupied stations
        let pendingStations = getPendingOccupiedStations(for: machine)
        let currentBatchStations = Set(batch.products.flatMap { $0.occupiedStations })
        
        return !pendingStations.intersection(currentBatchStations).isEmpty
    }
    
    func getConflictingStations(batch: ProductionBatch, machine: WorkshopMachine) -> Set<Int> {
        // Use the dedicated method to get pending occupied stations
        let pendingStations = getPendingOccupiedStations(for: machine)
        let currentBatchStations = Set(batch.products.flatMap { $0.occupiedStations })
        
        return pendingStations.intersection(currentBatchStations)
    }

    // MARK: - Computed Properties
    var canManageProduction: Bool {
        guard let user = authService.currentUser else { return false }
        return user.hasRole(.workshopManager) || user.hasRole(.administrator)
    }
    
    var canCreateBatch: Bool {
        guard canManageProduction,
              let machine = selectedMachine else { return false }
        
        return machine.canReceiveNewTasks
    }
    
    var batchCreationDisabledReason: String {
        if !canManageProduction {
            return "没有生产管理权限"
        }
        
        guard let machine = selectedMachine else {
            return "请先选择生产设备"
        }
        
        if !machine.canReceiveNewTasks {
            switch machine.status {
            case .maintenance:
                return "设备正在维护中，请等待维护完成"
            case .error:
                return "设备出现故障，请联系技术人员"
            case .stopped:
                return "设备已停机，请先启动设备"
            default:
                return "设备状态不允许创建批次"
            }
        }
        
        return ""
    }
    
    var canAddProducts: Bool {
        guard canManageProduction else { return false }
        
        // Check station availability for the selected machine
        if let machine = selectedMachine {
            let availableStationCount = getAvailableStationCount(for: machine)
            
            // Need at least minimum stations per product for the selected mode
            let minStationsNeeded = selectedMode.minStationsPerProduct
            
            // If there aren't enough stations available, don't allow adding products
            if availableStationCount < minStationsNeeded {
                return false
            }
        }
        
        // Allow adding products if we have an unsubmitted batch or can create a new one
        if let batch = currentBatch {
            return batch.status == .unsubmitted
        }
        
        return true // Can create new batch and add products
    }
    
    var canSubmitBatch: Bool {
        guard let batch = currentBatch,
              canManageProduction,
              !batch.products.isEmpty else { return false }
        
        guard batch.status == .unsubmitted else { return false }
        
        // Note: Station conflict checking is now handled in the submit action
        // to allow users to see the conflict alert dialog
        return true
    }
    
    var submitButtonText: String {
        guard let batch = currentBatch else { return "提交批次" }
        
        switch batch.status {
        case .unsubmitted:
            return batch.products.isEmpty ? "添加产品后可提交" : "提交审批"
        case .pending:
            return "等待审批中..."
        case .approved:
            return "已审批通过"
        case .pendingExecution:
            return "等待执行..."
        case .rejected:
            return "已被拒绝"
        case .active:
            // For active batches, show that they are being handled in approval section
            return "批次正在执行中"
        case .completed:
            return "批次已完成"
        }
    }
    
    var submitButtonDisabledReason: String {
        guard let batch = currentBatch else {
            return "选择设备和模式"
        }
        
        if batch.products.isEmpty {
            if !canAddProducts {
                if let machine = selectedMachine {
                    let availableCount = getAvailableStationCount(for: machine)
                    let minNeeded = selectedMode.minStationsPerProduct
                    return "可用工位不足：还剩 \(availableCount) 个工位，但 \(selectedMode.displayName) 至少需要 \(minNeeded) 个工位"
                }
            }
            return "批次中需要至少添加一个产品配置"
        }
        
        if batch.status != .unsubmitted {
            return "只能提交未提交状态的批次"
        }
        
        // Note: Station conflict messages are now shown in the alert dialog
        // when user attempts to submit, not as a disabled button reason
        
        if !canManageProduction {
            return "没有生产管理权限"
        }
        
        return ""
    }
    
    var workflowCurrentStep: Int {
        guard let batch = currentBatch else { return 0 }
        
        switch batch.status {
        case .unsubmitted:
            return batch.products.isEmpty ? 0 : 1
        case .pending:
            return 2
        case .approved, .pendingExecution, .rejected, .active, .completed:
            return 3
        }
    }
    
    var stationUsageInfo: String {
        guard let machine = selectedMachine else { return "选择设备后查看工位信息" }
        
        let occupiedCount = getOccupiedStations(for: machine).count
        let availableCount = getAvailableStationCount(for: machine)
        
        var info = "设备工位: \(occupiedCount)/12 已占用, \(availableCount) 个可用"
        
        // Add active batch info if machine has one
        if machine.hasActiveProductionBatch {
            let runningStations = machine.stations.filter { $0.status == .running }.count
            info += " | 执行中: \(runningStations) 个工位"
            
            // Show projected availability
            let projectedAvailable = getProjectedAvailableStations(for: machine).count
            if projectedAvailable != availableCount {
                info += " (完成后可用: \(projectedAvailable))"
            }
        }
        
        // Add current batch info
        if let batch = currentBatch {
            let currentBatchStations = batch.totalStationsUsed
            info += " | 当前批次: \(currentBatchStations) 个工位"
        }
        
        return info
    }
    
    // MARK: - Service Access
    func getBatchService() -> ProductionBatchService {
        return batchService
    }
    
    // MARK: - Error Handling
    private func setError(_ message: String) {
        errorMessage = message
        hasError = true
    }
    
    func clearErrors() {
        errorMessage = nil
        hasError = false
    }
}