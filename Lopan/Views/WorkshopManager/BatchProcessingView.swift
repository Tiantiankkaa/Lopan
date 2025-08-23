//
//  BatchProcessingView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI
import SwiftData

// MARK: - Sheet Type Enum
enum SheetType: Identifiable, Equatable {
    case batchCreation
    case batchList
    case batchEdit(ProductionBatch)
    case batchApproval(ProductionBatch)
    
    var id: String {
        switch self {
        case .batchCreation:
            return "batchCreation"
        case .batchList:
            return "batchList"
        case .batchEdit(let batch):
            return "batchEdit_\(batch.id)"
        case .batchApproval(let batch):
            return "batchApproval_\(batch.id)"
        }
    }
    
    static func == (lhs: SheetType, rhs: SheetType) -> Bool {
        switch (lhs, rhs) {
        case (.batchCreation, .batchCreation), (.batchList, .batchList):
            return true
        case (.batchEdit(let lhsBatch), .batchEdit(let rhsBatch)):
            return lhsBatch.id == rhsBatch.id
        case (.batchApproval(let lhsBatch), .batchApproval(let rhsBatch)):
            return lhsBatch.id == rhsBatch.id
        default:
            return false
        }
    }
}

// MARK: - Batch Processing View (批次处理视图)
struct BatchProcessingView: View {
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    @State private var selectedDate = Date()
    @State private var selectedShift: Shift = .morning
    @State private var selectedMachineIds: Set<String> = []
    @State private var isLoadingBatches = false
    @State private var activeSheet: SheetType?
    @State private var currentBatches: [ProductionBatch] = []
    @State private var availableMachines: [WorkshopMachine] = []
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isHeaderCollapsed = false
    
    // Service dependencies
    @StateObject private var productionBatchService: ProductionBatchService
    @StateObject private var machineService: MachineService
    @StateObject private var batchEditPermissionService: StandardBatchEditPermissionService
    
