//
//  ProductionConfigurationView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData


struct ProductionConfigurationView: View {
    @StateObject private var viewModel: ProductionConfigurationViewModel
    @ObservedObject private var authService: AuthenticationService
    @State private var selectedBatchForDetails: ProductionBatch?
    @State private var showingConflictAlert = false
    @State private var currentConflictInfo: StationConflictInfo?
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        
        let batchService = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        
        let colorService = ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        
        let machineService = MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        
        let productService = ProductService(
            repositoryFactory: repositoryFactory
        )
        
        self._viewModel = StateObject(wrappedValue: ProductionConfigurationViewModel(
            batchService: batchService,
            colorService: colorService,
            machineService: machineService,
            productService: productService,
            authService: authService
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载数据...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }
            }
            .navigationTitle("生产配置")
            .refreshable {
                await viewModel.loadData()
            }
            .alert("Error", isPresented: .constant(viewModel.hasError)) {
                Button("确定") {
                    viewModel.clearErrors()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("工位冲突提醒", isPresented: $showingConflictAlert) {
                Button("修改配置", role: .cancel) {
                    showingConflictAlert = false
                }
            } message: {
                if let conflictInfo = currentConflictInfo {
                    Text("操作错误：\(conflictInfo.conflictDescription)，请修改产品配置后再提交审批")
                }
            }
            .sheet(isPresented: $viewModel.showingAddProduct) {
                if let batch = viewModel.currentBatch, let machine = viewModel.selectedMachine {
                    AddProductSheet(
                        batch: batch,
                        machine: machine,
                        colors: viewModel.activeColors,
                        products: viewModel.availableProducts,
                        batchService: viewModel.getBatchService(),
                        prePopulatedPrimaryColor: viewModel.selectedPrimaryColor,
                        prePopulatedSecondaryColor: viewModel.selectedSecondaryColor
                    ) {
                        viewModel.dismissAddProduct()
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $selectedBatchForDetails) { batch in
                BatchDetailsSheet(
                    batch: batch,
                    colors: viewModel.activeColors,
                    machines: viewModel.availableMachines,
                    onExecuteBatch: { batch, executionTime in
                        Task {
                            await viewModel.executeBatch(batch, at: executionTime)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        .task {
            await viewModel.loadData()
            viewModel.startStatusPolling()
        }
        .onDisappear {
            viewModel.stopStatusPolling()
        }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Machine selection
                machineSelectionSection
                
                if viewModel.selectedMachine != nil {
                    // Approval workflow display
                    approvalWorkflowSection
                    
                    // Production mode selection
                    productionModeSection
                    
                    // Current batch info
                    if let batch = viewModel.currentBatch {
                        batchConfigurationSection(batch)
                    } else {
                        createBatchSection
                    }
                }
            }
            .padding()
            // Add safe area padding for tab bar
            .safeAreaInset(edge: .bottom) {
                LopanColors.clear.frame(height: 34)
            }
        }
    }
    
    // MARK: - Machine Selection Section
    private var machineSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择生产设备")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.availableMachines, id: \.id) { machine in
                        MachineCard(
                            machine: machine,
                            isSelected: viewModel.selectedMachine?.id == machine.id
                        ) {
                            viewModel.selectMachine(machine)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Production Mode Section
    private var productionModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生产模式")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach(ProductionMode.allCases, id: \.self) { mode in
                    ProductionModeCard(
                        mode: mode,
                        isSelected: viewModel.selectedMode == mode
                    ) {
                        viewModel.selectMode(mode)
                    }
                }
            }
        }
    }
    
    // MARK: - Machine-Specific Approval Status Section
    private var approvalWorkflowSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("审批状态")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let machine = viewModel.selectedMachine {
                    Text("生产设备 A-\(String(format: "%03d", machine.machineNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let machine = viewModel.selectedMachine {
                // Machine-specific approval status
                MachineApprovalStatusView(
                    machineId: machine.id,
                    batchService: viewModel.batchService,
                    onBatchTapped: { batch in
                        selectedBatchForDetails = batch
                    }
                )
            } else {
                // No machine selected
                machineSelectionPrompt
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var machineSelectionPrompt: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("请选择生产设备")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("选择设备后查看对应的批次审批状态")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(LopanColors.warningLight)
        .cornerRadius(12)
    }
    
    // MARK: - Create Batch Section
    private var createBatchSection: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.createNewBatch()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(viewModel.canCreateBatch ? LopanColors.primary : LopanColors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCreateBatch)
            
            VStack(spacing: 8) {
                Text("创建生产配置")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if !viewModel.canCreateBatch {
                    Text(viewModel.batchCreationDisabledReason)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Batch Configuration Section
    private func batchConfigurationSection(_ batch: ProductionBatch) -> some View {
        VStack(spacing: 16) {
            // Workflow progress indicator
            WorkflowProgressView(
                currentStep: viewModel.workflowCurrentStep,
                steps: ["创建批次", "添加产品", "提交审批", "等待审批"]
            )
            
            // Batch info header
            batchInfoHeader(batch)
            
            // Products list
            productsListSection(batch)
            
            // Add product button
            if viewModel.canAddProducts && batch.products.count < batch.mode.maxProducts {
                Button("添加产品") {
                    viewModel.showAddProduct()
                }
                .buttonStyle(.bordered)
            }
            
            
            // Submit for approval button - always visible with state feedback
            VStack(spacing: 8) {
                Button(viewModel.submitButtonText) {
                    handleSubmitBatch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmitBatch || viewModel.isLoading)
                
                if !viewModel.canSubmitBatch {
                    Text(viewModel.submitButtonDisabledReason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Station utilization visualization
            stationVisualization(batch)
        }
    }
    
    // MARK: - Batch Info Header
    private func batchInfoHeader(_ batch: ProductionBatch) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("批次编号")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(batch.batchNumber + " (" + batch.batchType.displayName + ")")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(batch.status.color)
                            .frame(width: 8, height: 8)
                        Text(batch.status.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text("当前批次工位: \(batch.totalStationsUsed)/12")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("|\(batch.mode.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("产品数量: \(batch.products.count)/\(batch.mode.maxProducts)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Products List Section
    private func productsListSection(_ batch: ProductionBatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            if batch.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(LopanColors.textSecondary)
                    
                    Text("暂无产品配置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(batch.products, id: \.id) { product in
                        ProductConfigRow(
                            product: product,
                            colors: viewModel.activeColors,
                            onDelete: viewModel.canAddProducts ? {
                                _ = viewModel.getBatchService().removeProductFromBatch(batch, productConfig: product)
                            } : nil
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Station Visualization
    private func stationVisualization(_ batch: ProductionBatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工位分配")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 8) {
                    // Gun A stations (1-6)
                    HStack(spacing: 4) {
                        Text("Gun A")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        ForEach(1...6, id: \.self) { stationNumber in
                            StationIndicator(
                                stationNumber: stationNumber,
                                isOccupied: batch.products.contains { $0.occupiedStations.contains(stationNumber) },
                                productName: batch.products.first { $0.occupiedStations.contains(stationNumber) }?.productName
                            )
                        }
                    }
                    
                    // Gun B stations (7-12)
                    HStack(spacing: 4) {
                        Text("Gun B")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        ForEach(7...12, id: \.self) { stationNumber in
                            StationIndicator(
                                stationNumber: stationNumber,
                                isOccupied: batch.products.contains { $0.occupiedStations.contains(stationNumber) },
                                productName: batch.products.first { $0.occupiedStations.contains(stationNumber) }?.productName
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(LopanColors.backgroundSecondary)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    private func handleSubmitBatch() {
        let result = viewModel.submitBatch()
        
        if !result.canSubmit, let conflictInfo = result.conflictInfo {
            // Show conflict alert
            currentConflictInfo = conflictInfo
            showingConflictAlert = true
        }
    }
}


// MARK: - Machine Card
struct MachineCard: View {
    let machine: WorkshopMachine
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Machine #\(machine.machineNumber)")
                .font(.caption)
                .fontWeight(.semibold)
            
            Image(systemName: "gearshape.2.fill")
                .font(.title)
                .foregroundColor(isSelected ? .white : statusColor)
            
            VStack(spacing: 2) {
                Text(machine.status.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                
                Text("\(machine.availableStations.count) 工位可用")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
        }
        .frame(width: 100, height: 100)
        .background(isSelected ? LopanColors.primary : LopanColors.backgroundSecondary)
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
    
    private var statusColor: Color {
        switch machine.status {
        case .running: return LopanColors.success
        case .stopped: return LopanColors.textSecondary
        case .maintenance: return .orange
        case .error: return LopanColors.error
        }
    }
}

// MARK: - Production Mode Card
struct ProductionModeCard: View {
    let mode: ProductionMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(mode.displayName)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 4) {
                Text("≥\(mode.minStationsPerProduct) 工位/产品")
                    .font(.caption)
                
                Text("最多 \(mode.maxProducts) 个产品")
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(isSelected ? LopanColors.primary : LopanColors.backgroundSecondary)
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Product Config Row
struct ProductConfigRow: View {
    let product: ProductConfig
    let colors: [ColorCard]
    let onDelete: (() -> Void)?
    
    private var primaryColor: ColorCard? {
        colors.first { $0.id == product.primaryColorId }
    }
    
    private var secondaryColor: ColorCard? {
        guard let secondaryColorId = product.secondaryColorId else { return nil }
        return colors.first { $0.id == secondaryColorId }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("工位: \(product.occupiedStations.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Colors
            HStack(spacing: 8) {
                if let primaryColor = primaryColor {
                    ColorDot(color: primaryColor)
                }
                
                if let secondaryColor = secondaryColor {
                    ColorDot(color: secondaryColor)
                }
            }
            
            // Delete button
            if let onDelete = onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(LopanColors.error)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Color Dot
struct ColorDot: View {
    let color: ColorCard
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(LopanColors.secondaryLight, lineWidth: 1)
                )
            
            Text(color.name)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

// MARK: - Station Indicator
struct StationIndicator: View {
    let stationNumber: Int
    let isOccupied: Bool
    let productName: String?
    
    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isOccupied ? LopanColors.primary : LopanColors.secondaryLight)
                .frame(width: 32, height: 20)
                .overlay(
                    Text("\(stationNumber)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isOccupied ? LopanColors.textPrimary : LopanColors.textSecondary)
                )
            
            if let productName = productName {
                Text(productName.prefix(3))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Add Product Sheet (Placeholder)
struct AddProductSheet: View {
    let batch: ProductionBatch
    let machine: WorkshopMachine
    let colors: [ColorCard]
    let products: [Product]
    @ObservedObject var batchService: ProductionBatchService
    let prePopulatedPrimaryColor: ColorCard?
    let prePopulatedSecondaryColor: ColorCard?
    let onDismiss: () -> Void
    
    @State private var selectedProduct: Product?
    @State private var productName = ""
    @State private var selectedPrimaryColor: ColorCard?
    @State private var selectedSecondaryColor: ColorCard?
    @State private var selectedStations: Set<Int> = []
    @State private var selectedStationCount: Int?
    @State private var selectedGun: String = "Gun A"
    @State private var selectedTargetDate: Date = Date()
    @State private var selectedShift: Shift = .morning
    @State private var isAdding = false
    @State private var showingValidationAlert = false
    @State private var validationAlertTitle = ""
    @State private var validationAlertMessage = ""
    
    // Services for shift management
    private let dateShiftPolicy = StandardDateShiftPolicy()
    private let timeProvider = SystemTimeProvider()
    
    var availableStations: [Int] {
        let occupiedStations = batch.products.flatMap { $0.occupiedStations }
        return (1...12).filter { !occupiedStations.contains($0) }
    }
    
    var stationCountOptions: [Int] {
        switch batch.mode {
        case .singleColor:
            // Apply single-color production constraints
            if let existingProduct = batch.products.first,
               let existingGun = existingProduct.gunAssignment,
               existingGun == selectedGun,
               let existingStationCount = existingProduct.stationCount {
                // If same gun is selected and there are existing products with that gun,
                // only show the same station count and "Other" option
                return [existingStationCount]
            } else {
                // Calculate available options based on selected gun capacity
                let availableStationsForGun = selectedGun == "Gun A" ? gunAAvailableStations : gunBAvailableStations
                var options: [Int] = []
                
                // Add 3 stations if possible
                if availableStationsForGun.count >= 3 {
                    options.append(3)
                }
                
                // Add 6 stations if possible
                if availableStationsForGun.count >= 6 {
                    options.append(6)
                }
                
                return options.isEmpty ? [] : options
            }
        case .dualColor:
            // Apply two-color production constraints
            if let existingProduct = batch.products.first,
               let existingStationCount = existingProduct.stationCount {
                // If there are existing products, only show the same station count and "Other" option
                return [existingStationCount]
            } else {
                var options: [Int] = []
                
                // For dual color, need both guns to have minimum stations
                if gunAAvailableStations.count >= 3 && gunBAvailableStations.count >= 3 {
                    options.append(3)
                }
                
                if gunAAvailableStations.count >= 6 && gunBAvailableStations.count >= 6 {
                    options.append(6)
                }
                
                return options
            }
        }
    }
    
    var gunAStations: [Int] { return [1, 2, 3, 4, 5, 6] }
    var gunBStations: [Int] { return [7, 8, 9, 10, 11, 12] }
    
    // Gun capacity tracking
    var gunAOccupiedStations: [Int] {
        return batch.products.flatMap { $0.occupiedStations }.filter { $0 <= 6 }
    }
    
    var gunBOccupiedStations: [Int] {
        return batch.products.flatMap { $0.occupiedStations }.filter { $0 > 6 }
    }
    
    var gunAAvailableStations: [Int] {
        return gunAStations.filter { station in
            !gunAOccupiedStations.contains(station) && availableStations.contains(station)
        }
    }
    
    var gunBAvailableStations: [Int] {
        return gunBStations.filter { station in
            !gunBOccupiedStations.contains(station) && availableStations.contains(station)
        }
    }
    
    var isGunAFull: Bool {
        return gunAOccupiedStations.count >= 6
    }
    
    var isGunBFull: Bool {
        return gunBOccupiedStations.count >= 6
    }
    
    var canSelectGunA: Bool {
        return !isGunAFull && gunAAvailableStations.count >= batch.mode.minStationsPerProduct
    }
    
    var canSelectGunB: Bool {
        return !isGunBFull && gunBAvailableStations.count >= batch.mode.minStationsPerProduct
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Product selection
                    productSelectionSection
                    
                    // Color selection
                    colorSelectionSection
                    
                    // Station count selection
                    stationCountSelectionSection
                    
                    // Gun assignment
                    gunAssignmentSection
                    
                    // Shift selection (Date and Shift)
                    shiftSelectionSection
                    
                    // Station visualization (if station count is selected or if "Other" is selected and stations are chosen)
                    if let stationCount = selectedStationCount, stationCount > 0 {
                        stationVisualizationSection(stationCount)
                    } else if selectedStationCount == -1 && !selectedStations.isEmpty {
                        stationVisualizationSection(selectedStations.count)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button("添加产品") {
                            handleAddProductTap()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAdding)
                        
                        Button("取消") {
                            onDismiss()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isAdding)
                    }
                }
                .padding()
            }
            .navigationTitle("添加产品")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize with pre-populated colors from gun configuration for dual-color mode
                if batch.mode == .dualColor {
                    if selectedPrimaryColor == nil {
                        selectedPrimaryColor = prePopulatedPrimaryColor
                    }
                    if selectedSecondaryColor == nil {
                        selectedSecondaryColor = prePopulatedSecondaryColor
                    }
                }
                
                // For single-color mode, set up initial gun selection and color
                if batch.mode == .singleColor {
                    // Default to first available gun
                    if selectedGun.isEmpty {
                        if canSelectGunA {
                            selectedGun = "Gun A"
                        } else if canSelectGunB {
                            selectedGun = "Gun B"
                        }
                    }
                    
                    // Validate current gun selection is still valid
                    if selectedGun == "Gun A" && !canSelectGunA {
                        selectedGun = canSelectGunB ? "Gun B" : ""
                    } else if selectedGun == "Gun B" && !canSelectGunB {
                        selectedGun = canSelectGunA ? "Gun A" : ""
                    }
                    
                    if !selectedGun.isEmpty {
                        updateColorBasedOnGunSelection()
                    }
                }
            }
        }
        .alert(validationAlertTitle, isPresented: $showingValidationAlert) {
            Button("确定") {
                showingValidationAlert = false
            }
        } message: {
            Text(validationAlertMessage)
        }
    }
    
    private var productSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品选择")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Picker("选择产品", selection: $selectedProduct) {
                    Text("请选择产品...").tag(nil as Product?)
                    ForEach(products, id: \.id) { product in
                        Text(product.name).tag(product as Product?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProduct) { _, newProduct in
                    if let product = newProduct {
                        productName = product.name
                    } else {
                        productName = ""
                    }
                }
                
                if products.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("暂无可用产品")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("请联系管理员添加产品")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(LopanColors.warningLight)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("颜色选择")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if (batch.mode == .singleColor && isColorPrePopulated(selectedPrimaryColor, gunName: selectedGun)) ||
                   (batch.mode == .dualColor && (isColorPrePopulated(selectedPrimaryColor, gunName: "Gun A") || isColorPrePopulated(selectedSecondaryColor, gunName: "Gun B"))) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(LopanColors.success)
                        Text("已从喷枪配置自动填充")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(spacing: 12) {
                // Primary color - read-only if pre-populated, otherwise selectable
                let shouldShowReadOnlyPrimaryColor = (batch.mode == .singleColor && isColorPrePopulated(selectedPrimaryColor, gunName: selectedGun)) ||
                                                    (batch.mode == .dualColor && isColorPrePopulated(selectedPrimaryColor, gunName: "Gun A"))
                
                if shouldShowReadOnlyPrimaryColor && selectedPrimaryColor != nil {
                    ReadOnlyColorRow(
                        title: batch.mode == .dualColor ? "主颜色 (Gun A)" : "主颜色 (\(selectedGun))",
                        color: selectedPrimaryColor!
                    )
                } else {
                    ColorPickerRow(
                        title: batch.mode == .dualColor ? "主颜色 (Gun A)" : "主颜色 (\(selectedGun))",
                        selectedColor: selectedPrimaryColor,
                        colors: colors,
                        isPrePopulated: false
                    ) { color in
                        selectedPrimaryColor = color
                        // Auto-assign stations if dual-color and station count is selected
                        if batch.mode == .dualColor && selectedStationCount != nil && selectedStationCount! > 0 {
                            autoAssignStations()
                        }
                    }
                }
                
                if batch.mode == .dualColor {
                    // Secondary color - read-only if pre-populated, otherwise selectable
                    if isColorPrePopulated(selectedSecondaryColor, gunName: "Gun B") && selectedSecondaryColor != nil {
                        ReadOnlyColorRow(
                            title: "副颜色 (Gun B)",
                            color: selectedSecondaryColor!
                        )
                    } else {
                        ColorPickerRow(
                            title: "副颜色 (Gun B)",
                            selectedColor: selectedSecondaryColor,
                            colors: colors.filter { $0.id != selectedPrimaryColor?.id },
                            isPrePopulated: false
                        ) { color in
                            selectedSecondaryColor = color
                            // Auto-assign stations when secondary color is selected
                            if selectedStationCount != nil && selectedStationCount! > 0 {
                                autoAssignStations()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var stationCountSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工位数量选择")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(stationCountOptions, id: \.self) { count in
                    Button("\(count) 工位") {
                        selectedStationCount = count
                        autoAssignStations()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedStationCount == count ? LopanColors.primary : LopanColors.secondaryLight)
                    .foregroundColor(selectedStationCount == count ? .white : .primary)
                    .cornerRadius(8)
                }
                
                Button("其他") {
                    selectedStationCount = -1 // Use -1 to indicate "Other" option
                    selectedStations = []
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedStationCount == -1 ? LopanColors.primary : LopanColors.secondaryLight)
                .foregroundColor(selectedStationCount == -1 ? .white : .primary)
                .cornerRadius(8)
            }
            
            // Show manual station selection when "Other" is selected
            if selectedStationCount == -1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择所需工位 (至少 \(batch.mode.minStationsPerProduct) 个) - 仅限 \(selectedGun) 工位")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let stationsForSelectedGun = batch.mode == .singleColor ? 
                        (selectedGun == "Gun A" ? gunAAvailableStations : gunBAvailableStations) :
                        availableStations
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(stationsForSelectedGun, id: \.self) { station in
                            Button("\(station)") {
                                if selectedStations.contains(station) {
                                    selectedStations.remove(station)
                                } else {
                                    selectedStations.insert(station)
                                }
                            }
                            .frame(height: 40)
                            .background(selectedStations.contains(station) ? LopanColors.primary : LopanColors.secondaryLight)
                            .foregroundColor(selectedStations.contains(station) ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                    
                    if stationsForSelectedGun.isEmpty {
                        Text("所选喷枪无可用工位")
                            .font(.caption)
                            .foregroundColor(LopanColors.error)
                            .padding()
                            .background(LopanColors.errorLight)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var gunAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("喷枪分配")
                .font(.headline)
                .fontWeight(.semibold)
            
            if batch.mode == .dualColor {
                VStack(spacing: 8) {
                    Text("双色产品自动分配：主颜色→Gun A，副颜色→Gun B")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("Gun A")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("主颜色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let primaryColor = selectedPrimaryColor {
                                Circle()
                                    .fill(primaryColor.swiftUIColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(LopanColors.secondaryLight, lineWidth: 1)
                                    )
                            } else {
                                Circle()
                                    .fill(LopanColors.secondaryLight)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LopanColors.primaryLight)
                        .cornerRadius(8)
                        
                        VStack(spacing: 4) {
                            Text("Gun B")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("副颜色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let secondaryColor = selectedSecondaryColor {
                                Circle()
                                    .fill(secondaryColor.swiftUIColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(LopanColors.secondaryLight, lineWidth: 1)
                                    )
                            } else {
                                Circle()
                                    .fill(LopanColors.secondaryLight)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LopanColors.warningLight)
                        .cornerRadius(8)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Button("Gun A") {
                            selectedGun = "Gun A"
                            updateColorBasedOnGunSelection()
                            if selectedStationCount != nil && selectedStationCount! > 0 {
                                autoAssignStations()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedGun == "Gun A" ? LopanColors.primary : (canSelectGunA ? LopanColors.secondaryLight : LopanColors.errorLight))
                        .foregroundColor(selectedGun == "Gun A" ? LopanColors.textPrimary : (canSelectGunA ? LopanColors.primary : LopanColors.error))
                        .cornerRadius(8)
                        .disabled(!canSelectGunA)
                        
                        if !canSelectGunA {
                            Text(isGunAFull ? "已满" : "工位不足")
                                .font(.caption2)
                                .foregroundColor(LopanColors.error)
                        } else {
                            Text("\(gunAAvailableStations.count) 个可用")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Button("Gun B") {
                            selectedGun = "Gun B"
                            updateColorBasedOnGunSelection()
                            if selectedStationCount != nil && selectedStationCount! > 0 {
                                autoAssignStations()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedGun == "Gun B" ? LopanColors.primary : (canSelectGunB ? LopanColors.secondaryLight : LopanColors.errorLight))
                        .foregroundColor(selectedGun == "Gun B" ? LopanColors.textPrimary : (canSelectGunB ? LopanColors.primary : LopanColors.error))
                        .cornerRadius(8)
                        .disabled(!canSelectGunB)
                        
                        if !canSelectGunB {
                            Text(isGunBFull ? "已满" : "工位不足")
                                .font(.caption2)
                                .foregroundColor(LopanColors.error)
                        } else {
                            Text("\(gunBAvailableStations.count) 个可用")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var shiftSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Use the ShiftDateSelector component
            ShiftDateSelector(
                selectedDate: $selectedTargetDate,
                selectedShift: $selectedShift,
                dateShiftPolicy: dateShiftPolicy,
                timeProvider: timeProvider,
                isDisabled: false
            )
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private func stationVisualizationSection(_ stationCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工位分配预览")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("已选择 \(selectedStations.count) 个工位")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 8) {
                    // Gun A stations (1-6)
                    HStack(spacing: 4) {
                        Text("Gun A")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        ForEach(gunAStations, id: \.self) { station in
                            StationPreviewIndicator(
                                stationNumber: station,
                                isSelected: selectedStations.contains(station),
                                isAvailable: availableStations.contains(station),
                                colorIndicator: batch.mode == .dualColor ? selectedPrimaryColor?.swiftUIColor : nil
                            )
                        }
                    }
                    
                    // Gun B stations (7-12)
                    HStack(spacing: 4) {
                        Text("Gun B")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        ForEach(gunBStations, id: \.self) { station in
                            StationPreviewIndicator(
                                stationNumber: station,
                                isSelected: selectedStations.contains(station),
                                isAvailable: availableStations.contains(station),
                                colorIndicator: batch.mode == .dualColor ? selectedSecondaryColor?.swiftUIColor : nil
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var stationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工位选择")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("至少选择 \(batch.mode.minStationsPerProduct) 个工位")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(availableStations, id: \.self) { station in
                    Button("\(station)") {
                        if selectedStations.contains(station) {
                            selectedStations.remove(station)
                        } else {
                            selectedStations.insert(station)
                        }
                    }
                    .frame(height: 40)
                    .background(selectedStations.contains(station) ? LopanColors.primary : LopanColors.secondaryLight)
                    .foregroundColor(selectedStations.contains(station) ? .white : .primary)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var isShiftValid: Bool {
        // Check if selected shift is allowed for the target date
        let allowedShifts = dateShiftPolicy.allowedShifts(for: selectedTargetDate, currentTime: timeProvider.now)
        return allowedShifts.contains(selectedShift)
    }
    
    private var shiftValidationMessage: String {
        let cutoffInfo = dateShiftPolicy.getCutoffInfo(for: selectedTargetDate, currentTime: timeProvider.now)
        return cutoffInfo.restrictionMessage ?? ""
    }
    
    private var isValidConfiguration: Bool {
        selectedProduct != nil &&
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedPrimaryColor != nil &&
        (batch.mode == .singleColor || selectedSecondaryColor != nil) &&
        selectedStations.count >= batch.mode.minStationsPerProduct &&
        (selectedStationCount != nil && (selectedStationCount! > 0 || selectedStationCount! == -1)) &&
        isShiftValid
    }
    
    private func handleAddProductTap() {
        let validation = performComprehensiveValidation()
        
        if validation.isValid {
            // All validations passed, proceed with adding product
            addProduct()
        } else {
            // Show validation error alert
            validationAlertTitle = validation.title
            validationAlertMessage = validation.message
            showingValidationAlert = true
        }
    }
    
    private func autoAssignStations() {
        guard let stationCount = selectedStationCount, stationCount > 0 else { return }
        
        selectedStations.removeAll()
        
        if batch.mode == .dualColor {
            // For dual-color products: use equal stations on both guns
            if stationCount == 3 {
                // 3 stations each gun: Gun A (1-3), Gun B (7-9)
                let gunAAvailable = gunAStations.filter { availableStations.contains($0) }
                let gunBAvailable = gunBStations.filter { availableStations.contains($0) }
                
                selectedStations.formUnion(gunAAvailable.prefix(3))
                selectedStations.formUnion(gunBAvailable.prefix(3))
            } else if stationCount == 6 {
                // 6 stations each gun: Gun A (1-6), Gun B (7-12)
                let gunAAvailable = gunAStations.filter { availableStations.contains($0) }
                let gunBAvailable = gunBStations.filter { availableStations.contains($0) }
                
                selectedStations.formUnion(gunAAvailable.prefix(6))
                selectedStations.formUnion(gunBAvailable.prefix(6))
            }
        } else {
            // Single color products: use selected gun only, respect capacity limits
            let availableStationsForSelectedGun = selectedGun == "Gun A" ? gunAAvailableStations : gunBAvailableStations
            
            // Only assign stations from the selected gun, no spillover to other gun
            selectedStations = Set(availableStationsForSelectedGun.prefix(stationCount))
        }
    }
    
    private func addProduct() {
        guard let primaryColor = selectedPrimaryColor else { return }
        
        Task {
            isAdding = true
            
            // Update batch with shift information if not already set
            if batch.targetDate == nil || batch.shift == nil {
                batch.targetDate = selectedTargetDate
                batch.shift = selectedShift
                batch.approvalTargetDate = selectedTargetDate
            }
            
            // Combine target date with shift start time
            let shiftStartTime = DateTimeUtilities.createShiftStartTime(for: selectedTargetDate, shift: selectedShift)
            
            let success = await batchService.addProductToBatch(
                batch,
                productName: productName,
                primaryColorId: primaryColor.id,
                secondaryColorId: selectedSecondaryColor?.id,
                stations: Array(selectedStations),
                productId: selectedProduct?.id,
                stationCount: selectedStationCount,
                gunAssignment: selectedGun,
                approvalTargetDate: selectedTargetDate,
                startTime: shiftStartTime,
                isFromProductionConfiguration: true
            )
            isAdding = false
            if success {
                onDismiss()
            } else {
                // Show error message when adding product fails
                // 当添加产品失败时显示错误信息
                validationAlertTitle = "添加失败"
                validationAlertMessage = batchService.errorMessage ?? "添加产品时发生未知错误"
                showingValidationAlert = true
            }
        }
    }
    
    // createShiftStartTime function replaced with DateTimeUtilities.createShiftStartTime
    
    private func isColorPrePopulated(_ color: ColorCard?, gunName: String) -> Bool {
        guard let color = color else { return false }
        
        let gun = machine.guns.first { $0.name == gunName }
        return gun?.currentColorId == color.id
    }
    
    private func updateColorBasedOnGunSelection() {
        guard batch.mode == .singleColor else { return }
        
        // Check if there are existing products using the same gun
        if let existingProduct = batch.products.first(where: { $0.gunAssignment == selectedGun }) {
            // Retain the color from existing product using the same gun
            selectedPrimaryColor = colors.first { $0.id == existingProduct.primaryColorId }
            return
        }
        
        let selectedGunModel = machine.guns.first { $0.name == selectedGun }
        
        // If the selected gun has a configured color, use it
        if let colorId = selectedGunModel?.currentColorId {
            selectedPrimaryColor = colors.first { $0.id == colorId }
        } else {
            // If the selected gun has no configured color, clear selection to force user configuration
            selectedPrimaryColor = nil
        }
    }
    
    private func validateShift() {
        // Trigger validation by accessing the computed property
        _ = isShiftValid
    }
    
    // combineDateTime function replaced with DateTimeUtilities.combineDateTime
    
    // formatDate function replaced with DateTimeUtilities.formatMediumDate
    
    // MARK: - Validation Methods
    
    private func validateProductSelection() -> (isValid: Bool, title: String, message: String) {
        if selectedProduct == nil {
            return (false, "产品未选择", "请选择一个产品后再继续添加")
        }
        return (true, "", "")
    }
    
    private func validateColorConfiguration() -> (isValid: Bool, title: String, message: String) {
        if selectedPrimaryColor == nil {
            return (false, "颜色未配置", "请配置主颜色后再继续添加")
        }
        
        if batch.mode == .dualColor && selectedSecondaryColor == nil {
            return (false, "颜色未配置", "双色模式需要配置副颜色，请配置副颜色后继续添加")
        }
        
        return (true, "", "")
    }
    
    private func validateGunAssignment() -> (isValid: Bool, title: String, message: String) {
        if batch.mode == .singleColor && selectedGun.isEmpty {
            return (false, "喷枪未分配", "请选择喷枪分配后再继续添加")
        }
        return (true, "", "")
    }
    
    private func validateStationSelection() -> (isValid: Bool, title: String, message: String) {
        if selectedStationCount == nil {
            return (false, "工位数量未选择", "请选择工位数量后再继续添加")
        }
        
        if selectedStations.count < batch.mode.minStationsPerProduct {
            return (false, "工位配置不足", "至少需要选择 \(batch.mode.minStationsPerProduct) 个工位")
        }
        
        // Check for station conflicts
        let occupiedStations = batch.products.flatMap { $0.occupiedStations }
        let conflictingStations = selectedStations.filter { occupiedStations.contains($0) }
        
        if !conflictingStations.isEmpty {
            let stationNumbers = conflictingStations.sorted().map { String($0) }.joined(separator: ", ")
            return (false, "工位冲突", "工位 \(stationNumbers) 已被其他批次占用，请选择不同的工位")
        }
        
        return (true, "", "")
    }
    
    private func validateTimeConfiguration() -> (isValid: Bool, title: String, message: String) {
        // Check if selected shift is allowed for the target date
        let allowedShifts = dateShiftPolicy.allowedShifts(for: selectedTargetDate, currentTime: timeProvider.now)
        
        if !allowedShifts.contains(selectedShift) {
            // Only show error if trying to select an invalid shift
            let cutoffInfo = dateShiftPolicy.getCutoffInfo(for: selectedTargetDate, currentTime: timeProvider.now)
            let message = cutoffInfo.restrictionMessage ?? "所选班次不可用"
            return (false, "时间配置无效", message)
        }
        
        return (true, "", "")
    }
    
    private func performComprehensiveValidation() -> (isValid: Bool, title: String, message: String) {
        // Check product selection
        let productValidation = validateProductSelection()
        if !productValidation.isValid {
            return productValidation
        }
        
        // Check color configuration
        let colorValidation = validateColorConfiguration()
        if !colorValidation.isValid {
            return colorValidation
        }
        
        // Check gun assignment
        let gunValidation = validateGunAssignment()
        if !gunValidation.isValid {
            return gunValidation
        }
        
        // Check station selection
        let stationValidation = validateStationSelection()
        if !stationValidation.isValid {
            return stationValidation
        }
        
        // Check time configuration
        let timeValidation = validateTimeConfiguration()
        if !timeValidation.isValid {
            return timeValidation
        }
        
        return (true, "", "")
    }
}

// MARK: - Read Only Color Row
struct ReadOnlyColorRow: View {
    let title: String
    let color: ColorCard
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(LopanColors.success)
            }
            .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            // Display the configured color
            HStack(spacing: 12) {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(LopanColors.success, lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(color.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(color.hexCode)
                        .font(.caption)
                        .monospaced()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("已配置")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LopanColors.successLight)
                    .foregroundColor(LopanColors.success)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Color Picker Row
struct ColorPickerRow: View {
    let title: String
    let selectedColor: ColorCard?
    let colors: [ColorCard]
    let isPrePopulated: Bool
    let onSelect: (ColorCard) -> Void
    
    init(title: String, selectedColor: ColorCard?, colors: [ColorCard], isPrePopulated: Bool = false, onSelect: @escaping (ColorCard) -> Void) {
        self.title = title
        self.selectedColor = selectedColor
        self.colors = colors
        self.isPrePopulated = isPrePopulated
        self.onSelect = onSelect
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isPrePopulated {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(LopanColors.success)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(colors, id: \.id) { color in
                        Button {
                            onSelect(color)
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor?.id == color.id ? LopanColors.primary : LopanColors.secondaryLight, lineWidth: selectedColor?.id == color.id ? 2 : 1)
                                    )
                                
                                Text(color.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Station Preview Indicator
struct StationPreviewIndicator: View {
    let stationNumber: Int
    let isSelected: Bool
    let isAvailable: Bool
    let colorIndicator: Color?
    
    init(stationNumber: Int, isSelected: Bool, isAvailable: Bool, colorIndicator: Color? = nil) {
        self.stationNumber = stationNumber
        self.isSelected = isSelected
        self.isAvailable = isAvailable
        self.colorIndicator = colorIndicator
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .frame(width: 32, height: 20)
            .overlay(
                Text("\(stationNumber)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
            )
            .overlay(
                // Color indicator for dual-color mode
                Group {
                    if let color = colorIndicator, isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .offset(x: 10, y: -6)
                    }
                }
            )
    }
    
    private var fillColor: Color {
        if isSelected {
            return LopanColors.primary
        } else if isAvailable {
            return LopanColors.textSecondary.opacity(0.3)
        } else {
            return LopanColors.error.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isAvailable {
            return LopanColors.textSecondary
        } else {
            return LopanColors.error
        }
    }
}

// MARK: - Supporting Components

struct WorkflowProgressView: View {
    let currentStep: Int
    let steps: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(index <= currentStep ? LopanColors.primary : LopanColors.secondaryLight)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(index <= currentStep ? LopanColors.textPrimary : LopanColors.textSecondary)
                            )
                        
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? LopanColors.primary : LopanColors.secondaryLight)
                                .frame(height: 2)
                        }
                    }
                }
            }
            
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    Text(steps[index])
                        .font(.caption)
                        .foregroundColor(index <= currentStep ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Approval Batch Row
struct ApprovalBatchRow: View {
    let batch: ProductionBatch
    let colors: [ColorCard]
    let machines: [WorkshopMachine]
    let canManageProduction: Bool
    let onExecute: (ProductionBatch) -> Void
    let onRecreate: (ProductionBatch) -> Void
    let onTap: () -> Void
    
    private var machine: WorkshopMachine? {
        machines.first { $0.id == batch.machineId }
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Batch status indicator
                VStack {
                    Circle()
                        .fill(batch.status.color)
                        .frame(width: 12, height: 12)
                    Spacer()
                }
                
                // Batch information
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(batch.batchNumber + " (" + batch.batchType.displayName + ")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(DateTimeUtilities.timeAgoString(from: batch.submittedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text(batch.status.displayName)
                            .font(.caption)
                            .foregroundColor(batch.status.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(batch.status.color.opacity(0.1))
                            .cornerRadius(4)
                        
                        Text(batch.mode.displayName)
                            .font(.caption)
                            .foregroundColor(LopanColors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LopanColors.primaryLight)
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text((machine?.machineNumber).map { "\($0)" } ?? batch.machineId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !batch.products.isEmpty {
                            HStack(spacing: 4) {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(batch.products.count) 产品")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(batch.totalStationsUsed) 工位")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Text("提交者: \(batch.submittedByName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("目标: \(DateTimeUtilities.formatApprovalDate(batch.approvalTargetDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let reviewNotes = batch.reviewNotes, batch.status == .rejected {
                        Text("拒绝原因: \(reviewNotes)")
                            .font(.caption)
                            .foregroundColor(LopanColors.error)
                            .padding(.top, 2)
                    }
                }
                
                // Action buttons
                VStack(spacing: 8) {
                    if batch.status == .approved && canManageProduction {
                        Button("执行") { 
                            onExecute(batch)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(LopanColors.primary)
                        .foregroundColor(LopanColors.textPrimary)
                        .cornerRadius(4)
                        .onTapGesture {
                            onExecute(batch)
                        }
                    }
                    
                    if batch.status == .rejected && canManageProduction {
                        Button("重新创建") {
                            onRecreate(batch)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(LopanColors.warning)
                        .foregroundColor(LopanColors.textPrimary)
                        .cornerRadius(4)
                        .onTapGesture {
                            onRecreate(batch)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(8)
    }
    
    // timeAgoString and formatApprovalDate functions replaced with DateTimeUtilities
}

// MARK: - Batch Details Sheet
struct BatchDetailsSheet: View {
    let batch: ProductionBatch
    let colors: [ColorCard]
    let machines: [WorkshopMachine]
    let onExecuteBatch: ((ProductionBatch, Date) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    // Execution time selection states
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var machine: WorkshopMachine? {
        machines.first { $0.id == batch.machineId }
    }
    
    init(batch: ProductionBatch, colors: [ColorCard], machines: [WorkshopMachine], onExecuteBatch: ((ProductionBatch, Date) -> Void)? = nil) {
        self.batch = batch
        self.colors = colors
        self.machines = machines
        self.onExecuteBatch = onExecuteBatch
        
        // Initialize with current time or batch target date
        let initialDate = batch.targetDate ?? Date()
        self._selectedDate = State(initialValue: initialDate)
        self._selectedTime = State(initialValue: Date())
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with batch info
                    batchHeaderSection
                    
                    // Consolidated production configuration
                    consolidatedProductionSection
                    
                    // Status and timing (with submitter info)
                    statusTimingSection
                }
                .padding()
            }
            .navigationTitle("批次详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var batchHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("批次编号")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(batch.batchNumber)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("批次号 \(batch.batchNumber.replacingOccurrences(of: "-", with: " "))")
                        .accessibilityHint("生产配置批次")
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(batch.status.color)
                            .frame(width: 10, height: 10)
                        Text(batch.status.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(batch.status.color)
                    }
                }
            }
            
            // Submitter info moved to status section
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var consolidatedProductionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("生产配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Equipment and mode info (compact)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.caption)
                                .foregroundColor(LopanColors.primary)
                            Text((machine?.machineNumber).map { "\($0)" } ?? batch.machineId)
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(batch.mode.displayName)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(LopanColors.primary)
                    }
                }
                .padding(8)
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(8)
                
                Divider()
                
                // Products list (compact)
                if batch.products.isEmpty {
                    Text("暂无产品配置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(batch.products, id: \.id) { product in
                            CompactProductRow(product: product, colors: colors)
                        }
                    }
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var equipmentModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设备和生产模式")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 6) {
                HStack {
                    Text("生产设备")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.caption)
                            .foregroundColor(LopanColors.primary)
                        Text((machine?.machineNumber).map { "\($0)" } ?? batch.machineId)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("(\(machine?.status.displayName ?? "未知状态"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("生产模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(batch.mode.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("产品配置 (\(batch.products.count)/\(batch.mode.maxProducts))")
                .font(.headline)
                .fontWeight(.semibold)
            
            if batch.products.isEmpty {
                Text("暂无产品配置")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 6) {
                    ForEach(batch.products, id: \.id) { product in
                        CompactProductRow(product: product, colors: colors)
                    }
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var gunAAssignment: String {
        let gunAProducts = batch.products.compactMap { product -> String? in
            let occupiedInGunA = product.occupiedStations.filter { $0 <= 6 }
            guard !occupiedInGunA.isEmpty else { return nil }
            
            let stationsText = occupiedInGunA.sorted().map(String.init).joined(separator: ",")
            let colorText = getColorDisplayText(for: product)
            return "工位 \(stationsText) (\(product.productName)\(colorText))"
        }
        
        return gunAProducts.joined(separator: "; ")
    }
    
    private var gunBAssignment: String {
        let gunBProducts = batch.products.compactMap { product -> String? in
            let occupiedInGunB = product.occupiedStations.filter { $0 > 6 }
            guard !occupiedInGunB.isEmpty else { return nil }
            
            let stationsText = occupiedInGunB.sorted().map(String.init).joined(separator: ",")
            let colorText = getColorDisplayText(for: product)
            return "工位 \(stationsText) (\(product.productName)\(colorText))"
        }
        
        return gunBProducts.joined(separator: "; ")
    }
    
    private func getColorDisplayText(for product: ProductConfig) -> String {
        let primaryColor = colors.first { $0.id == product.primaryColorId }
        let secondaryColor = product.secondaryColorId != nil ? colors.first { $0.id == product.secondaryColorId } : nil
        
        var colorText = ""
        if let primary = primaryColor {
            colorText = "-\(primary.name)"
        }
        if let secondary = secondaryColor {
            colorText += "+\(secondary.name)"
        }
        
        return colorText
    }
    
    private var statusTimingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("审批信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Submitter info (moved from header)
                HStack {
                    Text("提交者:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(batch.submittedByName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("审批目标日期:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(DateTimeUtilities.formatMediumDate(batch.approvalTargetDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let reviewedAt = batch.reviewedAt {
                    HStack {
                        Text("审批时间:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(DateTimeUtilities.formatDateTime(reviewedAt))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                if let reviewedByName = batch.reviewedByName {
                    HStack {
                        Text("审批人:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(reviewedByName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                if let reviewNotes = batch.reviewNotes, !reviewNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("审批备注:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(reviewNotes)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(batch.status == .rejected ? LopanColors.errorLight : LopanColors.successLight)
                            .foregroundColor(batch.status == .rejected ? LopanColors.error : LopanColors.success)
                            .cornerRadius(8)
                    }
                }
                
                // Execution information section for completed batches
                if batch.status == .completed {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("执行信息")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        // 显示执行时间
                        if let executionTime = batch.executionTime {
                            HStack {
                                Text("执行时间:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(DateTimeUtilities.formatDateTime(executionTime))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // 显示完成时间
                        if let completedAt = batch.completedAt {
                            HStack {
                                Text("完成时间:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(DateTimeUtilities.formatDateTime(completedAt))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // 显示生产时长
                        if let duration = batch.formattedRuntimeDuration {
                            HStack {
                                Text("生产时长:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(duration)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(LopanColors.primary)
                            }
                        }
                        
                        // 显示执行类型
                        if let executionInfo = batch.executionTypeInfo {
                            HStack {
                                Text("执行方式:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(executionInfo.type)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(batch.isSystemAutoCompleted ? LopanColors.warning : LopanColors.success)
                            }
                            
                            // 显示执行描述
                            /*if !executionInfo.details.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("执行描述:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(executionInfo.details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(LopanColors.secondary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }*/
                        }
                    }
                }
                
                // Execution action section for pending execution batches
                if batch.status == .pendingExecution, onExecuteBatch != nil {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 16) {
                        /*HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(LopanColors.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("准备执行")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("批次已通过审批，可以设置执行时间开始生产")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }*/
                        
                        // Date Time Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("选择执行时间")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                // Fixed Date Display (no picker - locked to batch target date)
                                HStack {
                                    Label("日期", systemImage: "calendar")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(selectedDate.formatted(.dateTime.year().month().day()))
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(LopanColors.secondary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                // Date restriction explanation
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Text("执行日期已锁定为批次提交日期，仅可修改执行时间")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                
                                // Time Picker
                                HStack {
                                    Label("时间", systemImage: "clock")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    DatePicker(
                                        "",
                                        selection: $selectedTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                            }
                        }
                        
                        // Validation Section
                        VStack(alignment: .leading, spacing: 8) {
                            Label("验证条件", systemImage: "checkmark.shield")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 6) {
                                validationItem(
                                    title: "时间限制",
                                    isValid: combinedDateTime <= Date(),
                                    message: combinedDateTime <= Date() ? "执行时间有效" : "执行时间不能晚于当前时间"
                                )
                                
                                if let shift = batch.shift {
                                    validationItem(
                                        title: "班次时间",
                                        isValid: isWithinShiftHours,
                                        message: isWithinShiftHours ? "在班次时间范围内" : "不在 \(shift.timeRangeDisplay) 范围内"
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button("取消") {
                                dismiss()
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(LopanColors.error)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(LopanColors.errorLight)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LopanColors.error.opacity(0.5), lineWidth: 1)
                            )
                            
                            Button(action: confirmExecution) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("确认执行")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(LopanColors.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(canConfirm ? LopanColors.primary : LopanColors.secondary)
                                .cornerRadius(12)
                            }
                            .disabled(!canConfirm)
                        }
                    }
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // formatDate and formatDateTime functions replaced with DateTimeUtilities
    
    // MARK: - Execution Time Helper Properties
    
    private var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? Date()
    }
    
    private var isWithinShiftHours: Bool {
        guard let shift = batch.shift else { return true }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: combinedDateTime)
        
        switch shift {
        case .morning:
            // Morning shift: 07:00 - 19:00
            return hour >= 7 && hour < 19
        case .evening:
            // Evening shift: 19:00 - 07:00 (next day)
            return hour >= 19 || hour < 7
        }
    }
    
    private var canConfirm: Bool {
        return combinedDateTime <= Date() && isWithinShiftHours
    }
    
    private func confirmExecution() {
        guard canConfirm else {
            errorMessage = "请选择有效的执行时间"
            showingError = true
            return
        }
        
        if let onExecuteBatch = onExecuteBatch {
            onExecuteBatch(batch, combinedDateTime)
        }
        
        dismiss()
    }
    
    private func validationItem(title: String, isValid: Bool, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isValid ? LopanColors.success : LopanColors.error)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.caption2)
                    .foregroundColor(isValid ? LopanColors.success : LopanColors.error)
            }
            
            Spacer()
        }
    }
}

// MARK: - Product Detail Row
struct ProductDetailRow: View {
    let product: ProductConfig
    let colors: [ColorCard]
    
    private var primaryColor: ColorCard? {
        colors.first { $0.id == product.primaryColorId }
    }
    
    private var secondaryColor: ColorCard? {
        guard let secondaryColorId = product.secondaryColorId else { return nil }
        return colors.first { $0.id == secondaryColorId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let gunAssignment = product.gunAssignment {
                    Text(gunAssignment)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LopanColors.secondaryLight)
                        .cornerRadius(4)
                }
            }
            
            HStack {
                Text("工位: \(product.occupiedStations.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let primaryColor = primaryColor {
                        ColorDetailDot(color: primaryColor, label: "主")
                    }
                    
                    if let secondaryColor = secondaryColor {
                        ColorDetailDot(color: secondaryColor, label: "副")
                    }
                }
            }
            
            if let startTime = product.startTime {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("开始时间: \(formatTime(startTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(8)
    }
    
    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: time)
    }
}

// MARK: - Color Detail Dot
struct ColorDetailDot: View {
    let color: ColorCard
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(LopanColors.secondaryLight, lineWidth: 1)
                    )
                
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
            }
            
            Text(color.name)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

// MARK: - Compact Product Row
struct CompactProductRow: View {
    let product: ProductConfig
    let colors: [ColorCard]
    
    private var primaryColor: ColorCard? {
        colors.first { $0.id == product.primaryColorId }
    }
    
    private var secondaryColor: ColorCard? {
        guard let secondaryColorId = product.secondaryColorId else { return nil }
        return colors.first { $0.id == secondaryColorId }
    }
    
    var body: some View {
        HStack {
            Text(product.productName)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("工位: \(product.occupiedStations.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    if let primaryColor = primaryColor {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: primaryColor.hexCode) ?? LopanColors.secondary)
                                .frame(width: 8, height: 8)
                            Text("主")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let secondaryColor = secondaryColor {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: secondaryColor.hexCode) ?? LopanColors.secondary)
                                .frame(width: 8, height: 8)
                            Text("副")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Station Detail Indicator
struct StationDetailIndicator: View {
    let stationNumber: Int
    let isOccupied: Bool
    let productName: String?
    
    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isOccupied ? LopanColors.primary : LopanColors.secondaryLight)
                .frame(width: 32, height: 20)
                .overlay(
                    Text("\(stationNumber)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isOccupied ? LopanColors.textPrimary : LopanColors.textSecondary)
                )
            
            if let productName = productName {
                Text(String(productName.prefix(2)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct ProductionConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self,
            ColorCard.self, ProductionBatch.self, ProductConfig.self,
            User.self, AuditLog.self, Product.self, ProductSize.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        ProductionConfigurationView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}
