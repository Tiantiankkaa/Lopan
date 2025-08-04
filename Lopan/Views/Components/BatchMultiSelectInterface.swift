import SwiftUI

/// Advanced multi-select interface for batch operations with search, filtering, and bulk actions
struct BatchMultiSelectInterface: View {
    
    // MARK: - Properties
    
    @StateObject private var coordinator: BatchOperationCoordinator
    @State private var selectedBatchIds: Set<String> = []
    @State private var searchText: String = ""
    @State private var filterStatus: BatchFilterStatus = .all
    @State private var activeSheet: SheetType?
    
    enum SheetType: Identifiable {
        case conflictResolution
        case approvalSummary
        
        var id: String {
            switch self {
            case .conflictResolution: return "conflictResolution"
            case .approvalSummary: return "approvalSummary"
            }
        }
    }
    
    private let targetDate: Date
    private let onSelectionChanged: (Set<String>) -> Void
    
    // MARK: - Computed Properties
    
    private var filteredBatches: [ProductionBatch] {
        coordinator.availableBatches
            .filter { batch in
                // Search filter
                if !searchText.isEmpty {
                    let searchLower = searchText.lowercased()
                    return batch.machineId.lowercased().contains(searchLower) ||
                           batch.products.contains { config in
                               config.productName.lowercased().contains(searchLower)
                           }
                }
                return true
            }
            .filter { batch in
                // Status filter
                switch filterStatus {
                case .all: return true
                case .ready: return batch.canBeProcessed
                case .pending: return batch.approvalStatus == .pending
                case .approved: return batch.approvalStatus == .approved
                case .conflicts: return batch.hasConflicts
                }
            }
            .sorted { $0.submittedAt ?? Date.distantPast < $1.submittedAt ?? Date.distantPast }
    }
    
    private var selectionSummary: SelectionSummary {
        let selectedBatches = filteredBatches.filter { selectedBatchIds.contains($0.id) }
        let machineIds = Set(selectedBatches.map { $0.machineId })
        let hasConflicts = selectedBatches.contains { $0.hasConflicts }
        
        return SelectionSummary(
            batchCount: selectedBatches.count,
            machineCount: machineIds.count,
            hasConflicts: hasConflicts,
            canProcess: !selectedBatches.isEmpty && selectedBatches.allSatisfy { $0.canBeProcessed }
        )
    }
    
    // MARK: - Initialization
    