    @StateObject private var dateShiftPolicy = StandardDateShiftPolicy()
    private let timeProvider = SystemTimeProvider()
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        
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
    }
    
    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("批次处理")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        refreshButton
                    }
                }
                .task {
                    await loadInitialData()
                }
                .alert("错误", isPresented: $showingError, presenting: errorMessage) { _ in
                    Button("确定", role: .cancel) { }
                } message: { message in
                    Text(message)
                }
                .sheet(item: $activeSheet) { sheetType in
                    sheetContent(for: sheetType)
                }
                .onChange(of: activeSheet) {
                if activeSheet == nil {
                    // Refresh data when any sheet is dismissed
                    Task {
                        await loadBatchesForSelectedDateTime()
                    }
                }
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            
            scrollableContent
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(BatchScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isHeaderCollapsed = value < -20
                    }
                }
                .refreshable {
                    await refreshData()
                }
        }
    }
    
    private var scrollableContent: some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear.preference(key: BatchScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
            }
            .frame(height: 0)
            
            LazyVStack(spacing: 20) {
                shiftDateSelectorSection
                machineStatusSection
                machineSelectionSection
                batchListSection
                createBatchSection
            }
            .padding()
        }
    }
    
    // MARK: - Header Section (头部区域)
    
    private var headerSection: some View {
        VStack(spacing: isHeaderCollapsed ? 6 : 12) {
            HStack {
                VStack(alignment: .leading, spacing: isHeaderCollapsed ? 2 : 4) {
                    Text("班次批次管理")
                        .font(isHeaderCollapsed ? .headline : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if !isHeaderCollapsed {
                        Text("按班次安排生产批次，精准控制生产节奏")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                Spacer()
                
                batchCountBadge
                    .scaleEffect(isHeaderCollapsed ? 0.8 : 1.0)
            }
            .padding(.horizontal)
            .padding(.top, isHeaderCollapsed ? 4 : 8)
            
            Divider()
        }
        .frame(height: isHeaderCollapsed ? 60 : 80)
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.25), value: isHeaderCollapsed)
    }
    
    private var batchCountBadge: some View {
        VStack(spacing: 2) {
            Text("\(currentBatches.count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("当前批次")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    // MARK: - Shift Date Selector Section (班次日期选择区域)
    
    private var shiftDateSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "选择日期和班次", icon: "calendar.badge.clock")
            
            ShiftDateSelector(
                selectedDate: $selectedDate,
                selectedShift: $selectedShift,
                dateShiftPolicy: dateShiftPolicy,
                timeProvider: timeProvider
            )
            .onChange(of: selectedDate) { _ in
                Task {
                    await loadBatchesForSelectedDateTime()
                }
            }
            .onChange(of: selectedShift) { _ in
                Task {
                    await loadBatchesForSelectedDateTime()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Machine Status Section (机器状态区域)
    
    private var machineStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "设备状态检查", icon: "gearshape.2")
            
            MachineStatusChecker(
                machineService: machineService,
                onStatusChange: { isRunning in
                    // Handle machine status change if needed
                }
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Machine Selection Section (机器选择区域)
    
    private var machineSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "选择生产设备", icon: "gearshape.fill")
                
                Spacer()
                
                if !availableMachines.isEmpty {
                    selectAllToggle
                }
            }
            
            if availableMachines.isEmpty {
                machineEmptyState
            } else {
                machineSelectionGrid
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var selectAllToggle: some View {
        Button(action: {
            if selectedMachineIds.count == availableMachines.count {
                selectedMachineIds.removeAll()
            } else {
                selectedMachineIds = Set(availableMachines.map { $0.id })
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: selectedMachineIds.count == availableMachines.count ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedMachineIds.count == availableMachines.count ? .blue : .secondary)
                
                Text(selectedMachineIds.count == availableMachines.count ? "取消全选" : "全选")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var machineEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("暂无可用设备")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("请先在设备管理中添加生产设备")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var machineSelectionGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(availableMachines, id: \.id) { machine in
                machineSelectionCard(machine: machine)
            }
        }
    }
    
    private func machineSelectionCard(machine: WorkshopMachine) -> some View {
        let isSelected = selectedMachineIds.contains(machine.id)
        
        return Button(action: {
            if selectedMachineIds.contains(machine.id) {
                selectedMachineIds.remove(machine.id)
            } else {
                selectedMachineIds.insert(machine.id)
            }
        }) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: machine.isOperational ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(machine.isOperational ? .green : .orange)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(machine.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("编号: \(machine.machineNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(machine.isOperational ? "运行正常" : "需要维护")
                        .font(.caption2)
                        .foregroundColor(machine.isOperational ? .green : .orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .accessibilityLabel("机器 \(machine.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("点击选择此机器创建批次")
    }
    
    // MARK: - Batch List Section (批次列表区域)
    
    private var batchListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "当前批次列表", icon: "square.stack.3d.down.right")
                
                Spacer()
                
                if !currentBatches.isEmpty {
                    Button("查看全部") {
                        activeSheet = .batchList
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isLoadingBatches {
                batchListLoadingState
            } else if currentBatches.isEmpty {
                batchListEmptyState
            } else {
                batchListContent
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var batchListLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载批次...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var batchListEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("当前时段暂无批次")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("选择设备后可创建新的生产批次")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var batchListContent: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(currentBatches.prefix(3)), id: \.id) { batch in
                batchPreviewCard(batch: batch)
            }
        }
    }
    
    private func batchPreviewCard(batch: ProductionBatch) -> some View {
        Button(action: {
            // Workshop Manager can only edit batches, not approve them
            activeSheet = .batchEdit(batch)
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(batch.batchNumber + " (" + batch.batchType.displayName + ")")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        batchStatusBadge(status: batch.status)
                    }
                    
                    if let targetDate = batch.targetDate, let shift = batch.shift {
                        HStack(spacing: 4) {
                            Image(systemName: shift == .morning ? "sun.min" : "moon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(DateTimeUtilities.formatDate(targetDate, format: "MM-dd")) - \(shift.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("机器: \(batch.machineId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if batch.allowsColorModificationOnly {
                            HStack(spacing: 2) {
                                Image(systemName: "paintpalette")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                
                                Text("颜色模式")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange.opacity(0.2))
                            )
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func batchStatusBadge(status: BatchStatus) -> some View {
        HStack(spacing: 3) {
            Image(systemName: status.iconName)
                .font(.caption2)
                .foregroundColor(.white)
            
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(status.color)
        )
        .accessibilityLabel(status.accessibilityLabel)
    }
    
    // MARK: - Create Batch Section (创建批次区域)
    
    private var createBatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "创建新批次", icon: "plus.square.on.square")
            
            createBatchButton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var createBatchButton: some View {
        let hasSelectedMachines = !selectedMachineIds.isEmpty
        let selectedCount = selectedMachineIds.count
        
        return Button(action: {
            if hasSelectedMachines {
                activeSheet = .batchCreation
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: hasSelectedMachines ? "plus.circle.fill" : "plus.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(hasSelectedMachines ? .white : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("创建批次处理")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(hasSelectedMachines ? .white : .blue)
                    
                    if !hasSelectedMachines {
                        Text("请先选择设备")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("为\(selectedCount)个设备创建批次处理 (BP)")
                            .font(.caption)
                            .foregroundColor(hasSelectedMachines ? .white.opacity(0.8) : .secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(hasSelectedMachines ? .white : .blue)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hasSelectedMachines ? Color.blue : Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasSelectedMachines ? Color.clear : Color.blue, lineWidth: 1)
            )
        }
        .disabled(!hasSelectedMachines)
        .accessibilityLabel("创建生产批次")
        .accessibilityHint(hasSelectedMachines ? "点击为所选设备创建批次" : "请先选择设备")
    }
    
    // MARK: - Toolbar and Actions (工具栏和操作)
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshData()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .medium))
        }
        .accessibilityLabel("刷新数据")
    }
    
    // MARK: - Sheet Views (弹出视图)
    
    @ViewBuilder
    private func sheetContent(for sheetType: SheetType) -> some View {
        switch sheetType {
        case .batchCreation:
            batchCreationSheet
        case .batchList:
            batchListSheet
        case .batchEdit(let batch):
            batchEditSheet(batch: batch)
        case .batchApproval(let batch):
            batchApprovalSheet(batch: batch)
        }
    }
    
    @ViewBuilder
    private var batchCreationSheet: some View {
        if !selectedMachineIds.isEmpty {
            // Pass all selected machines for batch creation
            BatchCreationView(
                repositoryFactory: repositoryFactory,
                authService: authService,
                auditService: auditService,
                selectedDate: selectedDate,
                selectedShift: selectedShift,
                selectedMachineIds: selectedMachineIds
            )
        } else {
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("未选择设备")
                        .font(.headline)
                    
                    Text("请先选择生产设备")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .navigationTitle("创建批次")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
            }
        }
    }
    
    private var batchListSheet: some View {
        NavigationView {
            List(currentBatches, id: \.id) { batch in
                batchPreviewCard(batch: batch)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("批次列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        activeSheet = nil
                    }
                }
            }
            .refreshable {
                await loadBatchesForSelectedDateTime()
            }
        }
    }
    
    private func batchEditSheet(batch: ProductionBatch) -> some View {
        BatchEditView(
            batchId: batch.id,
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
    
    private func batchApprovalSheet(batch: ProductionBatch) -> some View {
        ShiftAwareApprovalView(
            batch: batch,
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
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
    
    // MARK: - Data Loading Methods (数据加载方法)
    
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAvailableMachines()
            }
            group.addTask {
                await self.loadBatchesForSelectedDateTime()
            }
        }
    }
    
    private func refreshData() async {
        await loadInitialData()
        await machineService.forceRefreshMachineStatus()
    }
    
    private func loadAvailableMachines() async {
        do {
            let machines = try await repositoryFactory.machineRepository.fetchMachinesWithoutPendingApprovalBatches()
            await MainActor.run {
                self.availableMachines = machines
            }
        } catch {
            await showError("加载设备列表失败: \(error.localizedDescription)")
        }
    }
    
    private func loadBatchesForSelectedDateTime() async {
        await MainActor.run {
            isLoadingBatches = true
        }
        
        do {
            let batches = try await repositoryFactory.productionBatchRepository.fetchBatches(
                forDate: selectedDate,
                shift: selectedShift
            )
            // Filter to only show Batch Processing (BP) type batches in Workshop Manager
            let bpBatches = batches.filter { $0.batchType == .batchProcessing }
            await MainActor.run {
                self.currentBatches = bpBatches
                self.isLoadingBatches = false
            }
        } catch {
            await showError("加载批次列表失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingBatches = false
            }
        }
    }
    
    private func showError(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.showingError = true
        }
    }
}

// MARK: - BatchScrollOffsetPreferenceKey (滚动偏移量首选项键)
struct BatchScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - BatchStatus Extensions (批次状态扩展)
extension BatchStatus {
    var color: Color {
        switch self {
        case .unsubmitted:
            return .orange
        case .pending:
            return .blue
        case .approved:
            return .green
        case .pendingExecution:
            return .cyan
        case .active:
            return .purple
        case .completed:
            return .secondary
        case .rejected:
            return .red
        }
    }
}

// MARK: - Preview Support (预览支持)
struct BatchProcessingView_Previews: PreviewProvider {
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
        
        BatchProcessingView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}
