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
        
        return description + " 处于待审核状态"
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
        
        // Find the most recent unsubmitted batch for this machine that matches current mode
        // Active, completed, and other states should not be shown in production configuration section
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
        
        // Validate machine status before attempting batch creation
        guard machine.canReceiveNewTasks else {
            let statusMessage: String
            switch machine.status {
            case .maintenance:
                statusMessage = "设备 A-\(String(format: "%03d", machine.machineNumber)) 正在维护中，无法创建新的生产批次。请等待维护完成后重试。"
            case .error:
                statusMessage = "设备 A-\(String(format: "%03d", machine.machineNumber)) 出现故障，无法创建新的生产批次。请联系技术人员处理。"
            case .stopped:
                statusMessage = "设备 A-\(String(format: "%03d", machine.machineNumber)) 已停机，无法创建新的生产批次。请先启动设备。"
            default:
                statusMessage = "设备 A-\(String(format: "%03d", machine.machineNumber)) 当前状态不允许创建新的生产批次。"
            }
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
                    await refreshMachineStatuses()
                }
            }
        }
    }
    
    func stopStatusPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func refreshMachineStatuses() async {
        await machineService.loadMachines()
        availableMachines = machineService.machines
    }
    
    // MARK: - Station Management
    func getOccupiedStations(for machine: WorkshopMachine) -> Set<Int> {
        // Get all batches for this machine that occupy stations
        // Only include pending batches for station conflict calculation
        let pendingBatches = batchService.batches.filter { batch in
            guard batch.machineId == machine.id else { return false }
            
            // Only include pending batches - they are the ones that reserve stations
            // Active batches are executing but don't prevent new configurations
            switch batch.status {
            case .pending:
                return true
            case .unsubmitted, .approved, .pendingExecution, .rejected, .active, .completed:
                return false
            }
        }
        
        // Collect all occupied stations from pending batches
        var occupiedStations = Set<Int>()
        for batch in pendingBatches {
            for product in batch.products {
                occupiedStations.formUnion(product.occupiedStations)
            }
        }
        
        return occupiedStations
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
        guard let batch = currentBatch else { return "创建批次后可提交" }
        
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
            return "需要先选择设备和生产模式并创建批次"
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
        
        let pendingOccupiedCount = getPendingOccupiedStationCount(for: machine)
        let availableCount = getAvailableStationCount(for: machine)
        
        if let batch = currentBatch {
            let currentBatchStations = batch.totalStationsUsed
            return "设备工位: \(pendingOccupiedCount)/12 已占用, \(availableCount) 个可用 | 当前批次: \(currentBatchStations) 个工位"
        }
        
        return "设备工位: \(pendingOccupiedCount)/12 已占用, \(availableCount) 个可用"
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