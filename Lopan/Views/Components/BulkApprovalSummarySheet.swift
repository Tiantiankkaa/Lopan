import SwiftUI

/// Comprehensive bulk approval summary with conflict resolution and validation
struct BulkApprovalSummarySheet: View {
    
    // MARK: - Properties
    
    @ObservedObject private var coordinator: BatchOperationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var approvalNotes: String = ""
    @State private var showingConfirmation: Bool = false
    @State private var isProcessing: Bool = false
    @State private var validationErrors: [String] = []
    @State private var conflictResolutions: [ConflictResolution] = []
    @State private var approvalResult: BatchApprovalResult?
    
    private let selectedBatchIds: [String]
    private let onApprovalComplete: (BatchApprovalResult) -> Void
    
    // MARK: - Computed Properties
    
    private var selectedBatches: [ProductionBatch] {
        coordinator.availableBatches.filter { selectedBatchIds.contains($0.id) }
    }
    
    private var machineGroups: [MachineGroup] {
        let groupedByMachine = Dictionary(grouping: selectedBatches) { $0.machineId }
        return groupedByMachine.map { machineId, batches in
            MachineGroup(
                machineId: machineId,
                batches: batches,
                readinessState: coordinator.machineReadiness[machineId]
            )
        }.sorted { $0.machineId < $1.machineId }
    }
    
    private var conflictingSections: [ConflictSection] {
        let conflicts = coordinator.activeConflicts.filter { conflict in
            conflict.affectedMachineIds.contains(where: { machineId in
                selectedBatches.contains(where: { $0.machineId == machineId })
            })
        }
        
        return Dictionary(grouping: conflicts) { $0.type }
            .map { type, conflicts in
                ConflictSection(type: type, conflicts: conflicts)
            }
            .sorted { $0.type.severity.rawValue > $1.type.severity.rawValue }
    }
    
    private var approvalSummary: ApprovalSummary {
        let totalBatches = selectedBatches.count
        let readyMachines = machineGroups.filter { $0.isReady }.count
        let conflictCount = coordinator.activeConflicts.filter { conflict in
            conflict.affectedMachineIds.contains(where: { machineId in
                selectedBatches.contains(where: { $0.machineId == machineId })
            })
        }.count
        
        return ApprovalSummary(
            totalBatches: totalBatches,
            totalMachines: machineGroups.count,
            readyMachines: readyMachines,
            conflictCount: conflictCount,
            canProceed: conflictCount == 0 && readyMachines == machineGroups.count
        )
    }
    
    // MARK: - Initialization
    