    init(
        coordinator: BatchOperationCoordinator,
        targetDate: Date,
        onSelectionChanged: @escaping (Set<String>) -> Void
    ) {
        self._coordinator = StateObject(wrappedValue: coordinator)
        self.targetDate = targetDate
        self.onSelectionChanged = onSelectionChanged
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerSection
            
            // Batch list
            batchListSection
            
            // Selection toolbar
            if !selectedBatchIds.isEmpty {
                selectionToolbar
            }
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .approvalSummary:
                BulkApprovalSummarySheet(
                    coordinator: coordinator,
                    selectedBatchIds: Array(selectedBatchIds),
                    onApprovalComplete: handleApprovalComplete
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .conflictResolution:
                BatchConflictResolutionSheet(
                    coordinator: coordinator,
                    conflicts: getConflictsForSelection(),
                    onResolutionComplete: handleConflictResolution
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: selectedBatchIds) { _, newValue in
            onSelectionChanged(newValue)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索设备或产品...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Filter options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BatchFilterStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            count: getBatchCount(for: status),
                            isSelected: filterStatus == status,
                            color: status.color
                        ) {
                            filterStatus = status
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Batch List Section
    
    private var batchListSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredBatches.isEmpty {
                    EmptyBatchListView(
                        searchText: searchText,
                        filterStatus: filterStatus
                    )
                } else {
                    ForEach(filteredBatches, id: \.id) { batch in
                        BatchSelectionRow(
                            batch: batch,
                            isSelected: selectedBatchIds.contains(batch.id),
                            machineState: coordinator.machineReadiness[batch.machineId],
                            onSelectionToggled: { isSelected in
                                toggleBatchSelection(batch.id, isSelected: isSelected)
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
    }
    
    // MARK: - Selection Toolbar
    
    private var selectionToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Selection summary
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选择 \(selectionSummary.batchCount) 个批次")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label("\(selectionSummary.machineCount) 台设备", systemImage: "gear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if selectionSummary.hasConflicts {
                            Label("存在冲突", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("清除选择") {
                        selectedBatchIds.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    if selectionSummary.hasConflicts {
                        Button("解决冲突") {
                            activeSheet = .conflictResolution
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    
                    Button(selectionSummary.hasConflicts ? "强制审批" : "批量审批") {
                        activeSheet = .approvalSummary
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!selectionSummary.canProcess)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleBatchSelection(_ batchId: String, isSelected: Bool) {
        if isSelected {
            selectedBatchIds.insert(batchId)
        } else {
            selectedBatchIds.remove(batchId)
        }
    }
    
    private func getBatchCount(for status: BatchFilterStatus) -> Int {
        coordinator.availableBatches.filter { batch in
            switch status {
            case .all: return true
            case .ready: return batch.canBeProcessed
            case .pending: return batch.approvalStatus == .pending
            case .approved: return batch.approvalStatus == .approved
            case .conflicts: return batch.hasConflicts
            }
        }.count
    }
    
    private func getConflictsForSelection() -> [ConfigurationConflict] {
        return coordinator.activeConflicts.filter { conflict in
            conflict.affectedMachineIds.contains(where: { machineId in
                filteredBatches.contains(where: { batch in
                    selectedBatchIds.contains(batch.id) && batch.machineId == machineId
                })
            })
        }
    }
    
    private func handleApprovalComplete(_ result: BatchApprovalResult) {
        // Close sheet
        activeSheet = nil
        // Clear selection after successful approval
        if result.isFullySuccessful {
            selectedBatchIds.removeAll()
        }
    }
    
    private func handleConflictResolution(_ resolutions: [ConflictResolution]) {
        // Close sheet
        activeSheet = nil
        // Refresh data after conflict resolution
        Task {
            if let workflow = coordinator.currentWorkflow {
                // Refresh data through public interface
                // await coordinator.refreshApprovalGroups(for: workflow.targetDate)
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BatchSelectionRow: View {
    let batch: ProductionBatch
    let isSelected: Bool
    let machineState: MachineReadinessState?
    let onSelectionToggled: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: { onSelectionToggled(!isSelected) }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Batch information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("设备 \(batch.machineId)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    BatchStatusBadge(status: batch.approvalStatus)
                }
                
                HStack {
                    Text("\(batch.products.count) 个产品")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let state = machineState {
                        Spacer()
                        MachineStatusIndicator(state: state)
                    }
                }
                
                if batch.hasConflicts {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("存在配置冲突")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Disclosure indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct EmptyBatchListView: View {
    let searchText: String
    let filterStatus: BatchFilterStatus
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyMessage)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(emptySubMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "无搜索结果"
        } else {
            switch filterStatus {
            case .all: return "暂无批次"
            case .ready: return "无就绪批次"
            case .pending: return "无待审批批次"
            case .approved: return "无已批准批次"
            case .conflicts: return "无冲突批次"
            }
        }
    }
    
    private var emptySubMessage: String {
        if !searchText.isEmpty {
            return "尝试调整搜索关键词或筛选条件"
        } else {
            return "当前没有符合条件的生产批次"
        }
    }
}

// MARK: - Supporting Types

enum BatchFilterStatus: CaseIterable {
    case all
    case ready
    case pending
    case approved
    case conflicts
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .ready: return "就绪"
        case .pending: return "待审批"
        case .approved: return "已批准"
        case .conflicts: return "冲突"
        }
    }
    
    var color: String {
        switch self {
        case .all: return "blue"
        case .ready: return "green"
        case .pending: return "orange"
        case .approved: return "purple"
        case .conflicts: return "red"
        }
    }
}

struct SelectionSummary {
    let batchCount: Int
    let machineCount: Int
    let hasConflicts: Bool
    let canProcess: Bool
}

// MARK: - Batch Status Badge

struct BatchStatusBadge: View {
    let status: BatchStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(status.color).opacity(0.2))
            )
            .foregroundColor(Color(status.color))
    }
}

// MARK: - Machine Status Indicator

struct MachineStatusIndicator: View {
    let state: MachineReadinessState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(state.readinessStatus.color))
                .frame(width: 8, height: 8)
            
            Text(state.readinessStatus.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extensions

extension ProductionBatch {
    var canBeProcessed: Bool {
        return status == .pending
    }
    
    var hasConflicts: Bool {
        // Check if this batch is involved in any active conflicts
        // This would ideally be injected from the coordinator, but for now
        // we'll do basic validation checks
        
        // Check for duplicate machine usage (simplified)
        let productMachines = Set(products.map { _ in machineId })
        
        // Check for overlapping station usage within the batch
        let allStations = products.flatMap { $0.occupiedStations }
        let uniqueStations = Set(allStations)
        if allStations.count != uniqueStations.count {
            return true // Station conflict within batch
        }
        
        // Check for color conflicts within batch
        let allColors = products.compactMap { $0.primaryColorId } + 
                       products.compactMap { $0.secondaryColorId }
        let colorGroups = Dictionary(grouping: allColors) { $0 }
        let hasColorConflict = colorGroups.values.contains { $0.count > 1 }
        
        return hasColorConflict
    }
    
    var approvalStatus: BatchStatus {
        return status
    }
}