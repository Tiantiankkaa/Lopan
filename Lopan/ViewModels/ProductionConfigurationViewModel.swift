//
//  ProductionConfigurationViewModel.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/12.
//

import Foundation
import SwiftUI
import SwiftData

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
        
        // Find the most recent active or unsubmitted batch for this machine
        currentBatch = batchService.batches
            .filter { $0.machineId == machine.id }
            .filter { $0.status == .unsubmitted || $0.status == .active }
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
        
        if let machine = selectedMachine {
            updateSelectedColorsFromGuns(machine)
        }
    }
    
    // MARK: - Batch Operations
    func createNewBatch() {
        guard let machine = selectedMachine else { return }
        
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
    
    func submitBatch() {
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
    
    // MARK: - Computed Properties
    var canManageProduction: Bool {
        guard let user = authService.currentUser else { return false }
        return user.hasRole(.workshopManager) || user.hasRole(.administrator)
    }
    
    var canAddProducts: Bool {
        guard let batch = currentBatch, canManageProduction else { return false }
        return batch.status == .unsubmitted
    }
    
    var canSubmitBatch: Bool {
        guard let batch = currentBatch,
              canManageProduction,
              !batch.products.isEmpty else { return false }
        
        return batch.status == .unsubmitted
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
            return "执行中..."
        case .completed:
            return "已完成"
        }
    }
    
    var submitButtonDisabledReason: String {
        guard let batch = currentBatch else {
            return "需要先选择设备和生产模式并创建批次"
        }
        
        if batch.products.isEmpty {
            return "批次中需要至少添加一个产品配置"
        }
        
        if batch.status != .unsubmitted {
            return "只能提交未提交状态的批次"
        }
        
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