    init(
        coordinator: BatchOperationCoordinator,
        selectedBatchIds: [String],
        onApprovalComplete: @escaping (BatchApprovalResult) -> Void
    ) {
        self.coordinator = coordinator
        self.selectedBatchIds = selectedBatchIds
        self.onApprovalComplete = onApprovalComplete
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary header
                    summaryHeaderSection
                    
                    // Machine groups
                    machineGroupsSection
                    
                    // Conflicts section
                    if !conflictingSections.isEmpty {
                        conflictsSection
                    }
                    
                    // Approval notes
                    approvalNotesSection
                    
                    // Validation errors
                    if !validationErrors.isEmpty {
                        validationErrorsSection
                    }
                }
                .padding()
            }
            .navigationTitle("批量审批确认")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("审批") {
                        performValidation()
                    }
                    .disabled(!canProceedWithApproval)
                }
            }
        }
        .alert("确认批量审批", isPresented: $showingConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认审批") {
                performApproval()
            }
        } message: {
            Text("您即将审批 \(approvalSummary.totalBatches) 个批次，涉及 \(approvalSummary.totalMachines) 台设备。此操作不可撤销。")
        }
        .processingOverlay(
            isProcessing: isProcessing,
            message: "正在处理批量审批...",
            progress: coordinator.isProcessing ? coordinator.workflowProgress : nil,
            statusMessage: coordinator.isProcessing ? coordinator.statusMessage : nil
        )
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeaderSection: some View {
        LopanCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("批量审批摘要")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("准备审批选定的生产批次")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Summary metrics
                HStack(spacing: 20) {
                    SummaryMetric(
                        title: "批次数量",
                        value: "\(approvalSummary.totalBatches)",
                        icon: "list.bullet.rectangle",
                        color: .blue
                    )
                    
                    SummaryMetric(
                        title: "设备数量",
                        value: "\(approvalSummary.totalMachines)",
                        icon: "gear.2",
                        color: .green
                    )
                    
                    if approvalSummary.conflictCount > 0 {
                        SummaryMetric(
                            title: "冲突数量",
                            value: "\(approvalSummary.conflictCount)",
                            icon: "exclamationmark.triangle",
                            color: .orange
                        )
                    }
                }
                
                // Status indicator
                HStack {
                    Image(systemName: approvalSummary.canProceed ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundColor(approvalSummary.canProceed ? .green : .orange)
                    
                    Text(approvalSummary.canProceed ? "所有条件已满足，可以进行审批" : "存在需要解决的问题")
                        .font(.subheadline)
                        .foregroundColor(approvalSummary.canProceed ? .green : .orange)
                }
            }
        }
    }
    
    // MARK: - Machine Groups Section
    
    private var machineGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备详情")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(machineGroups, id: \.machineId) { group in
                MachineGroupCard(group: group)
            }
        }
    }
    
    // MARK: - Conflicts Section
    
    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("配置冲突")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("自动解决") {
                    Task {
                        await attemptAutoResolution()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
            
            ForEach(conflictingSections, id: \.type) { section in
                ConflictSectionCard(section: section) { conflict in
                    // Handle manual conflict resolution
                    showConflictResolutionOptions(for: conflict)
                }
            }
        }
    }
    
    // MARK: - Approval Notes Section
    
    private var approvalNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("审批备注")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("输入审批备注 (可选)", text: $approvalNotes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
                .onChange(of: approvalNotes) { newValue in
                    validateApprovalNotes(newValue)
                }
        }
    }
    
    // MARK: - Validation Errors Section
    
    private var validationErrorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("验证错误")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            ForEach(validationErrors, id: \.self) { error in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    
    // MARK: - Helper Properties
    
    private var canProceedWithApproval: Bool {
        return !isProcessing && 
               approvalSummary.canProceed && 
               validationErrors.isEmpty
    }
    
    // MARK: - Methods
    
    private func loadInitialData() async {
        // Perform initial validation
        await performInitialValidation()
    }
    
    private func performInitialValidation() async {
        validationErrors.removeAll()
        
        // Validate batch compatibility
        do {
            let conflicts = try await coordinator.batchRepository.validateBatchCompatibility(batchIds: selectedBatchIds)
            if !conflicts.isEmpty {
                validationErrors.append("检测到 \(conflicts.count) 个批次兼容性问题")
            }
        } catch {
            validationErrors.append("批次验证失败: \(error.localizedDescription)")
        }
        
        // Validate machine readiness
        for group in machineGroups {
            if !group.isReady {
                validationErrors.append("设备 \(group.machineId) 未就绪")
            }
        }
    }
    
    private func validateApprovalNotes(_ notes: String) {
        let validation = SecurityValidation.validateReviewNotes(notes)
        if !validation.isValid {
            validationErrors.removeAll { $0.contains("备注") }
            if let error = validation.errorMessage {
                validationErrors.append("备注验证失败: \(error)")
            }
        } else {
            validationErrors.removeAll { $0.contains("备注") }
        }
    }
    
    private func performValidation() {
        Task {
            await performInitialValidation()
            
            if validationErrors.isEmpty {
                showingConfirmation = true
            }
        }
    }
    
    private func performApproval() {
        Task {
            isProcessing = true
            
            do {
                // Create approval group for selected batches
                let approvalGroup = ApprovalGroup(
                    groupName: "批量审批-\(Date().formatted(date: .abbreviated, time: .shortened))",
                    targetDate: coordinator.currentWorkflow?.targetDate ?? Date(),
                    batchIds: selectedBatchIds,
                    coordinatorUserId: coordinator.currentWorkflow?.coordinatorId ?? ""
                )
                
                try await coordinator.batchRepository.createApprovalGroup(approvalGroup)
                
                // Process the approval
                let result = try await coordinator.processBatchApproval(
                    groupId: approvalGroup.id,
                    approverUserId: coordinator.currentWorkflow?.coordinatorId ?? "",
                    notes: approvalNotes.isEmpty ? nil : approvalNotes
                )
                
                approvalResult = result
                onApprovalComplete(result)
                
                dismiss()
                
            } catch {
                validationErrors.append("审批处理失败: \(error.localizedDescription)")
            }
            
            isProcessing = false
        }
    }
    
    private func attemptAutoResolution() async {
        let conflicts = coordinator.activeConflicts.filter { $0.canAutoResolve }
        
        do {
            let resolutions = try await coordinator.batchRepository.autoResolveConflicts(conflicts)
            conflictResolutions.append(contentsOf: resolutions)
            
            // Refresh conflict detection
            if let workflow = coordinator.currentWorkflow {
                // Refresh conflicts through public interface
                // await coordinator.detectAndUpdateConflicts(for: workflow.targetDate)
            }
            
        } catch {
            validationErrors.append("自动解决冲突失败: \(error.localizedDescription)")
        }
    }
    
    private func showConflictResolutionOptions(for conflict: ConfigurationConflict) {
        // This would show manual resolution options
        // For now, placeholder implementation
    }
}

