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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
    @StateObject private var serviceProvider: WorkshopManagerServiceProvider
    @ObservedObject private var productionBatchService: ProductionBatchService
    @ObservedObject private var machineService: MachineService
    @ObservedObject private var batchEditPermissionService: StandardBatchEditPermissionService
    
    @StateObject private var dateShiftPolicy = StandardDateShiftPolicy()
    private let timeProvider = SystemTimeProvider()
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        
        let provider = WorkshopManagerServiceProvider(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
        self._serviceProvider = StateObject(wrappedValue: provider)
        self._productionBatchService = ObservedObject(wrappedValue: provider.batchService)
        self._machineService = ObservedObject(wrappedValue: provider.machineService)
        self._batchEditPermissionService = ObservedObject(wrappedValue: provider.batchEditPermissionService)
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("batch_processing_title".localized)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        refreshButton
                    }
                }
                .task {
                    await loadInitialData()
                }
                .alert("batch_processing_error_title".localized, isPresented: $showingError, presenting: errorMessage) { _ in
                    Button("common_ok".localized, role: .cancel) { }
                } message: { message in
                    Text(message)
                }
                .sheet(item: $activeSheet) { sheetType in
                    sheetContent(for: sheetType)
                }
                .onChange(of: activeSheet) {
                if activeSheet == nil {
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
                    if reduceMotion {
                        isHeaderCollapsed = value < -20
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHeaderCollapsed = value < -20
                        }
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
            .padding(.horizontal, LopanSpacing.screenPadding)
            .padding(.vertical, LopanSpacing.lg)
        }
    }
    
    // MARK: - Header Section (头部区域)
    
    private var headerSection: some View {
        VStack(spacing: isHeaderCollapsed ? 6 : 12) {
            HStack {
                VStack(alignment: .leading, spacing: isHeaderCollapsed ? 2 : 4) {
                    Text("batch_processing_header_title".localized)
                        .font(isHeaderCollapsed ? .headline : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    if !isHeaderCollapsed {
                        Text("batch_processing_header_subtitle".localized)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
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
        .background(LopanColors.backgroundPrimary)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isHeaderCollapsed)
    }

    private var batchCountBadge: some View {
        VStack(spacing: LopanSpacing.xxxs) {
            Text(currentBatches.count.formatted())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.info)

            Text("batch_processing_header_badge".localized)
                .font(.caption2)
                .foregroundColor(LopanColors.textSecondary)
        }
        .padding(.horizontal, LopanSpacing.sm)
        .padding(.vertical, LopanSpacing.xs)
        .background(
            Capsule()
                .fill(LopanColors.info.opacity(0.12))
        )
    }
    
    // MARK: - Shift Date Selector Section (班次日期选择区域)
    
    private var shiftDateSelectorSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                sectionHeader(title: "batch_processing_section_date_shift", icon: "calendar.badge.clock")

                ShiftDateSelector(
                    selectedDate: $selectedDate,
                    selectedShift: $selectedShift,
                    dateShiftPolicy: dateShiftPolicy,
                    timeProvider: timeProvider
                )
                .onChange(of: selectedDate) { _ in
                    Task { await loadBatchesForSelectedDateTime() }
                }
                .onChange(of: selectedShift) { _ in
                    Task { await loadBatchesForSelectedDateTime() }
                }
            }
        }
    }
    
    // MARK: - Machine Status Section (机器状态区域)
    
    private var machineStatusSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                sectionHeader(title: "batch_processing_section_machine_status", icon: "gearshape.2")

                MachineStatusChecker(
                    machineService: machineService,
                    onStatusChange: { _ in }
                )
            }
        }
    }
    
    // MARK: - Machine Selection Section (机器选择区域)
    
    private var machineSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "batch_processing_section_machine_select", icon: "gearshape.fill")
                
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
    }

    private var selectAllToggle: some View {
        let isAllSelected = !availableMachines.isEmpty && selectedMachineIds.count == availableMachines.count
        let toggleKey: LocalizedStringKey = isAllSelected ? "batch_processing_action_deselect_all" : "batch_processing_action_select_all"

        return Button(action: {
            if isAllSelected {
                selectedMachineIds.removeAll()
            } else {
                selectedMachineIds = Set(availableMachines.map { $0.id })
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isAllSelected ? LopanColors.info : LopanColors.textSecondary)
                
                Text(toggleKey)
                    .font(.caption)
                    .foregroundColor(LopanColors.info)
            }
        }
    }

    private var machineEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(LopanColors.warning)
            
            Text("batch_processing_machine_empty_title")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("batch_processing_machine_empty_subtitle")
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
                        .foregroundColor(machine.isOperational ? LopanColors.success : LopanColors.warning)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LopanColors.info)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(machine.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(String(format: "batch_processing_machine_number".localized, machine.machineNumber))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(machine.isOperational ? "batch_processing_machine_status_operational".localized : "batch_processing_machine_status_maintenance".localized)
                        .font(.caption2)
                        .foregroundColor(machine.isOperational ? LopanColors.success : LopanColors.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? LopanColors.info.opacity(0.1) : LopanColors.backgroundPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? LopanColors.info : LopanColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .accessibilityLabel(String(format: "batch_processing_machine_accessibility_label".localized, machine.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("batch_processing_machine_selection_hint".localized)
    }
    
    // MARK: - Batch List Section (批次列表区域)
    
    private var batchListSection: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                HStack {
                    sectionHeader(title: "batch_processing_section_current_batches", icon: "square.stack.3d.down.right")

                    Spacer()

                    if !currentBatches.isEmpty {
                        Button("batch_processing_action_view_all".localized) {
                            activeSheet = .batchList
                        }
                        .font(.caption)
                        .foregroundColor(LopanColors.info)
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
        }
    }
    
    private var batchListLoadingState: some View {
        VStack(spacing: LopanSpacing.sm) {
            ProgressView()
                .scaleEffect(1.2)

            Text("batch_processing_batch_list_loading".localized)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.xl)
    }

    private var batchListEmptyState: some View {
        VStack(spacing: LopanSpacing.sm) {
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 40))
                .foregroundColor(LopanColors.textSecondary)
            
            Text("batch_processing_batch_list_empty_title".localized)
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)
            
            Text("batch_processing_batch_list_empty_description".localized)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LopanSpacing.xl)
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
            activeSheet = .batchEdit(batch)
        }) {
            HStack(spacing: LopanSpacing.sm) {
                VStack(alignment: .leading, spacing: LopanSpacing.xxxs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(batch.batchNumber + " (" + batch.batchType.displayName + ")")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(LopanColors.textPrimary)

                        Spacer()

                        batchStatusBadge(status: batch.status)
                    }

                    if let targetDate = batch.targetDate, let shift = batch.shift {
                        HStack(spacing: LopanSpacing.xxxs) {
                            Image(systemName: shift == .morning ? "sun.min" : "moon")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)

                            Text(String(format: "batch_processing_batch_card_shift".localized, DateTimeUtilities.formatDate(targetDate, format: "MM-dd"), shift.displayName))
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }

                    HStack(spacing: LopanSpacing.sm) {
                        HStack(spacing: LopanSpacing.xxxs) {
                            Image(systemName: "gearshape")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)

                            Text(String(format: "batch_processing_batch_machine".localized, batch.machineId))
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                        }

                        if batch.allowsColorModificationOnly {
                            HStack(spacing: LopanSpacing.xxxs) {
                                Image(systemName: "paintpalette")
                                    .font(.caption2)
                                    .foregroundColor(LopanColors.accent)

                                Text("batch_processing_color_mode".localized)
                                    .font(.caption2)
                                    .foregroundColor(LopanColors.accent)
                            }
                            .padding(.horizontal, LopanSpacing.xxxs)
                            .padding(.vertical, LopanSpacing.xxxs)
                            .background(
                                RoundedRectangle(cornerRadius: LopanCornerRadius.sm, style: .continuous)
                                    .fill(LopanColors.accent.opacity(0.15))
                            )
                        }
                    }
                }

                Spacer(minLength: LopanSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
            .padding(LopanSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                    .fill(LopanColors.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                    .stroke(LopanColors.border.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(batch.batchNumber))
    }
    
    private func batchStatusBadge(status: BatchStatus) -> some View {
        HStack(spacing: 3) {
            Image(systemName: status.iconName)
                .font(.caption2)
                .foregroundColor(LopanColors.textOnPrimary)
            
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textOnPrimary)
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
            sectionHeader(title: "batch_processing_section_create", icon: "plus.square.on.square")
            
            createBatchButton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.backgroundSecondary)
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
            HStack(spacing: LopanSpacing.sm) {
                Image(systemName: hasSelectedMachines ? "plus.circle.fill" : "plus.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(hasSelectedMachines ? LopanColors.textOnPrimary : LopanColors.info)

                VStack(alignment: .leading, spacing: LopanSpacing.xxxs) {
                    Text("batch_processing_create_button".localized)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(hasSelectedMachines ? LopanColors.textOnPrimary : LopanColors.info)

                    if !hasSelectedMachines {
                        Text("batch_processing_create_button_disabled".localized)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                    } else {
                        Text(String(format: "batch_processing_create_button_summary".localized, selectedCount.formatted()))
                            .font(.caption)
                            .foregroundColor(LopanColors.textOnPrimary.opacity(0.85))
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(hasSelectedMachines ? LopanColors.textOnPrimary : LopanColors.info)
            }
            .padding(LopanSpacing.cardPadding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                    .fill(hasSelectedMachines ? LopanColors.info : LopanColors.info.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                    .stroke(hasSelectedMachines ? Color.clear : LopanColors.info, lineWidth: hasSelectedMachines ? 0 : 1)
            )
        }
        .disabled(!hasSelectedMachines)
        .accessibilityLabel(Text("batch_processing_create_button".localized))
        .accessibilityHint(Text(hasSelectedMachines ? "batch_processing_create_button".localized : "batch_processing_create_button_disabled".localized))
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
        .accessibilityLabel(Text("batch_processing_refresh".localized))
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
            BatchCreationView(
                serviceProvider: serviceProvider,
                authService: authService,
                auditService: auditService,
                selectedDate: selectedDate,
                selectedShift: selectedShift,
                selectedMachineIds: selectedMachineIds
            )
        } else {
            NavigationStack {
                VStack(spacing: LopanSpacing.contentSpacing) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(LopanColors.warning)
                    
                    Text("batch_processing_no_machine_title".localized)
                        .font(.headline)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text("batch_processing_sheet_no_machine_message".localized)
                        .font(.body)
                        .foregroundColor(LopanColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("batch_processing_sheet_no_machine_button".localized) {
                        activeSheet = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("batch_processing_sheet_creation_title".localized)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var batchListSheet: some View {
        NavigationStack {
            List(currentBatches, id: \.id) { batch in
                batchPreviewCard(batch: batch)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("batch_processing_sheet_list_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close".localized) {
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
    
    private func sectionHeader(title key: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: LopanSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.info)

            Text(key)
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)
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
            await showError(String(format: "batch_processing_error_network".localized, error.localizedDescription))
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
            await showError(String(format: "batch_processing_error_refresh".localized, error.localizedDescription))
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
            return LopanColors.warning
        case .pending:
            return LopanColors.info
        case .approved:
            return LopanColors.success
        case .pendingExecution:
            return LopanColors.accent
        case .active:
            return LopanColors.premium
        case .completed:
            return LopanColors.secondary
        case .rejected:
            return LopanColors.error
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
