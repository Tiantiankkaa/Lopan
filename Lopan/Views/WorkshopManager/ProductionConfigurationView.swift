//
//  ProductionConfigurationView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData


struct ProductionConfigurationView: View {
    @StateObject private var batchService: ProductionBatchService
    @StateObject private var colorService: ColorService
    @StateObject private var machineService: MachineService
    @StateObject private var productService: ProductService
    @ObservedObject private var authService: AuthenticationService
    
    @State private var selectedMachine: WorkshopMachine?
    @State private var selectedMode: ProductionMode = .singleColor
    @State private var currentBatch: ProductionBatch?
    @State private var showingAddProduct = false
    @State private var selectedPrimaryColor: ColorCard?
    @State private var selectedSecondaryColor: ColorCard?
    @State private var isColorPrePopulated = false
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        self._batchService = StateObject(wrappedValue: ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        ))
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
        self._productService = StateObject(wrappedValue: ProductService(
            repositoryFactory: repositoryFactory
        ))
    }
    
    var body: some View {
        VStack {
            if machineService.isLoading || colorService.isLoading || productService.isLoading {
                ProgressView("加载数据...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContent
            }
        }
            .refreshable {
                await loadData()
            }
            .alert("Error", isPresented: .constant(hasError)) {
                Button("确定") {
                    clearErrors()
                }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingAddProduct) {
                if let batch = currentBatch, let machine = selectedMachine {
                    AddProductSheet(
                        batch: batch,
                        machine: machine,
                        colors: colorService.colors.filter { $0.isActive },
                        products: productService.products,
                        batchService: batchService,
                        prePopulatedPrimaryColor: selectedPrimaryColor,
                        prePopulatedSecondaryColor: selectedSecondaryColor
                    ) {
                        showingAddProduct = false
                    }
                }
            }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Machine selection
                machineSelectionSection
                
                if selectedMachine != nil {
                    // Production mode selection
                    productionModeSection
                    
                    // Current batch info
                    if let batch = currentBatch {
                        batchConfigurationSection(batch)
                    } else {
                        createBatchSection
                    }
                }
            }
            .padding()
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
                    ForEach(machineService.machines.filter { $0.canReceiveNewTasks }, id: \.id) { machine in
                        MachineCard(
                            machine: machine,
                            isSelected: selectedMachine?.id == machine.id
                        ) {
                            selectedMachine = machine
                            currentBatch = nil // Reset batch when changing machine
                            autoPopulateGunColors() // Auto-populate colors for new machine
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
                        isSelected: selectedMode == mode
                    ) {
                        selectedMode = mode
                        currentBatch = nil // Reset batch when changing mode
                        autoPopulateGunColors() // Re-populate colors for new mode
                    }
                }
            }
        }
    }
    
    // MARK: - Create Batch Section
    private var createBatchSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("创建生产批次")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("选择设备和生产模式后，创建新的生产配置批次")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("创建批次") {
                createNewBatch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canManageProduction || selectedMachine == nil)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Batch Configuration Section
    private func batchConfigurationSection(_ batch: ProductionBatch) -> some View {
        VStack(spacing: 16) {
            // Batch info header
            batchInfoHeader(batch)
            
            // Products list
            productsListSection(batch)
            
            // Add product button
            if canManageProduction && batch.products.count < batch.mode.maxProducts {
                Button("添加产品") {
                    showingAddProduct = true
                }
                .buttonStyle(.bordered)
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
                    Text(batch.batchNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("生产模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(batch.mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            HStack {
                Text("工位使用: \(batch.totalStationsUsed)/12")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("产品数量: \(batch.products.count)/\(batch.mode.maxProducts)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
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
                        .foregroundColor(.gray)
                    
                    Text("暂无产品配置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(batch.products, id: \.id) { product in
                        ProductConfigRow(
                            product: product,
                            colors: colorService.colors,
                            onDelete: canManageProduction ? {
                                _ = batchService.removeProductFromBatch(batch, productConfig: product)
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
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Properties
    private var canManageProduction: Bool {
        authService.currentUser?.hasRole(.workshopManager) == true ||
        authService.currentUser?.hasRole(.administrator) == true
    }
    
    private var hasError: Bool {
        batchService.errorMessage != nil || colorService.errorMessage != nil || machineService.errorMessage != nil || productService.error != nil
    }
    
    private var errorMessage: String {
        batchService.errorMessage ?? colorService.errorMessage ?? machineService.errorMessage ?? productService.error?.localizedDescription ?? ""
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        await machineService.loadMachines()
        await colorService.loadActiveColors()
        await productService.loadProducts()
        
        // Select first available machine if none selected
        if selectedMachine == nil {
            selectedMachine = machineService.machines.filter { $0.canReceiveNewTasks }.first
        }
        
        // Auto-populate gun colors if machine is selected and guns have colors
        autoPopulateGunColors()
    }
    
    private func autoPopulateGunColors() {
        guard let machine = selectedMachine else { return }
        
        // Check if guns have assigned colors
        let gunA = machine.guns.first { $0.name == "Gun A" }
        let gunB = machine.guns.first { $0.name == "Gun B" }
        
        if selectedMode == .dualColor {
            // Auto-populate primary color from Gun A for dual-color mode
            if let gunAColorId = gunA?.currentColorId {
                selectedPrimaryColor = colorService.colors.first { $0.id == gunAColorId }
            }
            
            // Auto-populate secondary color from Gun B for dual-color mode
            if let gunBColorId = gunB?.currentColorId {
                selectedSecondaryColor = colorService.colors.first { $0.id == gunBColorId }
            }
        } else if selectedMode == .singleColor {
            // For single-color mode, no pre-population here
            // Color selection will be handled dynamically based on gun selection in AddProductSheet
            selectedPrimaryColor = nil
            selectedSecondaryColor = nil
        }
    }
    
    private func isColorPrePopulated(_ color: ColorCard?, gunName: String) -> Bool {
        guard let machine = selectedMachine,
              let color = color else { return false }
        
        let gun = machine.guns.first { $0.name == gunName }
        return gun?.currentColorId == color.id
    }
    
    private func clearErrors() {
        batchService.clearError()
        colorService.clearError()
        machineService.clearError()
    }
    
    private func createNewBatch() {
        guard let machine = selectedMachine else { return }
        
        Task {
            currentBatch = await batchService.createBatch(machineId: machine.id, mode: selectedMode)
        }
    }
    
    private func submitBatch() {
        guard let batch = currentBatch else { return }
        
        Task {
            let success = await batchService.submitBatch(batch)
            if success {
                currentBatch = nil
            }
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
        .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
    
    private var statusColor: Color {
        switch machine.status {
        case .running: return .green
        case .stopped: return .gray
        case .maintenance: return .orange
        case .error: return .red
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
        .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
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
                
                Text(product.stationRange)
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
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
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
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
                .fill(isOccupied ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 32, height: 20)
                .overlay(
                    Text("\(stationNumber)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isOccupied ? .white : .gray)
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
    @State private var isAdding = false
    
    var availableStations: [Int] {
        let occupiedStations = batch.products.flatMap { $0.occupiedStations }
        return (1...12).filter { !occupiedStations.contains($0) }
    }
    
    var stationCountOptions: [Int] {
        switch batch.mode {
        case .singleColor:
            return [3, 6, 9, 12]
        case .dualColor:
            return [3, 6]
        }
    }
    
    var gunAStations: [Int] { return [1, 2, 3, 4, 5, 6] }
    var gunBStations: [Int] { return [7, 8, 9, 10, 11, 12] }
    
    var body: some View {
        NavigationView {
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
                            addProduct()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValidConfiguration || isAdding)
                        
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
                    // Default to Gun A initially
                    if selectedGun.isEmpty {
                        selectedGun = "Gun A"
                    }
                    updateColorBasedOnGunSelection()
                }
            }
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
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
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
                            .foregroundColor(.green)
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
        .background(Color(UIColor.secondarySystemBackground))
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
                    .background(selectedStationCount == count ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(selectedStationCount == count ? .white : .primary)
                    .cornerRadius(8)
                }
                
                Button("其他") {
                    selectedStationCount = -1 // Use -1 to indicate "Other" option
                    selectedStations = []
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedStationCount == -1 ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(selectedStationCount == -1 ? .white : .primary)
                .cornerRadius(8)
            }
            
            // Show manual station selection when "Other" is selected
            if selectedStationCount == -1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择所需工位 (至少 \(batch.mode.minStationsPerProduct) 个)")
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
                            .background(selectedStations.contains(station) ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedStations.contains(station) ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
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
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
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
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button("Gun A") {
                        selectedGun = "Gun A"
                        updateColorBasedOnGunSelection()
                        if selectedStationCount != nil && selectedStationCount! > 0 {
                            autoAssignStations()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedGun == "Gun A" ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(selectedGun == "Gun A" ? .white : .primary)
                    .cornerRadius(8)
                    
                    Button("Gun B") {
                        selectedGun = "Gun B"
                        updateColorBasedOnGunSelection()
                        if selectedStationCount != nil && selectedStationCount! > 0 {
                            autoAssignStations()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedGun == "Gun B" ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(selectedGun == "Gun B" ? .white : .primary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
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
        .background(Color(UIColor.secondarySystemBackground))
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
                    .background(selectedStations.contains(station) ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(selectedStations.contains(station) ? .white : .primary)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var isValidConfiguration: Bool {
        selectedProduct != nil &&
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedPrimaryColor != nil &&
        (batch.mode == .singleColor || selectedSecondaryColor != nil) &&
        selectedStations.count >= batch.mode.minStationsPerProduct &&
        (selectedStationCount != nil && (selectedStationCount! > 0 || selectedStationCount! == -1))
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
            // Single color products: use selected gun
            let targetStations = selectedGun == "Gun A" ? gunAStations : gunBStations
            let availableTargetStations = targetStations.filter { availableStations.contains($0) }
            
            if stationCount <= 6 {
                // For counts <= 6, use only the selected gun
                selectedStations = Set(availableTargetStations.prefix(stationCount))
            } else {
                // For counts > 6, need to use both guns
                let primaryGunStations = availableTargetStations.prefix(6)
                selectedStations.formUnion(primaryGunStations)
                
                let remainingCount = stationCount - primaryGunStations.count
                if remainingCount > 0 {
                    let oppositeStations = selectedGun == "Gun A" ? gunBStations : gunAStations
                    let availableOppositeStations = oppositeStations.filter { availableStations.contains($0) }
                    selectedStations.formUnion(availableOppositeStations.prefix(remainingCount))
                }
            }
        }
    }
    
    private func addProduct() {
        guard let primaryColor = selectedPrimaryColor else { return }
        
        Task {
            isAdding = true
            let success = await batchService.addProductToBatch(
                batch,
                productName: productName,
                primaryColorId: primaryColor.id,
                secondaryColorId: selectedSecondaryColor?.id,
                stations: Array(selectedStations),
                productId: selectedProduct?.id,
                stationCount: selectedStationCount,
                gunAssignment: selectedGun
            )
            isAdding = false
            if success {
                onDismiss()
            }
        }
    }
    
    private func isColorPrePopulated(_ color: ColorCard?, gunName: String) -> Bool {
        guard let color = color else { return false }
        
        let gun = machine.guns.first { $0.name == gunName }
        return gun?.currentColorId == color.id
    }
    
    private func updateColorBasedOnGunSelection() {
        guard batch.mode == .singleColor else { return }
        
        let selectedGunModel = machine.guns.first { $0.name == selectedGun }
        
        // If the selected gun has a configured color, use it
        if let colorId = selectedGunModel?.currentColorId {
            selectedPrimaryColor = colors.first { $0.id == colorId }
            print("DEBUG: Gun \(selectedGun) has color ID \(colorId), found color: \(selectedPrimaryColor?.name ?? "nil")")
        } else {
            // If the selected gun has no configured color, clear selection to force user configuration
            selectedPrimaryColor = nil
            print("DEBUG: Gun \(selectedGun) has no configured color")
        }
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
                    .foregroundColor(.green)
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
                            .stroke(Color.green, lineWidth: 2)
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
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
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
                        .foregroundColor(.green)
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
                                            .stroke(selectedColor?.id == color.id ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedColor?.id == color.id ? 2 : 1)
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
            return .blue
        } else if isAvailable {
            return .gray.opacity(0.3)
        } else {
            return .red.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isAvailable {
            return .gray
        } else {
            return .red
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