// MARK: - Supporting Views

struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MachineGroupCard: View {
    let group: MachineGroup
    
    var body: some View {
        LopanCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("设备 \(group.machineId)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(group.batches.count) 个批次")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if let state = group.readinessState {
                            MachineStatusIndicator(state: state)
                        }
                        
                        Image(systemName: group.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(group.isReady ? .green : .orange)
                    }
                }
                
                // Batch details
                VStack(spacing: 6) {
                    ForEach(group.batches, id: \.id) { batch in
                        HStack {
                            Text("批次 \(batch.id.prefix(8))...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(batch.products.count) 产品")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            BatchStatusBadge(status: batch.approvalStatus)
                        }
                    }
                }
            }
        }
    }
}

struct ConflictSectionCard: View {
    let section: ConflictSection
    let onResolveConflict: (ConfigurationConflict) -> Void
    
    var body: some View {
        LopanCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(section.type.severity.color))
                    
                    Text(section.type.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(section.conflicts.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(section.type.severity.color).opacity(0.2))
                        .cornerRadius(8)
                }
                
                ForEach(section.conflicts, id: \.id) { conflict in
                    ConflictRow(conflict: conflict, onResolve: onResolveConflict)
                }
            }
        }
    }
}

struct ConflictRow: View {
    let conflict: ConfigurationConflict
    let onResolve: (ConfigurationConflict) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conflict.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if !conflict.affectedMachineIds.isEmpty {
                    Text("影响设备: \(conflict.affectedMachineIds.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if conflict.canAutoResolve {
                Button("自动解决") {
                    onResolve(conflict)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("手动解决") {
                    onResolve(conflict)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

struct MachineGroup {
    let machineId: String
    let batches: [ProductionBatch]
    let readinessState: MachineReadinessState?
    
    var isReady: Bool {
        return readinessState?.isReady ?? false
    }
}

struct ConflictSection {
    let type: ConflictType
    let conflicts: [ConfigurationConflict]
}

struct ApprovalSummary {
    let totalBatches: Int
    let totalMachines: Int
    let readyMachines: Int
    let conflictCount: Int
    let canProceed: Bool
}